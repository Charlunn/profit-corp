-- =============================================================================
-- RLS Policies — shared/library/database/rls_policies.sql
-- Default Row Level Security templates for SaaS data isolation.
--
-- Design: All tables share a single Supabase project (cost optimisation).
-- Isolation is achieved via `saas_tag` (text column on every table) which
-- identifies which micro-SaaS app owns the row.
--
-- Usage:
--   1. Run schema_v1.json migrations first to create the tables.
--   2. Replace {{APP_TAG}} with your project's unique identifier (e.g. 'invoicer_v1').
--   3. Execute this file against your Supabase project.
-- =============================================================================

-- Enable RLS on core tables
ALTER TABLE public.users    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing  ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- users table
-- ---------------------------------------------------------------------------

-- Each user can only see their own row AND it must belong to the correct app.
CREATE POLICY "users: select own row"
  ON public.users FOR SELECT
  USING (
    auth.uid() = id
    AND saas_tag = '{{APP_TAG}}'
  );

CREATE POLICY "users: insert own row"
  ON public.users FOR INSERT
  WITH CHECK (
    auth.uid() = id
    AND saas_tag = '{{APP_TAG}}'
  );

CREATE POLICY "users: update own row"
  ON public.users FOR UPDATE
  USING (
    auth.uid() = id
    AND saas_tag = '{{APP_TAG}}'
  )
  WITH CHECK (
    auth.uid() = id
    AND saas_tag = '{{APP_TAG}}'
  );

-- ---------------------------------------------------------------------------
-- projects table
-- ---------------------------------------------------------------------------

CREATE POLICY "projects: select own"
  ON public.projects FOR SELECT
  USING (
    owner_id = auth.uid()
    AND saas_tag = '{{APP_TAG}}'
  );

CREATE POLICY "projects: insert own"
  ON public.projects FOR INSERT
  WITH CHECK (
    owner_id = auth.uid()
    AND saas_tag = '{{APP_TAG}}'
  );

CREATE POLICY "projects: update own"
  ON public.projects FOR UPDATE
  USING (owner_id = auth.uid() AND saas_tag = '{{APP_TAG}}')
  WITH CHECK (owner_id = auth.uid() AND saas_tag = '{{APP_TAG}}');

CREATE POLICY "projects: delete own"
  ON public.projects FOR DELETE
  USING (owner_id = auth.uid() AND saas_tag = '{{APP_TAG}}');

-- ---------------------------------------------------------------------------
-- billing table
-- ---------------------------------------------------------------------------

CREATE POLICY "billing: select own"
  ON public.billing FOR SELECT
  USING (
    user_id = auth.uid()
    AND saas_tag = '{{APP_TAG}}'
  );

-- Billing rows are created by server-side webhook only (no direct INSERT from client)
-- No INSERT/UPDATE/DELETE policy needed for the client role.
