# First-time setup: creates the data\ folder from the templates. Safe to run again: it never overwrites existing files.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup.ps1
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dataDir = Join-Path $root 'data'
$tplDir = Join-Path $root 'templates'
New-Item -ItemType Directory -Force $dataDir | Out-Null
New-Item -ItemType Directory -Force (Join-Path $dataDir 'CV') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $dataDir 'history') | Out-Null
$files = @(
  @('profile.example.md', 'profile.md'),
  @('job-log.example.md', 'job-log.md'),
  @('history.example.md', 'history.md')
)
foreach ($f in $files) {
  $dst = Join-Path $dataDir $f[1]
  if (Test-Path -LiteralPath $dst) {
    Write-Output ('Kept existing: data\' + $f[1])
  } else {
    Copy-Item -LiteralPath (Join-Path $tplDir $f[0]) -Destination $dst
    Write-Output ('Created:       data\' + $f[1])
  }
}
Write-Output ''
Write-Output 'Next steps:'
Write-Output '  1. Open data\profile.md and fill in every field (the file explains each one).'
Write-Output '  2. Put your CV as an image (JPG/PNG) in data\CV\ so Claude can read it. Never attach files from this folder to an application.'
Write-Output '  3. Open this folder in Claude Code and type /job-search'
