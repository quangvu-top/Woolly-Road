# Side-by-side crop of the same Figma-px region: Figma frame (886 wide) | game capture (scaled to 886 wide).
# A grid line every 50 Figma px (labels every 100) so positions can be read straight off.
# usage (from the project root): tools/crop.ps1 -id S12 -x 0 -y 300 -w 886 -h 700 [-figma dir] [-game build/flow_shots] [-out build/cmp/crop.png]
param([string]$id, [int]$x = 0, [int]$y = 0, [int]$w = 886, [int]$h = 600,
	[string]$figma = "$env:TEMP\..\..\Local\Temp\claude\6ce7371ac3362d3b\f08fc99f-4528-4c31-b59d-3e8b0a44dd53\scratchpad\full",
	[string]$game = "build/flow_shots", [string]$out = "")
Add-Type -AssemblyName System.Drawing
if (-not $out) { $out = "build/cmp/crop_$id.png" }; $out = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $out))
$fp = Join-Path $figma "$id.png"
$gp = (Get-ChildItem $game -Filter "$id*.png" | Where-Object { $_.BaseName -eq $id -or $_.BaseName -like "${id}_*" } | Select-Object -First 1).FullName
$fi = [System.Drawing.Image]::FromFile((Resolve-Path $fp)); $gi = [System.Drawing.Image]::FromFile($gp)
$gap = 12
$sheet = New-Object System.Drawing.Bitmap (2 * $w + $gap), $h
$g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::Black); $g.InterpolationMode = 'HighQualityBicubic'
$g.DrawImage($fi, [System.Drawing.Rectangle]::new(0, 0, $w, $h), [System.Drawing.Rectangle]::new($x, $y, $w, $h), [System.Drawing.GraphicsUnit]::Pixel)
$k = $gi.Width / 886.0
$g.DrawImage($gi, [System.Drawing.RectangleF]::new($w + $gap, 0, $w, $h), [System.Drawing.RectangleF]::new($x * $k, $y * $k, $w * $k, $h * $k), [System.Drawing.GraphicsUnit]::Pixel)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(110, 255, 0, 255)), 1
$pen2 = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 255, 255, 0)), 1
$font = New-Object System.Drawing.Font("Consolas", 11)
foreach ($ox in 0, ($w + $gap)) {
	for ($gy = [math]::Ceiling($y / 50) * 50; $gy -lt $y + $h; $gy += 50) { $p = if ($gy % 100 -eq 0) { $pen2 } else { $pen }; $g.DrawLine($p, $ox, $gy - $y, $ox + $w, $gy - $y); if ($gy % 100 -eq 0) { $g.DrawString("$gy", $font, [System.Drawing.Brushes]::Yellow, $ox + 2, $gy - $y + 1) } }
	for ($gx = [math]::Ceiling($x / 50) * 50; $gx -lt $x + $w; $gx += 50) { $p = if ($gx % 100 -eq 0) { $pen2 } else { $pen }; $g.DrawLine($p, $ox + $gx - $x, 0, $ox + $gx - $x, $h); if ($gx % 100 -eq 0) { $g.DrawString("$gx", $font, [System.Drawing.Brushes]::Yellow, $ox + $gx - $x + 2, 2) } }
}
$g.Dispose(); $sheet.Save($out); $sheet.Dispose(); $fi.Dispose(); $gi.Dispose(); "saved $out"

