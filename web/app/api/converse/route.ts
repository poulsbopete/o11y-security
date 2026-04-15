import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  const base = process.env.KIBANA_BASE_URL?.replace(/\/$/, "");
  const key = process.env.KIBANA_API_KEY;
  if (!base || !key) {
    return NextResponse.json(
      {
        message:
          "Server is missing KIBANA_BASE_URL or KIBANA_API_KEY. Set them in the Vercel project environment.",
      },
      { status: 503 }
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ message: "Invalid JSON body" }, { status: 400 });
  }

  const payload: Record<string, unknown> =
    typeof body === "object" && body !== null && !Array.isArray(body)
      ? { ...(body as Record<string, unknown>) }
      : {};

  const fromClient = payload.agent_id;
  const clientEmpty =
    fromClient === undefined ||
    fromClient === null ||
    (typeof fromClient === "string" && fromClient.trim() === "");
  const defaultAgent = process.env.KIBANA_AGENT_ID?.trim();
  if (clientEmpty && defaultAgent) {
    payload.agent_id = defaultAgent;
  }

  const url = `${base}/api/agent_builder/converse`;
  const r = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `ApiKey ${key}`,
      "kbn-xsrf": "true",
    },
    body: JSON.stringify(payload),
  });

  const text = await r.text();
  const ct = r.headers.get("content-type") || "application/json; charset=utf-8";
  return new NextResponse(text, {
    status: r.status,
    headers: { "Content-Type": ct },
  });
}
