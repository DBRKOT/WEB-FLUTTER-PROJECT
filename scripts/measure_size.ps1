
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

flutter build web --release --base-href /WEB-FLUTTER-PROJECT/ -o build/web_size

$total = (Get-ChildItem build\web_size -Recurse -File | Measure-Object Length -Sum).Sum
$main = (Get-Item build\web_size\main.dart.js).Length
$parts = Get-ChildItem build\web_size -Filter "*.part.js" -ErrorAction SilentlyContinue |
  Measure-Object Length -Sum

Write-Host ("catalog_MB={0:N2}" -f ($total / 1MB))
Write-Host ("main_dart_js_KB={0:N0}" -f ($main / 1KB))
if ($parts.Sum) {
  Write-Host ("deferred_parts_KB={0:N0}" -f ($parts.Sum / 1KB))
  Write-Host ("deferred_parts_count={0}" -f $parts.Count)
} else {
  Write-Host "deferred_parts_KB=0"
}
