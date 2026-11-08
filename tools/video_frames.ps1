# Frames from a video without ffmpeg (Windows.Media.Editing), e.g. to study a reference gameplay recording:
#   powershell -File tools/video_frames.ps1 -Path clip.mp4 -OutDir frames -Step 0.5 -Width 360 [-Start 2] [-End 8]
param([string]$Path, [string]$OutDir, [double]$Step = 2.0, [int]$Width = 360, [double]$Start = 0, [double]$End = 9999)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$t) { $m = $asTask.MakeGenericMethod($t); $task = $m.Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
$null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
$null = [Windows.Media.Editing.MediaClip,Windows.Media.Editing,ContentType=WindowsRuntime]
$null = [Windows.Media.Editing.MediaComposition,Windows.Media.Editing,ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
$clip = Await ([Windows.Media.Editing.MediaClip]::CreateFromFileAsync($file)) ([Windows.Media.Editing.MediaClip])
$comp = New-Object Windows.Media.Editing.MediaComposition
[System.Collections.Generic.ICollection[Windows.Media.Editing.MediaClip]].GetMethod("Add").Invoke($comp.Clips, @($clip))
$props = $clip.GetVideoEncodingProperties()
$dur = $clip.OriginalDuration.TotalSeconds
Write-Output ("Duration {0:N1}s, {1}x{2}" -f $dur, $props.Width, $props.Height)
$h = [int]($Width * $props.Height / $props.Width)
$i = 0
for ($t = $Start; $t -lt [Math]::Min($dur,$End); $t += $Step) {
  $ts = [TimeSpan]::FromSeconds($t)
  $img = Await ($comp.GetThumbnailAsync($ts, $Width, $h, [Windows.Media.Editing.VideoFramePrecision]::NearestFrame)) ([Windows.Graphics.Imaging.ImageStream,Windows.Graphics,ContentType=WindowsRuntime])
  $s = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($img)
  $out = Join-Path $OutDir ("f_{0:D3}_{1:000.0}s.jpg" -f $i, $t)
  $fs = [System.IO.File]::Create($out); $s.CopyTo($fs); $fs.Close(); $s.Close()
  $i++
}
Write-Output "Frames: $i"
