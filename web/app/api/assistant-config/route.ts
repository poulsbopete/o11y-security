import { NextResponse } from "next/server";

export const runtime = "nodejs";

/**
 * Non-sensitive hints for the browser UI (hosted / Vercel only).
 */
export async function GET() {
  const id = process.env.KIBANA_AGENT_ID?.trim() ?? "";
  return NextResponse.json({
    hosted: true,
    defaultAgentConfigured: Boolean(id),
    /** Short tail so you can confirm the right agent without printing the full id. */
    defaultAgentTail: id.length > 10 ? id.slice(-10) : id || null,
  });
}
