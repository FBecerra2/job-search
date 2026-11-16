# Stops the local job-log server. Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-server.ps1
$procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*log-server.ps1*' }
if ($procs) {
  foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
  Write-Output 'Server stopped.'
} else {
  Write-Output 'The server was not running.'
}
