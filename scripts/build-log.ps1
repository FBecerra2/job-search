# Builds data\job-log.html from data\job-log.md (cards per offer, sections per status, search box, notes, "Applied" and "Discard" checkboxes).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-log.ps1 [-Run mode -Note "summary"] [-Open]
#  -Run     : skill mode (search, apply, report, discard). -Note: short summary of what changed.
#             If -Note is given, a version is saved: a copy of job-log.md in data\history\ and a row in data\history.md.
#             Without -Note NO version is created (that is how the server uses it when saving notes or marking applied).
#  -Open    : starts the local server (log-server.ps1) if it is not running and opens http://localhost:8765/
#  -Refresh : used by the server after a deliberate change from the web page: restores nothing, only refreshes the safety copy.
# NOTE: this file must be plain ASCII (PowerShell 5.1 reads it as ANSI). Emojis are built with ConvertFromUtf32.
# GUARANTEE: the rows of "Applied" and "User notes" are never lost. On every run they are compared with data\job-log-applied.bak
# and, if any is missing (for example because job-log.md was rewritten), they are restored and "RESTORED: ..." is printed.
param([string]$Source = 'job-log.md', [string]$Out = 'job-log.html', [string]$Run = '', [string]$Note = '', [switch]$Open, [switch]$Refresh)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dataDir = Join-Path $root 'data'
$tplDir = Join-Path $root 'templates'
New-Item -ItemType Directory -Force $dataDir | Out-Null
# First run: create the data files from the templates.
foreach ($pair in @(@('job-log.example.md', 'job-log.md'), @('history.example.md', 'history.md'))) {
  $dst = Join-Path $dataDir $pair[1]
  if (-not (Test-Path -LiteralPath $dst)) { Copy-Item -LiteralPath (Join-Path $tplDir $pair[0]) -Destination $dst }
}
$srcPath = Join-Path $dataDir $Source
$outPath = Join-Path $dataDir $Out
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
  if ($t -match 'To apply') { return 'apply' }
  if ($t -match 'Unsure') { return 'unsure' }
  if ($t -match 'Unverified') { return 'unverified' }
  if ($t -match 'Applied') { return 'applied' }
  if ($t -match 'Repl') { return 'replies' }
  if ($t -match 'Discarded') { return 'discarded' }
  return 'other'
}

# ---- Guarantee: applied rows and notes are permanent + summary counts ----
$utf8nb = New-Object System.Text.UTF8Encoding($false)
$bakPath = Join-Path $dataDir 'job-log-applied.bak'
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
    if ($c0 -like '_none*') { continue }
    if ($sec -match 'notes') { $res.N += $l; $res.NIds[$c0] = $true; continue }
    $res.Ids[$c0] = $true
    if ($sec -match 'Applied') { $res.A += $l }
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
    if ($pat -eq 'notes') {
      [void]$work.Add('## ' + [char]::ConvertFromUtf32(0x1F4DD) + ' User notes'); [void]$work.Add('')
      [void]$work.Add('| # | Offer | Date and time | Note |'); [void]$work.Add('|---|-------|---------------|------|')
    } else {
      [void]$work.Add('## ' + [char]::ConvertFromUtf32(0x2705) + ' Applied'); [void]$work.Add('')
      [void]$work.Add('| # | Position | Company | Date and time | CV used | Message sent | Notes |'); [void]$work.Add('|---|----------|---------|---------------|---------|--------------|-------|')
    }
    $start = $work.Count - 4
  }
  $hdr = -1
  for ($i = $start + 1; $i -lt $work.Count; $i++) { if ($work[$i] -match '^## ') { break }; if ($work[$i].StartsWith('|')) { $hdr = $i; break } }
  if ($hdr -lt 0) { return }
  $j = $hdr + 2
  while ($j -lt $work.Count -and $work[$j].StartsWith('|')) {
    if ((Cell0 $work[$j]) -like '_none*') { $work.RemoveAt($j) } else { $j++ }
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
      Insert-IntoSection $work 'Applied' $raw; $changed = $true; Write-Output ('RESTORED: applied #' + $bid + ' (was missing from job-log.md)')
    }
    if ($bk -eq 'N' -and -not $cur0.NIds.ContainsKey($bid)) {
      Insert-IntoSection $work 'notes' $raw; $changed = $true; Write-Output ('RESTORED: note for offer #' + $bid + ' (was missing from job-log.md)')
    }
  }
}
$cur1 = Get-KeepRows $work
for ($i = 0; $i -lt $work.Count; $i++) {
  if ($work[$i] -match '^## ') { break }
  if ($work[$i] -match '^\| (.+?) \| (\d+)\s*\|$') {
    $lab = $Matches[1]; $kk = Kind $lab
    if (@('apply', 'unsure', 'unverified', 'applied', 'replies') -contains $kk) {
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

# ---- Markdown parsing ----
$title = 'Job log'
$updated = ''
$sections = New-Object System.Collections.ArrayList
$cur = [ordered]@{ Title = 'Summary'; Headers = @(); Rows = (New-Object System.Collections.ArrayList); Intro = (New-Object System.Collections.ArrayList) }
[void]$sections.Add($cur)
foreach ($raw in $lines) {
  $line = $raw.TrimEnd()
  if ($line -match '^# (.+)$') { $title = $Matches[1]; continue }
  if ($line -match '^## (.+)$') {
    $cur = [ordered]@{ Title = $Matches[1]; Headers = @(); Rows = (New-Object System.Collections.ArrayList); Intro = (New-Object System.Collections.ArrayList) }
    [void]$sections.Add($cur)
    continue
  }
  if ($line -match 'Last updated:\s*(.+)$') { $updated = $Matches[0]; continue }
  if ($line.StartsWith('|')) {
    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -gt 0 -and $cells[0] -match '^-+$') { continue }
    if ($cur.Headers.Count -eq 0) { $cur.Headers = $cells } else { [void]$cur.Rows.Add($cells) }
    continue
  }
  if ($line -ne '' -and $line -ne '---') { [void]$cur.Intro.Add($line) }
}

# User notes (section "User notes" of job-log.md): id -> note
$notesMap = @{}
foreach ($sec in $sections) {
  if ($sec.Title -match 'notes' -and $sec.Headers.Count -ge 4) {
    foreach ($r in $sec.Rows) { if ($r.Count -ge 4 -and $r[0] -notlike '_none*') { $notesMap[$r[0]] = @{ When = $r[2]; Text = $r[3] } } }
  }
}

# Applied offers (to warn about similar offers)
$stopW = @('de', 'la', 'el', 'y', 'en', 'and', 'the', 'with', 'for', 'of', 'al', 'con', 'para', 'del', 'las', 'los', 'una', 'un')
# Staffing agencies post many unrelated jobs: "same company" is not a useful warning for them. Add your local agencies here.
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
  if ($sec.Title -match 'Applied' -and $sec.Headers.Count -gt 0) {
    $ia = [array]::IndexOf($sec.Headers, 'Position'); $ib = [array]::IndexOf($sec.Headers, 'Company')
    foreach ($r in $sec.Rows) {
      if ($r[0] -like '_none*') { continue }
      $pt = ''; if ($ia -ge 0 -and $ia -lt $r.Count) { $pt = $r[$ia] }
      $em = ''; if ($ib -ge 0 -and $ib -lt $r.Count) { $em = $r[$ib] }
      [void]$appliedList.Add(@{ Id = $r[0]; Key = (CoKey $em); Name = ([regex]::Replace($em, '\[([^\]]+)\]\([^)]*\)', '$1')); Words = (TitleWords $pt) })
    }
  }
}

# ---- Version history ----
$histPath = Join-Path $dataDir 'history.md'
$snapDir = Join-Path $dataDir 'history'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$histRows = New-Object System.Collections.ArrayList
foreach ($hl in (Get-Content -LiteralPath $histPath -Encoding UTF8)) {
  if ($hl -match '^\| v\d+ \|') { [void]$histRows.Add(@($hl.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })) }
}
if ($Note -ne '') {
  New-Item -ItemType Directory -Force $snapDir | Out-Null
  $snapName = 'job-log_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.md'
  Copy-Item -LiteralPath $srcPath -Destination (Join-Path $snapDir $snapName) -Force
  $ver = 'v' + ($histRows.Count + 1)
  $runTxt = $Run
  if ($runTxt -eq '') { $runTxt = 'search' }
  $noteTxt = $Note.Replace('|', '/')
  $when = Get-Date -Format 'yyyy-MM-dd HH:mm'
  [System.IO.File]::AppendAllText($histPath, ('| ' + $ver + ' | ' + $when + ' | ' + $runTxt + ' | ' + $noteTxt + ' | ' + $snapName + ' |' + "`r`n"), $utf8)
  [void]$histRows.Add(@($ver, $when, $runTxt, $noteTxt, $snapName))
}
$verTxt = ''
if ($histRows.Count -gt 0) {
  $lastH = $histRows[$histRows.Count - 1]
  $verTxt = ' &middot; Version ' + (Enc $lastH[0]) + ' (' + (Enc $lastH[1]) + ')'
}

# ---- HTML generation ----
$css = @'
:root{--bg:#f6f7f9;--card:#fff;--ink:#1c2430;--muted:#6b7684;--line:#e3e7ec;--link:#1a5fd0;
--apply:#1f9d55;--unsure:#d98a00;--unverified:#7a8594;--applied:#2b6cd9;--replies:#8a4fd6;--discarded:#c0504d;--other:#7a8594}
@media (prefers-color-scheme:dark){:root{--bg:#12161c;--card:#1b212a;--ink:#e6eaf0;--muted:#98a3b3;--line:#2a323d;--link:#7fb0ff}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1200px;margin:0 auto;padding:24px 16px 64px}
h1{margin:0 0 4px;font-size:26px}.sub{color:var(--muted);font-size:13px;margin-bottom:18px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin-bottom:18px}
.stat{display:block;text-decoration:none;color:var(--ink);background:var(--card);border:1px solid var(--line);border-left:5px solid var(--c);border-radius:10px;padding:10px 14px}
.stat .n{display:block;font-size:28px;font-weight:700;line-height:1.1}.stat .l{display:block;font-size:13px;color:var(--muted)}.stat .s{display:block;font-size:11px;color:var(--muted)}
.k-apply{--c:var(--apply)}.k-unsure{--c:var(--unsure)}.k-unverified{--c:var(--unverified)}.k-applied{--c:var(--applied)}.k-replies{--c:var(--replies)}.k-discarded{--c:var(--discarded)}.k-other{--c:var(--other)}
.search{width:100%;padding:10px 14px;border:1px solid var(--line);border-radius:10px;background:var(--card);color:var(--ink);font:inherit;margin-bottom:10px}
.bar{margin:0 0 16px;font-size:13px;color:var(--muted)}
details.sec{margin-bottom:18px}details.sec>summary{cursor:pointer;list-style:none;font-size:18px;font-weight:700;padding:8px 0;display:flex;align-items:center;gap:10px}
details.sec>summary::-webkit-details-marker{display:none}
.badge{background:var(--c);color:#fff;border-radius:99px;padding:1px 10px;font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:12px;margin-top:8px}
.card{background:var(--card);border:1px solid var(--line);border-top:4px solid var(--c);border-radius:12px;padding:14px;display:flex;flex-direction:column;gap:6px}
.card.done{border-left:4px solid var(--applied)}
.top{display:flex;gap:8px;align-items:flex-start}.num{background:var(--c);color:#fff;border-radius:6px;padding:0 7px;font-size:12px;font-weight:700;margin-top:3px}
.card h3{margin:0;font-size:16px;line-height:1.3}.card h3 a{color:var(--link);text-decoration:none}.card h3 a:hover{text-decoration:underline}
.tools{margin-left:auto;display:flex;flex-direction:column;align-items:flex-end;gap:4px}
.chk{font-size:12.5px;white-space:nowrap;display:flex;align-items:center;gap:4px;cursor:pointer}
.notebtn{font:inherit;font-size:12.5px;padding:1px 9px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--ink);cursor:pointer}.notebtn:hover{border-color:var(--link)}
.co{color:var(--muted);font-weight:600}
.facts{display:flex;flex-wrap:wrap;gap:6px}.f{background:var(--bg);border:1px solid var(--line);border-radius:8px;padding:2px 8px;font-size:12.5px}.f b{color:var(--muted);font-weight:600;margin-right:4px}
.note{font-size:13.5px;color:var(--ink);border-top:1px dashed var(--line);padding-top:6px;margin-top:2px}.note b.l{color:var(--muted);font-weight:600}
.note.cv{background:var(--bg);border:1px solid var(--line);border-left:4px solid var(--applied);border-radius:8px;padding:8px 10px}
.note.co2{color:var(--muted)}
.note.un{background:var(--bg);border:1px solid var(--line);border-left:4px solid var(--unsure);border-radius:8px;padding:8px 10px}
.rel{font-size:13px;background:var(--bg);border:1px solid var(--unsure);border-radius:8px;padding:3px 9px}
.hist{width:100%;border-collapse:collapse;font-size:13.5px;background:var(--card);border:1px solid var(--line)}
.hist th,.hist td{padding:6px 10px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}.hist th{color:var(--muted);font-weight:600}
.empty{color:var(--muted);padding:6px 0 2px}a{color:var(--link)}
.panel{position:fixed;top:0;right:0;height:100%;width:min(400px,100%);background:var(--card);border-left:1px solid var(--line);box-shadow:-4px 0 18px rgba(0,0,0,.2);transform:translateX(105%);transition:transform .2s;z-index:50;padding:16px;display:flex;flex-direction:column;gap:10px}
.panel.open{transform:none}
.ph{display:flex;justify-content:space-between;align-items:center;font-size:17px}.ph button{font-size:24px;background:none;border:none;color:var(--ink);cursor:pointer;line-height:1}
.psub{color:var(--muted);font-size:13px}
.panel textarea{flex:1;width:100%;font:inherit;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--ink);resize:none}
.pbtns{display:flex;gap:8px}.pbtns button{font:inherit;padding:6px 14px;border-radius:8px;border:1px solid var(--line);background:var(--card);color:var(--ink);cursor:pointer}
.pbtns .primary{background:var(--applied);color:#fff;border-color:var(--applied)}
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
g('mode').textContent=LIVE?'Editable mode: what you check or write is saved to job-log.md and the page reloads by itself.':'Read-only. To mark applications and save notes, open http://localhost:8765/ (the skill opens it for you when it finishes).';
var applied=0;
document.querySelectorAll('.card').forEach(function(c){var cb=c.querySelector('input.apl');if(!cb)return;var on=c.classList.contains('k-applied');cb.checked=on;if(on){applied++;c.classList.add('done');}if(!LIVE){cb.disabled=true;}});
g('aplcount').textContent=applied;
document.addEventListener('change',function(e){
var t=e.target;if(!t||!t.classList||!t.classList.contains('apl'))return;
var id=t.closest('.card').getAttribute('data-id');
if(!LIVE){t.checked=!t.checked;return;}
var marking=t.checked;
if(!marking&&!confirm('Remove the applied mark and move the offer back to its previous section?')){t.checked=true;return;}
api(marking?'/api/apply':'/api/unapply',{id:id}).then(function(r){
if(r&&r.ok){location.reload();}else{t.checked=!marking;toast((r&&r.error)||'Could not save');}
}).catch(function(){t.checked=!marking;toast('No connection to the server');});});
document.querySelectorAll('input.dsc,input.rst').forEach(function(x){if(!LIVE){x.disabled=true;}});
document.addEventListener('change',function(e){
var t=e.target;if(!t||!t.classList)return;
var isD=t.classList.contains('dsc'),isR=t.classList.contains('rst');
if(!isD&&!isR)return;
var id=t.closest('.card').getAttribute('data-id');
if(!LIVE){t.checked=isR;return;}
if(isD){
var why=prompt('Why are you discarding it? (optional, you can leave it empty)','');
if(why===null){t.checked=false;return;}
api('/api/discard',{id:id,reason:why}).then(function(r){
if(r&&r.ok){location.reload();}else{t.checked=false;toast((r&&r.error)||'Could not save');}
}).catch(function(){t.checked=false;toast('No connection to the server');});
}else{
if(!confirm('Restore this offer and move it back to its previous section?')){t.checked=true;return;}
api('/api/restore',{id:id}).then(function(r){
if(r&&r.ok){location.reload();}else{t.checked=true;toast((r&&r.error)||'Could not save');}
}).catch(function(){t.checked=true;toast('No connection to the server');});
}});
var cur=null;
document.addEventListener('click',function(e){
var b=e.target.closest?e.target.closest('.notebtn'):null;if(!b)return;
var c=b.closest('.card');cur=c;
g('ptitle').textContent='Note #'+c.getAttribute('data-id');
g('psub').textContent=c.getAttribute('data-name')+' - '+c.querySelector('h3').textContent;
g('ptext').value=c.getAttribute('data-note')||'';
g('pwhen').textContent=c.getAttribute('data-notewhen')?('Saved on '+c.getAttribute('data-notewhen')):'';
g('panel').classList.add('open');g('ptext').focus();});
g('pclose').addEventListener('click',function(){g('panel').classList.remove('open');});
document.addEventListener('keydown',function(e){if(e.key==='Escape'){g('panel').classList.remove('open');}});
function saveNote(text){
if(!LIVE){toast('Open http://localhost:8765/ to save notes');return;}
api('/api/note',{id:cur.getAttribute('data-id'),name:cur.getAttribute('data-name')+' - '+cur.querySelector('h3').textContent,text:text}).then(function(r){
if(r&&r.ok){location.reload();}else{toast((r&&r.error)||'Could not save');}
}).catch(function(){toast('No connection to the server');});}
g('psave').addEventListener('click',function(){saveNote(g('ptext').value);});
g('pdel').addEventListener('click',function(){saveNote('');});
document.addEventListener('click',function(e){var a=e.target.closest?e.target.closest('.relgo'):null;if(!a)return;e.preventDefault();var c=document.querySelector('.card[data-id="'+a.getAttribute('data-go')+'"]');if(!c)return;var d=c.closest('details');if(d)d.open=true;c.scrollIntoView({behavior:'smooth',block:'center'});c.style.outline='3px solid #d98a00';setTimeout(function(){c.style.outline='';},2500);});
if(LIVE){var base=null;setInterval(function(){fetch('/api/mtime').then(function(r){return r.text();}).then(function(t){if(base===null){base=t;}else if(t!==base&&!g('panel').classList.contains('open')){location.reload();}}).catch(function(){});},4000);}
'@

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">')
[void]$sb.AppendLine('<title>' + (Enc $title) + '</title><style>' + $css + '</style></head><body><div class="wrap">')
[void]$sb.AppendLine('<h1>' + (Enc $title) + '</h1><div class="sub">' + (Fmt $updated) + $verTxt + ' &middot; Generated on ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '</div>')

# Summary (count cards)
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
[void]$sb.AppendLine('<input id="q" class="search" type="search" placeholder="Search the log (company, position, language, location...)">')
[void]$sb.AppendLine('<div class="bar"><span id="mode"></span> &middot; Marked as applied: <b id="aplcount">0</b></div>')

# Sections with cards
for ($i = 1; $i -lt $sections.Count; $i++) {
  $sec = $sections[$i]
  if ($sec.Headers.Count -eq 0) { continue }
  if ($sec.Title -match 'notes') { continue }
  $k = Kind $sec.Title
  $hdr = $sec.Headers
  $idxNum = -1; $idxTitle = -1; $idxCo = -1; $noteIdx = @()
  for ($c = 0; $c -lt $hdr.Count; $c++) {
    if ($hdr[$c] -eq '#') { $idxNum = $c }
    elseif ($hdr[$c] -match '^Position') { $idxTitle = $c }
    elseif ($hdr[$c] -match '^Company') { $idxCo = $c }
    elseif ($hdr[$c] -match '^(Notes|Issue|Reason|What they replied|Next step|Message sent|What the company does|CV improvements)') { $noteIdx += $c }
  }
  $real = @($sec.Rows | Where-Object { $_[0] -notmatch '^_none' })
  $openAttr = ''
  if ($k -ne 'discarded') { $openAttr = ' open' }
  [void]$sb.AppendLine('<details class="sec k-' + $k + '" id="s-' + $k + '"' + $openAttr + '><summary>' + (Enc $sec.Title) + ' <span class="badge">' + $real.Count + '</span></summary>')
  if ($real.Count -eq 0) {
    [void]$sb.AppendLine('<div class="empty">None for now.</div>')
  } else {
    [void]$sb.AppendLine('<div class="grid">')
    foreach ($row in $real) {
      $numTxt = ''; if ($idxNum -ge 0) { $numTxt = $row[$idxNum] }
      $titleTxt = ''; if ($idxTitle -ge 0) { $titleTxt = $row[$idxTitle] }
      $coTxt = ''; if ($idxCo -ge 0) { $coTxt = $row[$idxCo] }
      $nt = $null
      if ($notesMap.ContainsKey($numTxt)) { $nt = $notesMap[$numTxt] }
      $noteAttr = ''; $noteWhen = ''; $btnTxt = 'Note'
      if ($null -ne $nt) {
        $noteAttr = (Enc $nt.Text.Replace('<br>', "`n")).Replace("`n", '&#10;')
        $noteWhen = Enc $nt.When
        $btnTxt = 'Note &#9998;'
      }
      $chkHtml = ''
      if ($k -ne 'discarded' -and $idxNum -ge 0) {
        $chkHtml = '<label class="chk"><input type="checkbox" class="apl"> Applied</label>'
        if (@('apply', 'unsure', 'unverified') -contains $k) {
          $chkHtml += '<label class="chk"><input type="checkbox" class="dsc"> Discard</label>'
        }
      } elseif ($k -eq 'discarded' -and $idxNum -ge 0 -and (($row -join '|') -match '<!--orig:')) {
        $chkHtml = '<label class="chk"><input type="checkbox" class="rst" checked> Discarded</label>'
      }
      [void]$sb.AppendLine('<article class="card k-' + $k + '" data-id="' + (Enc $numTxt) + '" data-name="' + (Enc $coTxt) + '" data-note="' + $noteAttr + '" data-notewhen="' + $noteWhen + '"><div class="top"><span class="num">#' + (Enc $numTxt) + '</span><h3>' + (Fmt $titleTxt) + '</h3><div class="tools">' + $chkHtml + '<button type="button" class="notebtn">' + $btnTxt + '</button></div></div>')
      if ($coTxt -ne '') { [void]$sb.AppendLine('<div class="co">' + (Fmt $coTxt) + '</div>') }
      if (@('apply', 'unsure', 'unverified') -contains $k -and $appliedList.Count -gt 0) {
        $ckey = CoKey $coTxt
        $tw = TitleWords $titleTxt
        $rels = New-Object System.Collections.ArrayList
        foreach ($ap in $appliedList) {
          if ($ap.Id -eq $numTxt -or $ckey.Length -lt 3 -or $ap.Key -ne $ckey) { continue }
          $jj = Jacc $tw $ap.Words
          $isAg = $agencies -contains $ckey
          if ($jj -ge 0.34) { [void]$rels.Add('Similar to applied offer <a href="#" class="relgo" data-go="' + (Enc $ap.Id) + '">#' + (Enc $ap.Id) + '</a> (' + (Enc $ap.Name) + ')') }
          elseif (-not $isAg) { [void]$rels.Add('Same company as applied offer <a href="#" class="relgo" data-go="' + (Enc $ap.Id) + '">#' + (Enc $ap.Id) + '</a> (' + (Enc $ap.Name) + ')') }
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
          if ($hdr[$c] -match '^CV improvements') { $nc = 'note cv' }
          elseif ($hdr[$c] -match '^What the company') { $nc = 'note co2' }
          [void]$sb.AppendLine('<div class="' + $nc + '"><b class="l">' + (Enc $hdr[$c]) + ':</b> ' + (Fmt $row[$c]) + '</div>')
        }
      }
      if ($null -ne $nt) {
        [void]$sb.AppendLine('<div class="note un"><b class="l">My note (' + $noteWhen + '):</b> ' + (Enc $nt.Text).Replace('&lt;br&gt;', '<br>') + '</div>')
      }
      [void]$sb.AppendLine('</article>')
    }
    [void]$sb.AppendLine('</div>')
  }
  [void]$sb.AppendLine('</details>')
}
if ($histRows.Count -gt 0) {
  [void]$sb.AppendLine('<details class="sec k-other" id="s-history"><summary>Version history <span class="badge">' + $histRows.Count + '</span></summary><table class="hist"><thead><tr><th>Version</th><th>Date and time</th><th>Mode</th><th>Changes</th><th>Copy</th></tr></thead><tbody>')
  for ($i = $histRows.Count - 1; $i -ge [Math]::Max(0, $histRows.Count - 30); $i--) {
    $hr = $histRows[$i]
    [void]$sb.AppendLine('<tr><td>' + (Enc $hr[0]) + '</td><td>' + (Enc $hr[1]) + '</td><td>' + (Enc $hr[2]) + '</td><td>' + (Enc $hr[3]) + '</td><td><a href="history/' + (Enc $hr[4]) + '">' + (Enc $hr[4]) + '</a></td></tr>')
  }
  [void]$sb.AppendLine('</tbody></table></details>')
}
[void]$sb.AppendLine('<footer>Generated from job-log.md. The "Applied" and "Discard" checkboxes and the notes are saved to job-log.md when the page is opened from the local server (http://localhost:8765/).</footer>')
[void]$sb.AppendLine('</div>')
[void]$sb.AppendLine('<aside id="panel" class="panel"><div class="ph"><b id="ptitle">Note</b><button id="pclose" type="button" title="Close">&times;</button></div><div id="psub" class="psub"></div><textarea id="ptext" placeholder="Write your comments about this offer..."></textarea><div class="pbtns"><button id="psave" type="button" class="primary">Save</button><button id="pdel" type="button">Delete note</button></div><div id="pwhen" class="psub"></div></aside><div id="toast" class="toast"></div>')
[void]$sb.AppendLine('<script>' + $js + '</script></body></html>')

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Output ('OK: ' + $outPath + ' (' + $sections.Count + ' sections, ' + $histRows.Count + ' versions, ' + $notesMap.Count + ' notes)')

if ($Open) {
  $srv = Join-Path $PSScriptRoot 'log-server.ps1'
  $up = $false
  try { $pr = Invoke-WebRequest -Uri 'http://localhost:8765/ping' -UseBasicParsing -TimeoutSec 2; if ($pr.StatusCode -eq 200) { $up = $true } } catch { $up = $false }
  if (-not $up -and (Test-Path -LiteralPath $srv)) {
    Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $srv + '"'))
    Start-Sleep -Seconds 2
  }
  Start-Process 'http://localhost:8765/'
}
