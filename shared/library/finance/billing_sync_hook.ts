import Stripe from "stripe";
import { createClient } from "@supabase/supabase-js";
import type { NextApiRequest, NextApiResponse } from "next";
import { buffer } from "micro";

// ---------------------------------------------------------------------------
// Billing Sync Hook — shared/library/finance/billing_sync_hook.ts
// Listens to Stripe webhook events and syncs subscription state to Supabase.
// Route: POST /api/billing/webhook
// Disable Next.js body parsing — Stripe requires the raw body for signature verification.
// ---------------------------------------------------------------------------

export const config = { api: { bodyParser: false } };

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: "2023-10-16" });

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!   // service role bypasses RLS for server-side writes
);

const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET!;

async function upsertBilling(customerId: string, data: Record<string, any>) {
  const { error } = await supabase
    .from("billing")
    .upsert({ stripe_customer_id: customerId, ...data }, { onConflict: "stripe_customer_id" });
  if (error) throw new Error(`Supabase upsert failed: ${error.message}`);
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end("Method Not Allowed");

  const rawBody = await buffer(req);
  const sig = req.headers["stripe-signature"] as string;

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, WEBHOOK_SECRET);
  } catch (err: any) {
    console.error("[billing_sync_hook] Webhook signature error:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    switch (event.type) {
      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const sub = event.data.object as Stripe.Subscription;
        await upsertBilling(sub.customer as string, {
          stripe_subscription_id: sub.id,
          plan: sub.items.data[0]?.price.nickname ?? "unknown",
          status: sub.status,
          current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
        });
        break;
      }

      case "customer.subscription.deleted": {
        const sub = event.data.object as Stripe.Subscription;
        await upsertBilling(sub.customer as string, {
          status: "canceled",
          plan: "free",
          stripe_subscription_id: null,
        });
        break;
      }

      default:
        // Unhandled event type — safe to ignore
        break;
    }
  } catch (err: any) {
    console.error("[billing_sync_hook] Processing error:", err.message);
    return res.status(500).json({ error: err.message });
  }

  return res.status(200).json({ received: true });
}
