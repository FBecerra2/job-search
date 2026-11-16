# Convierte registro.md en registro.html (tarjetas por oferta, secciones por estado, buscador, notas y casillas "Aplique" y "Descartar").
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File generar-registro.ps1 [-Run modo -Note "resumen"] [-Open]
#  -Run  : modo de la skill (buscar, aplicar, reporte). -Note: resumen corto de lo que cambio.
#          Si se pasa -Note, se guarda una version: copia de registro.md en historial\ y una fila en historial.md.
#          Sin -Note NO se crea version (asi lo usa el servidor al guardar notas o marcar aplicadas).
#  -Open : arranca el servidor local (servidor-registro.ps1) si no esta activo y abre http://localhost:8765/
# NOTA: este archivo debe ser solo ASCII (PowerShell 5.1 lo lee en ANSI). Los acentos van como entidades HTML.
#  -Refresh : lo usa el servidor tras un cambio hecho a proposito desde la web: no restaura nada, solo refresca la copia de seguridad.
# GARANTIA: las filas de Aplicadas y de Notas nunca se pierden. En cada ejecucion se comparan con registro-aplicadas.bak y, si
# falta alguna (por ejemplo porque se reescribio registro.md), se restauran automaticamente y se avisa con "RESTAURADO: ...".
param([string]$Source = 'registro.md', [string]$Out = 'registro.html', [string]$Run = '', [string]$Note = '', [switch]$Open, [switch]$Refresh)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Join-Path $root $Source
$outPath = Join-Path $root $Out
$lines = Get-Content -LiteralPath $srcPath -Encoding UTF8

function Enc([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }
function Fmt([string]$s) {
  $s = [regex]::Replace($s, '<!--.*?-->', '')
  $t = Enc $s
  $t = [regex]::Replace($t, '\[([^\]]+)\]\((https?://[^)\s]+)\)', '<a href="$2" target="_blank" rel="noopener">$1</a>')
  $t = [regex]::Replace($t, '\*\*(.+?)\*\*', '<strong>$1</strong>')
  return $t
}
function Kind([string]$t) {
  if ($t -match 'Para aplicar') { return 'aplicar' }
  if ($t -match 'Con dudas') { return 'dudas' }
  if ($t -match 'Sin verificar') { return 'verificar' }
  if ($t -match 'Aplicadas') { return 'aplicadas' }
  if ($t -match 'Respuesta') { return 'respuestas' }
  if ($t -match 'Descartadas') { return 'descartadas' }
  return 'otro'
}

# ---- Garantia: aplicadas y notas permanentes + recuento del resumen ----
$utf8nb = New-Object System.Text.UTF8Encoding($false)
$bakPath = Join-Path $root 'registro-aplicadas.bak'
function Cell0([string]$l) { return ($l.Trim().Trim('|').Split('|')[0]).Trim() }
function Get-KeepRows($arr) {
  $res = @{ A = @(); N = @(); Ids = @{}; NIds = @{}; Counts = @{} }
  $sec = ''; $tbl = 0
  foreach ($l in $arr) {
    if ($l -match '^## (.+)$') { $sec = $Matches[1]; $tbl = 0; continue }
    if ($sec -eq '' -or -not $l.StartsWith('|')) { continue }
    $tbl++
    if ($tbl -le 2) { continue }
    $c0 = Cell0 $l
    if ($c0 -like '_ninguna*') { continue }
    if ($sec -match 'Notas') { $res.N += $l; $res.NIds[$c0] = $true; continue }
    $res.Ids[$c0] = $true
    if ($sec -match 'Aplicadas') { $res.A += $l }
    $kk = Kind $sec
    $res.Counts[$kk] = [int]$res.Counts[$kk] + 1
  }
  return $res
}
function Insert-IntoSection($work, [string]$pat, [string]$row) {
  $start = -1
  for ($i = 0; $i -lt $work.Count; $i++) { if ($work[$i] -match '^## ' -and $work[$i] -match $pat) { $start = $i; break } }
  if ($start -lt 0) {
    [void]$work.Add('')
    if ($pat -eq 'Notas') {
      [void]$work.Add('## ' + [char]::ConvertFromUtf32(0x1F4DD) + ' Notas de la usuaria'); [void]$work.Add('')
      [void]$work.Add('| # | Oferta | Fecha y hora | Nota |'); [void]$work.Add('|---|--------|--------------|------|')
    } else {
      [void]$work.Add('## ' + [char]::ConvertFromUtf32(0x2705) + ' Aplicadas'); [void]$work.Add('')
      [void]$work.Add('| # | Puesto | Empresa | Fecha y hora | CV usado | Mensaje enviado | Notas |'); [void]$work.Add('|---|--------|---------|--------------|----------|-----------------|-------|')
    }
    $start = $work.Count - 4
  }
  $hdr = -1
  for ($i = $start + 1; $i -lt $work.Count; $i++) { if ($work[$i] -match '^## ') { break }; if ($work[$i].StartsWith('|')) { $hdr = $i; break } }
  if ($hdr -lt 0) { return }
  $j = $hdr + 2
  while ($j -lt $work.Count -and $work[$j].StartsWith('|')) {
    if ((Cell0 $work[$j]) -like '_ninguna*') { $work.RemoveAt($j) } else { $j++ }
  }
  $work.Insert($j, $row)
}
$work = New-Object System.Collections.ArrayList
$work.AddRange([string[]]@($lines))
$changed = $false
$cur0 = Get-KeepRows $work
if ((-not $Refresh) -and (Test-Path -LiteralPath $bakPath)) {
  foreach ($b in (Get-Content -LiteralPath $bakPath -Encoding UTF8)) {
    if ($b.Length -lt 3) { continue }
    $bk = $b.Substring(0, 1); $raw = $b.Substring(2); $bid = Cell0 $raw
    if ($bk -eq 'A' -and -not $cur0.Ids.ContainsKey($bid)) {
      Insert-IntoSection $work 'Aplicadas' $raw; $changed = $true; Write-Output ('RESTAURADO: aplicada #' + $bid + ' (faltaba en registro.md)')
    }
    if ($bk -eq 'N' -and -not $cur0.NIds.ContainsKey($bid)) {
      Insert-IntoSection $work 'Notas' $raw; $changed = $true; Write-Output ('RESTAURADO: nota de la oferta #' + $bid + ' (faltaba en registro.md)')
    }
  }
}
$cur1 = Get-KeepRows $work
for ($i = 0; $i -lt $work.Count; $i++) {
  if ($work[$i] -match '^## ') { break }
  if ($work[$i] -match '^\| (.+?) \| (\d+)\s*\|$') {
    $lab = $Matches[1]; $kk = Kind $lab
    if (@('aplicar', 'dudas', 'verificar', 'aplicadas', 'respuestas') -contains $kk) {
      $newL = '| ' + $lab + ' | ' + [int]$cur1.Counts[$kk] + ' |'
      if ($work[$i] -ne $newL) { $work[$i] = $newL; $changed = $true }
    }
  }
}
if ($changed) {
  [System.IO.File]::WriteAllLines($srcPath, [string[]]$work.ToArray([string]), $utf8nb)
  $lines = Get-Content -LiteralPath $srcPath -Encoding UTF8
  $cur1 = Get-KeepRows $work
}
$bakOut = New-Object System.Collections.ArrayList
foreach ($a in $cur1.A) { [void]$bakOut.Add('A ' + $a) }
foreach ($n in $cur1.N) { [void]$bakOut.Add('N ' + $n) }
[System.IO.File]::WriteAllLines($bakPath, [string[]]$bakOut.ToArray([string]), $utf8nb)

# ---- Parseo del markdown ----
$title = 'Registro de ofertas'
$updated = ''
$sections = New-Object System.Collections.ArrayList
$cur = [ordered]@{ Title = 'Resumen'; Headers = @(); Rows = (New-Object System.Collections.ArrayList); Intro = (New-Object System.Collections.ArrayList) }
[void]$sections.Add($cur)
foreach ($raw in $lines) {
  $line = $raw.TrimEnd()
  if ($line -match '^# (.+)$') { $title = $Matches[1]; continue }
  if ($line -match '^## (.+)$') {
    $cur = [ordered]@{ Title = $Matches[1]; Headers = @(); Rows = (New-Object System.Collections.ArrayList); Intro = (New-Object System.Collections.ArrayList) }
    [void]$sections.Add($cur)
    continue
  }
  if ($line -match 'actualizaci.n:\s*(.+)$') { $updated = $Matches[1]; continue }
  if ($line.StartsWith('|')) {
    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -gt 0 -and $cells[0] -match '^-+$') { continue }
    if ($cur.Headers.Count -eq 0) { $cur.Headers = $cells } else { [void]$cur.Rows.Add($cells) }
    continue
  }
  if ($line -ne '' -and $line -ne '---') { [void]$cur.Intro.Add($line) }
}

# Notas de la usuaria (seccion "Notas" de registro.md): id -> nota
$notesMap = @{}
foreach ($sec in $sections) {
  if ($sec.Title -match 'Notas' -and $sec.Headers.Count -ge 4) {
    foreach ($r in $sec.Rows) { if ($r.Count -ge 4) { $notesMap[$r[0]] = @{ When = $r[2]; Text = $r[3] } } }
  }
}

# Ofertas aplicadas (para avisar de ofertas parecidas)
$stopW = @('de', 'la', 'el', 'y', 'en', 'and', 'the', 'with', 'for', 'of', 'al', 'con', 'para', 'del', 'las', 'los', 'una', 'un')
$agencies = @('randstad', 'adecco', 'manpower', 'michael', 'hays', 'synergie', 'gi', 'lhh', 'talent', 'nuclio', 'robert', 'page', 'kross', 'real', 'sandra', 'externalia', 'paul')
function CoKey([string]$s) {
  $t = [regex]::Replace($s, '\[([^\]]+)\]\([^)]*\)', '$1').ToLower()
  $t = [regex]::Replace($t, '[^a-z0-9 ]', ' ')
  $w = @($t.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
  if ($w.Count -eq 0) { return '' }
  return $w[0]
}
function TitleWords([string]$s) {
  $t = [regex]::Replace($s, '\[([^\]]+)\]\([^)]*\)', '$1').ToLower()
  $t = [regex]::Replace($t, '[^a-z0-9 ]', ' ')
  return @($t.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | Where-Object { $_.Length -ge 3 -and $stopW -notcontains $_ })
}
function Jacc($a, $b) {
  if ($a.Count -eq 0 -or $b.Count -eq 0) { return 0.0 }
  $sa = @{}; foreach ($x in $a) { $sa[$x] = $true }
  $sb2 = @{}; foreach ($x in $b) { $sb2[$x] = $true }
  $inter = 0; foreach ($kx in $sa.Keys) { if ($sb2.ContainsKey($kx)) { $inter++ } }
  return [double]$inter / [double]($sa.Count + $sb2.Count - $inter)
}
$appliedList = New-Object System.Collections.ArrayList
foreach ($sec in $sections) {
  if ($sec.Title -match 'Aplicadas' -and $sec.Headers.Count -gt 0) {
    $ia = [array]::IndexOf($sec.Headers, 'Puesto'); $ib = [array]::IndexOf($sec.Headers, 'Empresa')
    foreach ($r in $sec.Rows) {
      if ($r[0] -like '_ninguna*') { continue }
      $pt = ''; if ($ia -ge 0 -and $ia -lt $r.Count) { $pt = $r[$ia] }
      $em = ''; if ($ib -ge 0 -and $ib -lt $r.Count) { $em = $r[$ib] }
      [void]$appliedList.Add(@{ Id = $r[0]; Key = (CoKey $em); Name = ([regex]::Replace($em, '\[([^\]]+)\]\([^)]*\)', '$1')); Words = (TitleWords $pt) })
    }
  }
}

# ---- Historial de versiones ----
$histPath = Join-Path $root 'historial.md'
$snapDir = Join-Path $root 'historial'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$histRows = New-Object System.Collections.ArrayList
if (Test-Path -LiteralPath $histPath) {
  foreach ($hl in (Get-Content -LiteralPath $histPath -Encoding UTF8)) {
    if ($hl -match '^\| v\d+ \|') { [void]$histRows.Add(@($hl.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })) }
  }
}
if ($Note -ne '') {
  New-Item -ItemType Directory -Force $snapDir | Out-Null
  $snapName = 'registro_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.md'
  Copy-Item -LiteralPath $srcPath -Destination (Join-Path $snapDir $snapName) -Force
  if (-not (Test-Path -LiteralPath $histPath)) {
    $hdr = "# Historial de versiones`r`n`r`n| Versi" + [char]243 + "n | Fecha y hora | Modo | Cambios | Copia |`r`n|---|---|---|---|---|`r`n"
    [System.IO.File]::WriteAllText($histPath, $hdr, $utf8)
  }
  $ver = 'v' + ($histRows.Count + 1)
  $runTxt = $Run
  if ($runTxt -eq '') { $runTxt = 'buscar' }
  $noteTxt = $Note.Replace('|', '/')
  $when = Get-Date -Format 'yyyy-MM-dd HH:mm'
  [System.IO.File]::AppendAllText($histPath, ('| ' + $ver + ' | ' + $when + ' | ' + $runTxt + ' | ' + $noteTxt + ' | ' + $snapName + ' |' + "`r`n"), $utf8)
  [void]$histRows.Add(@($ver, $when, $runTxt, $noteTxt, $snapName))
}
$verTxt = ''
if ($histRows.Count -gt 0) {
  $lastH = $histRows[$histRows.Count - 1]
  $verTxt = ' &middot; Versi&oacute;n ' + (Enc $lastH[0]) + ' (' + (Enc $lastH[1]) + ')'
}

# ---- Generacion del HTML ----
$css = @'
:root{--bg:#f6f7f9;--card:#fff;--ink:#1c2430;--muted:#6b7684;--line:#e3e7ec;--link:#1a5fd0;
--aplicar:#1f9d55;--dudas:#d98a00;--verificar:#7a8594;--aplicadas:#2b6cd9;--respuestas:#8a4fd6;--descartadas:#c0504d;--otro:#7a8594}
@media (prefers-color-scheme:dark){:root{--bg:#12161c;--card:#1b212a;--ink:#e6eaf0;--muted:#98a3b3;--line:#2a323d;--link:#7fb0ff}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1200px;margin:0 auto;padding:24px 16px 64px}
h1{margin:0 0 4px;font-size:26px}.sub{color:var(--muted);font-size:13px;margin-bottom:18px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin-bottom:18px}
.stat{display:block;text-decoration:none;color:var(--ink);background:var(--card);border:1px solid var(--line);border-left:5px solid var(--c);border-radius:10px;padding:10px 14px}
.stat .n{display:block;font-size:28px;font-weight:700;line-height:1.1}.stat .l{display:block;font-size:13px;color:var(--muted)}.stat .s{display:block;font-size:11px;color:var(--muted)}
.k-aplicar{--c:var(--aplicar)}.k-dudas{--c:var(--dudas)}.k-verificar{--c:var(--verificar)}.k-aplicadas{--c:var(--aplicadas)}.k-respuestas{--c:var(--respuestas)}.k-descartadas{--c:var(--descartadas)}.k-otro{--c:var(--otro)}
.search{width:100%;padding:10px 14px;border:1px solid var(--line);border-radius:10px;background:var(--card);color:var(--ink);font:inherit;margin-bottom:10px}
.bar{margin:0 0 16px;font-size:13px;color:var(--muted)}
details.sec{margin-bottom:18px}details.sec>summary{cursor:pointer;list-style:none;font-size:18px;font-weight:700;padding:8px 0;display:flex;align-items:center;gap:10px}
details.sec>summary::-webkit-details-marker{display:none}
.badge{background:var(--c);color:#fff;border-radius:99px;padding:1px 10px;font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:12px;margin-top:8px}
.card{background:var(--card);border:1px solid var(--line);border-top:4px solid var(--c);border-radius:12px;padding:14px;display:flex;flex-direction:column;gap:6px}
.card.applied{border-left:4px solid var(--aplicadas)}
.top{display:flex;gap:8px;align-items:flex-start}.num{background:var(--c);color:#fff;border-radius:6px;padding:0 7px;font-size:12px;font-weight:700;margin-top:3px}
.card h3{margin:0;font-size:16px;line-height:1.3}.card h3 a{color:var(--link);text-decoration:none}.card h3 a:hover{text-decoration:underline}
.tools{margin-left:auto;display:flex;flex-direction:column;align-items:flex-end;gap:4px}
.chk{font-size:12.5px;white-space:nowrap;display:flex;align-items:center;gap:4px;cursor:pointer}
.notebtn{font:inherit;font-size:12.5px;padding:1px 9px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--ink);cursor:pointer}.notebtn:hover{border-color:var(--link)}
.co{color:var(--muted);font-weight:600}
.facts{display:flex;flex-wrap:wrap;gap:6px}.f{background:var(--bg);border:1px solid var(--line);border-radius:8px;padding:2px 8px;font-size:12.5px}.f b{color:var(--muted);font-weight:600;margin-right:4px}
.note{font-size:13.5px;color:var(--ink);border-top:1px dashed var(--line);padding-top:6px;margin-top:2px}.note b.l{color:var(--muted);font-weight:600}
.note.cv{background:var(--bg);border:1px solid var(--line);border-left:4px solid var(--aplicadas);border-radius:8px;padding:8px 10px}
.note.co2{color:var(--muted)}
.note.un{background:var(--bg);border:1px solid var(--line);border-left:4px solid var(--dudas);border-radius:8px;padding:8px 10px}
.rel{font-size:13px;background:var(--bg);border:1px solid var(--dudas);border-radius:8px;padding:3px 9px}
.hist{width:100%;border-collapse:collapse;font-size:13.5px;background:var(--card);border:1px solid var(--line)}
.hist th,.hist td{padding:6px 10px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}.hist th{color:var(--muted);font-weight:600}
.empty{color:var(--muted);padding:6px 0 2px}a{color:var(--link)}
.panel{position:fixed;top:0;right:0;height:100%;width:min(400px,100%);background:var(--card);border-left:1px solid var(--line);box-shadow:-4px 0 18px rgba(0,0,0,.2);transform:translateX(105%);transition:transform .2s;z-index:50;padding:16px;display:flex;flex-direction:column;gap:10px}
.panel.open{transform:none}
.ph{display:flex;justify-content:space-between;align-items:center;font-size:17px}.ph button{font-size:24px;background:none;border:none;color:var(--ink);cursor:pointer;line-height:1}
.psub{color:var(--muted);font-size:13px}
.panel textarea{flex:1;width:100%;font:inherit;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--ink);resize:none}
.pbtns{display:flex;gap:8px}.pbtns button{font:inherit;padding:6px 14px;border-radius:8px;border:1px solid var(--line);background:var(--card);color:var(--ink);cursor:pointer}
.pbtns .primary{background:var(--aplicadas);color:#fff;border-color:var(--aplicadas)}
.toast{position:fixed;left:50%;bottom:24px;transform:translateX(-50%);background:#222;color:#fff;padding:8px 16px;border-radius:8px;opacity:0;pointer-events:none;transition:opacity .2s;z-index:60}.toast.show{opacity:1}
footer{color:var(--muted);font-size:12px;margin-top:30px}
'@
$js = @'
var TOKEN='__TOKEN__';
var LIVE=(location.protocol==='http:')&&TOKEN.length===32;
function g(id){return document.getElementById(id);}
function toast(m){var t=g('toast');t.textContent=m;t.className='toast show';setTimeout(function(){t.className='toast';},3500);}
function api(path,body){return fetch(path,{method:'POST',headers:{'Content-Type':'application/json','X-Token':TOKEN},body:JSON.stringify(body)}).then(function(r){return r.json();});}
g('q').addEventListener('input',function(e){var v=e.target.value.toLowerCase();document.querySelectorAll('.card').forEach(function(c){c.style.display=c.textContent.toLowerCase().indexOf(v)>-1?'':'none';});});
g('mode').textContent=LIVE?'Modo editable: lo que marques o anotes se guarda en registro.md y la p\u00e1gina se recarga sola.':'Solo lectura. Para marcar aplicaciones y guardar notas abre http://localhost:8765/ (la skill lo abre sola al terminar).';
var applied=0;
document.querySelectorAll('.card').forEach(function(c){var cb=c.querySelector('input.apl');if(!cb)return;var on=c.classList.contains('k-aplicadas');cb.checked=on;if(on){applied++;c.classList.add('applied');}if(!LIVE){cb.disabled=true;}});
g('aplcount').textContent=applied;
document.addEventListener('change',function(e){
var t=e.target;if(!t||!t.classList||!t.classList.contains('apl'))return;
var id=t.closest('.card').getAttribute('data-id');
if(!LIVE){t.checked=!t.checked;return;}
var marking=t.checked;
if(!marking&&!confirm('\u00bfQuitar la marca de aplicada y devolver la oferta a su secci\u00f3n anterior?')){t.checked=true;return;}
api(marking?'/api/aplicar':'/api/desaplicar',{id:id}).then(function(r){
if(r&&r.ok){location.reload();}else{t.checked=!marking;toast((r&&r.error)||'No se pudo guardar');}
}).catch(function(){t.checked=!marking;toast('No hay conexi\u00f3n con el servidor');});});
document.querySelectorAll('input.dsc,input.rst').forEach(function(x){if(!LIVE){x.disabled=true;}});
document.addEventListener('change',function(e){
var t=e.target;if(!t||!t.classList)return;
var isD=t.classList.contains('dsc'),isR=t.classList.contains('rst');
if(!isD&&!isR)return;
var id=t.closest('.card').getAttribute('data-id');
if(!LIVE){t.checked=isR;return;}
if(isD){
var why=prompt('\u00bfPor qu\u00e9 la descartas? (opcional: puedes dejarlo vac\u00edo)','');
if(why===null){t.checked=false;return;}
api('/api/descartar',{id:id,reason:why}).then(function(r){
if(r&&r.ok){location.reload();}else{t.checked=false;toast((r&&r.error)||'No se pudo guardar');}
}).catch(function(){t.checked=false;toast('No hay conexi\u00f3n con el servidor');});
}else{
if(!confirm('\u00bfRecuperar esta oferta y devolverla a su secci\u00f3n anterior?')){t.checked=true;return;}
api('/api/restaurar',{id:id}).then(function(r){
if(r&&r.ok){location.reload();}else{t.checked=true;toast((r&&r.error)||'No se pudo guardar');}
}).catch(function(){t.checked=true;toast('No hay conexi\u00f3n con el servidor');});
}});
var cur=null;
document.addEventListener('click',function(e){
var b=e.target.closest?e.target.closest('.notebtn'):null;if(!b)return;
var c=b.closest('.card');cur=c;
g('ptitle').textContent='Nota #'+c.getAttribute('data-id');
g('psub').textContent=c.getAttribute('data-name')+' - '+c.querySelector('h3').textContent;
g('ptext').value=c.getAttribute('data-note')||'';
g('pwhen').textContent=c.getAttribute('data-notewhen')?('Guardada el '+c.getAttribute('data-notewhen')):'';
g('panel').classList.add('open');g('ptext').focus();});
g('pclose').addEventListener('click',function(){g('panel').classList.remove('open');});
document.addEventListener('keydown',function(e){if(e.key==='Escape'){g('panel').classList.remove('open');}});
function saveNote(text){
if(!LIVE){toast('Abre http://localhost:8765/ para guardar notas');return;}
api('/api/nota',{id:cur.getAttribute('data-id'),name:cur.getAttribute('data-name')+' - '+cur.querySelector('h3').textContent,text:text}).then(function(r){
if(r&&r.ok){location.reload();}else{toast((r&&r.error)||'No se pudo guardar');}
}).catch(function(){toast('No hay conexi\u00f3n con el servidor');});}
g('psave').addEventListener('click',function(){saveNote(g('ptext').value);});
g('pdel').addEventListener('click',function(){saveNote('');});
document.addEventListener('click',function(e){var a=e.target.closest?e.target.closest('.relgo'):null;if(!a)return;e.preventDefault();var c=document.querySelector('.card[data-id="'+a.getAttribute('data-go')+'"]');if(!c)return;var d=c.closest('details');if(d)d.open=true;c.scrollIntoView({behavior:'smooth',block:'center'});c.style.outline='3px solid #d98a00';setTimeout(function(){c.style.outline='';},2500);});
if(LIVE){var base=null;setInterval(function(){fetch('/api/mtime').then(function(r){return r.text();}).then(function(t){if(base===null){base=t;}else if(t!==base&&!g('panel').classList.contains('open')){location.reload();}}).catch(function(){});},4000);}
'@

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">')
[void]$sb.AppendLine('<title>' + (Enc $title) + '</title><style>' + $css + '</style></head><body><div class="wrap">')
[void]$sb.AppendLine('<h1>' + (Enc $title) + '</h1><div class="sub">' + (Fmt $updated) + $verTxt + ' &middot; Generado el ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '</div>')

# Resumen (tarjetas de cantidades)
$res = $sections[0]
if ($res.Rows.Count -gt 0) {
  [void]$sb.AppendLine('<div class="stats">')
  foreach ($r in $res.Rows) {
    $k = Kind $r[0]
    $n = $r[1]; $sub = ''
    if ($r[1] -match '^(\d+)\s*(.*)$') { $n = $Matches[1]; $sub = $Matches[2] }
    [void]$sb.AppendLine('<a class="stat k-' + $k + '" href="#s-' + $k + '"><span class="n">' + (Enc $n) + '</span><span class="l">' + (Enc $r[0]) + '</span><span class="s">' + (Enc $sub) + '</span></a>')
  }
  [void]$sb.AppendLine('</div>')
}
[void]$sb.AppendLine('<input id="q" class="search" type="search" placeholder="Buscar en el registro (empresa, puesto, idioma, lugar...)">')
[void]$sb.AppendLine('<div class="bar"><span id="mode"></span> &middot; Marcadas como aplicadas: <b id="aplcount">0</b></div>')

# Secciones con tarjetas
for ($i = 1; $i -lt $sections.Count; $i++) {
  $sec = $sections[$i]
  if ($sec.Headers.Count -eq 0) { continue }
  if ($sec.Title -match 'Notas') { continue }
  $k = Kind $sec.Title
  $hdr = $sec.Headers
  $idxNum = -1; $idxTitle = -1; $idxCo = -1; $noteIdx = @()
  for ($c = 0; $c -lt $hdr.Count; $c++) {
    if ($hdr[$c] -eq '#') { $idxNum = $c }
    elseif ($hdr[$c] -match '^Puesto') { $idxTitle = $c }
    elseif ($hdr[$c] -match '^Empresa') { $idxCo = $c }
    elseif ($hdr[$c] -match '^(Notas|Pega|Motivo|Qu. respondieron|Siguiente paso|Mensaje enviado|Qu. hace la empresa|Mejoras al CV)') { $noteIdx += $c }
  }
  $real = @($sec.Rows | Where-Object { $_[0] -notmatch '^_ninguna' })
  $openAttr = ''
  if ($k -ne 'descartadas') { $openAttr = ' open' }
  [void]$sb.AppendLine('<details class="sec k-' + $k + '" id="s-' + $k + '"' + $openAttr + '><summary>' + (Enc $sec.Title) + ' <span class="badge">' + $real.Count + '</span></summary>')
  if ($real.Count -eq 0) {
    [void]$sb.AppendLine('<div class="empty">Ninguna por ahora.</div>')
  } else {
    [void]$sb.AppendLine('<div class="grid">')
    foreach ($row in $real) {
      $numTxt = ''; if ($idxNum -ge 0) { $numTxt = $row[$idxNum] }
      $titleTxt = ''; if ($idxTitle -ge 0) { $titleTxt = $row[$idxTitle] }
      $coTxt = ''; if ($idxCo -ge 0) { $coTxt = $row[$idxCo] }
      $nt = $null
      if ($notesMap.ContainsKey($numTxt)) { $nt = $notesMap[$numTxt] }
      $noteAttr = ''; $noteWhen = ''; $btnTxt = 'Nota'
      if ($null -ne $nt) {
        $noteAttr = (Enc $nt.Text.Replace('<br>', "`n")).Replace("`n", '&#10;')
        $noteWhen = Enc $nt.When
        $btnTxt = 'Nota &#9998;'
      }
      $chkHtml = ''
      if ($k -ne 'descartadas' -and $idxNum -ge 0) {
        $chkHtml = '<label class="chk"><input type="checkbox" class="apl"> Apliqu&eacute;</label>'
        if (@('aplicar', 'dudas', 'verificar') -contains $k) {
          $chkHtml += '<label class="chk"><input type="checkbox" class="dsc"> Descartar</label>'
        }
      } elseif ($k -eq 'descartadas' -and $idxNum -ge 0 -and (($row -join '|') -match '<!--orig:')) {
        $chkHtml = '<label class="chk"><input type="checkbox" class="rst" checked> Descartada</label>'
      }
      [void]$sb.AppendLine('<article class="card k-' + $k + '" data-id="' + (Enc $numTxt) + '" data-name="' + (Enc $coTxt) + '" data-note="' + $noteAttr + '" data-notewhen="' + $noteWhen + '"><div class="top"><span class="num">#' + (Enc $numTxt) + '</span><h3>' + (Fmt $titleTxt) + '</h3><div class="tools">' + $chkHtml + '<button type="button" class="notebtn">' + $btnTxt + '</button></div></div>')
      if ($coTxt -ne '') { [void]$sb.AppendLine('<div class="co">' + (Fmt $coTxt) + '</div>') }
      if (@('aplicar', 'dudas', 'verificar') -contains $k -and $appliedList.Count -gt 0) {
        $ckey = CoKey $coTxt
        $tw = TitleWords $titleTxt
        $rels = New-Object System.Collections.ArrayList
        foreach ($ap in $appliedList) {
          if ($ap.Id -eq $numTxt -or $ckey.Length -lt 3 -or $ap.Key -ne $ckey) { continue }
          $jj = Jacc $tw $ap.Words
          $isAg = $agencies -contains $ckey
          if ($jj -ge 0.34) { [void]$rels.Add('Parecida a la aplicada <a href="#" class="relgo" data-go="' + (Enc $ap.Id) + '">#' + (Enc $ap.Id) + '</a> (' + (Enc $ap.Name) + ')') }
          elseif (-not $isAg) { [void]$rels.Add('Misma empresa que la aplicada <a href="#" class="relgo" data-go="' + (Enc $ap.Id) + '">#' + (Enc $ap.Id) + '</a> (' + (Enc $ap.Name) + ')') }
        }
        if ($rels.Count -gt 0) { [void]$sb.AppendLine('<div class="rel">&#9888; ' + ($rels -join '; ') + '</div>') }
      }
      $facts = New-Object System.Text.StringBuilder
      for ($c = 0; $c -lt $hdr.Count; $c++) {
        if ($c -eq $idxNum -or $c -eq $idxTitle -or $c -eq $idxCo -or $noteIdx -contains $c) { continue }
        if ($c -ge $row.Count -or $row[$c] -eq '') { continue }
        [void]$facts.Append('<span class="f"><b>' + (Enc $hdr[$c]) + '</b>' + (Fmt $row[$c]) + '</span>')
      }
      if ($facts.Length -gt 0) { [void]$sb.AppendLine('<div class="facts">' + $facts.ToString() + '</div>') }
      foreach ($c in $noteIdx) {
        if ($c -lt $row.Count -and $row[$c] -ne '') {
          $nc = 'note'
          if ($hdr[$c] -match '^Mejoras') { $nc = 'note cv' }
          elseif ($hdr[$c] -match '^Qu. hace') { $nc = 'note co2' }
          [void]$sb.AppendLine('<div class="' + $nc + '"><b class="l">' + (Enc $hdr[$c]) + ':</b> ' + (Fmt $row[$c]) + '</div>')
        }
      }
      if ($null -ne $nt) {
        [void]$sb.AppendLine('<div class="note un"><b class="l">Mi nota (' + $noteWhen + '):</b> ' + (Enc $nt.Text).Replace('&lt;br&gt;', '<br>') + '</div>')
      }
      [void]$sb.AppendLine('</article>')
    }
    [void]$sb.AppendLine('</div>')
  }
  [void]$sb.AppendLine('</details>')
}
if ($histRows.Count -gt 0) {
  [void]$sb.AppendLine('<details class="sec k-otro" id="s-historial"><summary>Historial de versiones <span class="badge">' + $histRows.Count + '</span></summary><table class="hist"><thead><tr><th>Versi&oacute;n</th><th>Fecha y hora</th><th>Modo</th><th>Cambios</th><th>Copia</th></tr></thead><tbody>')
  for ($i = $histRows.Count - 1; $i -ge [Math]::Max(0, $histRows.Count - 30); $i--) {
    $hr = $histRows[$i]
    [void]$sb.AppendLine('<tr><td>' + (Enc $hr[0]) + '</td><td>' + (Enc $hr[1]) + '</td><td>' + (Enc $hr[2]) + '</td><td>' + (Enc $hr[3]) + '</td><td><a href="historial/' + (Enc $hr[4]) + '">' + (Enc $hr[4]) + '</a></td></tr>')
  }
  [void]$sb.AppendLine('</tbody></table></details>')
}
[void]$sb.AppendLine('<footer>Generado desde registro.md. Las marcas "Apliqu&eacute;" y "Descartar" y las notas se guardan en registro.md cuando la p&aacute;gina se abre desde el servidor local (http://localhost:8765/).</footer>')
[void]$sb.AppendLine('</div>')
[void]$sb.AppendLine('<aside id="panel" class="panel"><div class="ph"><b id="ptitle">Nota</b><button id="pclose" type="button" title="Cerrar">&times;</button></div><div id="psub" class="psub"></div><textarea id="ptext" placeholder="Escribe tus comentarios sobre esta oferta..."></textarea><div class="pbtns"><button id="psave" type="button" class="primary">Guardar</button><button id="pdel" type="button">Borrar nota</button></div><div id="pwhen" class="psub"></div></aside><div id="toast" class="toast"></div>')
[void]$sb.AppendLine('<script>' + $js + '</script></body></html>')

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Output ('OK: ' + $outPath + ' (' + $sections.Count + ' secciones, ' + $histRows.Count + ' versiones, ' + $notesMap.Count + ' notas)')

if ($Open) {
  $srv = Join-Path $root 'servidor-registro.ps1'
  $up = $false
  try { $pr = Invoke-WebRequest -Uri 'http://localhost:8765/ping' -UseBasicParsing -TimeoutSec 2; if ($pr.StatusCode -eq 200) { $up = $true } } catch { $up = $false }
  if (-not $up -and (Test-Path -LiteralPath $srv)) {
    Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $srv + '"'))
    Start-Sleep -Seconds 2
  }
  Start-Process 'http://localhost:8765/'
}
