// PersonalOS Plus: RevenueCat tells this function about every purchase,
// renewal, cancellation and expiry, and it keeps the account's row in
// `entitlements` in step. That row — not anything the app says — is what
// lets an account sync, use its voice allowance and keep the Plus looks.
//
// Deploy:   supabase functions deploy revenuecat-webhook --no-verify-jwt
// Secrets:  supabase secrets set REVENUECAT_WEBHOOK_AUTH=<a long random string>
//           supabase secrets set REVENUECAT_ALLOW_SANDBOX=true   (testing only)
// RevenueCat → Project → Integrations → Webhooks:
//           URL    https://<project>.supabase.co/functions/v1/revenuecat-webhook
//           Authorization header   the same long random string
//
// RevenueCat calls this without a Supabase sign-in, so JWT verification is
// off and the shared Authorization value is the only thing that lets a
// request in. Without the secret set, every request is refused.
//
// The app buys under the account's id (Purchases.logIn(userId)), so
// `app_user_id` is the Supabase user id.

import { createClient } from "npm:@supabase/supabase-js@2.118.0";

// Must match RevenueCatConfig.entitlement in the app and the entitlement's
// identifier in the RevenueCat dashboard.
const ENTITLEMENT = "plus";

// Rows this function must never change: grants made by hand that don't
// come from a store.
const PROTECTED_STORES = new Set(["owner", "manual"]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type RcEvent = {
  type?: string;
  environment?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  entitlement_ids?: string[] | null;
  product_id?: string;
  store?: string;
  event_timestamp_ms?: number;
  expiration_at_ms?: number | null;
  grace_period_expiration_at_ms?: number | null;
  cancel_reason?: string;
  transferred_from?: string[];
  transferred_to?: string[];
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Compares in constant time, so the secret can't be guessed a character at
// a time from how long a refusal takes.
function same(a: string, b: string) {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

const iso = (ms: number | null | undefined) =>
  typeof ms === "number" ? new Date(ms).toISOString() : null;

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_AUTH") ?? "";
  if (secret.length < 16) return reply(500, { error: "not_configured" });
  const given = req.headers.get("Authorization") ?? "";
  if (!same(given, secret) && !same(given, `Bearer ${secret}`)) {
    return reply(401, { error: "unauthorized" });
  }

  let event: RcEvent;
  try {
    event = ((await req.json()) as { event?: RcEvent }).event ?? {};
  } catch {
    return reply(400, { error: "bad_request" });
  }
  const type = event.type ?? "";
  // RevenueCat's "send test event" button.
  if (type === "TEST") return reply(200, { ok: true, ignored: "test" });

  // Pretend purchases (RevenueCat's Test Store, Play licence testers) only
  // count while testing. In production they must not hand out Plus.
  const sandbox = (event.environment ?? "").toUpperCase() !== "PRODUCTION";
  if (sandbox && Deno.env.get("REVENUECAT_ALLOW_SANDBOX") !== "true") {
    return reply(200, { ok: true, ignored: "sandbox" });
  }

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // Only ids that are real accounts here; RevenueCat's anonymous ids and
  // anything else are skipped.
  async function accounts(ids: (string | undefined)[]) {
    const found: string[] = [];
    for (const id of new Set(ids.filter((i): i is string => !!i && UUID.test(i)))) {
      const { data } = await db.auth.admin.getUserById(id);
      if (data?.user) found.push(id);
    }
    return found;
  }

  async function current(userId: string) {
    const { data } = await db.from("entitlements")
      .select("active, product_id, store, expires_at, updated_at")
      .eq("user_id", userId).maybeSingle();
    return data as
      | { active: boolean; product_id: string | null; store: string | null;
          expires_at: string | null; updated_at: string }
      | null;
  }

  const at = iso(event.event_timestamp_ms) ?? new Date().toISOString();

  async function write(
    userId: string,
    row: { active: boolean; expires_at: string | null; product_id?: string | null; store?: string | null },
  ) {
    const existing = await current(userId);
    if (existing && PROTECTED_STORES.has(existing.store ?? "")) return "protected";
    // Events can arrive out of order; an older one mustn't undo a newer one.
    // (A testing-period 'beta' grant is always replaced by a real purchase.)
    if (
      existing && existing.store !== "beta" &&
      Date.parse(existing.updated_at) > Date.parse(at)
    ) return "stale";
    const { error } = await db.from("entitlements").upsert({
      user_id: userId,
      active: row.active,
      expires_at: row.expires_at,
      product_id: row.product_id ?? existing?.product_id ?? null,
      store: row.store ?? existing?.store ?? null,
      updated_at: at,
    });
    if (error) throw error;
    return "written";
  }

  try {
    // A subscription moved from one account to another (restored under a
    // different sign-in): the new account takes over what the old one had.
    if (type === "TRANSFER") {
      const from = await accounts(event.transferred_from ?? []);
      const to = await accounts(event.transferred_to ?? []);
      let carried: Awaited<ReturnType<typeof current>> = null;
      for (const id of from) {
        const row = await current(id);
        if (row && !PROTECTED_STORES.has(row.store ?? "") && row.store !== "beta") {
          carried ??= row;
          await write(id, { active: false, expires_at: row.expires_at });
        }
      }
      if (carried?.active) {
        for (const id of to) {
          await write(id, {
            active: true,
            expires_at: carried.expires_at,
            product_id: carried.product_id,
            store: carried.store,
          });
        }
      }
      return reply(200, { ok: true });
    }

    // Events about some other entitlement aren't ours to act on.
    const ids = event.entitlement_ids;
    if (Array.isArray(ids) && ids.length > 0 && !ids.includes(ENTITLEMENT)) {
      return reply(200, { ok: true, ignored: "other_entitlement" });
    }

    const users = await accounts([
      event.app_user_id,
      event.original_app_user_id,
      ...(event.aliases ?? []),
    ]);
    if (users.length === 0) return reply(200, { ok: true, ignored: "no_account" });

    const store = (event.store ?? "").toLowerCase() || null;
    const expires = iso(event.expiration_at_ms);
    let row: Parameters<typeof write>[1] | null = null;

    switch (type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "UNCANCELLATION":
      case "PRODUCT_CHANGE":
      case "NON_RENEWING_PURCHASE":
      case "SUBSCRIPTION_EXTENDED":
      case "TEMPORARY_ENTITLEMENT_GRANT":
        row = { active: true, expires_at: expires, product_id: event.product_id, store };
        break;
      case "CANCELLATION":
        // Usually "won't renew": Plus runs to the end of what was paid for.
        // A refund ends it now.
        row = event.cancel_reason === "CUSTOMER_SUPPORT"
          ? { active: false, expires_at: expires, product_id: event.product_id, store }
          : { active: true, expires_at: expires, product_id: event.product_id, store };
        break;
      case "BILLING_ISSUE":
        // The store keeps trying the card for a while; Plus lasts that long.
        if (event.grace_period_expiration_at_ms) {
          row = {
            active: true,
            expires_at: iso(event.grace_period_expiration_at_ms),
            product_id: event.product_id,
            store,
          };
        }
        break;
      case "EXPIRATION":
        row = { active: false, expires_at: expires, product_id: event.product_id, store };
        break;
      default:
        // SUBSCRIPTION_PAUSED, INVOICE_ISSUANCE and anything new: nothing
        // changes until an event above says so.
        return reply(200, { ok: true, ignored: type });
    }

    const results: Record<string, string> = {};
    if (row) for (const id of users) results[id] = await write(id, row);
    return reply(200, { ok: true, results: Object.values(results) });
  } catch (_) {
    // A 5xx makes RevenueCat try again later.
    return reply(500, { error: "internal" });
  }
});
