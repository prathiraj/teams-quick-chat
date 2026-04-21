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
$zipName = "TeamsQuickChat-$Version-win-x64.zip"
$publishDir = Join-Path $repoRoot "publish"
$zipPath = Join-Path $repoRoot $zipName

Write-Host "==> Building TeamsQuickChat $tag ..." -ForegroundColor Cyan
dotnet publish $repoRoot -c Release -o $publishDir
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed"; exit 1 }

Write-Host "==> Creating $zipName ..." -ForegroundColor Cyan
if (Test-Path $zipPath) { Remove-Item $zipPath }
Compress-Archive -Path "$publishDir\*" -DestinationPath $zipPath

Write-Host "==> Tagging $tag ..." -ForegroundColor Cyan
git tag $tag 2>$null
git push origin $tag 2>&1

Write-Host "==> Creating GitHub Release ..." -ForegroundColor Cyan
$ghArgs = @("release", "create", $tag, $zipPath, "--title", "TeamsQuickChat $tag", "--generate-notes")
if ($Draft) { $ghArgs += "--draft" }
& gh @ghArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "==> Release $tag published!" -ForegroundColor Green
} else {
    Write-Error "Release creation failed"
    exit 1
}

# Cleanup
Remove-Item $publishDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -ErrorAction SilentlyContinue
