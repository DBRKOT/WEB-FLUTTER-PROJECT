

param(
  [string]$BaseHref = "/WEB-FLUTTER-PROJECT/",

  [string]$ApiBaseUrl = "http://127.0.0.1:8090/api",
  [string]$OutDir = "build/web"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "base-href = $BaseHref"
Write-Host "API_BASE_URL = $ApiBaseUrl"


$ErrorActionPreference = "Continue"
flutter build web --release `
  --base-href $BaseHref `
  --dart-define=API_BASE_URL=$ApiBaseUrl
if ($LASTEXITCODE -ne 0) { throw "flutter build web завершился с кодом $LASTEXITCODE" }
$ErrorActionPreference = "Stop"

Copy-Item -Force "$OutDir/index.html" "$OutDir/404.html"
Write-Host "OK: $OutDir (+ 404.html)"
