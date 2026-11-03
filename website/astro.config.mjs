import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://convcalc.app',
  output: 'static',
  trailingSlash: 'never',
  devToolbar: { enabled: false },
  build: { format: 'file', inlineStylesheets: 'never' },
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'fr', 'de', 'it', 'pt', 'nl', 'es', 'ru', 'hi', 'no', 'sv', 'ar', 'zh', 'ko', 'th', 'ja'],
    routing: { prefixDefaultLocale: false },
  },
  vite: {
    build: {
      minify: 'terser',
      cssMinify: true,
      terserOptions: { compress: { drop_console: true, drop_debugger: true }, format: { comments: false } },
    },
  },
});
