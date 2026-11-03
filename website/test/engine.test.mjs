import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { evaluate, bmi, age, dateDiff, loan, discount, fmt } from "../src/lib/engine.js";
import { TOOLS } from "../src/lib/tools.js";

// Cases extracted from ios/ConvCalcTests/CalculatorEngineTests.swift.
const cases = JSON.parse(readFileSync(new URL("./engine-cases.json", import.meta.url)));

for (const c of cases.values) {
  test(`${c.e} = ${c.w} (${c.mode})`, () => {
    assert.ok(Math.abs(evaluate(c.e, c.mode === "deg") - c.w) <= c.a, `got ${evaluate(c.e, c.mode === "deg")}`);
  });
}
for (const c of cases.throws) {
  test(`${c.e} throws (${c.mode})`, () => assert.throws(() => evaluate(c.e, c.mode === "deg")));
}
test("form calculators", () => {
  assert.deepEqual(bmi(170, 70), { bmi: 24.2, category: "normal" });
  assert.deepEqual(discount(100, 20), { savings: 20, finalPrice: 80 });
  assert.equal(loan(100000, 5, 30).monthly, 536.82);
  assert.equal(loan(1200, 0, 1).monthly, 100);
  assert.deepEqual(age(1990, 1, 1, new Date(2026, 10, 3)), { years: 36, months: 10, days: 2 });
  assert.equal(age(2030, 1, 1, new Date(2026, 10, 3)), null);
  assert.equal(dateDiff(2020, 1, 1, 2021, 1, 1).totalDays, 366);
  assert.equal(dateDiff(2021, 2, 30, 2021, 3, 1), null);
});
test("units", () => {
  const conv = (t, a, b, v) => { const u = TOOLS[t].units; const f = u.find((x) => x.label === a), g = u.find((x) => x.label === b); return g.from(f.to(v)); };
  assert.ok(Math.abs(conv("length", "cm", "in", 2.54) - 1) < 1e-12);
  assert.ok(Math.abs(conv("temperature", "°C", "°F", 100) - 212) < 1e-9);
  assert.equal(fmt(0.1), "0.1");
  assert.equal(fmt(1234.5), "1,234.5");
});
