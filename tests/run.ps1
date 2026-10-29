# Runs the test suite headless with mslrt and prints the results.
#   .\tests\run.ps1            all tests
#   .\tests\run.ps1 classes    one test
param([string]$Only = '', [string]$Mslrt = 'mslrt')
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$data = Join-Path ([IO.Path]::GetTempPath()) 'msl-js-rt-tests'
New-Item -ItemType Directory -Force $data | Out-Null
$boot = Join-Path $data 'boot.mrc'
@"
on *:START: { hadd -m jstr exit 1 }
"@ | Set-Content $boot -Encoding utf8
if ($Only) {
  @"
on *:START: { hadd -m jstr exit 1 | .timerjstests off | .timerjsone 1 0 jstest $Only }
"@ | Set-Content $boot -Encoding utf8
}
$src = 'core', 'lexer', 'parser', 'eval', 'builtins', 'bridge' | ForEach-Object { Join-Path $root "src\$_.mrc" }
& $Mslrt -no-stdin -headless -data $data @src (Join-Path $here 'run.mrc') $boot 2>&1 |
  Where-Object { $_ -notmatch "Loaded script" } |
  ForEach-Object { $_ -replace '^\d\d:\d\d:\d\d \[Status Window\] ', '' }
