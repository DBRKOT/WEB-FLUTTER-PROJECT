

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$site = Join-Path $root "build\site_preview"
$app = Join-Path $site "WEB-FLUTTER-PROJECT"

if (-not (Test-Path "build\web\index.html")) {
  Write-Host "Сначала: .\scripts\build_gh_pages.ps1"
  exit 1
}

Remove-Item -Recurse -Force $site -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $app | Out-Null
Copy-Item -Recurse -Force "build\web\*" $app

Write-Host "Сервер: http://localhost:8000/WEB-FLUTTER-PROJECT/"
Set-Location $site
python -m http.server 8000
