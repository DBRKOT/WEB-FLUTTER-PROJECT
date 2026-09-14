

param(
  [string]$BaseHref = "/WEB-FLUTTER-PROJECT/",
  [string]$ApiBaseUrl = "http://localhost:8080/api",
  [string]$OutDir = "build/web"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "base-href = $BaseHref"
Write-Host "API_BASE_URL = $ApiBaseUrl"

flutter build web --release `
  --base-href $BaseHref `
  --dart-define=API_BASE_URL=$ApiBaseUrl

Copy-Item -Force "$OutDir/index.html" "$OutDir/404.html"
Write-Host "OK: $OutDir (+ 404.html)"
