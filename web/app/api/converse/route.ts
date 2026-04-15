import { NextRequest, NextResponse } from "next/server";
import {
  parseConverseJsonBody,
  requireKibanaConverseEnv,
} from "@/lib/kibana-converse-request";

export const runtime = "nodejs";
/** Allow long agent runs (Vercel plan must support this cap). */
export const maxDuration = 120;

export async function POST(req: NextRequest) {
  const env = requireKibanaConverseEnv();
  if (!env.ok) return env.response;

  const parsed = await parseConverseJsonBody(req);
  if (!parsed.ok) return parsed.response;

  const url = `${env.base}/api/agent_builder/converse`;

  let r: Response;
  try {
    r = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `ApiKey ${env.key}`,
        "kbn-xsrf": "true",
      },
      body: JSON.stringify(parsed.payload),
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "fetch failed";
    console.error("[converse proxy] fetch error:", msg);
    return NextResponse.json(
      { message: `Upstream fetch failed: ${msg}`, upstream: env.base },
      { status: 502 }
    );
  }

  const text = await r.text();
  if (!r.ok) {
    console.error(
      "[converse proxy] Kibana non-OK",
      r.status,
      text.slice(0, 4000)
    );
  }
  const ct = r.headers.get("content-type") || "application/json; charset=utf-8";
  return new NextResponse(text, {
    status: r.status,
    headers: { "Content-Type": ct },
  });
}
