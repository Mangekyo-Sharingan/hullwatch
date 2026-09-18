param(
    [switch]$Debug
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$engine = Join-Path $root "Engine\Godot_v4.7.2-stable_win64_console.exe"
$project = Join-Path $root "game"
$outDir = Join-Path $root "build\windows"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$preset = "Windows Desktop"
$mode = "--export-release"
$name = "Hullwatch.exe"
if ($Debug) {
    $preset = "Windows Desktop (Debug)"
    $mode = "--export-debug"
    $name = "Hullwatch-Debug.exe"
}
$out = Join-Path $outDir $name

& $engine --headless --path $project --import | Out-Null
& $engine --headless --path $project $mode $preset $out
if ($LASTEXITCODE -ne 0) {
    throw "Export failed with exit code $LASTEXITCODE"
}
Write-Host "Built: $out"
