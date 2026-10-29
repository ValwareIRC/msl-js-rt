// object literals, destructuring, property access, Object.*
const key = "dyn";
const base = { a: 1, b: 2 };
const o = { ...base, c: 3, [key + "amic"]: true, shorthand() { return "m"; }, "quoted key": 4 };
console.log(o);
console.log(Object.keys(o).length, o.dynamic, o.shorthand(), o["quoted key"]);

const { a, b: renamed, z = "dflt", ...others } = o;
console.log(a, renamed, z, others);
const [first, , third = "t", ...tail] = [1, 2, undefined, 4, 5];
console.log(first, third, tail);
let m = 1, n = 2;
[m, n] = [n, m];
console.log(m, n);
const { inner: { deep } } = { inner: { deep: "found" } };
console.log(deep);
function draw({ w = 10, h = 20 } = {}) { return w * h; }
console.log(draw(), draw({ w: 2 }));

const temp = {
  _c: 25,
  get f() { return this._c * 9 / 5 + 32; },
  set f(v) { this._c = (v - 32) * 5 / 9; },
};
console.log(temp.f);
temp.f = 212;
console.log(temp._c);

console.log("a" in o, "zzz" in o, delete o.a, "a" in o);
const proto = { hello() { return "hi from proto"; } };
const child = Object.create(proto);
child.own = 1;
console.log(child.hello(), Object.keys(child), child.hasOwnProperty("own"), child.hasOwnProperty("hello"));
const keys = [];
for (const k in child) keys.push(k);
console.log(keys);

console.log(Object.entries({ x: 1, y: 2 }), Object.values({ x: 1, y: 2 }));
console.log(Object.fromEntries([["p", 1], ["q", 2]]), Object.assign({}, { r: 1 }, { s: 2 }));
const frozen = Object.freeze({ v: 1 });
frozen.v = 2;
console.log(frozen.v, Object.isFrozen(frozen));
const CaseTest = { name: "lower", Name: "Upper", NAME: "caps" };
console.log(CaseTest.name, CaseTest.Name, CaseTest.NAME, Object.keys(CaseTest));
const nested = { level1: { level2: { level3: { level4: "deep" } } }, arr: [1, [2, [3, [4]]]] };
console.log(nested);
