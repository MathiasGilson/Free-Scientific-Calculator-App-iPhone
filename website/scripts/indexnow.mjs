#!/usr/bin/env node
// Submits URLs from the built sitemap(s) to IndexNow (Bing, Yandex, Seznam, Naver...).
// The key file must be deployed at https://<host>/<key>.txt with the key as its only content;
// this script finds it in the build output by that convention.
//
// Usage: node scripts/indexnow.mjs --dist dist --host example.com [--days 3] [--all] [--dry-run]
//   --days N   only submit URLs whose sitemap <lastmod> is within the last N days (default 3).
//              URLs without <lastmod> are always submitted.
//   --all      submit every sitemap URL regardless of lastmod.
// Never fails the deploy: errors are logged and the exit code stays 0.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};
const dist = opt("dist", "dist");
const host = opt("host");
const days = Number(opt("days", "3"));
const all = args.includes("--all");
const dryRun = args.includes("--dry-run");

const main = async () => {
  if (!host) throw new Error("--host is required");

  const key = readdirSync(dist).find((f) => {
    const m = f.match(/^([a-f0-9]{32})\.txt$/);
    return m && readFileSync(join(dist, f), "utf8").trim() === m[1];
  })?.slice(0, 32);
  if (!key) throw new Error(`no IndexNow key file (<32 hex>.txt) found in ${dist}`);

  const sitemapFiles = [];
  const walk = (dir) => {
    for (const f of readdirSync(dir)) {
      const p = join(dir, f);
      if (statSync(p).isDirectory()) walk(p);
      else if (/^sitemap.*\.xml$/.test(f)) sitemapFiles.push(p);
    }
  };
  walk(dist);

  const cutoff = Date.now() - days * 86_400_000;
  const urls = new Set();
  for (const file of sitemapFiles) {
    const xml = readFileSync(file, "utf8");
    for (const [, block] of xml.matchAll(/<url>([\s\S]*?)<\/url>/g)) {
      const loc = block.match(/<loc>\s*([^<]+?)\s*<\/loc>/)?.[1]?.replace(/&amp;/g, "&");
      if (!loc || new URL(loc).host !== host) continue;
      const lastmod = block.match(/<lastmod>\s*([^<]+?)\s*<\/lastmod>/)?.[1];
      if (all || !lastmod || Date.parse(lastmod) >= cutoff) urls.add(loc);
    }
  }

  const list = [...urls];
  console.log(`[indexnow] ${host}: ${list.length} URL(s) from ${sitemapFiles.length} sitemap file(s)`);
  if (!list.length || dryRun) {
    if (dryRun) console.log(list.slice(0, 20).join("\n"));
    return;
  }

  for (let i = 0; i < list.length; i += 10_000) {
    const res = await fetch("https://api.indexnow.org/indexnow", {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify({
        host,
        key,
        keyLocation: `https://${host}/${key}.txt`,
        urlList: list.slice(i, i + 10_000),
      }),
    });
    console.log(`[indexnow] batch ${i / 10_000 + 1}: HTTP ${res.status} ${await res.text()}`);
  }
};

main().catch((err) => console.error(`[indexnow] skipped: ${err.message}`));
