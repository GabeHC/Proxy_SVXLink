param(
    [string]$ProfilePath = "$env:USERPROFILE\Documents\Echolink\profile.reg",
    [string]$ProxyPassword = "public",
    [int]$SampleSize = 5
)

function Get-Proxies {
    Write-Host "Fetching proxy list from echolink.org..."
    $content = (Invoke-WebRequest -Uri "http://www.echolink.org/proxylist.jsp" -UseBasicParsing).Content -split "`n"
    $proxies = @()
    foreach ($line in $content) {
        if ($line -notmatch "Ready" -or $line -notmatch "8100" -or $line -notmatch "pi9") { continue }
        $parts = $line -split "\s+"
        if ($parts.Length -lt 3) { continue }
        $host = $parts[2]
        if ($host -match ":") { continue }
        if ($host -match "^192\." -or $host -match "^44\.") { continue }
        $proxies += $host
    }
    return $proxies | Select-Object -Unique
}

function Get-LatencyMs {
    param([string]$Host)
    $lat = $null
    try {
        $probe = Test-NetConnection -ComputerName $Host -Port 8100 -InformationLevel Detailed -WarningAction SilentlyContinue -ErrorAction Stop
        if ($probe.PingMilliseconds -gt 0) { $lat = [int][math]::Round($probe.PingMilliseconds) }
    } catch {}
    if (-not $lat) {
        try {
            $ping = Test-Connection -ComputerName $Host -Count 1 -ErrorAction Stop | Select-Object -First 1 -ExpandProperty ResponseTime
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
    $new = $raw -replace '(?m)^"ProxyServer"="[^"]*"', "\"ProxyServer\"=\"$Proxy\""
    if ($new -ne $raw) { $changed++ ; $raw = $new }
    $new = $raw -replace '(?m)^"ProxyPort"="[^"]*"', '\"ProxyPort\"="8100"'
    if ($new -ne $raw) { $changed++ ; $raw = $new }
    $new = $raw -replace '(?m)^"ProxyPassword"="[^"]*"', "\"ProxyPassword\"=\"$Password\""
    if ($new -ne $raw) { $changed++ ; $raw = $new }
    Set-Content -Path $Path -Value $raw -Encoding ASCII
    return $changed
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
    $lat = Get-LatencyMs -Host $proxy
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
    $changed = Update-EchoLinkProfile -Path $ProfilePath -Proxy $best -Password $ProxyPassword
    Write-Host "Updated profile.reg ($changed fields). Importing..."
    reg import "$ProfilePath"
    Write-Host "Registry updated. Relaunch EchoLink to use the new proxy."
} catch {
    Write-Error $_
    exit 1
}
