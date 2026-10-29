# Runs a JavaScript file with msl-js-rt on mslrt.
#   .\run.ps1 examples\hello.js -Exit
#   .\run.ps1 examples\bot.js -Server irc.libera.chat:+6697 -Nick mybot -Join "#test"
# Without -Exit it keeps running (for bots and timers); type /js <code> to
# run more JavaScript, or press Ctrl+C to stop.
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$File,
  [switch]$Exit,
  [string]$Server = '',
  [string]$Nick = '',
  [string]$Join = '',
  [string]$Mslrt = 'mslrt'
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = (Resolve-Path $File).Path
$data = Join-Path ([IO.Path]::GetTempPath()) 'msl-js-rt'
New-Item -ItemType Directory -Force $data | Out-Null
$boot = Join-Path $data 'run-boot.mrc'
$lines = @('on *:START: {', "  jsload $file")
if ($Exit) { $lines += '  .timerjsrunexit 1 2 exit' }
$lines += '}'
Set-Content $boot $lines -Encoding utf8
$cmd = @('-data', $data)
if ($Server) { $cmd += @('-server', $Server) }
if ($Nick) { $cmd += @('-nick', $Nick) }
if ($Join) { $cmd += @('-join', $Join) }
if ($Exit) { $cmd += @('-no-stdin', '-headless') }
& $Mslrt @cmd (Join-Path $here 'js.mrc') $boot 2>&1 |
  Where-Object { $_ -notmatch "Loaded script" } |
  ForEach-Object { $_ -replace '^\d\d:\d\d:\d\d \[Status Window\] ', '' }
