# o11y-security site (Vercel + Next.js)

This folder deploys the same static deck and prompt library as [`../docs/`](../docs/), plus a **server-side proxy** at `POST /api/converse` so the in-page chat can reach Kibana **without CORS or pasting API keys in the browser**.

## Environment variables (Vercel)

| Name | Required | Description |
|------|----------|-------------|
| `KIBANA_BASE_URL` | Yes | Kibana origin, e.g. `https://your-deployment.kb.region.aws.elastic.cloud` (no trailing slash). |
| `KIBANA_API_KEY` | Yes | Base64 Kibana API key with Agent Builder privileges. **Mark as sensitive** in Vercel. |

See [`env.example`](./env.example).

## Deploy on Vercel

1. **New Project** → import this Git repository.
2. Set **Root Directory** to `web` (required if the repo root is not the Next app).
3. Framework Preset: **Next.js** (auto-detected).
4. Add the environment variables above, then deploy.

The `web/vercel.json` **buildCommand** is `npm run build` so Vercel does not use the default `next build` alone (that would skip copying `../docs` into `public/` and you would get **404** on `/` and `/index.html`).

Build runs `npm run sync-docs` (copies `../docs` into `public/` and sets `<meta name="o11y-converse-url" content="/api/converse" />`), then `next build`.

### If you see `404: NOT_FOUND`

- Confirm **Root Directory** is **`web`**.
- Confirm the latest deploy **Build Command** shows `npm run build` (from `vercel.json`) or set it manually to `npm run build`.
- Open **`/index.html`** after redeploy; `/` should redirect there once the build copied static files into `public/`.

## Local preview

```bash
cd web
cp env.example .env.local
# edit .env.local with real values
npm install
npm run dev
```

Open `http://localhost:3000` (redirects to `/index.html`). Use **A2A help** → Kibana chat; no API key field when the proxy meta is set.

## GitHub Pages

The canonical `docs/` tree keeps `<meta name="o11y-converse-url" content="" />` so the assistant still talks to Kibana **from the browser** when you paste an API key (subject to CORS). Vercel builds use the non-empty meta via `sync-docs.mjs` only in the generated `web/public/` copy.
