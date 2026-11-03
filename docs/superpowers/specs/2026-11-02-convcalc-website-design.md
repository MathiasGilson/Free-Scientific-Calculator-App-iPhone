# ConvCalc website design

Date: 2026-11-02. Status: built and deployed at Mathias's request on 2026-11-03. See "As built" at the end.

## Intent

Mathias wants to find out how much search traffic and how many App Store installs a free app can earn. Monetization may come later and does not shape this work.

The motivation is personal: Mathias thinks every calculator on iOS is badly designed and ConvCalc looks better. The site should make that argument on sight, not only collect keywords. Someone landing on it should feel the difference within seconds.

Success means installs. Traffic matters only where it can lead to installs.

## Goals

- Rank for every search term the app can honestly serve, in multiple languages. Core pages launch in all 16 languages; conversion pages expand in stages.
- Show the design through a small, working demo of the app's features.
- Reuse Record Meeting's website architecture so the site is familiar to maintain.

## Non-goals

- Monetization, accounts, or anything on the site that requires a server at request time.
- Localizing the iOS app. It is English only on the App Store. This may be a follow-up.
- A blog at launch. Comparison and feature pages cover that intent for now.

## Anti-goals

What would make this a failure even if it technically works:

- A site that looks like a templated SEO farm. It would contradict the entire argument.
- Any claim the SwiftUI app can't back up: no widgets, Siri, iPad, Apple Watch, tip calculator, graphing, or RPN.
- Fabricated comparison facts or reviews, or hiding that we make the app we rank first.
- Demo results that differ from the app's results. For currency this covers arithmetic only, since rates come from a different source and may differ. Currency pages must not say they match the app.
- Pages that exist only to hold a keyword. Every page must do something useful.

## Decisions Mathias made

| Decision | Choice |
|---|---|
| Domain | `convcalc.app`, already on Cloudflare |
| Hosting | Cloudflare Workers, personal account `4e58baf2fc785a7d928f35b2433e86f8` |
| Architecture | Same as Record Meeting's site |
| App version advertised | The new SwiftUI version only, not 1.0.6 |
| Visual direction | Direction A, "the keys are the page" |
| Hero display | No backspace button; removed entirely |
| Launch size | About 640 pages, then staged expansion |
| Keyword source | Google Keyword Planner |
| Named page | A "best calculator for iOS 2027" page is required |
| CI runners | Default GitHub-hosted runners |
| Analytics | PostHog, configured like Record Meeting, in a new project on Qualtir's self-hosted PostHog |

## Calls I made, for Mathias to check

- The site replaces the existing `website/` directory in this repo. Its old `convcalc.com` URLs are wrong because that domain isn't ours, and its GitHub link points to someone else's repository.
- Multi-language pages are built from English sources by machine translation with Record Meeting's script, followed by the checks below.
- The launch page set, the expansion trigger, and currency handling below.
- 16 languages, matching Record Meeting, including thin-data ones like Norwegian and Swedish.
- Copied test cases, currency matching on arithmetic only, static daily rates, Simplified Chinese, and a preview-first launch, as described below.

## Dependency on the app release

The site advertises the SwiftUI version, which at the time of writing was still being merged from `rewrite-swiftui-native`. App Review also takes time. Production launch waits until that version is live on the App Store, so visitors never install 1.0.6 after seeing the new design. The work can merge and deploy before that, behind a build flag that sets `noindex` on all pages and blocks crawling in `robots.txt`. This plan ends at that deployed preview plus a launch checklist. Mathias confirms the release and triggers the launch, which flips the flag, submits sitemaps and captures final screenshots if the UI changed.

## Architecture

Follow `RecordMeeting/src/website` and its `CLAUDE.md`. Read them rather than guessing.

- Astro 5 static output, `trailingSlash: 'never'`, Tailwind 4, TypeScript, no client framework. Interactivity uses `<script>` in Astro components.
- 16 locales: `en, fr, de, it, pt, nl, es, ru, hi, no, sv, ar, zh, ko, th, ja`. English has no URL prefix; the rest are prefixed. Arabic must render right to left.
- Page content lives in reusable components taking a `locale` prop, with thin files in `src/pages/` and `src/pages/[locale]/`.
- `src/locales/*.json` with `en.json` as the source of truth, loaded through a `src/utils/i18n.ts` modeled on Record Meeting's. Slugs stay English across locales.
- Canonical and `hreflang` tags including `x-default`, split sitemaps, generated Open Graph images, IndexNow after deploy, and terser stripping console output.
- `wrangler.jsonc` deploys `dist` as Workers static assets on `convcalc.app`, with `_worker.js` only if redirects need it.
- GitHub Actions deploy on push to the default branch, for changes under `website/`, modeled on Record Meeting's `deploy-website.yml`. Use GitHub-hosted runners (`ubuntu-24.04`), not Blacksmith: Mathias decided this because Blacksmith doesn't work with personal accounts, and this repo is on the personal `MathiasGilson` account. The repository's default branch is `master`. The repo has no Actions secrets yet, so the Cloudflare API token for the personal account is obtained from Mathias through a secret request.

The Record Meeting pieces that don't apply (reviews, webapp, ads landing pages, blog pipeline, signed-in redirect) should not be copied.

## Pages at launch

About 642 pages.

**Core pages, about 30, in all 16 languages (about 480):**

- Home.
- Tools hub and 20 tool pages: currency, length, area, mass, volume, speed, pressure, power, temperature, angle, energy, force, fuel, time, data, age, BMI, date, discount, loan.
- Feature pages: scientific calculator, calculator with history, calculator with no ads.
- Comparison hub and: best calculator apps for iPhone in 2027, best free calculator apps for iPhone, best scientific calculator apps for iPhone, ConvCalc versus Apple Calculator.

**English only (about 162):**

- Top 160 conversions by US volume, under `/convert/<a>-to-<b>`. Listed in `2026-11-02-convcalc-website/keywords/pairs.json`, the first 160 rows. Current split: length 39, currency 26, volume 24, mass 18, time 13, data 10, temperature 6, area 6, speed 5, pressure 5, energy 3, angle 2, force 2, power 1.
- Privacy and support. Non-English URLs aren't generated for these.

A conversions hub linking to these pages is included and counted in the approximate total.

**After launch:** every two to four weeks, check Search Console. Add the next batch of conversions, in English and in languages showing traction, once most existing pages are indexed. If they aren't, improve the pages rather than adding more. Long-term reach is 532 pairs across 16 languages.

Bare `calculator`-only pages for terms the app can't serve, such as graphing or construction calculators, are out.

## Keyword research

Raw data is in `docs/superpowers/specs/2026-11-02-convcalc-website/keywords/`:

- `ideas.json`: Keyword Planner ideas per locale, `{k: keyword, v: monthly searches, c: competition}`.
- `pairs.json`: US English volume for 532 conversion pairs built from the app's real units, `{k, t: tool, v}`.

Method: Google Ads API v24 `generateKeywordIdeas` and `generateKeywordHistoricalMetrics`, account `755-822-2292`, credentials via `CLOUDSDK_CONFIG=~/.config/gcloud-qualtir-ads`. Read only.

Findings that shape the site:

- 532 pairs total 23.25M US searches per month. The top 160 hold 97% of that and the top 329 almost all of it.
- `age calculator` and `date calculator` are 673K each. `percent off calculator` is 40.5K and `discount calculator` 33.1K.
- Install-intent terms are far smaller: iPhone, iOS and iPad calculator terms total 19.9K; "best" terms 8.8K.
- `best calculator app for iphone 2022` shows 0 searches, so year pages are for intent rather than volume.
- Google answers many conversion searches directly on the results page, and the domain is new. Volumes are an upper bound on demand, not a traffic forecast.
- The app is iPhone only (`TARGETED_DEVICE_FAMILY = 1`), so iPad terms are excluded even though the research surfaced them.
- Non-US data covers only the seeds tried. `zh` is Simplified Chinese, matching Record Meeting, but it was researched in Traditional Chinese for Taiwan and Hong Kong, so that data can't supply its titles. Traditional Chinese is a possible later locale. Each other locale's title and description should use that locale's real terms from `ideas.json` where they fit the page, not a literal translation of English.

## Visual design

Mockups are in `docs/superpowers/specs/2026-11-02-convcalc-website/mockups/` and run with `npm install && npm run dev`. `src/pages/a.astro`, `best-calculator-app-iphone.astro` and `convert/cm-to-inches.astro` are the reference. Directions B and C were rejected. The mockups are throwaway reference, not code to ship: production uses the architecture above and self-hosted fonts.

- True black background. Amber `#F59905` for accents and input, `#CC7A00` for the primary button and the equals key.
- Keys: number `#2B2B2B`, secondary `#171717`, operator `#3B2401`, thin translucent edges, squircle corners.
- Instrument Sans for page type; SF on Apple devices and Inter elsewhere inside the app surface. Locales whose scripts these fonts don't cover need suitable fallbacks.
- Home hero: a full-width display that fills with a scripted calculation, a working keypad at the right, and the headline "Calculators on iOS look terrible. This one doesn't." No phone frame in the hero. Motion runs once and respects reduced motion.
- Below the hero: a tool grid that opens tools on a live phone, then real app screenshots with captions.
- User-facing copy has no em dashes, is sentence case, and is plain and direct.

Screenshots must be real captures from the released SwiftUI app. The `CONVCALC_DEBUG_ROUTE` environment variable opens each screen in the simulator. The form-based tools (age, BMI, date, discount, loan) are screenshots in the mockup, but their pages need working calculators.

## Demo and calculator behavior

The site ships its own TypeScript port. `ios/ConvCalc/Core/CalculatorEngine.swift` and `ConverterCore.swift` are the source of truth for grammar, unit factors, formatting, and the calculators' formulas. The mockup's `src/lib/engine.js` and `tools.js` are a starting point only and are incomplete.

Add tests under `website/` with cases copied from `ios/ConvCalcTests/CalculatorEngineTests.swift`. This is the one place tests are required, because "same answers as the app" is a promise. A copy won't notice later app changes, so any change to those Swift files needs the tests rechecked by hand; a shared fixture or Swift CI job can come later.

## Page content rules

**Conversion pages** contain a working converter, the formula in plain words, a chart of useful values, a worked example chosen for that pair, related conversions, and a call to action showing the matching app screen. Generate values from the engine, never by hand. Worked examples and common values must vary by pair so pages aren't identical apart from numbers.

**Currency pages** use a build-time rate snapshot in the HTML, labeled with its date, with no browser calls to a rates provider, so visitors' IP addresses aren't sent to a third party. A scheduled workflow rebuilds daily so the numbers stay current. The rates provider's terms and attribution must be checked before launch. They must say rates are for reference only. The app's own rates endpoint is not to be reused.

**Comparison pages** must:

- State on the page that we make ConvCalc.
- Date all prices and ratings, sourced from the iTunes Search API at build time or from a dated data file, including ConvCalc's own small rating count (4.8 from 5 at the time of writing).
- Verify every descriptive statement against the app's current listing or the developer's documentation before publishing. The mockup's descriptions and its "most built in for free" line are unverified drafts.
- Be fair to competitors. Criticize only what's checkable; design opinions are labeled as our opinion.

The site's "no ads" and "free" claims are backed by the current code, which has no ad, analytics or purchase SDKs. Recheck this at launch. Do not claim "no tracking" unless the privacy policy and `PrivacyInfo.xcprivacy` agree. The site uses PostHog (see Analytics), and the privacy policy must describe it accurately.

Every page has a working App Store link: `https://apps.apple.com/app/convcalc-calculator-converter/id6472445974`. The source repository is `MathiasGilson/Free-Scientific-Calculator-App-iPhone`.

Add `SoftwareApplication` structured data on app pages. Do not add review or rating markup on comparison pages. Do not mark up our own ranking as a review of ourselves.

## Analytics

PostHog, matching `RecordMeeting/src/website/src/layouts/Layout.astro`, in a new dedicated project on Qualtir's self-hosted instance. See `Qualtir-PostHog` and `RecordMeeting/docs/architecture/infra/external-services.md`.

- Create the project during the build and use its public `phc_` key. Don't reuse Record Meeting's key.
- `api_host: https://analytics.qualtir.com`, `person_profiles: "identified_only"`, `persistence: "localStorage+cookie"`, `capture_pageview: true`, session recording off, web vitals off in the SDK config, and `posthog.register({ source: "website" })`.
- A `before_send` drops all events on `localhost` and `127.0.0.1`.
- Copy first-touch attribution using a ConvCalc-specific storage key. Leave out Record Meeting's webapp, sign-in and ads funnel code, which has no equivalent here.
- Add one custom event for App Store link clicks, with page type, page slug and locale. It measures interest in installing, not installs.

Confirm the new project receives the `strip-pii` transformation that the instance's `upgrade.sh` applies to every team.

## Translation

Use Record Meeting's `translate-locales.mjs` approach through OpenRouter. The key is stored in Mathias's Keychain, which agents are blocked from reading by a local hook. Obtain it from Mathias through a secret request at that step; never ask for it in chat.

Run a dry run first, because this is a paid API. Verify output for: mismatched placeholders, untranslated strings, altered numbers or units, right-to-left layout in Arabic, and text overflow in CJK, Thai and Hindi. A locale that fails stays `noindex` with a canonical to English until fixed.

## Open items left to the builder

- Copy, beyond the rules above, and the exact file layout.
- Branch name and how the work is split into commits or PRs. Another session is changing app files on `rewrite-swiftui-native`, so build the site on its own branch and don't touch files outside `website/` and the deploy workflow.

## Verification before launch

- `astro check` and build pass; engine tests pass.
- Browser checks on desktop and mobile for the home page and one page of each type, in English, Arabic and one CJK locale.
- Automated checks on every built page: one `h1`, a unique title and description, correct canonical and `hreflang`, no broken internal links, App Store link present.
- Lighthouse or equivalent on the home page and a conversion page.
- CI green on the deployed commit, then `convcalc.app` serving the expected commit. Per the global rules, a production deploy requires a local CI gate and green CI, and Search Console setup needs Mathias's access.

## As built

Mathias asked to ship on 2026-11-03, ahead of the App Store release. Differences from the sections above:

- The site launched indexable rather than behind a preview flag. The live 1.0.6 has the same tools, so the site's claims hold, but its screenshots show the SwiftUI version.
- One shared Open Graph image instead of one per page, and plain CSS instead of Tailwind.
- A GitHub issues link instead of a contact email, because contact details weren't provided.
- App Store links aren't campaign tagged, because no provider token was provided. PostHog records App Store clicks only.

Still open: the Impressum and contact details, and campaign tagging.
