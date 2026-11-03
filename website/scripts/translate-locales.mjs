#!/usr/bin/env node
/**
 * Translate locale files for the ConvCalc website using OpenRouter API.
 *
 * Checks all locale JSON files against src/locales/en.json and translates
 * missing keys. Structure: src/locales/<lang>.json (nested JSON).
 *
 * Ported from Tasksboard — adapted for nested JSON structure.
 *
 * Usage:
 *   node scripts/translate-locales.mjs              # all locales
 *   node scripts/translate-locales.mjs ru fr de     # specific locales only
 *   node scripts/translate-locales.mjs --only=ru,fr # same via flag
 *   node scripts/translate-locales.mjs --force      # retranslate existing keys
 *   node scripts/translate-locales.mjs --dry-run    # preview what would be done
 *   node scripts/translate-locales.mjs --key=nav.productLinks  # one subtree only
 *
 * Env: OPEN_ROUTER_API_KEY must be set.
 *     node scripts/translate-locales.mjs
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const API_KEY = process.env.OPEN_ROUTER_API_KEY;
if (!API_KEY) {
  console.error('ERROR: OPEN_ROUTER_API_KEY environment variable is not set.');
  console.error(
  );
  process.exit(1);
}

const API_URL = 'https://openrouter.ai/api/v1/chat/completions';
const MODEL = 'google/gemini-2.5-flash';

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'locales');
const EN_FILE = path.join(LOCALES_DIR, 'en.json');

const MAX_CHUNK_BYTES = 30000;
const MAX_CONCURRENT_API = 6;
const DELAY_BETWEEN_CALLS_MS = 150;

const LOCALE_NAMES = {
  ar: 'Arabic',
  de: 'German',
  es: 'Spanish',
  fr: 'French',
  hi: 'Hindi',
  it: 'Italian',
  ja: 'Japanese',
  ko: 'Korean',
  nl: 'Dutch',
  no: 'Norwegian',
  pt: 'Portuguese',
  ru: 'Russian',
  sv: 'Swedish',
  th: 'Thai',
  zh: 'Chinese (Simplified)',
};

// Real search terms from the Keyword Planner research (docs/superpowers/specs/2026-11-02-convcalc-website/keywords).
const GLOSSARY = {
  fr: "calculatrice iphone, calculatrice scientifique iphone, convertisseur de devises, convertisseur d'unités",
  de: 'Taschenrechner iPhone, Taschenrechner App, wissenschaftlicher Taschenrechner, Währungsrechner, Verlauf',
  it: 'calcolatrice iPhone, calcolatrice scientifica, convertitore valuta, convertitore di unità',
  pt: 'calculadora iPhone, calculadora científica iPhone, histórico da calculadora, conversor de moedas, conversor de unidades',
  nl: 'rekenmachine app iPhone, wetenschappelijke rekenmachine, valuta omrekenen, eenheden omrekenen',
  es: 'calculadora iPhone, calculadora científica iPhone, historial de calculadora, conversor de divisas, conversor de unidades',
  ru: 'калькулятор для айфона, инженерный калькулятор, конвертер валют, конвертер величин',
  hi: 'कैलकुलेटर ऐप, साइंटिफिक कैलकुलेटर, यूनिट कन्वर्टर, मुद्रा परिवर्तक',
  no: 'kalkulator app iPhone, vitenskapelig kalkulator, valutakalkulator',
  sv: 'miniräknare app iPhone, vetenskaplig miniräknare, valutaomvandlare',
  ar: 'آلة حاسبة علمية, تطبيق آلة حاسبة للايفون, تحويل العملات, تحويل الوحدات',
  zh: 'iPhone 计算器 App, 科学计算器, 汇率换算, 单位换算',
  ko: '아이폰 계산기 앱, 공학용 계산기, 환율 계산기, 단위 변환',
  th: 'เครื่องคิดเลขวิทยาศาสตร์, แอพเครื่องคิดเลข, แปลงสกุลเงิน, แปลงหน่วย',
  ja: '計算機 アプリ, iPhone 電卓, 関数電卓 アプリ, 為替 計算, 単位変換',
};

// ── CLI args ──────────────────────────────────────────────────────────────────

const rawArgs = process.argv.slice(2);
const flags = {
  force: rawArgs.includes('--force'),
  dryRun: rawArgs.includes('--dry-run'),
  only: null,
  key: null,
};

for (const arg of rawArgs) {
  if (arg.startsWith('--only=')) flags.only = arg.slice(7).split(',');
  if (arg.startsWith('--key=')) flags.key = arg.slice(6);
}

// Positional args (non-flag tokens) treated as locale list
const positionalLocales = rawArgs.filter((a) => !a.startsWith('--') && LOCALE_NAMES[a]);

// ── Nested JSON helpers ───────────────────────────────────────────────────────

/**
 * Deep diff: return subtree of `source` that is missing in `target`.
 * For arrays: if the array exists in target but has fewer items, include full array from source.
 */
function findMissingSubtree(source, target) {
  if (target === undefined || target === null) return source;

  if (Array.isArray(source)) {
    // If array exists in target but differs — treat as missing only when --force
    if (!Array.isArray(target) || flags.force) return source;
    return undefined; // array present, skip
  }

  if (typeof source === 'object' && source !== null) {
    if (typeof target !== 'object' || Array.isArray(target)) return source;
    const diff = {};
    for (const [k, v] of Object.entries(source)) {
      const childDiff = findMissingSubtree(v, flags.force ? undefined : target[k]);
      if (childDiff !== undefined) diff[k] = childDiff;
    }
    return Object.keys(diff).length > 0 ? diff : undefined;
  }

  // Primitive
  if (flags.force) return source;
  return undefined; // exists in target
}

/**
 * Count leaf values (strings + array elements) in an object recursively.
 */
function countLeaves(obj) {
  if (obj === null || obj === undefined) return 0;
  if (Array.isArray(obj)) return obj.length;
  if (typeof obj === 'object') {
    return Object.values(obj).reduce((sum, v) => sum + countLeaves(v), 0);
  }
  return 1;
}

/**
 * Deep-merge `translated` into `target`, replacing only keys present in `translated`.
 */
function deepMerge(target, translated) {
  if (typeof translated !== 'object' || Array.isArray(translated) || translated === null) {
    return translated;
  }
  const result = { ...target };
  for (const [k, v] of Object.entries(translated)) {
    if (
      typeof v === 'object' &&
      !Array.isArray(v) &&
      v !== null &&
      typeof result[k] === 'object' &&
      !Array.isArray(result[k])
    ) {
      result[k] = deepMerge(result[k] || {}, v);
    } else {
      result[k] = v;
    }
  }
  return result;
}

/**
 * Reorder top-level keys in `locData` to match `enData` order.
 * Preserves any extra keys in locData at the end.
 */
function reorderKeys(enData, locData) {
  const ordered = {};
  for (const key of Object.keys(enData)) {
    if (key in locData) ordered[key] = locData[key];
  }
  for (const key of Object.keys(locData)) {
    if (!(key in ordered)) ordered[key] = locData[key];
  }
  return ordered;
}

/**
 * Get a nested subtree from `obj` by dot-path (e.g. "nav.productLinks").
 */
function getByPath(obj, dotPath) {
  return dotPath.split('.').reduce((cur, k) => cur?.[k], obj);
}

/**
 * Set a nested value in `obj` by dot-path. Mutates obj.
 */
function setByPath(obj, dotPath, value) {
  const keys = dotPath.split('.');
  let cur = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    if (typeof cur[keys[i]] !== 'object' || cur[keys[i]] === null) cur[keys[i]] = {};
    cur = cur[keys[i]];
  }
  cur[keys[keys.length - 1]] = value;
}

// ── Progress tracker ──────────────────────────────────────────────────────────

const progress = {
  startTime: null,
  totalKeys: 0,
  doneKeys: 0,
  failedKeys: 0,
  apiCalls: 0,
  locales: {},

  init(localeKeyCounts) {
    this.startTime = Date.now();
    this.totalKeys = 0;
    this.doneKeys = 0;
    this.failedKeys = 0;
    this.apiCalls = 0;
    for (const [loc, count] of Object.entries(localeKeyCounts)) {
      this.locales[loc] = { total: count, done: 0, failed: 0, status: 'waiting' };
      this.totalKeys += count;
    }
  },

  startLocale(locale) {
    if (this.locales[locale]) this.locales[locale].status = 'translating';
    this.print();
  },

  updateLocale(locale, keysDone, keysFailed) {
    if (!this.locales[locale]) return;
    this.locales[locale].done += keysDone;
    this.locales[locale].failed += keysFailed;
    this.doneKeys += keysDone;
    this.failedKeys += keysFailed;
    this.print();
  },

  finishLocale(locale) {
    if (!this.locales[locale]) return;
    const loc = this.locales[locale];
    loc.status = loc.failed > 0 ? 'partial' : 'done';
    this.print();
  },

  countApiCall() {
    this.apiCalls++;
  },

  print() {
    const elapsed = Date.now() - this.startTime;
    const elapsedStr = formatDuration(elapsed);
    const pct = this.totalKeys > 0 ? ((this.doneKeys / this.totalKeys) * 100).toFixed(1) : '0.0';
    const rate = elapsed > 0 ? (this.doneKeys / (elapsed / 1000)).toFixed(1) : '0';
    const remaining = this.totalKeys - this.doneKeys - this.failedKeys;
    const eta = parseFloat(rate) > 0 && remaining > 0 ? formatDuration((remaining / parseFloat(rate)) * 1000) : '--';
    const statusIcons = { waiting: '.', translating: '*', done: 'OK', partial: '!!' };
    const localeBar = Object.entries(this.locales)
      .map(([loc, s]) => {
        const locPct = s.total > 0 ? Math.round((s.done / s.total) * 100) : 100;
        const icon = statusIcons[s.status] || '?';
        return `${loc}:${locPct}%[${icon}]`;
      })
      .join(' ');
    console.log(
      `[${elapsedStr}] ${pct}% (${this.doneKeys}/${this.totalKeys}) | ${rate} keys/s | ETA ${eta} | API calls: ${this.apiCalls}${this.failedKeys > 0 ? ` | FAILED: ${this.failedKeys}` : ''}`
    );
    console.log(`  ${localeBar}`);
  },
};

function formatDuration(ms) {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const h = Math.floor(m / 60);
  if (h > 0) return `${h}h${String(m % 60).padStart(2, '0')}m`;
  if (m > 0) return `${m}m${String(s % 60).padStart(2, '0')}s`;
  return `${s}s`;
}

// ── API ───────────────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function translateJSON(enChunk, locale, retries = 3) {
  const langName = LOCALE_NAMES[locale] || locale;
  const jsonStr = JSON.stringify(enChunk, null, 2);

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 120_000);

      const response = await fetch(API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${API_KEY}`,
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: MODEL,
          messages: [
            {
              role: 'system',
              content: `You are a professional translator localizing the website of ConvCalc, a free calculator and converter app for iPhone.

Translate the JSON values from English to ${langName}.

TRANSLATION RULES — strict:
1. Translate every word exactly. Preserve full meaning, length, and structure.
2. Do NOT shorten, abbreviate, summarize, or simplify the text.
3. Do NOT drop details, qualifiers, or modifiers.
4. Do NOT replace specific terms with broader categories.
5. If the source has 12 words, the translation should have a comparable count (within natural language variation, not less than 80%).
6. Preserve placeholders exactly: {variable}, {{variable}}, %s, $1, {h}, {/h}, etc. — never translate them.
7. Do NOT translate brand or app names: ConvCalc, Apple, iPhone, iPad, iOS, iPadOS, App Store, GitHub, PCalc, PCalc Lite, Calcbot, Calculator₊, Tydlig, Desmos, Tapbots, Math Notes. Keep unit abbreviations such as km, mph and PSI as they are.
8. Do NOT translate technical terms when they are commonly used in English in the target language: API, URL, JSON, SDK, OAuth, SaaS.
9. Match the tone of the source: direct, functional, no fluff.
10. Output ONLY the translated JSON value. No commentary, no quotes around the JSON, no explanations.

STRUCTURE RULES — strict:
11. Keep ALL JSON keys exactly as-is (do not translate keys).
12. Keep the JSON structure exactly as-is — nested objects, arrays, same depth.
13. Keep numbers, special characters, HTML entities as-is.
14. Output ONLY valid JSON — no explanations, no markdown code blocks, no wrapping.

QUALITY RULES — strict:
15. The translation must be natural and fluent in ${langName}.
16. Do NOT use em dashes (—) in translations — use commas, periods, or restructure instead.
17. Avoid AI/marketing clichés in any language: words equivalent to "leverage", "seamlessly", "unlock", "elevate", "robust", "comprehensive", "cutting-edge", "harness", "empower", "streamline", "revolutionize", "transform", "state-of-the-art".
SEARCH TERMS: where natural, use these real search terms in titles, descriptions and headings: ${GLOSSARY[locale] || 'none'}.

18. Search snippets override rules 1 to 5: a page title (a "title" or "pageTitle" next to a meta description, or any "title" inside a "seo" object) must stay at most 70 characters, and a meta description ("metaDescription", "seoDescription", or a "description" inside a "seo" object) must be 100 to 160 characters. A literal Japanese, Chinese, Korean or Thai description is often under 100 characters: add a relevant detail from the page rather than padding.`,
            },
            { role: 'user', content: jsonStr },
          ],
          temperature: 0.3,
        }),
      });

      clearTimeout(timeout);

      if (!response.ok) {
        const err = await response.text();
        throw new Error(`API ${response.status}: ${err}`);
      }

      const data = await response.json();
      let content = data.choices[0].message.content.trim();

      // Strip markdown fences if present
      if (content.startsWith('```')) {
        content = content.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
      }

      await sleep(DELAY_BETWEEN_CALLS_MS);
      progress.countApiCall();

      return JSON.parse(content);
    } catch (err) {
      if (attempt < retries) {
        const backoff = 2000 * (attempt + 1);
        console.warn(`  [${locale}] retry ${attempt + 1}/${retries} (wait ${backoff}ms): ${err.message}`);
        await sleep(backoff);
      } else {
        throw err;
      }
    }
  }
}

function createSemaphore(max) {
  let active = 0;
  const queue = [];
  return {
    async acquire() {
      if (active < max) {
        active++;
        return;
      }
      await new Promise((resolve) => queue.push(resolve));
      active++;
    },
    release() {
      active--;
      if (queue.length > 0) queue.shift()();
    },
  };
}

// ── Chunking for nested JSON ──────────────────────────────────────────────────

/**
 * Split a potentially large nested object into chunks that fit within MAX_CHUNK_BYTES.
 * Strategy: if the whole thing fits — one chunk. Otherwise, split by top-level keys.
 */
function chunkNestedObject(obj) {
  const fullSize = JSON.stringify(obj).length;
  if (fullSize <= MAX_CHUNK_BYTES * 1.25) return [obj];

  // Split top-level keys into chunks
  const chunks = [];
  let current = {};
  let currentSize = 2;

  for (const [key, val] of Object.entries(obj)) {
    const entrySize = JSON.stringify({ [key]: val }).length + 1;
    if (currentSize + entrySize > MAX_CHUNK_BYTES && Object.keys(current).length > 0) {
      chunks.push(current);
      current = {};
      currentSize = 2;
    }
    current[key] = val;
    currentSize += entrySize;
  }

  if (Object.keys(current).length > 0) chunks.push(current);
  return chunks;
}

// ── Per-locale processing ─────────────────────────────────────────────────────

async function processLocale(locale, enData, semaphore) {
  const locPath = path.join(LOCALES_DIR, `${locale}.json`);

  let locData = {};
  if (fs.existsSync(locPath)) {
    locData = JSON.parse(fs.readFileSync(locPath, 'utf8'));
  } else {
    console.log(`[${locale}] File missing — translating everything`);
  }

  // If --key flag: scope to a specific subtree
  let sourceToTranslate = enData;
  let targetForDiff = locData;
  if (flags.key) {
    sourceToTranslate = getByPath(enData, flags.key);
    if (sourceToTranslate === undefined) {
      console.log(`[${locale}] --key=${flags.key} not found in en.json, skipping`);
      return { locale, totalTranslated: 0, totalFailed: 0 };
    }
    targetForDiff = getByPath(locData, flags.key);
  }

  const missing = findMissingSubtree(sourceToTranslate, flags.force ? undefined : targetForDiff);

  if (missing === undefined || (typeof missing === 'object' && !Array.isArray(missing) && Object.keys(missing).length === 0)) {
    console.log(`[${locale}] Up to date.`);
    progress.finishLocale(locale);
    return { locale, totalTranslated: 0, totalFailed: 0, changed: false };
  }

  const keyCount = countLeaves(missing);

  if (flags.dryRun) {
    console.log(`[${locale}] [dry-run] Would translate ${keyCount} leaf values:`);
    console.log(JSON.stringify(missing, null, 2).split('\n').slice(0, 20).join('\n'));
    return { locale, totalTranslated: 0, totalFailed: 0, changed: false };
  }

  progress.startLocale(locale);

  const chunks = chunkNestedObject(typeof missing === 'object' && !Array.isArray(missing) ? missing : { _root: missing });
  let translatedMerge = {};
  let totalTranslated = 0;
  let totalFailed = 0;

  for (let i = 0; i < chunks.length; i++) {
    const chunkLeaves = countLeaves(chunks[i]);
    await semaphore.acquire();
    try {
      const translated = await translateJSON(chunks[i], locale);
      translatedMerge = deepMerge(translatedMerge, translated);
      totalTranslated += chunkLeaves;
      progress.updateLocale(locale, chunkLeaves, 0);
    } catch (err) {
      console.error(`  [${locale}] chunk ${i + 1}/${chunks.length} FAILED: ${err.message}`);
      totalFailed += chunkLeaves;
      progress.updateLocale(locale, 0, chunkLeaves);
    } finally {
      semaphore.release();
    }
  }

  // Merge translated data back
  if (flags.key) {
    const existing = getByPath(locData, flags.key);
    const merged = deepMerge(existing || {}, translatedMerge._root !== undefined ? translatedMerge._root : translatedMerge);
    setByPath(locData, flags.key, merged);
  } else {
    locData = deepMerge(locData, translatedMerge);
  }

  // Preserve EN key order at top level
  const ordered = reorderKeys(enData, locData);

  fs.writeFileSync(locPath, JSON.stringify(ordered, null, 2) + '\n');
  progress.finishLocale(locale);

  return { locale, totalTranslated, totalFailed, changed: true };
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  if (!fs.existsSync(EN_FILE)) {
    console.error(`ERROR: English source not found: ${EN_FILE}`);
    process.exit(1);
  }

  const enData = JSON.parse(fs.readFileSync(EN_FILE, 'utf8'));
  const allLocales = Object.keys(LOCALE_NAMES);

  // Determine target locales
  let targetLocales;
  if (flags.only) {
    targetLocales = flags.only.filter((l) => allLocales.includes(l));
  } else if (positionalLocales.length > 0) {
    targetLocales = positionalLocales;
  } else {
    targetLocales = allLocales;
  }

  if (targetLocales.length === 0) {
    console.log('No valid locales specified. Available:', allLocales.join(', '));
    process.exit(1);
  }

  console.log(`Target locales: ${targetLocales.join(', ')}`);
  if (flags.key) console.log(`Scoped to key: ${flags.key}`);
  if (flags.force) console.log('Force mode: retranslating existing keys');
  if (flags.dryRun) console.log('Dry-run mode: no files will be written');
  console.log();

  // Pre-flight: count missing leaves per locale
  const localeKeyCounts = {};
  let totalMissing = 0;

  for (const locale of targetLocales) {
    const locPath = path.join(LOCALES_DIR, `${locale}.json`);

    let locData = {};
    if (fs.existsSync(locPath)) {
      locData = JSON.parse(fs.readFileSync(locPath, 'utf8'));
    }

    let sourceToTranslate = enData;
    let targetForDiff = locData;
    if (flags.key) {
      sourceToTranslate = getByPath(enData, flags.key);
      targetForDiff = getByPath(locData, flags.key);
    }

    const missing = findMissingSubtree(sourceToTranslate, flags.force ? undefined : targetForDiff);
    const count =
      missing === undefined
        ? 0
        : typeof missing === 'object' && !Array.isArray(missing)
          ? countLeaves(missing)
          : countLeaves(missing);

    if (count > 0) {
      console.log(`  ${locale}: ${count} leaf values need translation`);
    }
    localeKeyCounts[locale] = count;
    totalMissing += count;
  }

  if (totalMissing === 0) {
    console.log('All translations are up to date.');
    process.exit(0);
  }

  if (!flags.dryRun) {
    progress.init(localeKeyCounts);
    console.log(`\nTranslating ${targetLocales.length} locales (${totalMissing} total leaf values)...\n`);
  }

  const semaphore = createSemaphore(MAX_CONCURRENT_API);
  const results = await Promise.all(targetLocales.map((locale) => processLocale(locale, enData, semaphore)));

  // Summary
  if (!flags.dryRun) {
    console.log('\n' + '='.repeat(50));
    console.log('Translation summary:');
    let anyFailed = false;

    for (const { locale, totalTranslated, totalFailed } of results) {
      if (totalTranslated > 0 || totalFailed > 0) {
        console.log(
          `  ${locale}: ${totalTranslated} translated${totalFailed > 0 ? `, ${totalFailed} FAILED` : ''}`
        );
      }
      if (totalFailed > 0) anyFailed = true;
    }
    console.log('='.repeat(50));

    if (anyFailed) {
      console.error('\nSome translations failed. Review the output above.');
      process.exit(1);
    }
  }
}

main()
  .then(() => console.log('\nDone.'))
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
