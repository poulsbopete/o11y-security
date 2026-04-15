/**
 * Floating assistant: Agent Builder MCP copy + Kibana Converse chat.
 * Set <meta name="o11y-converse-url" content="/api/converse" /> (same-origin path) to use a
 * server proxy (e.g. Vercel) so the browser does not call Kibana directly.
 */
(function () {
  "use strict";

  var KIBANA_BASE = "https://ai-assistants-ffcafb.kb.us-east-1.aws.elastic.cloud";
  var MCP_URL = KIBANA_BASE + "/api/agent_builder/mcp";

  var metaConverse = document.querySelector('meta[name="o11y-converse-url"]');
  var converseMetaRaw = metaConverse && metaConverse.getAttribute("content");
  var converseMeta = converseMetaRaw != null ? String(converseMetaRaw).trim() : "";
  var CONVERSE_URL = converseMeta.length ? converseMeta : KIBANA_BASE + "/api/agent_builder/converse";
  /** Leading / means same-origin proxy (no browser API key). */
  var SERVER_PROXY = converseMeta.length > 0 && converseMeta.charAt(0) === "/";

  var SK = "o11y_pages_ab_api_key";
  var SK_CONV = "o11y_pages_ab_conversation_id";
  var SK_AGENT = "o11y_pages_ab_agent_id";

  function escapeAttr(s) {
    return String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
  }

  function copyText(text, ok, fail) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(ok).catch(fail);
      return;
    }
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.select();
    try {
      document.execCommand("copy");
      ok();
    } catch (e) {
      fail();
    }
    document.body.removeChild(ta);
  }

  function extractAssistantMessage(data) {
    if (!data || typeof data !== "object") return "";
    if (data.response && typeof data.response.message === "string") return data.response.message;
    if (typeof data.message === "string") return data.message;
    return "";
  }

  var css =
    "#o11y-ab-assistant-root{font-family:ui-sans-serif,system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;}" +
    "#o11y-ab-fab{position:fixed;right:1rem;bottom:calc(5.5rem + env(safe-area-inset-bottom,0px));z-index:200;padding:0.65rem 1rem;border-radius:999px;border:1px solid rgba(88,166,255,0.45);background:rgba(22,27,34,0.95);color:#58a6ff;font-weight:650;font-size:0.9rem;cursor:pointer;box-shadow:0 8px 28px rgba(0,0,0,0.45);backdrop-filter:blur(8px);}" +
    "#o11y-ab-fab:hover{border-color:#58a6ff;background:rgba(88,166,255,0.12);}" +
    "#o11y-ab-panel{position:fixed;right:1rem;bottom:calc(9.25rem + env(safe-area-inset-bottom,0px));z-index:200;width:min(100vw - 2rem,26rem);max-height:min(85vh,32rem);display:none;flex-direction:column;border-radius:12px;border:1px solid #30363d;background:rgba(13,17,23,0.97);color:#e6edf3;box-shadow:0 16px 48px rgba(0,0,0,0.5);overflow:hidden;backdrop-filter:blur(10px);}" +
    "#o11y-ab-panel.open{display:flex;}" +
    "#o11y-ab-head{display:flex;align-items:center;justify-content:space-between;gap:0.5rem;padding:0.65rem 0.85rem;border-bottom:1px solid #30363d;background:rgba(22,27,34,0.95);}" +
    "#o11y-ab-head strong{font-size:0.95rem;}" +
    "#o11y-ab-close{appearance:none;border:none;background:transparent;color:#8b949e;font-size:1.25rem;line-height:1;cursor:pointer;padding:0.15rem 0.35rem;border-radius:6px;}" +
    "#o11y-ab-close:hover{color:#e6edf3;background:#21262d;}" +
    "#o11y-ab-tabs{display:flex;border-bottom:1px solid #30363d;}" +
    "#o11y-ab-tabs button{flex:1;padding:0.5rem 0.35rem;font:inherit;font-size:0.82rem;font-weight:600;border:none;background:transparent;color:#8b949e;cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px;}" +
    "#o11y-ab-tabs button[aria-selected='true']{color:#58a6ff;border-bottom-color:#58a6ff;}" +
    ".o11y-ab-pane{flex:1;min-height:0;display:none;flex-direction:column;padding:0.75rem;gap:0.6rem;overflow:auto;}" +
    ".o11y-ab-pane.active{display:flex;}" +
    ".o11y-ab-note{font-size:0.78rem;line-height:1.45;color:#8b949e;margin:0;}" +
    ".o11y-ab-label{font-size:0.78rem;font-weight:600;color:#8b949e;display:block;margin-bottom:0.25rem;}" +
    ".o11y-ab-input,.o11y-ab-textarea{width:100%;box-sizing:border-box;border-radius:8px;border:1px solid #30363d;background:#0d1117;color:#e6edf3;font:inherit;padding:0.45rem 0.55rem;font-size:0.85rem;}" +
    ".o11y-ab-textarea{min-height:4.5rem;resize:vertical;}" +
    ".o11y-ab-row{display:flex;gap:0.4rem;flex-wrap:wrap;align-items:center;}" +
    ".o11y-ab-btn{appearance:none;border:1px solid #30363d;background:#21262d;color:#e6edf3;font:inherit;font-size:0.82rem;font-weight:600;padding:0.4rem 0.75rem;border-radius:8px;cursor:pointer;}" +
    ".o11y-ab-btn:hover{border-color:#58a6ff;color:#58a6ff;}" +
    ".o11y-ab-btn.primary{background:rgba(88,166,255,0.15);border-color:rgba(88,166,255,0.45);color:#58a6ff;}" +
    ".o11y-ab-msgs{flex:1;min-height:6rem;max-height:11rem;overflow:auto;border:1px solid #30363d;border-radius:8px;padding:0.5rem;background:#0d1117;font-size:0.82rem;line-height:1.45;}" +
    ".o11y-ab-msg{margin:0 0 0.5rem;padding:0.45rem 0.55rem;border-radius:6px;white-space:pre-wrap;word-break:break-word;}" +
    ".o11y-ab-msg.user{background:rgba(88,166,255,0.12);border:1px solid rgba(88,166,255,0.25);}" +
    ".o11y-ab-msg.bot{background:rgba(63,185,80,0.08);border:1px solid rgba(63,185,80,0.2);}" +
    ".o11y-ab-msg.err{background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.35);color:#ffa198;}" +
    ".o11y-ab-code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:0.72rem;background:#161b22;border:1px solid #30363d;border-radius:8px;padding:0.5rem;overflow:auto;max-height:9rem;white-space:pre-wrap;word-break:break-all;}" +
    "a.o11y-ab-link{color:#58a6ff;font-weight:600;text-decoration:none;font-size:0.82rem;}" +
    "a.o11y-ab-link:hover{text-decoration:underline;}" +
    ".o11y-ab-head-main{flex:1;min-width:0;display:flex;flex-direction:column;gap:0.2rem;}" +
    ".o11y-ab-title-row{display:flex;align-items:center;gap:0.4rem;flex-wrap:wrap;}" +
    ".o11y-ab-hosted-pill{font-size:0.62rem;font-weight:750;letter-spacing:0.06em;text-transform:uppercase;padding:0.12rem 0.42rem;border-radius:999px;background:rgba(63,185,80,0.22);color:#3fb950;border:1px solid rgba(63,185,80,0.5);}" +
    "#o11y-ab-agent-hint{min-height:1.1em;}";

  var style = document.createElement("style");
  style.textContent = css;
  document.head.appendChild(style);

  var fabLabel = SERVER_PROXY ? "Live · chat" : "Cross-sell help";
  var agentPlaceholder = SERVER_PROXY
    ? "Optional: override server default agent id"
    : "Leave blank for default agent";

  var introHtml = SERVER_PROXY
    ? "<p class=\"o11y-ab-note\">You are on the <strong>hosted</strong> build: chat goes to <code style=\"color:#79c0ff\">" +
      escapeAttr(CONVERSE_URL) +
      "</code>, not straight to Kibana in the browser. Set <code style=\"color:#79c0ff\">KIBANA_AGENT_ID</code> in Vercel to pin your workshop agent when this field is empty.</p>"
    : "<p class=\"o11y-ab-note\">Uses <code style=\"color:#79c0ff\">POST /api/agent_builder/converse</code> on the same host as the lab MCP URL. Paste a Kibana API key with Agent Builder access (stored only in <strong>session storage</strong> for this tab).</p>";

  var corsHtml = SERVER_PROXY
    ? ""
    : "<p class=\"o11y-ab-note\">Many Kibana deployments do not send CORS headers to static hosts like GitHub Pages, so the browser may block the request. If chat fails with “Failed to fetch”, deploy this site behind a small proxy (see <code>web/README.md</code>), use the MCP tab in Cursor, or open Kibana and chat there.</p>";

  var keyBlock =
    '<div id="o11y-ab-key-row"' +
    (SERVER_PROXY ? ' style="display:none"' : "") +
    ">" +
    '    <label class="o11y-ab-label" for="o11y-ab-key">Kibana API key</label>' +
    '    <input id="o11y-ab-key" class="o11y-ab-input" type="password" autocomplete="off" placeholder="Base64 API key" />' +
    "</div>";

  var root = document.createElement("div");
  root.id = "o11y-ab-assistant-root";
  root.setAttribute("aria-live", "polite");
  root.innerHTML =
    '<button type="button" id="o11y-ab-fab" aria-expanded="false" aria-controls="o11y-ab-panel">' +
    escapeAttr(fabLabel) +
    "</button>" +
    '<div id="o11y-ab-panel" role="dialog" aria-label="o11y-security Agent Builder assistant">' +
    '  <div id="o11y-ab-head">' +
    '    <div class="o11y-ab-head-main">' +
    '      <div class="o11y-ab-title-row">' +
    "        <strong>Agent Builder</strong>" +
    '        <span id="o11y-ab-hosted-pill" class="o11y-ab-hosted-pill"' +
    (SERVER_PROXY ? "" : ' style="display:none"') +
    ">Hosted</span>" +
    "      </div>" +
    '      <span id="o11y-ab-agent-hint" class="o11y-ab-note"' +
    (SERVER_PROXY ? "" : ' style="display:none"') +
    "></span>" +
    "    </div>" +
    '    <button type="button" id="o11y-ab-close" aria-label="Close">×</button>' +
    "  </div>" +
    '  <div id="o11y-ab-tabs" role="tablist">' +
    '    <button type="button" role="tab" id="o11y-tab-chat" aria-selected="true" aria-controls="o11y-pane-chat">Kibana chat</button>' +
    '    <button type="button" role="tab" id="o11y-tab-mcp" aria-selected="false" aria-controls="o11y-pane-mcp">MCP (Cursor)</button>' +
    "  </div>" +
    '  <div id="o11y-pane-chat" class="o11y-ab-pane active" role="tabpanel" aria-labelledby="o11y-tab-chat">' +
    introHtml +
    corsHtml +
    keyBlock +
    '    <label class="o11y-ab-label" for="o11y-ab-agent">Agent id (optional)</label>' +
    '    <input id="o11y-ab-agent" class="o11y-ab-input" type="text" autocomplete="off" placeholder="' +
    escapeAttr(agentPlaceholder) +
    '" />' +
    '    <div id="o11y-ab-msgs" class="o11y-ab-msgs" aria-label="Messages"></div>' +
    '    <label class="o11y-ab-label" for="o11y-ab-user">Message</label>' +
    '    <textarea id="o11y-ab-user" class="o11y-ab-textarea" placeholder="Ask about Observability ↔ Security cross-sell, MCP, or the workshop…"></textarea>' +
    '    <div class="o11y-ab-row">' +
    '      <button type="button" class="o11y-ab-btn primary" id="o11y-ab-send">Send</button>' +
    '      <button type="button" class="o11y-ab-btn" id="o11y-ab-clear">New conversation</button>' +
    "    </div>" +
    '    <a class="o11y-ab-link" href="' +
    KIBANA_BASE +
    '/" target="_blank" rel="noopener noreferrer">Open this Kibana →</a>' +
    "  </div>" +
    '  <div id="o11y-pane-mcp" class="o11y-ab-pane" role="tabpanel" aria-labelledby="o11y-tab-mcp" hidden>' +
    "    <p class=\"o11y-ab-note\">MCP is for editor and automation clients (Cursor, Claude Desktop, VS Code). It is not invoked directly from static HTML; use the URL below in your MCP config together with <code style=\"color:#79c0ff\">Authorization: ApiKey …</code>.</p>" +
    '    <span class="o11y-ab-label">MCP endpoint</span>' +
    '    <div class="o11y-ab-code" id="o11y-ab-mcp-url"></div>' +
    '    <div class="o11y-ab-row">' +
    '      <button type="button" class="o11y-ab-btn" id="o11y-ab-copy-mcp">Copy MCP URL</button>' +
    '      <button type="button" class="o11y-ab-btn" id="o11y-ab-copy-json">Copy Cursor-style JSON</button>' +
    "    </div>" +
    "    <p class=\"o11y-ab-note\">Official setup: <a class=\"o11y-ab-link\" href=\"https://www.elastic.co/docs/explore-analyze/ai-features/agent-builder/mcp-server\" target=\"_blank\" rel=\"noopener noreferrer\">Elastic Agent Builder MCP server →</a></p>" +
    "  </div>" +
    "</div>";

  document.body.appendChild(root);

  var fab = document.getElementById("o11y-ab-fab");
  var panel = document.getElementById("o11y-ab-panel");
  var closeBtn = document.getElementById("o11y-ab-close");
  var tabChat = document.getElementById("o11y-tab-chat");
  var tabMcp = document.getElementById("o11y-tab-mcp");
  var paneChat = document.getElementById("o11y-pane-chat");
  var paneMcp = document.getElementById("o11y-pane-mcp");
  var keyInput = document.getElementById("o11y-ab-key");
  var agentInput = document.getElementById("o11y-ab-agent");
  var userInput = document.getElementById("o11y-ab-user");
  var msgs = document.getElementById("o11y-ab-msgs");
  var sendBtn = document.getElementById("o11y-ab-send");
  var clearBtn = document.getElementById("o11y-ab-clear");
  var mcpUrlEl = document.getElementById("o11y-ab-mcp-url");
  var copyMcp = document.getElementById("o11y-ab-copy-mcp");
  var copyJson = document.getElementById("o11y-ab-copy-json");

  mcpUrlEl.textContent = MCP_URL;

  try {
    keyInput.value = sessionStorage.getItem(SK) || "";
    agentInput.value = sessionStorage.getItem(SK_AGENT) || "";
  } catch (e) {}

  var agentHint = document.getElementById("o11y-ab-agent-hint");
  if (SERVER_PROXY && agentHint) {
    fetch("/api/assistant-config", { method: "GET", credentials: "same-origin" })
      .then(function (r) {
        return r.json();
      })
      .then(function (cfg) {
        if (!cfg || !agentHint) return;
        if (cfg.defaultAgentConfigured && cfg.defaultAgentTail) {
          agentHint.textContent =
            "Server default agent id ends with ···" + String(cfg.defaultAgentTail) + " (from KIBANA_AGENT_ID).";
        } else {
          agentHint.textContent =
            "No KIBANA_AGENT_ID in Vercel yet — Kibana’s default agent is used unless you paste an id above.";
        }
      })
      .catch(function () {
        if (agentHint) agentHint.textContent = "";
      });
  }

  function setOpen(open) {
    panel.classList.toggle("open", open);
    fab.setAttribute("aria-expanded", open ? "true" : "false");
  }

  fab.addEventListener("click", function () {
    setOpen(!panel.classList.contains("open"));
  });
  closeBtn.addEventListener("click", function () {
    setOpen(false);
  });

  function selectTab(which) {
    var isChat = which === "chat";
    tabChat.setAttribute("aria-selected", isChat ? "true" : "false");
    tabMcp.setAttribute("aria-selected", isChat ? "false" : "true");
    paneChat.classList.toggle("active", isChat);
    paneMcp.classList.toggle("active", !isChat);
    paneChat.hidden = !isChat;
    paneMcp.hidden = isChat;
  }
  tabChat.addEventListener("click", function () {
    selectTab("chat");
  });
  tabMcp.addEventListener("click", function () {
    selectTab("mcp");
  });

  keyInput.addEventListener("change", function () {
    try {
      sessionStorage.setItem(SK, keyInput.value);
    } catch (e) {}
  });
  agentInput.addEventListener("change", function () {
    try {
      sessionStorage.setItem(SK_AGENT, agentInput.value.trim());
    } catch (e) {}
  });

  function getConversationId() {
    try {
      return sessionStorage.getItem(SK_CONV) || "";
    } catch (e) {
      return "";
    }
  }

  function setConversationId(id) {
    try {
      if (id) sessionStorage.setItem(SK_CONV, id);
      else sessionStorage.removeItem(SK_CONV);
    } catch (e) {}
  }

  function appendMsg(role, text) {
    var p = document.createElement("p");
    p.className = "o11y-ab-msg " + (role === "user" ? "user" : role === "err" ? "err" : "bot");
    p.textContent = text;
    msgs.appendChild(p);
    msgs.scrollTop = msgs.scrollHeight;
  }

  clearBtn.addEventListener("click", function () {
    setConversationId("");
    msgs.innerHTML = "";
  });

  function mcpCursorJson() {
    return (
      "{\n" +
      '  "mcpServers": {\n' +
      '    "o11y-security-agent-builder": {\n' +
      '      "command": "npx",\n' +
      '      "args": [\n' +
      '        "-y",\n' +
      '        "mcp-remote",\n' +
      '        "' +
      MCP_URL +
      '",\n' +
      '        "--header",\n' +
      '        "Authorization:${AUTH_HEADER}"\n' +
      "      ],\n" +
      '      "env": {\n' +
      '        "AUTH_HEADER": "ApiKey YOUR_KIBANA_API_KEY_HERE"\n' +
      "      }\n" +
      "    }\n" +
      "  }\n" +
      "}\n"
    );
  }

  copyMcp.addEventListener("click", function () {
    copyText(
      MCP_URL,
      function () {
        copyMcp.textContent = "Copied!";
        setTimeout(function () {
          copyMcp.textContent = "Copy MCP URL";
        }, 2000);
      },
      function () {
        copyMcp.textContent = "Copy failed";
        setTimeout(function () {
          copyMcp.textContent = "Copy MCP URL";
        }, 2000);
      }
    );
  });

  copyJson.addEventListener("click", function () {
    copyText(
      mcpCursorJson(),
      function () {
        copyJson.textContent = "Copied!";
        setTimeout(function () {
          copyJson.textContent = "Copy Cursor-style JSON";
        }, 2000);
      },
      function () {
        copyJson.textContent = "Copy failed";
        setTimeout(function () {
          copyJson.textContent = "Copy Cursor-style JSON";
        }, 2000);
      }
    );
  });

  userInput.addEventListener("keydown", function (e) {
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
      e.preventDefault();
      sendBtn.click();
    }
  });

  sendBtn.addEventListener("click", function () {
    var key = keyInput.value.trim();
    var text = userInput.value.trim();
    if (!SERVER_PROXY && !key) {
      appendMsg("err", "Add a Kibana API key first.");
      return;
    }
    if (!text) return;

    try {
      if (!SERVER_PROXY) sessionStorage.setItem(SK, key);
      sessionStorage.setItem(SK_AGENT, agentInput.value.trim());
    } catch (e) {}

    appendMsg("user", text);
    userInput.value = "";
    sendBtn.disabled = true;

    var body = { input: text };
    var cid = getConversationId();
    if (cid) body.conversation_id = cid;
    var aid = agentInput.value.trim();
    if (aid) body.agent_id = aid;

    var headers = {
      "Content-Type": "application/json",
      "kbn-xsrf": "true",
    };
    if (!SERVER_PROXY) headers.Authorization = "ApiKey " + key;

    fetch(CONVERSE_URL, {
      method: "POST",
      headers: headers,
      body: JSON.stringify(body),
      credentials: SERVER_PROXY ? "same-origin" : "omit",
    })
      .then(function (r) {
        return r.text().then(function (t) {
          var data = null;
          try {
            data = t ? JSON.parse(t) : null;
          } catch (e) {}
          return { ok: r.ok, status: r.status, data: data, raw: t };
        });
      })
      .then(function (res) {
        sendBtn.disabled = false;
        if (!res.ok) {
          var errMsg =
            (res.data && (res.data.message || res.data.error)) ||
            res.raw ||
            "HTTP " + res.status;
          appendMsg("err", "Request failed: " + errMsg);
          return;
        }
        if (res.data && res.data.conversation_id) setConversationId(res.data.conversation_id);
        var out = extractAssistantMessage(res.data);
        if (!out) out = res.raw ? res.raw.slice(0, 4000) : "(Empty response)";
        appendMsg("bot", out);
      })
      .catch(function (err) {
        sendBtn.disabled = false;
        var msg = err && err.message ? err.message : String(err);
        if (/Failed to fetch|NetworkError|load failed/i.test(msg)) {
          appendMsg(
            "err",
            SERVER_PROXY
              ? "Could not reach this site’s chat proxy. Check Vercel logs and that KIBANA_BASE_URL / KIBANA_API_KEY are set."
              : "Browser could not reach Kibana (often CORS). Use a deployed proxy (see web/README.md), the MCP tab in Cursor, or open Kibana."
          );
        } else {
          appendMsg("err", msg);
        }
      });
  });

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && panel.classList.contains("open")) setOpen(false);
  });
})();
