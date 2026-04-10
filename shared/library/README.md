# Shared Asset Library (V0.1)
This library contains standardized components and logic to accelerate MVP building.

## 📁 [Auth](auth/)
- `supabase_auth_provider.tsx`: Standard wrapper for Supabase Auth.
- `middleware_auth.ts`: Route protection logic.

## 📁 [Database](database/)
- `rls_policies.sql`: Default Row Level Security templates for SaaS isolation.
- `schema_v1.json`: Generic user/project/billing schema.

## 📁 [Finance](finance/)
- `stripe_checkout_handler.ts`: Boilerplate for Stripe sessions.
- `billing_sync_hook.ts`: Syncs Stripe webhooks to Supabase.

## 📁 [Pages](pages/)
- `landing_page_simple.tsx`: High-conversion hero + features template.
- `dashboard_layout.tsx`: Sidebar + Header + Content Area scaffold.
- `pricing_grid.tsx`: Standard SaaS pricing tiers UI.

---
**Usage**: Architect (Arch) must reference these files in `TECH_SPEC.md` to reduce custom code requirements.
