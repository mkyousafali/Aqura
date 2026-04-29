-- ============================================================
-- Migration: 20260429_create_user_erp_credentials.sql
-- Purpose:   Per-branch ERP credentials table for keyboard-wedge
--            QR login on the mobile home page.
--
-- SECURITY NOTE: erp_password is stored as plain text by design.
-- This is required so that the mobile app can generate a keyboard-
-- wedge QR code that encodes both username and password verbatim.
-- If you require encryption in future, consider:
--   1. pgcrypto symmetric encryption (pgp_sym_encrypt/decrypt)
--      with a server-side key stored in Supabase Vault.
--   2. Supabase Vault (vault.secrets) to hold the encryption key.
-- Until one of those is in place, protect this table via strict RLS
-- (only the owning user and admins can read rows).
-- ============================================================

-- ── Table ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_erp_credentials (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID          NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  branch_id   BIGINT        NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  erp_username TEXT         NOT NULL,
  erp_password TEXT         NOT NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_user_erp_credentials_user_branch UNIQUE (user_id, branch_id)
);

COMMENT ON TABLE  public.user_erp_credentials IS
  'Per-branch ERP login credentials for users. One row per (user_id, branch_id). '
  'Used to render keyboard-wedge QR codes on the mobile home page. '
  'Passwords are stored in plain text — protect strictly via RLS.';

COMMENT ON COLUMN public.user_erp_credentials.erp_username IS
  'ERP system username; free-form text, may contain spaces and digits.';

COMMENT ON COLUMN public.user_erp_credentials.erp_password IS
  'ERP system password. SECURITY: stored as plain text for QR-wedge generation. '
  'Access is restricted by RLS to the owning user (SELECT) and admins (full CRUD). '
  'Consider pgcrypto/Vault encryption if compliance requires it.';

-- ── Indexes ─────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_user_erp_credentials_user_id
  ON public.user_erp_credentials(user_id);

CREATE INDEX IF NOT EXISTS idx_user_erp_credentials_branch_id
  ON public.user_erp_credentials(branch_id);

-- ── updated_at trigger ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_user_erp_credentials_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_erp_credentials_updated_at ON public.user_erp_credentials;

CREATE TRIGGER trg_user_erp_credentials_updated_at
  BEFORE UPDATE ON public.user_erp_credentials
  FOR EACH ROW EXECUTE FUNCTION public.set_user_erp_credentials_updated_at();

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE public.user_erp_credentials ENABLE ROW LEVEL SECURITY;

-- Admin: full CRUD (matches is_master_admin OR is_admin on users table)
-- We check the calling user's admin flag from the users table itself.
CREATE POLICY "admin_full_access_user_erp_credentials"
  ON public.user_erp_credentials
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND (u.is_master_admin = true OR u.is_admin = true)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND (u.is_master_admin = true OR u.is_admin = true)
    )
  );

-- Authenticated user: SELECT only their own rows
CREATE POLICY "user_self_select_user_erp_credentials"
  ON public.user_erp_credentials
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- No anon / public access (no policy added for anon role)

-- ── Grants ───────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_erp_credentials TO authenticated;
-- UUID primary key uses gen_random_uuid() — no sequence to grant
