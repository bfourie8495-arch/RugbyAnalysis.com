# Creates the RugbyAnalysis upload key (the key that proves an app update comes from you) and
# gives it to GitHub, so GitHub's builds are signed with it. Run once, from the app folder:
#     powershell -ExecutionPolicy Bypass -File .\make-upload-key.ps1
#
# It makes:
#   ~\rugbyanalysis-upload.jks     the key itself: back it up somewhere safe (not in git)
#   android\key.properties         its password, for building on this PC (git ignores it)
# and four GitHub secrets: UPLOAD_KEYSTORE_BASE64, UPLOAD_KEYSTORE_PASSWORD, UPLOAD_KEY_ALIAS,
# UPLOAD_KEY_PASSWORD. Secrets can be used by the repo's builds but never read back by anyone.
#
# Google Play then re-signs the app with its own key for people who install from Play
# (Play App Signing), so if this upload key is ever lost, Play support can reset it.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$Repo = 'bfourie8495-arch/RugbyAnalysis.com'
$Key = Join-Path $HOME 'rugbyanalysis-upload.jks'
$Alias = 'upload'

if (Test-Path $Key) { throw "$Key already exists. Delete it first only if you're sure it has never been used." }

# keytool comes with Java; Android Studio has its own copy.
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
foreach ($candidate in @("$env:JAVA_HOME\bin\keytool.exe", "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe")) {
    if (-not $keytool -and (Test-Path $candidate)) { $keytool = $candidate }
}
if (-not $keytool) { throw "Couldn't find keytool. It comes with Android Studio (jbr\bin) or any Java install." }

# A long random password, letters and digits only (so nothing needs escaping anywhere).
$chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
$bytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$Password = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })

Write-Host "`n== Creating the upload key at $Key" -ForegroundColor Yellow
& $keytool -genkeypair -keystore $Key -storetype PKCS12 -alias $Alias -keyalg RSA -keysize 2048 -validity 10000 `
    -storepass $Password -keypass $Password -dname 'CN=Brendon Fourie, O=RugbyAnalysis, C=GB'
if ($LASTEXITCODE -ne 0) { throw 'keytool failed.' }

Write-Host "`n== Saving android\key.properties (for building on this PC)" -ForegroundColor Yellow
@"
storeFile=$($Key -replace '\\', '/')
storePassword=$Password
keyAlias=$Alias
keyPassword=$Password
"@ | Set-Content -Encoding ascii android\key.properties

$secrets = [ordered]@{
    UPLOAD_KEYSTORE_BASE64   = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Key))
    UPLOAD_KEYSTORE_PASSWORD = $Password
    UPLOAD_KEY_ALIAS         = $Alias
    UPLOAD_KEY_PASSWORD      = $Password
}

Write-Host "`n== Giving the key to GitHub's builds" -ForegroundColor Yellow
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) { cmd /c "gh auth status >nul 2>&1"; $ghReady = $LASTEXITCODE -eq 0 } else { $ghReady = $false }
if ($ghReady) {
    foreach ($name in $secrets.Keys) {
        gh secret set $name --repo $Repo --body $secrets[$name]  # --body: a pipe would add a newline
        if ($LASTEXITCODE -ne 0) { throw "Couldn't set the secret $name." }
    }
    Write-Host 'Done: four secrets added.'
} else {
    Write-Host 'GitHub CLI not set up here, so we''ll add the four secrets by hand.'
    Start-Process "https://github.com/$Repo/settings/secrets/actions/new"
    foreach ($name in $secrets.Keys) {
        Set-Clipboard -Value $secrets[$name]
        Read-Host "In the browser: Name = $name, paste into Secret (Ctrl+V), click Add secret, then 'New repository secret' again. Press Enter here when done"
    }
    Set-Clipboard -Value ' '
}

Write-Host "`n== All set" -ForegroundColor Green
Write-Host "Back up $Key and its password (in android\key.properties) somewhere safe, such as a password manager."
Write-Host 'GitHub''s next build will be signed with this key.'
