// require() and module.exports
const shapes = require("./lib/shapes");
const again = require("./lib/shapes.js");
const { Circle, perimeter } = shapes;
console.log(new Circle(10).area(), perimeter(10), shapes === again, shapes.loads);
console.log(typeof PI2, Object.keys(shapes));
const code = "1 + 2 * 3";
console.log(eval(code), eval("var evalVar = 'made by eval'; evalVar"));
