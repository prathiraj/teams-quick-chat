<#
.SYNOPSIS
    Build and publish a GitHub Release for TeamsQuickChat.
.EXAMPLE
    .\release.ps1 -Version 1.0.0
    .\release.ps1 -Version 1.2.0 -Draft
#>
param(
    [Parameter(Mandatory)]
    [string]$Version,
    [switch]$Draft
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

# Validate version format
if ($Version -notmatch '^\d+\.\d+(\.\d+)?$') {
    Write-Error "Version must be in format X.Y or X.Y.Z (e.g. 1.0 or 1.0.0)"
    exit 1
}

$tag = "v$Version"
$publishDir = Join-Path $repoRoot "publish"
$zipName = "TeamsQuickChat-$Version-win-x64.zip"
$zipPath = Join-Path $repoRoot $zipName
$installerName = "TeamsQuickChatSetup-$Version.exe"
$issPath = Join-Path $repoRoot "installer\TeamsQuickChat.iss"

# --- Build ---
Write-Host "==> Building TeamsQuickChat $tag (self-contained) ..." -ForegroundColor Cyan
dotnet publish $repoRoot -c Release -o $publishDir
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed"; exit 1 }

# --- Portable zip ---
Write-Host "==> Creating $zipName ..." -ForegroundColor Cyan
if (Test-Path $zipPath) { Remove-Item $zipPath }
Compress-Archive -Path "$publishDir\*" -DestinationPath $zipPath

# --- Inno Setup installer ---
$iscc = $null
$isccPaths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe"
)
foreach ($p in $isccPaths) {
    if (Test-Path $p) { $iscc = $p; break }
}

$installerPath = $null
if ($iscc) {
    Write-Host "==> Building installer with Inno Setup ..." -ForegroundColor Cyan
    & $iscc "/DAppVersion=$Version" $issPath
    if ($LASTEXITCODE -ne 0) { Write-Error "Installer build failed"; exit 1 }

    $installerPath = Join-Path $repoRoot "installer\Output\$installerName"
    if (-not (Test-Path $installerPath)) {
        Write-Warning "Installer exe not found at expected path: $installerPath"
        $installerPath = $null
    }
} else {
    Write-Warning "Inno Setup not found. Skipping installer build (zip-only release)."
    Write-Warning "Install Inno Setup from https://jrsoftware.org/isinfo.php to build installers."
}

# --- Tag and release ---
Write-Host "==> Tagging $tag ..." -ForegroundColor Cyan
git tag $tag 2>$null
git push origin $tag 2>&1

Write-Host "==> Creating GitHub Release ..." -ForegroundColor Cyan
$assets = @($zipPath)
if ($installerPath) { $assets += $installerPath }

$ghArgs = @("release", "create", $tag)
$ghArgs += $assets
$ghArgs += @("--title", "TeamsQuickChat $tag", "--generate-notes")
if ($Draft) { $ghArgs += "--draft" }
& gh @ghArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "==> Release $tag published!" -ForegroundColor Green
} else {
    Write-Error "Release creation failed"
    exit 1
}

# --- Cleanup ---
Remove-Item $publishDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -ErrorAction SilentlyContinue
if ($installerPath) {
    Remove-Item (Join-Path $repoRoot "installer\Output") -Recurse -Force -ErrorAction SilentlyContinue
}
