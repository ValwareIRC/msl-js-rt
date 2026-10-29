; ============================================================================
;  msl-js-rt: parser - tokens (jst) -> syntax tree (jsa)
; ============================================================================
;
; Recursive descent with precedence climbing for binary operators. Every
; parse function is an identifier returning a node id (0 on error; the
; message is in %jperr). The current token index is %jp.
;
; A node <n> has <n>:t (type) and fields named in the evaluator. Lists of
; child nodes are space-separated ids. Names are stored case-escaped
; (:k, :n) for scopes and properties; display names are encoded strings.
;
; While parsing a function, %jpfs holds the stack of function nodes so
; that var names (:hv), function declarations (:hf) and use of arguments
; (:ua) can be recorded on the function that owns them, and %jpbs the stack
; of blocks so that blocks with let/const/class get their own scope (:lex).

alias js.parseinit {
  if ($hget(jsm,parseready)) { return }
  ; binary operator precedence
  var -n %p = nc:2 or:2 and:3 bor:4 bxor:5 band:6 eq:7 ne:7 seq:7 sne:7 lt:8 gt:8 le:8 ge:8 in:8 instanceof:8 shl:9 shr:9 ushr:9 add:10 sub:10 mul:11 div:11 mod:11 exp:12
  var -n %i = 1
  while (%i <= $numtok(%p,32)) {
    hadd jsm bp. $+ $gettok($gettok(%p,%i,32),1,58) $gettok($gettok(%p,%i,32),2,58)
    inc %i
  }
  ; assignment operators -> the binary operator they apply (= for plain)
  var -n %a = asg:= aadd:add asub:sub amul:mul adiv:div amod:mod aexp:exp ashl:shl ashr:shr aushr:ushr aband:band abor:bor abxor:bxor aand:and aor:or anc:nc
  var -n %i = 1
  while (%i <= $numtok(%a,32)) {
    hadd jsm as. $+ $gettok($gettok(%a,%i,32),1,58) $gettok($gettok(%a,%i,32),2,58)
    inc %i
  }
  hadd jsm parseready 1
}

; parse the tokens in jst -> program node, 0 on error (%jperr)
alias js_parse {
  js.parseinit
  unset %jperr
  set %jp 1
  var -n %prog = $jp_node(prog)
  set %jpfs %prog
  set %jpbs %prog
  var -n %list = $null
  while ($hget(jst,%jp $+ :t) !=== x) && (!%jperr) {
    var -n %s = $jp_stmt
    if (%s) { var -n %list = %list %s }
  }
  hadd jsa %prog $+ :s %list
  unset %jpfs %jpbs %jpnoin %jpnfn
  if (%jperr) { return 0 }
  return %prog
}

; ---------------------------------------------------------------- helpers --

alias jp_node {
  var -n %id = $calc( $hget(jsm,aid) + 1 )
  hadd jsm aid %id
  hadd jsa %id $+ :t $1
  return %id
}

; current token type / value / is it (type,value)
alias jp_t { return $hget(jst,%jp $+ :t) }
alias jp_v { return $hget(jst,%jp $+ :v) }
alias jp_is { return $iif($hget(jst,%jp $+ :t) === $1 && $hget(jst,%jp $+ :v) === $2,1,0) }
alias jp_isp { return $iif($hget(jst,%jp $+ :t) === p && $hget(jst,%jp $+ :v) === $1,1,0) }
alias jp_peekp { return $iif($hget(jst,$calc( %jp + $1 ) $+ :t) === p && $hget(jst,$calc( %jp + $1 ) $+ :v) === $2,1,0) }

; take a punctuator if it is next
alias jp_eatp {
  if ($hget(jst,%jp $+ :t) === p) && ($hget(jst,%jp $+ :v) === $1) { inc %jp | return 1 }
  return 0
}

; require a punctuator
alias jp_needp {
  if ($hget(jst,%jp $+ :t) === p) && ($hget(jst,%jp $+ :v) === $1) { inc %jp | return 1 }
  noop $jp_fail
  return 0
}

; record a syntax error at the current token
alias jp_fail {
  if (%jperr) { return 0 }
  var -n %t = $hget(jst,%jp $+ :t)
  var -n %v = $hget(jst,%jp $+ :v)
  var -n %what = $null
  if ($1 != $null) { var -n %what = $1- }
  elseif (%t === x) { var -n %what = Unexpected end of input }
  elseif (%t === p) { var -n %what = Unexpected token ' $+ $js_pname(%v) $+ ' }
  elseif (%t === s) || (%t === q) { var -n %what = Unexpected string }
  elseif (%t === n) { var -n %what = Unexpected number }
  else { var -n %what = Unexpected token ' $+ %v $+ ' }
  set %jperr SyntaxError: %what (line $hget(jst,%jp $+ :ln) $+ )
  ; stop the parse loops
  set %jp $hget(jst,count)
  return 0
}

; punctuator name -> its text, for messages
alias js_pname {
  var -n %names = lb:123 rb:125 lp:40 rp:41 ls:91 rs:93 semi:59 comma:44 dot:46 colon:58 asg:61 arrow:61.62 qm:63 lt:60 gt:62 add:43 sub:45 mul:42 div:47
  var -n %i = 1
  while (%i <= $numtok(%names,32)) {
    if ($gettok($gettok(%names,%i,32),1,58) === $1) {
      var -n %c = $gettok($gettok(%names,%i,32),2,58)
      var -n %s = $null
      var -n %j = 1
      while (%j <= $numtok(%c,46)) {
        var -n %s = %s $+ $chr($gettok(%c,%j,46))
        inc %j
      }
      return %s
    }
    inc %i
  }
  return $1
}

; automatic semicolon insertion
alias jp_semi {
  if ($jp_eatp(semi)) { return 1 }
  if ($jp_isp(rb)) || ($hget(jst,%jp $+ :t) === x) || ($hget(jst,%jp $+ :nl)) { return 1 }
  noop $jp_fail
  return 0
}

; current function / block nodes
alias jp_curfn { return $gettok(%jpfs,-1,32) }
alias jp_curblk { return $gettok(%jpbs,-1,32) }

; hoist a var name (key) into the current function
alias jp.hoistvar {
  var -n %f = $jp_curfn
  var -n %hv = $hget(jsa,%f $+ :hv)
  if (!$istokcs(%hv,$1,32)) { hadd jsa %f $+ :hv %hv $1 }
}

; every name bound by a pattern -> list of keys
alias jp_patnames {
  var -n %n = $1
  var -n %t = $hget(jsa,%n $+ :t)
  if (%t === id) { return $hget(jsa,%n $+ :n) }
  if (%t === def) { return $jp_patnames($hget(jsa,%n $+ :l)) }
  if (%t === rest) || (%t === spread) { return $jp_patnames($hget(jsa,%n $+ :a)) }
  var -n %out = $null
  if (%t === arr) || (%t === apat) {
    var -n %e = $hget(jsa,%n $+ :e)
    var -n %i = 1
    while (%i <= $numtok(%e,32)) {
      if ($gettok(%e,%i,32)) { var -n %out = %out $jp_patnames($gettok(%e,%i,32)) }
      inc %i
    }
    return %out
  }
  if (%t === obj) || (%t === opat) {
    var -n %p = $hget(jsa,%n $+ :p)
    var -n %i = 1
    while (%i <= $numtok(%p,32)) {
      var -n %pp = $gettok(%p,%i,32)
      if ($hget(jsa,%pp $+ :t) === rest) { var -n %out = %out $jp_patnames(%pp) }
      else { var -n %out = %out $jp_patnames($hget(jsa,%pp $+ :v)) }
      inc %i
    }
    return %out
  }
  return $null
}

; turn an expression into an assignment target (arrays/objects -> patterns)
alias jp_topat {
  var -n %n = $1
  var -n %t = $hget(jsa,%n $+ :t)
  if (%t === arr) {
    hadd jsa %n $+ :t apat
    var -n %e = $hget(jsa,%n $+ :e)
    var -n %i = 1
    while (%i <= $numtok(%e,32)) {
      var -n %el = $gettok(%e,%i,32)
      if (%el) { noop $jp_topat(%el) }
      inc %i
    }
  }
  elseif (%t === obj) {
    hadd jsa %n $+ :t opat
    var -n %p = $hget(jsa,%n $+ :p)
    var -n %i = 1
    while (%i <= $numtok(%p,32)) {
      var -n %pp = $gettok(%p,%i,32)
      if ($hget(jsa,%pp $+ :kind) === spread) {
        hadd jsa %pp $+ :t rest
        hadd jsa %pp $+ :a $hget(jsa,%pp $+ :v)
      }
      else { noop $jp_topat($hget(jsa,%pp $+ :v)) }
      inc %i
    }
  }
  elseif (%t === asg) && ($hget(jsa,%n $+ :o) === asg) {
    hadd jsa %n $+ :t def
    noop $jp_topat($hget(jsa,%n $+ :l))
  }
  elseif (%t === spread) {
    hadd jsa %n $+ :t rest
    noop $jp_topat($hget(jsa,%n $+ :a))
  }
  return %n
}

; ------------------------------------------------------------- statements --

alias jp_stmt {
  var -n %t = $hget(jst,%jp $+ :t)
  var -n %v = $hget(jst,%jp $+ :v)
  var -n %ln = $hget(jst,%jp $+ :ln)
  var -n %n = 0
  if (%t === p) {
    if (%v === lb) { return $jp_block }
    if (%v === semi) { inc %jp | return 0 }
  }
  if (%t === k) {
    if (%v === var) || (%v === const) { var -n %n = $jp_vardecl | if (!$jp_semi) { return 0 } | goto done }
    if (%v === function) { var -n %n = $jp_fndecl | goto done }
    if (%v === class) { var -n %n = $jp_clsdecl | goto done }
    if (%v === if) { var -n %n = $jp_if | goto done }
    if (%v === for) { var -n %n = $jp_for | goto done }
    if (%v === while) { var -n %n = $jp_while | goto done }
    if (%v === do) { var -n %n = $jp_do | goto done }
    if (%v === return) { var -n %n = $jp_return | goto done }
    if (%v === break) || (%v === continue) { var -n %n = $jp_jump | goto done }
    if (%v === throw) { var -n %n = $jp_throw | goto done }
    if (%v === try) { var -n %n = $jp_try | goto done }
    if (%v === switch) { var -n %n = $jp_switch | goto done }
    if (%v === debugger) { inc %jp | noop $jp_semi | return 0 }
    if (%v === import) || (%v === export) { noop $jp_fail(import/export are not supported; use require()) | return 0 }
  }
  if (%t === i) {
    if (%v === let) {
      var -n %nt = $hget(jst,$calc( %jp + 1 ) $+ :t)
      var -n %nv = $hget(jst,$calc( %jp + 1 ) $+ :v)
      if (%nt === i) || ((%nt === p) && ((%nv === ls) || (%nv === lb))) { var -n %n = $jp_vardecl | if (!$jp_semi) { return 0 } | goto done }
    }
    if (%v === async) && ($hget(jst,$calc( %jp + 1 ) $+ :v) === function) && (!$hget(jst,$calc( %jp + 1 ) $+ :nl)) {
      inc %jp
      var -n %n = $jp_fndecl
      hadd jsa $hget(jsa,%n $+ :f) $+ :async 1
      goto done
    }
    if ($jp_peekp(1,colon)) {
      var -n %n = $jp_node(lab)
      hadd jsa %n $+ :l %v
      inc %jp 2
      hadd jsa %n $+ :b $jp_stmt
      goto done
    }
  }
  var -n %n = $jp_node(exp)
  hadd jsa %n $+ :a $jp_expr
  if (!$jp_semi) { return 0 }
  :done
  if (%n) { hadd jsa %n $+ :ln %ln }
  return %n
}

alias jp_block {
  var -n %b = $jp_node(blk)
  noop $jp_needp(lb)
  set %jpbs %jpbs %b
  var -n %list = $null
  while (!$jp_isp(rb)) && ($hget(jst,%jp $+ :t) !=== x) && (!%jperr) {
    var -n %s = $jp_stmt
    if (%s) { var -n %list = %list %s }
  }
  noop $jp_needp(rb)
  set %jpbs $deltok(%jpbs,-1,32)
  hadd jsa %b $+ :s %list
  return %b
}

; var / let / const declarations (no semicolon)
alias jp_vardecl {
  var -n %kind = $hget(jst,%jp $+ :v)
  inc %jp
  var -n %n = $jp_node(var)
  hadd jsa %n $+ :k %kind
  var -n %list = $null
  while (!%jperr) {
    var -n %d = $jp_node(decl)
    var -n %id = $jp_bindpat
    hadd jsa %d $+ :id %id
    if ($jp_eatp(asg)) { hadd jsa %d $+ :i $jp_assign }
    var -n %list = %list %d
    if (%kind === var) {
      var -n %names = $jp_patnames(%id)
      var -n %i = 1
      while (%i <= $numtok(%names,32)) {
        jp.hoistvar $gettok(%names,%i,32)
        inc %i
      }
    }
    else { hadd jsa $jp_curblk $+ :lex 1 }
    if (!$jp_eatp(comma)) { break }
  }
  hadd jsa %n $+ :d %list
  return %n
}

; binding pattern: name, [a, b = 1, ...rest] or {a, b: c, d = 2, ...rest}
alias jp_bindpat {
  var -n %t = $hget(jst,%jp $+ :t)
  if (%t === i) {
    var -n %n = $jp_node(id)
    hadd jsa %n $+ :n $hget(jst,%jp $+ :e)
    hadd jsa %n $+ :r $hget(jst,%jp $+ :v)
    inc %jp
    return %n
  }
  if ($jp_isp(ls)) {
    inc %jp
    var -n %n = $jp_node(apat)
    var -n %list = $null
    while (!$jp_isp(rs)) && (!%jperr) {
      if ($jp_isp(comma)) { inc %jp | var -n %list = %list 0 | continue }
      if ($jp_eatp(ellip)) {
        var -n %r = $jp_node(rest)
        hadd jsa %r $+ :a $jp_bindpat
        var -n %list = %list %r
      }
      else { var -n %list = %list $jp_bindelem }
      if (!$jp_isp(rs)) { noop $jp_needp(comma) }
    }
    noop $jp_needp(rs)
    hadd jsa %n $+ :e %list
    return %n
  }
  if ($jp_isp(lb)) {
    inc %jp
    var -n %n = $jp_node(opat)
    var -n %list = $null
    while (!$jp_isp(rb)) && (!%jperr) {
      if ($jp_eatp(ellip)) {
        var -n %r = $jp_node(rest)
        hadd jsa %r $+ :a $jp_bindpat
        var -n %list = %list %r
      }
      else {
        var -n %pp = $jp_node(pp)
        var -n %kt = $hget(jst,%jp $+ :t)
        if ($jp_isp(ls)) {
          inc %jp
          hadd jsa %pp $+ :c $jp_assign
          noop $jp_needp(rs)
        }
        else { hadd jsa %pp $+ :k $jp_propkey }
        if ($jp_eatp(colon)) { hadd jsa %pp $+ :v $jp_bindelem }
        else {
          ; shorthand {a} or {a = 1}
          var -n %id = $jp_node(id)
          hadd jsa %id $+ :n $hget(jsa,%pp $+ :k)
          hadd jsa %id $+ :r $js_dec($js_kdec($hget(jsa,%pp $+ :k)))
          if ($jp_eatp(asg)) {
            var -n %d = $jp_node(def)
            hadd jsa %d $+ :l %id
            hadd jsa %d $+ :r $jp_assign
            var -n %id = %d
          }
          hadd jsa %pp $+ :v %id
        }
        var -n %list = %list %pp
      }
      if (!$jp_isp(rb)) { noop $jp_needp(comma) }
    }
    noop $jp_needp(rb)
    hadd jsa %n $+ :p %list
    return %n
  }
  noop $jp_fail
  return 0
}

; pattern element with an optional default
alias jp_bindelem {
  var -n %p = $jp_bindpat
  if ($jp_eatp(asg)) {
    var -n %d = $jp_node(def)
    hadd jsa %d $+ :l %p
    hadd jsa %d $+ :r $jp_assign
    return %d
  }
  return %p
}

; property key: identifier, keyword, string or number -> case-escaped key
alias jp_propkey {
  var -n %t = $hget(jst,%jp $+ :t)
  var -n %v = $hget(jst,%jp $+ :v)
  inc %jp
  if (%t === i) || (%t === k) { return $js_kenc(%v) }
  if (%t === s) { return $js_kenc($mid(%v,2)) }
  if (%t === n) { return $js_kenc($js_numstr($mid(%v,2))) }
  dec %jp
  noop $jp_fail
  return $null
}

alias jp_if {
  inc %jp
  var -n %n = $jp_node(if)
  noop $jp_needp(lp)
  hadd jsa %n $+ :q $jp_expr
  noop $jp_needp(rp)
  hadd jsa %n $+ :a $jp_stmt
  if ($hget(jst,%jp $+ :t) === k) && ($hget(jst,%jp $+ :v) === else) {
    inc %jp
    hadd jsa %n $+ :b $jp_stmt
  }
  return %n
}

alias jp_while {
  inc %jp
  var -n %n = $jp_node(while)
  noop $jp_needp(lp)
  hadd jsa %n $+ :q $jp_expr
  noop $jp_needp(rp)
  hadd jsa %n $+ :b $jp_stmt
  return %n
}

alias jp_do {
  inc %jp
  var -n %n = $jp_node(do)
  hadd jsa %n $+ :b $jp_stmt
  if ($hget(jst,%jp $+ :v) !=== while) { noop $jp_fail | return 0 }
  inc %jp
  noop $jp_needp(lp)
  hadd jsa %n $+ :q $jp_expr
  noop $jp_needp(rp)
  noop $jp_eatp(semi)
  return %n
}

alias jp_for {
  inc %jp
  if ($hget(jst,%jp $+ :v) === await) { noop $jp_fail(for await is not supported) | return 0 }
  noop $jp_needp(lp)
  ; the head gets its own block so let/const stay inside the loop
  var -n %head = $jp_node(blk)
  var -n %fnbefore = %jpnfn
  set %jpbs %jpbs %head
  var -n %init = 0
  var -n %t = $hget(jst,%jp $+ :t)
  var -n %v = $hget(jst,%jp $+ :v)
  set %jpnoin 1
  var -n %islet = 0
  if (%t === i) && (%v === let) {
    var -n %nt = $hget(jst,$calc( %jp + 1 ) $+ :t)
    var -n %nv = $hget(jst,$calc( %jp + 1 ) $+ :v)
    if (%nt === i) || ((%nt === p) && ((%nv === ls) || (%nv === lb))) { var -n %islet = 1 }
  }
  if ((%t === k) && ((%v === var) || (%v === const))) || (%islet) { var -n %init = $jp_vardecl }
  elseif (!$jp_isp(semi)) { var -n %init = $jp_expr }
  unset %jpnoin
  var -n %t = $hget(jst,%jp $+ :t)
  var -n %v = $hget(jst,%jp $+ :v)
  if ((%t === k) && (%v === in)) || ((%t === i) && (%v === of)) {
    inc %jp
    var -n %n = $jp_node(forin)
    hadd jsa %n $+ :of $iif(%v === of,1,0)
    if ($hget(jsa,%init $+ :t) !=== var) { noop $jp_topat(%init) }
    hadd jsa %n $+ :l %init
    hadd jsa %n $+ :r $iif(%v === of,$jp_assign,$jp_expr)
    noop $jp_needp(rp)
    hadd jsa %n $+ :b $jp_stmt
  }
  else {
    var -n %n = $jp_node(for)
    hadd jsa %n $+ :i %init
    noop $jp_needp(semi)
    if (!$jp_isp(semi)) { hadd jsa %n $+ :q $jp_expr }
    noop $jp_needp(semi)
    if (!$jp_isp(rp)) { hadd jsa %n $+ :u $jp_expr }
    noop $jp_needp(rp)
    hadd jsa %n $+ :b $jp_stmt
  }
  set %jpbs $deltok(%jpbs,-1,32)
  if ($hget(jsa,%head $+ :lex)) { hadd jsa %n $+ :lex 1 }
  ; only loops whose body makes closures need a fresh scope per iteration
  if (%jpnfn != %fnbefore) { hadd jsa %n $+ :cpy 1 }
  return %n
}

alias jp_return {
  inc %jp
  var -n %n = $jp_node(ret)
  if (!$jp_isp(semi)) && (!$jp_isp(rb)) && ($hget(jst,%jp $+ :t) !=== x) && (!$hget(jst,%jp $+ :nl)) { hadd jsa %n $+ :a $jp_expr }
  noop $jp_semi
  return %n
}

alias jp_jump {
  var -n %n = $jp_node($iif($hget(jst,%jp $+ :v) === break,brk,cnt))
  inc %jp
  if ($hget(jst,%jp $+ :t) === i) && (!$hget(jst,%jp $+ :nl)) {
    hadd jsa %n $+ :l $hget(jst,%jp $+ :v)
    inc %jp
  }
  noop $jp_semi
  return %n
}

alias jp_throw {
  inc %jp
  var -n %n = $jp_node(thr)
  if ($hget(jst,%jp $+ :nl)) { noop $jp_fail(Illegal newline after throw) | return 0 }
  hadd jsa %n $+ :a $jp_expr
  noop $jp_semi
  return %n
}

alias jp_try {
  inc %jp
  var -n %n = $jp_node(try)
  hadd jsa %n $+ :b $jp_block
  if ($hget(jst,%jp $+ :v) === catch) && ($hget(jst,%jp $+ :t) === k) {
    inc %jp
    if ($jp_eatp(lp)) {
      hadd jsa %n $+ :p $jp_bindpat
      noop $jp_needp(rp)
    }
    hadd jsa %n $+ :h $jp_block
  }
  if ($hget(jst,%jp $+ :v) === finally) && ($hget(jst,%jp $+ :t) === k) {
    inc %jp
    hadd jsa %n $+ :f $jp_block
  }
  if (!$hget(jsa,%n $+ :h)) && (!$hget(jsa,%n $+ :f)) { noop $jp_fail(Missing catch or finally after try) }
  return %n
}

alias jp_switch {
  inc %jp
  var -n %n = $jp_node(sw)
  noop $jp_needp(lp)
  hadd jsa %n $+ :d $jp_expr
  noop $jp_needp(rp)
  noop $jp_needp(lb)
  set %jpbs %jpbs %n
  var -n %cases = $null
  while (!$jp_isp(rb)) && ($hget(jst,%jp $+ :t) !=== x) && (!%jperr) {
    var -n %c = $jp_node(case)
    if ($hget(jst,%jp $+ :v) === default) && ($hget(jst,%jp $+ :t) === k) { inc %jp | hadd jsa %c $+ :q 0 }
    elseif ($hget(jst,%jp $+ :v) === case) && ($hget(jst,%jp $+ :t) === k) { inc %jp | hadd jsa %c $+ :q $jp_expr }
    else { noop $jp_fail | break }
    noop $jp_needp(colon)
    var -n %list = $null
    while (!$jp_isp(rb)) && ($hget(jst,%jp $+ :t) !=== x) && (!%jperr) {
      if ($hget(jst,%jp $+ :t) === k) && (($hget(jst,%jp $+ :v) === case) || ($hget(jst,%jp $+ :v) === default)) { break }
      var -n %s = $jp_stmt
      if (%s) { var -n %list = %list %s }
    }
    hadd jsa %c $+ :s %list
    var -n %cases = %cases %c
  }
  noop $jp_needp(rb)
  set %jpbs $deltok(%jpbs,-1,32)
  hadd jsa %n $+ :c %cases
  return %n
}

; ----------------------------------------------------------------- functions --

; function name(...) {...} as a statement
alias jp_fndecl {
  inc %jp
  if ($jp_isp(mul)) { noop $jp_fail(Generators are not supported) | return 0 }
  if ($hget(jst,%jp $+ :t) !=== i) { noop $jp_fail | return 0 }
  var -n %key = $hget(jst,%jp $+ :e)
  var -n %name = $hget(jst,%jp $+ :v)
  inc %jp
  var -n %f = $jp_function(%name)
  var -n %d = $jp_node(fnd)
  hadd jsa %d $+ :k %key
  hadd jsa %d $+ :f %f
  var -n %cf = $jp_curfn
  hadd jsa %cf $+ :hf $hget(jsa,%cf $+ :hf) %d
  return %d
}

; parameters and body after the name: $jp_function(display name[,method])
alias jp_function {
  var -n %f = $jp_node(fn)
  inc %jpnfn
  hadd jsa %f $+ :nm $js_enc($1)
  if ($2) { hadd jsa %f $+ :meth 1 }
  set %jpfs %jpfs %f
  noop $jp_needp(lp)
  noop $jp_params(%f,rp)
  hadd jsa %f $+ :b $jp_fnbody
  set %jpfs $deltok(%jpfs,-1,32)
  return %f
}

; parameter list up to the closing punctuator $2
alias jp_params {
  var -n %list = $null
  var -n %np = 0
  var -n %simple = 1
  while (!$jp_isp($2)) && (!%jperr) {
    if ($jp_eatp(ellip)) {
      var -n %r = $jp_node(rest)
      hadd jsa %r $+ :a $jp_bindpat
      var -n %list = %list %r
      var -n %simple = 0
    }
    else {
      var -n %p = $jp_bindelem
      var -n %list = %list %p
      if ($hget(jsa,%p $+ :t) === def) { var -n %simple = 0 }
      if (%simple) { inc %np }
    }
    if (!$jp_isp($2)) { noop $jp_needp(comma) }
  }
  noop $jp_needp($2)
  hadd jsa $1 $+ :ps %list
  hadd jsa $1 $+ :np %np
}

; { statements } of a function, as its own block
alias jp_fnbody {
  var -n %b = $jp_node(blk)
  noop $jp_needp(lb)
  set %jpbs %jpbs %b
  var -n %list = $null
  while (!$jp_isp(rb)) && ($hget(jst,%jp $+ :t) !=== x) && (!%jperr) {
    var -n %s = $jp_stmt
    if (%s) { var -n %list = %list %s }
  }
  noop $jp_needp(rb)
  set %jpbs $deltok(%jpbs,-1,32)
  hadd jsa %b $+ :s %list
  ; the function scope already isolates its body
  hdel jsa %b $+ :lex
  return %b
}

; is the ( at %jp the start of arrow parameters? (look for ) =>)
alias jp_isarrow {
  var -n %i = %jp
  var -n %depth = 0
  while (1) {
    var -n %t = $hget(jst,%i $+ :t)
    var -n %v = $hget(jst,%i $+ :v)
    if (%t === x) { return 0 }
    if (%t === p) {
      if (%v === lp) || (%v === ls) || (%v === lb) { inc %depth }
      elseif (%v === rp) || (%v === rs) || (%v === rb) {
        dec %depth
        if (%depth == 0) {
          inc %i
          return $iif($hget(jst,%i $+ :t) === p && $hget(jst,%i $+ :v) === arrow && !$hget(jst,%i $+ :nl),1,0)
        }
      }
    }
    inc %i
  }
}

; an arrow function; %jp is at its parameters
alias jp_arrow {
  var -n %f = $jp_node(fn)
  inc %jpnfn
  hadd jsa %f $+ :arrow 1
  hadd jsa %f $+ :nm $null
  if ($hget(jst,%jp $+ :t) === i) {
    var -n %p = $jp_node(id)
    hadd jsa %p $+ :n $hget(jst,%jp $+ :e)
    hadd jsa %p $+ :r $hget(jst,%jp $+ :v)
    inc %jp
    hadd jsa %f $+ :ps %p
    hadd jsa %f $+ :np 1
  }
  else {
    noop $jp_needp(lp)
    noop $jp_params(%f,rp)
  }
  noop $jp_needp(arrow)
  set %jpfs %jpfs %f
  if ($jp_isp(lb)) { hadd jsa %f $+ :b $jp_fnbody }
  else {
    hadd jsa %f $+ :ex 1
    var -n %save = %jpnoin
    unset %jpnoin
    hadd jsa %f $+ :b $jp_assign
    if (%save) { set %jpnoin %save }
  }
  set %jpfs $deltok(%jpfs,-1,32)
  ; arrows see the enclosing function's arguments
  if ($hget(jsa,%f $+ :ua)) { hadd jsa $jp_curfn $+ :ua 1 }
  return %f
}

; ------------------------------------------------------------------ classes --

alias jp_clsdecl {
  var -n %c = $jp_class
  var -n %d = $jp_node(clsd)
  hadd jsa %d $+ :k $hget(jsa,%c $+ :k)
  hadd jsa %d $+ :c %c
  hadd jsa $jp_curblk $+ :lex 1
  return %d
}

; class [name] [extends expr] { members }
alias jp_class {
  inc %jp
  var -n %c = $jp_node(cls)
  if ($hget(jst,%jp $+ :t) === i) && ($hget(jst,%jp $+ :v) !=== extends) {
    hadd jsa %c $+ :k $hget(jst,%jp $+ :e)
    hadd jsa %c $+ :nm $js_enc($hget(jst,%jp $+ :v))
    inc %jp
  }
  if ($hget(jst,%jp $+ :t) === k) && ($hget(jst,%jp $+ :v) === extends) {
    inc %jp
    hadd jsa %c $+ :sup $jp_lhs
  }
  noop $jp_needp(lb)
  var -n %members = $null
  while (!$jp_isp(rb)) && ($hget(jst,%jp $+ :t) !=== x) && (!%jperr) {
    if ($jp_eatp(semi)) { continue }
    var -n %m = $jp_node(md)
    hadd jsa %m $+ :kind method
    if ($hget(jst,%jp $+ :v) === static) && (!$jp_peekp(1,lp)) && (!$jp_peekp(1,asg)) {
      inc %jp
      hadd jsa %m $+ :st 1
      if ($jp_isp(lb)) {
        ; static { } initialisation block
        var -n %f = $jp_node(fn)
        hadd jsa %f $+ :meth 1
        set %jpfs %jpfs %f
        hadd jsa %f $+ :b $jp_fnbody
        set %jpfs $deltok(%jpfs,-1,32)
        hadd jsa %m $+ :kind sblock
        hadd jsa %m $+ :v %f
        var -n %members = %members %m
        continue
      }
    }
    if ($hget(jst,%jp $+ :v) === async) && (!$jp_peekp(1,lp)) && (!$hget(jst,$calc( %jp + 1 ) $+ :nl)) {
      inc %jp
      hadd jsa %m $+ :async 1
    }
    if ($jp_isp(mul)) { noop $jp_fail(Generators are not supported) | return 0 }
    var -n %gv = $hget(jst,%jp $+ :v)
    if ((%gv === get) || (%gv === set)) && ($hget(jst,%jp $+ :t) === i) && (!$jp_peekp(1,lp)) && (!$jp_peekp(1,asg)) && (!$jp_peekp(1,semi)) {
      inc %jp
      hadd jsa %m $+ :kind %gv
    }
    var -n %disp = $null
    if ($jp_isp(ls)) {
      inc %jp
      hadd jsa %m $+ :c $jp_assign
      noop $jp_needp(rs)
    }
    else {
      var -n %disp = $hget(jst,%jp $+ :v)
      if ($hget(jst,%jp $+ :t) === s) { var -n %disp = $js_dec($mid(%disp,2)) }
      hadd jsa %m $+ :k $jp_propkey
    }
    if ($jp_isp(lp)) {
      var -n %isctor = $iif(!$hget(jsa,%m $+ :st) && !$hget(jsa,%m $+ :c) && $hget(jsa,%m $+ :k) === constructor,1,0)
      var -n %f = $jp_function(%disp,$iif(%isctor,0,1))
      if ($hget(jsa,%m $+ :async)) { hadd jsa %f $+ :async 1 }
      if (%isctor) { hadd jsa %c $+ :ctor %f | continue }
      hadd jsa %m $+ :v %f
    }
    else {
      ; a field: name [= value];
      hadd jsa %m $+ :kind field
      if ($jp_eatp(asg)) {
        var -n %f = $jp_node(fn)
        hadd jsa %f $+ :meth 1
        set %jpfs %jpfs %f
        hadd jsa %m $+ :v $jp_assign
        set %jpfs $deltok(%jpfs,-1,32)
      }
      noop $jp_semi
    }
    var -n %members = %members %m
  }
  noop $jp_needp(rb)
  hadd jsa %c $+ :m %members
  return %c
}

; -------------------------------------------------------------- expressions --

alias jp_expr {
  var -n %e = $jp_assign
  if (!$jp_isp(comma)) { return %e }
  var -n %n = $jp_node(seq)
  var -n %list = %e
  while ($jp_eatp(comma)) && (!%jperr) { var -n %list = %list $jp_assign }
  hadd jsa %n $+ :e %list
  return %n
}

alias jp_assign {
  var -n %t = $hget(jst,%jp $+ :t)
  ; arrow functions: x => ..., (a, b) => ..., async x => ...
  if (%t === i) && ($hget(jst,%jp $+ :v) === async) && (!$hget(jst,$calc( %jp + 1 ) $+ :nl)) {
    var -n %nt = $hget(jst,$calc( %jp + 1 ) $+ :t)
    if ((%nt === i) && ($jp_peekp(2,arrow))) || ((%nt === p) && ($hget(jst,$calc( %jp + 1 ) $+ :v) === lp) && ($jp_isarrowat($calc( %jp + 1 )))) {
      inc %jp
      var -n %f = $jp_arrow
      hadd jsa %f $+ :async 1
      return %f
    }
  }
  if (%t === i) && ($jp_peekp(1,arrow)) && (!$hget(jst,$calc( %jp + 1 ) $+ :nl)) { return $jp_arrow }
  if (%t === p) && ($hget(jst,%jp $+ :v) === lp) && ($jp_isarrow) { return $jp_arrow }
  if (%t === i) && ($hget(jst,%jp $+ :v) === yield) { noop $jp_fail(Generators are not supported) | return 0 }
  var -n %left = $jp_cond
  if ($hget(jst,%jp $+ :t) === p) {
    var -n %op = $hget(jsm,as. $+ $hget(jst,%jp $+ :v))
    if (%op != $null) {
      inc %jp
      var -n %n = $jp_node(asg)
      hadd jsa %n $+ :o $iif(%op === =,asg,%op)
      if (%op === =) { noop $jp_topat(%left) }
      hadd jsa %n $+ :l %left
      hadd jsa %n $+ :r $jp_assign
      ; name anonymous functions after what they are assigned to
      if ($hget(jsa,%left $+ :t) === id) { noop $jp_namefn($hget(jsa,%n $+ :r),$hget(jsa,%left $+ :r)) }
      return %n
    }
  }
  return %left
}

alias jp_isarrowat {
  var -n %save = %jp
  set %jp $1
  var -n %r = $jp_isarrow
  set %jp %save
  return %r
}

; give an anonymous function or class a name
alias jp_namefn {
  var -n %t = $hget(jsa,$1 $+ :t)
  if (%t === fn) || (%t === cls) {
    if ($hget(jsa,$1 $+ :nm) == $null) { hadd jsa $1 $+ :nm $js_enc($2) }
  }
}

alias jp_cond {
  var -n %q = $jp_bin(0)
  if (!$jp_isp(qm)) { return %q }
  inc %jp
  var -n %n = $jp_node(cond)
  hadd jsa %n $+ :q %q
  var -n %save = %jpnoin
  unset %jpnoin
  hadd jsa %n $+ :a $jp_assign
  if (%save) { set %jpnoin %save }
  noop $jp_needp(colon)
  hadd jsa %n $+ :b $jp_assign
  return %n
}

; precedence climbing: binary operators stronger than $1
alias jp_bin {
  var -n %min = $1
  var -n %left = $jp_unary
  while (!%jperr) {
    var -n %t = $hget(jst,%jp $+ :t)
    var -n %op = $null
    if (%t === p) { var -n %op = $hget(jst,%jp $+ :v) }
    elseif (%t === k) {
      var -n %op = $hget(jst,%jp $+ :v)
      if (%op === in) && (%jpnoin) { break }
      if (%op !=== in) && (%op !=== instanceof) { break }
    }
    else { break }
    var -n %prec = $hget(jsm,bp. $+ %op)
    if (%prec == $null) || (%prec <= %min) { break }
    inc %jp
    ; ** is right-associative
    var -n %right = $jp_bin($iif(%op === exp,$calc( %prec - 1 ),%prec))
    var -n %n = $jp_node($iif(%op === and || %op === or || %op === nc,log,bin))
    hadd jsa %n $+ :o %op
    hadd jsa %n $+ :l %left
    hadd jsa %n $+ :r %right
    var -n %left = %n
  }
  return %left
}

alias jp_unary {
  var -n %t = $hget(jst,%jp $+ :t)
  var -n %v = $hget(jst,%jp $+ :v)
  if (%t === p) {
    if (%v === not) || (%v === bnot) || (%v === add) || (%v === sub) {
      inc %jp
      var -n %n = $jp_node(un)
      hadd jsa %n $+ :o %v
      hadd jsa %n $+ :a $jp_unary
      if ($jp_isp(exp)) { noop $jp_fail(Unary operator before ** needs parentheses) }
      return %n
    }
    if (%v === inc) || (%v === dec) {
      inc %jp
      var -n %n = $jp_node(upd)
      hadd jsa %n $+ :o %v
      hadd jsa %n $+ :pre 1
      hadd jsa %n $+ :a $jp_unary
      return %n
    }
  }
  if (%t === k) && ((%v === typeof) || (%v === void) || (%v === delete)) {
    inc %jp
    var -n %n = $jp_node(un)
    hadd jsa %n $+ :o %v
    hadd jsa %n $+ :a $jp_unary
    return %n
  }
  if (%t === i) && (%v === await) {
    inc %jp
    var -n %n = $jp_node(await)
    hadd jsa %n $+ :a $jp_unary
    return %n
  }
  var -n %e = $jp_lhs
  if ($hget(jst,%jp $+ :t) === p) && (!$hget(jst,%jp $+ :nl)) {
    var -n %v = $hget(jst,%jp $+ :v)
    if (%v === inc) || (%v === dec) {
      inc %jp
      var -n %n = $jp_node(upd)
      hadd jsa %n $+ :o %v
      hadd jsa %n $+ :a %e
      return %n
    }
  }
  return %e
}

; member access, calls, new, optional chains, tagged templates
alias jp_lhs {
  var -n %e = 0
  var -n %ln = $hget(jst,%jp $+ :ln)
  if ($hget(jst,%jp $+ :t) === k) && ($hget(jst,%jp $+ :v) === new) { var -n %e = $jp_new }
  else { var -n %e = $jp_primary }
  var -n %chain = 0
  while (!%jperr) {
    var -n %t = $hget(jst,%jp $+ :t)
    var -n %v = $hget(jst,%jp $+ :v)
    if (%t === p) && (%v === dot) {
      inc %jp
      var -n %n = $jp_node($iif($hget(jsa,%e $+ :t) === super,supm,mem))
      hadd jsa %n $+ :o %e
      hadd jsa %n $+ :k $jp_dotname
      if (%chain) { hadd jsa %n $+ :ch 1 }
      var -n %e = %n
      continue
    }
    if (%t === p) && (%v === optc) {
      inc %jp
      var -n %chain = 1
      if ($jp_isp(lp)) {
        var -n %n = $jp_node(call)
        hadd jsa %n $+ :f %e
        hadd jsa %n $+ :a $jp_args
      }
      elseif ($jp_eatp(ls)) {
        var -n %n = $jp_node(mem)
        hadd jsa %n $+ :o %e
        hadd jsa %n $+ :c $jp_expr
        noop $jp_needp(rs)
      }
      else {
        var -n %n = $jp_node(mem)
        hadd jsa %n $+ :o %e
        hadd jsa %n $+ :k $jp_dotname
      }
      hadd jsa %n $+ :opt 1
      hadd jsa %n $+ :ch 1
      hadd jsa %n $+ :ln %ln
      var -n %e = %n
      continue
    }
    if (%t === p) && (%v === ls) {
      inc %jp
      var -n %n = $jp_node($iif($hget(jsa,%e $+ :t) === super,supm,mem))
      hadd jsa %n $+ :o %e
      var -n %save = %jpnoin
      unset %jpnoin
      hadd jsa %n $+ :c $jp_expr
      if (%save) { set %jpnoin %save }
      noop $jp_needp(rs)
      if (%chain) { hadd jsa %n $+ :ch 1 }
      var -n %e = %n
      continue
    }
    if (%t === p) && (%v === lp) {
      var -n %n = $jp_node($iif($hget(jsa,%e $+ :t) === super,supc,call))
      hadd jsa %n $+ :f %e
      hadd jsa %n $+ :a $jp_args
      hadd jsa %n $+ :ln %ln
      if (%chain) { hadd jsa %n $+ :ch 1 }
      var -n %e = %n
      continue
    }
    if (%t === q) && (($hget(jst,%jp $+ :k) === f) || ($hget(jst,%jp $+ :k) === h)) {
      var -n %n = $jp_node(tag)
      hadd jsa %n $+ :f %e
      hadd jsa %n $+ :q $jp_template
      hadd jsa %n $+ :ln %ln
      var -n %e = %n
      continue
    }
    break
  }
  if (%chain) { hadd jsa %e $+ :che 1 }
  return %e
}

; the name after . (identifiers, keywords and #private names)
alias jp_dotname {
  var -n %t = $hget(jst,%jp $+ :t)
  if (%t === i) || (%t === k) {
    var -n %k = $js_kenc($hget(jst,%jp $+ :v))
    inc %jp
    return %k
  }
  noop $jp_fail
  return $null
}

; new X(args), new X, new.target
alias jp_new {
  inc %jp
  if ($jp_eatp(dot)) {
    if ($hget(jst,%jp $+ :v) !=== target) { noop $jp_fail | return 0 }
    inc %jp
    return $jp_node(nt)
  }
  var -n %n = $jp_node(new)
  hadd jsa %n $+ :ln $hget(jst,%jp $+ :ln)
  ; the callee: a member expression without calls
  var -n %f = 0
  if ($hget(jst,%jp $+ :t) === k) && ($hget(jst,%jp $+ :v) === new) { var -n %f = $jp_new }
  else { var -n %f = $jp_primary }
  while (!%jperr) {
    if ($jp_eatp(dot)) {
      var -n %m = $jp_node(mem)
      hadd jsa %m $+ :o %f
      hadd jsa %m $+ :k $jp_dotname
      var -n %f = %m
      continue
    }
    if ($jp_eatp(ls)) {
      var -n %m = $jp_node(mem)
      hadd jsa %m $+ :o %f
      hadd jsa %m $+ :c $jp_expr
      noop $jp_needp(rs)
      var -n %f = %m
      continue
    }
    break
  }
  hadd jsa %n $+ :f %f
  if ($jp_isp(lp)) { hadd jsa %n $+ :a $jp_args }
  return %n
}

; ( args ) with spread
alias jp_args {
  noop $jp_needp(lp)
  var -n %list = $null
  var -n %save = %jpnoin
  unset %jpnoin
  while (!$jp_isp(rp)) && (!%jperr) {
    if ($jp_eatp(ellip)) {
      var -n %s = $jp_node(spread)
      hadd jsa %s $+ :a $jp_assign
      var -n %list = %list %s
    }
    else { var -n %list = %list $jp_assign }
    if (!$jp_isp(rp)) { noop $jp_needp(comma) }
  }
  if (%save) { set %jpnoin %save }
  noop $jp_needp(rp)
  return %list
}

; template literal -> tpl node with :q (string tokens) and :e (expressions)
alias jp_template {
  var -n %n = $jp_node(tpl)
  var -n %qs = $hget(jst,%jp $+ :v)
  var -n %es = $null
  var -n %kind = $hget(jst,%jp $+ :k)
  inc %jp
  if (%kind === h) {
    while (!%jperr) {
      var -n %es = %es $jp_expr
      if ($hget(jst,%jp $+ :t) !=== q) { noop $jp_fail | break }
      var -n %qs = %qs $hget(jst,%jp $+ :v)
      var -n %k = $hget(jst,%jp $+ :k)
      inc %jp
      if (%k === t) { break }
    }
  }
  hadd jsa %n $+ :q %qs
  hadd jsa %n $+ :e %es
  return %n
}

alias jp_primary {
  var -n %t = $hget(jst,%jp $+ :t)
  var -n %v = $hget(jst,%jp $+ :v)
  if (%t === i) {
    if (%v === async) && ($hget(jst,$calc( %jp + 1 ) $+ :v) === function) && (!$hget(jst,$calc( %jp + 1 ) $+ :nl)) {
      inc %jp
      var -n %f = $jp_fnexpr
      hadd jsa %f $+ :async 1
      return %f
    }
    var -n %n = $jp_node(id)
    hadd jsa %n $+ :n $hget(jst,%jp $+ :e)
    hadd jsa %n $+ :r %v
    if (%v === arguments) { hadd jsa $jp_curfn $+ :ua 1 }
    inc %jp
    return %n
  }
  if (%t === n) || (%t === s) {
    var -n %n = $jp_node(lit)
    hadd jsa %n $+ :v %v
    inc %jp
    return %n
  }
  if (%t === q) { return $jp_template }
  if (%t === r) {
    var -n %n = $jp_node(rx)
    hadd jsa %n $+ :v %v
    hadd jsa %n $+ :f $hget(jst,%jp $+ :f)
    inc %jp
    return %n
  }
  if (%t === k) {
    if (%v === this) { inc %jp | return $jp_node(this) }
    if (%v === null) || (%v === true) || (%v === false) {
      var -n %n = $jp_node(lit)
      hadd jsa %n $+ :v $iif(%v === null,z,$iif(%v === true,t,f))
      inc %jp
      return %n
    }
    if (%v === function) { return $jp_fnexpr }
    if (%v === class) { return $jp_class }
    if (%v === super) { inc %jp | return $jp_node(super) }
    if (%v === new) { return $jp_new }
  }
  if (%t === p) {
    if (%v === lp) {
      inc %jp
      var -n %save = %jpnoin
      unset %jpnoin
      var -n %e = $jp_expr
      if (%save) { set %jpnoin %save }
      noop $jp_needp(rp)
      return %e
    }
    if (%v === ls) { return $jp_array }
    if (%v === lb) { return $jp_object }
  }
  noop $jp_fail
  return 0
}

; function [name] (...) {...} as an expression
alias jp_fnexpr {
  inc %jp
  if ($jp_isp(mul)) { noop $jp_fail(Generators are not supported) | return 0 }
  var -n %name = $null
  if ($hget(jst,%jp $+ :t) === i) {
    var -n %name = $hget(jst,%jp $+ :v)
    var -n %key = $hget(jst,%jp $+ :e)
    inc %jp
  }
  var -n %f = $jp_function(%name)
  ; a named function expression can call itself
  if (%name != $null) { hadd jsa %f $+ :self %key }
  return %f
}

alias jp_array {
  inc %jp
  var -n %n = $jp_node(arr)
  var -n %list = $null
  var -n %save = %jpnoin
  unset %jpnoin
  while (!$jp_isp(rs)) && (!%jperr) {
    if ($jp_isp(comma)) { inc %jp | var -n %list = %list 0 | continue }
    if ($jp_eatp(ellip)) {
      var -n %s = $jp_node(spread)
      hadd jsa %s $+ :a $jp_assign
      var -n %list = %list %s
    }
    else { var -n %list = %list $jp_assign }
    if (!$jp_isp(rs)) { noop $jp_needp(comma) }
  }
  if (%save) { set %jpnoin %save }
  noop $jp_needp(rs)
  hadd jsa %n $+ :e %list
  return %n
}

alias jp_object {
  inc %jp
  var -n %n = $jp_node(obj)
  var -n %list = $null
  var -n %save = %jpnoin
  unset %jpnoin
  while (!$jp_isp(rb)) && (!%jperr) {
    var -n %pp = $jp_node(pp)
    hadd jsa %pp $+ :kind init
    if ($jp_eatp(ellip)) {
      hadd jsa %pp $+ :kind spread
      hadd jsa %pp $+ :v $jp_assign
      var -n %list = %list %pp
      if (!$jp_isp(rb)) { noop $jp_needp(comma) }
      continue
    }
    var -n %async = 0
    if ($hget(jst,%jp $+ :v) === async) && ($hget(jst,%jp $+ :t) === i) && (!$jp_peekp(1,lp)) && (!$jp_peekp(1,colon)) && (!$jp_peekp(1,comma)) && (!$jp_peekp(1,rb)) {
      inc %jp
      var -n %async = 1
    }
    var -n %gv = $hget(jst,%jp $+ :v)
    if ((%gv === get) || (%gv === set)) && ($hget(jst,%jp $+ :t) === i) && (!$jp_peekp(1,lp)) && (!$jp_peekp(1,colon)) && (!$jp_peekp(1,comma)) && (!$jp_peekp(1,rb)) {
      inc %jp
      hadd jsa %pp $+ :kind %gv
    }
    var -n %disp = $null
    var -n %isid = 0
    if ($jp_isp(ls)) {
      inc %jp
      hadd jsa %pp $+ :c $jp_assign
      noop $jp_needp(rs)
    }
    else {
      var -n %disp = $hget(jst,%jp $+ :v)
      var -n %isid = $iif($hget(jst,%jp $+ :t) === i,1,0)
      if ($hget(jst,%jp $+ :t) === s) { var -n %disp = $js_dec($mid(%disp,2)) }
      hadd jsa %pp $+ :k $jp_propkey
    }
    if ($jp_isp(lp)) {
      var -n %f = $jp_function(%disp,1)
      if (%async) { hadd jsa %f $+ :async 1 }
      hadd jsa %pp $+ :v %f
      hadd jsa %pp $+ :home 1
    }
    elseif ($jp_eatp(colon)) {
      hadd jsa %pp $+ :v $jp_assign
      noop $jp_namefn($hget(jsa,%pp $+ :v),%disp)
    }
    elseif (%isid) {
      ; shorthand {a} or (in patterns) {a = 1}
      var -n %id = $jp_node(id)
      hadd jsa %id $+ :n $hget(jsa,%pp $+ :k)
      hadd jsa %id $+ :r %disp
      if ($jp_isp(asg)) {
        inc %jp
        var -n %a = $jp_node(asg)
        hadd jsa %a $+ :o asg
        hadd jsa %a $+ :l %id
        hadd jsa %a $+ :r $jp_assign
        var -n %id = %a
      }
      hadd jsa %pp $+ :v %id
    }
    else { noop $jp_fail | break }
    var -n %list = %list %pp
    if (!$jp_isp(rb)) { noop $jp_needp(comma) }
  }
  if (%save) { set %jpnoin %save }
  noop $jp_needp(rb)
  hadd jsa %n $+ :p %list
  return %n
}
