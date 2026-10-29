; ============================================================================
;  msl-js-rt: lexer - JavaScript source -> tokens in the hash table jst
; ============================================================================
;
; Token <i> has:  <i>:t  type   i identifier, k keyword, n number, s string,
;                               q template part, r regex, p punctuator, x end
;                 <i>:v  value  identifier name, keyword, value token (n/s),
;                               punctuator name (lp rp lb rb add aadd ...)
;                 <i>:e  identifier name case-escaped for hash keys
;                 <i>:k  template part kind: f (whole) h (head) m (middle) t (tail)
;                 <i>:f  regex flags
;                 <i>:nl 1 if a line break comes before the token
;                 <i>:ln line number
;
; Punctuators are named so that the parser never has to spell (, |, { or %
; in mSL, where they mean something else.

alias js.lexinit {
  if ($hget(jsm,lexready)) { return }
  ; codes:name, codes joined by dots
  var -n %p = 123:lb 125:rb 40:lp 41:rp 91:ls 93:rs 59:semi 44:comma 60:lt 62:gt 43:add 45:sub 42:mul 47:div 37:mod 38:band 124:bor 94:bxor 33:not 126:bnot 63:qm 58:colon 61:asg 46:dot 64:at
  var -n %p = %p 61.62:arrow 61.61:eq 33.61:ne 60.61:le 62.61:ge 38.38:and 124.124:or 63.63:nc 63.46:optc 43.43:inc 45.45:dec 43.61:aadd 45.61:asub 42.61:amul 47.61:adiv 37.61:amod 38.61:aband 124.61:abor 94.61:abxor 42.42:exp 60.60:shl 62.62:shr
  var -n %p = %p 61.61.61:seq 33.61.61:sne 42.42.61:aexp 60.60.61:ashl 62.62.61:ashr 62.62.62:ushr 46.46.46:ellip 38.38.61:aand 124.124.61:aor 63.63.61:anc 62.62.62.61:aushr
  var -n %n = $numtok(%p,32)
  var -n %i = 1
  while (%i <= %n) {
    var -n %pair = $gettok(%p,%i,32)
    var -n %codes = $gettok(%pair,1,58)
    var -n %s = $null
    var -n %j = 1
    while (%j <= $numtok(%codes,46)) {
      var -n %s = %s $+ $chr($gettok(%codes,%j,46))
      inc %j
    }
    hadd jsm p. $+ %s $gettok(%pair,2,58)
    inc %i
  }
  hadd jsm kw break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof new return super switch this throw try typeof var void while with yield null true false
  hadd jsm lexready 1
}

; decode one UTF-8 sequence: $js_u8(b1,b2,b3,b4) -> "codepoint length"
alias js_u8 {
  var -n %b = $1
  if (%b < 128) { return %b 1 }
  if (%b >= 240) { return $calc( $and(%b,7) * 262144 + $and($2,63) * 4096 + $and($3,63) * 64 + $and($4,63) ) 4 }
  if (%b >= 224) { return $calc( $and(%b,15) * 4096 + $and($2,63) * 64 + $and($3,63) ) 3 }
  if (%b >= 192) { return $calc( $and(%b,31) * 64 + $and($2,63) ) 2 }
  return 65533 1
}

; one character as encoded string text
alias js_encch {
  if ($1 == 32) { return $+($chr(1),b) }
  if ($1 == 10) { return $+($chr(1),n) }
  if ($1 == 13) { return $+($chr(1),r) }
  if ($1 == 9) { return $+($chr(1),t) }
  if ($1 == 11) { return $+($chr(1),v) }
  if ($1 == 12) { return $+($chr(1),f) }
  if ($1 == 1) { return $+($chr(1),a) }
  if ($1 == 2) { return $+($chr(1),c) }
  if ($1 == 0) { return $null }
  return $chr($1)
}

; tokenise: $js_lex(f,path) or $js_lex(t,source text) -> token count, 0 on error
; (a syntax error leaves its message in %jserr)
alias js_lex {
  js.lexinit
  if ($hget(jst)) { hfree jst }
  hmake jst 2000
  unset %jserr
  ; bset/bread only overwrite: clear what an earlier, longer source left
  bunset &jssrc
  if ($1 === f) {
    if (!$isfile($2)) { %jserr = Cannot find file $2 | return 0 }
    bread $qt($2) 0 $file($2).size &jssrc
  }
  else { bset -t &jssrc 1 $2 }
  var -n %n = $bvar(&jssrc,0)
  var -n %i = 1
  if ($bvar(&jssrc,1-3) == 239 187 191) { var -n %i = 4 }
  ; #! line
  if ($bvar(&jssrc,%i) == 35) && ($bvar(&jssrc,$calc( %i + 1 )) == 33) {
    while (%i <= %n) && ($bvar(&jssrc,%i) != 10) { inc %i }
  }
  var -n %t = 0
  var -n %nl = 0
  var -n %line = 1
  var -n %pt = $null
  var -n %pv = $null
  var -n %bd = 0
  var -n %tpl = $null
  var -n %kw = $hget(jsm,kw)
  while (%i <= %n) {
    var -n %c = $bvar(&jssrc,%i)
    ; whitespace and line breaks
    if (%c == 10) { var -n %nl = 1 | inc %line | inc %i | continue }
    if (%c == 32) || (%c == 9) || (%c == 13) || (%c == 11) || (%c == 12) { inc %i | continue }
    if (%c == 194) && ($bvar(&jssrc,$calc( %i + 1 )) == 160) { inc %i 2 | continue }
    ; comments
    if (%c == 47) {
      var -n %c2 = $bvar(&jssrc,$calc( %i + 1 ))
      if (%c2 == 47) {
        while (%i <= %n) && ($bvar(&jssrc,%i) != 10) { inc %i }
        continue
      }
      if (%c2 == 42) {
        inc %i 2
        while (%i <= %n) {
          var -n %cc = $bvar(&jssrc,%i)
          if (%cc == 10) { var -n %nl = 1 | inc %line }
          if (%cc == 42) && ($bvar(&jssrc,$calc( %i + 1 )) == 47) { inc %i 2 | break }
          inc %i
        }
        continue
      }
    }
    inc %t
    hadd jst %t $+ :nl %nl
    hadd jst %t $+ :ln %line
    var -n %nl = 0
    ; template continuation after ${ ... }
    if (%c == 125) && (%tpl != $null) && ($gettok(%tpl,-1,32) == %bd) {
      var -n %tpl = $deltok(%tpl,-1,32)
      var -n %r = $js_lexquasi(%i,%n,m,%t,%line)
      if (!%r) { return 0 }
      var -n %i = $gettok(%r,1,32)
      var -n %line = $gettok(%r,2,32)
      if ($gettok(%r,3,32) === h) { var -n %tpl = %tpl %bd }
      var -n %pt = q
      continue
    }
    ; identifiers and keywords (# for private names)
    if ($js_lexidstart(%c)) || ((%c == 35) && ($js_lexidstart($bvar(&jssrc,$calc( %i + 1 ))))) {
      var -n %name = $null
      if (%c == 35) { var -n %name = $chr(35) | inc %i }
      while (%i <= %n) {
        var -n %c = $bvar(&jssrc,%i)
        if (%c >= 128) {
          var -n %u = $js_u8(%c,$bvar(&jssrc,$calc( %i + 1 )),$bvar(&jssrc,$calc( %i + 2 )),$bvar(&jssrc,$calc( %i + 3 )))
          var -n %name = %name $+ $chr($gettok(%u,1,32))
          inc %i $gettok(%u,2,32)
          continue
        }
        if (!$js_lexidpart(%c)) { break }
        var -n %name = %name $+ $chr(%c)
        inc %i
      }
      if ($istokcs(%kw,%name,32)) { hadd jst %t $+ :t k }
      else {
        hadd jst %t $+ :t i
        hadd jst %t $+ :e $js_kenc(%name)
      }
      hadd jst %t $+ :v %name
      var -n %pt = $hget(jst,%t $+ :t)
      var -n %pv = %name
      continue
    }
    ; numbers
    if ($js_lexdigit(%c)) || ((%c == 46) && ($js_lexdigit($bvar(&jssrc,$calc( %i + 1 ))))) {
      var -n %num = $null
      var -n %c2 = $bvar(&jssrc,$calc( %i + 1 ))
      if (%c == 48) && ($istok(120 88 111 79 98 66,%c2,32)) {
        var -n %radix = $iif(%c2 == 120 || %c2 == 88,16,$iif(%c2 == 111 || %c2 == 79,8,2))
        inc %i 2
        while (%i <= %n) && ($js_lexidpart($bvar(&jssrc,%i))) {
          if ($bvar(&jssrc,%i) != 95) { var -n %num = %num $+ $chr($bvar(&jssrc,%i)) }
          inc %i
        }
        if ($right(%num,1) === n) { var -n %num = $left(%num,-1) }
        var -n %num = $base(%num,%radix,10)
      }
      else {
        while (%i <= %n) {
          var -n %c = $bvar(&jssrc,%i)
          if ($js_lexdigit(%c)) || (%c == 46) { var -n %num = %num $+ $chr(%c) | inc %i | continue }
          if (%c == 95) { inc %i | continue }
          if (%c == 101) || (%c == 69) {
            var -n %num = %num $+ e
            inc %i
            var -n %c = $bvar(&jssrc,%i)
            if (%c == 43) || (%c == 45) { var -n %num = %num $+ $chr(%c) | inc %i }
            continue
          }
          if (%c == 110) { inc %i }
          break
        }
        var -n %num = $js_parsedec(%num)
      }
      hadd jst %t $+ :t n
      hadd jst %t $+ :v $js_numtok(%num)
      var -n %pt = n
      continue
    }
    ; strings
    if (%c == 34) || (%c == 39) {
      var -n %r = $js_lexstr(%i,%n,%c,%line)
      if (!%r) { return 0 }
      hadd jst %t $+ :t s
      hadd jst %t $+ :v $gettok(%r,3,32)
      var -n %i = $gettok(%r,1,32)
      var -n %line = $gettok(%r,2,32)
      var -n %pt = s
      continue
    }
    ; template literals
    if (%c == 96) {
      var -n %r = $js_lexquasi(%i,%n,f,%t,%line)
      if (!%r) { return 0 }
      var -n %i = $gettok(%r,1,32)
      var -n %line = $gettok(%r,2,32)
      if ($gettok(%r,3,32) === h) { var -n %tpl = %tpl %bd }
      var -n %pt = q
      continue
    }
    ; regular expression literals
    if (%c == 47) && ($js_lexreok(%pt,%pv)) {
      var -n %r = $js_lexregex(%i,%n,%t,%line)
      if (!%r) { return 0 }
      var -n %i = %r
      var -n %pt = r
      continue
    }
    ; punctuators: longest match first
    var -n %s1 = $chr(%c)
    var -n %s2 = %s1 $+ $chr($bvar(&jssrc,$calc( %i + 1 )))
    var -n %s3 = %s2 $+ $chr($bvar(&jssrc,$calc( %i + 2 )))
    var -n %s4 = %s3 $+ $chr($bvar(&jssrc,$calc( %i + 3 )))
    var -n %name = $null
    var -n %len = 0
    if ($calc( %i + 3 ) <= %n) && ($hget(jsm,p. $+ %s4)) { var -n %name = $hget(jsm,p. $+ %s4) | var -n %len = 4 }
    elseif ($calc( %i + 2 ) <= %n) && ($hget(jsm,p. $+ %s3)) { var -n %name = $hget(jsm,p. $+ %s3) | var -n %len = 3 }
    elseif ($calc( %i + 1 ) <= %n) && ($hget(jsm,p. $+ %s2)) { var -n %name = $hget(jsm,p. $+ %s2) | var -n %len = 2 }
    elseif ($hget(jsm,p. $+ %s1)) { var -n %name = $hget(jsm,p. $+ %s1) | var -n %len = 1 }
    if (%name === optc) && ($js_lexdigit($bvar(&jssrc,$calc( %i + 2 )))) { var -n %name = qm | var -n %len = 1 }
    if (!%len) {
      %jserr = SyntaxError: Unexpected character ' $+ $chr(%c) $+ ' (line %line $+ )
      return 0
    }
    if (%name === lb) { inc %bd }
    if (%name === rb) { dec %bd }
    hadd jst %t $+ :t p
    hadd jst %t $+ :v %name
    inc %i %len
    var -n %pt = p
    var -n %pv = %name
  }
  inc %t
  hadd jst %t $+ :t x
  hadd jst %t $+ :v $null
  hadd jst %t $+ :nl 1
  hadd jst %t $+ :ln %line
  hadd jst count %t
  return %t
}

alias js_lexidstart {
  var -n %c = $1
  if (%c >= 97) && (%c <= 122) { return 1 }
  if (%c >= 65) && (%c <= 90) { return 1 }
  if (%c == 95) || (%c == 36) || (%c >= 128) { return 1 }
  return 0
}

alias js_lexidpart {
  var -n %c = $1
  if ($js_lexidstart(%c)) { return 1 }
  if (%c >= 48) && (%c <= 57) { return 1 }
  return 0
}

alias js_lexdigit { return $iif($1 >= 48 && $1 <= 57,1,0) }

; can a / here start a regex? (after an operator or keyword, not a value)
alias js_lexreok {
  if ($1 == $null) { return 1 }
  if ($1 === p) { return $iif($istok(rp rs,$2,32),0,1) }
  if ($1 === k) { return $iif($istok(this super null true false,$2,32),0,1) }
  return 0
}

; read an escape sequence after the backslash at %i: -> "newindex lines encodedtext"
alias js_lexesc {
  var -n %i = $1
  var -n %c = $bvar(&jssrc,%i)
  if (%c == 110) { return $calc( %i + 1 ) 0 $js_encch(10) }
  if (%c == 116) { return $calc( %i + 1 ) 0 $js_encch(9) }
  if (%c == 114) { return $calc( %i + 1 ) 0 $js_encch(13) }
  if (%c == 98) { return $calc( %i + 1 ) 0 $chr(8) }
  if (%c == 102) { return $calc( %i + 1 ) 0 $js_encch(12) }
  if (%c == 118) { return $calc( %i + 1 ) 0 $js_encch(11) }
  if (%c == 48) && (!$js_lexdigit($bvar(&jssrc,$calc( %i + 1 )))) { return $calc( %i + 1 ) 0 $null }
  if (%c == 10) { return $calc( %i + 1 ) 1 $null }
  if (%c == 13) {
    if ($bvar(&jssrc,$calc( %i + 1 )) == 10) { return $calc( %i + 2 ) 1 $null }
    return $calc( %i + 1 ) 0 $null
  }
  if (%c == 120) {
    var -n %h = $chr($bvar(&jssrc,$calc( %i + 1 ))) $+ $chr($bvar(&jssrc,$calc( %i + 2 )))
    return $calc( %i + 3 ) 0 $js_encch($base(%h,16,10))
  }
  if (%c == 117) {
    if ($bvar(&jssrc,$calc( %i + 1 )) == 123) {
      var -n %j = $calc( %i + 2 )
      var -n %h = $null
      while ($bvar(&jssrc,%j) != 125) && (%j <= $bvar(&jssrc,0)) {
        var -n %h = %h $+ $chr($bvar(&jssrc,%j))
        inc %j
      }
      return $calc( %j + 1 ) 0 $js_encch($base(%h,16,10))
    }
    var -n %h = $null
    var -n %j = 1
    while (%j <= 4) {
      var -n %h = %h $+ $chr($bvar(&jssrc,$calc( %i + %j )))
      inc %j
    }
    var -n %cp = $base(%h,16,10)
    ; a surrogate pair 😀 becomes one character
    if (%cp >= 55296) && (%cp <= 56319) && ($bvar(&jssrc,$calc( %i + 5 )) == 92) && ($bvar(&jssrc,$calc( %i + 6 )) == 117) {
      var -n %h2 = $null
      var -n %j = 7
      while (%j <= 10) {
        var -n %h2 = %h2 $+ $chr($bvar(&jssrc,$calc( %i + %j )))
        inc %j
      }
      var -n %lo = $base(%h2,16,10)
      if (%lo >= 56320) && (%lo <= 57343) {
        return $calc( %i + 11 ) 0 $js_encch($calc( ( %cp - 55296 ) * 1024 + ( %lo - 56320 ) + 65536 ))
      }
    }
    return $calc( %i + 5 ) 0 $js_encch(%cp)
  }
  var -n %u = $js_u8(%c,$bvar(&jssrc,$calc( %i + 1 )),$bvar(&jssrc,$calc( %i + 2 )),$bvar(&jssrc,$calc( %i + 3 )))
  return $calc( %i + $gettok(%u,2,32) ) 0 $js_encch($gettok(%u,1,32))
}

; string literal starting at %i (the quote): -> "endindex line s<value>"
alias js_lexstr {
  var -n %i = $calc( $1 + 1 )
  var -n %n = $2
  var -n %q = $3
  var -n %line = $4
  var -n %s = $null
  while (%i <= %n) {
    var -n %c = $bvar(&jssrc,%i)
    if (%c == %q) { return $calc( %i + 1 ) %line s $+ %s }
    if (%c == 10) { %jserr = SyntaxError: Unterminated string (line %line $+ ) | return 0 }
    if (%c == 92) {
      var -n %e = $js_lexesc($calc( %i + 1 ))
      var -n %i = $gettok(%e,1,32)
      inc %line $gettok(%e,2,32)
      var -n %s = %s $+ $gettok(%e,3,32)
      continue
    }
    if (%c >= 128) {
      var -n %u = $js_u8(%c,$bvar(&jssrc,$calc( %i + 1 )),$bvar(&jssrc,$calc( %i + 2 )),$bvar(&jssrc,$calc( %i + 3 )))
      var -n %s = %s $+ $chr($gettok(%u,1,32))
      inc %i $gettok(%u,2,32)
      continue
    }
    var -n %s = %s $+ $js_encch(%c)
    inc %i
  }
  %jserr = SyntaxError: Unterminated string (line %line $+ )
  return 0
}

; template text from just after ` or } up to ` or ${, as token %t
; $4 kind of start: f (after `) or m (after }) -> "endindex line h|t"
alias js_lexquasi {
  var -n %i = $calc( $1 + 1 )
  var -n %n = $2
  var -n %start = $3
  var -n %t = $4
  var -n %line = $5
  var -n %s = $null
  while (%i <= %n) {
    var -n %c = $bvar(&jssrc,%i)
    if (%c == 96) {
      hadd jst %t $+ :t q
      hadd jst %t $+ :k $iif(%start === f,f,t)
      hadd jst %t $+ :v s $+ %s
      return $calc( %i + 1 ) %line t
    }
    if (%c == 36) && ($bvar(&jssrc,$calc( %i + 1 )) == 123) {
      hadd jst %t $+ :t q
      hadd jst %t $+ :k $iif(%start === f,h,m)
      hadd jst %t $+ :v s $+ %s
      return $calc( %i + 2 ) %line h
    }
    if (%c == 92) {
      var -n %e = $js_lexesc($calc( %i + 1 ))
      var -n %i = $gettok(%e,1,32)
      inc %line $gettok(%e,2,32)
      var -n %s = %s $+ $gettok(%e,3,32)
      continue
    }
    if (%c == 10) { inc %line }
    if (%c == 13) { inc %i | continue }
    if (%c >= 128) {
      var -n %u = $js_u8(%c,$bvar(&jssrc,$calc( %i + 1 )),$bvar(&jssrc,$calc( %i + 2 )),$bvar(&jssrc,$calc( %i + 3 )))
      var -n %s = %s $+ $chr($gettok(%u,1,32))
      inc %i $gettok(%u,2,32)
      continue
    }
    var -n %s = %s $+ $js_encch(%c)
    inc %i
  }
  %jserr = SyntaxError: Unterminated template literal (line %line $+ )
  return 0
}

; regex literal at %i as token %t -> end index
alias js_lexregex {
  var -n %i = $calc( $1 + 1 )
  var -n %n = $2
  var -n %t = $3
  var -n %s = $null
  var -n %class = 0
  while (%i <= %n) {
    var -n %c = $bvar(&jssrc,%i)
    if (%c == 10) { %jserr = SyntaxError: Unterminated regular expression (line $4 $+ ) | return 0 }
    if (%c == 92) {
      var -n %s = %s $+ $js_encch(92) $+ $js_encch($bvar(&jssrc,$calc( %i + 1 )))
      inc %i 2
      continue
    }
    if (%c == 91) { var -n %class = 1 }
    if (%c == 93) { var -n %class = 0 }
    if (%c == 47) && (!%class) { break }
    if (%c >= 128) {
      var -n %u = $js_u8(%c,$bvar(&jssrc,$calc( %i + 1 )),$bvar(&jssrc,$calc( %i + 2 )),$bvar(&jssrc,$calc( %i + 3 )))
      var -n %s = %s $+ $chr($gettok(%u,1,32))
      inc %i $gettok(%u,2,32)
      continue
    }
    var -n %s = %s $+ $js_encch(%c)
    inc %i
  }
  inc %i
  var -n %f = $null
  while (%i <= %n) && ($js_lexidpart($bvar(&jssrc,%i))) {
    var -n %f = %f $+ $chr($bvar(&jssrc,%i))
    inc %i
  }
  hadd jst %t $+ :t r
  hadd jst %t $+ :v s $+ %s
  hadd jst %t $+ :f %f
  return %i
}
