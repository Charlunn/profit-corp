// ---------------------------------------------------------------------------
// Dashboard Layout — shared/library/pages/dashboard_layout.tsx
// Sidebar + Header + Content Area scaffold for Profit-Corp micro-SaaS apps.
// ---------------------------------------------------------------------------

import Link from "next/link";
import { useRouter } from "next/router";
import { useAuth } from "../auth/supabase_auth_provider";

const NAV_ITEMS = [
  { href: "/dashboard",          label: "Overview",  icon: "🏠" },
  { href: "/dashboard/projects", label: "Projects",  icon: "📁" },
  { href: "/dashboard/billing",  label: "Billing",   icon: "💳" },
  { href: "/settings",           label: "Settings",  icon: "⚙️" },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { user, signOut } = useAuth();
  const router = useRouter();

  return (
    <div className="flex h-screen bg-gray-50 text-gray-900 font-sans">
      {/* ── Sidebar ── */}
      <aside className="w-60 bg-white border-r flex flex-col py-6 px-4 gap-2 shrink-0">
        <span className="text-lg font-bold px-2 mb-4">{"{{APP_NAME}}"}</span>

        {NAV_ITEMS.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition
              ${router.pathname === item.href
                ? "bg-gray-100 font-semibold"
                : "text-gray-600 hover:bg-gray-50"}`}
          >
            <span>{item.icon}</span>
            <span>{item.label}</span>
          </Link>
        ))}

        <div className="mt-auto border-t pt-4">
          <p className="text-xs text-gray-400 px-2 truncate">{user?.email}</p>
          <button
            onClick={() => signOut().then(() => router.push("/login"))}
            className="mt-2 w-full text-left text-sm text-red-500 px-2 py-1 rounded hover:bg-red-50"
          >
            Sign out
          </button>
        </div>
      </aside>

      {/* ── Main content ── */}
      <div className="flex flex-col flex-1 overflow-hidden">
        {/* Header */}
        <header className="h-14 bg-white border-b flex items-center px-6 shrink-0">
          <h1 className="text-sm font-semibold text-gray-700">
            {NAV_ITEMS.find((i) => i.href === router.pathname)?.label ?? "Dashboard"}
          </h1>
        </header>

        {/* Content */}
        <main className="flex-1 overflow-y-auto p-8">
          {children}
        </main>
      </div>
    </div>
  );
}
