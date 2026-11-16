# Local server (localhost only) for job-log.html: mark offers as applied, discard them (or restore them) and save notes in data\job-log.md.
# Started by build-log.ps1 -Open. It does NOT create history versions: only the job-search skill does.
# Stop it with scripts\stop-server.ps1. NOTE: this file must be plain ASCII.
param([int]$Port = 8765)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dataDir = Join-Path $root 'data'
$mdPath = Join-Path $dataDir 'job-log.md'
$htmlPath = Join-Path $dataDir 'job-log.html'
$genPath = Join-Path $PSScriptRoot 'build-log.ps1'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$token = [guid]::NewGuid().ToString('N')
$memo = [char]::ConvertFromUtf32(0x1F4DD)

function Get-Cells([string]$line) { return @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }) }
function Get-Kind([string]$t) {
  if ($t -match 'notes') { return 'notes' }
  if ($t -match 'To apply') { return 'apply' }
  if ($t -match 'Unsure') { return 'unsure' }
  if ($t -match 'Unverified') { return 'unverified' }
  if ($t -match 'Applied') { return 'applied' }
  if ($t -match 'Repl') { return 'replies' }
  if ($t -match 'Discarded') { return 'discarded' }
  return 'other'
}
function Load-Lines {
  $al = New-Object System.Collections.ArrayList
  $al.AddRange([string[]]@(Get-Content -LiteralPath $mdPath -Encoding UTF8))
  return ,$al
}

# Table sections: Title, Kind, HdrIdx, SepIdx, Rows (indexes of data rows), Headers
function Get-Sections($lines) {
  $secs = New-Object System.Collections.ArrayList
  $cur = $null
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match '^## (.+)$') {
      $cur = @{ Title = $Matches[1]; Kind = (Get-Kind $Matches[1]); HdrIdx = -1; SepIdx = -1; Rows = (New-Object System.Collections.ArrayList); Headers = @() }
      [void]$secs.Add($cur)
      continue
    }
    if ($l.StartsWith('|')) {
      if ($null -eq $cur) {
        $cur = @{ Title = ''; Kind = 'summary'; HdrIdx = -1; SepIdx = -1; Rows = (New-Object System.Collections.ArrayList); Headers = @() }
        [void]$secs.Add($cur)
      }
      if ($cur.HdrIdx -lt 0) { $cur.HdrIdx = $i; $cur.Headers = Get-Cells $l }
      elseif ($cur.SepIdx -lt 0) { $cur.SepIdx = $i }
      else { [void]$cur.Rows.Add($i) }
    }
  }
  return ,$secs
}
function Remove-Placeholders($lines, [string]$kind) {
  $secs = Get-Sections $lines
  foreach ($s in $secs) {
    if ($s.Kind -eq $kind) {
      for ($j = $s.Rows.Count - 1; $j -ge 0; $j--) {
        $idx = $s.Rows[$j]
        if ((Get-Cells $lines[$idx])[0] -like '_none*') { $lines.RemoveAt($idx) }
      }
    }
  }
}
function Add-Row($lines, [string]$kind, [string]$newLine) {
  Remove-Placeholders $lines $kind
  $secs = Get-Sections $lines
  foreach ($s in $secs) {
    if ($s.Kind -eq $kind) {
      $at = $s.SepIdx + 1
      if ($s.Rows.Count -gt 0) { $at = $s.Rows[$s.Rows.Count - 1] + 1 }
      $lines.Insert($at, $newLine)
      return
    }
  }
  throw ('Section not found: ' + $kind)
}
function Ensure-Placeholder($lines, [string]$kind, [string]$text) {
  $secs = Get-Sections $lines
  foreach ($s in $secs) {
    if ($s.Kind -eq $kind -and $s.Rows.Count -eq 0) {
      $n = $s.Headers.Count
      $lines.Insert($s.SepIdx + 1, ('| ' + $text + ' |' + (' |' * ($n - 1))))
      return
    }
  }
}
function Update-Counts($lines) {
  $secs = Get-Sections $lines
  $counts = @{}
  foreach ($s in $secs) {
    $real = 0
    foreach ($ri in $s.Rows) { if ((Get-Cells $lines[$ri])[0] -notlike '_none*') { $real++ } }
    $counts[$s.Kind] = $real
  }
  foreach ($s in $secs) {
    if ($s.Kind -eq 'summary') {
      foreach ($ri in $s.Rows) {
        $c = Get-Cells $lines[$ri]
        $k = Get-Kind $c[0]
        if (@('apply', 'unsure', 'unverified', 'applied', 'replies') -contains $k) { $lines[$ri] = '| ' + $c[0] + ' | ' + $counts[$k] + ' |' }
      }
    }
  }
}
function Update-Stamp($lines, [string]$what) {
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'Last updated:') {
      $lines[$i] = ('Last updated: ' + $stamp + ' (' + $what + ')')
      return
    }
  }
}
function Save-And-Regen($lines) {
  [System.IO.File]::WriteAllLines($mdPath, [string[]]$lines.ToArray([string]), $utf8)
  & $genPath -Refresh | Out-Null
}

function Op-Apply([string]$id) {
  $lines = Load-Lines
  $secs = Get-Sections $lines
  $found = $null
  foreach ($s in $secs) {
    if (@('apply', 'unsure', 'unverified') -contains $s.Kind) {
      foreach ($ri in $s.Rows) {
        $c = Get-Cells $lines[$ri]
        if ($c[0] -eq $id) { $found = @{ Sec = $s; Idx = $ri; Cells = $c } }
      }
    }
  }
  if ($null -eq $found) { return @{ ok = $false; error = 'That offer is no longer in To apply, Unsure or Unverified (maybe it is already applied).' } }
  $hdr = $found.Sec.Headers
  $ip = [array]::IndexOf($hdr, 'Position')
  $ie = [array]::IndexOf($hdr, 'Company')
  $pos = ''; if ($ip -ge 0) { $pos = $found.Cells[$ip] }
  $emp = ''; if ($ie -ge 0) { $emp = $found.Cells[$ie] }
  $kind = $found.Sec.Kind
  $labels = @{ apply = 'To apply'; unsure = 'Unsure'; unverified = 'Unverified' }
  $b64 = [Convert]::ToBase64String($utf8.GetBytes($lines[$found.Idx]))
  $lines.RemoveAt($found.Idx)
  Ensure-Placeholder $lines $kind '_none right now_'
  $when = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $newRow = '| ' + $id + ' | ' + $pos + ' | ' + $emp + ' | ' + $when + ' | (manual, by the user) | - | Origin: ' + $labels[$kind] + ' <!--orig:' + $kind + ':' + $b64 + '--> |'
  Add-Row $lines 'applied' $newRow
  Update-Counts $lines
  Update-Stamp $lines ('marked as applied from the web page: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}
function Op-Unapply([string]$id) {
  $lines = Load-Lines
  $secs = Get-Sections $lines
  $found = -1
  foreach ($s in $secs) {
    if ($s.Kind -eq 'applied') {
      foreach ($ri in $s.Rows) { if ((Get-Cells $lines[$ri])[0] -eq $id) { $found = $ri } }
    }
  }
  if ($found -lt 0) { return @{ ok = $false; error = 'That offer was not found in Applied.' } }
  $m = [regex]::Match($lines[$found], '<!--orig:(\w+):([A-Za-z0-9+/=]+)-->')
  if (-not $m.Success) { return @{ ok = $false; error = 'Cannot undo it: the original row was not saved (it was applied by the skill). Move it by hand in job-log.md.' } }
  $origKind = $m.Groups[1].Value
  $origLine = $utf8.GetString([Convert]::FromBase64String($m.Groups[2].Value))
  $lines.RemoveAt($found)
  Ensure-Placeholder $lines 'applied' '_none yet_'
  Add-Row $lines $origKind $origLine
  Update-Counts $lines
  Update-Stamp $lines ('applied mark removed from the web page: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}
function Adjust-Discards($lines, [int]$delta) {
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].StartsWith('|') -and $lines[$i] -match 'Discarded \| (\d+) rows \(about (\d+) offers\)') {
      $f = [int]$Matches[1] + $delta
      $o = [int]$Matches[2] + $delta
      if ($f -lt 0) { $f = 0 }
      if ($o -lt 0) { $o = 0 }
      $lines[$i] = [regex]::Replace($lines[$i], '\d+ rows \(about \d+ offers\)', ([string]$f + ' rows (about ' + [string]$o + ' offers)'))
      return
    }
  }
}
function Op-Discard([string]$id, [string]$reason) {
  $lines = Load-Lines
  $secs = Get-Sections $lines
  $found = $null
  foreach ($s in $secs) {
    if (@('apply', 'unsure', 'unverified') -contains $s.Kind) {
      foreach ($ri in $s.Rows) {
        $c = Get-Cells $lines[$ri]
        if ($c[0] -eq $id) { $found = @{ Sec = $s; Idx = $ri; Cells = $c } }
      }
    }
  }
  if ($null -eq $found) { return @{ ok = $false; error = 'That offer is no longer in To apply, Unsure or Unverified.' } }
  $hdr = $found.Sec.Headers
  $ip = [array]::IndexOf($hdr, 'Position')
  $ie = [array]::IndexOf($hdr, 'Company')
  $il = [array]::IndexOf($hdr, 'Location')
  $pos = ''; if ($ip -ge 0) { $pos = $found.Cells[$ip] }
  $emp = ''; if ($ie -ge 0) { $emp = $found.Cells[$ie] }
  $loc = ''; if ($il -ge 0 -and $il -lt $found.Cells.Count) { $loc = $found.Cells[$il] }
  $kind = $found.Sec.Kind
  $labels = @{ apply = 'To apply'; unsure = 'Unsure'; unverified = 'Unverified' }
  $why = ([string]$reason).Replace('|', '/').Replace("`r", ' ').Replace("`n", ' ').Trim()
  if ($why.Length -gt 300) { $why = $why.Substring(0, 300) }
  $mot = 'Discarded by the user'
  if ($why -ne '') { $mot = $mot + ': ' + $why }
  $b64 = [Convert]::ToBase64String($utf8.GetBytes($lines[$found.Idx]))
  $lines.RemoveAt($found.Idx)
  Ensure-Placeholder $lines $kind '_none right now_'
  $newRow = '| ' + $id + ' | ' + $pos + ' | ' + $emp + ' | ' + $loc + ' | ' + $mot + '. Origin: ' + $labels[$kind] + ' <!--orig:' + $kind + ':' + $b64 + '--> |'
  Add-Row $lines 'discarded' $newRow
  Update-Counts $lines
  Adjust-Discards $lines 1
  Update-Stamp $lines ('discarded from the web page: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}
function Op-Restore([string]$id) {
  $lines = Load-Lines
  $secs = Get-Sections $lines
  $found = -1
  foreach ($s in $secs) {
    if ($s.Kind -eq 'discarded') {
      foreach ($ri in $s.Rows) { if ((Get-Cells $lines[$ri])[0] -eq $id) { $found = $ri } }
    }
  }
  if ($found -lt 0) { return @{ ok = $false; error = 'That offer was not found in Discarded.' } }
  $m = [regex]::Match($lines[$found], '<!--orig:(\w+):([A-Za-z0-9+/=]+)-->')
  if (-not $m.Success) { return @{ ok = $false; error = 'Cannot restore it from the web page: the original row was not saved. Ask the skill to restore it ("put offer N back") or move it by hand in job-log.md.' } }
  $origKind = $m.Groups[1].Value
  $origLine = $utf8.GetString([Convert]::FromBase64String($m.Groups[2].Value))
  $lines.RemoveAt($found)
  Add-Row $lines $origKind $origLine
  Update-Counts $lines
  Adjust-Discards $lines -1
  Update-Stamp $lines ('restored from Discarded on the web page: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}
function Op-Note([string]$id, [string]$name, [string]$text) {
  $lines = Load-Lines
  $clean = $text.Replace("`r`n", '<br>').Replace("`n", '<br>').Replace("`r", '<br>').Replace('|', '/').Trim()
  $nm = $name.Replace('|', '/').Trim()
  $when = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $secs = Get-Sections $lines
  $notes = $null
  foreach ($s in $secs) { if ($s.Kind -eq 'notes') { $notes = $s } }
  if ($null -eq $notes) {
    if ($clean -eq '') { return @{ ok = $true } }
    [void]$lines.Add('')
    [void]$lines.Add('## ' + $memo + ' User notes')
    [void]$lines.Add('')
    [void]$lines.Add('| # | Offer | Date and time | Note |')
    [void]$lines.Add('|---|-------|---------------|------|')
    $secs = Get-Sections $lines
    foreach ($s in $secs) { if ($s.Kind -eq 'notes') { $notes = $s } }
  }
  if ($clean -ne '') {
    Remove-Placeholders $lines 'notes'
    $secs = Get-Sections $lines
    foreach ($s in $secs) { if ($s.Kind -eq 'notes') { $notes = $s } }
  }
  $existing = -1
  foreach ($ri in $notes.Rows) { if ((Get-Cells $lines[$ri])[0] -eq $id) { $existing = $ri } }
  if ($clean -eq '') {
    if ($existing -ge 0) { $lines.RemoveAt($existing); Ensure-Placeholder $lines 'notes' '_none yet_' }
  } else {
    $row = '| ' + $id + ' | ' + $nm + ' | ' + $when + ' | ' + $clean + ' |'
    if ($existing -ge 0) { $lines[$existing] = $row }
    else {
      $at = $notes.SepIdx + 1
      if ($notes.Rows.Count -gt 0) { $at = $notes.Rows[$notes.Rows.Count - 1] + 1 }
      $lines.Insert($at, $row)
    }
  }
  Update-Stamp $lines ('note saved from the web page: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}

function Send($ctx, [int]$code, [string]$ctype, [string]$body) {
  $bytes = $utf8.GetBytes($body)
  $ctx.Response.StatusCode = $code
  $ctx.Response.ContentType = $ctype
  $ctx.Response.ContentLength64 = $bytes.Length
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $ctx.Response.OutputStream.Close()
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:' + $Port + '/')
$listener.Start()
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $req = $ctx.Request
    $path = $req.Url.AbsolutePath
    if ($req.HttpMethod -eq 'GET') {
      if ($path -eq '/ping') { Send $ctx 200 'text/plain; charset=utf-8' 'ok'; continue }
      if ($path -eq '/api/mtime') { Send $ctx 200 'text/plain; charset=utf-8' ([string](Get-Item -LiteralPath $htmlPath).LastWriteTimeUtc.Ticks); continue }
      if ($path -eq '/' -or $path -eq '/job-log.html') {
        $h = [System.IO.File]::ReadAllText($htmlPath, $utf8)
        Send $ctx 200 'text/html; charset=utf-8' $h.Replace('__TOKEN__', $token)
        continue
      }
      if ($path -match '^/history/([\w\-\.]+\.md)$') {
        $f = Join-Path (Join-Path $dataDir 'history') $Matches[1]
        if (Test-Path -LiteralPath $f) { Send $ctx 200 'text/plain; charset=utf-8' ([System.IO.File]::ReadAllText($f, $utf8)); continue }
      }
      Send $ctx 404 'text/plain; charset=utf-8' 'Not found'
      continue
    }
    if ($req.HttpMethod -eq 'POST' -and $path -like '/api/*') {
      $ok = $true
      if ($req.Headers['X-Token'] -ne $token) { $ok = $false }
      $origin = $req.Headers['Origin']
      if ($origin -and $origin -ne ('http://localhost:' + $Port)) { $ok = $false }
      if (-not $req.ContentType -or $req.ContentType -notlike 'application/json*') { $ok = $false }
      if (-not $ok) { Send $ctx 403 'application/json; charset=utf-8' '{"ok":false,"error":"Not authorized"}'; continue }
      $sr = New-Object System.IO.StreamReader($req.InputStream, $utf8)
      $raw = $sr.ReadToEnd()
      $sr.Close()
      $data = $raw | ConvertFrom-Json
      $id = [string]$data.id
      if ($id -notmatch '^\d{1,4}$') { Send $ctx 200 'application/json; charset=utf-8' '{"ok":false,"error":"Invalid identifier"}'; continue }
      $res = $null
      if ($path -eq '/api/apply') { $res = Op-Apply $id }
      elseif ($path -eq '/api/unapply') { $res = Op-Unapply $id }
      elseif ($path -eq '/api/discard') { $res = Op-Discard $id ([string]$data.reason) }
      elseif ($path -eq '/api/restore') { $res = Op-Restore $id }
      elseif ($path -eq '/api/note') {
        $txt = [string]$data.text
        if ($txt.Length -gt 4000) { $txt = $txt.Substring(0, 4000) }
        $res = Op-Note $id ([string]$data.name) $txt
      }
      else { $res = @{ ok = $false; error = 'Unknown route' } }
      Send $ctx 200 'application/json; charset=utf-8' ($res | ConvertTo-Json -Compress)
      continue
    }
    Send $ctx 404 'text/plain; charset=utf-8' 'Not found'
  } catch {
    try { [System.IO.File]::AppendAllText((Join-Path $dataDir 'server.log'), ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $_.Exception.Message + ' | ' + $_.InvocationInfo.PositionMessage + "`r`n"), $utf8) } catch { }
    try { Send $ctx 500 'application/json; charset=utf-8' (@{ ok = $false; error = $_.Exception.Message } | ConvertTo-Json -Compress) } catch { }
  }
}
