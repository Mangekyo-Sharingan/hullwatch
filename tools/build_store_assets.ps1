param(
    [string]$OutDir = (Join-Path $PSScriptRoot "..\docs\store")
)

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function New-Capsule {
    param([int]$Width, [int]$Height, [string]$Path, [int]$TitleSize)
    $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(26, 28, 30),
        [System.Drawing.Color]::FromArgb(9, 11, 13),
        45
    )
    $g.FillRectangle($brush, $rect)
    $teal = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(46, 68, 72), 2)
    for ($i = 0; $i -lt 14; $i++) {
        $x = [int]($Width * $i / 14)
        $g.DrawLine($teal, $x, 0, $x, $Height)
    }
    $bar = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(214, 150, 50))
    $g.FillRectangle($bar, 0, [int]($Height * 0.74), $Width, [int]($Height * 0.03))
    $titleFont = New-Object System.Drawing.Font("Segoe UI", $TitleSize, [System.Drawing.FontStyle]::Bold)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(226, 228, 224))
    $g.DrawString("HULLWATCH", $titleFont, $white, [int]($Width * 0.055), [int]($Height * 0.40))
    $tagFont = New-Object System.Drawing.Font("Segoe UI", [math]::Max([int]($TitleSize * 0.34), 10))
    $amber = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(214, 150, 50))
    $g.DrawString("entropy is the only villain", $tagFont, $amber, [int]($Width * 0.058), [int]($Height * 0.63))
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

New-Capsule 1232 706 (Join-Path $OutDir "capsule_main_1232x706.png") 64
New-Capsule 616 353 (Join-Path $OutDir "capsule_small_616x353.png") 34
New-Capsule 460 215 (Join-Path $OutDir "capsule_header_460x215.png") 26
New-Capsule 600 900 (Join-Path $OutDir "capsule_library_600x900.png") 50

Write-Host "PASS: build_store_assets"
