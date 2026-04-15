# shadcn/ui + Tailwind + TypeScript (this repo)

The **`web/`** Next.js app now includes:

| Piece | Location |
|-------|----------|
| Tailwind entry | `app/globals.css` (`@tailwind` + CSS variables) |
| Tailwind config | `tailwind.config.ts` |
| PostCSS | `postcss.config.mjs` |
| `cn()` helper | `lib/utils.ts` (clsx + tailwind-merge) |
| shadcn-style UI | `components/ui/*` |
| shadcn manifest | `components.json` (aliases for `npx shadcn@latest add …`) |

Path alias **`@/*` → project root** is set in `tsconfig.json`, so imports use `@/components/ui/...` and `@/lib/utils`.

## Why `components/ui` matters

The **shadcn CLI** defaults to **`components/ui`** for generated primitives (Button, Card, …). Keeping that folder:

- Lets you run `npx shadcn@latest add button` without reconfiguring paths.
- Matches documentation and community examples (`@/components/ui/button`).
- Avoids splitting “custom” vs “CLI” components across different trees.

You can change aliases in `components.json`, but staying on `components/ui` reduces friction.

## Fresh project: shadcn CLI (reference)

If you were starting from zero instead of this repo:

```bash
npx create-next-app@latest my-app --typescript --tailwind --eslint --app
cd my-app
npx shadcn@latest init
```

`init` writes `components.json`, ensures Tailwind theme tokens, and creates `lib/utils.ts`. Then:

```bash
npx shadcn@latest add button
```

## Dependencies added here

- `tailwindcss`, `postcss`, `autoprefixer`, `tailwindcss-animate`
- `clsx`, `tailwind-merge`
- `lucide-react`, `framer-motion`

## Demo route

- **`/chat`** — full-page `AnimatedAIChat` (dark lab background + `lab-bg` helper from `globals.css`).

Static deck remains at **`/` → `/index.html`** (synced from `../docs`).
