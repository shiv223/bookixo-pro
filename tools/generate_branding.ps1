$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $root 'assets\branding\icon.png'))

function Write-BrandImage {
    param(
        [string]$RelativePath,
        [int]$Size,
        [int]$LogoSize,
        [System.Drawing.Color]$Background = [System.Drawing.Color]::Transparent
    )

    $path = Join-Path $root $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
    $pixelFormat = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    if ($Background.A -eq 255) {
        $pixelFormat = [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    }
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, $pixelFormat)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear($Background)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $offset = [int](($Size - $LogoSize) / 2)
        $graphics.DrawImage($source, $offset, $offset, $LogoSize, $LogoSize)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    $densities = @(
        @{ Name = 'mdpi'; Scale = 1 },
        @{ Name = 'hdpi'; Scale = 1.5 },
        @{ Name = 'xhdpi'; Scale = 2 },
        @{ Name = 'xxhdpi'; Scale = 3 },
        @{ Name = 'xxxhdpi'; Scale = 4 }
    )
    foreach ($density in $densities) {
        $iconSize = [int](48 * $density.Scale)
        Write-BrandImage "android\app\src\main\res\mipmap-$($density.Name)\ic_launcher.png" $iconSize $iconSize
        $launchSize = [int](120 * $density.Scale)
        Write-BrandImage "android\app\src\main\res\drawable-$($density.Name)\launch_logo.png" $launchSize $launchSize
    }

    # Keep the complete square logo inside Android 12's circular splash mask.
    Write-BrandImage 'android\app\src\main\res\drawable-nodpi\launch_logo_android12.png' 1152 528

    $catalog = 'ios\Runner\Assets.xcassets'
    $icons = Get-Content (Join-Path $root "$catalog\AppIcon.appiconset\Contents.json") -Raw | ConvertFrom-Json
    foreach ($icon in ($icons.images | Sort-Object filename -Unique)) {
        $size = [int]([double]($icon.size -split 'x')[0] * [double]($icon.scale -replace 'x', ''))
        # App Store icons must be opaque; fill the source's transparent corners.
        Write-BrandImage "$catalog\AppIcon.appiconset\$($icon.filename)" $size $size ([System.Drawing.Color]::FromArgb(26, 115, 232))
    }
    Write-BrandImage "$catalog\LaunchImage.imageset\LaunchImage.png" 120 120
    Write-BrandImage "$catalog\LaunchImage.imageset\LaunchImage@2x.png" 240 240
    Write-BrandImage "$catalog\LaunchImage.imageset\LaunchImage@3x.png" 360 360
    Write-Output 'Generated Android and iOS launcher icons and launch images from assets\branding\icon.png.'
}
finally {
    $source.Dispose()
}
