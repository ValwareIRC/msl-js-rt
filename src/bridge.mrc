; ============================================================================
;  msl-js-rt: the bridge between mIRC script and JavaScript
; ============================================================================
;
; From mSL:   /js <code>            run code (prints the value of a bare expression)
;             $js(<code>)           run code, return its value as text
;             /jsload <file.js>     run a file
;             /jscall <fn> [args]   call a global JS function with text arguments
;             $jscall(fn,args...)   the same, returning the result as text
;             /jsreset              forget everything and start again
;
; From JavaScript, the global object mirc:
;   mirc.on(event, [match], handler)   handle an IRC/mIRC event
;   mirc.off(event, [handler])         stop handling it
;   mirc.alias(name, fn)               define /name and $name() backed by fn
;   mirc.unalias(name)
;   mirc.cmd(line)                     run an mSL command (not evaluated)
;   mirc.exec(line)                    run an mSL command, evaluating $identifiers
;   mirc.eval(text)                    evaluate $identifiers and %variables
;   mirc.say(target, text)  mirc.notice(target, text)  mirc.action(target, text)
;   mirc.echo(...values)               print to the status window
;   mirc.getVar(name) / mirc.setVar(name, value) / mirc.unsetVar(name)
;   mirc.hget(table, item) / mirc.hadd(table, item, value) / mirc.hdel(table, item)
;   mirc.signal(name, ...args)
;   mirc.version

; --------------------------------------------------------------- loading ---

alias js {
  js.init
  hadd jsm depth 0
  if ($isid) {
    ; $js(a,b) would split at commas: put them back
    var -n %code = $1
    var -n %i = 2
    while (%i <= $0) {
      var -n %code = %code $+ $chr(44) $+ $($+($chr(36),%i),2)
      inc %i
    }
    var -n %r = $js_evalsrc(t,%code)
    if (%jsc === x) {
      noop $js_err(Uncaught $js_errtext(%jscv))
      js.settle
      return
    }
    var -n %text = $js_dec($js_tostr(%r))
    js.settle
    return %text
  }
  var -n %quiet = 0
  var -n %code = $1-
  if ($1 == -q) { var -n %quiet = 1 | var -n %code = $2- }
  if (%code == $null) {
    echo -s * /js: usage /js [-q] <code>
    return
  }
  var -n %r = $js_evalsrc(t,%code)
  if (%jsc !=== x) && (!%quiet) && (%r !=== u) { noop $js_out($js_inspect(%r,0,$null)) }
  js.settle
}

alias jsload {
  js.init
  hadd jsm depth 0
  var -n %file = $1-
  if (!$isfile(%file)) && ($isfile($mircdir $+ %file)) { var -n %file = $mircdir $+ %file }
  if (!$isfile(%file)) {
    echo -s * /jsload: no such file %file
    return
  }
  var -n %old = $hget(jsm,dir)
  hadd jsm dir $nofile(%file)
  if (!$js_lex(f,%file)) {
    noop $js_err(Uncaught %jserr in $nopath(%file))
    hadd jsm dir %old
    return
  }
  var -n %prog = $js_parse
  if (!%prog) {
    noop $js_err(Uncaught %jperr in $nopath(%file))
    hadd jsm dir %old
    return
  }
  noop $js_runprog(%prog)
  js.settle
}

alias jscall {
  js.init
  var -n %fn = $hget(jse,1. $+ $js_kenc($1))
  if (!$js_iscallable(%fn)) {
    if (!$isid) { echo -s * /jscall: $1 is not a JavaScript function }
    return
  }
  var -n %args = $null
  if ($isid) {
    var -n %i = 2
    while (%i <= $0) {
      var -n %args = %args s $+ $js_enc($($+($chr(36),%i),2))
      inc %i
    }
  }
  else {
    var -n %i = 2
    while (%i <= $0) {
      var -n %args = %args s $+ $js_enc($gettok($1-,%i,32))
      inc %i
    }
  }
  var -n %r = $js_call(%fn,u,%args)
  var -n %text = $iif(%jsc === x,$null,$js_dec($js_tostr(%r)))
  js.settle
  if ($isid) && (%r !=== u) { return %text }
}

alias jsreset {
  .timerjs* off
  if ($hget(jsm)) { hfree jsm }
  if ($hget(jsa)) { hfree jsa }
  if ($hget(jse)) { hfree jse }
  if ($hget(jso)) { hfree jso }
  if ($hget(jst)) { hfree jst }
  unset %jsc %jscv %jscl %jsoc %jsnt %jsna %jsnf %jsnew
  js.init
  if ($show) { echo -s * JavaScript runtime reset }
}

; ------------------------------------------------------------- mirc object --

alias js.b.mirc {
  var -n %m = $js_newobj
  noop $js_decl(1,mirc,%m)
  js.defs %m on:2:js_b_mon off:2:js_b_moff alias:2:js_b_malias unalias:1:js_b_munalias cmd:1:js_b_mcmd command:1:js_b_mcmd exec:1:js_b_mexec eval:1:js_b_meval say:2:js_b_msay msg:2:js_b_msay notice:2:js_b_mnotice action:2:js_b_maction describe:2:js_b_maction echo:1:js_b_mecho getVar:1:js_b_mgetvar setVar:2:js_b_msetvar unsetVar:1:js_b_munsetvar hget:2:js_b_mhget hadd:3:js_b_mhadd hdel:2:js_b_mhdel signal:1:js_b_msignal
  noop $js_put(%m,version,s $+ $js_enc(msl-js-rt 1.0 on $version))
}

; run an mSL command line: $js_runcmd(line,evaluate)
alias js_runcmd {
  var -n %line = $1
  if ($left(%line,1) == /) { var -n %line = $mid(%line,2) }
  if ($left(%line,1) == /) { var -n %line = $mid(%line,2) }
  var -n %name = $gettok(%line,1,32)
  var -n %rest = $gettok(%line,2-,32)
  if (%name == $null) { return }
  if ($2) { var -n %rest = $(%rest,2) }
  %name %rest
  return
  ; an mSL error becomes a JavaScript exception
  :error
  var -n %err = $error
  reseterror
  noop $js_throw(Error,%err)
}

alias js_b_mcmd {
  noop $js_runcmd($js_argtext(%jsna,1),0)
  return u
}

alias js_b_mexec {
  noop $js_runcmd($js_argtext(%jsna,1),1)
  return u
}

alias js_b_meval { return s $+ $js_enc($($js_argtext(%jsna,1),2)) }

alias js_b_msay {
  var -n %t = $js_argtext(%jsna,1)
  var -n %m = $js_argtext(%jsna,2)
  if (%t != $null) && (%m != $null) { msg %t %m }
  return u
}

alias js_b_mnotice {
  var -n %t = $js_argtext(%jsna,1)
  var -n %m = $js_argtext(%jsna,2)
  if (%t != $null) && (%m != $null) { notice %t %m }
  return u
}

alias js_b_maction {
  var -n %t = $js_argtext(%jsna,1)
  var -n %m = $js_argtext(%jsna,2)
  if (%t != $null) && (%m != $null) { describe %t %m }
  return u
}

alias js_b_mecho {
  noop $js_out($js_fmtargs(%jsna))
  return u
}

alias js_b_mgetvar {
  var -n %name = $remove($js_argtext(%jsna,1),$chr(37))
  var -n %v = $($+($chr(37),%name),2)
  if (%v == $null) && ($var($+($chr(37),%name),0) == 0) { return u }
  return s $+ $js_enc(%v)
}

alias js_b_msetvar {
  var -n %name = $remove($js_argtext(%jsna,1),$chr(37))
  set -n % $+ %name $js_argtext(%jsna,2)
  return u
}

alias js_b_munsetvar {
  var -n %name = $remove($js_argtext(%jsna,1),$chr(37))
  unset % $+ %name
  return u
}

alias js_b_mhget {
  var -n %v = $hget($js_argtext(%jsna,1),$js_argtext(%jsna,2))
  if (%v == $null) { return u }
  return s $+ $js_enc(%v)
}

alias js_b_mhadd {
  hadd -m $js_argtext(%jsna,1) $js_argtext(%jsna,2) $js_argtext(%jsna,3)
  return u
}

alias js_b_mhdel {
  var -n %t = $js_argtext(%jsna,1)
  if ($hget(%t)) { hdel %t $js_argtext(%jsna,2) }
  return u
}

alias js_b_msignal {
  var -n %args = %jsna
  var -n %name = $js_argtext(%args,1)
  var -n %rest = $null
  var -n %i = 2
  while (%i <= $numtok(%args,32)) {
    var -n %rest = %rest $js_dec($js_tostr($gettok(%args,%i,32)))
    inc %i
  }
  .signal -n %name %rest
  return u
}

; ----------------------------------------------------------------- aliases --

alias js_b_malias {
  var -n %name = $remove($js_argtext(%jsna,1),/,$chr(36))
  var -n %fn = $js_arg(%jsna,2)
  if (!$js_iscallable(%fn)) { return $js_throw(TypeError,mirc.alias needs a function) }
  if (!$regex(%name,/^[A-Za-z_][\w.]*$/)) { return $js_throw(TypeError,Invalid alias name: %name) }
  hadd jsm al. $+ %name %fn
  noop $js_capture(1)
  ; the body is built with $chr(36) so nothing in it is evaluated now:
  ;   if ($isid) return $js_acall(name,1,$0,$1,...,$9) | return $js_acall(name,0,1,$1-)
  var -n %d = $chr(36)
  var -n %c = $chr(44)
  var -n %ids = $null
  var -n %i = 1
  while (%i <= 9) {
    var -n %ids = %ids $+ %c $+ %d $+ %i
    inc %i
  }
  var -n %body = if ( $+ %d $+ isid) return %d $+ js_acall( $+ %name $+ %c $+ 1 $+ %c $+ %d $+ 0 $+ %ids $+ ) $chr(124) return %d $+ js_acall( $+ %name $+ %c $+ 0 $+ %c $+ 1 $+ %c $+ %d $+ 1-)
  .alias %name %body
  return u
}

alias js_b_munalias {
  var -n %name = $remove($js_argtext(%jsna,1),/,$chr(36))
  hdel jsm al. $+ %name
  .alias %name
  return u
}

; an alias made by mirc.alias was called: $js_acall(name,isid,count,args...)
alias js_acall {
  var -n %fn = $hget(jsm,al. $+ $1)
  if (!%fn) { return }
  var -n %args = $null
  if ($2) {
    var -n %i = 1
    while (%i <= $3) {
      var -n %a = $($+($chr(36),$calc( %i + 3 )),2)
      var -n %args = %args s $+ $js_enc(%a)
      inc %i
    }
  }
  else {
    var -n %line = $4
    var -n %i = 1
    while (%i <= $numtok(%line,32)) {
      var -n %args = %args s $+ $js_enc($gettok(%line,%i,32))
      inc %i
    }
  }
  var -n %r = $js_call(%fn,u,%args)
  var -n %text = $iif(%jsc === x || %r === u,$null,$js_dec($js_tostr(%r)))
  js.settle
  return %text
}

; ------------------------------------------------------------------ events --
; handlers live in jsm as hk.<event> = list of <fn><2><match> tokens

alias js_b_mon {
  var -n %args = %jsna
  var -n %ev = $lower($js_argtext(%args,1))
  var -n %match = s
  var -n %fn = $js_arg(%args,2)
  if ($numtok(%args,32) >= 3) {
    var -n %match = %fn
    var -n %fn = $js_arg(%args,3)
  }
  if (!$js_iscallable(%fn)) { return $js_throw(TypeError,mirc.on needs a handler function) }
  if (!$istok(text action notice join part quit nick kick topic invite mode connect disconnect input start exit raw ctcp signal open close sockread,%ev,32)) { return $js_throw(TypeError,Unknown event ' $+ %ev $+ ') }
  hadd jsm hk. $+ %ev $hget(jsm,hk. $+ %ev) %fn $+ $chr(2) $+ %match
  noop $js_capture(1)
  return u
}

alias js_b_moff {
  var -n %args = %jsna
  var -n %ev = $lower($js_argtext(%args,1))
  var -n %fn = $js_arg(%args,2)
  if (%fn === u) { hdel jsm hk. $+ %ev | return u }
  var -n %list = $hget(jsm,hk. $+ %ev)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    if ($gettok($gettok(%list,%i,32),1,2) !=== %fn) { var -n %out = %out $gettok(%list,%i,32) }
    inc %i
  }
  hadd jsm hk. $+ %ev %out
  return u
}

; does a handler's match accept this text?
alias js_hkmatch {
  var -n %m = $1
  if (%m === s) || (%m === u) { return 1 }
  if ($js_isregexp(%m)) { return $iif($js_reexec(%m,$2) !=== z,1,0) }
  if ($js_iscallable(%m)) { return $js_truthy($js_call(%m,u,s $+ $js_enc($2))) }
  return $iif($js_dec($js_tostr(%m)) iswm $2,1,0)
}

; build the event object and run the handlers: js.fire <event> <target> <text>
; returns 1 if a handler returned false (to halt default processing)
alias js.fire {
  if (!$hget(jsm,ready)) { return }
  var -n %ev = $1
  var -n %list = $hget(jsm,hk. $+ %ev)
  if (%list == $null) { return }
  var -n %text = $3-
  var -n %e = $js_newobj
  noop $js_put(%e,type,s $+ %ev)
  noop $js_put(%e,text,s $+ $js_enc(%text))
  noop $js_put(%e,args,$js_wordsarr(%text))
  if ($nick != $null) { noop $js_put(%e,nick,s $+ $js_enc($nick)) }
  if ($fulladdress != $null) { noop $js_put(%e,address,s $+ $js_enc($fulladdress)) }
  if ($chan != $null) { noop $js_put(%e,chan,s $+ $js_enc($chan)) }
  if ($2 != $null) && ($2 != -) { noop $js_put(%e,target,s $+ $js_enc($2)) }
  if ($me != $null) { noop $js_put(%e,me,s $+ $js_enc($me)) }
  if ($network != $null) { noop $js_put(%e,network,s $+ $js_enc($network)) }
  if ($cid) { noop $js_put(%e,cid,n $+ $cid) }
  if ($knick != $null) { noop $js_put(%e,knick,s $+ $js_enc($knick)) }
  if ($newnick != $null) { noop $js_put(%e,newnick,s $+ $js_enc($newnick)) }
  if ($numeric) { noop $js_put(%e,numeric,n $+ $numeric) }
  if (%ev === signal) { noop $js_put(%e,signal,s $+ $js_enc($signal)) }
  if ($2 != $null) && ($2 != -) {
    var -n %reply = $js_mknat(reply,1,js_b_ereply)
    hadd jso $mid(%reply,2) $+ :tgt $2
    hadd jso $mid(%reply,2) $+ :cid $cid
    noop $js_defhidden(%e,reply,%reply)
  }
  var -n %halt = 0
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    var -n %h = $gettok(%list,%i,32)
    var -n %match = $gettok(%h,2,2)
    ; signal handlers match the signal's name; the rest match the text
    if ($js_hkmatch(%match,$iif(%ev === signal,$signal,%text))) {
      var -n %r = $js_call($gettok(%h,1,2),u,%e)
      if (%jsc === x) {
        noop $js_err(Uncaught $js_errtext(%jscv) (in a mirc.on(' $+ %ev $+ ') handler))
        unset %jsc %jscv %jscl %jsoc
      }
      if (%r === f) { var -n %halt = 1 }
    }
    inc %i
  }
  js.settle
  if (%halt) { hadd jsm halt 1 }
}

alias js_wordsarr {
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok($1,32)) {
    var -n %out = %out s $+ $js_enc($gettok($1,%i,32))
    inc %i
  }
  return $js_newarr(%out)
}

; e.reply(text): answer where the event came from
alias js_b_ereply {
  var -n %f = %jsnf
  var -n %m = $js_argtext(%jsna,1)
  var -n %t = $hget(jso,$mid(%f,2) $+ :tgt)
  if (%m != $null) && (%t != $null) { scid $hget(jso,$mid(%f,2) $+ :cid) msg %t %m }
  return u
}

; the events, passed on to JavaScript; a handler returning false halts
; mIRC's default processing (for input, text and the like)
on *:TEXT:*:*: { hdel jsm halt | js.fire text $iif($chan,$chan,$nick) $1- | if ($hget(jsm,halt)) { haltdef } }
on *:ACTION:*:*: { js.fire action $iif($chan,$chan,$nick) $1- }
on *:NOTICE:*:*: { js.fire notice $iif($chan,$chan,$nick) $1- }
on *:JOIN:#: { js.fire join $chan $chan }
on *:PART:#: { js.fire part $chan $1- }
on *:QUIT: { js.fire quit - $1- }
on *:NICK: { js.fire nick - $newnick }
on *:KICK:#: { js.fire kick $chan $1- }
on *:TOPIC:#: { js.fire topic $chan $1- }
on *:INVITE:#: { js.fire invite $chan $chan }
on *:RAWMODE:#: { js.fire mode $chan $1- }
on *:CONNECT: { js.fire connect - $server }
on *:DISCONNECT: { js.fire disconnect - $server }
on *:INPUT:*: { hdel jsm halt | js.fire input $active $1- | if ($hget(jsm,halt)) { haltdef | halt } }
on *:EXIT: { js.fire exit - }
on *:RAW:*:*: { js.fire raw - $numeric $1- }
on *:CTCP:*:*: { js.fire ctcp $iif($chan,$chan,$nick) $1- }
on *:SIGNAL:*: { js.fire signal - $1- }
on *:SOCKREAD:*: { }
