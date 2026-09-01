-- Login now captures a password alongside the username (distinct from the
-- Authorization tab's erp_password). Additive — no data loss, existing rows
-- just get erp_login_password = NULL until re-linked/edited.
ALTER TABLE public.user_erp_credentials
    ADD COLUMN IF NOT EXISTS erp_login_password TEXT;
