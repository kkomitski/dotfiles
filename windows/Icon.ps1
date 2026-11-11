function New-TerminalIcon([string]$png, [string]$ico) {
# Include native small ICO images for Start/search icon extractors plus a 256px PNG.
$original = [Drawing.Image]::FromFile($png)
$images = @()
$sizes = @(16,32,48,256)
foreach ($size in $sizes) {
    $bitmap = New-Object Drawing.Bitmap $size,$size
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($original,0,0,$size,$size)
    $stream = New-Object IO.MemoryStream
    if ($size -eq 256) {
        $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
        $images += ,$stream.ToArray()
    } else {
        $handle = $bitmap.GetHicon()
        $icon = [Drawing.Icon]::FromHandle($handle)
        $icon.Save($stream)
        $raw = $stream.ToArray()
        $length = [BitConverter]::ToUInt32($raw,14)
        $offset = [BitConverter]::ToUInt32($raw,18)
        $data = New-Object byte[] $length
        [Array]::Copy($raw,$offset,$data,0,$length)
        $images += ,$data
        $icon.Dispose()
    }
    $stream.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$original.Dispose()
$writer = New-Object IO.BinaryWriter ([IO.File]::Create($ico))
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i=0; $i -lt $sizes.Count; $i++) {
    $dimension = if ($sizes[$i] -eq 256) {0} else {$sizes[$i]}
    $writer.Write([byte]$dimension); $writer.Write([byte]$dimension); $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([uint16]1); $writer.Write([uint16]32)
    $writer.Write([uint32]$images[$i].Length); $writer.Write([uint32]$offset)
    $offset += $images[$i].Length
}
foreach ($data in $images) { $writer.Write([byte[]]$data) }
$writer.Dispose()
}
