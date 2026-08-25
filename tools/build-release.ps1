param(
    [string]$Version = "1.5.2"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot "src"
$distRoot = Join-Path $repoRoot "dist"
$stagingRoot = Join-Path $distRoot "release-staging"
$modRoot = Join-Path $stagingRoot "ElixirCraftB42"
$archivePath = Join-Path $distRoot "ElixirCraftB42-v$Version.zip"

if (Test-Path $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

if (Test-Path $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

New-Item -ItemType Directory -Path $modRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot "42") -Destination $modRoot -Recurse
Copy-Item -LiteralPath (Join-Path $sourceRoot "common") -Destination $modRoot -Recurse
Copy-Item -LiteralPath (Join-Path $sourceRoot "README.txt") -Destination $modRoot

Compress-Archive -LiteralPath $modRoot -DestinationPath $archivePath -CompressionLevel Optimal
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

Write-Host "Created $archivePath"

