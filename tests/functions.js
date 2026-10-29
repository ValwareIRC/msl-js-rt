// closures, parameters, this, hoisting
function counter() {
  let n = 0;
  return { inc: () => ++n, get: () => n };
}
const c1 = counter(), c2 = counter();
c1.inc(); c1.inc(); c2.inc();
console.log(c1.get(), c2.get());

function defaults(a, b = a * 2, ...rest) { return [a, b, rest]; }
console.log(defaults(1), defaults(1, 5, 7, 8));

function args() { return arguments.length + ":" + Array.from(arguments).join("|"); }
console.log(args("x", "y", "z"));

const sum = (...nums) => nums.reduce((a, b) => a + b, 0);
console.log(sum(1, 2, 3, 4), sum(...[10, 20]), Math.max(...[3, 9, 2]));

console.log(hoisted(3));
function hoisted(v) { return v * 10; }
console.log(typeof laterVar, laterVar);
var laterVar = "now set";

const fact = function f(n) { return n <= 1 ? 1 : n * f(n - 1); };
console.log(fact(10), fact.name);

const obj = {
  name: "obj",
  regular() { return this.name; },
  arrow() { return [1].map(() => this.name)[0]; },
};
console.log(obj.regular(), obj.arrow());
const unbound = obj.regular;
console.log(unbound.call({ name: "other" }), unbound.apply({ name: "applied" }, []));
const bound = obj.regular.bind({ name: "bound" });
console.log(bound(), bound.name);

const fns = [];
for (let i = 0; i < 3; i++) fns.push(() => i);
console.log(fns.map(f => f()));

const adder = a => b => c => a + b + c;
console.log(adder(1)(2)(3));

console.log((function () { "use strict"; return typeof this; })(), (() => 42)());
function Point(x, y) { this.x = x; this.y = y; }
Point.prototype.len = function () { return Math.sqrt(this.x * this.x + this.y * this.y); };
const p = new Point(3, 4);
console.log(p.len(), p instanceof Point, p.constructor === Point, Object.keys(p));
