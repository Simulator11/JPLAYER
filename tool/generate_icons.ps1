# Generates the legacy launcher PNGs used on Android 7.x and below.
# Adaptive icons (Android 8+) are defined in res/mipmap-anydpi-v26.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$res = Join-Path $root "android\app\src\main\res"
$densities = @{ "mdpi" = 48; "hdpi" = 72; "xhdpi" = 96; "xxhdpi" = 144; "xxxhdpi" = 192 }

function New-JPlayerIcon {
    param([int]$Size, [string]$OutPath, [bool]$Round)

    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $dark = [System.Drawing.Color]::FromArgb(255, 7, 19, 31)
    if ($Round) {
        $darkBrush = New-Object System.Drawing.SolidBrush($dark)
        $graphics.FillEllipse($darkBrush, 0, 0, $Size - 1, $Size - 1)
        $darkBrush.Dispose()
    } else {
        $graphics.Clear($dark)
    }

    $pad = [int]($Size * 0.17)
    $diameter = $Size - (2 * $pad)
    $rect = New-Object System.Drawing.Rectangle($pad, $pad, $diameter, $diameter)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(255, 125, 211, 252),
        [System.Drawing.Color]::FromArgb(255, 14, 165, 233),
        [single]45
    )
    $graphics.FillEllipse($brush, $rect)
    $brush.Dispose()

    $cx = [single]($Size / 2)
    $cy = [single]($Size / 2)
    $r = [single]($Size * 0.20)
    $points = @(
        (New-Object System.Drawing.PointF([single]($cx - $r * 0.55), [single]($cy - $r))),
        (New-Object System.Drawing.PointF([single]($cx + $r * 0.95), $cy)),
        (New-Object System.Drawing.PointF([single]($cx - $r * 0.55), [single]($cy + $r)))
    )
    $playBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 5, 40, 60))
    $graphics.FillPolygon($playBrush, $points)
    $playBrush.Dispose()

    $graphics.Dispose()
    $bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

foreach ($density in $densities.Keys) {
    $dir = Join-Path $res ("mipmap-" + $density)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $size = $densities[$density]
    New-JPlayerIcon -Size $size -OutPath (Join-Path $dir "ic_launcher.png") -Round $false
    New-JPlayerIcon -Size $size -OutPath (Join-Path $dir "ic_launcher_round.png") -Round $true
}

Write-Host "JPlayer launcher icons generated."
