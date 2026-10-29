// numbers, strings, operators
console.log(1 + 2 * 3, (1 + 2) * 3, 7 % 3, -7 % 3, 2 ** 10, 10 / 4);
console.log("a" + 1 + 2, 1 + 2 + "a", "5" * "2", "5" - 2, +"42", -"3");
console.log(typeof 1, typeof "s", typeof true, typeof undefined, typeof null, typeof {}, typeof [], typeof (() => 1));
console.log(1 / 0, -1 / 0, 0 / 0, isNaN(NaN), Number.isInteger(5), Number.isInteger(5.5));
console.log(5 > 3, "b" > "a", "B" < "a", 2 == "2", 2 === "2", null == undefined, null === undefined, NaN == NaN);
console.log(0 || "default", 1 && "yes", null ?? "fallback", 0 ?? "zero kept", !"", !!"x");
console.log(5 & 3, 5 | 3, 5 ^ 3, ~5, 1 << 4, -16 >> 2, -16 >>> 28);
let x = 5;
x += 3; x -= 1; x *= 2; x /= 7; x **= 3;
console.log(x);
let y = null;
y ??= "set"; y ||= "not used"; y &&= y + "!";
console.log(y);
let i = 0;
console.log(i++, i, ++i, i--, --i);
const s = `multi
line ${1 + 1} and ${"nested " + `${2 * 3}`}`;
console.log(s);
console.log(typeof undeclaredThing, void 0);
const o = { a: { b: { c: 42 } } };
console.log(o?.a?.b?.c, o?.x?.y?.z, o.missing?.deep.chain, o.a?.["b"].c);
console.log((1, 2, 3), [] + [], [1, 2] + "", String(null), String([1, [2, 3]]));
console.log(0.5 + 0.25, 1e3, 1.5e-3, 0x1f, 0o17, 0b101, 1_000_000);
console.log(parseInt("42px"), parseInt("ff", 16), parseFloat("3.25abc"), Number("12.5"), Number("abc"));
