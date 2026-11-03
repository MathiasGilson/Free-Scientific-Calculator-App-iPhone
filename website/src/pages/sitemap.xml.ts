import en from "../locales/en.json";
import { CONVERSIONS } from "../utils/conversions.js";
import { SITE, locales, localizedPath } from "../utils/i18n";

const core = ["/", "/tools", "/compare", ...Object.keys(en.tools).map((k) => `/tools/${k}`), ...Object.keys(en.features).map((k) => `/features/${k}`), ...Object.keys(en.compare).map((k) => `/compare/${k}`)];
const english = ["/convert", "/privacy", "/support", ...(CONVERSIONS as { slug: string }[]).map((c) => `/convert/${c.slug}`)];
const url = (p: string) => `${SITE}${p === "/" ? "" : p}`.replace(/\/$/, "") || SITE;

export const GET = () => {
  const rows = [
    ...core.flatMap((p) => locales.map((l) => url(localizedPath(l, p)))),
    ...english.map(url),
  ];
  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${rows.map((u) => `<url><loc>${u}</loc></url>`).join("\n")}\n</urlset>\n`;
  return new Response(xml, { headers: { "Content-Type": "application/xml" } });
};
