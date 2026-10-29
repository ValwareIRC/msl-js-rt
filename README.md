# msl-js-rt

A JavaScript interpreter written entirely in mIRC script (mSL). Load it into
[mslrt](https://github.com/ValwareIRC/msl-runtime) or mIRC and you can run
JavaScript, write IRC bots in it, and extend mIRC script with JavaScript
functions that mSL can call as ordinary aliases and identifiers.

> Note: this project was written with Claude Opus 5.5, Anthropic's AI model.

```
/js console.log([1, 2, 3].map(n => n * 2))      [ 2, 4, 6 ]
/js 6 * 7                                        42
//echo -a $js("mIRC".split("").reverse().join(""))   CRIm
/jsload bot.js
```

## Getting started

With mslrt:

```powershell
.\run.ps1 examples\hello.js -Exit          # run a file and quit
.\run.ps1 examples\bot.js -Server irc.libera.chat:+6697 -Nick mybot -Join "#test"
mslrt js.mrc                               # then type /js ... or /jsload ...
```

With mIRC: `/load -rs js.mrc` (it loads the rest from `src\`), then use
`/js` and `/jsload`.

## From mIRC script

| | |
|---|---|
| `/js <code>` | Run JavaScript. The value of a bare expression is printed. `/js -q` stays quiet. |
| `$js(<code>)` | Run JavaScript and return its value as text. |
| `/jsload <file.js>` | Run a file. `require()` inside it resolves paths relative to it. |
| `/jscall <fn> [words]` | Call a global JavaScript function with text arguments. |
| `$jscall(fn,arg,...)` | The same, returning the result. |
| `/jsreset` | Forget all JavaScript state and start again. |

`console.log` and friends print to the status window, formatted the way
Node.js formats them.

## From JavaScript: the `mirc` object

```js
mirc.on("text", "!hello*", e => e.reply(`Hello, ${e.nick}!`));
mirc.alias("slugify", text => text.toLowerCase().replace(/\W+/g, "-"));
mirc.cmd("join #mychannel");
console.log(mirc.eval("$me on $network"));
```

| | |
|---|---|
| `mirc.on(event, [match], handler)` | Handle an event. `match` is a wildcard (`"!hi*"`), a RegExp or a function; for `signal` it matches the signal's name. Returning `false` halts mIRC's default handling where mIRC allows it. |
| `mirc.off(event, [handler])` | Remove one handler, or all of them for the event. |
| `mirc.alias(name, fn)` | Define `/name` and `$name(...)` in mSL, calling `fn`. Command calls pass the words as arguments; identifier calls pass the comma-separated arguments (up to 9). The return value is the identifier's value. |
| `mirc.unalias(name)` | Remove it again. |
| `mirc.cmd(line)` | Run an mSL command as written (`$` and `%` are not evaluated). An mSL error becomes a catchable JavaScript `Error`. |
| `mirc.exec(line)` | Run an mSL command, evaluating `$identifiers` and `%variables` first, like `//` in the editbox. |
| `mirc.eval(text)` | Evaluate `$identifiers` and `%variables` in text and return the result. |
| `mirc.say(target, text)`, `mirc.notice(target, text)`, `mirc.action(target, text)` | Talk on IRC. |
| `mirc.echo(...values)` | Print, like `console.log`. |
| `mirc.getVar(name)`, `mirc.setVar(name, value)`, `mirc.unsetVar(name)` | Global `%variables`. |
| `mirc.hget(table, item)`, `mirc.hadd(table, item, value)`, `mirc.hdel(table, item)` | Hash tables. |
| `mirc.signal(name, ...args)` | Fire an mSL `on SIGNAL` event (and JavaScript `signal` handlers). |
| `mirc.version` | The interpreter and runtime versions. |

Events: `text`, `action`, `notice`, `join`, `part`, `quit`, `nick`, `kick`,
`topic`, `invite`, `mode`, `connect`, `disconnect`, `input`, `exit`, `raw`,
`ctcp` and `signal`. The event object has `type`, `text`, `args` (the words),
`nick`, `address`, `chan`, `target`, `me`, `network`, `cid` and, where they
apply, `knick`, `newnick`, `numeric` and `signal`, plus `e.reply(text)`, which
answers in the channel or query the event came from.

## The language

Most of modern JavaScript runs:

- `let`/`const`/`var` with block scope and hoisting, closures (each `for (let ...)`
  iteration gets its own binding), default, rest and destructured parameters,
  arrow functions with lexical `this`, `arguments`
- classes with `extends`, `super`, static members, instance and static fields,
  `#private` fields and methods, getters and setters, `new.target`, extending
  built-ins such as `Error` and `Array`
- destructuring with defaults and rest, spread in arrays, objects and calls,
  computed keys, shorthand properties and methods, optional chaining `?.`,
  nullish coalescing `??`, logical assignment `&&=` `||=` `??=`, `**`
- template literals and tagged templates, regular expression literals
- `if`, `switch`, every loop including `for...in`, `for...of` and labelled
  `break`/`continue`, `try`/`catch`/`finally` with optional catch binding
- `async` functions and `await`, promises and a microtask queue, timers
- `require()` and `module.exports` for splitting code across files, and `eval`

Built-ins: `Object`, `Function` (`call`, `apply`, `bind`), `Array` (the usual
methods including `flat`, `flatMap`, `findLast`, `at`, `toSorted`), `String`
(including `padStart`, `replaceAll`, `matchAll`, `split` with a regex), `Number`,
`Boolean`, `Math`, `JSON` (with indentation, `toJSON`, revivers), `Map`, `Set`,
`WeakMap`, `WeakSet`, `Date`, `RegExp`, `Promise` (`all`, `allSettled`, `race`,
`any`), the `Error` types, `Symbol.iterator`, `console` (`log`, `warn`, `error`,
`dir`, `table`, `assert`, `count`, `time`, `group`), `setTimeout`,
`setInterval`, `queueMicrotask`, `structuredClone`, `encodeURIComponent`,
`decodeURIComponent`, `parseInt`, `parseFloat`, `globalThis`.

## Differences from Node.js

The interpreter runs on mSL's own arithmetic and data structures, and that
shows in a few places:

- **Numbers** go through `$calc`, which keeps 6 decimal places: `0.1 + 0.2` is
  `0.3` here (it is `0.30000000000000004` in Node), and `1 / 3` is `0.333333`.
  Integers are exact up to 2^53.
- **Call depth** is limited to about 100 nested JavaScript calls, because mSL
  allows 1000 nested aliases. Deeper recursion throws a catchable
  `RangeError: Maximum call stack size exceeded`.
- **`await`** runs pending promise jobs and then takes the result. Awaiting a
  promise that settles through the job queue works; awaiting one that waits
  for a timer or an IRC event throws. An `async` function runs to completion
  when called rather than pausing, so code placed *after* the call can run
  in a different order than in Node.
- **Generators** (`function*`, `yield`) and ES modules (`import`/`export`) are
  not supported; use `require`. Iterators: `keys()`, `values()` and
  `entries()` return arrays, and objects with `next()` or an `iterator()`
  method can be spread and used with `for...of`.
- **Regular expressions** use mIRC's PCRE-style engine (`i`, `m`, `s`, `g` and
  `y` flags). Sticky and unicode matching are approximate.
- **Speed**: it is an interpreter written in an interpreted language.
  Expect thousands of operations per second, not millions; that is plenty
  for bots, aliases and scripting, not for heavy computation.
- **Memory**: objects are never garbage-collected. Function scopes that no
  closure keeps are freed when they return.
- mSL splits identifier arguments at commas, so text with commas (such as
  JSON) is best passed to `$js()` and JavaScript aliases through a
  `%variable`.

## How it works

`src\lexer.mrc` turns source into tokens, `src\parser.mrc` builds a syntax
tree (recursive descent with precedence climbing), and `src\eval.mrc` walks
it. Values are short tokens with no spaces in them (`n42`, `shello`, `o17`
for object 17, `u` for undefined), which lets lists of values live in plain
mSL strings. Objects, scopes and syntax trees live in hash tables; strings are
encoded so that spaces and line breaks survive mSL's word splitting, and
property names are case-escaped because hash tables ignore case.
`src\builtins.mrc` holds the standard library and `src\bridge.mrc` the
`mirc` object and the commands above.

## Tests

```powershell
.\tests\run.ps1             # every tests\*.js
.\tests\run.ps1 classes     # one of them
.\tests\make-expected.ps1   # regenerate the expected output with Node.js
```

Each test's expected output is what Node.js prints for the same file, so the
suite checks real JavaScript behaviour (including how `console.log` lays
things out). `tests\hooks.js` exercises the `mirc` object and has
hand-written expectations.
