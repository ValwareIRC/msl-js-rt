// async functions and await (sequential, so the order matches Node)
async function add(a, b) { return a + b; }
async function fails() { throw new TypeError("async failure"); }
const delayFree = v => new Promise(resolve => resolve(v));

async function main() {
  const x = await add(1, 2);
  console.log("x", x);
  const y = await delayFree(10);
  console.log("y", y);
  try {
    await fails();
  } catch (e) {
    console.log("caught", e.name, e.message);
  }
  const all = await Promise.all([add(1, 1), delayFree("v"), 3]);
  console.log("all", all);
  const arrow = async () => (await add(20, 22)) + 0;
  console.log("arrow", await arrow());
  return "done";
}
main().then(r => console.log("main", r));
