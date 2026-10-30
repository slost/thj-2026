<#
.SYNOPSIS
  Build a self-contained Web zip for itch.io.

.DESCRIPTION
  Mirrors the "Assemble site" step of .github/workflows/deploy.yml, so the itch
  build loads hot-swap assets from its own assets/ folder instead of the network:
    1. Export the "Web" preset (skip with -SkipExport if you already exported).
    2. Copy assets/ next to index.html (dotfiles removed).
    3. Write assets/manifest.json with tools/make_manifest.py.
    4. Zip the export folder for upload.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/pack_itch.ps1
  powershell -ExecutionPolicy Bypass -File tools/pack_itch.ps1 -SkipExport
#>
param(
    [string]$Godot = "C:\Game Dev\Godot\Godot Main\Godot.exe",
    [string]$Preset = "Web",
    [string]$OutDir = "",
    [string]$Zip = "",
    [string]$Python = "python",
    [switch]$DebugBuild,
    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot

# Default output folder: the preset's export_path folder.
if ($OutDir -eq "") {
    $line = Select-String -Path (Join-Path $ProjectDir "export_presets.cfg") -Pattern '^export_path="(.*)"' | Select-Object -First 1
    if ($null -eq $line) { throw "No export_path in export_presets.cfg. Pass -OutDir." }
    $exportPath = $line.Matches[0].Groups[1].Value
    $OutDir = Split-Path -Parent ([IO.Path]::GetFullPath((Join-Path $ProjectDir $exportPath)))
}
$OutDir = [IO.Path]::GetFullPath($OutDir)
if ($Zip -eq "") { $Zip = "$OutDir-itch.zip" }

Write-Host "Project: $ProjectDir"
Write-Host "Output:  $OutDir"

if (-not $SkipExport) {
    if (-not (Test-Path $Godot)) { throw "Godot not found at '$Godot'. Pass -Godot." }
    if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
    New-Item -ItemType Directory -Path $OutDir | Out-Null
    $mode = if ($DebugBuild) { "--export-debug" } else { "--export-release" }
    Write-Host "Exporting '$Preset' ($mode)..."
    & $Godot --headless --path $ProjectDir $mode $Preset (Join-Path $OutDir "index.html") | Out-Host
}

# Godot can exit 0 even when the export failed, so check the files.
foreach ($f in "index.html", "index.wasm", "index.pck") {
    if (-not (Test-Path (Join-Path $OutDir $f))) { throw "Missing $f in $OutDir. Export failed?" }
}

Write-Host "Copying assets..."
$assetsOut = Join-Path $OutDir "assets"
if (Test-Path $assetsOut) { Remove-Item $assetsOut -Recurse -Force }
Copy-Item (Join-Path $ProjectDir "assets") $assetsOut -Recurse
Get-ChildItem $assetsOut -Recurse -Force | Where-Object { $_.Name.StartsWith(".") } | Remove-Item -Recurse -Force

Write-Host "Writing manifest..."
& $Python (Join-Path $ProjectDir "tools\make_manifest.py") $assetsOut `
    -o (Join-Path $assetsOut "manifest.json") `
    --status (Join-Path $assetsOut "status.html")
if ($LASTEXITCODE -ne 0) { throw "make_manifest.py failed." }

Write-Host "Zipping..."
if (Test-Path $Zip) { Remove-Item $Zip -Force }
# Compress-Archive in Windows PowerShell 5 writes "\" into entry names, and
# itch.io (Linux) then extracts "assets\manifest.json" as one file name.
# .NET Framework's ZipFile.CreateFromDirectory does the same, so build the
# archive entry by entry with "/" separators.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($Zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem $OutDir -Recurse -File) {
        $entryName = $file.FullName.Substring($OutDir.Length).TrimStart("\").Replace("\", "/")
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $archive.Dispose()
}
$sizeMb = [math]::Round((Get-Item $Zip).Length / 1MB, 1)
Write-Host "Done: $Zip ($sizeMb MB). Upload it to itch as an HTML game (index.html at the zip root)."


