# Run from anywhere — bootstraps Flutter project scaffolding around existing lib/
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
  $candidate = "C:\Users\Legion 5\flutter\bin\flutter.bat"
  if (Test-Path $candidate) {
    $env:PATH = "C:\Users\Legion 5\flutter\bin;" + $env:PATH
  } else {
    Write-Error "Flutter not found. Install Flutter and re-run."
  }
}

Write-Host "Generating platform folders (keeps existing lib/)..."
flutter create . --project-name smart_home_app --org com.calmhills --platforms=android
flutter pub get
Write-Host "Done. Run: flutter run"
