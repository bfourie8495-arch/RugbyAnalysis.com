# Sets up the RugbyAnalysis app on this computer and connects it to Firebase.
# Run it from the app folder:
#     powershell -ExecutionPolicy Bypass -File .\setup.ps1
# It's safe to run again: every step checks what's already done.
#
# It uses Smack Bang's Firebase project (middle-509820) but its own Firestore database
# (rugbydb), its own registered apps and its own functions codebase (rugby), so nothing
# of Smack Bang's is changed.

$Project = 'middle-509820'
$Database = 'rugbydb'
$Region = 'europe-west2'
$Package = 'com.rugbyanalysis.app'
$WebName = 'RugbyAnalysis (web)'

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Step($text) { Write-Host "`n== $text" -ForegroundColor Yellow }
function Succeeds($command) {
    # True if a command works, with its output hidden. (Through cmd, because Windows PowerShell
    # turns a hidden error message into a script error.)
    cmd /c "$command >nul 2>&1"
    return $LASTEXITCODE -eq 0
}
function Run {
    # Runs a command and stops the script if it fails.
    & $args[0] @($args | Select-Object -Skip 1)
    if ($LASTEXITCODE -ne 0) { throw "This failed: $($args -join ' ')" }
}

Step 'Checking Flutter, Python and the Firebase CLI'
foreach ($tool in 'flutter', 'dart', 'firebase', 'git') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool isn't installed or isn't on the PATH." }
}

Step 'Signing in to Firebase (a browser opens only if you are signed out)'
if (-not (Succeeds 'firebase projects:list --json')) { Run firebase login }

Step 'Getting the app''s packages'
Run flutter pub get

Step "Registering the web app '$WebName' (Smack Bang keeps its own)"
$apps = (firebase apps:list WEB --project $Project --json | Out-String | ConvertFrom-Json).result
$web = $apps | Where-Object { $_.displayName -eq $WebName } | Select-Object -First 1
if (-not $web) {
    Run firebase apps:create WEB $WebName --project $Project
    $apps = (firebase apps:list WEB --project $Project --json | Out-String | ConvertFrom-Json).result
    $web = $apps | Where-Object { $_.displayName -eq $WebName } | Select-Object -First 1
}
if (-not $web) { throw "Couldn't find the web app '$WebName' after creating it." }
Write-Host "Web app: $($web.appId)"

Step "Registering the Android app $Package and writing the Firebase settings"
Run dart pub global activate flutterfire_cli
Run dart pub global run flutterfire_cli:flutterfire configure `
    --project=$Project --platforms=android,web --android-package-name=$Package `
    --web-app-id=$($web.appId) --out=lib/firebase_options.dart --yes

Step "Creating the Firestore database '$Database' in $Region"
if (Succeeds "firebase firestore:databases:get $Database --project $Project") {
    Write-Host 'Already there.'
} else {
    Run firebase firestore:databases:create $Database --location $Region --project $Project
}

Step 'Deploying the database rules'
Run firebase deploy --only firestore --project $Project

Step 'Deploying the alert functions (codebase "rugby" only)'
if (-not (Test-Path functions\venv)) {
    # The functions run on Python 3.13 in the cloud; use 3.13 here too if it's installed.
    if (-not (Succeeds 'py -3.13 -m venv functions\venv')) {
        if (Get-Command py -ErrorAction SilentlyContinue) { Run py -3 -m venv functions\venv } else { Run python -m venv functions\venv }
    }
}
Run functions\venv\Scripts\python.exe -m pip install --quiet --upgrade pip
Run functions\venv\Scripts\python.exe -m pip install --quiet -r functions\requirements.txt
Run firebase deploy --only functions:rugby --project $Project

Step 'All set'
Write-Host 'Plug in your phone (or start an emulator), then run:  flutter run' -ForegroundColor Green
