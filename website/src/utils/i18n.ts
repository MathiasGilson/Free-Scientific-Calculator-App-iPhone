import en from "../locales/en.json";

export const locales = ["en", "fr", "de", "it", "pt", "nl", "es", "ru", "hi", "no", "sv", "ar", "zh", "ko", "th", "ja"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "en";
export const nonDefaultLocales = locales.filter((l) => l !== defaultLocale);
export const localeNames: Record<Locale, string> = {
  en: "English", fr: "Français", de: "Deutsch", it: "Italiano", pt: "Português", nl: "Nederlands", es: "Español", ru: "Русский",
  hi: "हिन्दी", no: "Norsk", sv: "Svenska", ar: "العربية", zh: "简体中文", ko: "한국어", th: "ไทย", ja: "日本語",
};
export const SITE = "https://convcalc.app";
export const APP_STORE = "https://apps.apple.com/app/convcalc-calculator-converter/id6472445974";
export const REPO = "https://github.com/MathiasGilson/Free-Scientific-Calculator-App-iPhone";

const files = import.meta.glob("../locales/*.json", { eager: true }) as Record<string, { default: typeof en }>;

function merge<T>(base: T, over: unknown): T {
  if (Array.isArray(base) || typeof base !== "object" || base === null) return (over ?? base) as T;
  const out: Record<string, unknown> = { ...(base as Record<string, unknown>) };
  for (const k of Object.keys(out)) out[k] = merge(out[k], (over as Record<string, unknown> | undefined)?.[k]);
  return out as T;
}

export const getTranslations = (locale: Locale) => merge(en, files[`../locales/${locale}.json`]?.default);
export const localizedPath = (locale: Locale, path: string) => {
  const p = path === "/" ? "" : path;
  return locale === defaultLocale ? path : `/${locale}${p}`;
};
export const localePaths = () => nonDefaultLocales.map((locale) => ({ params: { locale }, props: { locale } }));
export const isRtl = (locale: Locale) => locale === "ar";
