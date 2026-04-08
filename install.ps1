# Создаём уникальную временную папку
$tmpRoot = $env:TMP
$guid = [guid]::NewGuid().ToString()
$workDir = Join-Path $tmpRoot $guid

New-Item -ItemType Directory -Path $workDir | Out-Null

# Пути
$zipUrl = "https://github.com/lamedonkey/YggFW/raw/main/yggfw-x64.zip"
$zipPath = Join-Path $workDir "yggfw.zip"
$extractPath = Join-Path $workDir "yggfw-x64"
$targetPath = "C:\Bin\YggFW"

# Скачивание
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

# Распаковка
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# Создание целевой папки
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null

# Копирование
Copy-Item -Path "$extractPath\*" -Destination $targetPath -Recurse -Force

# Установка сервиса
sc.exe create YggFW binPath= "C:\Bin\YggFW\yggfw.exe" start= auto
sc.exe description YggFW "Lite Yggdrasil (IPv6) Firewall"
sc.exe start YggFW

Write-Host "Done..."