Add-Type -AssemblyName System.Drawing
$sourcePath = "C:\Users\harsh\AndroidStudioProjects\krishibhandar\assets\logo.png"
$destPath = "C:\Users\harsh\AndroidStudioProjects\krishibhandar\assets\logo_native_splash.png"

$srcImg = [System.Drawing.Image]::FromFile($sourcePath)
$canvasSize = 1080
$bmp = New-Object System.Drawing.Bitmap($canvasSize, $canvasSize)
$g = [System.Drawing.Graphics]::FromImage($bmp)

# Set high quality settings
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Calculate target size (e.g. 66% of canvas to fit in safe zone)
$targetWidth = $canvasSize * 0.66
$targetHeight = ($srcImg.Height / $srcImg.Width) * $targetWidth

if ($targetHeight -gt ($canvasSize * 0.66)) {
    $targetHeight = $canvasSize * 0.66
    $targetWidth = ($srcImg.Width / $srcImg.Height) * $targetHeight
}

$posX = ($canvasSize - $targetWidth) / 2
$posY = ($canvasSize - $targetHeight) / 2

$g.Clear([System.Drawing.Color]::Transparent)
$g.DrawImage($srcImg, $posX, $posY, $targetWidth, $targetHeight)

$bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()
$srcImg.Dispose()

Write-Output "Created $destPath with dimensions $($bmp.Width)x$($bmp.Height)"
