// supabase/functions/security-alert-notify/index.ts
//
// This is a Supabase Edge Function — code that runs inside your own
// Supabase project (not a third-party automation tool). It's called
// directly by a Supabase Database Webhook the instant a row is
// inserted into public.security_alerts, and sends:
//   - an email via Resend (always, if RESEND_API_KEY is set)
//   - a WhatsApp message via Meta's WhatsApp Cloud API (only if the
//     WHATSAPP_* secrets below are set — safe to leave WhatsApp unset
//     and just use email until you're ready to add it)
//
// Nothing here depends on Zapier, Make, or any bot service.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// ---- Configuration (set these with `supabase secrets set`, not in code) ----
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET") ?? "";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const ALERT_EMAIL_FROM = Deno.env.get("ALERT_EMAIL_FROM") ?? "onboarding@resend.dev";
const ALERT_EMAIL_TO = Deno.env.get("ALERT_EMAIL_TO") ?? "coderinnovator@gmail.com";

const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_TOKEN") ?? "";
const WHATSAPP_PHONE_NUMBER_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") ?? "";
const WHATSAPP_TO_NUMBER = Deno.env.get("WHATSAPP_TO_NUMBER") ?? "";

interface SecurityAlertRow {
  id: string;
  alert_type: string;
  identifier: string | null;
  device_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
}

interface DatabaseWebhookPayload {
  type: string;
  table: string;
  record: SecurityAlertRow;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Defense in depth: only accept calls that include the shared
  // secret you configured on the Supabase Database Webhook. Without
  // this, anyone who guessed your function's URL could trigger it.
  if (WEBHOOK_SECRET && req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  let payload: DatabaseWebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  const alert = payload.record;
  if (!alert) {
    return new Response("No record in payload", { status: 400 });
  }

  const summary =
    `${alert.alert_type} — identifier: ${alert.identifier ?? "n/a"}, ` +
    `device: ${alert.device_id ?? "n/a"}`;
  const detailsJson = JSON.stringify(alert.metadata ?? {}, null, 2);

  const results: Record<string, unknown> = {};

  if (RESEND_API_KEY) {
    results.email = await sendEmail(summary, detailsJson, alert);
  } else {
    results.email = "skipped — RESEND_API_KEY not set";
  }

  if (WHATSAPP_TOKEN && WHATSAPP_PHONE_NUMBER_ID && WHATSAPP_TO_NUMBER) {
    results.whatsapp = await sendWhatsApp(summary);
  } else {
    results.whatsapp = "skipped — WhatsApp secrets not set";
  }

  return new Response(JSON.stringify({ ok: true, results }), {
    headers: { "Content-Type": "application/json" },
  });
});

async function sendEmail(summary: string, detailsJson: string, alert: SecurityAlertRow) {
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: ALERT_EMAIL_FROM,
        to: ALERT_EMAIL_TO,
        subject: `[ZETRA ALERT] ${alert.alert_type}`,
        text: `${summary}\n\nAt: ${alert.created_at}\n\nRaw details:\n${detailsJson}`,
      }),
    });
    return { status: res.status, ok: res.ok, body: await res.text() };
  } catch (err) {
    return { ok: false, error: String(err) };
  }
}

async function sendWhatsApp(summary: string) {
  try {
    const res = await fetch(
      `https://graph.facebook.com/v20.0/${WHATSAPP_PHONE_NUMBER_ID}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${WHATSAPP_TOKEN}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: WHATSAPP_TO_NUMBER,
          type: "text",
          text: { body: `Zetra security alert: ${summary}` },
        }),
      },
    );
    return { status: res.status, ok: res.ok, body: await res.text() };
  } catch (err) {
    return { ok: false, error: String(err) };
  }
}
