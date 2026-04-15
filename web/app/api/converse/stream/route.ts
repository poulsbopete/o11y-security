import { NextRequest, NextResponse } from "next/server";
import {
  parseConverseJsonBody,
  requireKibanaConverseEnv,
} from "@/lib/kibana-converse-request";

export const runtime = "nodejs";
export const maxDuration = 120;

/**
 * Proxies to Kibana `POST /api/agent_builder/converse/async` (SSE) so the browser
 * can render tokens as they arrive instead of waiting for the full round-trip.
 */
export async function POST(req: NextRequest) {
  const env = requireKibanaConverseEnv();
  if (!env.ok) return env.response;

  const parsed = await parseConverseJsonBody(req);
  if (!parsed.ok) return parsed.response;

  const url = `${env.base}/api/agent_builder/converse/async`;

  let r: Response;
  try {
    r = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `ApiKey ${env.key}`,
        "kbn-xsrf": "true",
        Accept: "text/event-stream",
      },
      body: JSON.stringify(parsed.payload),
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "fetch failed";
    console.error("[converse stream] fetch error:", msg);
    return NextResponse.json(
      { message: `Upstream fetch failed: ${msg}`, upstream: env.base },
      { status: 502 }
    );
  }

  if (!r.ok) {
    const text = await r.text();
    console.error("[converse stream] Kibana non-OK", r.status, text.slice(0, 4000));
    const ct = r.headers.get("content-type") || "application/json; charset=utf-8";
    return new NextResponse(text, { status: r.status, headers: { "Content-Type": ct } });
  }

  /** Kibana may send `application/octet-stream`; browsers need a text-like type for fetch readers. */
  return new NextResponse(r.body, {
    status: 200,
    headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    },
  });
}
