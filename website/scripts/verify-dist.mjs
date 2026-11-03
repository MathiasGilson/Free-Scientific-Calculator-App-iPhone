#!/usr/bin/env node
// Checks every built page: one h1, unique title and description, canonical, hreflang, internal links, App Store link.
import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const dist = new URL("../dist/", import.meta.url).pathname;
const walk = (d) => readdirSync(d).flatMap((f) => { const p = join(d, f); return statSync(p).isDirectory() ? walk(p) : [p]; });
const files = walk(dist);
const pages = files.filter((f) => f.endsWith(".html"));
const errors = [], titles = new Map(), descs = new Map();
const exists = (u) => {
  const p = u.split(/[?#]/)[0].replace(/\/$/, "") || "/";
  return p === "/" ? existsSync(join(dist, "index.html")) : existsSync(join(dist, p + ".html")) || existsSync(join(dist, p, "index.html")) || existsSync(join(dist, p));
};
const decode = (s) => s.replace(/&#x27;/g, "'").replace(/&amp;/g, "&");
for (const f of pages) {
  const rel = "/" + relative(dist, f).replace(/(index)?\.html$/, "").replace(/\/$/, "");
  const html = readFileSync(f, "utf8");
  const err = (m) => errors.push(`${rel}: ${m}`);
  if ((html.match(/<h1[\s>]/g) || []).length !== 1) err("needs exactly one h1");
  const title = /<title>([^<]*)<\/title>/.exec(html)?.[1], desc = /<meta name="description" content="([^"]*)"/.exec(html)?.[1];
  if (!title) err("no title"); if (!desc) err("no description");
  if (titles.has(title)) err(`duplicate title with ${titles.get(title)}`); else titles.set(title, rel);
  if (descs.has(desc)) err(`duplicate description with ${descs.get(desc)}`); else descs.set(desc, rel);
  if (/\p{Script=Latin}—\p{Script=Latin}/u.test(decode(title + desc))) err("em dash in snippet");
  const canon = /<link rel="canonical" href="([^"]*)"/.exec(html)?.[1];
  if (rel !== "/404" && canon !== `https://convcalc.app${rel === "/" ? "" : rel}`) err(`canonical ${canon}`);
  const alts = [...html.matchAll(/hreflang="([^"]+)" href="([^"]+)"/g)];
  const isConvert = rel.startsWith("/convert") || ["/privacy", "/support", "/404"].includes(rel);
  if (!isConvert && alts.length !== 17) err(`hreflang count ${alts.length}`);
  for (const [, , h] of alts) if (!exists(h.replace("https://convcalc.app", "") || "/")) err(`hreflang target missing ${h}`);
  if (!["/privacy", "/404"].includes(rel) && !rel.endsWith("/compare") && !rel.endsWith("/convert") && !html.includes("apps.apple.com/app/convcalc-calculator-converter/id6472445974")) err("no App Store link");
  for (const m of html.matchAll(/<a\b[^>]*href="(\/[^"]*)"/g)) if (!exists(m[1])) err(`broken link ${m[1]}`);
}
const clean = (s) => decode(s).toLowerCase().replace(/°/g, "");
for (const { k } of JSON.parse(readFileSync(new URL("../src/data/conversions.json", import.meta.url), "utf8"))) {
  const rel = `/convert/${k.replace(/\//g, "-per-").replace(/\s+/g, "-")}`;
  const html = readFileSync(join(dist, existsSync(join(dist, rel + ".html")) ? rel + ".html" : rel + "/index.html"), "utf8");
  if (!clean(/<title>([^<]*)/.exec(html)[1]).includes(k)) errors.push(`${rel}: title lacks "${k}"`);
  if (!clean(/<h1[^>]*>([^<]*)/.exec(html)[1]).includes(k)) errors.push(`${rel}: h1 lacks "${k}"`);
  if (!/<output data-out[^>]*>[^<]+</.test(html)) errors.push(`${rel}: no result without JavaScript`);
}
const sm = readFileSync(join(dist, "sitemap.xml"), "utf8");
const locs = [...sm.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
for (const u of locs) if (!exists(u.replace("https://convcalc.app", "") || "/")) errors.push(`sitemap target missing ${u}`);
console.log(`${pages.length} pages, ${locs.length} sitemap URLs, ${errors.length} problems`);
errors.slice(0, 40).forEach((e) => console.log("  " + e));
process.exit(errors.length ? 1 : 0);
