; ============================================================================
;  msl-js-rt - a JavaScript interpreter written in mIRC script
; ============================================================================
;
; Load this file; it loads the interpreter from the src folder next to it.
;
;   /js console.log("hello")         run JavaScript
;   /js 1 + 2                        prints 3
;   //echo -a $js([1,2,3].map(x => x * 2).join())
;   /jsload bot.js                   run a file
;
; See README.md for the mirc object that lets JavaScript handle IRC events,
; define aliases and run commands.

on *:LOAD: { js.boot }
on *:START: { js.boot }

alias js.boot {
  var -n %dir = $scriptdir $+ src\
  var -n %files = core lexer parser eval builtins bridge
  var -n %i = 1
  while (%i <= $numtok(%files,32)) {
    var -n %f = %dir $+ $gettok(%files,%i,32) $+ .mrc
    if (!$script(%f)) { .load -rs $qt(%f) }
    inc %i
  }
  js.init
}
