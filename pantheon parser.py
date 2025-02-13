from PyQt5.QtWidgets import QApplication, QLabel, QWidget, QVBoxLayout, QTextEdit, QLineEdit, QPushButton
from PyQt5.QtCore import Qt, QTimer, QPoint
import sys
import threading
from collections import deque
from scapy.all import sniff, UDP, Raw
import binascii
import re
import nltk
import enchant
from nltk.corpus import words


# Initialize English dictionary from PyEnchant
enchant_dict = enchant.Dict("en_US")

# Ensure NLTK words are available
nltk.download("words")

# Load English words dictionary
english_words = set(words.words())

pantheon_port = "55518"
packet_counter = 0  # Track packet count
overlay_text = "Listening for packets..."
filtered_log = ""  # Store packets with meaningful words

# Filtering controls
filter_enabled = False  # Default: Filter is OFF
filter_keyword = ""  # Default: No keyword filter

# Store packets with a limit of 500 to prevent memory issues
MAX_PACKETS = 500
packet_log_buffer = deque(maxlen=MAX_PACKETS)  # Auto-removes old packets when limit is reached


# Function to decode text from different encodings
def decode_text(raw_data):
    for encoding in ["utf-8", "latin-1", "utf-16"]:
        try:
            return raw_data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return None


# Extract meaningful words with improved filtering
def extract_real_words(raw_data):
    meaningful_words = []
    start = None

    for i in range(len(raw_data)):
        if 32 <= raw_data[i] < 127:  # Detect printable ASCII characters
            if start is None:
                start = i
        else:
            if start is not None:
                chunk = raw_data[start:i]
                decoded_chunk = decode_text(chunk)
                if decoded_chunk:
                    word_list = re.findall(r"[a-zA-Z]+", decoded_chunk)
                    
                    # Hybrid approach: Check NLTK dictionary OR Enchant OR heuristic
                    valid_words = [
                        word for word in word_list
                        if is_valid_word(word)
                    ]
                    if valid_words:
                        meaningful_words.extend(valid_words)
                start = None

    return " ".join(meaningful_words) if meaningful_words else ""

# Function to check if a word is valid based on dictionary OR heuristic
def is_valid_word(word):
    vowels = {'a', 'e', 'i', 'o', 'u'}
    return (
        len(word) >= 4 and  # Ensure minimum length
        any(c in vowels for c in word.lower()) and  # Ensure at least one vowel
        (word.lower() in english_words or enchant_dict.check(word)) and  # Check against dictionaries
        not word.isupper()  # Exclude all-uppercase junk
    )

# Base class for draggable overlays
class DraggableOverlay(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_NoSystemBackground)
        self.old_pos = None

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.old_pos = event.globalPos()

    def mouseMoveEvent(self, event):
        if self.old_pos:
            delta = event.globalPos() - self.old_pos
            self.move(self.x() + delta.x(), self.y() + delta.y())
            self.old_pos = event.globalPos()


# Left-Side Overlay Window (Meaningful Words Only + Filter UI)
class Overlay(DraggableOverlay):
    def __init__(self):
        super().__init__()
        self.setGeometry(50, 50, 400, 250)  # Increased size for filter UI

        layout = QVBoxLayout()

        # Filter toggle button
        self.filter_button = QPushButton("Enable Filter", self)
        self.filter_button.setStyleSheet("background-color: gray; color: white; padding: 5px;")
        self.filter_button.clicked.connect(self.toggle_filter)
        layout.addWidget(self.filter_button)

        # Filter input box
        self.filter_input = QLineEdit(self)
        self.filter_input.setPlaceholderText("Enter keyword to filter...")
        self.filter_input.textChanged.connect(self.update_filter_keyword)
        layout.addWidget(self.filter_input)

        # Main label for displaying decoded packets
        self.label = QLabel(overlay_text)
        self.label.setStyleSheet("color: white; font-size: 14px; background-color: rgba(0, 0, 0, 150); padding: 10px;")
        layout.addWidget(self.label)

        self.setLayout(layout)

        # Update Timer
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_label)
        self.timer.start(500)  # Update every 500ms

    def toggle_filter(self):
        global filter_enabled
        filter_enabled = not filter_enabled
        self.filter_button.setText("Disable Filter" if filter_enabled else "Enable Filter")
        self.filter_button.setStyleSheet("background-color: green; color: white; padding: 5px;" if filter_enabled else "background-color: gray; color: white; padding: 5px;")

    def update_filter_keyword(self):
        global filter_keyword
        filter_keyword = self.filter_input.text().strip().lower()

    def update_label(self):
        global filtered_log
        self.label.setText(filtered_log)  # Update only with meaningful words


# Right-Side Packet Log Overlay (All Packets) with Auto-Scroll & Limited History
class PacketLog(DraggableOverlay):
    def __init__(self):
        super().__init__()
        self.setGeometry(1100, 50, 600, 400)  # More right-justified position

        layout = QVBoxLayout()
        self.text_box = QTextEdit()
        self.text_box.setReadOnly(True)
        self.text_box.setStyleSheet("color: white; font-size: 12px; background-color: rgba(0, 0, 0, 200); padding: 10px;")
        layout.addWidget(self.text_box)

        self.setLayout(layout)

        # Update Timer
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_log)
        self.timer.start(500)  # Update every 500ms

    def update_log(self):
        global packet_log_buffer
        self.text_box.setPlainText("\n".join(packet_log_buffer))
        self.text_box.moveCursor(self.text_box.textCursor().End)  # Auto-scroll to latest packet


# Update overlay text dynamically (for meaningful words only + filtering)
def update_overlay(packet_num, decoded_words):
    global filtered_log, filter_enabled, filter_keyword
    if filter_enabled and filter_keyword:
        if filter_keyword in decoded_words.lower():
            filtered_log = f"Packet #{packet_num}\nDecoded: {decoded_words}"
    else:
        filtered_log = f"Packet #{packet_num}\nDecoded: {decoded_words}"


# Update packet log (for all packets, with history limit)
def update_packet_log(packet_num, raw_hex, decoded_words):
    global packet_log_buffer
    packet_entry = (
        f"Packet #{packet_num}\n"
        f"Hex: {raw_hex}\n"
        f"Decoded: {decoded_words if decoded_words else '[Nothing found...]'}\n"
        f"{'-' * 40}\n"
    )
    packet_log_buffer.append(packet_entry)  # Automatically removes old packets when limit is reached


# Function to process captured packets
def process_packet(packet):
    global packet_counter
    if packet.haslayer(UDP) and packet.haslayer(Raw):
        packet_counter += 1  # Increment packet count

        raw_data = bytes(packet[Raw].load)
        hex_data = binascii.hexlify(raw_data).decode()[:40]  # First 20 bytes for readability

        # Extract meaningful words
        meaningful_words = extract_real_words(raw_data)

        # Update right-side window (all packets)
        update_packet_log(packet_counter, hex_data, meaningful_words)

        # Update left-side overlay **only if there are meaningful words**
        if meaningful_words:
            update_overlay(packet_counter, meaningful_words)


# Run sniffing in a separate thread
def start_sniffing():
    print("Listening for packets... (Press Ctrl+C to stop)")
    sniff(filter=f"udp port {pantheon_port}", prn=process_packet, store=False)


# Start Qt Application
app = QApplication(sys.argv)
overlay = Overlay()
packet_window = PacketLog()

overlay.show()
packet_window.show()

# Start packet sniffing in a thread
threading.Thread(target=start_sniffing, daemon=True).start()

sys.exit(app.exec_())
