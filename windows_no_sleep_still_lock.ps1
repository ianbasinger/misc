# this script will set the computer to never sleep but the display will still turn off and the computer will still lock after 900 seconds (15 minutes)

# prevent computer from going to sleep on AC power
powercfg /change standby-timeout-ac 0

# turn off the display after 15 minutes while on AC power
powercfg /change monitor-timeout-ac 15

# enforce lock on wake and idle via the power policy
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 1
powercfg /SETACTIVE SCHEME_CURRENT

# set path for the registry
$desktopPath = "HKCU:\Control Panel\Desktop"

# makes Windows require a password after the display turns off (15 minutes)
Set-ItemProperty -Path $desktopPath -Name "ScreenSaverIsSecure" -Value "1" -Type String
Set-ItemProperty -Path $desktopPath -Name "ScreenSaveTimeOut" -Value "900" -Type String
Set-ItemProperty -Path $desktopPath -Name "ScreenSaveActive" -Value "1" -Type String

# force Windows to apply the new idle and screen saver setting (without requiring a reboot)
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters
