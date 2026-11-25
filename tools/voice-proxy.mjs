#!/usr/bin/env node
// Calm Hills voice AI proxy.
//
// Browsers can't call the NVIDIA API directly (no CORS), and the API key must
// never ship inside the deployed website. Run this on the demo laptop:
//
//   node tools/voice-proxy.mjs
//
// It reads NVIDIA_API_KEY from the environment or from tools/.env
// (NVIDIA_API_KEY=nvapi-...), listens on http://localhost:8787, and the web
// dashboard's voice desk detects it automatically.
import http from "node:http";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
try {
  for (const line of readFileSync(join(here, ".env"), "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
} catch {
  /* no .env file */
}

const KEY = process.env.NVIDIA_API_KEY;
const MODEL = process.env.NVIDIA_MODEL || "nvidia/nemotron-3.5-lightning-30b-a3b";
const PORT = Number(process.env.PORT || 8787);
const ALLOWED = [
  /^https:\/\/calm-hills-smart-home\.(web\.app|firebaseapp\.com)$/,
  /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
];

if (!KEY) {
  console.error("Missing NVIDIA_API_KEY. Put NVIDIA_API_KEY=nvapi-... in tools/.env");
  process.exit(1);
}

// Mirrors mobile/smart_home_app/lib/voice/llm_agent.dart, minus the fan (mobile-only).
const REPLY_SCHEMA = {
  type: "object",
  properties: {
    actions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          key: {
            type: "string",
            // No fanOn: the proxy serves the web dashboard, and the fan is mobile-only.
            enum: ["garageOpen", "windowOpen", "led1", "led2", "led3", "autoMode", "silenceBuzzer"],
          },
          value: { type: "boolean" },
        },
        required: ["key", "value"],
      },
    },
    reply: { type: "string" },
  },
  required: ["actions", "reply"],
};

const systemPrompt = (state) => `You are "Home", the voice assistant of the Calm Hills smart home.
You control devices by writing boolean commands. Allowed command keys:
- garageOpen: true opens the garage door, false closes it
- windowOpen: true opens the window/roof, false closes it (it closes by itself when it rains; do not open it while state.window.raining is true)
There is also a fan, but it can only be controlled from the mobile app: if asked about the fan, say so and take no fan action.
- led1, led2, led3: the three general control lights, "light 1", "light 2", "light 3" (there are no other lights)
- autoMode: garage opens automatically from the ultrasonic sensor
- silenceBuzzer: true silences the fire alarm buzzer
Current house state (JSON): ${JSON.stringify(state)}
Reply with ONLY a JSON object, no markdown:
{"actions":[{"key":"<command key>","value":true|false}],"reply":"<one or two short spoken sentences>"}
Use an empty actions list for questions or chit-chat. Answer questions from the state.
If a request is unsafe or impossible, explain briefly in reply and take no action.`;

function cors(req, res) {
  const origin = req.headers.origin || "";
  if (ALLOWED.some((r) => r.test(origin))) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    // Chrome Private Network Access: lets the https site reach localhost.
    res.setHeader("Access-Control-Allow-Private-Network", "true");
  }
}

function send(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

async function readJson(req) {
  let raw = "";
  for await (const chunk of req) {
    raw += chunk;
    if (raw.length > 64_000) throw new Error("body too large");
  }
  return JSON.parse(raw || "{}");
}

const server = http.createServer(async (req, res) => {
  cors(req, res);
  if (req.method === "OPTIONS") return res.writeHead(204).end();
  if (req.method === "GET" && req.url === "/health") return send(res, 200, { ok: true, model: MODEL });
  if (req.method !== "POST" || req.url !== "/agent") return send(res, 404, { error: "not found" });

  try {
    const { text, state = {}, history = [] } = await readJson(req);
    if (typeof text !== "string" || !text.trim()) return send(res, 400, { error: "text required" });
    const safeHistory = (Array.isArray(history) ? history : [])
      .filter((m) => m && ["user", "assistant"].includes(m.role) && typeof m.content === "string")
      .slice(-8);
    const started = Date.now();
    const r = await fetch("https://integrate.api.nvidia.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.2,
        max_tokens: 300,
        chat_template_kwargs: { enable_thinking: false },
        response_format: { type: "json_schema", json_schema: { name: "home_actions", schema: REPLY_SCHEMA } },
        messages: [
          { role: "system", content: systemPrompt(state) },
          ...safeHistory,
          { role: "user", content: text.slice(0, 500) },
        ],
      }),
      signal: AbortSignal.timeout(12000),
    });
    const body = await r.json();
    if (!r.ok) {
      console.error("NVIDIA error", r.status, body?.detail || body);
      return send(res, 502, { error: "upstream error" });
    }
    const content = body.choices?.[0]?.message?.content ?? "";
    console.log(`[${Date.now() - started}ms] "${text}" -> ${content.replace(/\s+/g, " ").slice(0, 160)}`);
    send(res, 200, { content });
  } catch (err) {
    console.error(err);
    send(res, 500, { error: "proxy error" });
  }
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`Calm Hills voice proxy on http://localhost:${PORT} (model ${MODEL})`);
});
