Add-Type -AssemblyName System.Drawing

# Android 12+ splash icon: bake the white disc into the image instead of
# using icon_background_color, whose shape is OEM-dependent (renders as a
# square on some devices).
function New-CircleIcon([string]$srcPath, [string]$dstPath, [int]$diameter) {
  $src = New-Object System.Drawing.Bitmap($srcPath)
  [int]$w = $src.Width
  [int]$h = $src.Height
  $out = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($out)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  [int]$x = [int](($w - $diameter) / 2)
  [int]$y = [int](($h - $diameter) / 2)
  $g.FillEllipse([System.Drawing.Brushes]::White, $x, $y, $diameter, $diameter)
  $g.DrawImage($src, 0, 0, $w, $h)
  $g.Dispose()
  $out.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
  $src.Dispose()
  Write-Output "saved $dstPath"
}

$dir = 'D:\Users\ChadokZ\Documents\Flutter_Projects\inventory_app\assets\branding'
New-CircleIcon "$dir\app_icon_foreground.png" "$dir\splash_icon.png" 760
