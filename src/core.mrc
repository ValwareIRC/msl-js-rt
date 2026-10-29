; ============================================================================
;  msl-js-rt: core - values, strings, conversions, objects, scopes, calls
; ============================================================================
;
; Every JavaScript value is a token with no spaces in it:
;
;   u              undefined
;   z              null
;   t / f          true / false
;   n<number>      a number: n42, n-1.5, nNaN, nInf, n-Inf
;   s<text>        a string, encoded so it has no spaces (see $js_enc)
;   o<id>          an object (arrays and functions are objects too)
;   g<get>_<set>   an accessor property (only ever stored, never a value)
;
; Because tokens never contain spaces, lists of values are plain
; space-separated strings: an argument list is "n1 sfoo o12".
;
; Hash tables:
;   jsa  syntax trees    <node>:<field>
;   jse  scopes          <env>.<name> = value, <env>:p = parent, <env>:this
;   jso  objects         <id>.<key> = value, <id>:p = prototype, <id>:k = keys
;   jsm  interpreter state and well-known objects
;
; Hash table item names ignore case but JavaScript names do not, so
; property and variable names are stored "case-escaped": every capital and
; every ^ gets a ^ in front of it ($js_kenc). "Foo" is stored as "^Foo".
;
; Control flow travels in three globals: %jsc is the pending completion
; (r return, b break, c continue, x throw), %jscv its value and %jscl a
; label. Everything that evaluates code checks %jsc afterwards.

; ---------------------------------------------------------------- strings ---

; text -> encoded string body (no spaces)
alias js_enc { return $replacecs($1,$chr(1),$+($chr(1),a),$chr(2),$+($chr(1),c),$chr(32),$+($chr(1),b),$chr(10),$+($chr(1),n),$chr(13),$+($chr(1),r),$chr(9),$+($chr(1),t),$chr(11),$+($chr(1),v),$chr(12),$+($chr(1),f)) }

; encoded string body -> text
alias js_dec { return $replacecs($1,$+($chr(1),b),$chr(32),$+($chr(1),n),$chr(10),$+($chr(1),r),$chr(13),$+($chr(1),t),$chr(9),$+($chr(1),v),$chr(11),$+($chr(1),f),$chr(12),$+($chr(1),c),$chr(2),$+($chr(1),a),$chr(1)) }

; property or variable name (encoded string body) -> hash-safe key
alias js_kenc { return $regsubex($1,/([\p{Lu}^])/g,^\1) }

; hash-safe key -> encoded string body
alias js_kdec { return $regsubex($1,/\^(.)/g,\1) }

; JS string token for a text: $js_str(hello world) -> shello<sp>world
alias js_str { return s $+ $js_enc($1) }

; ----------------------------------------------------------------- numbers --

; canonical number token from a numeric string (handles -0 and exponents)
alias js_numtok {
  var -n %v = $1
  if (%v === NaN) || (%v === Inf) || (%v === -Inf) { return n $+ %v }
  return n $+ $calc( %v )
}

; ToNumber: value token -> number text (NaN, Inf, -Inf or a decimal)
alias js_tonum {
  var -n %v = $1
  var -n %ty = $left(%v,1)
  if (%ty === n) { return $mid(%v,2) }
  if (%ty === u) { return NaN }
  if (%ty === z) || (%ty === f) { return 0 }
  if (%ty === t) { return 1 }
  if (%ty === s) { return $js_strnum($js_dec($mid(%v,2))) }
  if (%ty === o) {
    var -n %p = $js_toprim(%v,number)
    if (%jsc) { return NaN }
    return $js_tonum(%p)
  }
  return NaN
}

; text -> number text, following JavaScript's string-to-number rules
alias js_strnum {
  var -n %s = $regsubex($1,/^\s+|\s+$/g,)
  if (%s == $null) { return 0 }
  if ($regex(%s,/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/)) { return $js_parsedec(%s) }
  if ($regex(%s,/^0[xX]([0-9a-fA-F]+)$/)) { return $base($regml(1),16,10) }
  if ($regex(%s,/^0[oO]([0-7]+)$/)) { return $base($regml(1),8,10) }
  if ($regex(%s,/^0[bB]([01]+)$/)) { return $base($regml(1),2,10) }
  if (%s === Infinity) || (%s === +Infinity) { return Inf }
  if (%s === -Infinity) { return -Inf }
  return NaN
}

; decimal literal text (maybe with an exponent) -> number text
alias js_parsedec {
  var -n %s = $1
  if ($regex(%s,/^([+-]?[\d.]+)[eE]([+-]?\d+)$/)) {
    var -n %m = $regml(1)
    var -n %e = $regml(2)
    if (%e > 300) { return $iif($left(%m,1) == -,-Inf,Inf) }
    if (%e < -300) { return 0 }
    return $calc( %m * 10 ^ %e )
  }
  return $calc( %s )
}

; number text -> display text (what String(n) gives)
alias js_numstr {
  var -n %n = $1
  if (%n === NaN) { return NaN }
  if (%n === Inf) { return Infinity }
  if (%n === -Inf) { return -Infinity }
  return %n
}

; is this number text finite?
alias js_isfin { return $iif($1 === NaN || $1 === Inf || $1 === -Inf,0,1) }

; arithmetic on number texts: $js_arith(op,a,b) -> number text
alias js_arith {
  var -n %o = $1
  var -n %a = $2
  var -n %b = $3
  if (%a === NaN) || (%b === NaN) { return NaN }
  if (!$js_isfin(%a)) || (!$js_isfin(%b)) { return $js_arithinf(%o,%a,%b) }
  if (%o === add) { return $calc( ( %a ) + ( %b ) ) }
  if (%o === sub) { return $calc( ( %a ) - ( %b ) ) }
  if (%o === mul) { return $calc( ( %a ) * ( %b ) ) }
  if (%o === div) {
    if (%b == 0) {
      if (%a == 0) { return NaN }
      return $iif(%a > 0,Inf,-Inf)
    }
    return $calc( ( %a ) / ( %b ) )
  }
  if (%o === mod) {
    if (%b == 0) { return NaN }
    return $calc( ( %a ) % ( %b ) )
  }
  if (%o === exp) {
    if (%b == 0) { return 1 }
    if (%a == 0) && (%b < 0) { return Inf }
    return $calc( ( %a ) ^ ( %b ) )
  }
  return NaN
}

; arithmetic when Infinity is involved (simplified IEEE rules)
alias js_arithinf {
  var -n %o = $1
  var -n %a = $2
  var -n %b = $3
  var -n %sa = $iif(%a === Inf,1,$iif(%a === -Inf,-1,$iif(%a < 0,-1,$iif(%a > 0,1,0))))
  var -n %sb = $iif(%b === Inf,1,$iif(%b === -Inf,-1,$iif(%b < 0,-1,$iif(%b > 0,1,0))))
  var -n %fa = $js_isfin(%a)
  var -n %fb = $js_isfin(%b)
  if (%o === add) || (%o === sub) {
    if (%o === sub) { var -n %sb = $calc( 0 - %sb ) }
    if (!%fa) && (!%fb) { return $iif(%sa == %sb,$iif(%sa > 0,Inf,-Inf),NaN) }
    if (!%fa) { return %a }
    return $iif(%sb > 0,Inf,-Inf)
  }
  if (%o === mul) {
    if (%sa == 0) || (%sb == 0) { return NaN }
    return $iif($calc( %sa * %sb ) > 0,Inf,-Inf)
  }
  if (%o === div) {
    if (!%fa) && (!%fb) { return NaN }
    if (!%fb) { return 0 }
    return $iif($calc( %sa * $iif(%sb == 0,1,%sb) ) > 0,Inf,-Inf)
  }
  if (%o === mod) {
    if (!%fa) { return NaN }
    return %a
  }
  if (%o === exp) {
    if (%b === Inf) { return $iif($abs(%a) > 1,Inf,0) }
    if (%b === -Inf) { return $iif($abs(%a) > 1,0,Inf) }
    if (%a === Inf) { return $iif(%b > 0,Inf,0) }
    return $iif(%b > 0,$iif($calc( %b % 2 ) == 1,-Inf,Inf),0)
  }
  return NaN
}

; ToInt32 / ToUint32 of a number text
alias js_toint32 {
  var -n %u = $js_touint32($1)
  if (%u >= 2147483648) { return $calc( %u - 4294967296 ) }
  return %u
}

alias js_touint32 {
  var -n %n = $1
  if (!$js_isfin(%n)) { return 0 }
  var -n %n = $int(%n)
  var -n %n = $calc( %n % 4294967296 )
  if (%n < 0) { var -n %n = $calc( %n + 4294967296 ) }
  return %n
}

; ---------------------------------------------------------- conversions ----

; typeof
alias js_typeof {
  var -n %ty = $left($1,1)
  if (%ty === u) { return undefined }
  if (%ty === z) { return object }
  if (%ty === t) || (%ty === f) { return boolean }
  if (%ty === n) { return number }
  if (%ty === s) { return string }
  if ($js_iscallable($1)) { return function }
  return object
}

alias js_iscallable {
  if ($left($1,1) !=== o) { return 0 }
  var -n %id = $mid($1,2)
  if ($hget(jso,%id $+ :fn)) || ($hget(jso,%id $+ :nat)) || ($hget(jso,%id $+ :bnd)) { return 1 }
  return 0
}

; ToBoolean -> 1 or 0
alias js_truthy {
  var -n %v = $1
  var -n %ty = $left(%v,1)
  if (%ty === o) || (%ty === t) { return 1 }
  if (%ty === s) { return $iif(%v === s,0,1) }
  if (%ty === n) { return $iif(%v === n0 || %v === nNaN,0,1) }
  return 0
}

alias js_bool { return $iif($1,t,f) }

; ToString: value token -> encoded string body
alias js_tostr {
  var -n %v = $1
  var -n %ty = $left(%v,1)
  if (%ty === s) { return $mid(%v,2) }
  if (%ty === n) { return $js_numstr($mid(%v,2)) }
  if (%ty === u) { return undefined }
  if (%ty === z) { return null }
  if (%ty === t) { return true }
  if (%ty === f) { return false }
  if (%ty === o) {
    var -n %p = $js_toprim(%v,string)
    if (%jsc) { return $null }
    return $js_tostr(%p)
  }
  return $null
}

; ToPrimitive: objects -> primitive token, by valueOf/toString
alias js_toprim {
  var -n %v = $1
  if ($left(%v,1) !=== o) { return %v }
  ; (keys are case-escaped)
  var -n %order = value^Of to^String
  if ($2 === string) { var -n %order = to^String value^Of }
  var -n %i = 1
  while (%i <= 2) {
    var -n %m = $js_get(%v,$gettok(%order,%i,32))
    if (%jsc) { return u }
    if ($js_iscallable(%m)) {
      var -n %r = $js_call(%m,%v,$null)
      if (%jsc) { return u }
      if ($left(%r,1) !=== o) { return %r }
    }
    inc %i
  }
  noop $js_throw(TypeError,Cannot convert object to primitive value)
  return u
}

; ToPropertyKey: value token -> hash-safe key
alias js_tokey {
  var -n %v = $1
  if ($left(%v,1) === s) { return $js_kenc($mid(%v,2)) }
  if ($left(%v,1) === n) { return $js_kenc($js_numstr($mid(%v,2))) }
  return $js_kenc($js_tostr(%v))
}

; ToObject for property access on primitives -> prototype id to search
alias js_primproto {
  var -n %ty = $left($1,1)
  if (%ty === s) { return $hget(jsm,SP) }
  if (%ty === n) { return $hget(jsm,NP) }
  if (%ty === t) || (%ty === f) { return $hget(jsm,BP) }
  return $null
}

; ---------------------------------------------------------------- objects --

; new object: $js_new(prototype token,class) -> o<id>
alias js_new {
  var -n %id = $calc( $hget(jsm,oid) + 1 )
  hadd jsm oid %id
  hadd jso %id $+ :p $iif($1,$1,z)
  if ($2) { hadd jso %id $+ :c $2 }
  return o $+ %id
}

alias js_newobj { return $js_new($hget(jsm,OP),Object) }

; new array from a list of value tokens
alias js_newarr {
  var -n %a = $js_new($hget(jsm,AP),Array)
  var -n %id = $mid(%a,2)
  var -n %n = $numtok($1,32)
  var -n %i = 1
  while (%i <= %n) {
    hadd jso %id $+ . $+ $calc( %i - 1 ) $gettok($1,%i,32)
    inc %i
  }
  hadd jso %id $+ :len %n
  return %a
}

; array elements as a token list (holes become u)
alias js_arrlist {
  var -n %id = $mid($1,2)
  var -n %n = $hget(jso,%id $+ :len)
  var -n %out = $null
  var -n %i = 0
  while (%i < %n) {
    var -n %v = $hget(jso,%id $+ . $+ %i)
    var -n %out = %out $iif(%v == $null,u,%v)
    inc %i
  }
  return %out
}

alias js_isarr { return $iif($left($1,1) === o && $hget(jso,$mid($1,2) $+ :len) != $null,1,0) }

; [[Get]]: $js_get(value,key[,receiver]) -> value token. Throws on undefined/
; null. Getters run with the receiver as this (super.x passes the instance).
alias js_get {
  var -n %o = $1
  var -n %k = $2
  var -n %ty = $left(%o,1)
  var -n %cur = $null
  if (%ty === o) {
    var -n %cur = $mid(%o,2)
    if (%k === length) {
      var -n %l = $hget(jso,%cur $+ :len)
      if (%l != $null) { return n $+ %l }
    }
  }
  elseif (%ty === s) {
    if (%k === length) { return n $+ $len($js_dec($mid(%o,2))) }
    if ($regex(%k,/^(0|[1-9]\d*)$/)) {
      var -n %t = $js_dec($mid(%o,2))
      if (%k < $len(%t)) { return s $+ $js_enc($mid(%t,$calc( %k + 1 ),1)) }
      return u
    }
    var -n %cur = $mid($js_primproto(%o),2)
  }
  elseif (%ty === u) || (%ty === z) {
    noop $js_throw(TypeError,Cannot read properties of $iif(%ty === u,undefined,null) (reading ' $+ $js_dec($js_kdec(%k)) $+ '))
    return u
  }
  else { var -n %cur = $mid($js_primproto(%o),2) }
  while (%cur) {
    var -n %v = $hget(jso,%cur $+ . $+ %k)
    if (%v != $null) {
      if ($left(%v,1) === g) { return $js_getacc(%v,$iif($3,$3,%o)) }
      return %v
    }
    if (%k === prototype) && ($hget(jso,%cur $+ :fn)) && (!$hget(jso,%cur $+ :arrow)) && (%cur == $mid(%o,2)) { return $js_mkproto(%cur) }
    var -n %p = $hget(jso,%cur $+ :p)
    if (%p === z) || (%p == $null) { return u }
    var -n %cur = $mid(%p,2)
  }
  return u
}

; call an accessor's getter: $js_getacc(g<get>_<set>,receiver)
alias js_getacc {
  var -n %g = $gettok($mid($1,2),1,95)
  if (%g == 0) { return u }
  return $js_call(o $+ %g,$2,$null)
}

; the prototype object of a function, created on first use
alias js_mkproto {
  var -n %p = $js_newobj
  hadd jso $1 $+ .prototype %p
  hadd jso $mid(%p,2) $+ .constructor o $+ $1
  return %p
}

; own property lookup (no prototype chain); $null if absent
alias js_getown {
  var -n %id = $mid($1,2)
  if ($2 === length) && ($hget(jso,%id $+ :len) != $null) { return n $+ $hget(jso,%id $+ :len) }
  return $hget(jso,%id $+ . $+ $2)
}

; [[Set]]: $js_put(object,key,value). Primitives are ignored.
alias js_put {
  var -n %o = $1
  var -n %k = $2
  var -n %v = $3
  var -n %ty = $left(%o,1)
  if (%ty === u) || (%ty === z) {
    noop $js_throw(TypeError,Cannot set properties of $iif(%ty === u,undefined,null) (setting ' $+ $js_dec($js_kdec(%k)) $+ '))
    return
  }
  if (%ty !=== o) { return }
  var -n %id = $mid(%o,2)
  if ($hget(jso,%id $+ :frozen)) { return }
  var -n %len = $hget(jso,%id $+ :len)
  if (%len != $null) {
    if ($regex(%k,/^(0|[1-9]\d*)$/)) {
      hadd jso %id $+ . $+ %k %v
      if (%k >= %len) { hadd jso %id $+ :len $calc( %k + 1 ) }
      return
    }
    if (%k === length) {
      var -n %nl = $int($js_tonum(%v))
      var -n %i = %nl
      while (%i < %len) {
        hdel jso %id $+ . $+ %i
        inc %i
      }
      hadd jso %id $+ :len %nl
      return
    }
  }
  if ($hget(jsm,acc)) {
    var -n %cur = %id
    while (%cur) {
      var -n %pv = $hget(jso,%cur $+ . $+ %k)
      if (%pv != $null) {
        if ($left(%pv,1) === g) {
          var -n %s = $gettok($mid(%pv,2),2,95)
          if (%s) { noop $js_call(o $+ %s,%o,%v) }
          return
        }
        break
      }
      var -n %p = $hget(jso,%cur $+ :p)
      if (%p === z) || (%p == $null) { break }
      var -n %cur = $mid(%p,2)
    }
  }
  ; #private names are never enumerable
  if ($hget(jso,%id $+ . $+ %k) == $null) && ($left(%k,1) !== $chr(35)) { hadd jso %id $+ :k $hget(jso,%id $+ :k) %k }
  hadd jso %id $+ . $+ %k %v
}

; define an own property that is not enumerable (methods, name, length)
alias js_defhidden { hadd jso $mid($1,2) $+ . $+ $2 $3 }

; define an accessor: $js_defacc(object,key,getter,setter,enumerable)
alias js_defacc {
  var -n %id = $mid($1,2)
  var -n %old = $hget(jso,%id $+ . $+ $2)
  var -n %g = $iif($3 && $3 !=== u,$mid($3,2),0)
  var -n %s = $iif($4 && $4 !=== u,$mid($4,2),0)
  if ($left(%old,1) === g) {
    if (%g == 0) { var -n %g = $gettok($mid(%old,2),1,95) }
    if (%s == 0) { var -n %s = $gettok($mid(%old,2),2,95) }
  }
  if ($5) && (%old == $null) { hadd jso %id $+ :k $hget(jso,%id $+ :k) $2 }
  hadd jso %id $+ . $+ $2 g $+ %g $+ _ $+ %s
  hadd jsm acc 1
}

; delete an own property
alias js_delete {
  if ($left($1,1) !=== o) { return }
  var -n %id = $mid($1,2)
  if ($hget(jso,%id $+ :frozen)) { return }
  hdel jso %id $+ . $+ $2
  var -n %k = $hget(jso,%id $+ :k)
  if (%k != $null) { hadd jso %id $+ :k $remtokcs(%k,$2,1,32) }
}

; own enumerable keys, in order: array indexes first
alias js_ownkeys {
  var -n %id = $mid($1,2)
  var -n %out = $null
  var -n %len = $hget(jso,%id $+ :len)
  if (%len != $null) {
    var -n %i = 0
    while (%i < %len) {
      if ($hget(jso,%id $+ . $+ %i) != $null) { var -n %out = %out %i }
      inc %i
    }
  }
  ; like JavaScript: integer-like keys first, in numeric order, then the rest
  ; in the order they were added
  var -n %ints = $null
  var -n %rest = $null
  var -n %k = $hget(jso,%id $+ :k)
  var -n %n = $numtok(%k,32)
  var -n %i = 1
  while (%i <= %n) {
    var -n %key = $gettok(%k,%i,32)
    if ($hget(jso,%id $+ . $+ %key) != $null) && (!$istokcs(%out,%key,32)) {
      if ($regex(%key,/^(0|[1-9]\d{0,8})$/)) && (!$istokcs(%ints,%key,32)) { var -n %ints = %ints %key }
      elseif (!$istokcs(%rest,%key,32)) { var -n %rest = %rest %key }
    }
    inc %i
  }
  if (%ints != $null) { var -n %ints = $sorttok(%ints,32,n) }
  return %out %ints %rest
}

; does the object or its prototype chain have this key?
alias js_haskey {
  if ($left($1,1) !=== o) { return 0 }
  var -n %cur = $mid($1,2)
  if ($2 === length) && ($hget(jso,%cur $+ :len) != $null) { return 1 }
  while (%cur) {
    if ($hget(jso,%cur $+ . $+ $2) != $null) { return 1 }
    var -n %p = $hget(jso,%cur $+ :p)
    if (%p === z) || (%p == $null) { return 0 }
    var -n %cur = $mid(%p,2)
  }
  return 0
}

; instanceof
alias js_instanceof {
  var -n %o = $1
  var -n %f = $2
  if (!$js_iscallable(%f)) {
    noop $js_throw(TypeError,Right-hand side of 'instanceof' is not callable)
    return 0
  }
  if ($left(%o,1) !=== o) { return 0 }
  var -n %proto = $js_get(%f,prototype)
  var -n %cur = $hget(jso,$mid(%o,2) $+ :p)
  while (%cur) && (%cur !=== z) {
    if (%cur === %proto) { return 1 }
    var -n %cur = $hget(jso,$mid(%cur,2) $+ :p)
  }
  return 0
}

; ----------------------------------------------------------------- scopes --

alias js_newenv {
  var -n %id = $calc( $hget(jsm,eid) + 1 )
  hadd jsm eid %id
  hadd jse %id $+ :p $iif($1,$1,0)
  return %id
}

; declare a name in exactly this scope: $js_decl(env,key,value[,const])
alias js_decl {
  if ($hget(jse,$1 $+ . $+ $2) == $null) { hadd jse $1 $+ :k $hget(jse,$1 $+ :k) $2 }
  hadd jse $1 $+ . $+ $2 $3
  if ($4) { hadd jse $1 $+ ~ $+ $2 1 }
}

; which scope holds a name? -> env id or 0
alias js_where {
  var -n %e = $1
  while (%e) {
    if ($hget(jse,%e $+ . $+ $2) != $null) { return %e }
    var -n %e = $hget(jse,%e $+ :p)
  }
  return 0
}

; read a variable; throws ReferenceError if it does not exist
alias js_lookup {
  var -n %e = $1
  while (%e) {
    var -n %v = $hget(jse,%e $+ . $+ $2)
    if (%v != $null) { return %v }
    var -n %e = $hget(jse,%e $+ :p)
  }
  noop $js_throw(ReferenceError,$js_dec($js_kdec($2)) is not defined)
  return u
}

; assign to an existing variable (or create a global)
alias js_assign {
  var -n %e = $js_where($1,$2)
  if (!%e) { var -n %e = 1 }
  elseif ($hget(jse,%e $+ ~ $+ $2)) {
    noop $js_throw(TypeError,Assignment to constant variable.)
    return
  }
  if ($hget(jse,%e $+ . $+ $2) == $null) { hadd jse %e $+ :k $hget(jse,%e $+ :k) $2 }
  hadd jse %e $+ . $+ $2 $3
}

; the nearest "this"
alias js_this {
  var -n %e = $1
  while (%e) {
    var -n %t = $hget(jse,%e $+ :this)
    if (%t != $null) { return %t }
    var -n %e = $hget(jse,%e $+ :p)
  }
  return u
}

; the nearest function scope's function object
alias js_curfn {
  var -n %e = $1
  while (%e) {
    var -n %f = $hget(jse,%e $+ :fo)
    if (%f != $null) { return %f }
    var -n %e = $hget(jse,%e $+ :p)
  }
  return $null
}

; a closure keeps its scope chain alive
alias js_capture {
  var -n %e = $1
  while (%e > 1) {
    if ($hget(jse,%e $+ :cap)) { return }
    hadd jse %e $+ :cap 1
    var -n %e = $hget(jse,%e $+ :p)
  }
}

; free a scope that no closure holds
alias js_freeenv {
  var -n %e = $1
  if (%e <= 1) || ($hget(jse,%e $+ :cap)) { return }
  var -n %k = $hget(jse,%e $+ :k)
  var -n %n = $numtok(%k,32)
  var -n %i = 1
  while (%i <= %n) {
    hdel jse %e $+ . $+ $gettok(%k,%i,32)
    hdel jse %e $+ ~ $+ $gettok(%k,%i,32)
    inc %i
  }
  hdel jse %e $+ :k
  hdel jse %e $+ :p
  hdel jse %e $+ :this
  hdel jse %e $+ :fo
  hdel jse %e $+ :nt
}

; ----------------------------------------------------------------- errors --

; throw a new error: $js_throw(TypeError,message) -> u
alias js_throw {
  var -n %ctor = $hget(jse,1. $+ $js_kenc($1))
  var -n %e = $js_new($iif(%ctor,$js_get(%ctor,prototype),$hget(jsm,EP)),Error)
  hadd jso $mid(%e,2) $+ .message s $+ $js_enc($2-)
  hadd jso $mid(%e,2) $+ .stack s $+ $js_enc($1: $2- $+ $iif($hget(jsm,line),$chr(10) $+ $str($chr(32),4) $+ at line $hget(jsm,line)))
  %jsc = x
  %jscv = %e
  return u
}

; throw any value
alias js_throwv {
  %jsc = x
  %jscv = $1
  return u
}

; text of an error value for "Uncaught ..." messages
alias js_errtext {
  var -n %v = $1
  if ($left(%v,1) === o) {
    var -n %saved = %jsc
    unset %jsc
    var -n %s = $js_tostr(%v)
    var -n %ln = $hget(jso,$mid(%v,2) $+ :line)
    if (%jsc) { unset %jsc | var -n %s = $js_enc([object]) }
    %jsc = %saved
    return $js_dec(%s) $+ $iif(%ln,$chr(32) $+ (line %ln $+ ))
  }
  if ($left(%v,1) === s) { return $js_dec($mid(%v,2)) }
  return $js_dec($js_tostr(%v))
}

; ------------------------------------------------------------------ calls --

; $js_call(function,this,args) -> result token
alias js_call {
  var -n %f = $1
  if ($left(%f,1) !=== o) {
    noop $js_throw(TypeError,$js_desc(%f) is not a function)
    return u
  }
  var -n %id = $mid(%f,2)
  var -n %nat = $hget(jso,%id $+ :nat)
  if (%nat) {
    %jsnt = $2
    %jsna = $3
    %jsnf = %f
    %jsnew = 0
    return $($+($chr(36),%nat),2)
  }
  var -n %b = $hget(jso,%id $+ :bnd)
  if (%b) { return $js_call(%b,$hget(jso,%id $+ :bthis),$hget(jso,%id $+ :bargs) $3) }
  var -n %fn = $hget(jso,%id $+ :fn)
  if (!%fn) {
    noop $js_throw(TypeError,$js_desc(%f) is not a function)
    return u
  }
  if ($hget(jso,%id $+ :cls)) {
    noop $js_throw(TypeError,Class constructor $js_dec($mid($hget(jso,%id $+ .name),2)) cannot be invoked without 'new')
    return u
  }
  return $js_invoke(%id,%fn,$2,$3,$null)
}

; describe a value for error messages
alias js_desc {
  var -n %v = $1
  var -n %ty = $left(%v,1)
  if (%ty === s) { return " $+ $js_dec($mid(%v,2)) $+ " }
  if (%ty === o) { return $iif($js_isarr(%v),[array],[object]) }
  return $js_dec($js_tostr(%v))
}

; run a JS function body: $js_invoke(id,fnnode,this,args,newtarget)
alias js_invoke {
  var -n %id = $1
  var -n %fn = $2
  ; mSL allows 1000 nested aliases and one JavaScript call uses several, so
  ; stop well before that with an error scripts can catch
  if ($hget(jsm,depth) >= 100) { return $js_throw(RangeError,Maximum call stack size exceeded) }
  hinc jsm depth
  var -n %r = $js_invoke_body($1,$2,$3,$4,$5)
  hdec jsm depth
  return %r
}

alias js_invoke_body {
  var -n %id = $1
  var -n %fn = $2
  var -n %env = $js_newenv($hget(jso,%id $+ :env))
  if (!$hget(jsa,%fn $+ :arrow)) {
    hadd jse %env $+ :this $3
    hadd jse %env $+ :fo o $+ %id
    if ($5) { hadd jse %env $+ :nt $5 }
  }
  ; hoisted var names and function declarations
  var -n %hv = $hget(jsa,%fn $+ :hv)
  var -n %n = $numtok(%hv,32)
  var -n %i = 1
  while (%i <= %n) {
    if ($hget(jse,%env $+ . $+ $gettok(%hv,%i,32)) == $null) { noop $js_decl(%env,$gettok(%hv,%i,32),u) }
    inc %i
  }
  if ($hget(jsa,%fn $+ :ua)) { noop $js_decl(%env,arguments,$js_newarr($4)) }
  noop $js_params(%fn,%env,$4)
  if (%jsc) { noop $js_freeenv(%env) | return u }
  noop $js_hoistfns(%fn,%env)
  var -n %body = $hget(jsa,%fn $+ :b)
  var -n %r = u
  if ($hget(jsa,%fn $+ :ex)) {
    var -n %r = $js_ev(%body,%env)
  }
  else {
    noop $js_exlist($hget(jsa,%body $+ :s),%env)
    if (%jsc === r) {
      var -n %r = %jscv
      unset %jsc %jscv
    }
    elseif (%jsc === b) || (%jsc === c) { unset %jsc %jscv %jscl }
  }
  noop $js_freeenv(%env)
  ; an async function returns a promise of its result
  if ($hget(jsa,%fn $+ :async)) {
    var -n %p = $js_newpromise
    if (%jsc === x) {
      var -n %e = %jscv
      unset %jsc %jscv %jscl
      noop $js_preject(%p,%e)
    }
    else { noop $js_presolve(%p,%r) }
    return %p
  }
  return %r
}

; bind parameters: $js_params(fnnode,env,args)
alias js_params {
  var -n %ps = $hget(jsa,$1 $+ :ps)
  var -n %n = $numtok(%ps,32)
  var -n %i = 1
  while (%i <= %n) {
    var -n %p = $gettok(%ps,%i,32)
    if ($hget(jsa,%p $+ :t) === rest) {
      noop $js_bind($hget(jsa,%p $+ :a),$js_newarr($gettok($3,%i $+ -,32)),$2,let)
      return
    }
    var -n %v = $gettok($3,%i,32)
    noop $js_bind(%p,$iif(%v == $null,u,%v),$2,let)
    if (%jsc) { return }
    inc %i
  }
}

; declare a function's hoisted function declarations in its scope
alias js_hoistfns {
  var -n %hf = $hget(jsa,$1 $+ :hf)
  var -n %n = $numtok(%hf,32)
  var -n %i = 1
  while (%i <= %n) {
    var -n %d = $gettok(%hf,%i,32)
    noop $js_decl($2,$hget(jsa,%d $+ :k),$js_closure($hget(jsa,%d $+ :f),$2))
    inc %i
  }
}

; make a function object for a function node in a scope
alias js_closure {
  var -n %f = $js_new($hget(jsm,FP),Function)
  var -n %id = $mid(%f,2)
  hadd jso %id $+ :fn $1
  hadd jso %id $+ :env $2
  if ($hget(jsa,$1 $+ :arrow)) { hadd jso %id $+ :arrow 1 }
  hadd jso %id $+ .name s $+ $hget(jsa,$1 $+ :nm)
  hadd jso %id $+ .length n $+ $hget(jsa,$1 $+ :np)
  noop $js_capture($2)
  return %f
}

; new F(...args): $js_construct(F,args[,newtarget])
alias js_construct {
  var -n %f = $1
  var -n %nt = $iif($3,$3,%f)
  if ($left(%f,1) !=== o) {
    noop $js_throw(TypeError,$js_desc(%f) is not a constructor)
    return u
  }
  var -n %id = $mid(%f,2)
  var -n %b = $hget(jso,%id $+ :bnd)
  if (%b) { return $js_construct(%b,$hget(jso,%id $+ :bargs) $2) }
  var -n %nat = $hget(jso,%id $+ :nat)
  if (%nat) {
    if (!$hget(jso,%id $+ :ctor)) {
      noop $js_throw(TypeError,$js_dec($mid($hget(jso,%id $+ .name),2)) is not a constructor)
      return u
    }
    var -n %proto = $js_get(%nt,prototype)
    var -n %this = $js_new($iif($left(%proto,1) === o,%proto,$hget(jsm,OP)),Object)
    %jsnt = %this
    %jsna = $2
    %jsnf = %f
    %jsnew = 1
    var -n %r = $($+($chr(36),%nat),2)
    %jsnew = 0
    if (%jsc) { return u }
    if ($left(%r,1) === o) { return %r }
    return %this
  }
  var -n %fn = $hget(jso,%id $+ :fn)
  if (!%fn) || ($hget(jso,%id $+ :arrow)) || ($hget(jsa,%fn $+ :meth)) {
    noop $js_throw(TypeError,$js_desc(%f) is not a constructor)
    return u
  }
  var -n %proto = $js_get(%nt,prototype)
  var -n %this = $js_new($iif($left(%proto,1) === o,%proto,$hget(jsm,OP)),Object)
  if ($hget(jso,%id $+ :cls)) && (!$hget(jso,%id $+ :derived)) {
    noop $js_initfields(%id,%this)
    if (%jsc) { return u }
  }
  var -n %r = $js_invoke(%id,%fn,%this,$2,%nt)
  if (%jsc) { return u }
  if ($left(%r,1) === o) { return %r }
  return %this
}

; run a class's field initialisers on an instance
alias js_initfields {
  var -n %fl = $hget(jso,$1 $+ :fields)
  if (%fl == $null) { return }
  var -n %env = $js_newenv($hget(jso,$1 $+ :env))
  hadd jse %env $+ :this $2
  hadd jse %env $+ :fo o $+ $1
  var -n %n = $numtok(%fl,32)
  var -n %i = 1
  while (%i <= %n) {
    var -n %fd = $gettok(%fl,%i,32)
    var -n %k = $hget(jsa,%fd $+ :k)
    if ($hget(jsa,%fd $+ :c)) { var -n %k = $js_tokey($js_ev(%k,%env)) }
    var -n %init = $hget(jsa,%fd $+ :v)
    var -n %v = $iif(%init,$js_ev(%init,%env),u)
    if (%jsc) { return }
    noop $js_put($2,%k,%v)
    inc %i
  }
}

; super(...args) inside a derived constructor
alias js_supercall {
  var -n %env = $1
  ; the running constructor is the class itself; its [[Prototype]] is the parent
  var -n %cls = $js_curfn(%env)
  var -n %parent = $hget(jso,$mid(%cls,2) $+ :p)
  var -n %this = $js_this(%env)
  if (!$js_iscallable(%parent)) {
    noop $js_throw(TypeError,Super constructor is not a constructor)
    return u
  }
  var -n %pid = $mid(%parent,2)
  var -n %nat = $hget(jso,%pid $+ :nat)
  if (%nat) {
    %jsnt = %this
    %jsna = $2
    %jsnf = %parent
    %jsnew = 1
    var -n %r = $($+($chr(36),%nat),2)
    %jsnew = 0
  }
  else {
    if (!$hget(jso,%pid $+ :derived)) {
      noop $js_initfields(%pid,%this)
      if (%jsc) { return u }
    }
    noop $js_invoke(%pid,$hget(jso,%pid $+ :fn),%this,$2,$hget(jse,%env $+ :nt))
  }
  if (%jsc) { return u }
  noop $js_initfields($mid(%cls,2),%this)
  return u
}
