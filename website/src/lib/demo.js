import { evaluate, fmt, pretty, nextParenthesis, addDecimalPoint, appendValue, appendFactor, bmi, age, dateDiff, loan, discount } from "./engine.js";
import { TOOLS } from "./tools.js";
import rates from "../data/rates.json";

function bindCalc(root) {
  const $ = (q) => root.querySelector(q);
  const exprEl = $("[data-expr]"), prevEl = $("[data-preview]"), keys = $("[data-keys]");
  if (!exprEl || !keys) return;
  let x = "", deg = true, inv = false, hyp = false, justEq = false;
  const hist = [];
  const paint = () => {
    exprEl.textContent = x ? pretty(x) : "0";
    exprEl.dataset.empty = x ? "0" : "1";
    let p = "";
    if (x && /[+\-*/^%!(a-z]/.test(x) && !justEq) {
      try { p = "= " + fmt(evaluate(x, deg)); } catch {}
    }
    if (prevEl) prevEl.textContent = p;
    root.querySelector("[data-backspace]")?.toggleAttribute("hidden", !x);
    exprEl.style.setProperty("--len", String(Math.max(pretty(x || "0").length, 1)));
  };
  const showHist = () => {
    const el = $("[data-history]");
    if (!el) return;
    el.innerHTML = hist.length
      ? hist.map((h) => `<button type="button" data-h="${h[2]}"><span>${pretty(h[0])}</span><b>${h[1]}</b></button>`).reverse().join("")
      : `<p>${el.dataset.empty}</p>`;
  };
  const fnLabels = () => keys.querySelectorAll("[data-a=fn]").forEach((k) => { k.textContent = `${k.dataset.v}${hyp ? "h" : ""}${inv ? "⁻¹" : ""}`; });
  keys.addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    const v = b.dataset.v, a = b.dataset.a;
    if (a === "clear") x = "";
    else if (a === "paren") x += nextParenthesis(x);
    else if (a === "eq") {
      try {
        const r = evaluate(x || "0", deg);
        hist.push([x, fmt(r), String(r)]);
        x = String(r);
        justEq = true;
        showHist();
        paint();
      } catch {
        exprEl.animate?.([{ transform: "translateX(-6px)" }, { transform: "translateX(6px)" }, { transform: "none" }], { duration: 160 });
      }
      return;
    }
    else if (a === "expand") root.toggleAttribute("data-expanded");
    else if (a === "deg") { deg = !deg; b.textContent = deg ? "DEG" : "RAD"; }
    else if (a === "inv") { inv = !inv; b.toggleAttribute("data-on", inv); fnLabels(); }
    else if (a === "hyp") { hyp = !hyp; b.toggleAttribute("data-on", hyp); fnLabels(); }
    else if (a === "rand") { if (justEq) x = ""; x = appendFactor(x, Math.random().toFixed(6)); }
    else if (a === "fn") { if (justEq) x = ""; x = appendFactor(x, `${inv ? "a" : ""}${v}${hyp ? "h" : ""}(`); }
    else if (v === ".") { if (justEq) x = ""; x = addDecimalPoint(x); }
    else if (v === "1/" || v === "pi" || v === "e" || v === "sqrt(" || v === "log(" || v === "log10(") { if (justEq) x = ""; x = appendFactor(x, v); }
    else { if (justEq && /\d/.test(v)) x = ""; x = appendValue(x, v); }
    justEq = false;
    paint();
  });
  root.querySelector("[data-backspace]")?.addEventListener("click", () => {
    x = x.replace(/(a?(sin|cos|tan)h?\(|log10\(|log\(|sqrt\(|pi|.)$/, "");
    justEq = false;
    paint();
  });
  root.querySelector("[data-history-toggle]")?.addEventListener("click", () => { showHist(); root.toggleAttribute("data-history-open"); });
  $("[data-history]")?.addEventListener("click", (e) => {
    const b = e.target.closest("[data-h]");
    if (b) { x = b.dataset.h; root.removeAttribute("data-history-open"); paint(); }
  });
  root.__press = (seq) => seq.forEach((v, n) => setTimeout(() => keys.querySelector(`[data-v="${CSS.escape(v)}"],[data-a="${CSS.escape(v)}"]`)?.click(), n * 170));
  paint();
}

const CUR = ["USD", "EUR", "GBP", "JPY"];
const FORMS = {
  age: { fields: [["year", "1990"], ["month", "1"], ["day", "1"]] },
  bmi: { fields: [["height", "170"], ["weight", "70"]] },
  date: { fields: [["year1", "2026"], ["month1", "1"], ["day1", "1"], ["year2", "2027"], ["month2", "1"], ["day2", "1"]] },
  discount: { fields: [["price", "100"], ["percent", "20"]] },
  loan: { fields: [["principal", "100000"], ["rate", "5"], ["years", "30"]] },
};

function bindDemo(root) {
  const L = JSON.parse(root.dataset.i18n);
  const views = root.querySelectorAll("[data-view]");
  const list = root.querySelector("[data-rows]"), pad = root.querySelector("[data-numpad]"), note = root.querySelector("[data-rate-note]");
  let tool = root.dataset.tool || "length", active = 0, val = "1", form = [], typed = false;
  const show = (name) => {
    views.forEach((v) => v.toggleAttribute("hidden", v.dataset.view !== name));
    root.querySelectorAll("[data-tab]").forEach((t) => t.setAttribute("aria-pressed", String(t.dataset.tab === name || (name === "tool" && t.dataset.tab === (tool === "currency" ? "currency" : "grid")))));
  };
  const result = () => {
    const n = form.map((s) => parseFloat(s));
    const row = (k, v) => `<div class="out"><i>${L.labels[k]}</i><b>${v}</b></div>`;
    const money = (v) => fmt(v);
    // Value above its unit, so no language needs singular and plural forms here.
    const split = (k, parts) => `<div class="out"><i>${L.labels[k]}</i><div class="parts">${parts.map(([v, u]) => `<span><b>${fmt(v)}</b><small>${L.labels[u]}</small></span>`).join("")}</div></div>`;
    if (tool === "bmi") { const r = bmi(n[0], n[1]); return r && row("bmi", `${r.bmi} - ${L.labels[r.category]}`); }
    if (tool === "age") { const r = age(n[0], n[1], n[2]); return r && split("age", [[r.years, "yearsUnit"], [r.months, "monthsUnit"], [r.days, "daysUnit"]]); }
    if (tool === "date") { const r = dateDiff(n[0], n[1], n[2], n[3], n[4], n[5]); return r && split("difference", [[r.totalDays, "daysUnit"], [r.weeks, "weeksUnit"], [r.months, "monthsUnit"], [r.years, "yearsUnit"]]); }
    if (tool === "discount") { const r = discount(n[0], n[1]); return r && row("savings", money(r.savings)) + row("finalPrice", money(r.finalPrice)); }
    if (tool === "loan") { const r = loan(n[0], n[1], n[2]); return r && row("monthly", money(r.monthly)) + row("totalPaid", money(r.totalPaid)) + row("totalInterest", money(r.totalInterest)); }
    return "";
  };
  const rows = () => {
    note.textContent = "";
    if (FORMS[tool]) {
      list.innerHTML = FORMS[tool].fields.map(([k], i) => `<button type="button" class="r ${i === active ? "on" : ""}" data-i="${i}"><span class="n">${L.labels[k]}</span><span class="v"><b>${form[i]}</b></span></button>`).join("") + `<div class="outs">${result() || ""}</div>`;
      return;
    }
    const n = parseFloat(val) || 0;
    if (tool === "currency") {
      const base = n / (rates.rates[CUR[active]] || 1);
      note.textContent = L.rateNote.replace("{date}", rates.date);
      list.innerHTML = CUR.map((c, i) => `<button type="button" class="r cur ${i === active ? "on" : ""}" data-i="${i}"><span class="n">${c}</span><span class="v"><b>${i === active ? val : fmt(+(base * rates.rates[c]).toFixed(rates.rates[c] > 50 ? 0 : 2))}</b><small>${L.currencies[c]}</small></span></button>`).join("");
      return;
    }
    const us = TOOLS[tool].units, b = us[active].to(n);
    list.innerHTML = us.map((u, i) => `<button type="button" class="r ${i === active ? "on" : ""}" data-i="${i}"><span class="n">${L.units[u.name] || u.name}</span><span class="v"><b>${i === active ? val : fmt(u.from(b))}</b><small>${u.label}</small></span></button>`).join("");
  };
  const open = (k) => {
    tool = k; active = 0; val = "1"; typed = false;
    form = FORMS[k] ? FORMS[k].fields.map((f) => f[1]) : [];
    show("tool");
    rows();
  };
  root.querySelectorAll("[data-open]").forEach((b) => b.addEventListener("click", () => {
    open(b.dataset.open);
    if (innerWidth < 900) root.querySelector("[data-phone]")?.scrollIntoView({ behavior: "smooth", block: "center" });
  }));
  root.querySelectorAll("[data-tab]").forEach((t) => t.addEventListener("click", () => { const n = t.dataset.tab; n === "currency" ? open("currency") : show(n); }));
  list?.addEventListener("click", (e) => { const b = e.target.closest("[data-i]"); if (!b) return; active = +b.dataset.i; typed = false; if (!FORMS[tool]) val = "1"; rows(); });
  pad?.addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    const v = b.dataset.n;
    let cur = FORMS[tool] ? form[active] : val;
    if (v === "ac") cur = "0";
    else if (v === "bk") cur = cur.slice(0, -1) || "0";
    else if (v === ".") { if (!typed) cur = "0."; else if (!cur.includes(".")) cur += "."; }
    else cur = !typed || cur === "0" ? v : cur + v;
    typed = v !== "ac";
    if (FORMS[tool]) form[active] = cur; else val = cur;
    rows();
  });
  root.querySelector("[data-back]")?.addEventListener("click", () => show("grid"));
  if (root.dataset.tool) open(root.dataset.tool); else { show(root.dataset.initial || "calc"); }
}

document.querySelectorAll("[data-calc]").forEach(bindCalc);
document.querySelectorAll("[data-demo]").forEach(bindDemo);

// Scripted first impression: runs once, skipped for reduced motion.
const auto = document.querySelector("[data-autoplay]");
if (auto && !matchMedia("(prefers-reduced-motion: reduce)").matches) setTimeout(() => auto.__press?.(JSON.parse(auto.dataset.autoplay)), 700);
