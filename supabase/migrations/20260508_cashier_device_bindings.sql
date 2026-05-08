-- =====================================================================
-- Cashier single-device binding (Windows app only — hard kick policy)
-- =====================================================================
-- Each cashier user can be bound to exactly ONE Windows device at a time.
-- A new login on a different device replaces the binding and rotates the
-- session_token. The old device's heartbeat/realtime listener detects
-- the token mismatch and force-logs-out the user.
-- PWA / web users are unaffected (frontend skips these RPCs entirely).
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.cashier_device_bindings (
    user_id        uuid PRIMARY KEY,
    device_id      text NOT NULL,
    device_name    text,
    app_kind       text NOT NULL DEFAULT 'windows',
    session_token  text NOT NULL,
    bound_at       timestamptz NOT NULL DEFAULT now(),
    last_seen_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cashier_device_bindings_device
    ON public.cashier_device_bindings (device_id);

-- Allow Supabase realtime to broadcast row updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.cashier_device_bindings;

-- RLS: enable but provide permissive policies (RPCs use SECURITY DEFINER)
ALTER TABLE public.cashier_device_bindings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cashier_bindings_select ON public.cashier_device_bindings;
CREATE POLICY cashier_bindings_select ON public.cashier_device_bindings
    FOR SELECT USING (true);

-- =====================================================================
-- claim_cashier_session: upsert the binding for this user, rotate token
-- =====================================================================
CREATE OR REPLACE FUNCTION public.claim_cashier_session(
    p_user_id     uuid,
    p_device_id   text,
    p_device_name text DEFAULT NULL,
    p_app_kind    text DEFAULT 'windows'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_token text;
BEGIN
    IF p_user_id IS NULL OR p_device_id IS NULL OR length(p_device_id) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid arguments');
    END IF;

    v_token := encode(gen_random_bytes(24), 'hex');

    INSERT INTO public.cashier_device_bindings
        (user_id, device_id, device_name, app_kind, session_token, bound_at, last_seen_at)
    VALUES
        (p_user_id, p_device_id, p_device_name, COALESCE(p_app_kind, 'windows'), v_token, now(), now())
    ON CONFLICT (user_id) DO UPDATE
        SET device_id     = EXCLUDED.device_id,
            device_name   = EXCLUDED.device_name,
            app_kind      = EXCLUDED.app_kind,
            session_token = EXCLUDED.session_token,
            bound_at      = now(),
            last_seen_at  = now();

    RETURN jsonb_build_object('success', true, 'session_token', v_token);
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_cashier_session(uuid, text, text, text) TO authenticated, anon;

-- =====================================================================
-- heartbeat_cashier_session: returns true if token still matches
-- =====================================================================
CREATE OR REPLACE FUNCTION public.heartbeat_cashier_session(
    p_user_id       uuid,
    p_session_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current text;
BEGIN
    SELECT session_token INTO v_current
    FROM public.cashier_device_bindings
    WHERE user_id = p_user_id;

    IF v_current IS NULL OR v_current <> p_session_token THEN
        RETURN jsonb_build_object('success', false, 'valid', false);
    END IF;

    UPDATE public.cashier_device_bindings
       SET last_seen_at = now()
     WHERE user_id = p_user_id
       AND session_token = p_session_token;

    RETURN jsonb_build_object('success', true, 'valid', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.heartbeat_cashier_session(uuid, text) TO authenticated, anon;

-- =====================================================================
-- release_cashier_session: clear the binding on explicit logout
-- =====================================================================
CREATE OR REPLACE FUNCTION public.release_cashier_session(
    p_user_id       uuid,
    p_session_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    DELETE FROM public.cashier_device_bindings
     WHERE user_id = p_user_id
       AND session_token = p_session_token;

    RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.release_cashier_session(uuid, text) TO authenticated, anon;
