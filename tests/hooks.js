// the mirc bridge: aliases, variables, hash tables, signals (mIRC only)
mirc.alias("double", x => String(Number(x) * 2));
console.log("identifier:", mirc.eval("$double(21)"));
mirc.alias("greet", (...words) => console.log("command got", words));
mirc.cmd("greet hello there irc");
mirc.alias("joinargs", (...args) => args.join("+"));
console.log("args:", mirc.eval("$joinargs(a b,c,d)"));

mirc.setVar("jstest", "value from js");
console.log(mirc.getVar("jstest"), "|", mirc.eval("%jstest"));
mirc.unsetVar("jstest");
console.log(mirc.getVar("jstest"));

mirc.hadd("jstab", "Key", "stored");
console.log(mirc.hget("jstab", "key"), mirc.eval("$hget(jstab,Key)"));
mirc.hdel("jstab", "key");
console.log(mirc.hget("jstab", "key"));

const seen = [];
mirc.on("signal", "ping*", e => seen.push(`${e.signal}: ${e.args.join(",")}`));
mirc.on("signal", e => { if (e.signal === "stop") return false; });
mirc.signal("ping", "one", 2);
mirc.signal("pong", "ignored by the matcher");
mirc.signal("pingpong");
console.log(seen);

console.log(mirc.eval("$calc(6 * 7)"), mirc.eval("$len(abcdef)"), typeof mirc.version);
mirc.exec("hadd -m jstab exec $upper(evaluated)");
console.log(mirc.hget("jstab", "exec"));
try { mirc.cmd("hadd"); } catch (e) { console.log("mIRC error caught:", e.message.includes("hadd")); }
mirc.unalias("double");
console.log("after unalias:", JSON.stringify(mirc.eval("$double(1)")));
