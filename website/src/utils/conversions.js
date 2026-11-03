import list from "../data/conversions.json";
import rates from "../data/rates.json";
import { UNITS, CURRENCIES, SCENARIOS } from "../data/units.js";
import { TOOLS } from "../lib/tools.js";
import { fmt } from "../lib/engine.js";

const hash = (s) => [...s].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7);
const cap = (s) => s[0].toUpperCase() + s.slice(1);
export const slugOf = (k) => k.replace(/\//g, "-per-").replace(/\s+/g, "-");

const SPECIAL = {
  "celsius to fahrenheit": "Multiply by 9/5, then add 32.",
  "fahrenheit to celsius": "Subtract 32, then multiply by 5/9.",
  "celsius to kelvin": "Add 273.15.",
  "kelvin to celsius": "Subtract 273.15.",
  "fahrenheit to kelvin": "Subtract 32, multiply by 5/9, then add 273.15.",
  "kelvin to fahrenheit": "Subtract 273.15, multiply by 9/5, then add 32.",
};
const trim = (n) => String(Number(n.toPrecision(7)));

function formula(fromU, toU, name) {
  const r = toU.from(fromU.to(1));
  const inv = 1 / r;
  const short = (n) => Number(n.toPrecision(10)).toString().replace(".", "").length <= 5;
  if (r >= 1 || (!short(inv) && short(r))) return `Multiply the number of ${name.from} by ${trim(r)}.`;
  if (short(inv)) return `Divide the number of ${name.from} by ${trim(inv)}.`;
  return `Multiply the number of ${name.from} by ${trim(r)}.`;
}

export function getConversion(item) {
  const [a, b] = item.k.split(" to ");
  const h = hash(item.k);
  const slug = slugOf(item.k);
  if (item.t === "currency") {
    const A = a.toUpperCase(), B = b.toUpperCase();
    const r = rates.rates[B] / rates.rates[A];
    const f = (n) => fmt(Number((n * r).toFixed(r * n >= 100 ? 2 : 4)));
    const amounts = [1, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 5000, 10000, 50000, 100000];
    return {
      ...item, slug, currency: true, from: A, to: B, fromName: CURRENCIES[a], toName: CURRENCIES[b], fromLabel: A, toLabel: B,
      title: `${A} to ${B} converter: ${cap(CURRENCIES[a])} to ${CURRENCIES[b]}`,
      h1: `${A} to ${B}`,
      description: `Convert ${CURRENCIES[a]} to ${CURRENCIES[b]}. 1 ${A} = ${f(1)} ${B} as of ${rates.date}, with a chart of common amounts.`,
      formula: `On ${rates.date}, 1 ${A} equals ${f(1)} ${B}. To convert, multiply the amount in ${A} by that rate.`,
      factor: r, rows: amounts.map((n) => [`${fmt(n)} ${A}`, `${f(n)} ${B}`]),
      example: `Paying ${fmt(250)} ${A} works out to about ${f(250)} ${B} at this rate. Banks and card issuers usually add a margin, so the amount you actually get will differ.`,
      defs: [],
    };
  }
  const units = UNITS[item.t], A = units[a], B = units[b];
  const list_ = TOOLS[item.t].units;
  const fromU = list_.find((u) => u.label === A.label), toU = list_.find((u) => u.label === B.label);
  const conv = (n) => toU.from(fromU.to(n));
  const isTemp = item.t === "temperature";
  const base = isTemp ? [-40, -20, -10, 0, 5, 10, 15, 20, 25, 30, 35, 37, 40, 50, 75, 100] : [1, 2, 3, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 500];
  const n = isTemp ? [20, 37, 100][h % 3] : [5, 12, 25, 40, 60, 75, 150][h % 7];
  const pretty = (v, u) => `${fmt(v)} ${v === 1 ? u.singular : u.plural}`;
  const tmpl = SCENARIOS[item.t][h % SCENARIOS[item.t].length];
  return {
    ...item, slug, from: a, to: b, fromName: A.plural, toName: B.plural, fromLabel: A.label, toLabel: B.label,
    title: `${cap(A.plural)} to ${B.plural} converter (${A.label} to ${B.label})`,
    h1: `${cap(A.plural)} to ${B.plural}`,
    description: `Convert ${A.plural} to ${B.plural}: 1 ${A.label} = ${fmt(conv(1))} ${B.label}. Includes the formula, a chart and a worked example.`,
    formula: SPECIAL[item.k] || formula(fromU, toU, { from: A.plural }),
    unitsKey: `${fromU.name}|${toU.name}`,
    rows: base.map((v) => [`${fmt(v)} ${A.label}`, `${fmt(conv(v))} ${B.label}`]),
    example: tmpl.replace("{a}", pretty(n, A)).replace("{b}", pretty(conv(n), B)),
    defs: [A.def, B.def],
  };
}

export const CONVERSIONS = list.map(getConversion);
export const relatedTo = (c, count = 8) => {
  const rev = CONVERSIONS.find((x) => x.k === c.k.split(" to ").reverse().join(" to "));
  const same = CONVERSIONS.filter((x) => x.t === c.t && x.k !== c.k && x !== rev);
  return [rev, ...same].filter(Boolean).slice(0, count);
};
export const byTool = (t) => CONVERSIONS.filter((x) => x.t === t);
