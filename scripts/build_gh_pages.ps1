

param(
  [string]$BaseHref = "/WEB-FLUTTER-PROJECT/",
  # Адрес REST API PocketBase. Для опубликованной сборки нужен адрес,
  # доступный из браузера: локальный 127.0.0.1 виден только на своей машине.
  [string]$ApiBaseUrl = "http://127.0.0.1:8090/api",
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
