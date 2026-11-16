# Para el servidor local de registro. Uso: powershell -NoProfile -ExecutionPolicy Bypass -File detener-servidor.ps1
$procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*servidor-registro.ps1*' }
if ($procs) {
  foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
  Write-Output 'Servidor detenido.'
} else {
  Write-Output 'El servidor no estaba activo.'
}
