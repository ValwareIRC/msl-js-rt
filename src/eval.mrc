; ============================================================================
;  msl-js-rt: evaluator - runs syntax trees
; ============================================================================
;
; $js_ev(node,env) evaluates an expression and returns a value token.
; $js_ex(node,env[,labels]) runs a statement; it returns nothing and leaves
; any break/continue/return/throw in %jsc. Both dispatch on the node type
; with goto, which keeps the mSL call depth per JavaScript call small.

; ------------------------------------------------------------ expressions --

alias js_ev {
  var -n %n = $1
  var -n %env = $2
  goto $+(e_,$hget(jsa,%n $+ :t))

  :e_lit
  return $hget(jsa,%n $+ :v)

  :e_id
  var -n %k = $hget(jsa,%n $+ :n)
  var -n %e = %env
  while (%e) {
    var -n %v = $hget(jse,%e $+ . $+ %k)
    if (%v != $null) { return %v }
    var -n %e = $hget(jse,%e $+ :p)
  }
  return $js_throw(ReferenceError,$hget(jsa,%n $+ :r) is not defined)

  :e_this
  return $js_this(%env)

  :e_nt
  var -n %e = %env
  while (%e) {
    if ($hget(jse,%e $+ :fo) != $null) { return $iif($hget(jse,%e $+ :nt),$v1,u) }
    var -n %e = $hget(jse,%e $+ :p)
  }
  return u

  :e_tpl
  var -n %qs = $hget(jsa,%n $+ :q)
  var -n %es = $hget(jsa,%n $+ :e)
  var -n %s = $mid($gettok(%qs,1,32),2)
  var -n %i = 1
  while (%i <= $numtok(%es,32)) {
    var -n %v = $js_ev($gettok(%es,%i,32),%env)
    if (%jsc) { return u }
    var -n %s = %s $+ $js_tostr(%v)
    if (%jsc) { return u }
    var -n %s = %s $+ $mid($gettok(%qs,$calc( %i + 1 ),32),2)
    inc %i
  }
  return s $+ %s

  :e_arr
  var -n %a = $js_newarr($null)
  var -n %id = $mid(%a,2)
  var -n %es = $hget(jsa,%n $+ :e)
  var -n %len = 0
  var -n %i = 1
  while (%i <= $numtok(%es,32)) {
    var -n %el = $gettok(%es,%i,32)
    if (!%el) { inc %len }
    elseif ($hget(jsa,%el $+ :t) === spread) {
      var -n %src = $js_ev($hget(jsa,%el $+ :a),%env)
      if (%jsc) { return u }
      var -n %list = $js_iterlist(%src)
      if (%jsc) { return u }
      var -n %j = 1
      while (%j <= $numtok(%list,32)) {
        hadd jso %id $+ . $+ %len $gettok(%list,%j,32)
        inc %len
        inc %j
      }
    }
    else {
      var -n %v = $js_ev(%el,%env)
      if (%jsc) { return u }
      hadd jso %id $+ . $+ %len %v
      inc %len
    }
    inc %i
  }
  hadd jso %id $+ :len %len
  return %a

  :e_obj
  var -n %o = $js_newobj
  var -n %ps = $hget(jsa,%n $+ :p)
  var -n %i = 1
  while (%i <= $numtok(%ps,32)) {
    var -n %pp = $gettok(%ps,%i,32)
    var -n %kind = $hget(jsa,%pp $+ :kind)
    if (%kind === spread) {
      var -n %src = $js_ev($hget(jsa,%pp $+ :v),%env)
      if (%jsc) { return u }
      noop $js_assignprops(%o,%src)
      inc %i
      continue
    }
    var -n %k = $hget(jsa,%pp $+ :k)
    if ($hget(jsa,%pp $+ :c)) {
      var -n %k = $js_tokey($js_ev($hget(jsa,%pp $+ :c),%env))
      if (%jsc) { return u }
    }
    var -n %v = $js_ev($hget(jsa,%pp $+ :v),%env)
    if (%jsc) { return u }
    if ($hget(jsa,%pp $+ :home)) { hadd jso $mid(%v,2) $+ :home %o }
    if (%kind === get) { noop $js_defacc(%o,%k,%v,0,1) }
    elseif (%kind === set) { noop $js_defacc(%o,%k,0,%v,1) }
    elseif (%k === __proto__) && (!$hget(jsa,%pp $+ :c)) {
      if ($left(%v,1) === o) || (%v === z) { hadd jso $mid(%o,2) $+ :p %v }
    }
    else { noop $js_put(%o,%k,%v) }
    inc %i
  }
  return %o

  :e_fn
  if ($hget(jsa,%n $+ :self)) {
    var -n %e2 = $js_newenv(%env)
    var -n %f = $js_closure(%n,%e2)
    noop $js_decl(%e2,$hget(jsa,%n $+ :self),%f)
    return %f
  }
  return $js_closure(%n,%env)

  :e_cls
  return $js_mkclass(%n,%env)

  :e_un
  var -n %o = $hget(jsa,%n $+ :o)
  var -n %an = $hget(jsa,%n $+ :a)
  if (%o === typeof) {
    if ($hget(jsa,%an $+ :t) === id) && (!$js_where(%env,$hget(jsa,%an $+ :n))) { return sundefined }
    var -n %v = $js_ev(%an,%env)
    if (%jsc) { return u }
    return s $+ $js_typeof(%v)
  }
  if (%o === delete) {
    var -n %at = $hget(jsa,%an $+ :t)
    if (%at === mem) {
      var -n %obj = $js_ev($hget(jsa,%an $+ :o),%env)
      if (%jsc) { return u }
      var -n %k = $hget(jsa,%an $+ :k)
      if ($hget(jsa,%an $+ :c)) { var -n %k = $js_tokey($js_ev($hget(jsa,%an $+ :c),%env)) }
      if (%jsc) { return u }
      if ($js_isarr(%obj)) && ($regex(%k,/^(0|[1-9]\d*)$/)) { hdel jso $mid(%obj,2) $+ . $+ %k | return t }
      noop $js_delete(%obj,%k)
      return t
    }
    return t
  }
  var -n %v = $js_ev(%an,%env)
  if (%jsc) { return u }
  if (%o === not) { return $iif($js_truthy(%v),f,t) }
  if (%o === void) { return u }
  var -n %x = $js_tonum(%v)
  if (%jsc) { return u }
  if (%o === add) { return n $+ %x }
  if (%o === sub) {
    if (%x === NaN) { return nNaN }
    if (%x === Inf) { return n-Inf }
    if (%x === -Inf) { return nInf }
    return $js_numtok($calc( 0 - ( %x ) ))
  }
  if (%o === bnot) { return n $+ $calc( 0 - $js_toint32(%x) - 1 ) }
  return u

  :e_upd
  var -n %an = $hget(jsa,%n $+ :a)
  var -n %old = $js_ev(%an,%env)
  if (%jsc) { return u }
  var -n %x = $js_tonum(%old)
  if (%jsc) { return u }
  var -n %new = n $+ $js_arith($iif($hget(jsa,%n $+ :o) === inc,add,sub),%x,1)
  noop $js_setref(%an,%new,%env)
  if (%jsc) { return u }
  if ($hget(jsa,%n $+ :pre)) { return %new }
  return n $+ %x

  :e_bin
  var -n %a = $js_ev($hget(jsa,%n $+ :l),%env)
  if (%jsc) { return u }
  var -n %b = $js_ev($hget(jsa,%n $+ :r),%env)
  if (%jsc) { return u }
  return $js_binop($hget(jsa,%n $+ :o),%a,%b)

  :e_log
  var -n %o = $hget(jsa,%n $+ :o)
  var -n %a = $js_ev($hget(jsa,%n $+ :l),%env)
  if (%jsc) { return u }
  if (%o === and) && (!$js_truthy(%a)) { return %a }
  if (%o === or) && ($js_truthy(%a)) { return %a }
  if (%o === nc) && (%a !=== u) && (%a !=== z) { return %a }
  return $js_ev($hget(jsa,%n $+ :r),%env)

  :e_cond
  var -n %q = $js_ev($hget(jsa,%n $+ :q),%env)
  if (%jsc) { return u }
  if ($js_truthy(%q)) { return $js_ev($hget(jsa,%n $+ :a),%env) }
  return $js_ev($hget(jsa,%n $+ :b),%env)

  :e_seq
  var -n %es = $hget(jsa,%n $+ :e)
  var -n %v = u
  var -n %i = 1
  while (%i <= $numtok(%es,32)) {
    var -n %v = $js_ev($gettok(%es,%i,32),%env)
    if (%jsc) { return u }
    inc %i
  }
  return %v

  :e_asg
  var -n %o = $hget(jsa,%n $+ :o)
  var -n %ln = $hget(jsa,%n $+ :l)
  var -n %lt = $hget(jsa,%ln $+ :t)
  if (%o === asg) {
    var -n %v = $js_ev($hget(jsa,%n $+ :r),%env)
    if (%jsc) { return u }
    if (%lt === apat) || (%lt === opat) { noop $js_bind(%ln,%v,%env,asg) }
    else { noop $js_setref(%ln,%v,%env) }
    return %v
  }
  ; compound: evaluate the target once
  var -n %obj = $null
  var -n %k = $null
  var -n %old = u
  if (%lt === mem) {
    var -n %obj = $js_ev($hget(jsa,%ln $+ :o),%env)
    if (%jsc) { return u }
    var -n %k = $hget(jsa,%ln $+ :k)
    if ($hget(jsa,%ln $+ :c)) { var -n %k = $js_tokey($js_ev($hget(jsa,%ln $+ :c),%env)) }
    if (%jsc) { return u }
    var -n %old = $js_get(%obj,%k)
  }
  else { var -n %old = $js_ev(%ln,%env) }
  if (%jsc) { return u }
  if (%o === and) || (%o === or) || (%o === nc) {
    if (%o === and) && (!$js_truthy(%old)) { return %old }
    if (%o === or) && ($js_truthy(%old)) { return %old }
    if (%o === nc) && (%old !=== u) && (%old !=== z) { return %old }
    var -n %v = $js_ev($hget(jsa,%n $+ :r),%env)
  }
  else {
    var -n %r = $js_ev($hget(jsa,%n $+ :r),%env)
    if (%jsc) { return u }
    var -n %v = $js_binop(%o,%old,%r)
  }
  if (%jsc) { return u }
  if (%lt === mem) { noop $js_put(%obj,%k,%v) }
  else { noop $js_setref(%ln,%v,%env) }
  return %v

  :e_mem
  var -n %obj = $js_ev($hget(jsa,%n $+ :o),%env)
  if (%jsc) { return u }
  if ($hget(jsa,%n $+ :ch)) {
    if (%jsoc) {
      if ($hget(jsa,%n $+ :che)) { unset %jsoc }
      return u
    }
    if ($hget(jsa,%n $+ :opt)) && ((%obj === u) || (%obj === z)) {
      if (!$hget(jsa,%n $+ :che)) { set %jsoc 1 }
      return u
    }
  }
  var -n %k = $hget(jsa,%n $+ :k)
  if ($hget(jsa,%n $+ :c)) {
    var -n %kv = $js_ev($hget(jsa,%n $+ :c),%env)
    if (%jsc) { return u }
    if ($left(%kv,1) === n) && ($regex($mid(%kv,2),/^(0|[1-9]\d*)$/)) { var -n %k = $mid(%kv,2) }
    else { var -n %k = $js_tokey(%kv) }
    if (%jsc) { return u }
  }
  return $js_get(%obj,%k)

  :e_supm
  var -n %home = $hget(jso,$mid($js_curfn(%env),2) $+ :home)
  var -n %proto = $iif(%home,$hget(jso,$mid(%home,2) $+ :p),z)
  var -n %k = $hget(jsa,%n $+ :k)
  if ($hget(jsa,%n $+ :c)) { var -n %k = $js_tokey($js_ev($hget(jsa,%n $+ :c),%env)) }
  if (%jsc) { return u }
  if (%proto === z) { return u }
  return $js_get(%proto,%k,$js_this(%env))

  :e_supc
  var -n %args = $js_evargs($hget(jsa,%n $+ :a),%env)
  if (%jsc) { return u }
  return $js_supercall(%env,%args)

  :e_call
  var -n %fnode = $hget(jsa,%n $+ :f)
  var -n %ft = $hget(jsa,%fnode $+ :t)
  var -n %this = u
  if (%ft === mem) {
    var -n %this = $js_ev($hget(jsa,%fnode $+ :o),%env)
    if (%jsc) { return u }
    if ($hget(jsa,%fnode $+ :ch)) {
      if (%jsoc) {
        if ($hget(jsa,%n $+ :che)) { unset %jsoc }
        return u
      }
      if ($hget(jsa,%fnode $+ :opt)) && ((%this === u) || (%this === z)) {
        if (!$hget(jsa,%n $+ :che)) { set %jsoc 1 }
        return u
      }
    }
    var -n %k = $hget(jsa,%fnode $+ :k)
    if ($hget(jsa,%fnode $+ :c)) {
      var -n %k = $js_tokey($js_ev($hget(jsa,%fnode $+ :c),%env))
      if (%jsc) { return u }
    }
    var -n %f = $js_get(%this,%k)
  }
  elseif (%ft === supm) {
    var -n %this = $js_this(%env)
    var -n %f = $js_ev(%fnode,%env)
  }
  else { var %f = $js_ev(%fnode,%env) }
  if (%jsc) { return u }
  if ($hget(jsa,%n $+ :ch)) {
    if (%jsoc) {
      if ($hget(jsa,%n $+ :che)) { unset %jsoc }
      return u
    }
    if ($hget(jsa,%n $+ :opt)) && ((%f === u) || (%f === z)) {
      if (!$hget(jsa,%n $+ :che)) { set %jsoc 1 }
      return u
    }
  }
  var -n %args = $js_evargs($hget(jsa,%n $+ :a),%env)
  if (%jsc) { return u }
  if ($hget(jsa,%n $+ :ln)) { hadd jsm line $v1 }
  if (!$js_iscallable(%f)) { return $js_throw(TypeError,$js_exprname(%fnode) is not a function) }
  return $js_call(%f,%this,%args)

  :e_new
  var -n %f = $js_ev($hget(jsa,%n $+ :f),%env)
  if (%jsc) { return u }
  var -n %args = $js_evargs($hget(jsa,%n $+ :a),%env)
  if (%jsc) { return u }
  if ($hget(jsa,%n $+ :ln)) { hadd jsm line $v1 }
  if (!$js_iscallable(%f)) { return $js_throw(TypeError,$js_exprname($hget(jsa,%n $+ :f)) is not a constructor) }
  return $js_construct(%f,%args)

  :e_tag
  var -n %f = $js_ev($hget(jsa,%n $+ :f),%env)
  if (%jsc) { return u }
  var -n %tn = $hget(jsa,%n $+ :q)
  var -n %strs = $js_newarr($hget(jsa,%tn $+ :q))
  noop $js_defhidden(%strs,raw,$js_newarr($hget(jsa,%tn $+ :q)))
  var -n %args = %strs
  var -n %es = $hget(jsa,%tn $+ :e)
  var -n %i = 1
  while (%i <= $numtok(%es,32)) {
    var -n %v = $js_ev($gettok(%es,%i,32),%env)
    if (%jsc) { return u }
    var -n %args = %args %v
    inc %i
  }
  return $js_call(%f,u,%args)

  :e_rx
  return $js_newregexp($mid($hget(jsa,%n $+ :v),2),$hget(jsa,%n $+ :f))

  :e_await
  var -n %v = $js_ev($hget(jsa,%n $+ :a),%env)
  if (%jsc) { return u }
  return $js_await(%v)

  :e_super
  return $js_throw(SyntaxError,'super' keyword unexpected here)

  :e_spread
  return $js_throw(SyntaxError,Unexpected spread)

  :e_apat
  :e_opat
  :e_def
  :e_rest
  return $js_throw(SyntaxError,Invalid destructuring assignment target)
}

; a short source-like name for an expression, for error messages
alias js_exprname {
  var -n %t = $hget(jsa,$1 $+ :t)
  if (%t === id) { return $hget(jsa,$1 $+ :r) }
  if (%t === this) { return this }
  if (%t === mem) {
    if ($hget(jsa,$1 $+ :c)) { return $js_exprname($hget(jsa,$1 $+ :o)) $+ [...] }
    return $js_exprname($hget(jsa,$1 $+ :o)) $+ . $+ $js_dec($js_kdec($hget(jsa,$1 $+ :k)))
  }
  if (%t === call) { return $js_exprname($hget(jsa,$1 $+ :f)) $+ (...) }
  return expression
}

; evaluate call arguments (with spread) -> token list
alias js_evargs {
  var -n %list = $1
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    var -n %a = $gettok(%list,%i,32)
    if ($hget(jsa,%a $+ :t) === spread) {
      var -n %src = $js_ev($hget(jsa,%a $+ :a),$2)
      if (%jsc) { return $null }
      var -n %items = $js_iterlist(%src)
      if (%jsc) { return $null }
      var -n %out = %out %items
    }
    else {
      var -n %v = $js_ev(%a,$2)
      if (%jsc) { return $null }
      var -n %out = %out %v
    }
    inc %i
  }
  return %out
}

; store into an assignment target: identifier or member
alias js_setref {
  var -n %n = $1
  var -n %t = $hget(jsa,%n $+ :t)
  if (%t === id) { noop $js_assign($3,$hget(jsa,%n $+ :n),$2) | return }
  if (%t === mem) {
    var -n %obj = $js_ev($hget(jsa,%n $+ :o),$3)
    if (%jsc) { return }
    var -n %k = $hget(jsa,%n $+ :k)
    if ($hget(jsa,%n $+ :c)) {
      var -n %kv = $js_ev($hget(jsa,%n $+ :c),$3)
      if (%jsc) { return }
      if ($left(%kv,1) === n) && ($regex($mid(%kv,2),/^(0|[1-9]\d*)$/)) { var -n %k = $mid(%kv,2) }
      else { var -n %k = $js_tokey(%kv) }
      if (%jsc) { return }
    }
    noop $js_put(%obj,%k,$2)
    return
  }
  if (%t === apat) || (%t === opat) { noop $js_bind(%n,$2,$3,asg) | return }
  noop $js_throw(SyntaxError,Invalid assignment target)
}

; bind a pattern to a value: $js_bind(pattern,value,env,kind)
; kind: var/let/const declare names; asg assigns to existing targets
alias js_bind {
  var -n %p = $1
  var -n %v = $2
  var -n %env = $3
  var -n %kind = $4
  var -n %t = $hget(jsa,%p $+ :t)
  if (%t === id) {
    if (%kind === asg) || (%kind === var) { noop $js_assign(%env,$hget(jsa,%p $+ :n),%v) }
    else { noop $js_decl(%env,$hget(jsa,%p $+ :n),%v,$iif(%kind === const,1,0)) }
    return
  }
  if (%t === def) {
    if (%v === u) {
      var -n %v = $js_ev($hget(jsa,%p $+ :r),%env)
      if (%jsc) { return }
      var -n %l = $hget(jsa,%p $+ :l)
      if ($hget(jsa,%l $+ :t) === id) {
        if ($left(%v,1) === o) && ($hget(jso,$mid(%v,2) $+ :fn)) && ($hget(jso,$mid(%v,2) $+ .name) === s) { hadd jso $mid(%v,2) $+ .name s $+ $js_enc($hget(jsa,%l $+ :r)) }
      }
    }
    noop $js_bind($hget(jsa,%p $+ :l),%v,%env,%kind)
    return
  }
  if (%t === mem) {
    noop $js_setref(%p,%v,%env)
    return
  }
  if (%t === apat) {
    var -n %list = $js_iterlist(%v)
    if (%jsc) { return }
    var -n %es = $hget(jsa,%p $+ :e)
    var -n %i = 1
    while (%i <= $numtok(%es,32)) {
      var -n %el = $gettok(%es,%i,32)
      if (%el) {
        if ($hget(jsa,%el $+ :t) === rest) {
          noop $js_bind($hget(jsa,%el $+ :a),$js_newarr($gettok(%list,%i $+ -,32)),%env,%kind)
          return
        }
        var -n %x = $gettok(%list,%i,32)
        noop $js_bind(%el,$iif(%x == $null,u,%x),%env,%kind)
        if (%jsc) { return }
      }
      inc %i
    }
    return
  }
  if (%t === opat) {
    if (%v === u) || (%v === z) {
      noop $js_throw(TypeError,Cannot destructure ' $+ $js_dec($js_tostr(%v)) $+ ' as it is $iif(%v === u,undefined,null) $+ .)
      return
    }
    var -n %used = $null
    var -n %ps = $hget(jsa,%p $+ :p)
    var -n %i = 1
    while (%i <= $numtok(%ps,32)) {
      var -n %pp = $gettok(%ps,%i,32)
      if ($hget(jsa,%pp $+ :t) === rest) {
        var -n %r = $js_newobj
        if ($left(%v,1) === o) {
          var -n %keys = $js_ownkeys(%v)
          var -n %j = 1
          while (%j <= $numtok(%keys,32)) {
            var -n %key = $gettok(%keys,%j,32)
            if (!$istokcs(%used,%key,32)) { noop $js_put(%r,%key,$js_get(%v,%key)) }
            inc %j
          }
        }
        noop $js_bind($hget(jsa,%pp $+ :a),%r,%env,%kind)
        return
      }
      var -n %k = $hget(jsa,%pp $+ :k)
      if ($hget(jsa,%pp $+ :c)) {
        var -n %k = $js_tokey($js_ev($hget(jsa,%pp $+ :c),%env))
        if (%jsc) { return }
      }
      var -n %used = %used %k
      var -n %x = $js_get(%v,%k)
      if (%jsc) { return }
      noop $js_bind($hget(jsa,%pp $+ :v),%x,%env,%kind)
      if (%jsc) { return }
      inc %i
    }
    return
  }
  if (%t === asg) {
    ; {a = 1} shorthand left as an assignment by the object parser
    var -n %d = %p
    if (%v === u) { var -n %v = $js_ev($hget(jsa,%d $+ :r),%env) }
    if (%jsc) { return }
    noop $js_bind($hget(jsa,%d $+ :l),%v,%env,%kind)
    return
  }
  noop $js_throw(SyntaxError,Invalid destructuring target)
}

; copy own enumerable properties (Object.assign / spread)
alias js_assignprops {
  var -n %src = $2
  var -n %ty = $left(%src,1)
  if (%ty === s) {
    var -n %t = $js_dec($mid(%src,2))
    var -n %i = 1
    while (%i <= $len(%t)) {
      noop $js_put($1,$calc( %i - 1 ),s $+ $js_enc($mid(%t,%i,1)))
      inc %i
    }
    return
  }
  if (%ty !=== o) { return }
  var -n %keys = $js_ownkeys(%src)
  var -n %i = 1
  while (%i <= $numtok(%keys,32)) {
    var -n %k = $gettok(%keys,%i,32)
    var -n %v = $js_get(%src,%k)
    if (%jsc) { return }
    noop $js_put($1,%k,%v)
    inc %i
  }
}

; values produced by iterating a value (arrays, strings, Map, Set)
alias js_iterlist {
  var -n %v = $1
  var -n %ty = $left(%v,1)
  if (%ty === s) {
    var -n %t = $js_dec($mid(%v,2))
    var -n %out = $null
    var -n %i = 1
    while (%i <= $len(%t)) {
      var -n %out = %out s $+ $js_enc($mid(%t,%i,1))
      inc %i
    }
    return %out
  }
  if (%ty === o) {
    var -n %id = $mid(%v,2)
    if ($hget(jso,%id $+ :len) != $null) { return $js_arrlist(%v) }
    var -n %c = $hget(jso,%id $+ :c)
    if (%c === Map) { return $js_mapentries(%v) }
    if (%c === Set) { return $js_setvalues(%v) }
    ; anything with a next() method, or a [Symbol.iterator]-like iterator() method
    var -n %it = $js_get(%v,iterator)
    if ($js_iscallable(%it)) {
      var -n %v = $js_call(%it,%v,$null)
      if (%jsc) { return $null }
    }
    var -n %next = $js_get(%v,next)
    if ($js_iscallable(%next)) {
      var -n %out = $null
      var -n %guard = 0
      while (%guard < 100000) {
        var -n %r = $js_call(%next,%v,$null)
        if (%jsc) { return $null }
        if ($js_truthy($js_get(%r,done))) { break }
        var -n %out = %out $js_get(%r,value)
        inc %guard
      }
      return %out
    }
  }
  noop $js_throw(TypeError,$js_desc(%v) is not iterable)
  return $null
}

; ----------------------------------------------------------------- operators --

alias js_binop {
  var -n %o = $1
  var -n %a = $2
  var -n %b = $3
  if (%o === add) {
    if ($left(%a,1) === n) && ($left(%b,1) === n) { return $js_numtok($js_arith(add,$mid(%a,2),$mid(%b,2))) }
    var -n %pa = $js_toprim(%a)
    if (%jsc) { return u }
    var -n %pb = $js_toprim(%b)
    if (%jsc) { return u }
    if ($left(%pa,1) === s) || ($left(%pb,1) === s) { return s $+ $js_tostr(%pa) $+ $js_tostr(%pb) }
    return $js_numtok($js_arith(add,$js_tonum(%pa),$js_tonum(%pb)))
  }
  if (%o === sub) || (%o === mul) || (%o === div) || (%o === mod) || (%o === exp) {
    var -n %x = $js_tonum(%a)
    if (%jsc) { return u }
    var -n %y = $js_tonum(%b)
    if (%jsc) { return u }
    return $js_numtok($js_arith(%o,%x,%y))
  }
  ; fast path: comparing two finite numbers
  if ($left(%a,1) === n) && ($left(%b,1) === n) && ($mid(%a,2) isnum) && ($mid(%b,2) isnum) {
    var -n %x = $mid(%a,2)
    var -n %y = $mid(%b,2)
    if (%o === lt) { return $iif(%x < %y,t,f) }
    if (%o === gt) { return $iif(%x > %y,t,f) }
    if (%o === le) { return $iif(%x <= %y,t,f) }
    if (%o === ge) { return $iif(%x >= %y,t,f) }
    if (%o === seq) || (%o === eq) { return $iif(%x == %y,t,f) }
    if (%o === sne) || (%o === ne) { return $iif(%x != %y,t,f) }
  }
  if (%o === seq) { return $js_bool($js_seq(%a,%b)) }
  if (%o === sne) { return $js_bool($iif($js_seq(%a,%b),0,1)) }
  if (%o === eq) { return $js_bool($js_leq(%a,%b)) }
  if (%o === ne) { return $js_bool($iif($js_leq(%a,%b),0,1)) }
  if (%o === lt) { return $js_bool($iif($js_lt(%a,%b) == 1,1,0)) }
  if (%o === gt) { return $js_bool($iif($js_lt(%b,%a) == 1,1,0)) }
  if (%o === le) { return $js_bool($iif($js_lt(%b,%a) == 0,1,0)) }
  if (%o === ge) { return $js_bool($iif($js_lt(%a,%b) == 0,1,0)) }
  if (%o === in) {
    if ($left(%b,1) !=== o) { return $js_throw(TypeError,Cannot use 'in' operator to search for ' $+ $js_dec($js_tostr(%a)) $+ ' in $js_dec($js_tostr(%b))) }
    return $js_bool($js_haskey(%b,$js_tokey(%a)))
  }
  if (%o === instanceof) { return $js_bool($js_instanceof(%a,%b)) }
  ; bitwise
  var -n %x = $js_tonum(%a)
  if (%jsc) { return u }
  var -n %y = $js_tonum(%b)
  if (%jsc) { return u }
  if (%o === band) { return n $+ $js_toint32($and($js_touint32(%x),$js_touint32(%y))) }
  if (%o === bor) { return n $+ $js_toint32($or($js_touint32(%x),$js_touint32(%y))) }
  if (%o === bxor) { return n $+ $js_toint32($xor($js_touint32(%x),$js_touint32(%y))) }
  var -n %s = $and($js_touint32(%y),31)
  if (%o === shl) { return n $+ $js_toint32($calc( ( $js_touint32(%x) * 2 ^ %s ) % 4294967296 )) }
  ; shifts by exact integer division ($calc rounds to 6 decimals)
  var -n %p = $calc( 2 ^ %s )
  if (%o === shr) {
    var -n %v = $js_toint32(%x)
    var -n %m = $calc( ( ( %v % %p ) + %p ) % %p )
    return n $+ $calc( ( %v - %m ) / %p )
  }
  if (%o === ushr) {
    var -n %v = $js_touint32(%x)
    return n $+ $calc( ( %v - ( %v % %p ) ) / %p )
  }
  return u
}

; === -> 1 or 0
alias js_seq {
  if ($1 === $2) { return $iif($1 === nNaN,0,1) }
  return 0
}

; == -> 1 or 0
alias js_leq {
  var -n %a = $1
  var -n %b = $2
  var -n %ta = $left(%a,1)
  var -n %tb = $left(%b,1)
  if (%ta === %tb) { return $js_seq(%a,%b) }
  if ((%ta === u) || (%ta === z)) && ((%tb === u) || (%tb === z)) { return 1 }
  if (%ta === u) || (%ta === z) || (%tb === u) || (%tb === z) { return 0 }
  if (%ta === t) || (%ta === f) { return $js_leq(n $+ $js_tonum(%a),%b) }
  if (%tb === t) || (%tb === f) { return $js_leq(%a,n $+ $js_tonum(%b)) }
  if (%ta === n) && (%tb === s) { return $js_seq(%a,$js_numtok($js_tonum(%b))) }
  if (%ta === s) && (%tb === n) { return $js_seq($js_numtok($js_tonum(%a)),%b) }
  if (%ta === o) {
    var -n %p = $js_toprim(%a)
    if (%jsc) { return 0 }
    return $js_leq(%p,%b)
  }
  if (%tb === o) {
    var -n %p = $js_toprim(%b)
    if (%jsc) { return 0 }
    return $js_leq(%a,%p)
  }
  return 0
}

; a < b -> 1, 0, or u (undefined: NaN involved)
alias js_lt {
  var -n %a = $js_toprim($1,number)
  if (%jsc) { return u }
  var -n %b = $js_toprim($2,number)
  if (%jsc) { return u }
  if ($left(%a,1) === s) && ($left(%b,1) === s) { return $js_strlt($js_dec($mid(%a,2)),$js_dec($mid(%b,2))) }
  var -n %x = $js_tonum(%a)
  var -n %y = $js_tonum(%b)
  if (%x === NaN) || (%y === NaN) { return u }
  if (%x === %y) { return 0 }
  if (%x === -Inf) || (%y === Inf) { return 1 }
  if (%x === Inf) || (%y === -Inf) { return 0 }
  return $iif(%x < %y,1,0)
}

; string comparison by character code
alias js_strlt {
  if ($1 === $2) { return 0 }
  var -n %la = $len($1)
  var -n %lb = $len($2)
  var -n %n = $iif(%la < %lb,%la,%lb)
  var -n %i = 1
  while (%i <= %n) {
    var -n %ca = $asc($mid($1,%i,1))
    var -n %cb = $asc($mid($2,%i,1))
    if (%ca != %cb) { return $iif(%ca < %cb,1,0) }
    inc %i
  }
  return $iif(%la < %lb,1,0)
}

; ----------------------------------------------------------------- classes --

alias js_mkclass {
  var -n %n = $1
  var -n %env = $2
  var -n %parent = 0
  var -n %pproto = $hget(jsm,OP)
  var -n %supn = $hget(jsa,%n $+ :sup)
  if (%supn) {
    var -n %parent = $js_ev(%supn,%env)
    if (%jsc) { return u }
    if (%parent === z) { var -n %pproto = z }
    elseif (!$js_iscallable(%parent)) { return $js_throw(TypeError,Class extends value $js_dec($js_tostr(%parent)) is not a constructor or null) }
    else {
      var -n %pproto = $js_get(%parent,prototype)
      if (%jsc) { return u }
    }
  }
  var -n %cenv = $js_newenv(%env)
  var -n %ctor = $hget(jsa,%n $+ :ctor)
  if (!%ctor) { var -n %ctor = $hget(jsm,$iif(%supn,defctor1,defctor0)) }
  var -n %f = $js_closure(%ctor,%cenv)
  var -n %fid = $mid(%f,2)
  hadd jso %fid $+ :cls 1
  if (%supn) {
    hadd jso %fid $+ :derived 1
    if (%parent !=== z) { hadd jso %fid $+ :p %parent }
  }
  hadd jso %fid $+ .name s $+ $hget(jsa,%n $+ :nm)
  var -n %proto = $js_new(%pproto,Object)
  noop $js_defhidden(%f,prototype,%proto)
  noop $js_defhidden(%proto,constructor,%f)
  hadd jso %fid $+ :home %proto
  if ($hget(jsa,%n $+ :k)) { noop $js_decl(%cenv,$hget(jsa,%n $+ :k),%f,1) }
  var -n %fields = $null
  var -n %statics = $null
  var -n %ms = $hget(jsa,%n $+ :m)
  var -n %i = 1
  while (%i <= $numtok(%ms,32)) {
    var -n %m = $gettok(%ms,%i,32)
    var -n %kind = $hget(jsa,%m $+ :kind)
    var -n %target = $iif($hget(jsa,%m $+ :st),%f,%proto)
    if (%kind === field) || (%kind === sblock) {
      if ($hget(jsa,%m $+ :st)) { var -n %statics = %statics %m }
      else { var -n %fields = %fields %m }
      inc %i
      continue
    }
    var -n %k = $hget(jsa,%m $+ :k)
    if ($hget(jsa,%m $+ :c)) {
      var -n %k = $js_tokey($js_ev($hget(jsa,%m $+ :c),%cenv))
      if (%jsc) { return u }
    }
    var -n %mf = $js_closure($hget(jsa,%m $+ :v),%cenv)
    hadd jso $mid(%mf,2) $+ :home %target
    if (%kind === get) { noop $js_defacc(%target,%k,%mf,0,0) }
    elseif (%kind === set) { noop $js_defacc(%target,%k,0,%mf,0) }
    else { noop $js_defhidden(%target,%k,%mf) }
    inc %i
  }
  if (%fields != $null) { hadd jso %fid $+ :fields %fields }
  ; static fields and static blocks run now, with this = the class
  var -n %i = 1
  while (%i <= $numtok(%statics,32)) {
    var -n %m = $gettok(%statics,%i,32)
    if ($hget(jsa,%m $+ :kind) === sblock) {
      noop $js_invoke($mid($js_closure($hget(jsa,%m $+ :v),%cenv),2),$hget(jsa,%m $+ :v),%f,$null,$null)
    }
    else {
      var -n %senv = $js_newenv(%cenv)
      hadd jse %senv $+ :this %f
      hadd jse %senv $+ :fo %f
      var -n %k = $hget(jsa,%m $+ :k)
      if ($hget(jsa,%m $+ :c)) { var -n %k = $js_tokey($js_ev($hget(jsa,%m $+ :c),%senv)) }
      var -n %init = $hget(jsa,%m $+ :v)
      var -n %v = $iif(%init,$js_ev(%init,%senv),u)
      if (%jsc) { return u }
      noop $js_put(%f,%k,%v)
    }
    if (%jsc) { return u }
    inc %i
  }
  return %f
}

; ------------------------------------------------------------- statements --

; run a list of statements; stops at the first pending completion
alias js_exlist {
  var -n %list = $1
  var -n %i = 1
  var -n %n = $numtok(%list,32)
  while (%i <= %n) {
    noop $js_ex($gettok(%list,%i,32),$2)
    if (%jsc) { return }
    inc %i
  }
}

alias js_ex {
  var -n %n = $1
  var -n %env = $2
  var -n %labels = $3
  var -n %ln = $hget(jsa,%n $+ :ln)
  if (%ln) { hadd jsm line %ln }
  goto $+(s_,$hget(jsa,%n $+ :t))

  :s_exp
  noop $js_ev($hget(jsa,%n $+ :a),%env)
  return

  :s_var
  var -n %kind = $hget(jsa,%n $+ :k)
  var -n %ds = $hget(jsa,%n $+ :d)
  var -n %i = 1
  while (%i <= $numtok(%ds,32)) {
    var -n %d = $gettok(%ds,%i,32)
    var -n %init = $hget(jsa,%d $+ :i)
    var -n %id = $hget(jsa,%d $+ :id)
    if (%init) {
      var -n %v = $js_ev(%init,%env)
      if (%jsc) { return }
      if ($hget(jsa,%id $+ :t) === id) && ($left(%v,1) === o) && ($hget(jso,$mid(%v,2) $+ .name) === s) && ($hget(jso,$mid(%v,2) $+ :fn)) { hadd jso $mid(%v,2) $+ .name s $+ $js_enc($hget(jsa,%id $+ :r)) }
      noop $js_bind(%id,%v,%env,%kind)
    }
    elseif (%kind !=== var) { noop $js_bind(%id,u,%env,%kind) }
    if (%jsc) { return }
    inc %i
  }
  return

  :s_fnd
  return

  :s_clsd
  var -n %c = $js_mkclass($hget(jsa,%n $+ :c),%env)
  if (%jsc) { return }
  noop $js_decl(%env,$hget(jsa,%n $+ :k),%c)
  return

  :s_ret
  var -n %a = $hget(jsa,%n $+ :a)
  var -n %v = u
  if (%a) {
    var -n %v = $js_ev(%a,%env)
    if (%jsc) { return }
  }
  set %jsc r
  set %jscv %v
  return

  :s_if
  var -n %q = $js_ev($hget(jsa,%n $+ :q),%env)
  if (%jsc) { return }
  if ($js_truthy(%q)) { noop $js_ex($hget(jsa,%n $+ :a),%env) }
  elseif ($hget(jsa,%n $+ :b)) { noop $js_ex($v1,%env) }
  return

  :s_blk
  var -n %e = %env
  if ($hget(jsa,%n $+ :lex)) { var -n %e = $js_newenv(%env) }
  noop $js_exlist($hget(jsa,%n $+ :s),%e)
  if (%e != %env) { noop $js_freeenv(%e) }
  if (%jsc === b) && (%jscl != $null) && ($istokcs(%labels,%jscl,32)) { unset %jsc %jscl }
  return

  :s_while
  var -n %body = $hget(jsa,%n $+ :b)
  var -n %qn = $hget(jsa,%n $+ :q)
  while (1) {
    var -n %q = $js_ev(%qn,%env)
    if (%jsc) { return }
    if (!$js_truthy(%q)) { return }
    noop $js_ex(%body,%env)
    if (%jsc) {
      if (!$js_loopctl(%labels)) { return }
      if (%jsc === b) { unset %jsc %jscl | return }
      unset %jsc %jscl
    }
  }

  :s_do
  var -n %body = $hget(jsa,%n $+ :b)
  var -n %qn = $hget(jsa,%n $+ :q)
  while (1) {
    noop $js_ex(%body,%env)
    if (%jsc) {
      if (!$js_loopctl(%labels)) { return }
      if (%jsc === b) { unset %jsc %jscl | return }
      unset %jsc %jscl
    }
    var -n %q = $js_ev(%qn,%env)
    if (%jsc) { return }
    if (!$js_truthy(%q)) { return }
  }

  :s_for
  var -n %lex = $hget(jsa,%n $+ :lex)
  var -n %cur = %env
  if (%lex) { var -n %cur = $js_newenv(%env) }
  var -n %init = $hget(jsa,%n $+ :i)
  if (%init) {
    if ($hget(jsa,%init $+ :t) === var) { noop $js_ex(%init,%cur) }
    else { noop $js_ev(%init,%cur) }
    if (%jsc) { return }
  }
  var -n %qn = $hget(jsa,%n $+ :q)
  var -n %un = $hget(jsa,%n $+ :u)
  var -n %body = $hget(jsa,%n $+ :b)
  while (1) {
    if (%qn) {
      var -n %q = $js_ev(%qn,%cur)
      if (%jsc) { return }
      if (!$js_truthy(%q)) { break }
    }
    noop $js_ex(%body,%cur)
    if (%jsc) {
      if (!$js_loopctl(%labels)) { return }
      if (%jsc === b) { unset %jsc %jscl | break }
      unset %jsc %jscl
    }
    if (%lex) && ($hget(jsa,%n $+ :cpy)) {
      ; a fresh scope per iteration, so closures keep that iteration's values
      var -n %next = $js_newenv(%env)
      var -n %ks = $hget(jse,%cur $+ :k)
      var -n %j = 1
      while (%j <= $numtok(%ks,32)) {
        var -n %kk = $gettok(%ks,%j,32)
        noop $js_decl(%next,%kk,$hget(jse,%cur $+ . $+ %kk),$hget(jse,%cur $+ ~ $+ %kk))
        inc %j
      }
      noop $js_freeenv(%cur)
      var -n %cur = %next
    }
    if (%un) {
      noop $js_ev(%un,%cur)
      if (%jsc) { return }
    }
  }
  if (%lex) { noop $js_freeenv(%cur) }
  return

  :s_forin
  var -n %r = $js_ev($hget(jsa,%n $+ :r),%env)
  if (%jsc) { return }
  var -n %of = $hget(jsa,%n $+ :of)
  var -n %items = $null
  if (%of) {
    var -n %items = $js_iterlist(%r)
    if (%jsc) { return }
  }
  else { var -n %items = $js_forinkeys(%r) }
  var -n %left = $hget(jsa,%n $+ :l)
  var -n %isdecl = $iif($hget(jsa,%left $+ :t) === var,1,0)
  var -n %kind = $iif(%isdecl,$hget(jsa,%left $+ :k),asg)
  var -n %target = $iif(%isdecl,$hget(jsa,$gettok($hget(jsa,%left $+ :d),1,32) $+ :id),%left)
  var -n %body = $hget(jsa,%n $+ :b)
  var -n %i = 1
  var -n %cnt = $numtok(%items,32)
  while (%i <= %cnt) {
    var -n %v = $gettok(%items,%i,32)
    if (!%of) { var -n %v = s $+ $js_kdec(%v) }
    var -n %e = %env
    if (%kind === let) || (%kind === const) { var -n %e = $js_newenv(%env) }
    noop $js_bind(%target,%v,%e,%kind)
    if (%jsc) { return }
    noop $js_ex(%body,%e)
    if (%e != %env) { noop $js_freeenv(%e) }
    if (%jsc) {
      if (!$js_loopctl(%labels)) { return }
      if (%jsc === b) { unset %jsc %jscl | return }
      unset %jsc %jscl
    }
    inc %i
  }
  return

  :s_brk
  set %jsc b
  set %jscl $hget(jsa,%n $+ :l)
  return

  :s_cnt
  set %jsc c
  set %jscl $hget(jsa,%n $+ :l)
  return

  :s_thr
  var -n %v = $js_ev($hget(jsa,%n $+ :a),%env)
  if (%jsc) { return }
  if ($left(%v,1) === o) && (!$hget(jso,$mid(%v,2) $+ :line)) { hadd jso $mid(%v,2) $+ :line %ln }
  set %jsc x
  set %jscv %v
  return

  :s_try
  noop $js_ex($hget(jsa,%n $+ :b),%env)
  if (%jsc === x) && ($hget(jsa,%n $+ :h)) {
    var -n %err = %jscv
    unset %jsc %jscv %jscl
    var -n %ce = $js_newenv(%env)
    if ($hget(jsa,%n $+ :p)) { noop $js_bind($v1,%err,%ce,let) }
    if (!%jsc) { noop $js_ex($hget(jsa,%n $+ :h),%ce) }
    noop $js_freeenv(%ce)
  }
  if ($hget(jsa,%n $+ :f)) {
    var -n %sc = %jsc
    var -n %scv = %jscv
    var -n %scl = %jscl
    unset %jsc %jscv %jscl
    noop $js_ex($hget(jsa,%n $+ :f),%env)
    if (!%jsc) {
      if (%sc) { set %jsc %sc }
      if (%scv != $null) { set %jscv %scv }
      if (%scl != $null) { set %jscl %scl }
    }
  }
  return

  :s_sw
  var -n %d = $js_ev($hget(jsa,%n $+ :d),%env)
  if (%jsc) { return }
  var -n %e = %env
  if ($hget(jsa,%n $+ :lex)) { var -n %e = $js_newenv(%env) }
  var -n %cases = $hget(jsa,%n $+ :c)
  var -n %cnt = $numtok(%cases,32)
  var -n %start = 0
  var -n %i = 1
  while (%i <= %cnt) {
    var -n %c = $gettok(%cases,%i,32)
    var -n %q = $hget(jsa,%c $+ :q)
    if (%q) {
      var -n %v = $js_ev(%q,%e)
      if (%jsc) { return }
      if ($js_seq(%d,%v)) { var -n %start = %i | break }
    }
    inc %i
  }
  if (!%start) {
    var -n %i = 1
    while (%i <= %cnt) {
      if (!$hget(jsa,$gettok(%cases,%i,32) $+ :q)) { var -n %start = %i | break }
      inc %i
    }
  }
  if (%start) {
    var -n %i = %start
    while (%i <= %cnt) {
      noop $js_exlist($hget(jsa,$gettok(%cases,%i,32) $+ :s),%e)
      if (%jsc) { break }
      inc %i
    }
  }
  if (%e != %env) { noop $js_freeenv(%e) }
  if (%jsc === b) && ((%jscl == $null) || ($istokcs(%labels,%jscl,32))) { unset %jsc %jscl }
  return

  :s_lab
  noop $js_ex($hget(jsa,%n $+ :b),%env,%labels $hget(jsa,%n $+ :l))
  if (%jsc === b) && (%jscl === $hget(jsa,%n $+ :l)) { unset %jsc %jscl }
  return
}

; after a loop body left a completion: is it this loop's? -> 1 to handle it
alias js_loopctl {
  if (%jsc !=== b) && (%jsc !=== c) { return 0 }
  if (%jscl == $null) { return 1 }
  return $iif($istokcs($1,%jscl,32),1,0)
}

; keys visited by for-in: own and inherited enumerable keys
alias js_forinkeys {
  var -n %v = $1
  var -n %ty = $left(%v,1)
  if (%ty === s) {
    var -n %out = $null
    var -n %i = 0
    while (%i < $len($js_dec($mid(%v,2)))) {
      var -n %out = %out %i
      inc %i
    }
    return %out
  }
  if (%ty !=== o) { return $null }
  var -n %out = $null
  var -n %cur = %v
  while ($left(%cur,1) === o) {
    var -n %keys = $js_ownkeys(%cur)
    var -n %i = 1
    while (%i <= $numtok(%keys,32)) {
      if (!$istokcs(%out,$gettok(%keys,%i,32),32)) { var -n %out = %out $gettok(%keys,%i,32) }
      inc %i
    }
    var -n %cur = $hget(jso,$mid(%cur,2) $+ :p)
  }
  return %out
}

; ---------------------------------------------------------------- programs --

; run a parsed program in the global scope -> completion value
alias js_runprog {
  var -n %prog = $1
  var -n %env = 1
  var -n %hv = $hget(jsa,%prog $+ :hv)
  var -n %i = 1
  while (%i <= $numtok(%hv,32)) {
    if ($hget(jse,%env $+ . $+ $gettok(%hv,%i,32)) == $null) { noop $js_decl(%env,$gettok(%hv,%i,32),u) }
    inc %i
  }
  noop $js_hoistfns(%prog,%env)
  ; the value of the last expression statement, for $js() and the REPL
  var -n %list = $hget(jsa,%prog $+ :s)
  var -n %last = u
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    var -n %s = $gettok(%list,%i,32)
    if ($hget(jsa,%s $+ :t) === exp) {
      hadd jsm line $hget(jsa,%s $+ :ln)
      var -n %last = $js_ev($hget(jsa,%s $+ :a),%env)
    }
    else { noop $js_ex(%s,%env) }
    if (%jsc) { break }
    inc %i
  }
  if (%jsc === r) || (%jsc === b) || (%jsc === c) { unset %jsc %jscv %jscl }
  return %last
}
