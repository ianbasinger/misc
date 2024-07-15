$lp_flg = $true
$lp_b_exec = $false

while ($lp_flg) {
    try{
    $v = 1..10 | ForEach-Object {Get-Random -Minimum 1 -Maximum 100}
    $t = $v | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $e = "($($v[0]) + $($v[1])) * ($($v[2]) - $($v[3])) / ($($v[4]) + $($v[5]))"
    $r = Invoke-Expression $e
    $v2 = 1..10 | ForEach-Object {Get-Random -Minimum 50 -Maximum 150}
    $t2 = $v2 | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $e2 = "($($v2[0]) - $($v2[1])) * ($($v2[2]) + $($v2[3])) / ($($v2[4]) - $($v2[5]))"
    $r2 = Invoke-Expression $e2
    }catch{Write-Host "Was not able to evaluate, ISE may not be running correctly or blocked" -ForegroundColor Red}

    $dt = Read-Host "Enter the destination address"
    try {
        $ipadr = [System.Net.Dns]::GetHostAddresses($dt)[0].IPAddressToString
        Write-Host "Resolved IP address for $dt : $ipadr" -ForegroundColor Cyan -BackgroundColor Black}catch{
        Write-Host "Could not resolve IP address for $dt. Please check the address." -ForegroundColor Red
        Write-Host "Invalid IP address/hostname, setting to loopback" -ForegroundColor Red
        $ipadr = "127.0.0.1"}
   
    $dt = $ipadr
    $pr = "ping_results.txt"
    $fp = Read-Host "Enter out file path"
    $lp = $fp + '\' + $pr
    while ($lp_flg) {
        Write-Host "Enter 1 to ping $dt" -ForegroundColor Red -BackgroundColor White
        Write-Host "Enter 2 to get latency results" -ForegroundColor Red -BackgroundColor White
        Write-Host "Enter 3 to clear out file" -ForegroundColor Red -BackgroundColor White
        Write-Host "Enter 4 to view out file size" -ForegroundColor Red -BackgroundColor White
        Write-Host "Enter 5 to exit" -ForegroundColor Red -BackgroundColor White
        $cc = Read-Host "Enter your choice" -ForegroundColor Red -BackgroundColor White

switch ($cc){
1{
try{
$dgw = (Get-NetRoute | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' }).NextHop}catch{
Write-Host "Could not find net adapter with gateway assigned for network prefix 0.0.0.0/0" -ForegroundColor Red}
    try{$ntwr = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })}catch{Write-Host "Could not find an interface within 'up' state" -ForegroundColor Red}
    try{
    $na = Get-NetAdapter
    $ea = $na | Where-Object { $_.Name -eq 'Ethernet' }
    $ip4 = $ea | Get-NetIPAddress -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress
    Write-Host $ip4}catch{Write-Host "Unable to get IPv4 address of Ethernet adapter" -ForegroundColor Red}
    $nt = $ip4 + ' ' + $ntwr
    $a = "Network interface used:"
    $a + ' ' + $nt| Out-File -Append -FilePath $lp
    $cntr = 0
    try{ping.exe -t $dt | ForEach-Object{
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
         "$ts - $_" | Out-File -Append -FilePath $lp
        Write-Host "Pinging $dt $ts" -ForegroundColor Green
        $cntr +=1
        if ($_ -match "Request timed out") {
         $cntr -=1
         Write-Host "Timeout detected: $_" -ForegroundColor Yellow
         "$ts Target $dt $_" | Out-File -Append -FilePath $lp} elseif ($_ -match "TTL expired in transit") {
                            $cntr -=1
                            Write-Host "TTL expired: $_" -ForegroundColor Cyan
                            "$ts Target $dt $_" | Out-File -Append -FilePath $lp
                        }elseif ($_ -match "Destination host unreachable") {
                            $cntr -=1
                            Write-Host "Host unreachable: $_" -ForegroundColor Magenta
                            "$ts Target $dt $_" | Out-File -Append -FilePath $lp
                        }else{Write-Host "Ping results appended to $lp" -ForegroundColor Green -BackroundColor
                        Write-Host "$cntr packets sent successfully" -ForegroundColor Green}}}catch{ Write-Host "Error occurred: $_" -ForegroundColor Red
                }
            }
2{
try{
$tt = 0
$ct = 0
$hv = [double]::NegativeInfinity
$lv = [double]::PositiveInfinity
$ipls = Get-Content -Raw -Path $lp | Select-String -Pattern '\b(?:\d{1,3}\.){3}\d{1,3}\b' -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique

$ri = @()

foreach ($iplss in $ipls) {
    try {
        $dns = [System.Net.Dns]::GetHostEntry($iplss)
        if ($dns.HostName) {
            $ri += [PSCustomObject]@{
                IPAddress = $iplss
                Hostname = $dns.HostName
            }
        } else {
            $ri += [PSCustomObject]@{
                IPAddress = $iplss
                Hostname = "Not resolved"
            }
        }
    } catch {
        $ri += [PSCustomObject]@{
            IPAddress = $iplss
            Hostname = "Error resolving, is this a private address?"
        }
    }
}

if ($ri.Count -gt 0) {
    Write-Host "IP Address | Hostname"
    Write-Host "----------------------"
    for ($i = 0; $i -lt $ri.Count; $i++) {
        Write-Host "$($i + 1). $($ri[$i].IPAddress) | $($ri[$i].Hostname)" -ForegroundColor White -BackgroundColor Red
    }

    $selindex = Read-Host "Enter the index of the desired hostname"
    if ($selindex -ge 1 -and $selindex -le $ri.Count) {
        $selip = $ri[$selindex - 1].IPAddress
        Write-Host "You selected IP address: $selip"
    } else {
        Write-Host "Invalid index. Please choose a valid index."
    }
} else {
    Write-Host "No IP addresses found or none resolved."
}



Get-Content -Path $lp | ForEach-Object{
                        if ($_ -match $selip -and $_ -match"time=(\d+)ms"){
                            $tv = [int]$matches[1]
                            $tt += $tv
                            $ct++
                            $hv = [math]::Max($hv, $tv)
                            $lv = [math]::Min($lv, $tv)}
                    }
                    $av = $tt / $ct
                    $fhv = "IP Address $selip highest latency value: $($hv) ms"
                    $flv = "IP Address $selip lowest latency value: $($lv) ms"
                    $fav = "IP Address $selip average latency value: $($av) ms"
                    Write-Host $fhv
                    Write-Host $flv
                    Write-Host $fav
                   
                   

                } catch {
                    Write-Host "Error occurred: $_" -ForegroundColor Red
                }
            }
3{
    try{
    Clear-Content $lp
    Write-Host "Cleared $lp file" -ForegroundColor Green
    } catch{Write-Host "Error occured, unable to clear out file: $lp $_" -ForegroundColor Red}}


4{
try{$fz = (Get-Item $lp).Length
$szkb = $fz / 1KB
$szmb = $fz / 1MB
$szgb = $fz / 1GB
$dvfzgb = $fz / (1024 * 1024 * 1024)
Write-Host "Out file size (Bytes) : $fz bytes" -ForegroundColor Blue -BackgroundColor Gray
Write-Host "Out file size (KB): $szkb" -ForegroundColor Blue -BackgroundColor Gray
Write-Host "Out file size (MB): $szmb" -ForegroundColor Blue -BackgroundColor Gray
Write-Host "Out file size (GB): $szgb" -ForegroundColor Blue -BackgroundColor Gray
# For GB, that value is actually correct, as $fz b = $fz b / (1024 * 1024 * 1024) = $dvfzgb, this is displayed in scientific notation by default, largers values (1GB+) will display correctly
}

catch{Write-Host "Unable to read out file size, check path or file" -ForegroundColor Red}

}

5{Write-Host "Exiting"

$lp_flg = $false}
        }
    }
}
