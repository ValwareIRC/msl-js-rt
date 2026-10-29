// classes, inheritance, fields, accessors, statics
class Animal {
  static count = 0;
  #secret = "hidden";
  legs = 4;
  constructor(name) {
    this.name = name;
    Animal.count++;
  }
  speak() { return `${this.name} makes a sound`; }
  get description() { return `${this.name} (${this.legs} legs)`; }
  set nickname(v) { this.nick = v.toUpperCase(); }
  reveal() { return this.#secret; }
  static create(name) { return new this(name); }
  toString() { return `Animal<${this.name}>`; }
}

class Dog extends Animal {
  constructor(name, breed) {
    super(name);
    this.breed = breed;
  }
  speak() { return super.speak() + " - woof"; }
  get description() { return super.description + " [dog]"; }
}

class Bird extends Animal {
  legs = 2;
  speak() { return "tweet"; }
}

const a = new Animal("generic");
const d = new Dog("Rex", "lab");
const b = Bird.create("Tweety");
console.log(a.speak(), "|", d.speak(), "|", b.speak());
console.log(a.description, "|", d.description, "|", b.description);
d.nickname = "rexy";
console.log(d.nick, d.reveal(), Animal.count, `${d}`, String(b));
console.log(d instanceof Dog, d instanceof Animal, b instanceof Dog, Object.getPrototypeOf(d) === Dog.prototype);
console.log(typeof Animal, Dog.name, d.constructor.name, Object.keys(d));
console.log(d);

class Stack {
  #items = [];
  push(...xs) { this.#items.push(...xs); return this; }
  pop() { return this.#items.pop(); }
  get size() { return this.#items.length; }
  static from(list) { return new Stack().push(...list); }
}
const s = Stack.from([1, 2, 3]).push(4);
console.log(s.pop(), s.size);

class ValidationError extends Error {
  constructor(field, msg) {
    super(msg);
    this.name = "ValidationError";
    this.field = field;
  }
}
try {
  throw new ValidationError("email", "is invalid");
} catch (e) {
  console.log(e instanceof ValidationError, e instanceof Error, e.name, e.field, e.message, String(e));
}

const Mixin = Base => class extends Base { greet() { return "mixed " + this.name; } };
class Cat extends Mixin(Animal) {}
console.log(new Cat("Tom").greet());

try {
  Animal("no new");
} catch (e) {
  console.log(e.constructor.name, e.message);
}
class Counter {
  static #instances = 0;
  static make() { Counter.#instances++; return Counter.#instances; }
}
Counter.make();
console.log(Counter.make());
