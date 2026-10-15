# Decoupe les 6 icones de la planche (interieur sombre, sans le cadre
# verdatre), les reduit en 64x64 et ecrit des TGA 32 bits (origine en haut)
# plus un apercu a 64 et 22 pixels.
Add-Type -AssemblyName System.Drawing
$dir = $PSScriptRoot
$sheet = [System.Drawing.Bitmap]::FromFile((Join-Path $dir "icons-sheet.jpg"))
$xs = @(145, 515, 884); $ys = @(126, 484); $side = 236; $inset = 3
$names = @("coin", "chest", "die", "tag", "crown", "crystal")

function Resize($img, $size) {
    $out = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    $g.Dispose()
    return $out
}

function WriteTga($bmp, $path) {
    $w = $bmp.Width; $h = $bmp.Height
    $bytes = New-Object byte[] (18 + $w * $h * 4)
    $bytes[2] = 2
    $bytes[12] = $w -band 255; $bytes[13] = $w -shr 8
    $bytes[14] = $h -band 255; $bytes[15] = $h -shr 8
    $bytes[16] = 32; $bytes[17] = 0x28
    $i = 18
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $bmp.GetPixel($x, $y)
            $bytes[$i] = $c.B; $bytes[$i + 1] = $c.G; $bytes[$i + 2] = $c.R; $bytes[$i + 3] = 255
            $i += 4
        }
    }
    [System.IO.File]::WriteAllBytes($path, $bytes)
}

# apercu : chaque icone a 64 px (x2) et a 22 px (x2), sur fond gris
$preview = New-Object System.Drawing.Bitmap((6 * 150), 190)
$pg = [System.Drawing.Graphics]::FromImage($preview)
$pg.Clear([System.Drawing.Color]::FromArgb(40, 40, 46))
$pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$pg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

for ($n = 0; $n -lt 6; $n++) {
    $c = $n % 3; $r = [math]::Floor($n / 3)
    $rect = New-Object System.Drawing.Rectangle(($xs[$c] + $inset), ($ys[$r] + $inset), ($side - 2 * $inset), ($side - 2 * $inset))
    $crop = $sheet.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $i64 = Resize $crop 64
    $i22 = Resize $crop 22
    $i64.Save((Join-Path $dir ("icon-" + $names[$n] + ".png")), [System.Drawing.Imaging.ImageFormat]::Png)
    WriteTga $i64 (Join-Path $dir ("icon-" + $names[$n] + ".tga"))
    $pg.DrawImage($i64, (New-Object System.Drawing.Rectangle(($n * 150 + 11), 10, 128, 128)))
    $pg.DrawImage($i22, (New-Object System.Drawing.Rectangle(($n * 150 + 53), 146, 44, 44)))
    $crop.Dispose(); $i64.Dispose(); $i22.Dispose()
}
$pg.Dispose()
$preview.Save((Join-Path $dir "icons-preview.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$preview.Dispose(); $sheet.Dispose()
"ok"
