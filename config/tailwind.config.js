module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'],
      },
      colors: {
        // Dark theme palette - OKLCH format
        dark: {
          50: 'oklch(98% 0.01 260)',
          100: 'oklch(96% 0.01 260)',
          200: 'oklch(91% 0.02 260)',
          300: 'oklch(85% 0.02 260)',
          400: 'oklch(70% 0.03 260)',
          500: 'oklch(55% 0.04 260)',
          600: 'oklch(43% 0.04 260)',
          700: 'oklch(33% 0.04 260)',
          800: 'oklch(23% 0.04 260)',
          850: 'oklch(19% 0.04 260)',
          900: 'oklch(15% 0.04 260)',
          950: 'oklch(11% 0.04 260)',
        },
        accent: {
          50: 'oklch(97% 0.02 260)',
          100: 'oklch(93% 0.05 260)',
          200: 'oklch(87% 0.08 260)',
          300: 'oklch(78% 0.13 260)',
          400: 'oklch(70% 0.17 260)',
          500: 'oklch(62% 0.21 260)',
          600: 'oklch(55% 0.22 260)',
          700: 'oklch(48% 0.22 260)',
        },
      },
    },
  },
  plugins: []
}
