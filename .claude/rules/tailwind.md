# Tailwind CSS 4 Standards

## Configuration Location

**All Tailwind configuration lives in CSS:**

```
app/assets/tailwind/application.css
```

There is **no JavaScript config file**. Tailwind v4 uses a CSS-first approach.

## File Structure

```css
@import "tailwindcss";
@plugin "@tailwindcss/forms";
@plugin "@tailwindcss/typography";

/* Custom variants */
@custom-variant dark (&:where(.dark, .dark *));

/* Theme configuration */
@theme {
  --font-sans: "Inter var", ...;
  --color-dark-500: oklch(52% 0.015 250);
  --color-accent-500: oklch(62% 0.21 260);
}

/* Custom utilities */
.body-bg { @apply bg-dark-800 text-dark-100; }
```

## Adding Configuration

### Colors (OKLCH only)

```css
@theme {
  /* Add new color scale */
  --color-brand-500: oklch(55% 0.2 280);
  --color-brand-600: oklch(48% 0.2 280);
}
```

Usage: `bg-brand-500`, `text-brand-600`

### Fonts

```css
@theme {
  --font-sans: "Inter var", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", monospace;
}
```

Usage: `font-sans`, `font-mono`

### Spacing / Sizing

```css
@theme {
  --spacing-18: 4.5rem;
  --width-128: 32rem;
}
```

Usage: `p-18`, `w-128`

### Custom Variants

```css
/* Class-based dark mode */
@custom-variant dark (&:where(.dark, .dark *));

/* Custom state */
@custom-variant hocus (&:hover, &:focus);
```

Usage: `dark:bg-dark-900`, `hocus:text-white`

### Plugins

```css
@plugin "@tailwindcss/forms";
@plugin "@tailwindcss/typography";
```

## What NOT to Do

```css
/* ❌ No hex colors */
--color-brand: #3b82f6;

/* ❌ No rgb/hsl */
--color-brand: rgb(59, 130, 246);

/* ✅ OKLCH only */
--color-brand: oklch(62% 0.21 260);
```

## Migration from v3

| v3 (JavaScript) | v4 (CSS) |
|-----------------|----------|
| `tailwind.config.js` | `application.css` |
| `theme.extend.colors` | `@theme { --color-* }` |
| `theme.extend.fontFamily` | `@theme { --font-* }` |
| `darkMode: 'class'` | `@custom-variant dark (...)` |
| `plugins: [require(...)]` | `@plugin "..."` |
| `content: [...]` | Auto-detected |

## Reference

- [Tailwind CSS v4 Docs](https://tailwindcss.com/docs)
- Config file: `app/assets/tailwind/application.css`
