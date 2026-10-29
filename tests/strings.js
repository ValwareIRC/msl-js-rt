// string methods and regular expressions
const s = "Hello, World";
console.log(s.length, s[0], s.at(-1), s.charAt(4), s.charCodeAt(0), String.fromCharCode(72, 105));
console.log(s.toUpperCase(), s.toLowerCase(), s.indexOf("o"), s.lastIndexOf("o"), s.indexOf("zzz"));
console.log(s.slice(7), s.slice(-5, -1), s.substring(5, 0), s.substr(7, 3));
console.log(s.includes("World"), s.startsWith("Hell"), s.endsWith("ld"), s.includes("world"));
console.log("  padded  ".trim() + "|", "  x".trimStart(), "x  ".trimEnd() + "|");
console.log("a,b,,c".split(","), "abc".split(""), "one two  three".split(" ", 2));
console.log("5".padStart(3, "0"), "ab".padEnd(5, "-"), "ha".repeat(3), "x".concat("y", 1));
console.log("aaa".replace("a", "b"), "aaa".replaceAll("a", "b"), "a-b-c".replace("-", m => "+" + m));
console.log("Case".localeCompare("case") !== 0, "a" < "b", "apple" > "Apple");
console.log(`${"tag"}`.length, "émoji ✓".length, [..."日本語"].length);

const re = /(\d+)-(\d+)/;
const m = "range 10-20 here".match(re);
console.log(m[0], m[1], m[2], m.index);
console.log("a1b22c333".match(/\d+/g), "no digits".match(/\d/), /^h/i.test("Hello"), /^h/.test("Hello"));
console.log("2024-01-15".replace(/(\d+)-(\d+)-(\d+)/, "$3/$2/$1"));
console.log("hello world".replace(/o/g, "0"), "a.b.c".split(/\./), "x1y2z3".split(/\d/));
console.log("John Smith".replace(/(\w+)\s(\w+)/, (all, first, last) => `${last}, ${first}`));
const g = /o/g;
console.log(g.exec("foo boo").index, g.lastIndex, g.exec("foo boo").index);
console.log("camelCaseString".replace(/([A-Z])/g, "_$1").toLowerCase());
console.log([..."a1b2".matchAll(/[a-z](\d)/g)].map(x => x[1]), "abc".search(/c/));
console.log(new RegExp("w+", "g").source, String(/x/gi), "tEsT".replace(/t/gi, "_"));
console.log(encodeURIComponent("a b&c=d/é"), decodeURIComponent("a%20b%26c"));
console.log(JSON.stringify("quote \" and \\ and \n newline"), 'it\'s', "tab\there");
