-- ============================================================================
-- Single active session per interface (Mobile / Desktop) + latest-device-only
-- push notifications.
--
-- The Cashier interface already enforces single-device login via
-- cashier_device_bindings / claim_cashier_session / heartbeat_cashier_session /
-- release_cashier_session (see 01_schema.sql). This migration extends the
-- same pattern to the Mobile and Desktop interfaces using the existing
-- (previously unused) user_device_sessions table, and adds latest-device-only
-- scoping to push_subscriptions.
--
-- Applies uniformly to ALL users, including Master Admin — no exemptions.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. user_device_sessions: one row per (user_id, device_type)
-- ---------------------------------------------------------------------------

-- Defensive cleanup in case any stray duplicate rows exist before adding the
-- uniqueness guarantee (table has had no writers so far, but stay safe).
DELETE FROM public.user_device_sessions a
USING public.user_device_sessions b
WHERE a.user_id = b.user_id
  AND a.device_type = b.device_type
  AND a.ctid < b.ctid;

ALTER TABLE public.user_device_sessions
  DROP CONSTRAINT IF EXISTS user_device_sessions_user_interface_key;
ALTER TABLE public.user_device_sessions
  ADD CONSTRAINT user_device_sessions_user_interface_key UNIQUE (user_id, device_type);

COMMENT ON TABLE public.user_device_sessions IS
  'One active binding per (user_id, device_type in mobile/desktop). Logging in on a new device for the same interface overwrites the row; the previous device is force-logged-out via heartbeat/Realtime, mirroring cashier_device_bindings. Applies to all users including Master Admin.';

-- ---------------------------------------------------------------------------
-- 2. claim_interface_session — called on login (password or quick-access)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.claim_interface_session(
  p_user_id uuid,
  p_device_type text,
  p_device_id text,
  p_device_name text DEFAULT NULL,
  p_user_agent text DEFAULT NULL,
  p_ip_address text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_token text;
BEGIN
  IF p_user_id IS NULL OR p_device_id IS NULL OR length(p_device_id) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid arguments');
  END IF;

  IF p_device_type NOT IN ('mobile', 'desktop') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid device_type');
  END IF;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');

  INSERT INTO public.user_device_sessions
    (user_id, device_id, session_token, device_type, browser_name, user_agent, ip_address, is_active, login_at, last_activity, expires_at, updated_at)
  VALUES
    (p_user_id, p_device_id, v_token, p_device_type, p_device_name, p_user_agent, NULLIF(p_ip_address, '')::inet, true, now(), now(), now() + interval '24 hours', now())
  ON CONFLICT (user_id, device_type) DO UPDATE
    SET device_id     = EXCLUDED.device_id,
        session_token = EXCLUDED.session_token,
        browser_name  = EXCLUDED.browser_name,
        user_agent    = EXCLUDED.user_agent,
        ip_address    = EXCLUDED.ip_address,
        is_active     = true,
        login_at      = now(),
        last_activity = now(),
        expires_at    = now() + interval '24 hours',
        updated_at    = now();

  RETURN jsonb_build_object('success', true, 'session_token', v_token);
END;
$$;

COMMENT ON FUNCTION public.claim_interface_session(uuid, text, text, text, text, text) IS
  'Claims the single active session slot for (user_id, device_type in mobile/desktop). Overwrites any existing binding, invalidating the previous device''s token. No exemption for Master Admin.';

-- ---------------------------------------------------------------------------
-- 3. heartbeat_interface_session — polled by the client to detect a kick
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.heartbeat_interface_session(
  p_user_id uuid,
  p_device_type text,
  p_session_token text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_found boolean;
BEGIN
  UPDATE public.user_device_sessions
     SET last_activity = now(),
         expires_at = now() + interval '24 hours',
         updated_at = now()
   WHERE user_id = p_user_id
     AND device_type = p_device_type
     AND session_token = p_session_token
     AND is_active = true
  RETURNING true INTO v_found;

  RETURN jsonb_build_object('valid', COALESCE(v_found, false));
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. release_interface_session — called on explicit logout
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.release_interface_session(
  p_user_id uuid,
  p_device_type text,
  p_session_token text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE public.user_device_sessions
     SET is_active = false,
         updated_at = now()
   WHERE user_id = p_user_id
     AND device_type = p_device_type
     AND session_token = p_session_token;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_interface_session(uuid, text, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.heartbeat_interface_session(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.release_interface_session(uuid, text, text) TO anon, authenticated;

-- Enable Realtime on this table for instant-kick detection (mirrors
-- cashier_device_bindings, already publicated).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'user_device_sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_device_sessions;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 5. push_subscriptions: latest-device-only per interface (Master Admin included)
-- ---------------------------------------------------------------------------

ALTER TABLE public.push_subscriptions
  ADD COLUMN IF NOT EXISTS interface_type varchar(20),
  ADD COLUMN IF NOT EXISTS manually_disabled boolean NOT NULL DEFAULT false;

ALTER TABLE public.push_subscriptions
  DROP CONSTRAINT IF EXISTS push_subscriptions_interface_type_check;
ALTER TABLE public.push_subscriptions
  ADD CONSTRAINT push_subscriptions_interface_type_check
  CHECK (interface_type IS NULL OR interface_type IN ('mobile', 'desktop', 'cashier'));

COMMENT ON COLUMN public.push_subscriptions.interface_type IS
  'Which interface this browser subscription belongs to. Registering a new subscription for the same user_id + interface_type deactivates every other subscription for that pair — only the latest device per interface receives pushes. Applies to Master Admin too.';
COMMENT ON COLUMN public.push_subscriptions.manually_disabled IS
  'User explicitly turned off notifications on this specific device. Prevents auto re-activation when this device later becomes the latest for its interface.';

CREATE OR REPLACE FUNCTION public.save_push_subscription_scoped(
  p_user_id uuid,
  p_endpoint text,
  p_subscription jsonb,
  p_user_agent text DEFAULT NULL,
  p_interface_type text DEFAULT NULL,
  p_reactivate boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_row_id uuid;
  v_manually_disabled boolean;
BEGIN
  IF p_user_id IS NULL OR p_endpoint IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid arguments');
  END IF;

  IF p_interface_type IS NOT NULL AND p_interface_type NOT IN ('mobile', 'desktop', 'cashier') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid interface_type');
  END IF;

  -- p_reactivate: explicit user action (re-enabling the toggle on this
  -- device) clears a prior manual opt-out. Without it, manually_disabled
  -- sticks across re-registrations (e.g. a silent auto-subscribe on login).
  INSERT INTO public.push_subscriptions
    (user_id, endpoint, subscription, user_agent, interface_type, is_active, manually_disabled, updated_at)
  VALUES
    (p_user_id, p_endpoint, p_subscription, p_user_agent, p_interface_type, true, false, now())
  ON CONFLICT (endpoint) DO UPDATE
    SET user_id           = EXCLUDED.user_id,
        subscription      = EXCLUDED.subscription,
        user_agent        = EXCLUDED.user_agent,
        interface_type    = EXCLUDED.interface_type,
        manually_disabled = CASE WHEN p_reactivate THEN false ELSE push_subscriptions.manually_disabled END,
        is_active         = CASE WHEN p_reactivate THEN true ELSE NOT push_subscriptions.manually_disabled END,
        updated_at        = now()
  RETURNING id, manually_disabled INTO v_row_id, v_manually_disabled;

  -- Latest-device-only: deactivate every other subscription for this
  -- user + interface (applies to Master Admin too — no exemption).
  IF NOT v_manually_disabled AND p_interface_type IS NOT NULL THEN
    UPDATE public.push_subscriptions
       SET is_active = false,
           updated_at = now()
     WHERE user_id = p_user_id
       AND interface_type = p_interface_type
       AND id <> v_row_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'id', v_row_id, 'active', NOT v_manually_disabled);
END;
$$;

COMMENT ON FUNCTION public.save_push_subscription_scoped(uuid, text, jsonb, text, text, boolean) IS
  'Upserts a push subscription by endpoint and makes it the sole active subscription for (user_id, interface_type). Respects manually_disabled: a device the user explicitly opted out of stays inactive even when re-registered.';

CREATE OR REPLACE FUNCTION public.disable_push_subscription_device(
  p_endpoint text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE public.push_subscriptions
     SET is_active = false,
         manually_disabled = true,
         updated_at = now()
   WHERE endpoint = p_endpoint;

  RETURN jsonb_build_object('success', true);
END;
$$;

COMMENT ON FUNCTION public.disable_push_subscription_device(text) IS
  'Explicit per-device opt-out: marks this endpoint manually_disabled so it will not be silently re-activated by the latest-device-per-interface logic.';

GRANT EXECUTE ON FUNCTION public.save_push_subscription_scoped(uuid, text, jsonb, text, text, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disable_push_subscription_device(text) TO anon, authenticated;
