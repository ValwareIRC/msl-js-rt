; ============================================================================
;  msl-js-rt test runner
; ============================================================================
;
; Runs every tests\*.js and compares what it prints with tests\expected\<name>.txt
; (made by running the same file in Node.js; see tests\make-expected.ps1).
; Load it after js.mrc, or run tests\run.ps1. /jstest [name] runs again.

on *:START: { .timerjstests 1 0 jstest }

alias jstest {
  var -n %dir = $scriptdir
  var -n %files = $null
  var -n %n = $findfile(%dir,*.js,0,1)
  var -n %i = 1
  while (%i <= %n) {
    var -n %f = $findfile(%dir,*.js,%i,1)
    if ($nofile(%f) === %dir) && (($1 == $null) || ($1 $+ .js == $nopath(%f))) { var -n %files = $addtok(%files,%f,124) }
    inc %i
  }
  hadd -m jstr files $sorttok(%files,124)
  hadd jstr i 0
  hadd jstr pass 0
  hadd jstr fail 0
  hadd jstr failed $null
  hadd jstr started $ticks
  jstest.next
}

; run the next test file
alias jstest.next {
  var -n %i = $calc( $hget(jstr,i) + 1 )
  hadd jstr i %i
  var -n %f = $gettok($hget(jstr,files),%i,124)
  if (%f == $null) { jstest.done | return }
  .jsreset
  hadd jsm capture @
  hadd jstr t0 $ticks
  .timerjstestcheck -m 1 5000 jstest.check %f
  jsload %f
  ; tests that use timers get time to finish
  var -n %wait = 10
  if ($read(%f,nw,*setTimeout*)) || ($read(%f,nw,*setInterval*)) { var -n %wait = 600 }
  .timerjstestcheck -m 1 %wait jstest.check %f
}

; compare the captured output with the expected file
alias jstest.check {
  var -n %f = $1-
  var -n %name = $remove($nopath(%f),.js)
  var -n %got = $mid($js_dec($hget(jsm,capture)),3)
  hdel jsm capture
  var -n %ms = $calc( $ticks - $hget(jstr,t0) )
  var -n %exp = $nofile(%f) $+ expected\ $+ %name $+ .txt
  if (!$isfile(%exp)) {
    echo -s ?? %name (no expected output; got:)
    echo -s %got
    jstest.next
    return
  }
  var -n %want = $null
  var -n %n = $lines(%exp)
  var -n %i = 1
  while (%i <= %n) {
    var -n %want = %want $+ $iif(%i > 1,$chr(10)) $+ $read(%exp,nt,%i)
    inc %i
  }
  ; ignore trailing blank lines
  while ($right(%want,1) == $chr(10)) { var -n %want = $left(%want,-1) }
  while ($right(%got,1) == $chr(10)) { var -n %got = $left(%got,-1) }
  if ($js_enc(%got) === $js_enc(%want)) {
    hinc jstr pass
    echo -s PASS %name ( $+ %ms ms)
  }
  else {
    hinc jstr fail
    hadd jstr failed $hget(jstr,failed) %name
    echo -s FAIL %name ( $+ %ms ms)
    var -n %l = 1
    var -n %max = $calc( $numtok(%want,10) + 1 )
    var -n %shown = 0
    while (%l <= %max) && (%shown < 6) {
      var -n %a = $gettok(%want,%l,10)
      var -n %b = $gettok(%got,%l,10)
      if (%a !=== %b) {
        echo -s $chr(160) $+ line %l expected: %a
        echo -s $chr(160) $+ line %l actual:   %b
        inc %shown
      }
      inc %l
    }
  }
  jstest.next
}

alias jstest.done {
  var -n %t = $calc( $ticks - $hget(jstr,started) )
  echo -s $hget(jstr,pass) passed, $hget(jstr,fail) failed in %t ms $iif($hget(jstr,failed),- failed: $v1)
  if ($hget(jstr,exit)) { exit }
}
