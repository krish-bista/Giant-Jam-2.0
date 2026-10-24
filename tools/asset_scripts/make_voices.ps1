# Generates raw voice lines with Windows' built-in offline voices (David / Zira).
# Usage: powershell -File make_voices.ps1 -Lines voice_lines.json -OutDir <raw folder>
param([string]$Lines, [string]$OutDir)
Add-Type -AssemblyName System.Speech
New-Item -ItemType Directory -Force $OutDir | Out-Null
$styles = @{
  "you"      = @("Microsoft David Desktop", "-5%",  "-4%");
  "stranger" = @("Microsoft David Desktop", "-18%", "-12%");
  "system"   = @("Microsoft Zira Desktop",  "-4%",  "+6%");
  "terminal" = @("Microsoft Zira Desktop",  "-15%", "-6%");
  "echo"     = @("Microsoft Zira Desktop",  "-22%", "-10%");
  "hypnotic" = @("Microsoft Zira Desktop",  "-12%", "+28%");
  "warden"   = @("Microsoft David Desktop", "-12%", "-30%");
  "sentinel" = @("Microsoft Zira Desktop",  "-15%", "-22%");
  "evil"     = @("Microsoft David Desktop", "-8%",  "-14%");
  "narrator" = @("Microsoft Zira Desktop",  "-20%", "-6%");
  "elder"    = @("Microsoft David Desktop", "-22%", "-20%");
  "reflection" = @("Microsoft David Desktop", "-10%", "+4%");
}
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$md5 = [System.Security.Cryptography.MD5]::Create()
$items = Get-Content $Lines -Raw -Encoding UTF8 | ConvertFrom-Json
$count = 0
foreach ($it in $items) {
  $st = $styles[$it.speaker]
  $hash = -join ($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($it.text)) | ForEach-Object { $_.ToString("x2") })
  $name = "{0}_{1}.wav" -f $it.speaker, $hash.Substring(0, 10)
  $spoken = if ($it.say) { $it.say } else { $it.text }
  $spoken = [System.Security.SecurityElement]::Escape($spoken)
  $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $s.SelectVoice($st[0])
  $s.SetOutputToWaveFile((Join-Path $OutDir $name), $fmt)
  $ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><prosody rate='$($st[1])' pitch='$($st[2])'>$spoken</prosody></speak>"
  $s.SpeakSsml($ssml)
  $s.Dispose()
  $count++
}
"generated $count lines"
