# ConvCalc website

Marketing site and free web tools for ConvCalc, at [convcalc.app](https://convcalc.app). Static Astro on Cloudflare Workers, with the same structure as Record Meeting's site.

```bash
npm install
npm run dev
npm test          # calculator engine, with cases from the Swift tests
npm run build     # fetches rates, type checks, builds
npm run verify    # checks every built page
```

- Copy lives in `src/locales/en.json`. Translate with `OPEN_ROUTER_API_KEY=... npm run translate`.
- Conversion pages come from `src/data/conversions.json`, top search volume first. Keyword data is in `docs/superpowers/specs/2026-11-02-convcalc-website/keywords/`. To add a batch, append pairs from `pairs.json`.
- `src/lib/engine.js` and `src/lib/tools.js` port the app's `ios/ConvCalc/Core`. Keep them in sync, including `test/engine-cases.json`.
- `src/data/apps.json` holds the dated App Store figures on the comparison pages. Recheck them and the descriptions in `takes` when you update it.
- Pushing to `master` deploys through `.github/workflows/deploy-website.yml`, which also rebuilds daily for fresh currency rates.
