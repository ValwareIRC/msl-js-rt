// control flow and exceptions
function grade(n) {
  if (n >= 90) return "A";
  else if (n >= 80) return "B";
  else return "C";
}
console.log(grade(95), grade(85), grade(10));

function sw(x) {
  const out = [];
  switch (x) {
    case 1: out.push("one");
    case 2: out.push("two"); break;
    case "3": out.push("string three"); break;
    default: out.push("default");
  }
  return out.join(",");
}
console.log(sw(1), sw(2), sw("3"), sw(3));

let w = 0, iters = 0;
while (true) { iters++; if (++w > 5) break; if (w % 2) continue; }
do { iters++; } while (false);
console.log(w, iters);

const found = [];
outer: for (let i = 0; i < 4; i++) {
  for (let j = 0; j < 4; j++) {
    if (j === 2) continue outer;
    if (i === 3) break outer;
    found.push(`${i}${j}`);
  }
}
console.log(found.join(" "));

function tryFinally() {
  const log = [];
  try {
    log.push("try");
    throw new RangeError("bad range");
  } catch (e) {
    log.push(`caught ${e.name}: ${e.message}`);
    return log;
  } finally {
    log.push("finally");
  }
}
console.log(tryFinally());

function finallyWins() {
  try { return "from try"; } finally { console.log("finally runs before return"); }
}
console.log(finallyWins());

try {
  null.prop;
} catch (e) {
  console.log(e instanceof TypeError, e.message);
}
try {
  undefinedFunction();
} catch (e) {
  console.log(e.name, e.message);
}
try {
  const k = 1;
  k = 2;
} catch (e) {
  console.log(e.name, e.message);
}
try {
  throw { custom: true };
} catch ({ custom }) {
  console.log("destructured catch", custom);
}
try { try { throw new Error("inner"); } finally { console.log("inner finally"); } } catch (e) { console.log("outer caught", e.message); }

const results = [];
for (const v of [1, 2, 3, 4, 5, 6]) {
  if (v === 2) continue;
  if (v === 5) break;
  results.push(v);
}
console.log(results);
let n = 0;
for (;;) { if (n++ >= 3) break; }
console.log(n);
const obj = { a: 1, b: 2 };
for (const k in obj) console.log(k, obj[k]);
console.log([1, 2, 3].map(x => { if (x === 2) return "two"; return x; }));
