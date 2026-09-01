/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        tgBg: 'var(--tg-theme-bg-color, #051424)',
        tgText: 'var(--tg-theme-text-color, #D4E4FA)',
        tgHint: 'var(--tg-theme-hint-color, #85967C)',
        tgLink: 'var(--tg-theme-link-color, #00F3FF)',
        tgButton: 'var(--tg-theme-button-color, #39FF14)',
        tgButtonText: 'var(--tg-theme-button-text-color, #053900)',
        tgSecondaryBg: 'var(--tg-theme-secondary-bg-color, #0D1C2D)',
        zen: {
          void: '#051424',
          surface: '#0D1C2D',
          muted: '#122131',
          border: '#273647',
          lime: '#39FF14',
          cyan: '#00F3FF',
          jade: '#2DD4BF',
          emerald: '#52B788',
          gold: '#D4A373',
          text: '#D4E4FA',
          subtext: '#BACCB0',
        },
      },
      boxShadow: {
        'glow-lime': '0 0 25px -5px rgba(57, 255, 20, 0.35)',
        'glow-cyan': '0 0 25px -5px rgba(0, 243, 255, 0.35)',
        'glass-card': '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
      },
      animation: {
        'pulse-glow': 'pulseGlow 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'float': 'float 6s ease-in-out infinite',
      },
      keyframes: {
        pulseGlow: {
          '0%, 100%': { opacity: 0.8, filter: 'drop-shadow(0 0 12px rgba(57,255,20,0.6))' },
          '50%': { opacity: 0.4, filter: 'drop-shadow(0 0 4px rgba(0,243,255,0.3))' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-6px)' },
        }
      }
    },
  },
  plugins: [],
}
