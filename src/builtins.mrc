; ============================================================================
;  msl-js-rt: built-in objects and functions
; ============================================================================
;
; A native function is an mSL alias. It is called with this in %jsnt, the
; argument list in %jsna, the function object in %jsnf and %jsnew = 1 when
; called with new; it must copy them into locals before calling anything.
; It returns a value token, or calls $js_throw.

; ------------------------------------------------------------------- setup --

; create every table and built-in (once)
alias js.init {
  if ($hget(jsm,ready)) { return }
  if (!$hget(jsm)) { hmake jsm 200 }
  if (!$hget(jsa)) { hmake jsa 5000 }
  if (!$hget(jse)) { hmake jse 5000 }
  if (!$hget(jso)) { hmake jso 10000 }
  hadd jsm oid 0
  hadd jsm eid 0
  hadd jsm aid 0
  unset %jsc %jscv %jscl %jsoc
  js.lexinit
  js.parseinit
  ; the global scope is env 1
  noop $js_newenv(0)
  ; prototypes
  var -n %op = $js_new(z,Object)
  hadd jsm OP %op
  hadd jsm FP $js_new(%op,Function)
  hadd jsm AP $js_new(%op,Array)
  hadd jsm SP $js_new(%op,String)
  hadd jsm NP $js_new(%op,Number)
  hadd jsm BP $js_new(%op,Boolean)
  hadd jsm EP $js_new(%op,Error)
  hadd jsm MP $js_new(%op,Map)
  hadd jsm SetP $js_new(%op,Set)
  hadd jsm DP $js_new(%op,Date)
  hadd jsm RP $js_new(%op,RegExp)
  hadd jsm PP $js_new(%op,Promise)
  ; constructors and globals
  js.b.object
  js.b.function
  js.b.array
  js.b.string
  js.b.number
  js.b.boolean
  js.b.errors
  js.b.math
  js.b.json
  js.b.mapset
  js.b.date
  js.b.regexp
  js.b.promise
  js.b.globals
  js.b.console
  js.b.mirc
  ; default class constructors
  js.defctors
  hadd jsm ready 1
}

; define natives on an object: js.defs <object> name:arity:alias ...
alias js.defs {
  var -n %o = $1
  var -n %n = $numtok($2-,32)
  var -n %i = 1
  while (%i <= %n) {
    var -n %spec = $gettok($2-,%i,32)
    noop $js_defhidden(%o,$js_kenc($gettok(%spec,1,58)),$js_mknat($gettok(%spec,1,58),$gettok(%spec,2,58),$gettok(%spec,3,58)))
    inc %i
  }
}

; a native function object: $js_mknat(name,arity,alias[,constructor])
alias js_mknat {
  var -n %f = $js_new($hget(jsm,FP),Function)
  var -n %id = $mid(%f,2)
  hadd jso %id $+ :nat $3
  hadd jso %id $+ .name s $+ $js_enc($1)
  hadd jso %id $+ .length n $+ $2
  if ($4) { hadd jso %id $+ :ctor 1 }
  return %f
}

; a global constructor: js.gctor Name arity alias prototypeKey
alias js_gctor {
  var -n %f = $js_mknat($1,$2,$3,1)
  var -n %proto = $hget(jsm,$4)
  noop $js_defhidden(%f,prototype,%proto)
  noop $js_defhidden(%proto,constructor,%f)
  noop $js_decl(1,$js_kenc($1),%f)
  return %f
}

; a global function
alias js.gfn { noop $js_decl(1,$js_kenc($1),$js_mknat($1,$2,$3)) }

; argument N of a list, or u
alias js_arg {
  var -n %v = $gettok($1,$2,32)
  if (%v == $null) { return u }
  return %v
}

; argument as an integer (for indexes), with a default
alias js_argint {
  var -n %v = $gettok($1,$2,32)
  if (%v == $null) || (%v === u) { return $3 }
  var -n %n = $js_tonum(%v)
  if (%n === NaN) { return 0 }
  if (%n === Inf) { return 999999999 }
  if (%n === -Inf) { return -999999999 }
  return $int(%n)
}

; relative index helper: negative counts from the end, clamped to 0..len
alias js_relidx {
  var -n %i = $1
  if (%i < 0) { var -n %i = $calc( $2 + %i ) }
  if (%i < 0) { var -n %i = 0 }
  if (%i > $2) { var -n %i = $2 }
  return %i
}

; default constructors, parsed once from source
alias js.defctors {
  var -n %o = $chr(123)
  var -n %c = $chr(125)
  noop $js_lex(t,class A %o constructor() %o %c %c class B extends A %o constructor(...args) %o super(...args) %c %c)
  var -n %prog = $js_parse
  var -n %s = $hget(jsa,%prog $+ :s)
  hadd jsm defctor0 $hget(jsa,$hget(jsa,$gettok(%s,1,32) $+ :c) $+ :ctor)
  hadd jsm defctor1 $hget(jsa,$hget(jsa,$gettok(%s,2,32) $+ :c) $+ :ctor)
}

; ------------------------------------------------------------------ Object --

alias js.b.object {
  var -n %f = $js_gctor(Object,1,js_b_object,OP)
  js.defs %f keys:1:js_b_okeys values:1:js_b_ovalues entries:1:js_b_oentries assign:2:js_b_oassign freeze:1:js_b_ofreeze isFrozen:1:js_b_oisfrozen create:2:js_b_ocreate getPrototypeOf:1:js_b_ogetproto setPrototypeOf:2:js_b_osetproto defineProperty:3:js_b_odefprop getOwnPropertyNames:1:js_b_okeys fromEntries:1:js_b_ofromentries is:2:js_b_ois hasOwn:2:js_b_ohasown seal:1:js_b_ofreeze
  js.defs $hget(jsm,OP) hasOwnProperty:1:js_b_ohasownproto toString:0:js_b_otostring toLocaleString:0:js_b_otostring valueOf:0:js_b_ovalueof isPrototypeOf:1:js_b_oisproto propertyIsEnumerable:1:js_b_ohasownproto
}

alias js_b_object {
  var -n %v = $js_arg(%jsna,1)
  if ($left(%v,1) === o) { return %v }
  if (%v === u) || (%v === z) { return $iif(%jsnew,%jsnt,$js_newobj) }
  return $js_wrapprim(%v)
}

; a wrapper object for a primitive (rarely needed)
alias js_wrapprim {
  var -n %o = $js_new($js_primproto($1),Object)
  hadd jso $mid(%o,2) $+ :prim $1
  return %o
}

alias js_b_okeys {
  var -n %o = $js_arg(%jsna,1)
  if ($left(%o,1) === s) { var -n %o = $js_wrapstr(%o) }
  if ($left(%o,1) !=== o) { return $js_newarr($null) }
  var -n %keys = $js_ownkeys(%o)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%keys,32)) {
    var -n %out = %out s $+ $js_kdec($gettok(%keys,%i,32))
    inc %i
  }
  return $js_newarr(%out)
}

; an array-like object for a string's characters
alias js_wrapstr {
  var -n %a = $js_newarr($js_iterlist($1))
  return %a
}

alias js_b_ovalues {
  var -n %o = $js_arg(%jsna,1)
  if ($left(%o,1) === s) { return $js_wrapstr(%o) }
  if ($left(%o,1) !=== o) { return $js_newarr($null) }
  var -n %keys = $js_ownkeys(%o)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%keys,32)) {
    var -n %out = %out $js_get(%o,$gettok(%keys,%i,32))
    if (%jsc) { return u }
    inc %i
  }
  return $js_newarr(%out)
}

alias js_b_oentries {
  var -n %o = $js_arg(%jsna,1)
  if ($left(%o,1) === s) { var -n %o = $js_wrapstr(%o) }
  if ($left(%o,1) !=== o) { return $js_newarr($null) }
  var -n %keys = $js_ownkeys(%o)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%keys,32)) {
    var -n %k = $gettok(%keys,%i,32)
    var -n %v = $js_get(%o,%k)
    if (%jsc) { return u }
    var -n %out = %out $js_newarr(s $+ $js_kdec(%k) %v)
    inc %i
  }
  return $js_newarr(%out)
}

alias js_b_oassign {
  var -n %args = %jsna
  var -n %t = $js_arg(%args,1)
  if ($left(%t,1) !=== o) { return $js_throw(TypeError,Cannot convert undefined or null to object) }
  var -n %i = 2
  while (%i <= $numtok(%args,32)) {
    noop $js_assignprops(%t,$gettok(%args,%i,32))
    if (%jsc) { return u }
    inc %i
  }
  return %t
}

alias js_b_ofreeze {
  var -n %o = $js_arg(%jsna,1)
  if ($left(%o,1) === o) { hadd jso $mid(%o,2) $+ :frozen 1 }
  return %o
}

alias js_b_oisfrozen {
  var -n %o = $js_arg(%jsna,1)
  if ($left(%o,1) !=== o) { return t }
  return $js_bool($hget(jso,$mid(%o,2) $+ :frozen))
}

alias js_b_ocreate {
  var -n %args = %jsna
  var -n %p = $js_arg(%args,1)
  if ($left(%p,1) !=== o) && (%p !=== z) { return $js_throw(TypeError,Object prototype may only be an Object or null) }
  var -n %o = $js_new(%p,Object)
  var -n %props = $js_arg(%args,2)
  if ($left(%props,1) === o) { noop $js_defprops(%o,%props) }
  return %o
}

alias js_b_ogetproto {
  var -n %o = $js_arg(%jsna,1)
  if ($left(%o,1) === o) { return $hget(jso,$mid(%o,2) $+ :p) }
  var -n %p = $js_primproto(%o)
  return $iif(%p,%p,z)
}

alias js_b_osetproto {
  var -n %args = %jsna
  var -n %o = $js_arg(%args,1)
  var -n %p = $js_arg(%args,2)
  if ($left(%o,1) === o) && (($left(%p,1) === o) || (%p === z)) { hadd jso $mid(%o,2) $+ :p %p }
  return %o
}

alias js_b_odefprop {
  var -n %args = %jsna
  var -n %o = $js_arg(%args,1)
  if ($left(%o,1) !=== o) { return $js_throw(TypeError,Object.defineProperty called on non-object) }
  noop $js_defprop(%o,$js_tokey($js_arg(%args,2)),$js_arg(%args,3))
  return %o
}

; define one property from a descriptor object
alias js_defprop {
  var -n %d = $3
  var -n %g = $js_get(%d,get)
  var -n %s = $js_get(%d,set)
  var -n %enum = $js_truthy($js_get(%d,enumerable))
  if (%g !=== u) || (%s !=== u) {
    noop $js_defacc($1,$2,$iif(%g === u,0,%g),$iif(%s === u,0,%s),%enum)
    return
  }
  var -n %v = $js_get(%d,value)
  if (%enum) { noop $js_put($1,$2,%v) }
  else { noop $js_defhidden($1,$2,%v) }
}

alias js_defprops {
  var -n %keys = $js_ownkeys($2)
  var -n %i = 1
  while (%i <= $numtok(%keys,32)) {
    noop $js_defprop($1,$gettok(%keys,%i,32),$js_get($2,$gettok(%keys,%i,32)))
    inc %i
  }
}

alias js_b_ofromentries {
  var -n %list = $js_iterlist($js_arg(%jsna,1))
  if (%jsc) { return u }
  var -n %o = $js_newobj
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    var -n %e = $gettok(%list,%i,32)
    noop $js_put(%o,$js_tokey($js_get(%e,0)),$js_get(%e,1))
    inc %i
  }
  return %o
}

alias js_b_ois {
  var -n %a = $js_arg(%jsna,1)
  var -n %b = $js_arg(%jsna,2)
  return $js_bool($iif(%a === %b,1,0))
}

alias js_b_ohasown {
  var -n %o = $js_arg(%jsna,1)
  var -n %k = $js_tokey($js_arg(%jsna,2))
  if ($left(%o,1) !=== o) { return f }
  return $js_bool($iif($js_getown(%o,%k) != $null,1,0))
}

alias js_b_ohasownproto {
  var -n %o = %jsnt
  var -n %k = $js_tokey($js_arg(%jsna,1))
  if ($left(%o,1) !=== o) { return f }
  return $js_bool($iif($js_getown(%o,%k) != $null,1,0))
}

alias js_b_otostring {
  var -n %o = %jsnt
  if (%o === u) { return s[object $+ $js_enc($chr(32)) $+ Undefined] }
  if (%o === z) { return s[object $+ $js_enc($chr(32)) $+ Null] }
  if ($js_isarr(%o)) { return s[object $+ $js_enc($chr(32)) $+ Array] }
  if ($js_iscallable(%o)) { return s[object $+ $js_enc($chr(32)) $+ Function] }
  return s[object $+ $js_enc($chr(32)) $+ Object]
}

alias js_b_ovalueof {
  var -n %o = %jsnt
  if ($left(%o,1) === o) && ($hget(jso,$mid(%o,2) $+ :prim)) { return $v1 }
  return %o
}

alias js_b_oisproto {
  var -n %p = %jsnt
  var -n %o = $js_arg(%jsna,1)
  if ($left(%o,1) !=== o) { return f }
  var -n %cur = $hget(jso,$mid(%o,2) $+ :p)
  while ($left(%cur,1) === o) {
    if (%cur === %p) { return t }
    var -n %cur = $hget(jso,$mid(%cur,2) $+ :p)
  }
  return f
}

; ---------------------------------------------------------------- Function --

alias js.b.function {
  noop $js_gctor(Function,1,js_b_function,FP)
  js.defs $hget(jsm,FP) call:1:js_b_fcall apply:2:js_b_fapply bind:1:js_b_fbind toString:0:js_b_ftostring
}

alias js_b_function { return $js_throw(EvalError,The Function constructor is not supported; use eval()) }

alias js_b_fcall {
  var -n %f = %jsnt
  var -n %args = %jsna
  return $js_call(%f,$js_arg(%args,1),$gettok(%args,2-,32))
}

alias js_b_fapply {
  var -n %f = %jsnt
  var -n %args = %jsna
  var -n %a = $js_arg(%args,2)
  var -n %list = $null
  if ($left(%a,1) === o) {
    var -n %list = $js_iterlist(%a)
    if (%jsc) { return u }
  }
  return $js_call(%f,$js_arg(%args,1),%list)
}

alias js_b_fbind {
  var -n %f = %jsnt
  var -n %args = %jsna
  var -n %b = $js_new($hget(jsm,FP),Function)
  var -n %id = $mid(%b,2)
  hadd jso %id $+ :bnd %f
  hadd jso %id $+ :bthis $js_arg(%args,1)
  hadd jso %id $+ :bargs $gettok(%args,2-,32)
  hadd jso %id $+ .name s $+ bound $+ $js_enc($chr(32)) $+ $mid($js_get(%f,name),2)
  return %b
}

alias js_b_ftostring {
  var -n %f = %jsnt
  var -n %name = $js_dec($mid($js_get(%f,name),2))
  if ($hget(jso,$mid(%f,2) $+ :cls)) { return $js_str(class %name $chr(123) $chr(91) $+ code $+ $chr(93) $chr(125)) }
  return $js_str(function %name $+ $chr(40) $+ $chr(41) $chr(123) $chr(91) $+ native code $+ $chr(93) $chr(125))
}

; ------------------------------------------------------------------- Array --

alias js.b.array {
  var -n %f = $js_gctor(Array,1,js_b_array,AP)
  js.defs %f isArray:1:js_b_aisarray from:1:js_b_afrom of:0:js_b_aof
  js.defs $hget(jsm,AP) push:1:js_b_apush pop:0:js_b_apop shift:0:js_b_ashift unshift:1:js_b_aunshift slice:2:js_b_aslice splice:2:js_b_asplice concat:1:js_b_aconcat join:1:js_b_ajoin reverse:0:js_b_areverse indexOf:1:js_b_aindexof lastIndexOf:1:js_b_alastindexof includes:1:js_b_aincludes find:1:js_b_afind findIndex:1:js_b_afindindex findLast:1:js_b_afindlast findLastIndex:1:js_b_afindlastindex filter:1:js_b_afilter map:1:js_b_amap forEach:1:js_b_aforeach reduce:1:js_b_areduce reduceRight:1:js_b_areduceright some:1:js_b_asome every:1:js_b_aevery sort:1:js_b_asort flat:0:js_b_aflat flatMap:1:js_b_aflatmap fill:1:js_b_afill keys:0:js_b_akeys values:0:js_b_avalues entries:0:js_b_aentries at:1:js_b_aat toString:0:js_b_atostring toReversed:0:js_b_atoreversed toSorted:1:js_b_atosorted
}

alias js_b_array {
  var -n %args = %jsna
  var -n %a = %jsnt
  if (!%jsnew) || ($left(%a,1) !=== o) { var -n %a = $js_newarr($null) }
  hadd jso $mid(%a,2) $+ :c Array
  if ($numtok(%args,32) == 1) && ($left(%args,1) === n) {
    hadd jso $mid(%a,2) $+ :len $int($mid(%args,2))
    return %a
  }
  var -n %i = 1
  while (%i <= $numtok(%args,32)) {
    hadd jso $mid(%a,2) $+ . $+ $calc( %i - 1 ) $gettok(%args,%i,32)
    inc %i
  }
  hadd jso $mid(%a,2) $+ :len $numtok(%args,32)
  return %a
}

alias js_b_aisarray { return $js_bool($js_isarr($js_arg(%jsna,1))) }

alias js_b_afrom {
  var -n %args = %jsna
  var -n %src = $js_arg(%args,1)
  var -n %fn = $js_arg(%args,2)
  var -n %list = $null
  if ($left(%src,1) === o) && (!$js_isarr(%src)) && ($hget(jso,$mid(%src,2) $+ :c) !=== Map) && ($hget(jso,$mid(%src,2) $+ :c) !=== Set) && ($js_get(%src,length) !=== u) && (!$js_iscallable($js_get(%src,next))) {
    ; array-like {length: n}
    var -n %n = $int($js_tonum($js_get(%src,length)))
    var -n %i = 0
    while (%i < %n) {
      var -n %list = %list $js_get(%src,%i)
      inc %i
    }
  }
  elseif (%src !=== u) && (%src !=== z) {
    var -n %list = $js_iterlist(%src)
    if (%jsc) { return u }
  }
  if ($js_iscallable(%fn)) {
    var -n %out = $null
    var -n %i = 1
    while (%i <= $numtok(%list,32)) {
      var -n %out = %out $js_call(%fn,u,$gettok(%list,%i,32) n $+ $calc( %i - 1 ))
      if (%jsc) { return u }
      inc %i
    }
    var -n %list = %out
  }
  return $js_newarr(%list)
}

alias js_b_aof { return $js_newarr(%jsna) }

; this as an array id, or throw
alias js_athis {
  if (!$js_isarr($1)) {
    noop $js_throw(TypeError,Array method called on a non-array)
    return $null
  }
  return $mid($1,2)
}

alias js_b_apush {
  var -n %id = $js_athis(%jsnt)
  var -n %args = %jsna
  if (!%id) { return u }
  var -n %len = $hget(jso,%id $+ :len)
  var -n %i = 1
  while (%i <= $numtok(%args,32)) {
    hadd jso %id $+ . $+ %len $gettok(%args,%i,32)
    inc %len
    inc %i
  }
  hadd jso %id $+ :len %len
  return n $+ %len
}

alias js_b_apop {
  var -n %id = $js_athis(%jsnt)
  if (!%id) { return u }
  var -n %len = $hget(jso,%id $+ :len)
  if (%len == 0) { return u }
  dec %len
  var -n %v = $hget(jso,%id $+ . $+ %len)
  hdel jso %id $+ . $+ %len
  hadd jso %id $+ :len %len
  return $iif(%v == $null,u,%v)
}

alias js_b_ashift {
  var -n %a = %jsnt
  var -n %id = $js_athis(%a)
  if (!%id) { return u }
  var -n %list = $js_arrlist(%a)
  if (%list == $null) { return u }
  noop $js_setarr(%id,$gettok(%list,2-,32))
  return $gettok(%list,1,32)
}

alias js_b_aunshift {
  var -n %a = %jsnt
  var -n %args = %jsna
  var -n %id = $js_athis(%a)
  if (!%id) { return u }
  noop $js_setarr(%id,%args $js_arrlist(%a))
  return n $+ $hget(jso,%id $+ :len)
}

; replace an array's contents with a token list
alias js_setarr {
  var -n %id = $1
  var -n %old = $hget(jso,%id $+ :len)
  var -n %n = $numtok($2,32)
  var -n %i = 1
  while (%i <= %n) {
    hadd jso %id $+ . $+ $calc( %i - 1 ) $gettok($2,%i,32)
    inc %i
  }
  var -n %i = %n
  while (%i < %old) {
    hdel jso %id $+ . $+ %i
    inc %i
  }
  hadd jso %id $+ :len %n
}

alias js_b_aslice {
  var -n %a = %jsnt
  var -n %args = %jsna
  if ($left(%a,1) === s) { return $js_b_sslice_do(%a,%args) }
  if (!$js_athis(%a)) { return u }
  var -n %list = $js_arrlist(%a)
  var -n %len = $numtok(%list,32)
  var -n %s = $js_relidx($js_argint(%args,1,0),%len)
  var -n %e = $js_relidx($js_argint(%args,2,%len),%len)
  if (%e <= %s) { return $js_newarr($null) }
  return $js_newarr($gettok(%list,$calc( %s + 1 ) $+ - $+ %e,32))
}

alias js_b_asplice {
  var -n %a = %jsnt
  var -n %args = %jsna
  var -n %id = $js_athis(%a)
  if (!%id) { return u }
  var -n %list = $js_arrlist(%a)
  var -n %len = $numtok(%list,32)
  var -n %s = $js_relidx($js_argint(%args,1,0),%len)
  var -n %dc = $iif($numtok(%args,32) < 2,$calc( %len - %s ),$js_argint(%args,2,0))
  if (%dc < 0) { var -n %dc = 0 }
  if ($calc( %s + %dc ) > %len) { var -n %dc = $calc( %len - %s ) }
  var -n %removed = $iif(%dc > 0,$gettok(%list,$calc( %s + 1 ) $+ - $+ $calc( %s + %dc ),32),$null)
  var -n %before = $iif(%s > 0,$gettok(%list,1- $+ %s,32),$null)
  var -n %after = $iif($calc( %s + %dc ) < %len,$gettok(%list,$calc( %s + %dc + 1 ) $+ -,32),$null)
  noop $js_setarr(%id,%before $gettok(%args,3-,32) %after)
  return $js_newarr(%removed)
}

alias js_b_aconcat {
  var -n %a = %jsnt
  var -n %args = %jsna
  var -n %out = $js_arrlist(%a)
  var -n %i = 1
  while (%i <= $numtok(%args,32)) {
    var -n %x = $gettok(%args,%i,32)
    if ($js_isarr(%x)) { var -n %out = %out $js_arrlist(%x) }
    else { var -n %out = %out %x }
    inc %i
  }
  return $js_newarr(%out)
}

alias js_b_ajoin {
  var -n %a = %jsnt
  var -n %sep = $js_arg(%jsna,1)
  var -n %s = $iif(%sep === u,$chr(44),$js_tostr(%sep))
  if (!$js_isarr(%a)) { return s $+ $js_joinlist($js_arrlist(%a),%s) }
  ; read by index rather than through a token list
  var -n %id = $mid(%a,2)
  var -n %n = $hget(jso,%id $+ :len)
  var -n %out = $null
  var -n %i = 0
  while (%i < %n) {
    if (%i > 0) { var -n %out = %out $+ %s }
    var -n %v = $hget(jso,%id $+ . $+ %i)
    if (%v != $null) && (%v !=== u) && (%v !=== z) {
      var -n %out = %out $+ $js_tostr(%v)
      if (%jsc) { return u }
    }
    inc %i
  }
  return s $+ %out
}

; join value tokens with an encoded separator (null/undefined -> empty)
alias js_joinlist {
  var -n %out = $null
  var -n %n = $numtok($1,32)
  var -n %i = 1
  while (%i <= %n) {
    var -n %v = $gettok($1,%i,32)
    if (%i > 1) { var -n %out = %out $+ $2 }
    if (%v !=== u) && (%v !=== z) {
      var -n %out = %out $+ $js_tostr(%v)
      if (%jsc) { return $null }
    }
    inc %i
  }
  return %out
}

alias js_b_atostring {
  var -n %a = %jsnt
  if (!$js_isarr(%a)) { return $js_b_otostring }
  return s $+ $js_joinlist($js_arrlist(%a),$chr(44))
}

alias js_b_areverse {
  var -n %a = %jsnt
  var -n %id = $js_athis(%a)
  if (!%id) { return u }
  var -n %list = $js_arrlist(%a)
  var -n %out = $null
  var -n %i = $numtok(%list,32)
  while (%i >= 1) {
    var -n %out = %out $gettok(%list,%i,32)
    dec %i
  }
  noop $js_setarr(%id,%out)
  return %a
}

alias js_b_atoreversed {
  var -n %list = $js_arrlist(%jsnt)
  var -n %out = $null
  var -n %i = $numtok(%list,32)
  while (%i >= 1) {
    var -n %out = %out $gettok(%list,%i,32)
    dec %i
  }
  return $js_newarr(%out)
}

alias js_b_aindexof {
  var -n %a = %jsnt
  var -n %args = %jsna
  if ($left(%a,1) === s) { return $js_b_sindexof_do(%a,%args) }
  var -n %x = $js_arg(%args,1)
  var -n %list = $js_arrlist(%a)
  var -n %i = $calc( $js_relidx($js_argint(%args,2,0),$numtok(%list,32)) + 1 )
  while (%i <= $numtok(%list,32)) {
    if ($js_seq($gettok(%list,%i,32),%x)) { return n $+ $calc( %i - 1 ) }
    inc %i
  }
  return n-1
}

alias js_b_alastindexof {
  var -n %x = $js_arg(%jsna,1)
  var -n %list = $js_arrlist(%jsnt)
  var -n %i = $numtok(%list,32)
  while (%i >= 1) {
    if ($js_seq($gettok(%list,%i,32),%x)) { return n $+ $calc( %i - 1 ) }
    dec %i
  }
  return n-1
}

alias js_b_aincludes {
  var -n %a = %jsnt
  var -n %args = %jsna
  if ($left(%a,1) === s) { return $js_b_sincludes_do(%a,%args) }
  var -n %x = $js_arg(%args,1)
  var -n %list = $js_arrlist(%a)
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    var -n %v = $gettok(%list,%i,32)
    if ($js_seq(%v,%x)) || ((%v === nNaN) && (%x === nNaN)) { return t }
    inc %i
  }
  return f
}

; the callback-based methods share one loop: $js_aiter(mode,array,args).
; Elements are read by index (holes are undefined), so long arrays stay linear.
alias js_aiter {
  var -n %mode = $1
  var -n %a = $2
  var -n %args = $3
  var -n %fn = $js_arg(%args,1)
  var -n %this = $js_arg(%args,2)
  if (!$js_iscallable(%fn)) { return $js_throw(TypeError,$js_desc(%fn) is not a function) }
  if (!$js_isarr(%a)) { var -n %a = $js_newarr($js_iterlist(%a)) }
  if (%jsc) { return u }
  var -n %id = $mid(%a,2)
  var -n %n = $hget(jso,%id $+ :len)
  var -n %out = $null
  var -n %step = 1
  var -n %i = 0
  if (%mode === findlast) || (%mode === findlastidx) {
    var -n %step = -1
    var -n %i = $calc( %n - 1 )
  }
  while (%i >= 0) && (%i < %n) {
    var -n %v = $hget(jso,%id $+ . $+ %i)
    if (%v == $null) { var -n %v = u }
    var -n %r = $js_call(%fn,%this,%v n $+ %i %a)
    if (%jsc) { return u }
    if (%mode === map) { var -n %out = %out %r }
    elseif (%mode === filter) { if ($js_truthy(%r)) { var -n %out = %out %v } }
    elseif (%mode === find) || (%mode === findlast) { if ($js_truthy(%r)) { return %v } }
    elseif (%mode === findidx) || (%mode === findlastidx) { if ($js_truthy(%r)) { return n $+ %i } }
    elseif (%mode === some) { if ($js_truthy(%r)) { return t } }
    elseif (%mode === every) { if (!$js_truthy(%r)) { return f } }
    elseif (%mode === flatmap) {
      if ($js_isarr(%r)) { var -n %out = %out $js_arrlist(%r) }
      else { var -n %out = %out %r }
    }
    inc %i %step
  }
  if (%mode === map) || (%mode === filter) || (%mode === flatmap) { return $js_newarr(%out) }
  if (%mode === find) || (%mode === findlast) { return u }
  if (%mode === findidx) || (%mode === findlastidx) { return n-1 }
  if (%mode === some) { return f }
  if (%mode === every) { return t }
  return u
}

alias js_b_amap { return $js_aiter(map,%jsnt,%jsna) }
alias js_b_afilter { return $js_aiter(filter,%jsnt,%jsna) }
alias js_b_aforeach { return $js_aiter(each,%jsnt,%jsna) }
alias js_b_afind { return $js_aiter(find,%jsnt,%jsna) }
alias js_b_afindindex { return $js_aiter(findidx,%jsnt,%jsna) }
alias js_b_afindlast { return $js_aiter(findlast,%jsnt,%jsna) }
alias js_b_afindlastindex { return $js_aiter(findlastidx,%jsnt,%jsna) }
alias js_b_asome { return $js_aiter(some,%jsnt,%jsna) }
alias js_b_aevery { return $js_aiter(every,%jsnt,%jsna) }
alias js_b_aflatmap { return $js_aiter(flatmap,%jsnt,%jsna) }

alias js_b_areduce { return $js_areduce(%jsnt,%jsna,0) }
alias js_b_areduceright { return $js_areduce(%jsnt,%jsna,1) }

alias js_areduce {
  var -n %a = $1
  var -n %args = $2
  var -n %fn = $js_arg(%args,1)
  if (!$js_iscallable(%fn)) { return $js_throw(TypeError,$js_desc(%fn) is not a function) }
  if (!$js_isarr(%a)) { var -n %a = $js_newarr($js_iterlist(%a)) }
  var -n %id = $mid(%a,2)
  var -n %n = $hget(jso,%id $+ :len)
  var -n %step = $iif($3,-1,1)
  var -n %i = $iif($3,$calc( %n - 1 ),0)
  if ($numtok(%args,32) >= 2) { var -n %acc = $gettok(%args,2,32) }
  else {
    if (%n == 0) { return $js_throw(TypeError,Reduce of empty array with no initial value) }
    var -n %acc = $hget(jso,%id $+ . $+ %i)
    if (%acc == $null) { var -n %acc = u }
    inc %i %step
  }
  while (%i >= 0) && (%i < %n) {
    var -n %v = $hget(jso,%id $+ . $+ %i)
    if (%v == $null) { var -n %v = u }
    var -n %acc = $js_call(%fn,u,%acc %v n $+ %i %a)
    if (%jsc) { return u }
    inc %i %step
  }
  return %acc
}

alias js_b_asort {
  var -n %a = %jsnt
  var -n %id = $js_athis(%a)
  if (!%id) { return u }
  var -n %sorted = $js_sortlist($js_arrlist(%a),$js_arg(%jsna,1))
  if (%jsc) { return u }
  noop $js_setarr(%id,%sorted)
  return %a
}

alias js_b_atosorted {
  var -n %sorted = $js_sortlist($js_arrlist(%jsnt),$js_arg(%jsna,1))
  if (%jsc) { return u }
  return $js_newarr(%sorted)
}

; stable merge sort of a token list with an optional comparator
alias js_sortlist {
  var -n %list = $1
  var -n %n = $numtok(%list,32)
  if (%n <= 1) { return %list }
  ; undefined sorts last and is never compared
  var -n %undef = $null
  var -n %vals = $null
  var -n %i = 1
  while (%i <= %n) {
    if ($gettok(%list,%i,32) === u) { var -n %undef = %undef u }
    else { var -n %vals = %vals $gettok(%list,%i,32) }
    inc %i
  }
  var -n %width = 1
  var -n %n = $numtok(%vals,32)
  while (%width < %n) {
    var -n %out = $null
    var -n %lo = 1
    while (%lo <= %n) {
      var -n %mid = $calc( %lo + %width )
      var -n %hi = $calc( %lo + 2 * %width )
      var -n %i = %lo
      var -n %j = %mid
      while (%i < %mid) && (%i <= %n) && (%j < %hi) && (%j <= %n) {
        var -n %x = $gettok(%vals,%i,32)
        var -n %y = $gettok(%vals,%j,32)
        var -n %c = $js_sortcmp(%x,%y,$2)
        if (%jsc) { return %list }
        if (%c > 0) { var -n %out = %out %y | inc %j }
        else { var -n %out = %out %x | inc %i }
      }
      while (%i < %mid) && (%i <= %n) { var -n %out = %out $gettok(%vals,%i,32) | inc %i }
      while (%j < %hi) && (%j <= %n) { var -n %out = %out $gettok(%vals,%j,32) | inc %j }
      var -n %lo = %hi
    }
    var -n %vals = %out
    var -n %width = $calc( %width * 2 )
  }
  return %vals %undef
}

; compare two values for sort -> negative, 0 or positive
alias js_sortcmp {
  if ($js_iscallable($3)) {
    var -n %r = $js_call($3,u,$1 $2)
    if (%jsc) { return 0 }
    var -n %x = $js_tonum(%r)
    if (%x === NaN) { return 0 }
    if (%x === Inf) { return 1 }
    if (%x === -Inf) { return -1 }
    return %x
  }
  var -n %a = $js_dec($js_tostr($1))
  var -n %b = $js_dec($js_tostr($2))
  if (%a === %b) { return 0 }
  return $iif($js_strlt(%a,%b),-1,1)
}

alias js_b_aflat {
  var -n %depth = $js_argint(%jsna,1,1)
  return $js_newarr($js_flatlist($js_arrlist(%jsnt),%depth))
}

alias js_flatlist {
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok($1,32)) {
    var -n %v = $gettok($1,%i,32)
    if ($js_isarr(%v)) && ($2 > 0) { var -n %out = %out $js_flatlist($js_arrlist(%v),$calc( $2 - 1 )) }
    else { var -n %out = %out %v }
    inc %i
  }
  return %out
}

alias js_b_afill {
  var -n %a = %jsnt
  var -n %args = %jsna
  var -n %id = $js_athis(%a)
  if (!%id) { return u }
  var -n %len = $hget(jso,%id $+ :len)
  var -n %v = $js_arg(%args,1)
  var -n %s = $js_relidx($js_argint(%args,2,0),%len)
  var -n %e = $js_relidx($js_argint(%args,3,%len),%len)
  while (%s < %e) {
    hadd jso %id $+ . $+ %s %v
    inc %s
  }
  return %a
}

alias js_b_akeys {
  var -n %n = $hget(jso,$mid(%jsnt,2) $+ :len)
  var -n %out = $null
  var -n %i = 0
  while (%i < %n) {
    var -n %out = %out n $+ %i
    inc %i
  }
  return $js_newarr(%out)
}

alias js_b_avalues { return $js_newarr($js_arrlist(%jsnt)) }

alias js_b_aentries {
  var -n %list = $js_arrlist(%jsnt)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    var -n %out = %out $js_newarr(n $+ $calc( %i - 1 ) $gettok(%list,%i,32))
    inc %i
  }
  return $js_newarr(%out)
}

alias js_b_aat {
  var -n %a = %jsnt
  var -n %args = %jsna
  if ($left(%a,1) === s) {
    var -n %t = $js_dec($mid(%a,2))
    var -n %i = $js_argint(%args,1,0)
    if (%i < 0) { var -n %i = $calc( $len(%t) + %i ) }
    if (%i < 0) || (%i >= $len(%t)) { return u }
    return s $+ $js_enc($mid(%t,$calc( %i + 1 ),1))
  }
  var -n %len = $hget(jso,$mid(%a,2) $+ :len)
  var -n %i = $js_argint(%args,1,0)
  if (%i < 0) { var -n %i = $calc( %len + %i ) }
  if (%i < 0) || (%i >= %len) { return u }
  return $js_get(%a,%i)
}

; ------------------------------------------------------------------ String --

alias js.b.string {
  var -n %f = $js_gctor(String,1,js_b_string,SP)
  js.defs %f fromCharCode:1:js_b_sfromcharcode fromCodePoint:1:js_b_sfromcharcode raw:1:js_b_sraw
  js.defs $hget(jsm,SP) charAt:1:js_b_scharat charCodeAt:1:js_b_scharcodeat codePointAt:1:js_b_scharcodeat indexOf:1:js_b_sindexof lastIndexOf:1:js_b_slastindexof includes:1:js_b_sincludes startsWith:1:js_b_sstartswith endsWith:1:js_b_sendswith slice:2:js_b_sslice substring:2:js_b_ssubstring substr:2:js_b_ssubstr toUpperCase:0:js_b_supper toLowerCase:0:js_b_slower toLocaleUpperCase:0:js_b_supper toLocaleLowerCase:0:js_b_slower trim:0:js_b_strim trimStart:0:js_b_strimstart trimEnd:0:js_b_strimend split:2:js_b_ssplit replace:2:js_b_sreplace replaceAll:2:js_b_sreplaceall repeat:1:js_b_srepeat padStart:2:js_b_spadstart padEnd:2:js_b_spadend at:1:js_b_aat concat:1:js_b_sconcat match:1:js_b_smatch matchAll:1:js_b_smatchall search:1:js_b_ssearch toString:0:js_b_stostring valueOf:0:js_b_stostring localeCompare:1:js_b_slocalecompare normalize:0:js_b_stostring
}

alias js_b_string {
  var -n %args = %jsna
  var -n %v = $iif($numtok(%args,32) == 0,s,s $+ $js_tostr($gettok(%args,1,32)))
  if (%jsc) { return u }
  if (%jsnew) { hadd jso $mid(%jsnt,2) $+ :prim %v | return %jsnt }
  return %v
}

; this as text (decoded)
alias js_sthis {
  var -n %v = $1
  if ($left(%v,1) === s) { return $js_dec($mid(%v,2)) }
  if (%v === u) || (%v === z) {
    noop $js_throw(TypeError,String.prototype method called on null or undefined)
    return $null
  }
  return $js_dec($js_tostr(%v))
}

alias js_argtext { return $js_dec($js_tostr($js_arg($1,$2))) }

alias js_b_stostring {
  var -n %v = %jsnt
  if ($left(%v,1) === o) && ($hget(jso,$mid(%v,2) $+ :prim)) { return $v1 }
  return %v
}

alias js_b_sfromcharcode {
  var -n %args = %jsna
  var -n %s = $null
  var -n %i = 1
  while (%i <= $numtok(%args,32)) {
    var -n %s = %s $+ $js_encch($int($js_tonum($gettok(%args,%i,32))))
    inc %i
  }
  return s $+ %s
}

alias js_b_sraw {
  var -n %args = %jsna
  var -n %strs = $js_get($js_arg(%args,1),raw)
  var -n %list = $js_arrlist(%strs)
  var -n %s = $null
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    var -n %s = %s $+ $mid($gettok(%list,%i,32),2)
    if (%i < $numtok(%list,32)) && ($gettok(%args,$calc( %i + 1 ),32) != $null) { var -n %s = %s $+ $js_tostr($gettok(%args,$calc( %i + 1 ),32)) }
    inc %i
  }
  return s $+ %s
}

alias js_b_scharat {
  var -n %t = $js_sthis(%jsnt)
  var -n %i = $js_argint(%jsna,1,0)
  if (%i < 0) || (%i >= $len(%t)) { return s }
  return s $+ $js_enc($mid(%t,$calc( %i + 1 ),1))
}

alias js_b_scharcodeat {
  var -n %t = $js_sthis(%jsnt)
  var -n %i = $js_argint(%jsna,1,0)
  if (%i < 0) || (%i >= $len(%t)) { return nNaN }
  return n $+ $asc($mid(%t,$calc( %i + 1 ),1))
}

alias js_b_sindexof { return $js_b_sindexof_do(%jsnt,%jsna) }
alias js_b_sindexof_do {
  var -n %t = $js_sthis($1)
  var -n %x = $js_argtext($2,1)
  var -n %from = $js_argint($2,2,0)
  if (%from < 0) { var -n %from = 0 }
  if (%x == $null) { return n $+ $iif(%from > $len(%t),$len(%t),%from) }
  var -n %p = $poscs($mid(%t,$calc( %from + 1 )),%x,1)
  if (!%p) { return n-1 }
  return n $+ $calc( %p - 1 + %from )
}

alias js_b_slastindexof {
  var -n %t = $js_sthis(%jsnt)
  var -n %x = $js_argtext(%jsna,1)
  if (%x == $null) { return n $+ $len(%t) }
  var -n %c = $poscs(%t,%x,0)
  if (!%c) { return n-1 }
  return n $+ $calc( $poscs(%t,%x,%c) - 1 )
}

alias js_b_sincludes { return $js_b_sincludes_do(%jsnt,%jsna) }
alias js_b_sincludes_do {
  var -n %t = $js_sthis($1)
  var -n %x = $js_argtext($2,1)
  if (%x == $null) { return t }
  return $js_bool($iif($poscs(%t,%x,1),1,0))
}

alias js_b_sstartswith {
  var -n %t = $js_sthis(%jsnt)
  var -n %x = $js_argtext(%jsna,1)
  var -n %from = $js_argint(%jsna,2,0)
  return $js_bool($iif($mid(%t,$calc( %from + 1 ),$len(%x)) === %x,1,0))
}

alias js_b_sendswith {
  var -n %t = $js_sthis(%jsnt)
  var -n %x = $js_argtext(%jsna,1)
  if (%x == $null) { return t }
  return $js_bool($iif($right(%t,$len(%x)) === %x,1,0))
}

alias js_b_sslice { return $js_b_sslice_do(%jsnt,%jsna) }
alias js_b_sslice_do {
  var -n %t = $js_sthis($1)
  var -n %len = $len(%t)
  var -n %s = $js_relidx($js_argint($2,1,0),%len)
  var -n %e = $js_relidx($js_argint($2,2,%len),%len)
  if (%e <= %s) { return s }
  return s $+ $js_enc($mid(%t,$calc( %s + 1 ),$calc( %e - %s )))
}

alias js_b_ssubstring {
  var -n %t = $js_sthis(%jsnt)
  var -n %len = $len(%t)
  var -n %s = $js_argint(%jsna,1,0)
  var -n %e = $js_argint(%jsna,2,%len)
  if (%s < 0) { var -n %s = 0 }
  if (%e < 0) { var -n %e = 0 }
  if (%s > %len) { var -n %s = %len }
  if (%e > %len) { var -n %e = %len }
  if (%s > %e) { var %tmp = %s | var -n %s = %e | var -n %e = %tmp }
  if (%e == %s) { return s }
  return s $+ $js_enc($mid(%t,$calc( %s + 1 ),$calc( %e - %s )))
}

alias js_b_ssubstr {
  var -n %t = $js_sthis(%jsnt)
  var -n %len = $len(%t)
  var -n %s = $js_relidx($js_argint(%jsna,1,0),%len)
  var -n %n = $js_argint(%jsna,2,%len)
  if (%n <= 0) { return s }
  return s $+ $js_enc($mid(%t,$calc( %s + 1 ),%n))
}

alias js_b_supper { return s $+ $js_enc($upper($js_sthis(%jsnt))) }
alias js_b_slower { return s $+ $js_enc($lower($js_sthis(%jsnt))) }
alias js_b_strim { return s $+ $js_enc($regsubex($js_sthis(%jsnt),/^\s+|\s+$/g,)) }
alias js_b_strimstart { return s $+ $js_enc($regsubex($js_sthis(%jsnt),/^\s+/,)) }
alias js_b_strimend { return s $+ $js_enc($regsubex($js_sthis(%jsnt),/\s+$/,)) }

alias js_b_sconcat {
  var -n %s = $js_enc($js_sthis(%jsnt))
  var -n %args = %jsna
  var -n %i = 1
  while (%i <= $numtok(%args,32)) {
    var -n %s = %s $+ $js_tostr($gettok(%args,%i,32))
    inc %i
  }
  return s $+ %s
}

alias js_b_srepeat {
  var -n %t = $js_enc($js_sthis(%jsnt))
  var -n %n = $js_argint(%jsna,1,0)
  if (%n < 0) { return $js_throw(RangeError,Invalid count value: %n) }
  var -n %s = $null
  while (%n > 0) {
    var -n %s = %s $+ %t
    dec %n
  }
  return s $+ %s
}

alias js_b_spadstart { return $js_pad(%jsnt,%jsna,start) }
alias js_b_spadend { return $js_pad(%jsnt,%jsna,end) }

alias js_pad {
  var -n %t = $js_sthis($1)
  var -n %n = $js_argint($2,1,0)
  var -n %f = $iif($js_arg($2,2) === u,$chr(32),$js_argtext($2,2))
  if (%n <= $len(%t)) || (%f == $null) { return s $+ $js_enc(%t) }
  var -n %need = $calc( %n - $len(%t) )
  var -n %p = $null
  while ($len(%p) < %need) { var -n %p = %p $+ %f }
  var -n %p = $js_enc($left(%p,%need))
  if ($3 === start) { return s $+ %p $+ $js_enc(%t) }
  return s $+ $js_enc(%t) $+ %p
}

alias js_b_slocalecompare {
  var -n %a = $js_sthis(%jsnt)
  var -n %b = $js_argtext(%jsna,1)
  if (%a === %b) { return n0 }
  return $iif($js_strlt(%a,%b),n-1,n1)
}

alias js_b_ssplit {
  var -n %t = $js_sthis(%jsnt)
  var -n %args = %jsna
  var -n %sep = $js_arg(%args,1)
  var -n %lim = $js_argint(%args,2,999999999)
  if (%sep === u) { return $js_newarr(s $+ $js_enc(%t)) }
  if ($js_isregexp(%sep)) { return $js_resplit(%sep,%t,%lim) }
  var -n %s = $js_dec($js_tostr(%sep))
  var -n %out = $null
  if (%s == $null) {
    var -n %i = 1
    while (%i <= $len(%t)) && (%i <= %lim) {
      var -n %out = %out s $+ $js_enc($mid(%t,%i,1))
      inc %i
    }
    return $js_newarr(%out)
  }
  var -n %rest = %t
  var -n %count = 0
  while (%count < %lim) {
    var -n %p = $poscs(%rest,%s,1)
    if (!%p) { var -n %out = %out s $+ $js_enc(%rest) | break }
    var -n %out = %out s $+ $js_enc($left(%rest,$calc( %p - 1 )))
    var -n %rest = $mid(%rest,$calc( %p + $len(%s) ))
    inc %count
    if (%count >= %lim) { break }
  }
  return $js_newarr($gettok(%out,1- $+ %lim,32))
}

alias js_b_sreplace { return $js_sreplace(%jsnt,%jsna,0) }
alias js_b_sreplaceall { return $js_sreplace(%jsnt,%jsna,1) }

; replace / replaceAll with a string pattern (regexes go to $js_rereplace)
alias js_sreplace {
  var -n %t = $js_sthis($1)
  var -n %pat = $js_arg($2,1)
  var -n %rep = $js_arg($2,2)
  if ($js_isregexp(%pat)) { return $js_rereplace(%pat,%t,%rep,$3) }
  var -n %p = $js_dec($js_tostr(%pat))
  var -n %out = $null
  var -n %rest = %t
  var -n %pos = 0
  while (1) {
    var -n %i = $poscs(%rest,%p,1)
    if (!%i) || ((%p == $null) && (%pos > 0) && (!$3)) { break }
    var -n %matchpos = $calc( %pos + %i - 1 )
    var -n %out = %out $+ $js_enc($left(%rest,$calc( %i - 1 )))
    if ($js_iscallable(%rep)) {
      var -n %r = $js_call(%rep,u,s $+ $js_enc(%p) n $+ %matchpos s $+ $js_enc(%t))
      if (%jsc) { return u }
      var -n %out = %out $+ $js_tostr(%r)
    }
    else { var -n %out = %out $+ $js_enc($js_expandrep($js_dec($js_tostr(%rep)),%p,$null,%matchpos,%t)) }
    var -n %rest = $mid(%rest,$calc( %i + $len(%p) ))
    var -n %pos = $calc( %matchpos + $len(%p) )
    if (!$3) { break }
    if (%p == $null) {
      if (%rest == $null) { break }
      var -n %out = %out $+ $js_enc($left(%rest,1))
      var -n %rest = $mid(%rest,2)
      inc %pos
    }
  }
  return s $+ %out $+ $js_enc(%rest)
}

; expand $& $1 $` $' $$ in a replacement: (template,match,groups list,pos,whole)
alias js_expandrep {
  var -n %r = $1
  if ($chr(36) !isin %r) { return %r }
  var -n %out = $null
  var -n %i = 1
  var -n %n = $len(%r)
  while (%i <= %n) {
    var -n %c = $mid(%r,%i,1)
    if (%c === $chr(36)) && (%i < %n) {
      var -n %d = $mid(%r,$calc( %i + 1 ),1)
      if (%d === $chr(36)) { var -n %out = %out $+ $chr(36) | inc %i 2 | continue }
      if (%d === &) { var -n %out = %out $+ $2 | inc %i 2 | continue }
      if (%d === `) { var -n %out = %out $+ $left($5,$4) | inc %i 2 | continue }
      if (%d === ') { var -n %out = %out $+ $mid($5,$calc( $4 + $len($2) + 1 )) | inc %i 2 | continue }
      if (%d isnum 0-9) {
        var -n %g = %d
        if ($mid(%r,$calc( %i + 2 ),1) isnum 0-9) && ($gettok($3,$calc( %d * 10 + $mid(%r,$calc( %i + 2 ),1) ),1) != $null) { var -n %g = $calc( %d * 10 + $mid(%r,$calc( %i + 2 ),1) ) | inc %i }
        if (%g > 0) {
          var -n %gv = $gettok($3,%g,2)
          var -n %out = %out $+ $js_dec($mid(%gv,2))
          inc %i 2
          continue
        }
      }
    }
    var -n %out = %out $+ %c
    inc %i
  }
  return %out
}

alias js_b_smatch {
  var -n %t = $js_sthis(%jsnt)
  var -n %re = $js_arg(%jsna,1)
  if (!$js_isregexp(%re)) { var -n %re = $js_newregexp($js_enc($js_reescape($js_dec($js_tostr(%re)))),$null) }
  if ($js_reflag(%re,g)) {
    var -n %all = $js_reall(%re,%t)
    if (%all == $null) { return z }
    var -n %out = $null
    var -n %i = 1
    while (%i <= $numtok(%all,32)) {
      var -n %out = %out $gettok($gettok(%all,%i,32),2,2)
      inc %i
    }
    return $js_newarr(%out)
  }
  return $js_reexec(%re,%t,0)
}

alias js_b_smatchall {
  var -n %t = $js_sthis(%jsnt)
  var -n %re = $js_arg(%jsna,1)
  if (!$js_isregexp(%re)) { var -n %re = $js_newregexp($js_enc($js_reescape($js_dec($js_tostr(%re)))),g) }
  var -n %all = $js_reall(%re,%t)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%all,32)) {
    var -n %out = %out $js_rematcharr($gettok(%all,%i,32),%t)
    inc %i
  }
  return $js_newarr(%out)
}

alias js_b_ssearch {
  var -n %t = $js_sthis(%jsnt)
  var -n %re = $js_arg(%jsna,1)
  if (!$js_isregexp(%re)) { var -n %re = $js_newregexp($js_enc($js_reescape($js_dec($js_tostr(%re)))),$null) }
  var -n %m = $js_refind(%re,%t,0)
  if (%m == $null) { return n-1 }
  return n $+ $gettok(%m,1,2)
}

; ------------------------------------------------------------------ Number --

alias js.b.number {
  var -n %f = $js_gctor(Number,1,js_b_number,NP)
  js.defs %f isInteger:1:js_b_nisinteger isFinite:1:js_b_nisfinite isNaN:1:js_b_nisnan isSafeInteger:1:js_b_nisinteger parseFloat:1:js_b_parsefloat parseInt:2:js_b_parseint
  noop $js_defhidden(%f,^M^A^X_^S^A^F^E_^I^N^T^E^G^E^R,n9007199254740991)
  noop $js_defhidden(%f,^M^I^N_^S^A^F^E_^I^N^T^E^G^E^R,n-9007199254740991)
  noop $js_defhidden(%f,^E^P^S^I^L^O^N,n0.000001)
  noop $js_defhidden(%f,^M^A^X_^V^A^L^U^E,n1.7976931348623157e308)
  noop $js_defhidden(%f,^M^I^N_^V^A^L^U^E,n0.000001)
  noop $js_defhidden(%f,^P^O^S^I^T^I^V^E_^I^N^F^I^N^I^T^Y,nInf)
  noop $js_defhidden(%f,^N^E^G^A^T^I^V^E_^I^N^F^I^N^I^T^Y,n-Inf)
  noop $js_defhidden(%f,^Na^N,nNaN)
  js.defs $hget(jsm,NP) toFixed:1:js_b_ntofixed toString:1:js_b_ntostring toPrecision:1:js_b_ntoprecision valueOf:0:js_b_nvalueof toLocaleString:0:js_b_ntolocale
}

alias js_b_number {
  var -n %args = %jsna
  var -n %v = $iif($numtok(%args,32) == 0,n0,n $+ $js_tonum($gettok(%args,1,32)))
  if (%jsc) { return u }
  var -n %v = $js_numtok($mid(%v,2))
  if (%jsnew) { hadd jso $mid(%jsnt,2) $+ :prim %v | return %jsnt }
  return %v
}

; this as a number text
alias js_nthis {
  var -n %v = $1
  if ($left(%v,1) === n) { return $mid(%v,2) }
  if ($left(%v,1) === o) && ($left($hget(jso,$mid(%v,2) $+ :prim),1) === n) { return $mid($hget(jso,$mid(%v,2) $+ :prim),2) }
  return $js_tonum(%v)
}

alias js_b_nvalueof { return n $+ $js_nthis(%jsnt) }

alias js_b_nisinteger {
  var -n %v = $js_arg(%jsna,1)
  if ($left(%v,1) !=== n) { return f }
  var -n %x = $mid(%v,2)
  if (!$js_isfin(%x)) { return f }
  return $js_bool($iif($int(%x) == %x,1,0))
}

alias js_b_nisfinite {
  var -n %v = $js_arg(%jsna,1)
  if ($left(%v,1) !=== n) { return f }
  return $js_bool($js_isfin($mid(%v,2)))
}

alias js_b_nisnan { return $js_bool($iif($js_arg(%jsna,1) === nNaN,1,0)) }

alias js_b_ntofixed {
  var -n %x = $js_nthis(%jsnt)
  var -n %d = $js_argint(%jsna,1,0)
  if (!$js_isfin(%x)) { return s $+ $js_numstr(%x) }
  if (%d < 0) || (%d > 100) { return $js_throw(RangeError,toFixed() digits argument must be between 0 and 100) }
  var -n %r = $round(%x,%d)
  if (%d > 0) {
    if (. !isin %r) { var -n %r = %r $+ . }
    var -n %have = $len($gettok(%r,2,46))
    while (%have < %d) { var -n %r = %r $+ 0 | inc %have }
  }
  return s $+ %r
}

alias js_b_ntoprecision {
  var -n %x = $js_nthis(%jsnt)
  var -n %p = $js_argint(%jsna,1,0)
  if (%p == 0) || (!$js_isfin(%x)) { return s $+ $js_numstr(%x) }
  if (%x == 0) { return $js_b_ntofixed_do(0,$calc( %p - 1 )) }
  var -n %mag = $floor($log10($abs(%x)))
  var -n %d = $calc( %p - 1 - %mag )
  if (%d < 0) { var -n %d = 0 }
  return $js_b_ntofixed_do(%x,%d)
}

alias js_b_ntofixed_do {
  %jsnt = n $+ $1
  %jsna = n $+ $2
  return $js_b_ntofixed
}

alias js_b_ntostring {
  var -n %x = $js_nthis(%jsnt)
  var -n %r = $js_argint(%jsna,1,10)
  if (%r == 10) || (!$js_isfin(%x)) { return s $+ $js_numstr(%x) }
  if (%r < 2) || (%r > 36) { return $js_throw(RangeError,toString() radix must be between 2 and 36) }
  var -n %neg = $iif(%x < 0,1,0)
  var -n %s = $lower($base($abs($int(%x)),10,%r))
  return s $+ $iif(%neg,-) $+ %s
}

alias js_b_ntolocale {
  var -n %x = $js_nthis(%jsnt)
  if (!$js_isfin(%x)) { return s $+ $js_numstr(%x) }
  var -n %r = $round(%x,3)
  var -n %int = $gettok(%r,1,46)
  var -n %frac = $gettok(%r,2,46)
  var -n %neg = $iif($left(%int,1) == -,1,0)
  if (%neg) { var -n %int = $mid(%int,2) }
  var -n %out = $null
  while ($len(%int) > 3) {
    var -n %out = $chr(44) $+ $right(%int,3) $+ %out
    var -n %int = $left(%int,-3)
  }
  return s $+ $iif(%neg,-) $+ %int $+ %out $+ $iif(%frac != $null,. $+ %frac)
}

; parseInt / parseFloat
alias js_b_parseint {
  var -n %args = %jsna
  var -n %s = $regsubex($js_argtext(%args,1),/^\s+/,)
  var -n %r = $js_argint(%args,2,0)
  var -n %neg = 0
  if ($left(%s,1) == -) { var -n %neg = 1 | var -n %s = $mid(%s,2) }
  elseif ($left(%s,1) == +) { var -n %s = $mid(%s,2) }
  if (%r == 0) || (%r == 16) {
    if ($regex(%s,/^0[xX]/)) { var -n %s = $mid(%s,3) | var -n %r = 16 }
  }
  if (%r == 0) { var -n %r = 10 }
  if (%r < 2) || (%r > 36) { return nNaN }
  var -n %digits = $left(0123456789abcdefghijklmnopqrstuvwxyz,%r)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $len(%s)) {
    if (!$pos(%digits,$mid(%s,%i,1),1)) { break }
    var -n %out = %out $+ $mid(%s,%i,1)
    inc %i
  }
  if (%out == $null) { return nNaN }
  var -n %v = $iif(%r == 10,$calc( %out ),$base(%out,%r,10))
  return $js_numtok($iif(%neg,- $+ %v,%v))
}

alias js_b_parsefloat {
  var -n %s = $regsubex($js_argtext(%jsna,1),/^\s+/,)
  if ($regex(%s,/^[+-]?Infinity/)) { return $iif($left(%s,1) == -,n-Inf,nInf) }
  if (!$regex(%s,/^([+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)/)) { return nNaN }
  return $js_numtok($js_parsedec($regml(1)))
}

; ----------------------------------------------------------------- Boolean --

alias js.b.boolean {
  noop $js_gctor(Boolean,1,js_b_boolean,BP)
  js.defs $hget(jsm,BP) toString:0:js_b_btostring valueOf:0:js_b_bvalueof
}

alias js_b_boolean {
  var -n %v = $js_bool($js_truthy($js_arg(%jsna,1)))
  if (%jsnew) { hadd jso $mid(%jsnt,2) $+ :prim %v | return %jsnt }
  return %v
}

alias js_b_btostring {
  var -n %v = %jsnt
  if ($left(%v,1) === o) { var -n %v = $hget(jso,$mid(%v,2) $+ :prim) }
  return s $+ $iif(%v === t,true,false)
}

alias js_b_bvalueof {
  var -n %v = %jsnt
  if ($left(%v,1) === o) { var -n %v = $hget(jso,$mid(%v,2) $+ :prim) }
  return %v
}

; ------------------------------------------------------------------ Errors --

alias js.b.errors {
  var -n %f = $js_gctor(Error,1,js_b_error,EP)
  var -n %ep = $hget(jsm,EP)
  noop $js_defhidden(%ep,name,sError)
  noop $js_defhidden(%ep,message,s)
  js.defs %ep toString:0:js_b_etostring
  var -n %names = TypeError RangeError SyntaxError ReferenceError EvalError URIError
  var -n %i = 1
  while (%i <= 6) {
    var -n %name = $gettok(%names,%i,32)
    var -n %p = $js_new(%ep,Error)
    hadd jsm $+(E_,%name) %p
    var -n %c = $js_mknat(%name,1,js_b_error,1)
    hadd jso $mid(%c,2) $+ :p %f
    noop $js_defhidden(%c,prototype,%p)
    noop $js_defhidden(%p,constructor,%c)
    noop $js_defhidden(%p,name,s $+ %name)
    noop $js_decl(1,$js_kenc(%name),%c)
    inc %i
  }
}

alias js_b_error {
  var -n %args = %jsna
  var -n %e = %jsnt
  if (!%jsnew) || ($left(%e,1) !=== o) { var -n %e = $js_new($js_get(%jsnf,prototype),Error) }
  hadd jso $mid(%e,2) $+ :c Error
  var -n %m = $js_arg(%args,1)
  if (%m !=== u) { hadd jso $mid(%e,2) $+ .message s $+ $js_tostr(%m) }
  var -n %opts = $js_arg(%args,2)
  if ($left(%opts,1) === o) && ($js_haskey(%opts,cause)) { noop $js_put(%e,cause,$js_get(%opts,cause)) }
  hadd jso $mid(%e,2) $+ :line $hget(jsm,line)
  var -n %name = $js_dec($js_tostr($js_get(%e,name)))
  noop $js_defhidden(%e,stack,s $+ $js_enc(%name $+ : $js_dec($js_tostr($js_get(%e,message))) $+ $chr(10) $+ $str($chr(32),4) $+ at line $hget(jsm,line)))
  return %e
}

alias js_b_etostring {
  var -n %e = %jsnt
  var -n %name = $js_tostr($js_get(%e,name))
  var -n %msg = $js_tostr($js_get(%e,message))
  if (%msg == $null) { return s $+ %name }
  if (%name == $null) { return s $+ %msg }
  return s $+ %name $+ $js_enc(: $+ $chr(32)) $+ %msg
}

; -------------------------------------------------------------------- Math --

alias js.b.math {
  var -n %m = $js_newobj
  noop $js_decl(1,^Math,%m)
  js.defs %m abs:1:js_b_mabs floor:1:js_b_mfloor ceil:1:js_b_mceil round:1:js_b_mround trunc:1:js_b_mtrunc sign:1:js_b_msign min:2:js_b_mmin max:2:js_b_mmax pow:2:js_b_mpow sqrt:1:js_b_msqrt cbrt:1:js_b_mcbrt random:0:js_b_mrandom sin:1:js_b_msin cos:1:js_b_mcos tan:1:js_b_mtan asin:1:js_b_masin acos:1:js_b_macos atan:1:js_b_matan atan2:2:js_b_matan2 log:1:js_b_mlog log2:1:js_b_mlog2 log10:1:js_b_mlog10 exp:1:js_b_mexp hypot:2:js_b_mhypot
  noop $js_defhidden(%m,^P^I,n3.141592653589793)
  noop $js_defhidden(%m,^E,n2.718281828459045)
  noop $js_defhidden(%m,^L^N2,n0.6931471805599453)
  noop $js_defhidden(%m,^L^N10,n2.302585092994046)
  noop $js_defhidden(%m,^S^Q^R^T2,n1.4142135623730951)
  noop $js_defhidden(%m,^L^O^G2^E,n1.4426950408889634)
  noop $js_defhidden(%m,^L^O^G10^E,n0.4342944819032518)
}

; first argument as a number text
alias js_m1 { return $js_tonum($js_arg($1,1)) }

alias js_b_mabs {
  var -n %x = $js_m1(%jsna)
  if (%x === -Inf) { return nInf }
  if (!$js_isfin(%x)) { return n $+ %x }
  return $js_numtok($abs(%x))
}

alias js_b_mfloor {
  var -n %x = $js_m1(%jsna)
  if (!$js_isfin(%x)) { return n $+ %x }
  return $js_numtok($floor(%x))
}

alias js_b_mceil {
  var -n %x = $js_m1(%jsna)
  if (!$js_isfin(%x)) { return n $+ %x }
  return $js_numtok($ceil(%x))
}

alias js_b_mround {
  var -n %x = $js_m1(%jsna)
  if (!$js_isfin(%x)) { return n $+ %x }
  return $js_numtok($floor($calc( %x + 0.5 )))
}

alias js_b_mtrunc {
  var -n %x = $js_m1(%jsna)
  if (!$js_isfin(%x)) { return n $+ %x }
  return $js_numtok($int(%x))
}

alias js_b_msign {
  var -n %x = $js_m1(%jsna)
  if (%x === NaN) { return nNaN }
  if (%x === Inf) || (%x > 0) { return n1 }
  if (%x === -Inf) || (%x < 0) { return n-1 }
  return n0
}

alias js_b_mmin { return $js_minmax(%jsna,min) }
alias js_b_mmax { return $js_minmax(%jsna,max) }

alias js_minmax {
  var -n %best = $iif($2 === min,Inf,-Inf)
  var -n %i = 1
  while (%i <= $numtok($1,32)) {
    var -n %x = $js_tonum($gettok($1,%i,32))
    if (%x === NaN) { return nNaN }
    if ($2 === min) && ($js_lt(n $+ %x,n $+ %best) == 1) { var -n %best = %x }
    if ($2 === max) && ($js_lt(n $+ %best,n $+ %x) == 1) { var -n %best = %x }
    inc %i
  }
  return n $+ %best
}

alias js_b_mpow { return $js_numtok($js_arith(exp,$js_m1(%jsna),$js_tonum($js_arg(%jsna,2)))) }

alias js_b_msqrt {
  var -n %x = $js_m1(%jsna)
  if (%x === NaN) || (%x < 0) || (%x === -Inf) { return nNaN }
  if (%x === Inf) { return nInf }
  return $js_numtok($sqrt(%x))
}

alias js_b_mcbrt {
  var -n %x = $js_m1(%jsna)
  if (!$js_isfin(%x)) { return n $+ %x }
  var -n %r = $calc( $abs(%x) ^ ( 1 / 3 ) )
  var -n %r = $round(%r,6)
  return $js_numtok($iif(%x < 0,- $+ %r,%r))
}

alias js_b_mrandom { return n $+ $calc( $rand(0,999999999) / 1000000000 ) }
alias js_b_msin { return $js_numtok($sin($js_m1(%jsna))) }
alias js_b_mcos { return $js_numtok($cos($js_m1(%jsna))) }
alias js_b_mtan { return $js_numtok($tan($js_m1(%jsna))) }
alias js_b_masin { return $js_numtok($asin($js_m1(%jsna))) }
alias js_b_macos { return $js_numtok($acos($js_m1(%jsna))) }
alias js_b_matan { return $js_numtok($atan($js_m1(%jsna))) }

alias js_b_matan2 {
  var -n %y = $js_m1(%jsna)
  var -n %x = $js_tonum($js_arg(%jsna,2))
  if (%x > 0) { return $js_numtok($atan($calc( %y / %x ))) }
  if (%x < 0) && (%y >= 0) { return $js_numtok($calc( $atan($calc( %y / %x )) + $pi )) }
  if (%x < 0) { return $js_numtok($calc( $atan($calc( %y / %x )) - $pi )) }
  if (%y > 0) { return $js_numtok($calc( $pi / 2 )) }
  if (%y < 0) { return $js_numtok($calc( 0 - $pi / 2 )) }
  return n0
}

alias js_b_mlog {
  var -n %x = $js_m1(%jsna)
  if (%x == 0) { return n-Inf }
  if (%x < 0) || (%x === NaN) { return nNaN }
  return $js_numtok($log(%x))
}

alias js_b_mlog2 {
  var -n %x = $js_m1(%jsna)
  if (%x == 0) { return n-Inf }
  if (%x < 0) { return nNaN }
  return $js_numtok($round($calc( $log(%x) / $log(2) ),6))
}

alias js_b_mlog10 {
  var -n %x = $js_m1(%jsna)
  if (%x == 0) { return n-Inf }
  if (%x < 0) { return nNaN }
  return $js_numtok($round($log10(%x),6))
}

alias js_b_mexp { return $js_numtok($calc( 2.718281828459045 ^ $js_m1(%jsna) )) }

alias js_b_mhypot {
  var -n %s = 0
  var -n %i = 1
  while (%i <= $numtok(%jsna,32)) {
    var -n %x = $js_tonum($gettok(%jsna,%i,32))
    var -n %s = $calc( %s + %x * %x )
    inc %i
  }
  return $js_numtok($sqrt(%s))
}

; -------------------------------------------------------------------- JSON --

alias js.b.json {
  var -n %j = $js_newobj
  noop $js_decl(1,^J^S^O^N,%j)
  js.defs %j stringify:3:js_b_jstringify parse:2:js_b_jparse
}

alias js_b_jstringify {
  var -n %args = %jsna
  var -n %v = $js_arg(%args,1)
  var -n %ind = $js_arg(%args,3)
  var -n %gap = $null
  if ($left(%ind,1) === n) { var -n %gap = $str($chr(32),$mid(%ind,2)) }
  elseif ($left(%ind,1) === s) { var -n %gap = $js_dec($mid(%ind,2)) }
  hadd jsm jsonseen $null
  var -n %r = $js_jsonstr(%v,$js_enc(%gap),$null)
  if (%jsc) { return u }
  if (%r === $chr(1) $+ u) { return u }
  return s $+ %r
}

; JSON text (encoded) for a value; $chr(1)u means "leave out"
alias js_jsonstr {
  var -n %v = $1
  var -n %gap = $2
  var -n %ind = $3
  var -n %ty = $left(%v,1)
  if (%ty === o) {
    var -n %tj = $js_get(%v,to^J^S^O^N)
    if ($js_iscallable(%tj)) {
      var -n %v = $js_call(%tj,%v,$null)
      if (%jsc) { return $null }
      var -n %ty = $left(%v,1)
    }
  }
  if (%ty === z) { return null }
  if (%ty === t) { return true }
  if (%ty === f) { return false }
  if (%ty === n) { return $iif($js_isfin($mid(%v,2)),$mid(%v,2),null) }
  if (%ty === s) { return $js_jsonquote($mid(%v,2)) }
  if (%ty === u) || ($js_iscallable(%v)) { return $chr(1) $+ u }
  if (%ty === o) {
    var -n %id = $mid(%v,2)
    if ($hget(jso,%id $+ :prim)) { return $js_jsonstr($v1,%gap,%ind) }
    if ($istok($hget(jsm,jsonseen),%id,32)) { noop $js_throw(TypeError,Converting circular structure to JSON) | return $null }
    hadd jsm jsonseen $hget(jsm,jsonseen) %id
    var -n %inner = %ind $+ %gap
    var -n %nl = $iif(%gap != $null,$js_enc($chr(10)) $+ %inner,$null)
    var -n %parts = $null
    var -n %count = 0
    if ($js_isarr(%v)) {
      var -n %list = $js_arrlist(%v)
      var -n %i = 1
      while (%i <= $numtok(%list,32)) {
        var -n %s = $js_jsonstr($gettok(%list,%i,32),%gap,%inner)
        if (%jsc) { return $null }
        if (%s === $chr(1) $+ u) { var -n %s = null }
        var -n %parts = %parts $+ $iif(%count,$chr(44)) $+ %nl $+ %s
        inc %count
        inc %i
      }
      hadd jsm jsonseen $remtok($hget(jsm,jsonseen),%id,1,32)
      if (!%count) { return [] }
      return $chr(91) $+ %parts $+ $iif(%gap != $null,$js_enc($chr(10)) $+ %ind) $+ $chr(93)
    }
    var -n %c = $hget(jso,%id $+ :c)
    if (%c === Map) || (%c === Set) { hadd jsm jsonseen $remtok($hget(jsm,jsonseen),%id,1,32) | return $+ $chr(123) $+ $chr(125) }
    var -n %keys = $js_ownkeys(%v)
    var -n %i = 1
    while (%i <= $numtok(%keys,32)) {
      var -n %k = $gettok(%keys,%i,32)
      var -n %s = $js_jsonstr($js_get(%v,%k),%gap,%inner)
      if (%jsc) { return $null }
      if (%s !=== $chr(1) $+ u) {
        var -n %parts = %parts $+ $iif(%count,$chr(44)) $+ %nl $+ $js_jsonquote($js_kdec(%k)) $+ : $+ $iif(%gap != $null,$js_enc($chr(32))) $+ %s
        inc %count
      }
      inc %i
    }
    hadd jsm jsonseen $remtok($hget(jsm,jsonseen),%id,1,32)
    if (!%count) { return $chr(123) $+ $chr(125) }
    return $chr(123) $+ %parts $+ $iif(%gap != $null,$js_enc($chr(10)) $+ %ind) $+ $chr(125)
  }
  return null
}

; quote an encoded string as JSON (result encoded)
alias js_jsonquote {
  var -n %t = $js_dec($1)
  var -n %t = $replacecs(%t,\,\\,$chr(34),\ $+ $chr(34),$chr(10),\n,$chr(13),\r,$chr(9),\t,$chr(8),\b,$chr(12),\f)
  var -n %t = $regsubex(%t,/([\x00-\x1F])/g,$+(\u,$base($asc(\1),10,16,4)))
  return " $+ $js_enc(%t) $+ "
}

alias js_b_jparse {
  var -n %args = %jsna
  var -n %text = $js_argtext(%args,1)
  if (!$js_lex(t,%text)) { return $js_throw(SyntaxError,Unexpected token in JSON) }
  set %jjp 1
  var -n %v = $js_jsonval
  if (%jsc) { return u }
  if ($hget(jst,%jjp $+ :t) !=== x) { return $js_throw(SyntaxError,Unexpected token in JSON at position %jjp) }
  var -n %rev = $js_arg(%args,2)
  if ($js_iscallable(%rev)) { var -n %v = $js_jsonrevive(%rev,$js_newobj,s,%v) }
  return %v
}

; one JSON value from the token table
alias js_jsonval {
  var -n %t = $hget(jst,%jjp $+ :t)
  var -n %v = $hget(jst,%jjp $+ :v)
  inc %jjp
  if (%t === s) || (%t === n) { return %v }
  if (%t === k) {
    if (%v === null) { return z }
    if (%v === true) { return t }
    if (%v === false) { return f }
  }
  if (%t === p) {
    if (%v === sub) && ($hget(jst,%jjp $+ :t) === n) {
      var -n %n = $hget(jst,%jjp $+ :v)
      inc %jjp
      return $js_numtok($calc( 0 - $mid(%n,2) ))
    }
    if (%v === ls) {
      var -n %list = $null
      if ($hget(jst,%jjp $+ :v) === rs) { inc %jjp | return $js_newarr($null) }
      while (1) {
        var -n %x = $js_jsonval
        if (%jsc) { return u }
        var -n %list = %list %x
        var -n %sep = $hget(jst,%jjp $+ :v)
        inc %jjp
        if (%sep === rs) { return $js_newarr(%list) }
        if (%sep !=== comma) { break }
      }
    }
    if (%v === lb) {
      var -n %o = $js_newobj
      if ($hget(jst,%jjp $+ :v) === rb) { inc %jjp | return %o }
      while (1) {
        if ($hget(jst,%jjp $+ :t) !=== s) { break }
        var -n %k = $js_kenc($mid($hget(jst,%jjp $+ :v),2))
        inc %jjp
        if ($hget(jst,%jjp $+ :v) !=== colon) { break }
        inc %jjp
        var -n %x = $js_jsonval
        if (%jsc) { return u }
        noop $js_put(%o,%k,%x)
        var -n %sep = $hget(jst,%jjp $+ :v)
        inc %jjp
        if (%sep === rb) { return %o }
        if (%sep !=== comma) { break }
      }
    }
  }
  return $js_throw(SyntaxError,Unexpected token in JSON at position %jjp)
}

alias js_jsonrevive {
  var -n %v = $4
  if ($left(%v,1) === o) {
    var -n %keys = $js_ownkeys(%v)
    var -n %i = 1
    while (%i <= $numtok(%keys,32)) {
      var -n %k = $gettok(%keys,%i,32)
      var -n %nv = $js_jsonrevive($1,%v,s $+ $js_kdec(%k),$js_get(%v,%k))
      if (%nv === u) { noop $js_delete(%v,%k) }
      else { noop $js_put(%v,%k,%nv) }
      inc %i
    }
  }
  return $js_call($1,$2,$3 %v)
}

; ---------------------------------------------------------------- Map, Set --
; entries live in jso as <id>|k<n> and <id>|v<n>; <id>:mk maps a key token
; (case-escaped) to its slot; <id>:order lists the live slots

alias js.b.mapset {
  var -n %m = $js_gctor(Map,0,js_b_map,MP)
  js.defs $hget(jsm,MP) get:1:js_b_mapget set:2:js_b_mapset has:1:js_b_maphas delete:1:js_b_mapdelete clear:0:js_b_mapclear forEach:1:js_b_mapforeach keys:0:js_b_mapkeys values:0:js_b_mapvalues entries:0:js_b_mapentriesm
  noop $js_defacc($hget(jsm,MP),size,$js_mknat(size,0,js_b_mapsize),0,0)
  var -n %s = $js_gctor(Set,0,js_b_set,SetP)
  js.defs $hget(jsm,SetP) add:1:js_b_setadd has:1:js_b_maphas delete:1:js_b_mapdelete clear:0:js_b_mapclear forEach:1:js_b_setforeach values:0:js_b_setvaluesm keys:0:js_b_setvaluesm entries:0:js_b_setentries
  noop $js_defacc($hget(jsm,SetP),size,$js_mknat(size,0,js_b_mapsize),0,0)
  noop $js_decl(1,^Weak^Map,%m)
  noop $js_decl(1,^Weak^Set,%s)
}

alias js_b_map {
  var -n %args = %jsna
  var -n %m = %jsnt
  if (!%jsnew) { return $js_throw(TypeError,Constructor Map requires 'new') }
  hadd jso $mid(%m,2) $+ :c Map
  hadd jso $mid(%m,2) $+ :n 0
  var -n %init = $js_arg(%args,1)
  if (%init !=== u) && (%init !=== z) {
    var -n %list = $js_iterlist(%init)
    if (%jsc) { return u }
    var -n %i = 1
    while (%i <= $numtok(%list,32)) {
      var -n %e = $gettok(%list,%i,32)
      noop $js_mapput(%m,$js_get(%e,0),$js_get(%e,1))
      inc %i
    }
  }
  return %m
}

alias js_b_set {
  var -n %args = %jsna
  var -n %m = %jsnt
  if (!%jsnew) { return $js_throw(TypeError,Constructor Set requires 'new') }
  hadd jso $mid(%m,2) $+ :c Set
  hadd jso $mid(%m,2) $+ :n 0
  var -n %init = $js_arg(%args,1)
  if (%init !=== u) && (%init !=== z) {
    var -n %list = $js_iterlist(%init)
    if (%jsc) { return u }
    var -n %i = 1
    while (%i <= $numtok(%list,32)) {
      noop $js_mapput(%m,$gettok(%list,%i,32),$gettok(%list,%i,32))
      inc %i
    }
  }
  return %m
}

; slot of a key in a map, or $null
alias js_mapslot { return $hget(jso,$mid($1,2) $+ :mk. $+ $js_kenc($2)) }

alias js_mapput {
  var -n %id = $mid($1,2)
  var -n %slot = $js_mapslot($1,$2)
  if (!%slot) {
    var -n %slot = $calc( $hget(jso,%id $+ :n) + 1 )
    hadd jso %id $+ :n %slot
    hadd jso %id $+ :mk. $+ $js_kenc($2) %slot
    hadd jso %id $+ :order $hget(jso,%id $+ :order) %slot
    hadd jso %id $+ $chr(124) $+ k $+ %slot $2
  }
  hadd jso %id $+ $chr(124) $+ v $+ %slot $3
}

; Map/Set methods check their receiver
alias js_mthis {
  var -n %c = $iif($left($1,1) === o,$hget(jso,$mid($1,2) $+ :c),$null)
  if (%c !=== Map) && (%c !=== Set) {
    noop $js_throw(TypeError,Method called on incompatible receiver)
    return 0
  }
  return 1
}

alias js_b_mapget {
  var -n %m = %jsnt
  if (!$js_mthis(%m)) { return u }
  var -n %slot = $js_mapslot(%m,$js_arg(%jsna,1))
  if (!%slot) { return u }
  return $hget(jso,$mid(%m,2) $+ $chr(124) $+ v $+ %slot)
}

alias js_b_mapset {
  var -n %m = %jsnt
  if (!$js_mthis(%m)) { return u }
  noop $js_mapput(%m,$js_arg(%jsna,1),$js_arg(%jsna,2))
  return %m
}

alias js_b_setadd {
  var -n %m = %jsnt
  if (!$js_mthis(%m)) { return u }
  noop $js_mapput(%m,$js_arg(%jsna,1),$js_arg(%jsna,1))
  return %m
}

alias js_b_maphas {
  var -n %m = %jsnt
  if (!$js_mthis(%m)) { return u }
  return $js_bool($iif($js_mapslot(%m,$js_arg(%jsna,1)),1,0))
}

alias js_b_mapdelete {
  var -n %m = %jsnt
  if (!$js_mthis(%m)) { return u }
  var -n %k = $js_arg(%jsna,1)
  var -n %slot = $js_mapslot(%m,%k)
  if (!%slot) { return f }
  var -n %id = $mid(%m,2)
  hdel jso %id $+ :mk. $+ $js_kenc(%k)
  hdel jso %id $+ $chr(124) $+ k $+ %slot
  hdel jso %id $+ $chr(124) $+ v $+ %slot
  hadd jso %id $+ :order $remtok($hget(jso,%id $+ :order),%slot,1,32)
  return t
}

alias js_b_mapclear {
  var -n %m = %jsnt
  if (!$js_mthis(%m)) { return u }
  var -n %id = $mid(%m,2)
  var -n %order = $hget(jso,%id $+ :order)
  var -n %i = 1
  while (%i <= $numtok(%order,32)) {
    var -n %slot = $gettok(%order,%i,32)
    hdel jso %id $+ :mk. $+ $js_kenc($hget(jso,%id $+ $chr(124) $+ k $+ %slot))
    hdel jso %id $+ $chr(124) $+ k $+ %slot
    hdel jso %id $+ $chr(124) $+ v $+ %slot
    inc %i
  }
  hadd jso %id $+ :order $null
  return u
}

alias js_b_mapsize {
  if (!$js_mthis(%jsnt)) { return u }
  return n $+ $numtok($hget(jso,$mid(%jsnt,2) $+ :order),32)
}

; [key, value] pairs of a map as arrays
alias js_mapentries {
  var -n %id = $mid($1,2)
  var -n %order = $hget(jso,%id $+ :order)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%order,32)) {
    var -n %slot = $gettok(%order,%i,32)
    var -n %out = %out $js_newarr($hget(jso,%id $+ $chr(124) $+ k $+ %slot) $hget(jso,%id $+ $chr(124) $+ v $+ %slot))
    inc %i
  }
  return %out
}

; keys or values of a map as a token list: $js_mapcol(map,k|v)
alias js_mapcol {
  var -n %id = $mid($1,2)
  var -n %order = $hget(jso,%id $+ :order)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%order,32)) {
    var -n %out = %out $hget(jso,%id $+ $chr(124) $+ $2 $+ $gettok(%order,%i,32))
    inc %i
  }
  return %out
}

alias js_setvalues { return $js_mapcol($1,k) }
alias js_b_mapkeys { return $js_newarr($js_mapcol(%jsnt,k)) }
alias js_b_mapvalues { return $js_newarr($js_mapcol(%jsnt,v)) }
alias js_b_mapentriesm { return $js_newarr($js_mapentries(%jsnt)) }
alias js_b_setvaluesm { return $js_newarr($js_mapcol(%jsnt,k)) }

alias js_b_setentries {
  var -n %list = $js_mapcol(%jsnt,k)
  var -n %out = $null
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    var -n %out = %out $js_newarr($gettok(%list,%i,32) $gettok(%list,%i,32))
    inc %i
  }
  return $js_newarr(%out)
}

alias js_b_mapforeach {
  var -n %m = %jsnt
  var -n %fn = $js_arg(%jsna,1)
  var -n %this = $js_arg(%jsna,2)
  if (!$js_mthis(%m)) { return u }
  var -n %id = $mid(%m,2)
  var -n %order = $hget(jso,%id $+ :order)
  var -n %i = 1
  while (%i <= $numtok(%order,32)) {
    var -n %slot = $gettok(%order,%i,32)
    noop $js_call(%fn,%this,$hget(jso,%id $+ $chr(124) $+ v $+ %slot) $hget(jso,%id $+ $chr(124) $+ k $+ %slot) %m)
    if (%jsc) { return u }
    inc %i
  }
  return u
}

alias js_b_setforeach {
  var -n %m = %jsnt
  var -n %fn = $js_arg(%jsna,1)
  var -n %this = $js_arg(%jsna,2)
  if (!$js_mthis(%m)) { return u }
  var -n %list = $js_mapcol(%m,k)
  var -n %i = 1
  while (%i <= $numtok(%list,32)) {
    noop $js_call(%fn,%this,$gettok(%list,%i,32) $gettok(%list,%i,32) %m)
    if (%jsc) { return u }
    inc %i
  }
  return u
}

; -------------------------------------------------------------------- Date --
; a Date keeps milliseconds since 1970 in :t (UTC); local time uses $asctime

alias js.b.date {
  var -n %f = $js_gctor(Date,7,js_b_date,DP)
  js.defs %f now:0:js_b_datenow parse:1:js_b_dateparse UTC:7:js_b_dateutc
  js.defs $hget(jsm,DP) getTime:0:js_b_dgettime valueOf:0:js_b_dgettime toISOString:0:js_b_dtoiso toJSON:0:js_b_dtoiso toString:0:js_b_dtostring toLocaleString:0:js_b_dtolocale toLocaleDateString:0:js_b_dtolocaledate toLocaleTimeString:0:js_b_dtolocaletime getFullYear:0:js_b_dyear getMonth:0:js_b_dmonth getDate:0:js_b_dday getDay:0:js_b_dweekday getHours:0:js_b_dhours getMinutes:0:js_b_dminutes getSeconds:0:js_b_dseconds getMilliseconds:0:js_b_dms getTimezoneOffset:0:js_b_dtzo
}

alias js_nowms { return $calc( $ctime * 1000 + $right($ticks,3) ) }

alias js_b_datenow { return n $+ $js_nowms }

alias js_b_date {
  var -n %args = %jsna
  var -n %ms = $js_nowms
  var -n %n = $numtok(%args,32)
  if (%n == 1) {
    var -n %a = $gettok(%args,1,32)
    if ($left(%a,1) === s) { var -n %ms = $js_dateparse($js_dec($mid(%a,2))) }
    elseif ($left(%a,1) === o) && ($hget(jso,$mid(%a,2) $+ :t) != $null) { var -n %ms = $v1 }
    else { var -n %ms = $js_tonum(%a) }
  }
  elseif (%n > 1) {
    var -n %y = $js_tonum($gettok(%args,1,32))
    var -n %mo = $js_tonum($gettok(%args,2,32))
    var -n %d = $iif(%n >= 3,$js_tonum($gettok(%args,3,32)),1)
    var -n %h = $iif(%n >= 4,$js_tonum($gettok(%args,4,32)),0)
    var -n %mi = $iif(%n >= 5,$js_tonum($gettok(%args,5,32)),0)
    var -n %s = $iif(%n >= 6,$js_tonum($gettok(%args,6,32)),0)
    var -n %msp = $iif(%n >= 7,$js_tonum($gettok(%args,7,32)),0)
    var -n %ms = $calc( ( $js_localtoepoch(%y,%mo,%d,%h,%mi,%s) ) * 1000 + %msp )
  }
  if (!%jsnew) { return s $+ $js_enc($js_datestr(%ms)) }
  hadd jso $mid(%jsnt,2) $+ :c Date
  hadd jso $mid(%jsnt,2) $+ :t %ms
  return %jsnt
}

; days since 1970-01-01 for a UTC date (month 0-11)
alias js_daysfromcivil {
  var -n %y = $1
  var -n %m = $calc( $2 + 1 )
  var -n %d = $3
  if (%m <= 2) { dec %y }
  var -n %era = $floor($calc( %y / 400 ))
  var -n %yoe = $calc( %y - %era * 400 )
  var -n %mp = $calc( ( %m + 9 ) % 12 )
  var -n %doy = $calc( $int($calc( ( 153 * %mp + 2 ) / 5 )) + %d - 1 )
  var -n %doe = $calc( %yoe * 365 + $int($calc( %yoe / 4 )) - $int($calc( %yoe / 100 )) + %doy )
  return $calc( %era * 146097 + %doe - 719468 )
}

; UTC parts -> epoch seconds
alias js_utctoepoch { return $calc( $js_daysfromcivil($1,$2,$3) * 86400 + $4 * 3600 + $5 * 60 + $6 ) }

; local parts -> epoch seconds (using the local offset now)
alias js_localtoepoch { return $calc( $js_utctoepoch($1,$2,$3,$4,$5,$6) + $js_tzofs * 60 ) }

; local timezone offset in minutes (like getTimezoneOffset)
alias js_tzofs {
  var -n %c = $ctime
  var -n %l = $js_utctoepoch($asctime(%c,yyyy),$calc( $asctime(%c,m) - 1 ),$asctime(%c,d),$asctime(%c,H),$asctime(%c,n),$asctime(%c,s))
  return $calc( ( %c - %l ) / 60 )
}

; parse ISO-ish date text -> ms (NaN if not understood)
alias js_dateparse {
  var -n %s = $1
  if ($regex(%s,/^(\d{4})-(\d\d)-(\d\d)(?:[T ](\d\d):(\d\d)(?::(\d\d)(?:\.(\d{1,3}))?)?)?(Z|[+-]\d\d:?\d\d)?$/)) {
    var -n %y = $regml(1)
    var -n %mo = $calc( $regml(2) - 1 )
    var -n %d = $regml(3)
    var -n %h = $iif($regml(4) != $null,$regml(4),0)
    var -n %mi = $iif($regml(5) != $null,$regml(5),0)
    var -n %se = $iif($regml(6) != $null,$regml(6),0)
    var -n %ms = $iif($regml(7) != $null,$left($regml(7) $+ 00,3),0)
    var -n %z = $regml(8)
    var -n %t = $js_utctoepoch(%y,%mo,%d,%h,%mi,%se)
    if (%z != $null) && (%z !== Z) {
      var -n %sign = $iif($left(%z,1) == -,-1,1)
      var -n %zz = $remove($mid(%z,2),:)
      var -n %t = $calc( %t - %sign * ( $left(%zz,2) * 3600 + $right(%zz,2) * 60 ) )
    }
    elseif (%z == $null) && (%h || %mi || %se) && ($regml(4) != $null) { var -n %t = $calc( %t + $js_tzofs * 60 ) }
    return $calc( %t * 1000 + %ms )
  }
  return NaN
}

alias js_b_dateparse { return n $+ $js_dateparse($js_argtext(%jsna,1)) }

alias js_b_dateutc {
  var -n %a = %jsna
  var -n %t = $js_utctoepoch($js_tonum($js_arg(%a,1)),$js_tonum($iif($gettok(%a,2,32),$v1,n0)),$js_tonum($iif($gettok(%a,3,32),$v1,n1)),$js_tonum($iif($gettok(%a,4,32),$v1,n0)),$js_tonum($iif($gettok(%a,5,32),$v1,n0)),$js_tonum($iif($gettok(%a,6,32),$v1,n0)))
  return n $+ $calc( %t * 1000 + $js_tonum($iif($gettok(%a,7,32),$v1,n0)) )
}

; ms of a Date this
alias js_dthis {
  var -n %t = $iif($left($1,1) === o,$hget(jso,$mid($1,2) $+ :t),$null)
  if (%t == $null) { noop $js_throw(TypeError,this is not a Date object.) | return NaN }
  return %t
}

alias js_b_dgettime { return n $+ $js_dthis(%jsnt) }

alias js_b_dtoiso {
  var -n %ms = $js_dthis(%jsnt)
  if (%ms === NaN) { return $js_throw(RangeError,Invalid time value) }
  var -n %s = $floor($calc( %ms / 1000 ))
  var -n %frac = $calc( %ms - %s * 1000 )
  var -n %days = $floor($calc( %s / 86400 ))
  var -n %rem = $calc( %s - %days * 86400 )
  var -n %civ = $js_civilfromdays(%days)
  var -n %iso = $gettok(%civ,1,32) $+ - $+ $base($gettok(%civ,2,32),10,10,2) $+ - $+ $base($gettok(%civ,3,32),10,10,2) $+ T $+ $base($int($calc( %rem / 3600 )),10,10,2) $+ : $+ $base($int($calc( ( %rem % 3600 ) / 60 )),10,10,2) $+ : $+ $base($calc( %rem % 60 ),10,10,2) $+ . $+ $base(%frac,10,10,3) $+ Z
  return s $+ %iso
}

; days since 1970 -> "year month(1-12) day"
alias js_civilfromdays {
  var -n %z = $calc( $1 + 719468 )
  var -n %era = $floor($calc( %z / 146097 ))
  var -n %doe = $calc( %z - %era * 146097 )
  var -n %yoe = $int($calc( ( %doe - $int($calc( %doe / 1460 )) + $int($calc( %doe / 36524 )) - $int($calc( %doe / 146096 )) ) / 365 ))
  var -n %y = $calc( %yoe + %era * 400 )
  var -n %doy = $calc( %doe - ( 365 * %yoe + $int($calc( %yoe / 4 )) - $int($calc( %yoe / 100 )) ) )
  var -n %mp = $int($calc( ( 5 * %doy + 2 ) / 153 ))
  var -n %d = $calc( %doy - $int($calc( ( 153 * %mp + 2 ) / 5 )) + 1 )
  var -n %m = $iif(%mp < 10,$calc( %mp + 3 ),$calc( %mp - 9 ))
  if (%m <= 2) { inc %y }
  return %y %m %d
}

; local text for a ms value via $asctime
alias js_datestr {
  if ($1 === NaN) { return Invalid Date }
  return $asctime($int($calc( $1 / 1000 )),ddd mmm dd yyyy HH:nn:ss)
}

alias js_b_dtostring { return s $+ $js_enc($js_datestr($js_dthis(%jsnt))) }
alias js_b_dtolocale { return s $+ $js_enc($asctime($int($calc( $js_dthis(%jsnt) / 1000 )),dd/mm/yyyy $+ $chr(44) HH:nn:ss)) }
alias js_b_dtolocaledate { return s $+ $js_enc($asctime($int($calc( $js_dthis(%jsnt) / 1000 )),dd/mm/yyyy)) }
alias js_b_dtolocaletime { return s $+ $js_enc($asctime($int($calc( $js_dthis(%jsnt) / 1000 )),HH:nn:ss)) }

; a local date part: $js_dpart(this,asctime format)
alias js_dpart {
  var -n %ms = $js_dthis($1)
  if (%ms === NaN) { return NaN }
  return $asctime($int($calc( %ms / 1000 )),$2)
}

alias js_b_dyear { return n $+ $js_dpart(%jsnt,yyyy) }
alias js_b_dmonth { return n $+ $calc( $js_dpart(%jsnt,m) - 1 ) }
alias js_b_dday { return n $+ $js_dpart(%jsnt,d) }
alias js_b_dhours { return n $+ $js_dpart(%jsnt,H) }
alias js_b_dminutes { return n $+ $js_dpart(%jsnt,n) }
alias js_b_dseconds { return n $+ $js_dpart(%jsnt,s) }
alias js_b_dms { return n $+ $calc( $js_dthis(%jsnt) % 1000 ) }
alias js_b_dtzo { return n $+ $js_tzofs }

alias js_b_dweekday {
  var -n %ms = $js_dthis(%jsnt)
  return n $+ $calc( $findtok(Sun Mon Tue Wed Thu Fri Sat,$asctime($int($calc( %ms / 1000 )),ddd),1,32) - 1 )
}

; ------------------------------------------------------------------ RegExp --
; a RegExp keeps its source (encoded) in :src and flags in :flags; matching
; uses mIRC's PCRE-style $regex on the text after the current position

alias js.b.regexp {
  noop $js_gctor(RegExp,2,js_b_regexp,RP)
  js.defs $hget(jsm,RP) test:1:js_b_retest exec:1:js_b_reexec toString:0:js_b_retostring
}

alias js_newregexp {
  var -n %r = $js_new($hget(jsm,RP),RegExp)
  noop $js_reinit(%r,$1,$2)
  return %r
}

alias js_reinit {
  var -n %id = $mid($1,2)
  hadd jso %id $+ :c RegExp
  hadd jso %id $+ :src $iif($2 == $null,$js_enc((?:)),$2)
  hadd jso %id $+ :flags $3
  noop $js_defhidden($1,source,s $+ $iif($2 == $null,$js_enc((?:)),$2))
  noop $js_defhidden($1,flags,s $+ $3)
  noop $js_defhidden($1,global,$js_bool($iif(g isincs $3,1,0)))
  noop $js_defhidden($1,ignore^Case,$js_bool($iif(i isincs $3,1,0)))
  noop $js_defhidden($1,multiline,$js_bool($iif(m isincs $3,1,0)))
  noop $js_defhidden($1,last^Index,n0)
}

alias js_b_regexp {
  var -n %args = %jsna
  var -n %p = $js_arg(%args,1)
  var -n %f = $js_arg(%args,2)
  var -n %src = $null
  if ($js_isregexp(%p)) { var -n %src = $hget(jso,$mid(%p,2) $+ :src) | if (%f === u) { var -n %f = s $+ $hget(jso,$mid(%p,2) $+ :flags) } }
  else { var -n %src = $iif(%p === u,$null,$js_tostr(%p)) }
  var -n %fl = $iif(%f === u,$null,$js_dec($js_tostr(%f)))
  var -n %r = $iif(%jsnew,%jsnt,$js_new($hget(jsm,RP),RegExp))
  noop $js_reinit(%r,%src,%fl)
  return %r
}

alias js_isregexp { return $iif($left($1,1) === o && $hget(jso,$mid($1,2) $+ :c) === RegExp,1,0) }

alias js_reflag { return $iif($2 isincs $hget(jso,$mid($1,2) $+ :flags),1,0) }

; the mIRC regex for a RegExp: /(source)/flags. The whole pattern is wrapped
; in one group because $regml reports the whole match as group 1 only when a
; pattern has no groups of its own; wrapped, group 1 is always the whole match
; (with its position) and the pattern's own groups follow. Backreferences in
; the source move up by one to match.
alias js_repattern {
  var -n %fl = $remove($hget(jso,$mid($1,2) $+ :flags),g,y,u,d)
  var -n %src = $regsubex($js_dec($hget(jso,$mid($1,2) $+ :src)),/(?<!\\)\\([1-9])/g,$js_rebackref(\1))
  return /( $+ %src $+ )/ $+ %fl
}

alias js_rebackref { return $chr(92) $+ $calc( $1 + 1 ) }

; a piece of text by 0-based start and length ("" when length <= 0; $mid
; would return the rest of the text for a length of 0)
alias js_substr {
  if ($3 <= 0) { return $null }
  return $mid($1,$calc( $2 + 1 ),$3)
}

; escape text for use as a regex
alias js_reescape { return $regsubex($1,/([.*+?^${}()|[\]\\\/])/g,\\\1) }

; first match at or after position $3 (0-based) ->
;   "index<1>s<match><1>s<group1><1>..." or $null; groups are value tokens
alias js_refind {
  var -n %t = $2
  var -n %from = $3
  var -n %pat = $js_repattern($1)
  var -n %rest = $mid(%t,$calc( %from + 1 ))
  if (%from > $len(%t)) { return $null }
  if (!$regex(jsre,%rest,%pat)) { return $null }
  var -n %m = $regml(jsre,0)
  ; group 1 is the whole match (see $js_repattern)
  var -n %idx = $calc( %from + $regml(jsre,1).pos - 1 )
  var -n %out = %idx $+ $chr(2) $+ s $+ $js_enc($regml(jsre,1))
  var -n %i = 2
  while (%i <= %m) {
    var -n %g = $regml(jsre,%i)
    var -n %out = %out $+ $chr(2) $+ $iif(%g == $null && !$regml(jsre,%i).pos,u,s $+ $js_enc(%g))
    inc %i
  }
  return %out
}

; every match of a global regex -> list of match records separated by spaces
; (each record is the $js_refind format with <1> separators)
alias js_reall {
  var -n %out = $null
  var -n %pos = 0
  var -n %guard = 0
  while (%guard < 10000) {
    var -n %m = $js_refind($1,$2,%pos)
    if (%m == $null) { break }
    var -n %out = %out %m
    var -n %idx = $gettok(%m,1,2)
    var -n %len = $len($js_dec($mid($gettok(%m,2,2),2)))
    var -n %pos = $calc( %idx + $iif(%len,%len,1) )
    if (%pos > $len($2)) { break }
    inc %guard
  }
  return %out
}

; a match record -> match array with index and input
alias js_rematcharr {
  var -n %rec = $1
  var -n %n = $numtok(%rec,2)
  var -n %list = $null
  var -n %i = 2
  while (%i <= %n) {
    var -n %list = %list $gettok(%rec,%i,2)
    inc %i
  }
  var -n %a = $js_newarr(%list)
  noop $js_put(%a,index,n $+ $gettok(%rec,1,2))
  noop $js_put(%a,input,s $+ $js_enc($2))
  return %a
}

alias js_reexec {
  var -n %re = $1
  var -n %t = $2
  var -n %glob = $iif($js_reflag(%re,g) || $js_reflag(%re,y),1,0)
  var -n %from = 0
  if (%glob) { var -n %from = $int($js_tonum($js_get(%re,last^Index))) }
  var -n %m = $js_refind(%re,%t,%from)
  if (%m == $null) {
    if (%glob) { noop $js_put(%re,last^Index,n0) }
    return z
  }
  if (%glob) {
    var -n %len = $len($js_dec($mid($gettok(%m,2,2),2)))
    noop $js_put(%re,last^Index,n $+ $calc( $gettok(%m,1,2) + $iif(%len,%len,1) ))
  }
  return $js_rematcharr(%m,%t)
}

alias js_b_reexec { return $js_reexec(%jsnt,$js_argtext(%jsna,1)) }

alias js_b_retest {
  var -n %r = $js_reexec(%jsnt,$js_argtext(%jsna,1))
  return $iif(%r === z,f,t)
}

alias js_b_retostring {
  var -n %id = $mid(%jsnt,2)
  return s/ $+ $hget(jso,%id $+ :src) $+ / $+ $hget(jso,%id $+ :flags)
}

; replace with a regex (string or function replacement)
alias js_rereplace {
  var -n %re = $1
  var -n %t = $2
  var -n %rep = $3
  var -n %all = $iif($js_reflag(%re,g),$js_reall(%re,%t),$js_refind(%re,%t,0))
  if (!$js_reflag(%re,g)) && ($4) { return $js_throw(TypeError,replaceAll must be called with a global RegExp) }
  var -n %out = $null
  var -n %pos = 0
  var -n %i = 1
  while (%i <= $numtok(%all,32)) {
    var -n %m = $gettok(%all,%i,32)
    var -n %idx = $gettok(%m,1,2)
    var -n %match = $js_dec($mid($gettok(%m,2,2),2))
    var -n %groups = $gettok(%m,3-,2)
    var -n %out = %out $+ $js_enc($js_substr(%t,%pos,$calc( %idx - %pos )))
    if ($js_iscallable(%rep)) {
      var -n %args = s $+ $js_enc(%match) $replace(%groups,$chr(2),$chr(32)) n $+ %idx s $+ $js_enc(%t)
      var -n %r = $js_call(%rep,u,%args)
      if (%jsc) { return u }
      var -n %out = %out $+ $js_tostr(%r)
    }
    else { var -n %out = %out $+ $js_enc($js_expandrep($js_dec($js_tostr(%rep)),%match,%groups,%idx,%t)) }
    var -n %pos = $calc( %idx + $len(%match) )
    inc %i
  }
  return s $+ %out $+ $js_enc($mid(%t,$calc( %pos + 1 )))
}

; split by a regex
alias js_resplit {
  var -n %all = $js_reall($iif($js_reflag($1,g),$1,$js_newregexp($hget(jso,$mid($1,2) $+ :src),g $+ $hget(jso,$mid($1,2) $+ :flags))),$2)
  var -n %out = $null
  var -n %pos = 0
  var -n %count = 0
  var -n %i = 1
  while (%i <= $numtok(%all,32)) && (%count < $3) {
    var -n %m = $gettok(%all,%i,32)
    var -n %idx = $gettok(%m,1,2)
    var -n %len = $len($js_dec($mid($gettok(%m,2,2),2)))
    if (%len == 0) && (%idx == %pos) { inc %i | continue }
    var -n %out = %out s $+ $js_enc($js_substr($2,%pos,$calc( %idx - %pos )))
    if ($numtok(%m,2) > 2) { var -n %out = %out $replace($gettok(%m,3-,2),$chr(2),$chr(32)) }
    var -n %pos = $calc( %idx + %len )
    inc %count
    inc %i
  }
  if (%count < $3) { var -n %out = %out s $+ $js_enc($mid($2,$calc( %pos + 1 ))) }
  return $js_newarr(%out)
}

; ----------------------------------------------------------------- Promise --
; state in :ps (p, f, r), value in :pv, reactions in :pr (list of objects)
; jobs wait in jsm as job.<n>; $js_drain runs them

alias js.b.promise {
  var -n %f = $js_gctor(Promise,1,js_b_promise,PP)
  js.defs %f resolve:1:js_b_presolvestatic reject:1:js_b_prejectstatic all:1:js_b_pall allSettled:1:js_b_pallsettled race:1:js_b_prace any:1:js_b_pany
  js.defs $hget(jsm,PP) then:2:js_b_pthen catch:1:js_b_pcatch finally:1:js_b_pfinally
}

alias js_newpromise {
  var -n %p = $js_new($hget(jsm,PP),Promise)
  hadd jso $mid(%p,2) $+ :ps p
  return %p
}

alias js_ispromise { return $iif($left($1,1) === o && $hget(jso,$mid($1,2) $+ :ps) != $null,1,0) }

alias js_b_promise {
  var -n %exec = $js_arg(%jsna,1)
  var -n %p = %jsnt
  if (!%jsnew) { return $js_throw(TypeError,Promise constructor cannot be invoked without 'new') }
  if (!$js_iscallable(%exec)) { return $js_throw(TypeError,Promise resolver $js_desc(%exec) is not a function) }
  hadd jso $mid(%p,2) $+ :ps p
  hadd jso $mid(%p,2) $+ :c Promise
  noop $js_call(%exec,u,$js_resolvers(%p))
  if (%jsc === x) {
    var -n %e = %jscv
    unset %jsc %jscv
    noop $js_preject(%p,%e)
  }
  return %p
}

; resolve and reject functions for a promise -> "resolveFn rejectFn"
alias js_resolvers {
  var -n %r = $js_mknat(resolve,1,js_b_presolvefn)
  var -n %j = $js_mknat(reject,1,js_b_prejectfn)
  hadd jso $mid(%r,2) $+ :pid $1
  hadd jso $mid(%j,2) $+ :pid $1
  hadd jso $mid(%r,2) $+ :pair %j
  hadd jso $mid(%j,2) $+ :pair %r
  return %r %j
}

alias js_b_presolvefn {
  var -n %f = %jsnf
  var -n %v = $js_arg(%jsna,1)
  if ($hget(jso,$mid(%f,2) $+ :used)) { return u }
  hadd jso $mid(%f,2) $+ :used 1
  hadd jso $mid($hget(jso,$mid(%f,2) $+ :pair),2) $+ :used 1
  noop $js_presolve($hget(jso,$mid(%f,2) $+ :pid),%v)
  return u
}

alias js_b_prejectfn {
  var -n %f = %jsnf
  var -n %v = $js_arg(%jsna,1)
  if ($hget(jso,$mid(%f,2) $+ :used)) { return u }
  hadd jso $mid(%f,2) $+ :used 1
  hadd jso $mid($hget(jso,$mid(%f,2) $+ :pair),2) $+ :used 1
  noop $js_preject($hget(jso,$mid(%f,2) $+ :pid),%v)
  return u
}

; resolve a promise with a value (adopting thenables)
alias js_presolve {
  var -n %p = $1
  var -n %v = $2
  if ($hget(jso,$mid(%p,2) $+ :ps) !=== p) { return }
  if (%v === %p) { noop $js_preject(%p,$js_mkerr(TypeError,Chaining cycle detected for promise)) | return }
  if ($left(%v,1) === o) {
    var -n %then = $js_get(%v,then)
    if (%jsc === x) {
      var -n %e = %jscv
      unset %jsc %jscv
      noop $js_preject(%p,%e)
      return
    }
    if ($js_iscallable(%then)) {
      noop $js_enqueue(adopt,%p,%v,%then)
      return
    }
  }
  noop $js_psettle(%p,f,%v)
}

alias js_preject { noop $js_psettle($1,r,$2) }

; an error object without throwing it
alias js_mkerr {
  var -n %saved = %jsc
  var -n %sv = %jscv
  noop $js_throw($1,$2-)
  var -n %e = %jscv
  set %jsc %saved
  set %jscv %sv
  if (%saved == $null) { unset %jsc %jscv }
  return %e
}

alias js_psettle {
  var -n %id = $mid($1,2)
  if ($hget(jso,%id $+ :ps) !=== p) { return }
  hadd jso %id $+ :ps $2
  hadd jso %id $+ :pv $3
  var -n %rs = $hget(jso,%id $+ :pr)
  var -n %i = 1
  while (%i <= $numtok(%rs,32)) {
    noop $js_enqueue(react,$gettok(%rs,%i,32),$1)
    inc %i
  }
  hdel jso %id $+ :pr
  if ($2 === r) && (!$hget(jso,%id $+ :handled)) { hadd jsm unhandled $hget(jsm,unhandled) $1 }
}

; then(onFulfilled, onRejected) -> new promise
alias js_b_pthen {
  var -n %p = %jsnt
  var -n %args = %jsna
  if (!$js_ispromise(%p)) { return $js_throw(TypeError,Method Promise.prototype.then called on incompatible receiver) }
  return $js_pthen(%p,$js_arg(%args,1),$js_arg(%args,2))
}

alias js_pthen {
  var -n %child = $js_newpromise
  var -n %r = $js_newobj
  hadd jso $mid(%r,2) $+ :onf $2
  hadd jso $mid(%r,2) $+ :onr $3
  hadd jso $mid(%r,2) $+ :child %child
  var -n %id = $mid($1,2)
  hadd jso %id $+ :handled 1
  hadd jsm unhandled $remtok($hget(jsm,unhandled),$1,1,32)
  if ($hget(jso,%id $+ :ps) === p) { hadd jso %id $+ :pr $hget(jso,%id $+ :pr) %r }
  else { noop $js_enqueue(react,%r,$1) }
  return %child
}

alias js_b_pcatch { return $js_pthen(%jsnt,u,$js_arg(%jsna,1)) }

alias js_b_pfinally {
  var -n %p = %jsnt
  var -n %fn = $js_arg(%jsna,1)
  var -n %onf = $js_mknat(finally,1,js_b_pfinallyf)
  var -n %onr = $js_mknat(finally,1,js_b_pfinallyr)
  hadd jso $mid(%onf,2) $+ :cb %fn
  hadd jso $mid(%onr,2) $+ :cb %fn
  return $js_pthen(%p,%onf,%onr)
}

alias js_b_pfinallyf {
  var -n %v = $js_arg(%jsna,1)
  var -n %cb = $hget(jso,$mid(%jsnf,2) $+ :cb)
  if ($js_iscallable(%cb)) { noop $js_call(%cb,u,$null) }
  if (%jsc) { return u }
  return %v
}

alias js_b_pfinallyr {
  var -n %v = $js_arg(%jsna,1)
  var -n %cb = $hget(jso,$mid(%jsnf,2) $+ :cb)
  if ($js_iscallable(%cb)) { noop $js_call(%cb,u,$null) }
  if (%jsc) { return u }
  return $js_throwv(%v)
}

alias js_b_presolvestatic {
  var -n %v = $js_arg(%jsna,1)
  if ($js_ispromise(%v)) { return %v }
  var -n %p = $js_newpromise
  noop $js_presolve(%p,%v)
  return %p
}

alias js_b_prejectstatic {
  var -n %p = $js_newpromise
  noop $js_preject(%p,$js_arg(%jsna,1))
  return %p
}

; Promise.all / allSettled / race / any share one combinator
alias js_b_pall { return $js_pcombine(all,$js_arg(%jsna,1)) }
alias js_b_pallsettled { return $js_pcombine(settled,$js_arg(%jsna,1)) }
alias js_b_prace { return $js_pcombine(race,$js_arg(%jsna,1)) }
alias js_b_pany { return $js_pcombine(any,$js_arg(%jsna,1)) }

alias js_pcombine {
  var -n %mode = $1
  var -n %list = $js_iterlist($2)
  if (%jsc) { return u }
  var -n %result = $js_newpromise
  var -n %n = $numtok(%list,32)
  var -n %state = $js_newobj
  hadd jso $mid(%state,2) $+ :left %n
  hadd jso $mid(%state,2) $+ :vals $js_newarr($null)
  hadd jso $mid(%state,2) $+ :res %result
  hadd jso $mid(%state,2) $+ :mode %mode
  if (%n == 0) {
    if (%mode === any) { noop $js_preject(%result,$js_mkerr(Error,All promises were rejected)) }
    elseif (%mode !=== race) { noop $js_presolve(%result,$js_newarr($null)) }
    return %result
  }
  var -n %i = 1
  while (%i <= %n) {
    var -n %item = $gettok(%list,%i,32)
    if (!$js_ispromise(%item)) {
      var -n %w = $js_newpromise
      noop $js_presolve(%w,%item)
      var -n %item = %w
    }
    var -n %onf = $js_mknat(f,1,js_b_pcombf)
    var -n %onr = $js_mknat(r,1,js_b_pcombr)
    hadd jso $mid(%onf,2) $+ :st %state
    hadd jso $mid(%onf,2) $+ :idx $calc( %i - 1 )
    hadd jso $mid(%onr,2) $+ :st %state
    hadd jso $mid(%onr,2) $+ :idx $calc( %i - 1 )
    noop $js_pthen(%item,%onf,%onr)
    inc %i
  }
  return %result
}

; a member promise of a combinator settled: $js_pcombdone(f|r,value)
alias js_pcombdone {
  var -n %f = %jsnf
  var -n %st = $hget(jso,$mid(%f,2) $+ :st)
  var -n %sid = $mid(%st,2)
  var -n %res = $hget(jso,%sid $+ :res)
  var -n %mode = $hget(jso,%sid $+ :mode)
  var -n %vals = $hget(jso,%sid $+ :vals)
  var -n %idx = $hget(jso,$mid(%f,2) $+ :idx)
  if (%mode === race) {
    if ($1 === f) { noop $js_presolve(%res,$2) }
    else { noop $js_preject(%res,$2) }
    return u
  }
  if (%mode === all) && ($1 === r) { noop $js_preject(%res,$2) | return u }
  if (%mode === any) && ($1 === f) { noop $js_presolve(%res,$2) | return u }
  if (%mode === settled) {
    var -n %o = $js_newobj
    noop $js_put(%o,status,s $+ $iif($1 === f,fulfilled,rejected))
    noop $js_put(%o,$iif($1 === f,value,reason),$2)
    noop $js_put(%vals,%idx,%o)
  }
  else { noop $js_put(%vals,%idx,$2) }
  var -n %left = $calc( $hget(jso,%sid $+ :left) - 1 )
  hadd jso %sid $+ :left %left
  if (%left == 0) {
    if (%mode === any) { noop $js_preject(%res,$js_mkerr(Error,All promises were rejected)) }
    else { noop $js_presolve(%res,%vals) }
  }
  return u
}

alias js_b_pcombf { return $js_pcombdone(f,$js_arg(%jsna,1)) }
alias js_b_pcombr { return $js_pcombdone(r,$js_arg(%jsna,1)) }

; ------------------------------------------------------------------ jobs --

; queue a job: react <reaction> <promise> | adopt <promise> <thenable> <then> | call <fn> <args...>
alias js_enqueue {
  var -n %n = $calc( $hget(jsm,jobhi) + 1 )
  hadd jsm jobhi %n
  hadd jsm job. $+ %n $1-
  if ($hget(jsm,joblo) == $null) { hadd jsm joblo %n }
}

; run queued jobs until none are left
alias js_drain {
  var -n %guard = 0
  while ($hget(jsm,joblo) != $null) && ($hget(jsm,joblo) <= $hget(jsm,jobhi)) && (%guard < 100000) {
    var -n %lo = $hget(jsm,joblo)
    var -n %job = $hget(jsm,job. $+ %lo)
    hdel jsm job. $+ %lo
    hadd jsm joblo $calc( %lo + 1 )
    noop $js_runjob(%job)
    inc %guard
  }
  hdel jsm joblo
  hdel jsm jobhi
  ; rejections nobody handled
  var -n %u = $hget(jsm,unhandled)
  if (%u != $null) {
    hadd jsm unhandled $null
    var -n %i = 1
    while (%i <= $numtok(%u,32)) {
      var -n %p = $gettok(%u,%i,32)
      if (!$hget(jso,$mid(%p,2) $+ :handled)) { noop $js_err(Uncaught (in promise) $js_errtext($hget(jso,$mid(%p,2) $+ :pv))) }
      inc %i
    }
  }
}

alias js_runjob {
  var -n %kind = $gettok($1,1,32)
  if (%kind === react) {
    var -n %r = $gettok($1,2,32)
    var -n %p = $gettok($1,3,32)
    var -n %rid = $mid(%r,2)
    var -n %state = $hget(jso,$mid(%p,2) $+ :ps)
    var -n %v = $hget(jso,$mid(%p,2) $+ :pv)
    var -n %h = $hget(jso,%rid $+ $iif(%state === f,:onf,:onr))
    var -n %child = $hget(jso,%rid $+ :child)
    if (!$js_iscallable(%h)) {
      if (%state === f) { noop $js_presolve(%child,%v) }
      else { noop $js_preject(%child,%v) }
      return
    }
    var -n %res = $js_call(%h,u,%v)
    if (%jsc === x) {
      var -n %e = %jscv
      unset %jsc %jscv
      noop $js_preject(%child,%e)
      return
    }
    unset %jsc %jscv %jscl
    noop $js_presolve(%child,%res)
    return
  }
  if (%kind === adopt) {
    var -n %p = $gettok($1,2,32)
    noop $js_call($gettok($1,4,32),$gettok($1,3,32),$js_resolvers(%p))
    if (%jsc === x) {
      var -n %e = %jscv
      unset %jsc %jscv
      noop $js_preject(%p,%e)
    }
    return
  }
  if (%kind === call) {
    noop $js_call($gettok($1,2,32),u,$gettok($1,3-,32))
    if (%jsc === x) {
      noop $js_err(Uncaught $js_errtext(%jscv))
      unset %jsc %jscv
    }
    unset %jsc %jscv %jscl
  }
}

; await: run queued jobs, then unwrap a settled promise
alias js_await {
  var -n %v = $1
  if (!$js_ispromise(%v)) { return %v }
  ; awaiting counts as handling a rejection
  hadd jso $mid(%v,2) $+ :handled 1
  hadd jsm unhandled $remtok($hget(jsm,unhandled),%v,1,32)
  noop $js_drain
  var -n %st = $hget(jso,$mid(%v,2) $+ :ps)
  if (%st === f) { return $hget(jso,$mid(%v,2) $+ :pv) }
  if (%st === r) {
    hadd jso $mid(%v,2) $+ :handled 1
    return $js_throwv($hget(jso,$mid(%v,2) $+ :pv))
  }
  return $js_throw(Error,await on a promise that is still pending (only promises that settle without waiting for a timer or event can be awaited))
}

; ----------------------------------------------------------------- globals --

alias js.b.globals {
  noop $js_decl(1,undefined,u)
  noop $js_decl(1,^Na^N,nNaN)
  noop $js_decl(1,^Infinity,nInf)
  var -n %g = $js_newobj
  noop $js_decl(1,global^This,%g)
  hadd jsm GO %g
  js.gfn parseInt 2 js_b_parseint
  js.gfn parseFloat 1 js_b_parsefloat
  js.gfn isNaN 1 js_b_isnan
  js.gfn isFinite 1 js_b_isfinite
  js.gfn setTimeout 2 js_b_settimeout
  js.gfn setInterval 2 js_b_setinterval
  js.gfn clearTimeout 1 js_b_cleartimer
  js.gfn clearInterval 1 js_b_cleartimer
  js.gfn queueMicrotask 1 js_b_queuemicrotask
  js.gfn structuredClone 1 js_b_structuredclone
  js.gfn eval 1 js_b_eval
  js.gfn require 1 js_b_require
  js.gfn encodeURIComponent 1 js_b_encodeuri
  js.gfn decodeURIComponent 1 js_b_decodeuri
  ; Symbol: just enough for [Symbol.iterator] style code
  var -n %sym = $js_mknat(Symbol,1,js_b_symbol)
  noop $js_defhidden(%sym,iterator,siterator)
  noop $js_defhidden(%sym,async^Iterator,sasyncIterator)
  noop $js_defhidden(%sym,to^String^Tag,stoStringTag)
  noop $js_decl(1,^Symbol,%sym)
}

alias js_b_isnan { return $js_bool($iif($js_tonum($js_arg(%jsna,1)) === NaN,1,0)) }
alias js_b_isfinite { return $js_bool($js_isfin($js_tonum($js_arg(%jsna,1)))) }

alias js_b_symbol {
  var -n %n = $calc( $hget(jsm,symn) + 1 )
  hadd jsm symn %n
  return s@@ $+ $js_tostr($js_arg(%jsna,1)) $+ @ $+ %n
}

alias js_b_queuemicrotask {
  noop $js_enqueue(call,$js_arg(%jsna,1))
  return u
}

alias js_b_structuredclone {
  var -n %v = $js_arg(%jsna,1)
  if ($left(%v,1) !=== o) { return %v }
  hadd jsm jsonseen $null
  var -n %s = $js_jsonstr(%v,$null,$null)
  if (%jsc) { return u }
  %jsna = s $+ %s
  return $js_b_jparse
}

alias js_b_encodeuri {
  var -n %t = $js_argtext(%jsna,1)
  return s $+ $js_enc($regsubex(%t,/([^A-Za-z0-9\-_.!~*'()])/g,$js_urlbyte(\1)))
}

alias js_urlbyte {
  if ($1 == $chr(32)) { return % $+ 20 }
  bset -t &jsu 1 $1
  var -n %out = $null
  var -n %i = 1
  while (%i <= $bvar(&jsu,0)) {
    var -n %out = %out $+ % $+ $base($bvar(&jsu,%i),10,16,2)
    inc %i
  }
  bunset &jsu
  return %out
}

alias js_b_decodeuri {
  var -n %t = $js_argtext(%jsna,1)
  var -n %out = $null
  var -n %bytes = $null
  var -n %i = 1
  while (%i <= $len(%t)) {
    var -n %c = $mid(%t,%i,1)
    if (%c === $chr(37)) && ($regex($mid(%t,$calc( %i + 1 ),2),/^[0-9a-fA-F]{2}$/)) {
      var -n %bytes = %bytes $base($mid(%t,$calc( %i + 1 ),2),16,10)
      inc %i 3
      continue
    }
    if (%bytes != $null) {
      var -n %out = %out $+ $js_u8bytes(%bytes)
      var -n %bytes = $null
    }
    var -n %out = %out $+ $js_enc(%c)
    inc %i
  }
  if (%bytes != $null) { var -n %out = %out $+ $js_u8bytes(%bytes) }
  return s $+ %out
}

; UTF-8 byte values (space-separated) -> encoded text
alias js_u8bytes {
  var -n %out = $null
  var -n %n = $numtok($1,32)
  var -n %i = 1
  while (%i <= %n) {
    var -n %u = $js_u8($gettok($1,%i,32),$gettok($1,$calc( %i + 1 ),32),$gettok($1,$calc( %i + 2 ),32),$gettok($1,$calc( %i + 3 ),32))
    var -n %out = %out $+ $js_encch($gettok(%u,1,32))
    inc %i $gettok(%u,2,32)
  }
  return %out
}

; eval(code): runs in the global scope
alias js_b_eval {
  var -n %code = $js_arg(%jsna,1)
  if ($left(%code,1) !=== s) { return %code }
  return $js_evalsrc(t,$js_dec($mid(%code,2)))
}

; lex, parse and run source -> completion value (throws SyntaxError)
alias js_evalsrc {
  if (!$js_lex($1,$2)) { return $js_throw(SyntaxError,$gettok(%jserr,2-,58)) }
  var -n %prog = $js_parse
  if (!%prog) { return $js_throw(SyntaxError,$gettok(%jperr,2-,58)) }
  return $js_runprog(%prog)
}

; require(path): run a file as a module and return module.exports
alias js_b_require {
  var -n %p = $js_argtext(%jsna,1)
  var -n %file = $js_resolve(%p)
  if (!$isfile(%file)) && ($isfile(%file $+ .js)) { var -n %file = %file $+ .js }
  if (!$isfile(%file)) { return $js_throw(Error,Cannot find module ' $+ %p $+ ') }
  var -n %key = $md5(%file)
  if ($hget(jsm,mod. $+ %key)) { return $js_get($v1,exports) }
  if (!$js_lex(f,%file)) { return $js_throw(SyntaxError,$gettok(%jserr,2-,58) in %file) }
  var -n %prog = $js_parse
  if (!%prog) { return $js_throw(SyntaxError,$gettok(%jperr,2-,58) in %file) }
  var -n %module = $js_newobj
  var -n %exports = $js_newobj
  noop $js_put(%module,exports,%exports)
  hadd jsm mod. $+ %key %module
  ; a module runs as a function body: its own scope, var hoisting, this = exports
  var -n %env = $js_newenv(1)
  hadd jse %env $+ :this %exports
  noop $js_decl(%env,module,%module)
  noop $js_decl(%env,exports,%exports)
  noop $js_decl(%env,__filename,s $+ $js_enc(%file))
  noop $js_decl(%env,__dirname,s $+ $js_enc($nofile(%file)))
  noop $js_capture(%env)
  var -n %olddir = $hget(jsm,dir)
  hadd jsm dir $nofile(%file)
  var -n %hv = $hget(jsa,%prog $+ :hv)
  var -n %i = 1
  while (%i <= $numtok(%hv,32)) {
    if ($hget(jse,%env $+ . $+ $gettok(%hv,%i,32)) == $null) { noop $js_decl(%env,$gettok(%hv,%i,32),u) }
    inc %i
  }
  noop $js_hoistfns(%prog,%env)
  noop $js_exlist($hget(jsa,%prog $+ :s),%env)
  hadd jsm dir %olddir
  if (%jsc === x) { return u }
  unset %jsc %jscv %jscl
  return $js_get(%module,exports)
}

; a path relative to the running script's folder
alias js_resolve {
  var -n %p = $replace($1,/,\)
  if ($mid(%p,2,1) == :) || ($left(%p,1) == \) { return %p }
  var -n %dir = $hget(jsm,dir)
  if (%dir == $null) { var -n %dir = $mircdir }
  if ($left(%p,2) == .\) { var -n %p = $mid(%p,3) }
  return %dir $+ %p
}

; ------------------------------------------------------------------ timers --

alias js_b_settimeout { return $js_timer(%jsna,1) }
alias js_b_setinterval { return $js_timer(%jsna,0) }

; $js_timer(args,once) -> timer id
alias js_timer {
  var -n %fn = $js_arg($1,1)
  if (!$js_iscallable(%fn)) { return $js_throw(TypeError,The callback must be a function) }
  var -n %ms = $int($js_tonum($js_arg($1,2)))
  if (%ms !isnum) || (%ms < 1) { var -n %ms = 1 }
  var -n %id = $calc( $hget(jsm,tmid) + 1 )
  hadd jsm tmid %id
  hadd jsm tm. $+ %id %fn $gettok($1,3-,32)
  noop $js_capture(1)
  .timerjs $+ %id -m $iif($2,1,0) %ms js.timerfire %id $2
  return n $+ %id
}

alias js_b_cleartimer {
  var -n %id = $int($js_tonum($js_arg(%jsna,1)))
  if (%id isnum) {
    .timerjs $+ %id off
    hdel jsm tm. $+ %id
  }
  return u
}

alias js.timerfire {
  var -n %t = $hget(jsm,tm. $+ $1)
  if (%t == $null) { return }
  hadd jsm depth 0
  if ($2) { hdel jsm tm. $+ $1 }
  noop $js_call($gettok(%t,1,32),u,$gettok(%t,2-,32))
  js.settle
}

; after running code from outside (timers, events, commands): report an
; uncaught exception and run pending promise jobs
alias js.settle {
  if (%jsc === x) { noop $js_err(Uncaught $js_errtext(%jscv)) }
  unset %jsc %jscv %jscl %jsoc
  noop $js_drain
  unset %jsc %jscv %jscl %jsoc
}

; ----------------------------------------------------------------- console --

alias js.b.console {
  var -n %c = $js_newobj
  noop $js_decl(1,console,%c)
  js.defs %c log:0:js_b_clog info:0:js_b_clog debug:0:js_b_clog warn:0:js_b_cwarn error:0:js_b_cwarn dir:0:js_b_cdir table:0:js_b_clog trace:0:js_b_clog assert:0:js_b_cassert time:0:js_b_ctime timeEnd:0:js_b_ctimeend timeLog:0:js_b_ctimeend count:0:js_b_ccount countReset:0:js_b_ccountreset group:0:js_b_cgroup groupEnd:0:js_b_cgroupend clear:0:js_b_cclear
}

alias js_b_clog {
  noop $js_out($js_fmtargs(%jsna))
  return u
}

alias js_b_cwarn {
  noop $js_err($js_fmtargs(%jsna))
  return u
}

alias js_b_cdir {
  noop $js_out($js_inspect($js_arg(%jsna,1),0,$null))
  return u
}

alias js_b_cassert {
  var -n %args = %jsna
  if ($js_truthy($js_arg(%args,1))) { return u }
  noop $js_err(Assertion failed $+ $iif($gettok(%args,2-,32) != $null,: $js_fmtargs($gettok(%args,2-,32))))
  return u
}

alias js_b_ctime {
  hadd jsm timer. $+ $md5($js_argtext(%jsna,1)) $ticks
  return u
}

alias js_b_ctimeend {
  var -n %label = $iif($js_arg(%jsna,1) === u,default,$js_argtext(%jsna,1))
  var -n %t = $hget(jsm,timer. $+ $md5(%label))
  if (%t == $null) { return u }
  noop $js_out(%label $+ : $calc( $ticks - %t ) $+ ms)
  return u
}

alias js_b_ccount {
  var -n %label = $iif($js_arg(%jsna,1) === u,default,$js_argtext(%jsna,1))
  var -n %k = count. $+ $md5(%label)
  hinc jsm %k
  noop $js_out(%label $+ : $hget(jsm,%k))
  return u
}

alias js_b_ccountreset {
  var -n %label = $iif($js_arg(%jsna,1) === u,default,$js_argtext(%jsna,1))
  hdel jsm count. $+ $md5(%label)
  return u
}

alias js_b_cgroup {
  if (%jsna != $null) { noop $js_out($js_fmtargs(%jsna)) }
  hinc jsm indent 2
  return u
}

alias js_b_cgroupend {
  hdec jsm indent 2
  if ($hget(jsm,indent) < 0) { hadd jsm indent 0 }
  return u
}

alias js_b_cclear { return u }

; console.log formatting: strings as-is, everything else inspected; %s %d
; %i %f %o %O %j in a leading format string
alias js_fmtargs {
  var -n %args = $1
  var -n %n = $numtok(%args,32)
  var -n %out = $null
  var -n %start = 1
  var -n %first = $gettok(%args,1,32)
  if ($left(%first,1) === s) && ($chr(37) isin $js_dec($mid(%first,2))) {
    var -n %f = $js_dec($mid(%first,2))
    var -n %ai = 2
    var -n %res = $null
    var -n %i = 1
    while (%i <= $len(%f)) {
      var -n %c = $mid(%f,%i,1)
      if (%c === $chr(37)) && (%i < $len(%f)) {
        var -n %d = $mid(%f,$calc( %i + 1 ),1)
        if (%d === $chr(37)) { var -n %res = %res $+ $chr(37) | inc %i 2 | continue }
        if ($istokcs(s d i f o O j c,%d,32)) && (%ai <= %n) {
          var -n %a = $gettok(%args,%ai,32)
          inc %ai
          if (%d === s) { var -n %res = %res $+ $iif($left(%a,1) === s,$js_dec($mid(%a,2)),$js_inspect(%a,1,$null)) }
          elseif (%d === d) || (%d === i) { var %x = $js_tonum(%a) | var -n %res = %res $+ $js_numstr($iif(%d === i && $js_isfin(%x),$int(%x),%x)) }
          elseif (%d === f) { var -n %res = %res $+ $js_numstr($js_tonum(%a)) }
          elseif (%d === c) { }
          else { var -n %res = %res $+ $js_inspect(%a,1,$null) }
          inc %i 2
          continue
        }
      }
      var -n %res = %res $+ %c
      inc %i
    }
    var -n %out = $chr(1) $+ %res
    var -n %start = %ai
  }
  var -n %i = %start
  while (%i <= %n) {
    var -n %v = $gettok(%args,%i,32)
    var -n %s = $iif($left(%v,1) === s,$js_dec($mid(%v,2)),$js_inspect(%v,0,$null))
    ; joined with $chr(1) first so empty strings keep their place
    var -n %out = %out $+ $chr(1) $+ %s
    inc %i
  }
  return $replace($mid(%out,2),$chr(1),$chr(32))
}

; util.inspect, following Node's rules: $js_inspect(value,nested) -> text
; (top-level strings print as they are; nested ones are quoted)
alias js_inspect {
  if (!$2) && ($left($1,1) === s) { return $js_dec($mid($1,2)) }
  hadd jsm cdepth 0
  return $js_insp($1,0,0,$null)
}

; $js_insp(value,recurseTimes,indentation,seen ids) - Node's formatValue
alias js_insp {
  var -n %v = $1
  var -n %rt = $2
  var -n %ind = $3
  var -n %ty = $left(%v,1)
  if (%ty === s) { return $js_strquote($js_dec($mid(%v,2))) }
  if (%ty === n) { return $js_numstr($mid(%v,2)) }
  if (%ty === u) { return undefined }
  if (%ty === z) { return null }
  if (%ty === t) { return true }
  if (%ty === f) { return false }
  if (%ty !=== o) { return %v }
  var -n %id = $mid(%v,2)
  if ($istok($4,%id,32)) { return $chr(91) $+ Circular *1 $+ $chr(93) }
  var -n %c = $hget(jso,%id $+ :c)
  var -n %base = $null
  var -n %callable = $js_iscallable(%v)
  if (%callable) {
    var -n %name = $js_dec($mid($hget(jso,%id $+ .name),2))
    if ($hget(jso,%id $+ :cls)) {
      var -n %pc = $hget(jso,%id $+ :p)
      var -n %ext = $null
      if ($hget(jso,%id $+ :derived)) && ($js_iscallable(%pc)) { var -n %ext = $chr(32) $+ extends $js_dec($mid($hget(jso,$mid(%pc,2) $+ .name),2)) }
      var -n %base = $chr(91) $+ class $iif(%name == $null,(anonymous),%name) $+ %ext $+ $chr(93)
    }
    else { var -n %base = $chr(91) $+ Function $+ $iif(%name == $null,$chr(32) $+ (anonymous),: %name) $+ $chr(93) }
    if ($js_ownkeys(%v) == $null) { return %base }
  }
  elseif ($hget(jso,%id $+ :prim)) {
    var -n %pv = $v1
    return $chr(91) $+ $js_typename(%pv) $+ : $js_insp(%pv,%rt,%ind,$4) $+ $chr(93)
  }
  elseif (%c === Error) {
    var -n %s = $js_dec($js_tostr($js_get(%v,stack)))
    if (%s == $null) { var -n %s = $js_dec($js_tostr(%v)) }
    return %s
  }
  elseif (%c === Date) { return $js_dec($mid($js_b_dtoiso_do(%v),2)) }
  elseif (%c === RegExp) { return / $+ $js_dec($hget(jso,%id $+ :src)) $+ / $+ $hget(jso,%id $+ :flags) }
  var -n %isarr = $iif($hget(jso,%id $+ :len) != $null,1,0)
  ; the prefix: a class name, Map(n), Set(n), null prototype
  var -n %prefix = $null
  var -n %proto = $hget(jso,%id $+ :p)
  if (%proto === z) { var -n %prefix = $chr(91) $+ Object: null prototype $+ $chr(93) }
  elseif (!%callable) && (!%isarr) && ($left(%proto,1) === o) && (%proto !=== $hget(jsm,OP)) && (%c !== Map) && (%c !== Set) && (%c !== Promise) {
    var -n %ctor = $hget(jso,$mid(%proto,2) $+ .constructor)
    if ($left(%ctor,1) === o) {
      var -n %cn = $js_dec($mid($hget(jso,$mid(%ctor,2) $+ .name),2))
      if (%cn != $null) && (%cn !=== Object) { var -n %prefix = %cn }
    }
  }
  if (%rt > 2) {
    if (%isarr) { return $chr(91) $+ Array $+ $chr(93) }
    if (%c === Map) || (%c === Set) { return $chr(91) $+ %c $+ $chr(93) }
    return $chr(91) $+ $iif(%prefix != $null && $left(%prefix,1) !== $chr(91),%prefix,Object) $+ $chr(93)
  }
  var -n %rt2 = $calc( %rt + 1 )
  hadd jsm cdepth %rt2
  var -n %seen = $4 %id
  var -n %ind2 = $calc( %ind + 2 )
  var -n %out = $null
  var -n %n = 0
  var -n %allnum = 1
  var -n %extra = 0
  var -n %open = $chr(123)
  var -n %close = $chr(125)
  if (%isarr) {
    var -n %open = $chr(91)
    var -n %close = $chr(93)
    var -n %len = $hget(jso,%id $+ :len)
    var -n %i = 0
    var -n %holes = 0
    while (%i < %len) {
      var -n %x = $hget(jso,%id $+ . $+ %i)
      if (%x == $null) { inc %holes }
      else {
        if (%holes) { var -n %out = %out $+ $chr(1) $+ < $+ %holes empty item $+ $iif(%holes > 1,s) $+ > | inc %n | var -n %holes = 0 | var -n %allnum = 0 }
        if ($left(%x,1) !=== n) { var -n %allnum = 0 }
        var -n %out = %out $+ $chr(1) $+ $js_insp(%x,%rt2,%ind2,%seen)
        inc %n
      }
      if (%n >= 100) && ($calc( %i + 1 ) < %len) { var -n %out = %out $+ $chr(1) $+ ... $calc( %len - %i - 1 ) more item $+ $iif($calc( %len - %i - 1 ) > 1,s) | inc %n | break }
      inc %i
    }
    if (%holes) { var -n %out = %out $+ $chr(1) $+ < $+ %holes empty item $+ $iif(%holes > 1,s) $+ > | inc %n | var -n %allnum = 0 }
  }
  elseif (%c === Map) || (%c === Set) {
    var -n %order = $hget(jso,%id $+ :order)
    var -n %prefix = %c $+ ( $+ $numtok(%order,32) $+ )
    var -n %i = 1
    while (%i <= $numtok(%order,32)) {
      var -n %slot = $gettok(%order,%i,32)
      var -n %k = $js_insp($hget(jso,%id $+ $chr(124) $+ k $+ %slot),%rt2,%ind2,%seen)
      if (%c === Map) { var -n %k = %k => $js_insp($hget(jso,%id $+ $chr(124) $+ v $+ %slot),%rt2,%ind2,%seen) }
      var -n %out = %out $+ $chr(1) $+ %k
      inc %n
      inc %i
    }
  }
  elseif (%c === Promise) {
    var -n %st = $hget(jso,%id $+ :ps)
    var -n %prefix = Promise
    var -n %out = $chr(1) $+ $iif(%st === p,<pending>,$iif(%st === r,<rejected> $+ $chr(32)) $+ $js_insp($hget(jso,%id $+ :pv),%rt2,%ind2,%seen))
    var -n %n = 1
  }
  ; own enumerable properties (for arrays, the non-index ones)
  var -n %keys = $iif(%isarr,$hget(jso,%id $+ :k),$js_ownkeys(%v))
  var -n %i = 1
  while (%i <= $numtok(%keys,32)) {
    var -n %k = $gettok(%keys,%i,32)
    var -n %raw = $hget(jso,%id $+ . $+ %k)
    if (%raw != $null) && ((!%isarr) || (!$regex(%k,/^\d+$/))) {
      if ($left(%raw,1) === g) {
        var -n %gs = $mid(%raw,2)
        var -n %val = $chr(91) $+ $iif($gettok(%gs,1,95),Getter $+ $iif($gettok(%gs,2,95),/Setter),Setter) $+ $chr(93)
      }
      else { var %val = $js_insp(%raw,%rt2,%ind2,%seen) }
      var -n %out = %out $+ $chr(1) $+ $js_inspkey(%k) $+ : %val
      inc %n
      inc %extra
    }
    inc %i
  }
  var -n %out = $mid(%out,2)
  if (%callable) { var -n %prefix = %base }
  if (%prefix != $null) { var -n %open = %prefix %open }
  if (%n == 0) {
    if (%isarr) && (%prefix == $null) { return $chr(91) $+ $chr(93) }
    return %open $+ %close
  }
  ; Node's reduceToSingleString
  var -n %entries = %n
  var -n %grouped = 0
  if (%isarr) && (%n > 6) && (%extra == 0) {
    var -n %g = $js_inspgroup(%out,%ind,%allnum)
    if (%g !=== %out) { var -n %out = %g | var -n %grouped = 1 }
  }
  if (!%grouped) && ($calc( $hget(jsm,cdepth) - %rt2 ) < 3) {
    var -n %start = $calc( %n + %ind + $len(%open) + 10 )
    var -n %total = $calc( %n + %start )
    if ($calc( %total + %n ) <= 80) {
      var -n %fits = 1
      var -n %i = 1
      while (%i <= %n) {
        inc %total $len($gettok(%out,%i,1))
        if (%total > 80) { var -n %fits = 0 | break }
        inc %i
      }
      if (%fits) && ($chr(10) !isin %out) { return %open $replace(%out,$chr(1),$chr(44) $+ $chr(32)) %close }
    }
  }
  var -n %nl = $chr(10) $+ $str($chr(32),%ind)
  return %open $+ %nl $+ $chr(32) $+ $chr(32) $+ $replace(%out,$chr(1),$chr(44) $+ %nl $+ $chr(32) $+ $chr(32)) $+ %nl $+ %close
}

; Node's groupArrayElements: lay long arrays out in aligned columns
; $1 entries separated by $chr(1), $2 indentation, $3 all numbers (pad left)
alias js_inspgroup {
  var -n %list = $1
  var -n %n = $numtok(%list,1)
  var -n %total = 0
  var -n %max = 0
  var -n %i = 1
  while (%i <= %n) {
    var -n %l = $len($gettok(%list,%i,1))
    inc %total $calc( %l + 2 )
    if (%l > %max) { var -n %max = %l }
    inc %i
  }
  var -n %amax = $calc( %max + 2 )
  if ($calc( %amax * 3 + $2 ) >= 80) { return %list }
  if ($calc( %total / %amax ) <= 5) && (%max > 6) { return %list }
  var -n %bias = $sqrt($calc( %amax - %total / %n ))
  var -n %bmax = $calc( %amax - 3 - %bias )
  if (%bmax < 1) { var -n %bmax = 1 }
  var -n %cols = $round($calc( $sqrt($calc( 2.5 * %bmax * %n )) / %bmax ),0)
  var -n %c2 = $int($calc( ( 80 - $2 ) / %amax ))
  if (%c2 < %cols) { var -n %cols = %c2 }
  if (%cols > 12) { var -n %cols = 12 }
  if (%cols <= 1) { return %list }
  ; widest entry in each column
  var -n %widths = $null
  var -n %c = 0
  while (%c < %cols) {
    var -n %w = 0
    var -n %j = $calc( %c + 1 )
    while (%j <= %n) {
      if ($len($gettok(%list,%j,1)) > %w) { var -n %w = $len($gettok(%list,%j,1)) }
      inc %j %cols
    }
    var -n %widths = %widths $calc( %w + 2 )
    inc %c
  }
  var -n %rows = $null
  var -n %i = 0
  while (%i < %n) {
    var -n %last = $iif($calc( %i + %cols ) < %n,$calc( %i + %cols ),%n)
    var -n %row = $null
    var -n %j = %i
    while (%j < %last) {
      var -n %e = $gettok(%list,$calc( %j + 1 ),1)
      var -n %w = $gettok(%widths,$calc( %j - %i + 1 ),32)
      if ($calc( %j + 1 ) < %last) {
        var -n %cell = %e $+ $chr(44) $+ $chr(32)
        var -n %pad = $str($chr(32),$calc( %w - $len(%cell) ))
        var -n %row = %row $+ $iif($3,%pad $+ %cell,%cell $+ %pad)
      }
      elseif ($3) { var -n %row = %row $+ $str($chr(32),$calc( %w - 2 - $len(%e) )) $+ %e }
      else { var -n %row = %row $+ %e }
      inc %j
    }
    var -n %rows = %rows $+ $chr(1) $+ %row
    inc %i %cols
  }
  return $mid(%rows,2)
}

; a string as Node prints it inside objects: 'text', "it's", `it's "x"`
alias js_strquote {
  var -n %t = $1
  var -n %q = $chr(39)
  if ($chr(39) isin %t) {
    if ($chr(34) !isin %t) { var -n %q = $chr(34) }
    elseif ($chr(96) !isin %t) && ($+($chr(36),$chr(123)) !isin %t) { var -n %q = $chr(96) }
  }
  var -n %t = $replacecs(%t,\,\\,$chr(10),\n,$chr(9),\t,$chr(13),\r,$chr(8),\b,$chr(12),\f,$chr(11),\v)
  if (%q === $chr(39)) { var -n %t = $replacecs(%t,$chr(39),\ $+ $chr(39)) }
  return %q $+ %t $+ %q
}

; (kept for callers of the old inspector)
alias js_inspmulti { return $1 $+ $replace($3,$chr(1),$chr(44) $+ $chr(32)) $+ $2 }

alias js_typename {
  var -n %t = $js_typeof($1)
  return $upper($left(%t,1)) $+ $mid(%t,2)
}

; a property key for display: bare if it is a simple identifier
alias js_inspkey {
  var -n %k = $js_dec($js_kdec($1))
  if ($regex(%k,/^[A-Za-z_][A-Za-z_0-9]*$/)) { return %k }
  return $js_strquote(%k)
}

alias js_b_dtoiso_do {
  %jsnt = $1
  return $js_b_dtoiso
}

; ------------------------------------------------------------------- output --

; print text: noop $js_out(text). Always called as an identifier, because a
; command would split the text into words and lose its line breaks. Lines
; are indented by console.group. While tests run, output is collected
; (encoded) in jsm capture instead.
alias js_out {
  var -n %t = $1
  var -n %ind = $str($chr(32),$hget(jsm,indent))
  var -n %n = $numtok(%t,10)
  if (%n == 0) { var -n %n = 1 }
  var -n %i = 1
  while (%i <= %n) {
    var -n %line = %ind $+ $gettok(%t,%i,10)
    if ($hget(jsm,capture)) { hadd jsm capture $hget(jsm,capture) $+ $js_enc($chr(10) $+ %line) }
    else {
      ; echo would swallow leading spaces and tabs: show them as no-break spaces
      var -n %line = $replace(%line,$chr(9),$str($chr(160),4))
      if ($regex(%line,/^( +)/)) { var -n %line = $str($chr(160),$len($regml(1))) $+ $mid(%line,$calc( $len($regml(1)) + 1 )) }
      if (%line == $null) { var -n %line = $chr(160) }
      ; Ctrl+O first: echo would take a leading number for a colour
      var -n %line = $chr(15) $+ %line
      if ($hget(jsm,outcmd)) { $hget(jsm,outcmd) %line }
      else { echo -s %line }
    }
    inc %i
  }
}

; errors and warnings (the same place, for now)
alias js_err { noop $js_out($1) }
