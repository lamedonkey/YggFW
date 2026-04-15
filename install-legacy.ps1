Write-Host "Creating temporary folder..."

$tmpRoot = $env:TEMP
$guid = [guid]::NewGuid().ToString()
$workDir = Join-Path $tmpRoot $guid

New-Item -ItemType Directory -Path $workDir -Force | Out-Null

Write-Host "Prepare paths..."
$zipUrl = "https://github.com/lamedonkey/YggFW/raw/main/yggfw-x64.zip"
$zipPath = Join-Path $workDir "yggfw.zip"
$extractPath = Join-Path $workDir "yggfw-x64"
$targetPath = "C:\Bin\YggFW"

# ВАЖНО: включаем TLS 1.2
Write-Host "Enabling TLS 1.2..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Downloading..."
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($zipUrl, $zipPath)

Write-Host "Unpacking..."

# Используем .NET вместо Expand-Archive
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractPath)

Write-Host "Creating service folder..."
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null

Write-Host "Copying files..."
Copy-Item -Path "$extractPath\*" -Destination $targetPath -Recurse -Force

Write-Host "Installing service..."

# Удалим старый сервис если есть
sc.exe stop YggFW | Out-Null 2>&1
sc.exe delete YggFW | Out-Null 2>&1

# ВАЖНО: пробел после "=" обязателен
sc.exe create YggFW binPath= "C:\Bin\YggFW\yggfw.exe" start= auto
sc.exe description YggFW "Lite Yggdrasil (IPv6) Firewall"
sc.exe start YggFW

Write-Host "Done."
