param(
    [switch]$Debug,
    [string]$ReleaseTag = ""
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

if ($ReleaseTag -ne "" -and $ReleaseTag -cnotmatch '^v[0-9]{1,6}\.[0-9]{1,6}\.[0-9]{1,6}(-playtest\.[0-9]{8}\.[0-9]{1,6})?\z') {
    throw "ReleaseTag must be a Windows playtest tag or stable vX.Y.Z tag"
}
$identity = Join-Path $project "src\data\build_version.json"
$originalIdentity = [System.IO.File]::ReadAllBytes($identity)
try {
    $stamp = @{ release_tag = $ReleaseTag } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($identity, $stamp, [System.Text.UTF8Encoding]::new($false))
    & $engine --headless --path $project --import | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Import failed with exit code $LASTEXITCODE" }
    & $engine --headless --path $project $mode $preset $out
    if ($LASTEXITCODE -ne 0) { throw "Export failed with exit code $LASTEXITCODE" }
} finally {
    [System.IO.File]::WriteAllBytes($identity, $originalIdentity)
}
if ($ReleaseTag -eq "") { Write-Host "Development build: pass -ReleaseTag for a published playtest's update checks." }
Write-Host "Built: $out"
