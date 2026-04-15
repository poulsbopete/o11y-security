"use client";

import {
  forwardRef,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent,
  type TextareaHTMLAttributes,
} from "react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";
import { consumeAgentBuilderSse, converseStreamUrl } from "@/lib/converse-stream-client";
import {
  BookOpen,
  Link2,
  LoaderIcon,
  Megaphone,
  Paperclip,
  SendIcon,
  Users,
  XIcon,
} from "lucide-react";
import { AnimatePresence, motion } from "framer-motion";
import ReactMarkdown from "react-markdown";
import type { Components } from "react-markdown";

interface UseAutoResizeTextareaProps {
  minHeight: number;
  maxHeight?: number;
}

function useAutoResizeTextarea({
  minHeight,
  maxHeight,
}: UseAutoResizeTextareaProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const adjustHeight = useCallback(
    (reset?: boolean) => {
      const textarea = textareaRef.current;
      if (!textarea) return;

      if (reset) {
        textarea.style.height = `${minHeight}px`;
        return;
      }

      textarea.style.height = `${minHeight}px`;
      const newHeight = Math.max(
        minHeight,
        Math.min(
          textarea.scrollHeight,
          maxHeight ?? Number.POSITIVE_INFINITY
        )
      );

      textarea.style.height = `${newHeight}px`;
    },
    [minHeight, maxHeight]
  );

  useEffect(() => {
    const textarea = textareaRef.current;
    if (textarea) {
      textarea.style.height = `${minHeight}px`;
    }
  }, [minHeight]);

  useEffect(() => {
    const handleResize = () => adjustHeight();
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, [adjustHeight]);

  return { textareaRef, adjustHeight };
}

interface CommandSuggestion {
  icon: ReactNode;
  label: string;
  description: string;
  prefix: string;
}

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  containerClassName?: string;
  showRing?: boolean;
}

const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className, containerClassName, showRing = true, ...props }, ref) => {
    const [isFocused, setIsFocused] = useState(false);

    return (
      <div className={cn("relative", containerClassName)}>
        <textarea
          className={cn(
            "flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm",
            "transition-all duration-200 ease-in-out",
            "placeholder:text-muted-foreground",
            "disabled:cursor-not-allowed disabled:opacity-50",
            showRing
              ? "focus-visible:outline-none focus-visible:ring-0 focus-visible:ring-offset-0"
              : "",
            className
          )}
          ref={ref}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          {...props}
        />

        {showRing && isFocused && (
          <motion.span
            className="pointer-events-none absolute inset-0 rounded-md ring-2 ring-violet-500/30 ring-offset-0"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
          />
        )}
      </div>
    );
  }
);
Textarea.displayName = "Textarea";

const rippleKeyframes = `
@keyframes ripple {
  0% { transform: scale(0.5); opacity: 0.6; }
  100% { transform: scale(2); opacity: 0; }
}
`;

function ensureRippleStyles() {
  if (typeof document === "undefined") return;
  if (document.getElementById("animated-ai-chat-ripple")) return;
  const style = document.createElement("style");
  style.id = "animated-ai-chat-ripple";
  style.innerHTML = rippleKeyframes;
  document.head.appendChild(style);
}

function newMsgId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `m-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

async function drainResponseBody(res: Response): Promise<void> {
  try {
    await res.text();
  } catch {
    /* release socket */
  }
}

function extractAssistantMessage(data: unknown): string {
  if (!data || typeof data !== "object") return "";
  const o = data as Record<string, unknown>;
  if (o.response && typeof o.response === "object") {
    const r = o.response as Record<string, unknown>;
    if (typeof r.message === "string") return r.message;
  }
  if (typeof o.message === "string") return o.message;
  return "";
}

/** Tailwind-styled elements for model markdown (headings, lists, code, links). */
const ASSISTANT_MD_COMPONENTS: Partial<Components> = {
  h1: ({ children, ...props }) => (
    <h1
      className="mb-3 mt-1 border-b border-white/10 pb-2.5 text-xl font-semibold tracking-tight text-white first:mt-0 sm:text-2xl"
      {...props}
    >
      {children}
    </h1>
  ),
  h2: ({ children, ...props }) => (
    <h2
      className="mb-2.5 mt-6 text-lg font-semibold tracking-tight text-white/95 first:mt-0 sm:text-xl"
      {...props}
    >
      {children}
    </h2>
  ),
  h3: ({ children, ...props }) => (
    <h3 className="mb-2 mt-4 text-base font-semibold text-white/90 first:mt-0" {...props}>
      {children}
    </h3>
  ),
  p: ({ children, ...props }) => (
    <p className="mb-3 text-[0.9375rem] leading-relaxed text-white/88 last:mb-0" {...props}>
      {children}
    </p>
  ),
  ul: ({ children, ...props }) => (
    <ul
      className="mb-3 list-disc space-y-1.5 pl-5 text-[0.9375rem] leading-relaxed text-white/85 marker:text-emerald-400/70"
      {...props}
    >
      {children}
    </ul>
  ),
  ol: ({ children, ...props }) => (
    <ol
      className="mb-3 list-decimal space-y-1.5 pl-5 text-[0.9375rem] leading-relaxed text-white/85 marker:text-emerald-400/70"
      {...props}
    >
      {children}
    </ol>
  ),
  li: ({ children, ...props }) => (
    <li className="leading-relaxed [&>p]:mb-0" {...props}>
      {children}
    </li>
  ),
  blockquote: ({ children, ...props }) => (
    <blockquote
      className="mb-3 border-l-2 border-emerald-400/40 pl-3.5 text-white/78 italic"
      {...props}
    >
      {children}
    </blockquote>
  ),
  a: ({ children, href, ...props }) => (
    <a
      href={href}
      className="font-medium text-violet-300 underline-offset-2 hover:text-violet-200 hover:underline"
      target="_blank"
      rel="noopener noreferrer"
      {...props}
    >
      {children}
    </a>
  ),
  hr: (props) => <hr className="my-5 border-white/10" {...props} />,
  strong: ({ children, ...props }) => (
    <strong className="font-semibold text-white" {...props}>
      {children}
    </strong>
  ),
  em: ({ children, ...props }) => (
    <em className="text-white/85" {...props}>
      {children}
    </em>
  ),
  table: ({ children, ...props }) => (
    <div className="mb-3 overflow-x-auto rounded-lg border border-white/10">
      <table className="w-full min-w-[16rem] border-collapse text-left text-sm" {...props}>
        {children}
      </table>
    </div>
  ),
  thead: ({ children, ...props }) => (
    <thead className="border-b border-white/15 bg-white/[0.06]" {...props}>
      {children}
    </thead>
  ),
  th: ({ children, ...props }) => (
    <th className="px-3 py-2 font-semibold text-white/90" {...props}>
      {children}
    </th>
  ),
  td: ({ children, ...props }) => (
    <td className="border-t border-white/10 px-3 py-2 text-white/80" {...props}>
      {children}
    </td>
  ),
  pre: ({ children, ...props }) => (
    <pre
      className="mb-3 overflow-x-auto rounded-xl border border-white/10 bg-black/55 p-4 text-[0.8125rem] leading-relaxed text-emerald-100/90 shadow-inner"
      {...props}
    >
      {children}
    </pre>
  ),
  code: ({ className, children, ...props }) => {
    const block = Boolean(className?.includes("language-"));
    if (block) {
      return (
        <code className={cn("block font-mono text-[0.8125rem]", className)} {...props}>
          {children}
        </code>
      );
    }
    return (
      <code
        className="rounded-md bg-white/[0.14] px-1.5 py-0.5 font-mono text-[0.85em] text-white/95"
        {...props}
      >
        {children}
      </code>
    );
  },
};

export type AnimatedAIChatProps = {
  /** Same-origin Kibana converse proxy (Vercel: `/api/converse`). */
  converseUrl?: string;
};

type ChatMsg = {
  id: string;
  role: "user" | "assistant" | "error";
  text: string;
};

/** One-click scenarios for cross-sell coaching; answer quality depends on Agent Builder instructions in Kibana. */
const PRACTICE_PROMPTS: {
  id: string;
  title: string;
  hint: string;
  question: string;
}[] = [
  {
    id: "obs-security-pitch",
    title: "O11y customer → why Security?",
    hint: "Expect: business pain first—breach cost, MTTR delays, blind spots—not a catalog of Elastic features.",
    question:
      "I have an observability customer who asked why they should care about adding security. What's my pitch?",
  },
  {
    id: "datadog-both",
    title: "Datadog for both O11y + security",
    hint: "Expect: Datadog competitive—cost at scale, security immaturity, AI limits vs your narrative.",
    question:
      "My customer says they're just going to use Datadog for both observability and security. How do I respond?",
  },
  {
    id: "soc-sre-friction",
    title: "SOC waiting on SRE for logs",
    hint: "Expect: SEC→OBS trigger, talk track, tactical next steps—not generic “share a dashboard.”",
    question:
      "I'm in a security account and I just heard the SOC team complain about waiting on the SRE team for logs during investigations. What do I do next?",
  },
  {
    id: "data-platform",
    title: "Data Platform team engagement",
    hint: "Expect: account mapping + Data Platform gateway motion—not only product SKUs.",
    question: "How do I find and engage the Data Platform team at my account?",
  },
];

export function AnimatedAIChat({
  converseUrl = "/api/converse",
}: AnimatedAIChatProps) {
  const [value, setValue] = useState("");
  const [attachments, setAttachments] = useState<string[]>([]);
  const [isSending, setIsSending] = useState(false);
  const [activeSuggestion, setActiveSuggestion] = useState<number>(-1);
  const [showCommandPalette, setShowCommandPalette] = useState(false);
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 });
  const { textareaRef, adjustHeight } = useAutoResizeTextarea({
    minHeight: 60,
    maxHeight: 200,
  });
  const [inputFocused, setInputFocused] = useState(false);
  const commandPaletteRef = useRef<HTMLDivElement>(null);
  const conversationIdRef = useRef<string | null>(null);
  const [messages, setMessages] = useState<ChatMsg[]>([]);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const commandSuggestions = useMemo<CommandSuggestion[]>(
    () => [
      {
        icon: <Megaphone className="h-4 w-4" />,
        label: "Elevator pitch",
        description: "Short Observability ↔ Security cross-sell opener",
        prefix: "/pitch",
      },
      {
        icon: <Users className="h-4 w-4" />,
        label: "Buyer angles",
        description: "CISO, SRE, Platform — split clusters + one narrative",
        prefix: "/buyers",
      },
      {
        icon: <Link2 className="h-4 w-4" />,
        label: "Cross-project bridge",
        description: "Security calls Observability over HTTPS, no duplicated analytics",
        prefix: "/a2a",
      },
      {
        icon: <BookOpen className="h-4 w-4" />,
        label: "Workshop",
        description: "Agent Builder lab, two Kibanas, enrichment index",
        prefix: "/lab",
      },
    ],
    []
  );

  /** Single list: scenarios + slash shortcuts, all sent as the same user message stream. */
  const quickStarters = useMemo(
    () => [
      ...PRACTICE_PROMPTS.map((p) => ({
        id: p.id,
        title: p.title,
        hint: p.hint,
        payload: p.question,
      })),
      ...commandSuggestions.map((c) => ({
        id: `starter-${c.prefix.replace(/^\//, "")}`,
        title: c.label,
        hint: c.description,
        payload: c.prefix,
      })),
    ],
    [commandSuggestions]
  );

  useEffect(() => {
    ensureRippleStyles();
  }, []);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages, isSending]);

  useEffect(() => {
    if (value.startsWith("/") && !value.includes(" ")) {
      setShowCommandPalette(true);

      const matchingSuggestionIndex = commandSuggestions.findIndex((cmd) =>
        cmd.prefix.startsWith(value)
      );

      if (matchingSuggestionIndex >= 0) {
        setActiveSuggestion(matchingSuggestionIndex);
      } else {
        setActiveSuggestion(-1);
      }
    } else {
      setShowCommandPalette(false);
    }
  }, [value, commandSuggestions]);

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      setMousePosition({ x: e.clientX, y: e.clientY });
    };

    window.addEventListener("mousemove", handleMouseMove);
    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
    };
  }, []);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Node;
      if (
        commandPaletteRef.current &&
        !commandPaletteRef.current.contains(target)
      ) {
        setShowCommandPalette(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, []);

  const submitMessage = useCallback(
    async (text: string) => {
      const trimmed = text.trim();
      if (!trimmed || isSending) return;

      setMessages((m) => [...m, { id: newMsgId(), role: "user", text: trimmed }]);
      setValue("");
      adjustHeight(true);
      setIsSending(true);

      const body: Record<string, unknown> = { input: trimmed };
      if (conversationIdRef.current) {
        body.conversation_id = conversationIdRef.current;
      }

      const appendError = (errText: string) => {
        setMessages((m) => [...m, { id: newMsgId(), role: "error", text: errText }]);
      };

      const runSyncFallback = async (signal?: AbortSignal): Promise<boolean> => {
        try {
          const r = await fetch(converseUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "kbn-xsrf": "true",
            },
            body: JSON.stringify(body),
            credentials: "same-origin",
            signal,
          });

          const raw = await r.text();
          let data: unknown = null;
          try {
            data = raw ? JSON.parse(raw) : null;
          } catch {
            data = null;
          }

          if (!r.ok) {
            const errObj = data as Record<string, unknown> | null;
            const errText =
              (errObj && typeof errObj.message === "string" && errObj.message) ||
              (errObj && typeof errObj.error === "string" && errObj.error) ||
              raw ||
              `HTTP ${r.status}`;
            appendError(errText);
            return false;
          }

          const obj = data as Record<string, unknown> | null;
          if (obj && typeof obj.conversation_id === "string") {
            conversationIdRef.current = obj.conversation_id;
          }

          const reply =
            extractAssistantMessage(data) || "(Empty reply from agent)";
          setMessages((m) => [
            ...m,
            { id: newMsgId(), role: "assistant", text: reply },
          ]);
          return true;
        } catch (err) {
          const msg =
            err instanceof DOMException && err.name === "AbortError"
              ? "The agent took too long and the request was stopped. Try again with a shorter question, or check Kibana / connector health."
              : err instanceof Error
                ? err.message
                : "Network error";
          appendError(msg);
          return false;
        }
      };

      const ac = new AbortController();
      const CONVERSE_TIMEOUT_MS = 118_000;
      const timeoutId = window.setTimeout(() => ac.abort(), CONVERSE_TIMEOUT_MS);
      /** Set when a streaming assistant bubble is added (for timeout cleanup). */
      let streamingAssistantId: string | null = null;

      try {
        const streamUrl = converseStreamUrl(converseUrl);
        const rs = await fetch(streamUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "kbn-xsrf": "true",
            Accept: "text/event-stream",
          },
          body: JSON.stringify(body),
          credentials: "same-origin",
          signal: ac.signal,
        });

        const ct = rs.headers.get("content-type") ?? "";
        const useStream =
          rs.ok &&
          rs.body &&
          (/\btext\/event-stream\b/i.test(ct) ||
            /\bapplication\/octet-stream\b/i.test(ct) ||
            (/\btext\/plain\b/i.test(ct) && !/\bhtml\b/i.test(ct)));

        if (!useStream) {
          await drainResponseBody(rs);
          await runSyncFallback(ac.signal);
          return;
        }

        const streamId = newMsgId();
        streamingAssistantId = streamId;
        setMessages((m) => [...m, { id: streamId, role: "assistant", text: "" }]);

        let sawAssistantText = false;
        try {
          await consumeAgentBuilderSse(
            rs.body,
            {
              onConversationId: (id) => {
                conversationIdRef.current = id;
              },
              onTextChunk: (chunk) => {
                sawAssistantText = true;
                setMessages((m) =>
                  m.map((x) =>
                    x.id === streamId ? { ...x, text: x.text + chunk } : x
                  )
                );
              },
              onCompleteMessage: (full) => {
                sawAssistantText = true;
                setMessages((m) =>
                  m.map((x) => (x.id === streamId ? { ...x, text: full } : x))
                );
              },
            },
            ac.signal
          );
        } catch (e) {
          setMessages((m) => m.filter((x) => x.id !== streamId));
          if (e instanceof DOMException && e.name === "AbortError") {
            appendError(
              "The agent took too long and the stream was stopped. Try again with a shorter question, or check Kibana / connector health."
            );
            return;
          }
          await runSyncFallback();
          return;
        }

        if (!sawAssistantText) {
          setMessages((m) => m.filter((x) => x.id !== streamId));
          await runSyncFallback(ac.signal);
        }
      } catch (err) {
        if (err instanceof DOMException && err.name === "AbortError") {
          if (streamingAssistantId) {
            setMessages((m) => m.filter((x) => x.id !== streamingAssistantId));
          }
          appendError(
            "The agent took too long and the request was stopped. Try again with a shorter question, or check Kibana / connector health."
          );
        } else {
          const msg = err instanceof Error ? err.message : "Network error";
          appendError(msg);
        }
      } finally {
        window.clearTimeout(timeoutId);
        setIsSending(false);
      }
    },
    [isSending, converseUrl, adjustHeight]
  );

  /** Slash shortcuts send immediately so practice cards, chips, and the composer share one thread. */
  const runCommandSuggestion = useCallback(
    (index: number) => {
      const cmd = commandSuggestions[index];
      if (!cmd) return;
      setShowCommandPalette(false);
      void submitMessage(cmd.prefix);
    },
    [commandSuggestions, submitMessage]
  );

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (showCommandPalette) {
      if (e.key === "ArrowDown") {
        e.preventDefault();
        setActiveSuggestion((prev) =>
          prev < commandSuggestions.length - 1 ? prev + 1 : 0
        );
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setActiveSuggestion((prev) =>
          prev > 0 ? prev - 1 : commandSuggestions.length - 1
        );
      } else if (e.key === "Tab" || e.key === "Enter") {
        e.preventDefault();
        if (activeSuggestion >= 0) {
          runCommandSuggestion(activeSuggestion);
        }
      } else if (e.key === "Escape") {
        e.preventDefault();
        setShowCommandPalette(false);
      }
    } else if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      const t = value.trim();
      if (t) {
        void submitMessage(t);
      }
    }
  };

  const handleAttachFile = () => {
    const mockFileName = `file-${Math.floor(Math.random() * 1000)}.pdf`;
    setAttachments((prev) => [...prev, mockFileName]);
  };

  const removeAttachment = (index: number) => {
    setAttachments((prev) => prev.filter((_, i) => i !== index));
  };

  return (
    <div className="relative flex min-h-screen w-full flex-col items-center justify-center overflow-hidden bg-transparent px-4 py-8 text-white sm:px-6 lg:px-10">
      <div className="absolute inset-0 h-full w-full overflow-hidden">
        <div className="absolute left-1/4 top-0 h-96 w-96 animate-pulse rounded-full bg-violet-500/10 mix-blend-normal blur-[128px] filter" />
        <div className="absolute bottom-0 right-1/4 h-96 w-96 animate-pulse rounded-full bg-indigo-500/10 mix-blend-normal blur-[128px] filter delay-700" />
        <div className="absolute right-1/3 top-1/4 h-64 w-64 animate-pulse rounded-full bg-fuchsia-500/10 mix-blend-normal blur-[96px] filter delay-1000" />
      </div>
      <div className="relative mx-auto w-full max-w-5xl xl:max-w-6xl">
        <motion.div
          className="relative z-10 space-y-8 sm:space-y-10"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: "easeOut" }}
        >
          <div className="space-y-3 text-center">
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2, duration: 0.5 }}
              className="inline-block"
            >
              <h1 className="bg-gradient-to-r from-white/90 to-white/40 bg-clip-text pb-1 text-2xl font-medium tracking-tight text-transparent sm:text-3xl">
                o11y-security · Observability ↔ Security
              </h1>
              <motion.div
                className="h-px bg-gradient-to-r from-transparent via-white/20 to-transparent"
                initial={{ width: 0, opacity: 0 }}
                animate={{ width: "100%", opacity: 1 }}
                transition={{ delay: 0.5, duration: 0.8 }}
              />
            </motion.div>
            <motion.p
              className="mx-auto max-w-3xl text-sm leading-relaxed text-white/45 sm:text-base"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.3 }}
            >
              Cross-sell <strong className="text-white/70">Elastic Observability</strong> with{" "}
              <strong className="text-white/70">Elastic Security</strong> using{" "}
              <strong className="text-white/70">Agent Builder</strong> and the cross-sell knowledge
              base—split serverless projects, one buyer story. Pick a starter in the chat panel or
              type your own message.
              Type <kbd className="rounded border border-white/15 bg-white/5 px-1 py-0.5 font-mono text-[0.7rem]">/</kbd>{" "}
              in the box to filter slash shortcuts.
            </motion.p>
          </div>

          <motion.div
            className="relative flex max-h-[min(92vh,54rem)] flex-col overflow-hidden rounded-2xl border border-white/[0.1] bg-black/50 shadow-2xl shadow-black/40 backdrop-blur-2xl xl:max-h-[min(92vh,58rem)]"
            initial={{ scale: 0.98 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.1 }}
            role="region"
            aria-label="Chat"
          >
            <div className="shrink-0 border-b border-white/[0.06] px-2 pb-2 pt-1">
              <p className="px-2 py-1 text-[0.65rem] font-semibold uppercase tracking-[0.12em] text-white/35">
                Starter prompts
              </p>
              <p className="px-2 pb-1.5 text-[0.62rem] leading-snug text-white/28">
                Good answers follow your{" "}
                <strong className="text-white/40">Agent Builder instructions</strong> in Kibana.
                One thread until you use New conversation.
              </p>
              <ul
                className="max-h-[min(28vh,13rem)] space-y-0.5 overflow-y-auto pr-0.5 sm:max-h-[min(26vh,12rem)]"
                aria-label="Starter prompts"
              >
                {quickStarters.map((s) => (
                  <li key={s.id}>
                    <button
                      type="button"
                      disabled={isSending}
                      onClick={() => {
                        void submitMessage(s.payload);
                      }}
                      className={cn(
                        "w-full rounded-lg border border-transparent px-2.5 py-2 text-left transition-colors",
                        "hover:border-white/10 hover:bg-white/[0.06]",
                        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-violet-500/50",
                        isSending && "pointer-events-none opacity-45"
                      )}
                    >
                      <span className="block text-[0.82rem] font-semibold leading-snug text-white/90">
                        {s.title}
                      </span>
                      <span className="mt-0.5 block text-[0.68rem] leading-snug text-white/38">
                        {s.hint}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            </div>

            <div
              className={cn(
                "min-h-[10rem] flex-1 space-y-3 overflow-y-auto px-3 py-4 text-left sm:px-5 sm:py-5",
                "max-h-[min(52vh,32rem)] xl:max-h-[min(56vh,36rem)]"
              )}
              aria-label="Messages"
            >
              {messages.length === 0 && (
                <p className="rounded-lg border border-dashed border-white/10 bg-white/[0.02] px-3 py-4 text-center text-[0.8rem] leading-relaxed text-white/35">
                  Choose a starter above or write below. Everything posts to the same Kibana
                  conversation until you click{" "}
                  <span className="text-white/50">New conversation</span>.
                </p>
              )}
              {messages.map((msg) => (
                <div
                  key={msg.id}
                  className={cn(
                    "rounded-xl leading-relaxed",
                    msg.role === "user" &&
                      "whitespace-pre-wrap border border-violet-500/25 bg-violet-500/[0.14] px-4 py-3.5 text-[0.9375rem] text-white sm:px-5 sm:py-4",
                    msg.role === "assistant" &&
                      "border border-emerald-500/30 bg-gradient-to-br from-emerald-950/45 via-black/35 to-black/25 px-4 py-4 text-white/90 shadow-inner sm:px-6 sm:py-5",
                    msg.role === "error" &&
                      "whitespace-pre-wrap border border-red-400/35 bg-red-500/10 px-4 py-3.5 text-red-100"
                  )}
                >
                  <span
                    className={cn(
                      "mb-2.5 inline-flex items-center rounded-md px-2 py-0.5 text-[0.65rem] font-bold uppercase tracking-[0.14em]",
                      msg.role === "user" && "bg-violet-500/25 text-violet-100",
                      msg.role === "assistant" && "bg-emerald-500/20 text-emerald-100",
                      msg.role === "error" && "bg-red-500/25 text-red-100"
                    )}
                  >
                    {msg.role === "user"
                      ? "You"
                      : msg.role === "assistant"
                        ? "Agent"
                        : "Error"}
                  </span>
                  {msg.role === "assistant" ? (
                    <div className="chat-markdown max-w-none [&>:first-child]:mt-0">
                      <ReactMarkdown components={ASSISTANT_MD_COMPONENTS}>
                        {msg.text}
                      </ReactMarkdown>
                    </div>
                  ) : (
                    <div className="text-[0.9375rem] leading-relaxed">{msg.text}</div>
                  )}
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>

            <div className="relative shrink-0 border-t border-white/[0.06]">
              <AnimatePresence>
                {showCommandPalette && (
                  <motion.div
                    ref={commandPaletteRef}
                    className="absolute bottom-full left-4 right-4 z-50 mb-2 overflow-hidden rounded-lg border border-white/10 bg-black/90 shadow-lg backdrop-blur-xl"
                    initial={{ opacity: 0, y: 5 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 5 }}
                    transition={{ duration: 0.15 }}
                  >
                    <div className="bg-black/95 py-1">
                      {commandSuggestions.map((suggestion, index) => (
                        <motion.div
                          key={suggestion.prefix}
                          className={cn(
                            "flex cursor-pointer items-center gap-2 px-3 py-2 text-xs transition-colors",
                            activeSuggestion === index
                              ? "bg-white/10 text-white"
                              : "text-white/70 hover:bg-white/5"
                          )}
                          onClick={() => runCommandSuggestion(index)}
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 1 }}
                          transition={{ delay: index * 0.03 }}
                        >
                          <div className="flex h-5 w-5 items-center justify-center text-white/60">
                            {suggestion.icon}
                          </div>
                          <div className="font-medium">{suggestion.label}</div>
                          <div className="ml-1 text-xs text-white/40">
                            {suggestion.prefix}
                          </div>
                        </motion.div>
                      ))}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              <div className="p-4 pb-2">
                <Textarea
                  ref={textareaRef}
                  value={value}
                  onChange={(e) => {
                    setValue(e.target.value);
                    adjustHeight();
                  }}
                  onKeyDown={handleKeyDown}
                  onFocus={() => setInputFocused(true)}
                  onBlur={() => setInputFocused(false)}
                  placeholder="Ask about Observability ↔ Security cross-selling: positioning, objections, enrichment agents, or the workshop lab…"
                  containerClassName="w-full"
                  className={cn(
                    "w-full min-h-[60px] resize-none border-none bg-transparent px-1 py-2 text-sm text-white/90",
                    "focus:outline-none",
                    "placeholder:text-white/20"
                  )}
                  style={{
                    overflow: "hidden",
                  }}
                  showRing={false}
                />
              </div>

              <AnimatePresence>
                {attachments.length > 0 && (
                  <motion.div
                    className="flex flex-wrap gap-2 px-4 pb-3"
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: "auto" }}
                    exit={{ opacity: 0, height: 0 }}
                  >
                    {attachments.map((file, index) => (
                      <motion.div
                        key={file + String(index)}
                        className="flex items-center gap-2 rounded-lg bg-white/[0.03] px-3 py-1.5 text-xs text-white/70"
                        initial={{ opacity: 0, scale: 0.9 }}
                        animate={{ opacity: 1, scale: 1 }}
                        exit={{ opacity: 0, scale: 0.9 }}
                      >
                        <span>{file}</span>
                        <button
                          type="button"
                          onClick={() => removeAttachment(index)}
                          className="text-white/40 transition-colors hover:text-white"
                        >
                          <XIcon className="h-3 w-3" />
                        </button>
                      </motion.div>
                    ))}
                  </motion.div>
                )}
              </AnimatePresence>

              <div className="flex flex-wrap items-center gap-3 p-4 pt-3">
                <motion.button
                  type="button"
                  onClick={handleAttachFile}
                  whileTap={{ scale: 0.94 }}
                  className="group relative rounded-lg p-2 text-white/40 transition-colors hover:text-white/90"
                >
                  <Paperclip className="h-4 w-4" />
                  <motion.span
                    className="absolute inset-0 rounded-lg bg-white/[0.05] opacity-0 transition-opacity group-hover:opacity-100"
                    layoutId="button-highlight-attach"
                  />
                </motion.button>

                <div className="ml-auto flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() => {
                      conversationIdRef.current = null;
                      setMessages([]);
                    }}
                    className="text-[0.7rem] text-violet-300/90 underline-offset-2 hover:text-violet-200 hover:underline"
                  >
                    New conversation
                  </button>
                  <motion.button
                    type="button"
                    onClick={() => {
                      void submitMessage(value);
                    }}
                    whileHover={{ scale: 1.01 }}
                    whileTap={{ scale: 0.98 }}
                    disabled={isSending || !value.trim()}
                    className={cn(
                      "flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition-all",
                      value.trim()
                        ? "bg-white text-[#0A0A0B] shadow-lg shadow-white/10"
                        : "bg-white/[0.05] text-white/40"
                    )}
                  >
                    {isSending ? (
                      <LoaderIcon className="h-4 w-4 animate-[spin_2s_linear_infinite]" />
                    ) : (
                      <SendIcon className="h-4 w-4" />
                    )}
                    <span>Send</span>
                  </motion.button>
                </div>
              </div>
            </div>
          </motion.div>
        </motion.div>
      </div>

      <AnimatePresence>
        {isSending && (
          <motion.div
            className="fixed bottom-8 left-1/2 z-50 -translate-x-1/2 rounded-full border border-white/[0.05] bg-white/[0.02] px-4 py-2 shadow-lg backdrop-blur-2xl"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
          >
            <div className="flex items-center gap-3">
              <div className="flex h-7 min-w-[2.75rem] items-center justify-center rounded-full bg-white/[0.05] px-1.5 text-center">
                <span className="text-[0.65rem] font-semibold leading-none text-white/90">
                  o11y
                </span>
              </div>
              <div className="flex items-center gap-2 text-sm text-white/70">
                <span>Cross-sell coach thinking</span>
                <TypingDots />
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {inputFocused && (
        <motion.div
          className="pointer-events-none fixed z-0 h-[50rem] w-[50rem] rounded-full bg-gradient-to-r from-violet-500 via-fuchsia-500 to-indigo-500 opacity-[0.02] blur-[96px]"
          animate={{
            x: mousePosition.x - 400,
            y: mousePosition.y - 400,
          }}
          transition={{
            type: "spring",
            damping: 25,
            stiffness: 150,
            mass: 0.5,
          }}
        />
      )}
    </div>
  );
}

function TypingDots() {
  return (
    <div className="ml-1 flex items-center">
      {[1, 2, 3].map((dot) => (
        <motion.div
          key={dot}
          className="mx-0.5 h-1.5 w-1.5 rounded-full bg-white/90"
          initial={{ opacity: 0.3 }}
          animate={{
            opacity: [0.3, 0.9, 0.3],
            scale: [0.85, 1.1, 0.85],
          }}
          transition={{
            duration: 1.2,
            repeat: Infinity,
            delay: dot * 0.15,
            ease: "easeInOut",
          }}
          style={{
            boxShadow: "0 0 4px rgba(255, 255, 255, 0.3)",
          }}
        />
      ))}
    </div>
  );
}
