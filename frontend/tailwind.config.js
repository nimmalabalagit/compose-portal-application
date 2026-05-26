/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Dark command center palette
        slate: {
          950: '#0A0E1A',   // Main background
          900: '#0F1629',   // Card background
          800: '#1A2235',   // Elevated surfaces
          700: '#243047',   // Borders/dividers
          600: '#3D4F6B',   // Muted elements
          400: '#8B9DBF',   // Secondary text
          200: '#C5CEDF',   // Primary text
          100: '#E2E8F0',   // High-contrast text
        },
        cyan: {
          500: '#00D4FF',   // Electric primary
          400: '#33DEFF',
          300: '#66E8FF',
          900: '#003D4D',   // Subtle cyan bg
        },
        amber: {
          500: '#F59E0B',   // Warning/alerts
          400: '#FBBF24',
          900: '#451A03',
        },
        emerald: {
          500: '#10B981',   // Success states
          400: '#34D399',
          900: '#022C22',
        },
        rose: {
          500: '#F43F5E',   // Error states
          400: '#FB7185',
          900: '#1F0A0D',
        },
      },
      fontFamily: {
        // JetBrains Mono for data/metrics (monospace precision)
        mono: ['JetBrains Mono', 'Fira Code', 'monospace'],
        // Syne for headings (distinctive, editorial)
        display: ['Syne', 'system-ui', 'sans-serif'],
        // IBM Plex Sans for body (clear, technical)
        sans: ['IBM Plex Sans', 'system-ui', 'sans-serif'],
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'scan': 'scan 8s linear infinite',
      },
      keyframes: {
        scan: {
          '0%': { transform: 'translateY(-100%)' },
          '100%': { transform: 'translateY(100vh)' },
        }
      }
    },
  },
  plugins: [],
};