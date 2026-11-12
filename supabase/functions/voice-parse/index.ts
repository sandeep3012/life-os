// LifeOS voice entry: turns one spoken sentence into three candidate records
// (expense, income, task, habit or event) for the app to offer.
//
// Deploy:   supabase functions deploy voice-parse
// Secret:   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//
// Only signed-in users can call it (the Supabase JWT is verified), and each
// is held to a daily allowance by `consume_voice_quota`. The API key never
// leaves this function.

import Anthropic from "npm:@anthropic-ai/sdk@1.1.0";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";

const MODEL = "claude-haiku-5-5";
const DAILY_LIMIT = 100;
const MAX_SENTENCE = 500;

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

// What one candidate looks like. Names, not ids: the model picks from the
// account and category names it's given, and the app maps them to its rows.
const option = {
  type: "object",
  additionalProperties: false,
  required: [
    "kind", "summary", "title", "amount", "account", "category",
    "date", "time", "endTime", "repeat", "weekdays", "notes",
  ],
  properties: {
    kind: { type: "string", enum: ["expense", "income", "task", "habit", "event"] },
    summary: {
      type: "string",
      description: "One short line describing the record, as the user would read it.",
    },
    title: { type: "string" },
    amount: {
      anyOf: [{ type: "number" }, { type: "null" }],
      description: "Money in major units (250.5), expense and income only.",
    },
    account: {
      anyOf: [{ type: "string" }, { type: "null" }],
      description: "Exactly one of the given account names, or null.",
    },
    category: {
      anyOf: [{ type: "string" }, { type: "null" }],
      description: "Exactly one of the given category names for this kind, or null.",
    },
    date: {
      anyOf: [{ type: "string", format: "date" }, { type: "null" }],
      description: "YYYY-MM-DD in the user's time zone.",
    },
    time: {
      anyOf: [{ type: "string" }, { type: "null" }],
      description: "HH:MM, 24-hour, in the user's time zone.",
    },
    endTime: {
      anyOf: [{ type: "string" }, { type: "null" }],
      description: "HH:MM end, events only.",
    },
    repeat: { type: "string", enum: ["none", "daily", "weekly", "monthly", "yearly"] },
    weekdays: {
      type: "array",
      items: { type: "integer" },
      description: "For weekly repeats: 1 = Monday … 7 = Sunday.",
    },
    notes: { anyOf: [{ type: "string" }, { type: "null" }] },
  },
} as const;

const schema = {
  type: "object",
  additionalProperties: false,
  required: ["options"],
  properties: { options: { type: "array", items: option } },
} as const;

const SYSTEM = `You turn one sentence a person spoke into a record for LifeOS, a personal life-management app. The sentence came from speech recognition, so expect misheard words, spoken numbers ("two fifty" = 250) and Hinglish ("250 ka lunch HDFC card se").

Return exactly three options, the most likely first. Make them genuinely different readings — a different kind, category, account, amount or date — not three copies. If the sentence is clear, the second and third are the next most plausible alternatives.

Kinds:
- expense / income: money spent or received. Needs an amount. Pick the account and category only from the names given; null if none fits.
- task: something to do, optionally due at a date and time.
- habit: a recurring routine to track ("every morning", "daily", "Mon Wed Fri").
- event: something happening at a time, usually with a start and end.

Dates and times are in the user's time zone; resolve "today", "tomorrow", "next Friday", "tonight" against the current date and time given. Leave a field null when the sentence doesn't say it — don't invent amounts, accounts or times. Titles are short and plain ("Lunch at Subway", "Call Mom"); summaries read like "₹250 expense · Dining · HDFC card · today".`;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function names(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((v): v is string => typeof v === "string").slice(0, 100)
    : [];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  // Signed-in users only, checked against Supabase Auth.
  const authHeader = req.headers.get("Authorization") ?? "";
  // Supabase provides the project's public key to every function; projects
  // that have turned off the legacy anon key may expose it under the newer
  // name, or it can be set as the LIFEOS_PUBLISHABLE_KEY secret.
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ||
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ||
    Deno.env.get("LIFEOS_PUBLISHABLE_KEY");
  if (!publicKey) return reply(500, { error: "missing_public_key" });
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    publicKey,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData } = await supabase.auth.getUser();
  if (!userData?.user) return reply(401, { error: "not_signed_in" });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "bad_request" });
  }
  const text = typeof body.text === "string" ? body.text.trim() : "";
  if (!text || text.length > MAX_SENTENCE) return reply(400, { error: "bad_request" });

  const { data: allowed, error: quotaError } = await supabase.rpc(
    "consume_voice_quota",
    { daily_limit: DAILY_LIMIT },
  );
  if (quotaError) return reply(500, { error: "quota_unavailable" });
  if (allowed !== true) return reply(429, { error: "daily_limit" });

  const categories = (body.categories ?? {}) as Record<string, unknown>;
  const context = [
    `Now: ${String(body.now ?? "")} (${String(body.timeZone ?? "local time")})`,
    `Currency: ${String(body.currency ?? "INR")}`,
    `Accounts: ${names(body.accounts).join(", ") || "(none)"}`,
    `Expense categories: ${names(categories.expense).join(", ") || "(none)"}`,
    `Income categories: ${names(categories.income).join(", ") || "(none)"}`,
    `Task and habit categories: ${names(categories.planner).join(", ") || "(none)"}`,
  ].join("\n");

  try {
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 2000,
      // A short extraction: low effort keeps it fast.
      output_config: {
        effort: "low",
        format: { type: "json_schema", schema },
      },
      system: SYSTEM,
      messages: [
        { role: "user", content: `${context}\n\nThe person said: "${text}"` },
      ],
    });

    if (response.stop_reason === "refusal") {
      return reply(422, { error: "not_understood" });
    }
    if (response.stop_reason === "max_tokens") {
      return reply(502, { error: "incomplete" });
    }
    const out = response.content.find((b) => b.type === "text");
    if (!out || out.type !== "text") return reply(502, { error: "incomplete" });
    const parsed = JSON.parse(out.text) as { options?: unknown[] };
    const options = Array.isArray(parsed.options) ? parsed.options.slice(0, 3) : [];
    if (options.length === 0) return reply(422, { error: "not_understood" });
    return reply(200, { options });
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return reply(503, { error: "busy" });
    if (e instanceof Anthropic.APIConnectionError) return reply(503, { error: "busy" });
    if (e instanceof Anthropic.APIError) return reply(502, { error: "ai_error" });
    return reply(500, { error: "internal" });
  }
});
