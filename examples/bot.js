// An IRC bot written in JavaScript, running inside mSL.
//   .\run.ps1 examples\bot.js -Server irc.libera.chat:+6697 -Nick mybot -Join "#mychannel"
// Commands in the channel: !hello  !dice [sides]  !calc <expression>  !seen <nick>  !uptime

const started = Date.now();
const seen = new Map();

const commands = {
  hello: e => e.reply(`Hello, ${e.nick}!`),
  dice: (e, sides = "6") => {
    const n = Math.max(2, Math.min(1000, parseInt(sides, 10) || 6));
    e.reply(`${e.nick} rolls a d${n}: ${1 + Math.floor(Math.random() * n)}`);
  },
  calc: (e, ...expr) => {
    const text = expr.join(" ");
    if (!/^[\d\s+\-*/%().]+$/.test(text)) return e.reply("numbers and + - * / % ( ) only");
    try { e.reply(`${text} = ${eval(text)}`); } catch { e.reply("that does not compute"); }
  },
  seen: (e, nick) => {
    const s = nick && seen.get(nick.toLowerCase());
    e.reply(s ? `${nick} was last seen ${ago(s.at)} in ${s.chan} saying: ${s.text}` : `I have not seen ${nick ?? "them"}.`);
  },
  uptime: e => e.reply(`up for ${ago(started).replace(" ago", "")}`),
};

function ago(ms) {
  const s = Math.round((Date.now() - ms) / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m ago`;
}

mirc.on("text", "!*", e => {
  const [name, ...args] = e.args;
  const cmd = commands[name.slice(1).toLowerCase()];
  if (cmd) cmd(e, ...args);
});

mirc.on("text", e => {
  if (e.chan) seen.set(e.nick.toLowerCase(), { at: Date.now(), chan: e.chan, text: e.text });
});

mirc.on("join", e => {
  if (e.nick !== e.me) mirc.notice(e.nick, `Welcome to ${e.chan}! Try !hello`);
});

mirc.on("connect", e => console.log(`connected to ${e.network ?? e.text} as ${e.me}`));

// an mSL command for the person running the bot: /botstats
mirc.alias("botstats", () => console.log(`seen ${seen.size} nicks, up ${ago(started)}`));
console.log("bot loaded:", Object.keys(commands).map(c => "!" + c).join(" "));
