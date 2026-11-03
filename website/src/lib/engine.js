// Port of ios/ConvCalc/Core/CalculatorEngine.swift. test/engine.test.mjs runs the Swift test cases against it.
const NOISE = 1e-14;
const isDigit = (c) => c !== undefined && c >= "0" && c <= "9";
const isLetter = (c) => c !== undefined && /\p{L}/u.test(c);

export function evaluate(src, deg = true) {
  const c = [...src.replace(/\s+/g, "")];
  if (!c.length) throw new Error("invalid");
  const toRad = (x) => (deg ? (x * Math.PI) / 180 : x);
  const fromRad = (x) => (deg ? (x * 180) / Math.PI : x);
  const trig = (r, arg) => (Math.abs(r) < NOISE && Math.abs(toRad(arg)) > 1e-6 ? 0 : r);
  let i = 0, percentEnd = null, lastPct = false;

  const fn = (n, a) => {
    switch (n) {
      case "sin": return trig(Math.sin(toRad(a)), a);
      case "cos": return trig(Math.cos(toRad(a)), a);
      case "tan":
        if (Math.abs(Math.cos(toRad(a))) <= NOISE) throw new Error("invalid");
        return trig(Math.tan(toRad(a)), a);
      case "asin": return fromRad(Math.asin(a));
      case "acos": return fromRad(Math.acos(a));
      case "atan": return fromRad(Math.atan(a));
      case "sinh": return Math.sinh(a);
      case "cosh": return Math.cosh(a);
      case "tanh": return Math.tanh(a);
      case "asinh": return Math.asinh(a);
      case "acosh": return Math.acosh(a);
      case "atanh": return Math.atanh(a);
      case "sqrt": return Math.sqrt(a);
      case "log": return Math.log(a);
      case "log10": return Math.log10(a);
      default: throw new Error("unknown");
    }
  };
  const factorial = (v) => {
    if (v < 0 || Math.trunc(v) !== v || v > 170) throw new Error("factorial");
    let r = 1;
    for (let k = 2; k <= v; k++) r *= k;
    return r;
  };
  const expr = () => {
    let v = term();
    while (c[i] === "+" || c[i] === "-") {
      const op = c[i++];
      const rhs = term();
      const operand = lastPct ? v * rhs : rhs;
      v = op === "+" ? v + operand : v - operand;
    }
    return v;
  };
  const implicit = (ch) => ch === "(" || ch === "." || isDigit(ch) || isLetter(ch);
  const term = () => {
    let v = unary(), single = true;
    while (i < c.length) {
      const ch = c[i];
      if (ch === "*" || ch === "/") {
        i++;
        const rhs = unary();
        if (ch === "/" && rhs === 0) throw new Error("division");
        v = ch === "*" ? v * rhs : v / rhs;
      } else if (implicit(ch)) v *= unary();
      else break;
      single = false;
    }
    lastPct = single && percentEnd === i;
    return v;
  };
  const unary = () => {
    if (c[i] === "+") { i++; return unary(); }
    if (c[i] === "-") { i++; return -unary(); }
    return power();
  };
  const power = () => {
    const base = post();
    if (c[i] === "^") {
      i++;
      const e = unary();
      percentEnd = null;
      return Math.pow(base, e);
    }
    return base;
  };
  const post = () => {
    let v = prim();
    while (c[i] === "!" || c[i] === "%") {
      if (c[i++] === "!") v = factorial(v);
      else { v /= 100; percentEnd = i; }
    }
    return v;
  };
  const prim = () => {
    if (c[i] === "(") {
      i++;
      const v = expr();
      if (c[i] !== ")") throw new Error("paren");
      i++;
      return v;
    }
    if (isDigit(c[i]) || c[i] === ".") return num();
    if (isLetter(c[i])) return ident();
    throw new Error("invalid");
  };
  const num = () => {
    const s = i;
    let dots = 0;
    while (isDigit(c[i]) || c[i] === ".") {
      if (c[i] === "." && ++dots > 1) throw new Error("invalid");
      i++;
    }
    if (c[i] === "E" || c[i] === "e") {
      let n = i + 1;
      if (c[i] === "E" && (c[n] === "+" || c[n] === "-")) n++;
      if (isDigit(c[n])) { i = n; while (isDigit(c[i])) i++; }
    }
    const text = c.slice(s, i).join("");
    const v = Number(text);
    if (text === "." || Number.isNaN(v)) throw new Error("invalid");
    return v;
  };
  const ident = () => {
    const s = i;
    while (isLetter(c[i]) || isDigit(c[i])) i++;
    const id = c.slice(s, i).join("");
    if (id === "pi") return Math.PI;
    if (id === "e") return Math.E;
    if (c[i] !== "(") throw new Error("unknown");
    i++;
    const a = expr();
    if (c[i] !== ")") throw new Error("paren");
    i++;
    return fn(id, a);
  };

  const out = expr();
  if (i < c.length || !Number.isFinite(out)) throw new Error("invalid");
  return roundedResult(out);
}

export function roundedResult(r) {
  if (!Number.isFinite(r) || r === 0) return r === 0 ? 0 : r;
  if (Math.trunc(r) === r) return r;
  if (Math.abs(r) >= 1e11) return r;
  return Number(r.toExponential(11));
}

// Port of ConverterCore.formatConversionResult.
export function fmt(v) {
  if (!Number.isFinite(v)) return "—";
  if (v === 0) return "0";
  const a = Math.abs(v);
  if (a >= 1e12 || a < 1e-6) return v.toExponential(4);
  const intDigits = a >= 1 ? Math.floor(Math.log10(a)) + 1 : 1;
  return v.toLocaleString("en-US", { maximumFractionDigits: Math.max(0, 8 - intDigits), useGrouping: true });
}

export const pretty = (x) =>
  x.replace(/pi/g, "π").replace(/([+\-*/^])/g, " $1 ").replace(/^ - /, "-").replace(/\( - /g, "(-").replace(/\s+/g, " ").trim();

// Ports of the expression editing helpers in CalculatorInputState.
export function nextParenthesis(x) {
  const last = x[x.length - 1];
  if (last === undefined || "+-/*^(".includes(last)) return "(";
  const open = (x.match(/\(/g) || []).length, close = (x.match(/\)/g) || []).length;
  return open > close ? ")" : "(";
}
export function addDecimalPoint(x) {
  const m = /[\d.]*$/.exec(x)[0];
  if (!m) return x + "0.";
  return m.includes(".") ? x : x + ".";
}
export function appendValue(x, v) {
  if (isDigit(v[0]) && x.length && /[a-z]$/.test(x)) return x + "*" + v;
  return x + v;
}
export function appendFactor(x, v) {
  return x.length && /[\da-z.)!%]$/.test(x) ? x + "*" + v : x + v;
}

// Ports of ConverterCore's form calculators.
const validDate = (y, m, d) => {
  if (!(y >= 1 && y <= 9999) || !Number.isInteger(y) || !Number.isInteger(m) || !Number.isInteger(d)) return null;
  const dt = new Date(Date.UTC(2000, m - 1, d));
  dt.setUTCFullYear(y, m - 1, d);
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d ? dt : null;
};
export function bmi(heightCm, weightKg) {
  if (!(heightCm > 0 && weightKg > 0)) return null;
  const b = weightKg / (heightCm / 100) ** 2;
  return { bmi: Math.round(b * 10) / 10, category: b < 18.5 ? "underweight" : b < 25 ? "normal" : b < 30 ? "overweight" : "obese" };
}
export function age(y, m, d, now = new Date()) {
  const birth = validDate(y, m, d);
  const today = validDate(now.getFullYear(), now.getMonth() + 1, now.getDate());
  if (!birth || birth > today) return null;
  let yrs = today.getUTCFullYear() - y, mos = today.getUTCMonth() + 1 - m, days = today.getUTCDate() - d;
  if (days < 0) {
    mos--;
    days += new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 0)).getUTCDate();
  }
  if (mos < 0) { yrs--; mos += 12; }
  return { years: yrs, months: mos, days };
}
export function dateDiff(y1, m1, d1, y2, m2, d2) {
  const a = validDate(y1, m1, d1), b = validDate(y2, m2, d2);
  if (!a || !b) return null;
  const totalDays = Math.round(Math.abs(b - a) / 86400000);
  return { totalDays, weeks: Math.floor(totalDays / 7), months: Math.round((totalDays / 30.4375) * 10) / 10, years: Math.round((totalDays / 365.25) * 100) / 100 };
}
const cents = (v) => Math.round(v * 100) / 100;
export function loan(principal, rate, years) {
  if (!(principal > 0 && rate >= 0 && years > 0)) return null;
  const r = rate / 100 / 12, n = years * 12;
  const monthly = rate === 0 ? principal / n : (principal * (r * (1 + r) ** n)) / ((1 + r) ** n - 1);
  if (!Number.isFinite(monthly)) return null;
  const total = monthly * n;
  return { monthly: cents(monthly), totalPaid: cents(total), totalInterest: cents(total - principal) };
}
export function discount(price, percent) {
  if (!(price >= 0 && percent >= 0 && percent <= 100)) return null;
  const savings = price * (percent / 100);
  return { savings: cents(savings), finalPrice: cents(price - savings) };
}
