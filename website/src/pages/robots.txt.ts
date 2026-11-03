export const GET = () =>
  new Response("User-agent: *\nAllow: /\n\nSitemap: https://convcalc.app/sitemap.xml\n", { headers: { "Content-Type": "text/plain" } });
