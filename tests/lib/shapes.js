// a module for modules.js
const PI2 = Math.PI * 2;
class Circle {
  constructor(r) { this.r = r; }
  area() { return Math.round(Math.PI * this.r * this.r); }
}
function perimeter(r) { return Math.round(PI2 * r); }
let loads = 0;
loads++;
module.exports = { Circle, perimeter, loads };
