// A quick tour of what runs. Try: .\run.ps1 examples\hello.js -Exit
class Greeter {
  #count = 0;
  constructor(greeting = "Hello") { this.greeting = greeting; }
  greet(name) {
    this.#count++;
    return `${this.greeting}, ${name}! (#${this.#count})`;
  }
}

const g = new Greeter();
for (const name of ["mIRC", "JavaScript", "World"]) console.log(g.greet(name));

const words = "the quick brown fox jumps over the lazy dog".split(" ");
const lengths = new Map();
for (const w of words) lengths.set(w.length, [...(lengths.get(w.length) ?? []), w]);
console.log(Object.fromEntries(lengths));

const { longest, total } = words.reduce(
  (acc, w) => ({ longest: w.length > acc.longest.length ? w : acc.longest, total: acc.total + w.length }),
  { longest: "", total: 0 },
);
console.log({ longest, total, average: (total / words.length).toFixed(2) });

console.log(JSON.stringify({ when: new Date(0).toISOString(), ok: true, tags: ["js", "msl"] }, null, 2));

setTimeout(() => console.log("...and a timer, a moment later"), 200);
Promise.resolve("promises work too").then(console.log);
