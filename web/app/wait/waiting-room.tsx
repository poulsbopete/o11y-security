"use client";

import { useEffect, useState } from "react";

const INSTRUQT =
  "https://play.instruqt.com/manage/elastic/tracks/elastic-a2a-serverless-agent-builder";

function formatElapsed(ms: number) {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r.toString().padStart(2, "0")}`;
}

export function WaitingRoom() {
  const [elapsed, setElapsed] = useState(0);

  useEffect(() => {
    const t0 = Date.now();
    const id = window.setInterval(() => setElapsed(Date.now() - t0), 1000);
    return () => window.clearInterval(id);
  }, []);

  return (
    <div className="flex h-dvh min-h-screen flex-col bg-[#0d1117] text-[#e6edf3]">
      <header className="flex shrink-0 flex-wrap items-center justify-between gap-3 border-b border-[#30363d] bg-[#161b22]/95 px-4 py-2.5 backdrop-blur-md">
        <div className="flex min-w-0 items-center gap-3">
          <span
            className="inline-flex h-2.5 w-2.5 shrink-0 animate-pulse rounded-full bg-[#3fb950] shadow-[0_0_12px_rgba(63,185,80,0.85)]"
            aria-hidden
          />
          <div className="min-w-0">
            <p className="text-[0.7rem] font-semibold uppercase tracking-[0.14em] text-[#8b949e]">
              Waiting room · {formatElapsed(elapsed)}
            </p>
            <p className="truncate text-sm font-semibold text-[#e6edf3]">
              Lab is starting — browse the story
            </p>
          </div>
        </div>
        <nav className="flex flex-wrap items-center gap-2 text-sm">
          <a
            href="/index.html"
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-lg border border-[#30363d] bg-[#21262d] px-3 py-1.5 font-semibold text-[#58a6ff] hover:border-[#58a6ff]"
          >
            Full-screen deck
          </a>
          <a
            href="/chat"
            className="rounded-lg border border-[#30363d] bg-[#21262d] px-3 py-1.5 font-semibold text-[#e6edf3] hover:border-[#58a6ff] hover:text-[#58a6ff]"
          >
            Chat
          </a>
          <a
            href={INSTRUQT}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-lg border border-[rgba(88,166,255,0.35)] bg-[rgba(88,166,255,0.12)] px-3 py-1.5 font-semibold text-[#58a6ff] hover:bg-[rgba(88,166,255,0.2)]"
          >
            Instruqt track
          </a>
        </nav>
      </header>
      <p className="shrink-0 border-b border-[#30363d] bg-[#0d1117] px-4 py-2 text-xs leading-relaxed text-[#8b949e]">
        Kibana tabs in Instruqt often show <span className="text-[#e6edf3]">503</span> until you paste
        both Cloud URLs into <code className="text-[#79c0ff]">.env</code> and run{" "}
        <code className="text-[#79c0ff]">render-kibana-proxy.sh</code>. These slides match{" "}
        <a
          className="font-semibold text-[#58a6ff] hover:underline"
          href="https://poulsbopete.github.io/o11y-security/"
          target="_blank"
          rel="noopener noreferrer"
        >
          poulsbopete.github.io/o11y-security
        </a>
        .
      </p>
      <iframe
        title="Observability and Security value slides"
        src="/index.html?embed=1"
        className="min-h-0 w-full flex-1 border-0 bg-[#0d1117]"
        allow="fullscreen"
      />
    </div>
  );
}
