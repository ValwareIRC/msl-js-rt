# Regenerates tests\expected\*.txt by running each test in Node.js.
# hooks.js uses the mirc object, which only exists in msl-js-rt, so its
# expected output is written by hand and left alone here.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
New-Item -ItemType Directory -Force "$here\expected" | Out-Null
Get-ChildItem "$here\*.js" | Where-Object { $_.Name -ne 'hooks.js' } | ForEach-Object {
  Push-Location $here
  try {
    $out = & node $_.FullName 2>&1 | Out-String
  } finally { Pop-Location }
  $file = "$here\expected\$($_.BaseName).txt"
  [IO.File]::WriteAllText($file, $out.Replace("`r`n", "`n"))
  "wrote $file"
}
