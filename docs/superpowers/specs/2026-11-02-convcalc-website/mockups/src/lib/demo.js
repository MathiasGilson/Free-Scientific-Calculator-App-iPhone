import { evaluate, fmt, pretty } from "./engine.js";
import { TOOLS } from "./tools.js";

function bindCalc(root) {
  const $ = (q) => root.querySelector(q);
  const exprEl = $("[data-expr]"), prevEl = $("[data-preview]"), keys = $("[data-keys]");
  if (!exprEl || !keys) return;
  let x = root.dataset.start || "", deg = true, inv = false, hyp = false, justEq = false;
  const hist = [];
  const paint = () => {
    exprEl.textContent = x ? pretty(x) : "0";
    exprEl.dataset.empty = x ? "0" : "1";
    let p = "";
    if (x && /[+\-*/^%!(a-z]/.test(x) && !justEq) { try { p = "= " + fmt(evaluate(x, deg)); } catch {} }
    if (prevEl) prevEl.textContent = p;
    root.querySelector("[data-backspace]")?.toggleAttribute("hidden", !x);
    exprEl.style.setProperty("--len", String(Math.max(pretty(x || "0").length, 1)));
  };
  const showHist = () => {
    const el = $("[data-history]"); if (!el) return;
    el.innerHTML = hist.length ? hist.map((h) => `<button type="button" data-h="${h[1]}"><span>${pretty(h[0])}</span><b>${h[1]}</b></button>`).reverse().join("") : "<p>Your calculations will show up here.</p>";
  };
  keys.addEventListener("click", (e) => {
    const b = e.target.closest("button"); if (!b) return;
    const v = b.dataset.v, a = b.dataset.a;
    if (a === "clear") { x = ""; }
    else if (a === "paren") { const o=(x.match(/\(/g)||[]).length-(x.match(/\)/g)||[]).length; x += o>0 && /[\d)!%ei]$/.test(x) ? ")" : "("; }
    else if (a === "eq") {
      try { const r = fmt(evaluate(x || "0", deg)); hist.push([x, r]); x = r; justEq = true; showHist(); paint(); root.dispatchEvent(new CustomEvent("calc:eq")); return; }
      catch { exprEl.animate?.([{transform:"translateX(-6px)"},{transform:"translateX(6px)"},{transform:"none"}],{duration:160}); return; }
    }
    else if (a === "expand") { root.toggleAttribute("data-expanded"); }
    else if (a === "deg") { deg = !deg; b.textContent = deg ? "DEG" : "RAD"; }
    else if (a === "inv") { inv = !inv; b.toggleAttribute("data-on", inv); fnLabels(); }
    else if (a === "hyp") { hyp = !hyp; b.toggleAttribute("data-on", hyp); fnLabels(); }
    else if (a === "rand") { x += String(Math.random().toFixed(6)); }
    else if (a === "fn") { x += `${inv?"a":""}${v}${hyp?"h":""}(`; }
    else { if (justEq && /[\d.]/.test(v)) x = ""; x += v; }
    justEq = false; paint();
  });
  const fnLabels = () => keys.querySelectorAll("[data-a=fn]").forEach((k) => { k.textContent = `${k.dataset.v}${hyp?"h":""}${inv?"⁻¹":""}`; });
  root.querySelector("[data-backspace]")?.addEventListener("click", () => { x = x.replace(/(a?(sin|cos|tan)h?\(|log10\(|log\(|sqrt\(|pi|.)$/, ""); justEq=false; paint(); });
  root.querySelector("[data-history-toggle]")?.addEventListener("click", () => { showHist(); root.toggleAttribute("data-history-open"); });
  $("[data-history]")?.addEventListener("click", (e) => { const b=e.target.closest("[data-h]"); if(b){x=b.dataset.h;root.removeAttribute("data-history-open");paint();} });
  root.__press = (seq) => seq.forEach((v, n) => setTimeout(() => keys.querySelector(`[data-v="${CSS.escape(v)}"],[data-a="${CSS.escape(v)}"]`)?.click(), n * 170));
  paint();
}

const RATES = { USD: 1, EUR: .9, GBP: .75, JPY: 158 };
const CUR = [["USD","US Dollar"],["EUR","Euro"],["GBP","British Pound Sterling"],["JPY","Japanese Yen"]];
let live = RATES, liveAt = "Sample rates";
fetch("https://open.er-api.com/v6/latest/USD").then((r) => r.json()).then((d) => { if (d.result === "success") { live = d.rates; liveAt = "Live rates, updated today"; document.dispatchEvent(new Event("rates")); } }).catch(() => {});

function bindDemo(root) {
  const views = root.querySelectorAll("[data-view]");
  const list = root.querySelector("[data-rows]"), shot = root.querySelector("[data-shot]"), pad = root.querySelector("[data-numpad]"), note = root.querySelector("[data-rate-note]");
  let tool = "length", active = 0, val = "1";
  const show = (name) => { views.forEach((v) => v.toggleAttribute("hidden", v.dataset.view !== name)); root.querySelectorAll("[data-tab]").forEach((t) => t.setAttribute("aria-pressed", String(t.dataset.tab === name || (name === "tool" && t.dataset.tab === "grid") || (name==="shot" && t.dataset.tab==="grid")))); };
  const rows = () => {
    const n = parseFloat(val) || 0;
    if (tool === "currency") {
      const base = n / (live[CUR[active][0]] || 1);
      note.textContent = liveAt;
      list.innerHTML = CUR.map(([c, name], i) => `<button type="button" class="r cur ${i===active?"on":""}" data-i="${i}"><span class="n">${c}</span><span class="v"><b>${i===active?val:String(+(base*(live[c]||1)).toFixed(live[c]>50?0:2))}</b><small>${name}</small></span></button>`).join("");
      return;
    }
    note.textContent = "";
    const us = TOOLS[tool].units, b = us[active].to(n);
    list.innerHTML = us.map((u, i) => `<button type="button" class="r ${i===active?"on":""}" data-i="${i}"><span class="n">${u.name}</span><span class="v"><b>${i===active?val:fmt(u.from(b))}</b><small>${u.label}</small></span></button>`).join("");
  };
  root.querySelectorAll("[data-open]").forEach((b) => b.addEventListener("click", () => open(b.dataset.open, b.dataset.shotname)));
  const open = (k, s) => {
    if (s) { shot.src = `/shots/${s}.jpg`; show("shot"); return; }
    tool = k; active = 0; val = "1"; show("tool"); rows();
    if (root.dataset.scroll && innerWidth < 900) root.querySelector("[data-phone]")?.scrollIntoView({behavior:"smooth",block:"center"});
  };
  root.querySelectorAll("[data-tab]").forEach((t) => t.addEventListener("click", () => { const n=t.dataset.tab; n==="currency"?open("currency"):show(n); }));
  list?.addEventListener("click", (e) => { const b=e.target.closest("[data-i]"); if(!b)return; active=+b.dataset.i; val="1"; rows(); });
  pad?.addEventListener("click", (e) => { const b=e.target.closest("button"); if(!b)return; const v=b.dataset.n;
    if(v==="ac")val="0"; else if(v==="bk")val=val.slice(0,-1)||"0"; else if(v==="."){if(!val.includes("."))val+=".";} else val=val==="0"?v:val+v; rows(); });
  root.querySelector("[data-back]")?.addEventListener("click",()=>show("grid"));
  root.querySelector("[data-shot-back]")?.addEventListener("click",()=>show("grid"));
  document.addEventListener("rates",()=>{ if(tool==="currency")rows(); });
  show(root.dataset.initial || "calc"); rows();
}
document.querySelectorAll("[data-calc]").forEach(bindCalc);
document.querySelectorAll("[data-demo]").forEach(bindDemo);

// Scripted first impression: only runs once, skipped for reduced motion.
const auto = document.querySelector("[data-autoplay]");
if (auto && !matchMedia("(prefers-reduced-motion: reduce)").matches) setTimeout(() => auto.__press?.(JSON.parse(auto.dataset.autoplay)), 700);

// Drag handle for the before/after comparison.
document.querySelectorAll("[data-wipe]").forEach((w) => {
  const set = (cx) => { const r=w.getBoundingClientRect(); const p=Math.min(96,Math.max(4,((cx-r.left)/r.width)*100)); w.style.setProperty("--p",p+"%"); };
  let d=false; const h=w.querySelector("[data-handle]");
  w.addEventListener("pointerdown",(e)=>{ if(e.target.closest("button:not([data-handle])"))return; d=true; w.setPointerCapture(e.pointerId); set(e.clientX); });
  w.addEventListener("pointermove",(e)=>d&&set(e.clientX));
  w.addEventListener("pointerup",()=>d=false);
  h?.addEventListener("keydown",(e)=>{ const cur=parseFloat(getComputedStyle(w).getPropertyValue("--p"))||50; if(e.key==="ArrowLeft")w.style.setProperty("--p",Math.max(4,cur-4)+"%"); if(e.key==="ArrowRight")w.style.setProperty("--p",Math.min(96,cur+4)+"%"); });
});
