// promises, microtask order, timers
console.log("start");
setTimeout(() => console.log("timeout 20"), 20);
setTimeout(() => console.log("timeout 0"), 0);
Promise.resolve(1).then(v => console.log("then", v));
queueMicrotask(() => console.log("microtask"));
const p = new Promise((resolve, reject) => resolve("resolved"));
p.then(v => { console.log(v); return v + "!"; })
 .then(v => console.log("chained", v))
 .finally(() => console.log("finally"));
Promise.reject(new Error("nope")).catch(e => console.log("caught", e.message));
Promise.all([1, Promise.resolve(2), new Promise(r => r(3))]).then(v => console.log("all", v));
Promise.allSettled([Promise.resolve("ok"), Promise.reject("bad")]).then(r => console.log(r.map(x => x.status).join()));
Promise.race([Promise.resolve("first"), Promise.resolve("second")]).then(v => console.log("race", v));
const iv = setInterval(() => { console.log("interval"); clearInterval(iv); }, 5);
console.log("end");
