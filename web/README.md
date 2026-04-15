# o11y-security site (Vercel + Next.js)

This folder deploys the same static deck and prompt library as [`../docs/`](../docs/), plus server-side proxies so the in-page chat can reach Kibana **without CORS or pasting API keys in the browser**:

- **`POST /api/converse`** — synchronous Agent Builder converse (full JSON response when the round finishes).
- **`POST /api/converse/stream`** — forwards to Kibana **`/api/agent_builder/converse/async`** (SSE). **`/chat`** uses streaming first so text can render as it arrives; unsupported stacks fall back to **`/api/converse`** automatically.

## Environment variables (Vercel)

| Name | Required | Description |
|------|----------|-------------|
| `KIBANA_BASE_URL` | Yes | Kibana origin, e.g. `https://your-deployment.kb.region.aws.elastic.cloud` (no trailing slash). |
| `KIBANA_API_KEY` | Yes | Base64 Kibana API key with Agent Builder privileges. **Mark as sensitive** in Vercel. |
| `KIBANA_AGENT_ID` | No | Agent Builder **agent id** (UUID). When set, the proxy adds **`agent_id`** to **converse** whenever the browser omits it—use this so **`/chat`** uses your workshop agent without a per-browser field. |

See [`env.example`](./env.example).

## Deploy on Vercel

1. **New Project** → import this Git repository.
2. Set **Root Directory** to `web` (required if the repo root is not the Next app).
3. Framework Preset: **Next.js** (auto-detected).
4. Add the environment variables above, then deploy.

The `web/vercel.json` **buildCommand** is `npm run build` so Vercel does not use the default `next build` alone (that would skip copying `../docs` into `public/` and you would get **404** on `/` and `/index.html`).

### React + Tailwind + shadcn-style UI

- **`/chat`** — **`AnimatedAIChat`** ([`components/ui/animated-ai-chat.tsx`](./components/ui/animated-ai-chat.tsx)): prefers **`POST /api/converse/stream`** (SSE) then falls back to **`POST /api/converse`**; shows **You / Agent / Error** bubbles; keeps **`conversation_id`**; starter prompts and **New conversation**. Default agent comes from **`KIBANA_AGENT_ID`** on the server only. Logs may show **`/api/converse/stream`** or **`/api/converse`** per request.
- Setup notes and CLI reference: [`docs/SHADCN-TAILWIND-SETUP.md`](./docs/SHADCN-TAILWIND-SETUP.md).

Build runs `npm run sync-docs` (copies `../docs` into `public/` and sets `<meta name="o11y-converse-url" content="/api/converse" />`), then `next build`.

### If `/api/converse` returns **500** (Vercel + Kibana both 500)

The proxy only forwards to **`{KIBANA_BASE_URL}/api/agent_builder/converse`**. A **500** means **Kibana** rejected the request or failed while running the agent (the proxy passes the same status and body back).

Check:

1. **`KIBANA_BASE_URL`** is exactly the Kibana origin, e.g. `https://ai-assistants-ffcafb.kb.us-east-1.aws.elastic.cloud` — **no** `/api/...` suffix, **no** trailing slash.
2. **`KIBANA_API_KEY`** is a **Kibana** API key with **`agentBuilder:read`** (and whatever else the agent needs), not an Elasticsearch-only key.
3. **`KIBANA_AGENT_ID`** (if set) is the **Agent Builder agent UUID**, not a project slug or MCP URL fragment.
4. In **Vercel → Deployment → Functions → `/api/converse` logs**, look for **`[converse proxy] Kibana non-OK`** — the next lines include Kibana’s error JSON (connector, inference, license, etc.).

`maxDuration` for both converse routes is **120s** so slow agent runs are less likely to die on the Vercel side (your plan must allow that duration).

**Latency (wall clock):** streaming improves *perceived* wait time (first tokens sooner) but not total model + tool work. In **Kibana Agent Builder**, tighten instructions (fewer default tool hops), trim retrieval limits, or use a faster inference endpoint if you need shorter end-to-end runs.

**Browser tab “still loading”:** long SSE `fetch` calls can keep some browsers busy; `/chat` uses a **118s client abort** and **drains** non-SSE responses so connections are not left hanging. The page backdrop avoids a third-party hero image so `load` is not blocked by blocked CDNs.

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

Open `http://localhost:3000` (redirects to `/index.html`). On the hosted build the launcher reads **Live · chat** and the panel shows a **Hosted** pill plus a one-line hint for `KIBANA_AGENT_ID`. The slide deck itself matches GitHub Pages by design.

## GitHub Pages

The canonical `docs/` tree keeps `<meta name="o11y-converse-url" content="" />` so the assistant still talks to Kibana **from the browser** when you paste an API key (subject to CORS). Vercel builds use the non-empty meta via `sync-docs.mjs` only in the generated `web/public/` copy.
