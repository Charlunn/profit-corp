// ---------------------------------------------------------------------------
// Landing Page — shared/library/pages/landing_page_simple.tsx
// High-conversion hero + features template for Profit-Corp micro-SaaS apps.
// Customize: APP_NAME, TAGLINE, FEATURES, CTA_URL
// ---------------------------------------------------------------------------

import Link from "next/link";

const APP_NAME  = "{{APP_NAME}}";
const TAGLINE   = "{{ONE_LINE_VALUE_PROP}}";
const CTA_URL   = "/signup";

const FEATURES: { icon: string; title: string; desc: string }[] = [
  { icon: "⚡", title: "{{Feature 1}}", desc: "{{Short description of feature 1}}" },
  { icon: "🔒", title: "{{Feature 2}}", desc: "{{Short description of feature 2}}" },
  { icon: "📊", title: "{{Feature 3}}", desc: "{{Short description of feature 3}}" },
];

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-white text-gray-900 font-sans">
      {/* ── Navbar ── */}
      <nav className="flex items-center justify-between px-8 py-4 border-b">
        <span className="text-xl font-bold">{APP_NAME}</span>
        <div className="flex gap-4">
          <Link href="/login"  className="text-sm text-gray-600 hover:text-gray-900">Log in</Link>
          <Link href={CTA_URL} className="text-sm bg-black text-white px-4 py-2 rounded-lg hover:bg-gray-800">
            Get started free
          </Link>
        </div>
      </nav>

      {/* ── Hero ── */}
      <section className="flex flex-col items-center text-center px-6 py-24 gap-6">
        <h1 className="text-5xl font-extrabold tracking-tight max-w-2xl leading-tight">
          {TAGLINE}
        </h1>
        <p className="text-lg text-gray-500 max-w-xl">
          {"{{Two-sentence elaboration of the value proposition.}}"}
        </p>
        <Link
          href={CTA_URL}
          className="mt-4 bg-black text-white text-lg px-8 py-4 rounded-xl hover:bg-gray-800 transition"
        >
          Start for free →
        </Link>
        <p className="text-sm text-gray-400">No credit card required.</p>
      </section>

      {/* ── Features ── */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-8 px-12 py-16 bg-gray-50">
        {FEATURES.map((f) => (
          <div key={f.title} className="flex flex-col gap-3 p-6 bg-white rounded-2xl shadow-sm">
            <span className="text-3xl">{f.icon}</span>
            <h3 className="text-lg font-semibold">{f.title}</h3>
            <p className="text-gray-500 text-sm">{f.desc}</p>
          </div>
        ))}
      </section>

      {/* ── Footer ── */}
      <footer className="text-center py-8 text-sm text-gray-400 border-t">
        © {new Date().getFullYear()} {APP_NAME}. Built with Profit-Corp.
      </footer>
    </main>
  );
}
