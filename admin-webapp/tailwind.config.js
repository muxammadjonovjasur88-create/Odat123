/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        tgBg: 'var(--tg-theme-bg-color, #0f172a)',
        tgText: 'var(--tg-theme-text-color, #f8fafc)',
        tgHint: 'var(--tg-theme-hint-color, #94a3b8)',
        tgLink: 'var(--tg-theme-link-color, #38bdf8)',
        tgButton: 'var(--tg-theme-button-color, #10b981)',
        tgButtonText: 'var(--tg-theme-button-text-color, #ffffff)',
        tgSecondaryBg: 'var(--tg-theme-secondary-bg-color, #1e293b)',
      },
    },
  },
  plugins: [],
}
