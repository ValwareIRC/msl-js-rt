// JSON, Math, Number, Map, Set, Date
const data = { name: "msl", tags: ["js", "irc"], nested: { ok: true, n: null }, skip: undefined, fn() {} };
const json = JSON.stringify(data);
console.log(json);
console.log(JSON.stringify(data, null, 2));
const back = JSON.parse('{"a":[1,2,{"b":"c"}],"d":-1.5,"e":true,"f":null,"g":"\\u0041\\n"}');
console.log(back, back.g.length);
console.log(JSON.stringify([new Date(0), "s", 1, false, null]), JSON.stringify({ toJSON() { return "custom"; } }));
try { JSON.parse("{bad json}"); } catch (e) { console.log(e.name); }

console.log(Math.max(1, 5, 3), Math.min(4, -2), Math.abs(-7), Math.floor(-2.5), Math.ceil(2.1), Math.round(2.5), Math.round(-2.5));
console.log(Math.trunc(-4.7), Math.sign(-3), Math.sqrt(16), Math.pow(2, 8), Math.hypot(3, 4), Math.cbrt(27));
const r = Math.random();
console.log(r >= 0 && r < 1, Math.PI.toFixed(4), Math.E.toFixed(2));
console.log((1234.5678).toFixed(2), (0.5).toFixed(0), (255).toString(16), (255).toString(2), (5).toString().length);
console.log(Number.MAX_SAFE_INTEGER, Number.isFinite(1 / 0), Number.parseFloat("1.5"), (1234567.891).toLocaleString());

const m = new Map([["a", 1], ["b", 2]]);
m.set("c", 3).set("a", 10);
m.delete("b");
console.log(m.size, m.get("a"), m.has("b"), [...m.keys()], [...m.values()], m);
const objKey = {};
m.set(objKey, "object key");
console.log(m.get(objKey), m.get({}));
const set = new Set([1, 2, 2, 3, 3, 3]);
set.add(4).add(1);
console.log(set.size, set.has(2), [...set], set);
const counts = new Map();
for (const w of "the cat the dog the end".split(" ")) counts.set(w, (counts.get(w) || 0) + 1);
console.log([...counts].sort((a, b) => b[1] - a[1])[0]);
let sum = 0;
m.forEach((v, k) => { if (typeof v === "number") sum += v; });
console.log(sum, new Set("hello").size);

const d = new Date(Date.UTC(2024, 0, 15, 12, 30, 45, 123));
console.log(d.toISOString(), d.getTime(), JSON.stringify({ when: d }));
console.log(new Date("2020-02-29T00:00:00Z").toISOString(), typeof Date.now(), Date.now() > 1600000000000);
console.log(Number("0x10"), Number(""), Number(" 42 "), Number(null), Number(undefined), Number([5]));
console.log(String(123), (123).toString().split("").reverse().join(""), Boolean(""), Boolean("0"));
