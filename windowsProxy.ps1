param(
    [string]$ProfilePath = "$env:USERPROFILE\Documents\Echolink\Proxyed.reg",
    [string]$ProxyPassword = "public",
    [int]$SampleSize = 5,
    [switch]$RestartEchoLink,
    [string]$ProfileName = "Proxyed"
)

function Get-Proxies {
    Write-Host "Fetching proxy list from echolink.org..."
    try {
        $raw = (Invoke-WebRequest -Uri "http://www.echolink.org/proxylist.jsp" -UseBasicParsing -ErrorAction Stop).Content
    } catch {
        Write-Error "Failed to fetch proxy list: $_"
        return @()
    }

    $rows = [regex]::Split($raw, '(?i)<tr[^>]*>') | Where-Object { $_ -match '</td>' }
    $allRows = @()
    foreach ($row in $rows) {
        $cells = [regex]::Matches($row, '(?i)<td[^>]*>(?<val>.*?)</td>')
        if ($cells.Count -lt 5) { continue }
        $proxyHost = $cells[1].Groups['val'].Value -replace '&nbsp;',' ' -replace '\s+',' ' -replace '^\s+|\s+$',''
        $portVal = $cells[2].Groups['val'].Value -replace '\D',''
        $portParsed = 0
        if (-not [int]::TryParse($portVal, [ref]$portParsed)) { continue }
        $port = $portParsed
        $status = $cells[4].Groups['val'].Value.Trim()
        if ($port -ne 8100) { continue }
        if ($proxyHost -match ":") { continue }
        if ($proxyHost -match "^192\." -or $proxyHost -match "^44\.") { continue }
        $allRows += [pscustomobject]@{ Host = $proxyHost; Status = $status }
    }

    $ready = $allRows | Where-Object { $_.Status -match '(?i)ready' }
    $use = if ($ready) { $ready } else { $allRows }

    if (-not $use -or $use.Count -eq 0) {
        Write-Host "No proxies found (after parsing)." -ForegroundColor Yellow
        return @()
    }

    $pi9 = $use | Where-Object { $_.Host -match "(?i)pi9" }
    $chosen = if ($pi9) { $pi9 } else { $use }
    $hosts = $chosen.Host | Select-Object -Unique

    Write-Host ("Proxies collected: {0} (parsed rows: {1}, ready rows: {2})" -f $hosts.Count, $allRows.Count, $ready.Count)
    return $hosts
}
function Get-LatencyMs {
    param([string]$HostName)
    $lat = $null
    try {
        $probe = Test-NetConnection -ComputerName $HostName -Port 8100 -InformationLevel Detailed -WarningAction SilentlyContinue -ErrorAction Stop
        if ($probe.PingMilliseconds -gt 0) { $lat = [int][math]::Round($probe.PingMilliseconds) }
    } catch {}
    if (-not $lat) {
        try {
            $ping = Test-Connection -ComputerName $HostName -Count 1 -ErrorAction Stop | Select-Object -First 1 -ExpandProperty ResponseTime
            if ($ping -gt 0) { $lat = [int][math]::Round($ping) }
        } catch {}
    }
    return $lat
}

function Update-EchoLinkProfile {
    param(
        [string]$Path,
        [string]$Proxy,
        [string]$Password
    )
    if (-not (Test-Path -Path $Path)) {
        throw "Profile file not found at $Path"
    }
    $raw = Get-Content -Path $Path -Raw
    $changed = 0

    function Set-EntryString {
        param([string]$Text, [string]$Name, [string]$Value)
        $pattern = '(?im)^"' + [regex]::Escape($Name) + '"\s*=\s*"[^"]*"'
        if ($Text -match $pattern) {
            $newText = [regex]::Replace($Text, $pattern, '"' + $Name + '"="' + $Value + '"')
            return @($newText, [int]($newText -ne $Text))
        } else {
            $append = '"' + $Name + '"="' + $Value + '"'
            $newText = $Text.TrimEnd() + "`r`n" + $append + "`r`n"
            return @($newText, 1)
        }
    }

    function Set-EntryDword {
        param([string]$Text, [string]$Name, [int]$Value)
        $hex = ('{0:x8}' -f $Value)
        $pattern = '(?im)^"' + [regex]::Escape($Name) + '"\s*=\s*dword:[0-9a-fA-F]{8}'
        if ($Text -match $pattern) {
            $newText = [regex]::Replace($Text, $pattern, '"' + $Name + '"=dword:' + $hex)
            return @($newText, [int]($newText -ne $Text))
        } else {
            $append = '"' + $Name + '"=dword:' + $hex
            $newText = $Text.TrimEnd() + "`r`n" + $append + "`r`n"
            return @($newText, 1)
        }
    }

    $raw, $delta = Set-EntryString -Text $raw -Name "ProxyServer" -Value $Proxy; $changed += $delta
    $raw, $delta = Set-EntryString -Text $raw -Name "ProxyPassword" -Value $Password; $changed += $delta
    $raw, $delta = Set-EntryString -Text $raw -Name "ProxyPort" -Value "8100"; $changed += $delta
    $raw, $delta = Set-EntryDword  -Text $raw -Name "ProxyPort" -Value 8100; $changed += $delta
    $raw, $delta = Set-EntryString -Text $raw -Name "Proxy" -Value $Proxy; $changed += $delta

    Set-Content -Path $Path -Value $raw -Encoding ASCII
    return $changed
}

function Set-EchoLinkRegistryValues {
    param(
        [string]$Profile,
        [string]$Proxy,
        [string]$Password
    )
    # K1RFD hive used by current EchoLink builds (global + per-profile options)
    $k1Base = "HKCU:\SOFTWARE\K1RFD\EchoLink"
    $k1Options = Join-Path $k1Base "Options"
    $k1ProfileOptions = Join-Path $k1Base "Profiles\$Profile\EchoLink\Options"
    if (-not (Test-Path $k1Options)) { New-Item -Path $k1Options -Force | Out-Null }
    if (-not (Test-Path $k1ProfileOptions)) { New-Item -Path $k1ProfileOptions -Force | Out-Null }

    foreach ($path in @($k1Options, $k1ProfileOptions)) {
        Set-ItemProperty -Path $path -Name "Proxy" -Value $Proxy -Type String
        Set-ItemProperty -Path $path -Name "ProxyPW" -Value $Password -Type String
        Set-ItemProperty -Path $path -Name "ProxyPort" -Value 8100 -Type DWord
        Set-ItemProperty -Path $path -Name "UseProxy" -Value 1 -Type DWord
    }

    # Set active/default profile under the modern hive
    Set-ItemProperty -Path $k1Base -Name "SelectedProfile" -Value $Profile -Type String
    Set-ItemProperty -Path $k1Base -Name "DefaultProfile" -Value $Profile -Type String
}

$proxies = Get-Proxies
if (-not $proxies) {
    Write-Error "No proxies found."
    exit 1
}

$sample = $proxies | Get-Random -Count ([math]::Min($SampleSize, $proxies.Count))
$best = $null
$bestLat = [double]::PositiveInfinity

foreach ($proxy in $sample) {
    $lat = Get-LatencyMs -HostName $proxy
    if (-not $lat) {
        Write-Host "Proxy $proxy failed" -ForegroundColor Yellow
        continue
    }
    Write-Host "Proxy $proxy latency ~ $lat ms"
    if ($lat -lt $bestLat) {
        $bestLat = $lat
        $best = $proxy
    }
}

if (-not $best) {
    Write-Error "No working proxy found in sample."
    exit 1
}

Write-Host "Best proxy: $best (~$bestLat ms)" -ForegroundColor Green

try {
    $changed = 0
    if (Test-Path $ProfilePath) {
        $changed = Update-EchoLinkProfile -Path $ProfilePath -Proxy $best -Password $ProxyPassword
        Write-Host "Updated profile.reg ($changed fields). Importing..."
        reg import "$ProfilePath" | Out-Null
    } else {
        Write-Host "Profile file not found at $ProfilePath; skipping file import." -ForegroundColor Yellow
    }
    Set-EchoLinkRegistryValues -Profile $ProfileName -Proxy $best -Password $ProxyPassword
    Write-Host "Registry updated."
    if ($RestartEchoLink) {
        Write-Host "Restarting EchoLink..."
        Stop-Process -Name EchoLink -ErrorAction SilentlyContinue
        $echopaths = @(
            'C:\Program Files (x86)\K1RFD\EchoLink\EchoLink.exe',
            'C:\Program Files\K1RFD\EchoLink\EchoLink.exe',
            'C:\Program Files (x86)\EchoLink\EchoLink.exe',
            'C:\Program Files\EchoLink\EchoLink.exe'
        )
        $exe = $echopaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($exe) {
            Start-Process -FilePath $exe -ArgumentList "-p$ProfileName"
            Write-Host "EchoLink restarted from $exe with profile $ProfileName"
        } else {
            Write-Host "EchoLink.exe not found; please start it manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Relaunch EchoLink to use the new proxy." -ForegroundColor Yellow
    }
} catch {
    Write-Error $_
    exit 1
}
