// JS port of the grammar in ios/ConvCalc/Core/CalculatorEngine.swift, for the mockup demo.
export function evaluate(src, deg = true) {
  let s = src.replace(/\s+/g, ""), i = 0;
  const open = (s.match(/\(/g) || []).length - (s.match(/\)/g) || []).length;
  if (open > 0) s += ")".repeat(open);
  const R = (x) => (deg ? (x * Math.PI) / 180 : x), D = (x) => (deg ? (x * 180) / Math.PI : x);
  const clean = (x) => (Math.abs(x) < 1e-12 ? 0 : x);
  const F = {
    sin: (x) => clean(Math.sin(R(x))), cos: (x) => clean(Math.cos(R(x))),
    tan: (x) => { if (Math.abs(Math.cos(R(x))) < 1e-12) throw 0; return clean(Math.tan(R(x))); },
    asin: (x) => D(Math.asin(x)), acos: (x) => D(Math.acos(x)), atan: (x) => D(Math.atan(x)),
    sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh, asinh: Math.asinh, acosh: Math.acosh, atanh: Math.atanh,
    sqrt: Math.sqrt, log: Math.log, log10: Math.log10,
  };
  let pct = false;
  const expr = () => {
    let a = term();
    while (s[i] === "+" || s[i] === "-") {
      const op = s[i++]; const b = term();
      const d = pct ? (a * b) : b; // "100+10%" adds 10 percent of 100, as in the app.
      a = op === "+" ? a + d : a - d;
    }
    pct = false; return a;
  };
  const term = () => {
    let a = pow(); let single = lastPct;
    while (s[i] === "*" || s[i] === "/" || (s[i] && /[(a-zπ\d.]/.test(s[i]) && i > 0)) {
      single = false;
      if (s[i] === "*") { i++; a *= pow(); }
      else if (s[i] === "/") { i++; const b = pow(); if (b === 0) throw 0; a /= b; }
      else a *= pow();
    }
    pct = single; return a;
  };
  const pow = () => { const a = unary(); if (s[i] === "^") { i++; return a ** pow(); } return a; };
  let lastPct = false;
  const unary = () => { if (s[i] === "-") { i++; return -unary(); } if (s[i] === "+") { i++; return unary(); } return post(); };
  const post = () => {
    let a = prim(); lastPct = false;
    while (s[i] === "!" || s[i] === "%") {
      if (s[i++] === "%") { a /= 100; lastPct = true; }
      else { if (a < 0 || a % 1 || a > 170) throw 0; let r = 1; for (let k = 2; k <= a; k++) r *= k; a = r; }
    }
    return a;
  };
  const prim = () => {
    if (s[i] === "(") { i++; const a = expr(); if (s[i] !== ")") throw 0; i++; return a; }
    const n = /^(\d+\.?\d*|\.\d+)/.exec(s.slice(i));
    if (n) { i += n[0].length; return parseFloat(n[0]); }
    const id = /^[a-z]+\d*/.exec(s.slice(i));
    if (!id) throw 0;
    i += id[0].length;
    if (id[0] === "pi") return Math.PI;
    if (id[0] === "e" && s[i] !== "(") return Math.E;
    if (!F[id[0]] || s[i] !== "(") throw 0;
    i++; const a = expr(); if (s[i] !== ")") throw 0; i++; return F[id[0]](a);
  };
  const out = expr();
  if (i !== s.length || !isFinite(out)) throw 0;
  return Number.isInteger(out) || Math.abs(out) >= 1e11 ? out : Number(out.toExponential(11));
}
export const fmt = (v) => {
  if (v === 0) return "0";
  const a = Math.abs(v);
  if (a >= 1e12 || a < 1e-6) return v.toExponential(4).replace("e+", "e");
  return String(Number(v.toPrecision(8)));
};
export const pretty = (x) => x.replace(/pi/g, "π").replace(/([+\-*/^])/g, " $1 ").replace(/^ - /, "-").replace(/\( - /g, "(-").replace(/\s+/g," ").trim();
