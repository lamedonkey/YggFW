Write-Host "Creating temporary folder..."

$tmpRoot = $env:TMP
$guid = [guid]::NewGuid().ToString()
$workDir = Join-Path $tmpRoot $guid

New-Item -ItemType Directory -Path $workDir | Out-Null

Write-Host "Prepare paths..."
$zipUrl = "https://github.com/lamedonkey/YggFW/raw/main/yggfw-x64.zip"
$zipPath = Join-Path $workDir "yggfw.zip"
$extractPath = Join-Path $workDir "yggfw-x64"
$targetPath = "C:\Bin\YggFW"

Write-Host "Downloading..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

Write-Host "Unpacking..."
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Write-Host "Creating service folder..."
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null

Write-Host "Coping files..."
Copy-Item -Path "$extractPath\*" -Destination $targetPath -Recurse -Force

Write-Host "Installing service..."
sc.exe create YggFW binPath= "C:\Bin\YggFW\yggfw.exe" start= auto
sc.exe description YggFW "Lite Yggdrasil (IPv6) Firewall"
sc.exe start YggFW

Write-Host "Done..."