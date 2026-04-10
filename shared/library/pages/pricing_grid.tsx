// ---------------------------------------------------------------------------
// Pricing Grid — shared/library/pages/pricing_grid.tsx
// Standard SaaS three-tier pricing UI for Profit-Corp micro-SaaS apps.
// Customize: tiers array and onSelectPlan handler.
// ---------------------------------------------------------------------------

type Tier = {
  name: string;
  price: string;        // e.g. "$9" or "Free"
  period: string;       // e.g. "/mo" or ""
  description: string;
  features: string[];
  cta: string;
  highlighted?: boolean; // shows "Most Popular" badge
  plan: string;          // plan key sent to stripe_checkout_handler
};

const TIERS: Tier[] = [
  {
    name: "Free",
    price: "$0",
    period: "/mo",
    description: "Get started at no cost.",
    features: [
      "{{Feature A}}",
      "{{Feature B}}",
      "{{Feature C — limited}}",
    ],
    cta: "Get started",
    plan: "free",
  },
  {
    name: "Starter",
    price: "${{price}}",
    period: "/mo",
    description: "For small teams and solo builders.",
    features: [
      "Everything in Free",
      "{{Feature D}}",
      "{{Feature E}}",
      "Priority support",
    ],
    cta: "Start free trial",
    highlighted: true,
    plan: "starter",
  },
  {
    name: "Pro",
    price: "${{price}}",
    period: "/mo",
    description: "For growing businesses.",
    features: [
      "Everything in Starter",
      "{{Feature F}}",
      "{{Feature G}}",
      "Dedicated account manager",
    ],
    cta: "Upgrade to Pro",
    plan: "pro",
  },
];

type PricingGridProps = {
  onSelectPlan: (plan: string) => void;
};

export default function PricingGrid({ onSelectPlan }: PricingGridProps) {
  return (
    <section className="py-16 px-6 bg-white">
      <h2 className="text-3xl font-bold text-center mb-4">Simple, transparent pricing</h2>
      <p className="text-center text-gray-500 mb-12">
        Start free. Upgrade when you need more.
      </p>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-5xl mx-auto">
        {TIERS.map((tier) => (
          <div
            key={tier.name}
            className={`relative flex flex-col rounded-2xl border p-8 gap-6
              ${tier.highlighted
                ? "border-black shadow-lg scale-105"
                : "border-gray-200"}`}
          >
            {tier.highlighted && (
              <span className="absolute -top-3 left-1/2 -translate-x-1/2 bg-black text-white text-xs px-3 py-1 rounded-full">
                Most Popular
              </span>
            )}

            <div>
              <h3 className="text-lg font-semibold">{tier.name}</h3>
              <p className="text-gray-400 text-sm mt-1">{tier.description}</p>
            </div>

            <div className="flex items-end gap-1">
              <span className="text-4xl font-extrabold">{tier.price}</span>
              <span className="text-gray-400 text-sm mb-1">{tier.period}</span>
            </div>

            <ul className="flex flex-col gap-2 text-sm text-gray-600">
              {tier.features.map((f) => (
                <li key={f} className="flex items-center gap-2">
                  <span className="text-green-500">✓</span> {f}
                </li>
              ))}
            </ul>

            <button
              onClick={() => onSelectPlan(tier.plan)}
              className={`mt-auto w-full py-3 rounded-xl font-semibold text-sm transition
                ${tier.highlighted
                  ? "bg-black text-white hover:bg-gray-800"
                  : "border border-gray-300 hover:bg-gray-50"}`}
            >
              {tier.cta}
            </button>
          </div>
        ))}
      </div>
    </section>
  );
}
