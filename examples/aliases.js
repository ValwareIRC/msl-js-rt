// Extending mIRC script with JavaScript: these become real mSL aliases.
//   /jsload examples\aliases.js
//   //echo -a $slugify(Hello World, from mIRC!)      -> hello-world-from-mirc
//   //var %j = {"a":{"b":[10,20]}} | echo -a $jsonget(%j,a.b.1)   -> 20
//   (mSL splits identifier arguments at commas, so pass JSON in a variable)
//   /shout hello there                               -> HELLO THERE!!!
//   //echo -a $wordcount(the cat and the hat)        -> the=2 cat=1 and=1 hat=1

mirc.alias("slugify", (...parts) =>
  parts.join(",").toLowerCase().normalize().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""));

mirc.alias("jsonget", (json, path) => {
  let value = JSON.parse(json);
  for (const key of path.split(".")) value = value?.[key];
  return value === undefined ? "" : typeof value === "object" ? JSON.stringify(value) : String(value);
});

mirc.alias("shout", (...words) => mirc.echo(words.join(" ").toUpperCase() + "!!!"));

mirc.alias("wordcount", text => {
  const counts = new Map();
  for (const w of text.split(/\s+/).filter(Boolean)) counts.set(w, (counts.get(w) ?? 0) + 1);
  return [...counts].map(([w, n]) => `${w}=${n}`).join(" ");
});

// mSL can signal JavaScript too: /signal jsping a b c
mirc.on("signal", "jsping", e => mirc.echo(`pong from JavaScript with ${e.args.length} args: ${e.args.join(", ")}`));

console.log("aliases ready: $slugify $jsonget /shout $wordcount (and /signal jsping)");
