
param(
  [string]$BaseHref = "/WEB-FLUTTER-PROJECT/",
  [string]$ApiBaseUrl = "http://localhost:8080/api",
  [string]$OutDir = "build/web_wasm"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

flutter build web --release --wasm `
  --base-href $BaseHref `
  --dart-define=API_BASE_URL=$ApiBaseUrl `
  -o $OutDir

Copy-Item -Force "$OutDir/index.html" "$OutDir/404.html"
Write-Host "OK: $OutDir (+ 404.html)"
