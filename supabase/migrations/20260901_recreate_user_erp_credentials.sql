-- Recreate user_erp_credentials with ERP branch + Aqura branch tracked
-- separately (previous shape only had a single branch_id). One row per
-- (user, aqura branch): erp_username covers the Login tab link, erp_password
-- covers the Authorization tab password. See
-- [[button-permission-system-rewrite]] for the ERP Credentials admin screen
-- this backs, and frontend/src/lib/components/desktop-interface/settings/ErpCredentials.svelte
-- / the mobile ERP Access page for its consumers.

DROP TABLE IF EXISTS public.user_erp_credentials CASCADE;

CREATE TABLE public.user_erp_credentials (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    aqura_branch_id  BIGINT NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    erp_branch_id    INTEGER NOT NULL,
    erp_user_id      TEXT,
    erp_username     TEXT,
    erp_password     TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_erp_credentials_user_branch UNIQUE (user_id, aqura_branch_id)
);

CREATE INDEX idx_user_erp_credentials_user_id ON public.user_erp_credentials (user_id);
CREATE INDEX idx_user_erp_credentials_aqura_branch_id ON public.user_erp_credentials (aqura_branch_id);
CREATE INDEX idx_user_erp_credentials_erp_branch_id ON public.user_erp_credentials (erp_branch_id);

ALTER TABLE public.user_erp_credentials ENABLE ROW LEVEL SECURITY;

-- Matches the permissive convention already used by user_erp_credentials'
-- previous shape and by erp_connections — this app enforces access at the
-- application layer (admin-only screens, set_user_context()) rather than
-- through native Postgres RLS.
CREATE POLICY "allow_all_operations" ON public.user_erp_credentials
    USING (true)
    WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.set_user_erp_credentials_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_user_erp_credentials_updated_at
    BEFORE UPDATE ON public.user_erp_credentials
    FOR EACH ROW EXECUTE FUNCTION public.set_user_erp_credentials_updated_at();
