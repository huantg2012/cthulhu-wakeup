Add-Type -AssemblyName System.Drawing
$studyRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../docs/game-state'))
$studyModel = Get-Content -LiteralPath (Join-Path $studyRoot 'ui-density-overview.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Get-StudyColor($value) {
    if (!$value -or $value -eq 'none') { return [Drawing.Color]::Transparent }
    return [Drawing.ColorTranslator]::FromHtml($value)
}
$bmp = New-Object Drawing.Bitmap ([int]$studyModel.width),([int]$studyModel.height)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$overflows = @()
foreach ($el in $studyModel.elements) {
    $brush = New-Object Drawing.SolidBrush (Get-StudyColor $el.fill)
    $width = 1.0
    if ($el.strokeWidth) { $width = [single]$el.strokeWidth }
    $pen = New-Object Drawing.Pen (Get-StudyColor $el.stroke),$width
    switch ($el.type) {
        'rect' {
            $g.FillRectangle($brush,[single]$el.x,[single]$el.y,[single]$el.w,[single]$el.h)
            $g.DrawRectangle($pen,[single]$el.x,[single]$el.y,[single]$el.w,[single]$el.h)
        }
        'line' { $g.DrawLine($pen,[single]$el.x1,[single]$el.y1,[single]$el.x2,[single]$el.y2) }
        'text' {
            $style = [Drawing.FontStyle]::Regular
            if ($el.weight -eq 600) { $style = [Drawing.FontStyle]::Bold }
            $font = New-Object Drawing.Font 'Microsoft YaHei',([single]$el.size),$style,([Drawing.GraphicsUnit]::Pixel)
            $fmt = [Drawing.StringFormat]::GenericTypographic.Clone()
            $fmt.FormatFlags = [Drawing.StringFormatFlags]::NoWrap
            $ascent = $font.FontFamily.GetCellAscent($style) / $font.FontFamily.GetEmHeight($style) * $el.size
            $x = [single]$el.x
            $measured = $g.MeasureString($el.text,$font,10000,$fmt).Width
            if ($el.anchor -eq 'middle') { $x -= $measured/2 }
            if ($el.anchor -eq 'end') { $x -= $measured }
            if ($x -lt 0 -or ($x+$measured) -gt 1920) { $overflows += $el.text }
            $g.DrawString($el.text,$font,$brush,$x,[single]($el.y-$ascent),$fmt)
            $font.Dispose(); $fmt.Dispose()
        }
    }
    $brush.Dispose(); $pen.Dispose()
}
$path = Join-Path $studyRoot 'ui-density-overview.png'
$bmp.Save($path,[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
if ($overflows.Count -gt 0) { throw "Text outside canvas: $overflows" }
Write-Output $path
