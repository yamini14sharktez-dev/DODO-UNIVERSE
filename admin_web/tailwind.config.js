/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        pine: {
          50: '#f2f8f5',
          100: '#e1efe8',
          200: '#c5e1d4',
          300: '#9bceb9',
          400: '#6bb497',
          500: '#469777',
          600: '#347b5f',
          700: '#2D6A4F', // Primary Scandinavian Pine
          800: '#265440',
          900: '#214636',
          950: '#0e261d',
        },
      },
    },
  },
  plugins: [],
}
