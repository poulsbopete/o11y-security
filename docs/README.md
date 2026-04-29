# GitHub Pages (slides only)

This folder powers the **short HTML slide deck** served by GitHub Pages (`index.html`). It is **not** the main project documentation.

**→ Read the real overview in the [repository root README](../README.md).**

## Enable Pages

1. Repository **Settings → Pages**.
2. **Source**: Deploy from branch **`main`**, folder **`/docs`**.

This folder includes an empty **`.nojekyll`** file so GitHub Pages serves **static files as-is** (otherwise Jekyll can interfere with assets like `pattern.css`).

Site URL: **https://poulsbopete.github.io/o11y-security/**

The deck has **seven** slides with **Prev / Next**, dots, a counter, and keyboard support (**←** **→**, **Space**). Slide 2 is **Same telemetry, different purpose** (Web / Database / OS logs—Observability vs Security “vase or face,” plus `workshop.demo_stream` in the lab). Slide 4 is the **reference workflow** (Security + Observability → MCP / Agent Builder) using [`images/a2a-mcp-architecture.jpg`](images/a2a-mcp-architecture.jpg), plus a note that **Cross-project search (CPS)** is **tech preview** in Elastic Cloud as an alternative or complement to **A2A via MCP**. Slide 5 adds **Kibana screenshots** ([`images/a2a-lab-workflows-list.jpg`](images/a2a-lab-workflows-list.jpg), [`images/a2a-lab-cases-list.jpg`](images/a2a-lab-cases-list.jpg)) and copy aligned with **`elastic-agent-builder-a2a-cloud-path`**: bidirectional **alert → HTTP converse → Case** workflows, **scheduled** synth inject pushed **disabled** by default, **manual** inject for demos, and the **~60s** outbound HTTP limit / **`[A2A_WF]`** fast path for Security → Observability peer review. Slide 7 (**Hands-on**) links the **Instruqt** track **`elastic-a2a-serverless-agent-builder`** (dual **Serverless** Kibana service tabs + single-host nginx proxy) and the GitHub workshop folder.

## AE training prompts

- Hub page: [`prompts/index.html`](prompts/index.html) (also linked from the slide deck).
- Full **AE selling coach** prompt: [`prompts/ae-a2a-selling-coach.md`](prompts/ae-a2a-selling-coach.md)
- Shorter **discovery cheat sheet**: [`prompts/discovery-call-cheat-sheet.md`](prompts/discovery-call-cheat-sheet.md)

## Background (FallingPattern)

GitHub Pages here is **static HTML + CSS** only—there is **no** React, **no** npm build, and **no** shadcn/Tailwind toolchain on this path.

The animated “falling lines” look is a **CSS port** of the `FallingPattern` + `framer-motion` idea:

- Styles: [`pattern.css`](pattern.css) (multi-layer `radial-gradient`, `@keyframes` on `background-position`, blur + dot overlay, radial `mask-image`).
- Tune colors and motion via CSS variables in `:root`: `--pattern-stripe`, `--pattern-bg`, `--pattern-duration`, `--pattern-blur`, `--pattern-density`.
- **`prefers-reduced-motion: reduce`** disables the animation.

### If you want the real React + shadcn component instead

Use a **Next.js (or Vite) + TypeScript** app with [shadcn/ui](https://ui.shadcn.com/) and Tailwind:

1. `npx shadcn@latest init` (pick TypeScript + Tailwind).
2. Ensure **`src/components/ui/`** exists (shadcn’s default for `add`); if your template uses another folder, create `components/ui` anyway so `npx shadcn add …` and imports like `@/components/ui/...` stay consistent.
3. `npm i framer-motion` and add `cn()` in `src/lib/utils.ts` per shadcn.
4. Paste the original **`falling-pattern.tsx`** into `src/components/ui/falling-pattern.tsx` and wrap your layout as in the demo.
5. Deploy that app (Vercel, Cloudflare Pages, etc.). GitHub Pages **can** host a built static export (`next export` / `output: 'export'`) if you add a CI build step—otherwise keep using this CSS version for zero-build Pages.
