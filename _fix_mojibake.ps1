$path = 'e:\Imam\Mohaffez_app\lib\screens\mohaffez_profile_screen.dart'
$text = Get-Content -Raw -Path $path

$pattern = "('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")"

$cp1252 = [System.Text.Encoding]::GetEncoding(
  1252,
  [System.Text.EncoderExceptionFallback]::new(),
  [System.Text.DecoderExceptionFallback]::new()
)
$latin1 = [System.Text.Encoding]::GetEncoding(
  28591,
  [System.Text.EncoderExceptionFallback]::new(),
  [System.Text.DecoderExceptionFallback]::new()
)
$utf8 = [System.Text.Encoding]::UTF8
$markers = @('Ã','Ø','Ù','Â','â','ƒ','Ë','‚')

$newText = [System.Text.RegularExpressions.Regex]::Replace($text, $pattern, {
  param($m)
  $token = $m.Value
  $q = $token.Substring(0,1)
  $body = $token.Substring(1, $token.Length - 2)

  $fixed = $body
  for($i = 0; $i -lt 10; $i++) {
    $hasMarker = $false
    foreach($mk in $markers) {
      if($fixed.Contains($mk)) { $hasMarker = $true; break }
    }
    if(-not $hasMarker) { break }

    $progressed = $false
    foreach($enc in @($cp1252, $latin1)) {
      try {
        $bytes = $enc.GetBytes($fixed)
        $candidate = $utf8.GetString($bytes)
        if($candidate -ne $fixed) {
          $fixed = $candidate
          $progressed = $true
          break
        }
      } catch {
      }
    }

    if(-not $progressed) { break }
  }

  return "$q$fixed$q"
}, 'Singleline')

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $newText, $utf8NoBom)
Write-Output 'updated'
