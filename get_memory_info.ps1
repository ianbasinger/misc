$lists = @("computername1","computername2") # array computers to run against

foreach ($list in $lists) { # iterate
    if (Test-Connection -ComputerName $list -Count 1 -Quiet) {
        try {
            # gets total visible memory
            $memout = cmd.exe /c "wmic /node:$list os get TotalVisibleMemorySize /value"
            $memline = $memout | Where-Object { $_ -match "^TotalVisibleMemorySize=" }
            if ($memline) {
                $KB = ($memline -split "=")[1]
                $GB = [math]::Round($KB / 1048576, 2)
                Write-Output "Total Memory on ${list}: ${GB} GB"
            } else {
                Write-Output "Memory not found in WMIC from ${list}"
            }

            # get the module info
            $raw = cmd.exe /c "wmic /node:$list memorychip get Capacity,DeviceLocator,Manufacturer,PartNumber,Speed"
            $lines = $raw | Where-Object { $_ -match "^[0-9]" }

            if ($lines.Count -gt 0) {
                Write-Output "Memory Modules on ${list}:"
                foreach ($line in $lines) {
                    $parts = $line -split '\s{2,}'
                    if ($parts.Count -ge 5) {
                        $capacityBytes = [int64]$parts[0]
                        $slot          = $parts[1]
                        $manufacturer  = $parts[2]
                        $partNumber    = $parts[3]
                        $speed         = $parts[4]
                        $capacityGB    = [math]::Round($capacityBytes / 1073741824, 2)
                        Write-Output " - Slot: $slot | Manufacturer: $manufacturer | Part#: $partNumber | Speed: $speed MHz | Capacity: ${capacityGB} GB"
                    }
                }
            } else {
                Write-Output "No valid memory module info found for ${list}"
            }

        } catch {
            Write-Output "WMIC failed on ${list}: $_"
        }
    } else {
        Write-Output "${list}: Computer unreachable, ping failed, RPC server unavailable"
    }
}
