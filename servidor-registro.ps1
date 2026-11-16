# Servidor local (solo localhost) para registro.html: marcar ofertas como aplicadas, descartarlas (o recuperarlas) y guardar notas en registro.md.
# Lo arranca generar-registro.ps1 -Open. NO crea versiones en el historial: solo la skill buscar-empleo lo hace.
# Parar: detener-servidor.ps1. NOTA: este archivo debe ser solo ASCII.
param([int]$Port = 8765)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mdPath = Join-Path $root 'registro.md'
$htmlPath = Join-Path $root 'registro.html'
$genPath = Join-Path $root 'generar-registro.ps1'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$token = [guid]::NewGuid().ToString('N')
$memo = [char]::ConvertFromUtf32(0x1F4DD)

function Get-Cells([string]$line) { return @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }) }
function Get-Kind([string]$t) {
  if ($t -match 'Notas') { return 'notas' }
  if ($t -match 'Para aplicar') { return 'aplicar' }
  if ($t -match 'Con dudas') { return 'dudas' }
  if ($t -match 'Sin verificar') { return 'verificar' }
  if ($t -match 'Aplicadas') { return 'aplicadas' }
  if ($t -match 'Respuesta') { return 'respuestas' }
  if ($t -match 'Descartadas') { return 'descartadas' }
  return 'otro'
}
function Load-Lines {
  $al = New-Object System.Collections.ArrayList
  $al.AddRange([string[]]@(Get-Content -LiteralPath $mdPath -Encoding UTF8))
  return ,$al
}

# Secciones de tablas: Title, Kind, HdrIdx, SepIdx, Rows (indices de filas de datos), Headers
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
        $cur = @{ Title = ''; Kind = 'resumen'; HdrIdx = -1; SepIdx = -1; Rows = (New-Object System.Collections.ArrayList); Headers = @() }
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
        if ((Get-Cells $lines[$idx])[0] -like '_ninguna*') { $lines.RemoveAt($idx) }
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
  throw ('No encuentro la seccion ' + $kind)
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
    foreach ($ri in $s.Rows) { if ((Get-Cells $lines[$ri])[0] -notlike '_ninguna*') { $real++ } }
    $counts[$s.Kind] = $real
  }
  foreach ($s in $secs) {
    if ($s.Kind -eq 'resumen') {
      foreach ($ri in $s.Rows) {
        $c = Get-Cells $lines[$ri]
        $k = Get-Kind $c[0]
        if (@('aplicar', 'dudas', 'verificar', 'aplicadas', 'respuestas') -contains $k) { $lines[$ri] = '| ' + $c[0] + ' | ' + $counts[$k] + ' |' }
      }
    }
  }
}
function Update-Stamp($lines, [string]$what) {
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'actualizaci.n:') {
      $lines[$i] = ([string][char]218 + 'ltima actualizaci' + [char]243 + 'n: ' + $stamp + ' (' + $what + ')')
      return
    }
  }
}
function Save-And-Regen($lines) {
  [System.IO.File]::WriteAllLines($mdPath, [string[]]$lines.ToArray([string]), $utf8)
  & $genPath -Refresh | Out-Null
}

function Op-Aplicar([string]$id) {
  $lines = Load-Lines
  $secs = Get-Sections $lines
  $found = $null
  foreach ($s in $secs) {
    if (@('aplicar', 'dudas', 'verificar') -contains $s.Kind) {
      foreach ($ri in $s.Rows) {
        $c = Get-Cells $lines[$ri]
        if ($c[0] -eq $id) { $found = @{ Sec = $s; Idx = $ri; Cells = $c } }
      }
    }
  }
  if ($null -eq $found) { return @{ ok = $false; error = 'Esa oferta ya no esta en Para aplicar, Con dudas ni Sin verificar (quiza ya esta aplicada).' } }
  $hdr = $found.Sec.Headers
  $ip = [array]::IndexOf($hdr, 'Puesto')
  $ie = [array]::IndexOf($hdr, 'Empresa')
  $puesto = ''; if ($ip -ge 0) { $puesto = $found.Cells[$ip] }
  $emp = ''; if ($ie -ge 0) { $emp = $found.Cells[$ie] }
  $kind = $found.Sec.Kind
  $labels = @{ aplicar = 'Para aplicar'; dudas = 'Con dudas'; verificar = 'Sin verificar' }
  $b64 = [Convert]::ToBase64String($utf8.GetBytes($lines[$found.Idx]))
  $lines.RemoveAt($found.Idx)
  Ensure-Placeholder $lines $kind '_ninguna ahora_'
  $when = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $newRow = '| ' + $id + ' | ' + $puesto + ' | ' + $emp + ' | ' + $when + ' | (manual, por la usuaria) | - | Origen: ' + $labels[$kind] + ' <!--orig:' + $kind + ':' + $b64 + '--> |'
  Add-Row $lines 'aplicadas' $newRow
  Update-Counts $lines
  Update-Stamp $lines ('marcada como aplicada desde la web: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}
function Op-Desaplicar([string]$id) {
  $lines = Load-Lines
  $secs = Get-Sections $lines
  $found = -1
  foreach ($s in $secs) {
    if ($s.Kind -eq 'aplicadas') {
      foreach ($ri in $s.Rows) { if ((Get-Cells $lines[$ri])[0] -eq $id) { $found = $ri } }
    }
  }
  if ($found -lt 0) { return @{ ok = $false; error = 'No encuentro esa oferta en Aplicadas.' } }
  $m = [regex]::Match($lines[$found], '<!--orig:(\w+):([A-Za-z0-9+/=]+)-->')
  if (-not $m.Success) { return @{ ok = $false; error = 'No puedo deshacerla: no guarda su fila original (se aplico con la skill). Muevela a mano en registro.md.' } }
  $origKind = $m.Groups[1].Value
  $origLine = $utf8.GetString([Convert]::FromBase64String($m.Groups[2].Value))
  $lines.RemoveAt($found)
  Ensure-Placeholder $lines 'aplicadas' ('_ninguna todav' + [char]237 + 'a_')
  Add-Row $lines $origKind $origLine
  Update-Counts $lines
  Update-Stamp $lines ('quitada la marca de aplicada desde la web: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}
function Adjust-Discards($lines, [int]$delta) {
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].StartsWith('|') -and $lines[$i] -match 'Descartadas \| (\d+) filas \(agrupan unas (\d+) ofertas\)') {
      $f = [int]$Matches[1] + $delta
      $o = [int]$Matches[2] + $delta
      if ($f -lt 0) { $f = 0 }
      if ($o -lt 0) { $o = 0 }
      $lines[$i] = [regex]::Replace($lines[$i], '\d+ filas \(agrupan unas \d+ ofertas\)', ([string]$f + ' filas (agrupan unas ' + [string]$o + ' ofertas)'))
      return
    }
  }
}
function Op-Descartar([string]$id, [string]$reason) {
  $lines = Load-Lines
  $secs = Get-Sections $lines
  $found = $null
  foreach ($s in $secs) {
    if (@('aplicar', 'dudas', 'verificar') -contains $s.Kind) {
      foreach ($ri in $s.Rows) {
        $c = Get-Cells $lines[$ri]
        if ($c[0] -eq $id) { $found = @{ Sec = $s; Idx = $ri; Cells = $c } }
      }
    }
  }
  if ($null -eq $found) { return @{ ok = $false; error = 'Esa oferta ya no esta en Para aplicar, Con dudas ni Sin verificar.' } }
  $hdr = $found.Sec.Headers
  $ip = [array]::IndexOf($hdr, 'Puesto')
  $ie = [array]::IndexOf($hdr, 'Empresa')
  $il = [array]::IndexOf($hdr, 'Lugar')
  $puesto = ''; if ($ip -ge 0) { $puesto = $found.Cells[$ip] }
  $emp = ''; if ($ie -ge 0) { $emp = $found.Cells[$ie] }
  $lugar = ''; if ($il -ge 0 -and $il -lt $found.Cells.Count) { $lugar = $found.Cells[$il] }
  $kind = $found.Sec.Kind
  $labels = @{ aplicar = 'Para aplicar'; dudas = 'Con dudas'; verificar = 'Sin verificar' }
  $why = ([string]$reason).Replace('|', '/').Replace("`r", ' ').Replace("`n", ' ').Trim()
  if ($why.Length -gt 300) { $why = $why.Substring(0, 300) }
  $mot = 'Descartada por la usuaria'
  if ($why -ne '') { $mot = $mot + ': ' + $why }
  $b64 = [Convert]::ToBase64String($utf8.GetBytes($lines[$found.Idx]))
  $lines.RemoveAt($found.Idx)
  Ensure-Placeholder $lines $kind '_ninguna ahora_'
  $newRow = '| ' + $id + ' | ' + $puesto + ' | ' + $emp + ' | ' + $lugar + ' | ' + $mot + '. Origen: ' + $labels[$kind] + ' <!--orig:' + $kind + ':' + $b64 + '--> |'
  Add-Row $lines 'descartadas' $newRow
  Update-Counts $lines
  Adjust-Discards $lines 1
  Update-Stamp $lines ('descartada desde la web: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}
function Op-Restaurar([string]$id) {
  $lines = Load-Lines
  $secs = Get-Sections $lines
  $found = -1
  foreach ($s in $secs) {
    if ($s.Kind -eq 'descartadas') {
      foreach ($ri in $s.Rows) { if ((Get-Cells $lines[$ri])[0] -eq $id) { $found = $ri } }
    }
  }
  if ($found -lt 0) { return @{ ok = $false; error = 'No encuentro esa oferta en Descartadas.' } }
  $m = [regex]::Match($lines[$found], '<!--orig:(\w+):([A-Za-z0-9+/=]+)-->')
  if (-not $m.Success) { return @{ ok = $false; error = 'No puedo recuperarla desde la web: no guarda su fila original. Pidele a la skill que la recupere (vuelve a poner la oferta) o muevela a mano en registro.md.' } }
  $origKind = $m.Groups[1].Value
  $origLine = $utf8.GetString([Convert]::FromBase64String($m.Groups[2].Value))
  $lines.RemoveAt($found)
  Add-Row $lines $origKind $origLine
  Update-Counts $lines
  Adjust-Discards $lines -1
  Update-Stamp $lines ('recuperada de descartadas desde la web: #' + $id)
  Save-And-Regen $lines
  return @{ ok = $true }
}
function Op-Nota([string]$id, [string]$name, [string]$text) {
  $lines = Load-Lines
  $clean = $text.Replace("`r`n", '<br>').Replace("`n", '<br>').Replace("`r", '<br>').Replace('|', '/').Trim()
  $nm = $name.Replace('|', '/').Trim()
  $when = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $secs = Get-Sections $lines
  $notes = $null
  foreach ($s in $secs) { if ($s.Kind -eq 'notas') { $notes = $s } }
  if ($null -eq $notes) {
    if ($clean -eq '') { return @{ ok = $true } }
    [void]$lines.Add('')
    [void]$lines.Add('## ' + $memo + ' Notas de la usuaria')
    [void]$lines.Add('')
    [void]$lines.Add('| # | Oferta | Fecha y hora | Nota |')
    [void]$lines.Add('|---|--------|--------------|------|')
    $secs = Get-Sections $lines
    foreach ($s in $secs) { if ($s.Kind -eq 'notas') { $notes = $s } }
  }
  $existing = -1
  foreach ($ri in $notes.Rows) { if ((Get-Cells $lines[$ri])[0] -eq $id) { $existing = $ri } }
  if ($clean -eq '') {
    if ($existing -ge 0) { $lines.RemoveAt($existing) }
  } else {
    $row = '| ' + $id + ' | ' + $nm + ' | ' + $when + ' | ' + $clean + ' |'
    if ($existing -ge 0) { $lines[$existing] = $row }
    else {
      $at = $notes.SepIdx + 1
      if ($notes.Rows.Count -gt 0) { $at = $notes.Rows[$notes.Rows.Count - 1] + 1 }
      $lines.Insert($at, $row)
    }
  }
  Update-Stamp $lines ('nota guardada desde la web: #' + $id)
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
      if ($path -eq '/' -or $path -eq '/registro.html') {
        $h = [System.IO.File]::ReadAllText($htmlPath, $utf8)
        Send $ctx 200 'text/html; charset=utf-8' $h.Replace('__TOKEN__', $token)
        continue
      }
      if ($path -match '^/historial/([\w\-\.]+\.md)$') {
        $f = Join-Path (Join-Path $root 'historial') $Matches[1]
        if (Test-Path -LiteralPath $f) { Send $ctx 200 'text/plain; charset=utf-8' ([System.IO.File]::ReadAllText($f, $utf8)); continue }
      }
      Send $ctx 404 'text/plain; charset=utf-8' 'No encontrado'
      continue
    }
    if ($req.HttpMethod -eq 'POST' -and $path -like '/api/*') {
      $ok = $true
      if ($req.Headers['X-Token'] -ne $token) { $ok = $false }
      $origin = $req.Headers['Origin']
      if ($origin -and $origin -ne ('http://localhost:' + $Port)) { $ok = $false }
      if (-not $req.ContentType -or $req.ContentType -notlike 'application/json*') { $ok = $false }
      if (-not $ok) { Send $ctx 403 'application/json; charset=utf-8' '{"ok":false,"error":"No autorizado"}'; continue }
      $sr = New-Object System.IO.StreamReader($req.InputStream, $utf8)
      $raw = $sr.ReadToEnd()
      $sr.Close()
      $data = $raw | ConvertFrom-Json
      $id = [string]$data.id
      if ($id -notmatch '^\d{1,4}$') { Send $ctx 200 'application/json; charset=utf-8' '{"ok":false,"error":"Identificador no valido"}'; continue }
      $res = $null
      if ($path -eq '/api/aplicar') { $res = Op-Aplicar $id }
      elseif ($path -eq '/api/desaplicar') { $res = Op-Desaplicar $id }
      elseif ($path -eq '/api/descartar') { $res = Op-Descartar $id ([string]$data.reason) }
      elseif ($path -eq '/api/restaurar') { $res = Op-Restaurar $id }
      elseif ($path -eq '/api/nota') {
        $txt = [string]$data.text
        if ($txt.Length -gt 4000) { $txt = $txt.Substring(0, 4000) }
        $res = Op-Nota $id ([string]$data.name) $txt
      }
      else { $res = @{ ok = $false; error = 'Ruta desconocida' } }
      Send $ctx 200 'application/json; charset=utf-8' ($res | ConvertTo-Json -Compress)
      continue
    }
    Send $ctx 404 'text/plain; charset=utf-8' 'No encontrado'
  } catch {
    try { [System.IO.File]::AppendAllText((Join-Path $root 'servidor-registro.log'), ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $_.Exception.Message + ' | ' + $_.InvocationInfo.PositionMessage + "`r`n"), $utf8) } catch { }
    try { Send $ctx 500 'application/json; charset=utf-8' (@{ ok = $false; error = $_.Exception.Message } | ConvertTo-Json -Compress) } catch { }
  }
}
