import Stripe from "stripe";
import type { NextApiRequest, NextApiResponse } from "next";

// ---------------------------------------------------------------------------
// Stripe Checkout Handler — shared/library/finance/stripe_checkout_handler.ts
// Creates a Stripe Checkout Session for subscription upgrades.
// Route: POST /api/billing/checkout
// ---------------------------------------------------------------------------

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2023-10-16",
});

/** Map your plan names to Stripe Price IDs (set in .env per app). */
const PRICE_IDS: Record<string, string> = {
  starter:    process.env.STRIPE_PRICE_STARTER!,
  pro:        process.env.STRIPE_PRICE_PRO!,
  enterprise: process.env.STRIPE_PRICE_ENTERPRISE!,
};

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { plan, userId, email, successUrl, cancelUrl } = req.body as {
    plan: string;
    userId: string;
    email: string;
    successUrl: string;
    cancelUrl: string;
  };

  const priceId = PRICE_IDS[plan];
  if (!priceId) {
    return res.status(400).json({ error: `Unknown plan: ${plan}` });
  }

  try {
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [{ price: priceId, quantity: 1 }],
      customer_email: email,
      client_reference_id: userId,
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: {
        user_id: userId,
        plan,
      },
    });

    return res.status(200).json({ url: session.url });
  } catch (err: any) {
    console.error("[stripe_checkout_handler] Error:", err.message);
    return res.status(500).json({ error: err.message });
  }
}
