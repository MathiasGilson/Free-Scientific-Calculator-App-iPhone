#!/usr/bin/env node
// Writes the build's currency snapshot. A failed fetch keeps the committed snapshot rather than breaking the build.
import { writeFileSync, existsSync } from "node:fs";

const out = new URL("../src/data/rates.json", import.meta.url);
const CODES = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN", "BRL", "KRW"];

try {
  const res = await fetch("https://open.er-api.com/v6/latest/USD");
  const d = await res.json();
  if (d.result !== "success") throw new Error(d.result);
  const rates = Object.fromEntries(CODES.map((c) => [c, d.rates[c]]));
  if (Object.values(rates).some((v) => !v)) throw new Error("missing rate");
  const date = new Date(d.time_last_update_unix * 1000).toISOString().slice(0, 10);
  writeFileSync(out, JSON.stringify({ date, rates }, null, 2) + "\n");
  console.log(`rates: ${date}`);
} catch (e) {
  if (!existsSync(out)) throw e;
  console.log(`rates: keeping the existing snapshot (${e.message})`);
}
