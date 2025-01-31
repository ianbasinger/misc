# get and convert hex to binary
Function get-base16-to-base2 {
    param (
        [string]$hex
    )
    if (-not $hex) {
        Write-Host "Hex string is empty or null..." -ForegroundColor Red
        return @()
    }
    $bytes = for ($i = 0; $i -lt $hex.Length; $i += 2) {
        [Convert]::ToByte($hex.Substring($i, 2), 16)
    }
    return ,$bytes
}

# get ASCII from binary
Function get-ascii {
    param (
        [byte[]]$data,
        [int]$minlength = 4
    )
    if (-not $data) {
        Write-Host "Binary data is empty or null..." -ForegroundColor Red
        return @()
    }
    $text = [System.Text.Encoding]::ASCII.GetString($data)
    $text = $text -replace "[^\x20-\x7E]", " "  # replace non-printable characters with spaces
    $matches = [regex]::Matches($text, "[a-zA-Z0-9_]{${minlength},}") # regex match (a-z, A-Z, 0-9)
    return $matches.Value
}

Function get-utf8 {
    param (
        [byte[]]$data
    )
    if (-not $data) {
        Write-Host "Binary data is empty or null..." -ForegroundColor Red
        return ""
    }
    return [System.Text.Encoding]::UTF8.GetString($data)
}


# get numeric values
Function get-numbers {
    param (
        [byte[]]$data,
        [switch]$negative
    )
    if (-not $data) {
        Write-Host "Binary data is empty or null..." -ForegroundColor Red
        return @{ "floats" = @(); "integers" = @() }
    }
    $floatvals = @()
    $intvals = @()
    for ($i = 0; $i -lt ($data.Length - 3); $i += 4) {
        $chunk = $data[$i..($i+3)]
        $floatval = [BitConverter]::ToSingle($chunk, 0)
        $intval = [BitConverter]::ToUInt32($chunk, 0)
        
        if ($negative -or $floatval -ge 0) {
            $floatvals += $floatval
        }
        if ($negative -or $intval -ge 0) {
            $intvals += $intval
        }
    }
    return @{ "floats" = $floatvals; "integers" = $intvals }
}

# analyze the data
Function get-analysis {
    param (
        [string]$hexdata,
        [int]$asciimlength = 4,
        [switch]$negativenumbers
    )
    if (-not $hexdata) {
        Write-Host "Error: Hex data is empty or null." -ForegroundColor Red
        return
    }
    $binarydata = get-base16-to-base2 -hex $hexdata
    
    if ($binarydata.Length -eq 0) {
        Write-Host "Error: Binary data conversion failed." -ForegroundColor Red
        return
    }
    
   # extract ASCII
    $asciitext = get-ascii -data $binarydata -minlength $asciimlength
    Write-Host "Extracted ASCII Text:" -ForegroundColor Green
    if ($asciitext.Count -gt 0) { $asciitext | ForEach-Object { Write-Host $_ } }
    else { Write-Host "No readable ASCII text found." -ForegroundColor Red }

    # extract UTF-8
    Write-Host "Extracted UTF-8 Text:" -ForegroundColor Magenta
    $utf8text = get-utf8 -data $binarydata
    if ($utf8text) { Write-Host $utf8text }
    else { Write-Host "No UTF-8 text found." -ForegroundColor Red }
    
    # extracts numbers
    $numbers = get-numbers -data $binarydata -negative:$negativenumbers
    Write-Host "Potential Float Values:" -ForegroundColor Cyan
    if ($numbers["floats"].Count -gt 0) {
        $numbers["floats"] | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No float values found..." -ForegroundColor Red
    }
    Write-Host "Potential Integer Values:" -ForegroundColor Yellow
    if ($numbers["integers"].Count -gt 0) {
        $numbers["integers"] | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No integer values found...." -ForegroundColor Red
    }
}

# read hex from file
Function read-hex {
    param (
        [string]$filepath
    )
    if (-not (Test-Path $filepath)) {
        Write-Host "File not found: $filepath" -ForegroundColor Red
        exit
    }
    return Get-Content $filepath -Raw
}

# read the input data
$hexdata = ""
get-analysis -hexdata $hexdata -asciimlength 5 -negativenumbers
