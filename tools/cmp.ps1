# Figma vs game, one row per screen: Figma | Game | 50/50 overlay | abs diff (x3).
# Also prints mean luminance of both and of 4 bands (top bar, upper, middle, lower) so brightness gaps show as numbers.
# usage (from the project root): tools/cmp.ps1 -figma <dir of S01.png...> -game build/flow_shots -out build/cmp -ids S02,S03
param([string]$figma, [string]$game = "build/flow_shots", [string]$out = "build/cmp", [string]$ids = "")
Add-Type -AssemblyName System.Drawing
if (-not ("Cmp" -as [type])) {
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class Cmp {
  public static Bitmap Fit(Image src, int w, int h) {
    var b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(b)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic; g.DrawImage(src, 0, 0, w, h); }
    return b;
  }
  static byte[] Bytes(Bitmap b) {
    var d = b.LockBits(new Rectangle(0,0,b.Width,b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var a = new byte[d.Stride*b.Height]; Marshal.Copy(d.Scan0, a, 0, a.Length); b.UnlockBits(d); return a;
  }
  static Bitmap FromBytes(byte[] a, int w, int h) {
    var b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    var d = b.LockBits(new Rectangle(0,0,w,h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    Marshal.Copy(a, 0, d.Scan0, a.Length); b.UnlockBits(d); return b;
  }
  public static Bitmap Blend(Bitmap x, Bitmap y) {
    var a = Bytes(x); var c = Bytes(y); var r = new byte[a.Length];
    for (int i = 0; i < a.Length; i += 4) { r[i]=(byte)((a[i]+c[i])/2); r[i+1]=(byte)((a[i+1]+c[i+1])/2); r[i+2]=(byte)((a[i+2]+c[i+2])/2); r[i+3]=255; }
    return FromBytes(r, x.Width, x.Height);
  }
  public static Bitmap Diff(Bitmap x, Bitmap y) {
    var a = Bytes(x); var c = Bytes(y); var r = new byte[a.Length];
    for (int i = 0; i < a.Length; i += 4) for (int k = 0; k < 3; k++) r[i+k] = (byte)Math.Min(255, 3*Math.Abs(a[i+k]-c[i+k]));
    for (int i = 3; i < a.Length; i += 4) r[i] = 255;
    return FromBytes(r, x.Width, x.Height);
  }
  // mean luminance (0-255) of rows y0..y1
  public static double Lum(Bitmap x, int y0, int y1) {
    var a = Bytes(x); int w = x.Width; double s = 0; long n = 0;
    for (int y = y0; y < y1; y++) for (int px = 0; px < w; px++) { int i = (y*w+px)*4; s += 0.0722*a[i] + 0.7152*a[i+1] + 0.2126*a[i+2]; n++; }
    return s / n;
  }
}
"@
}
New-Item -ItemType Directory -Force $out | Out-Null
$W = 443; $H = 960; $gap = 8
$games = Get-ChildItem $game -Filter "S*.png"
$want = if ($ids) { $ids -split ',' } else { (Get-ChildItem $figma -Filter "S*.png").BaseName }
$font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
foreach ($id in $want) {
  $fp = Join-Path $figma "$id.png"
  $gp = $games | Where-Object { $_.BaseName -eq $id -or $_.BaseName -like "${id}_*" } | Select-Object -First 1
  if (-not (Test-Path $fp) -or -not $gp) { "skip $id"; continue }
  $fi = [System.Drawing.Image]::FromFile((Resolve-Path $fp)); $gi = [System.Drawing.Image]::FromFile($gp.FullName)
  $fh = [int]($fi.Height * $W / $fi.Width); if ($fh -gt $H) { $fh = $H }   # long Shop frame: top part only
  $fb = New-Object System.Drawing.Bitmap $W, $H
  $gg = [System.Drawing.Graphics]::FromImage($fb); $gg.InterpolationMode = 'HighQualityBicubic'
  $gg.Clear([System.Drawing.Color]::Black)
  $gg.DrawImage($fi, [System.Drawing.Rectangle]::new(0, 0, $W, $H), [System.Drawing.Rectangle]::new(0, 0, $fi.Width, [int]($fi.Width * $H / $W)), [System.Drawing.GraphicsUnit]::Pixel); $gg.Dispose()
  $gb = [Cmp]::Fit($gi, $W, $H)
  $bl = [Cmp]::Blend($fb, $gb); $df = [Cmp]::Diff($fb, $gb)
  $sheet = New-Object System.Drawing.Bitmap (4 * $W + 3 * $gap), ($H + 34)
  $g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::FromArgb(255, 24, 24, 24))
  $x = 0; $names = "Figma", "Game", "Overlay", "Diff x3"
  foreach ($im in $fb, $gb, $bl, $df) { $g.DrawImage($im, $x, 34); $x += $W + $gap }
  for ($k = 0; $k -lt 4; $k++) { $g.DrawString("$id  $($names[$k])", $font, [System.Drawing.Brushes]::White, $k * ($W + $gap) + 6, 4) }
  # light grid every 10% so offsets can be read off
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(70, 255, 0, 255)), 1
  for ($k = 0; $k -lt 4; $k++) { for ($t = 1; $t -lt 10; $t++) { $yy = 34 + [int]($H * $t / 10); $g.DrawLine($pen, $k * ($W + $gap), $yy, $k * ($W + $gap) + $W, $yy) } }
  $g.Dispose(); $sheet.Save((Join-Path $out "$id.png")); $sheet.Dispose()
  $bands = @(0, 96), @(96, 384), @(384, 672), @(672, 960)
  $lf = [Cmp]::Lum($fb, 0, $H); $lg = [Cmp]::Lum($gb, 0, $H)
  $bs = ($bands | ForEach-Object { "{0,4:N0}/{1,-4:N0}" -f [Cmp]::Lum($fb, $_[0], $_[1]), [Cmp]::Lum($gb, $_[0], $_[1]) }) -join ' '
  "{0,-5} lum figma {1,5:N1} game {2,5:N1} d {3,6:N1} | bands f/g: {4}" -f $id, $lf, $lg, ($lg - $lf), $bs
  foreach ($im in $fi, $gi, $fb, $gb, $bl, $df) { $im.Dispose() }
}
