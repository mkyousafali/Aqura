CREATE OR REPLACE FUNCTION public.claim_cashier_session(
    p_user_id     uuid,
    p_device_id   text,
    p_device_name text DEFAULT NULL,
    p_app_kind    text DEFAULT 'windows'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_token text;
BEGIN
    IF p_user_id IS NULL OR p_device_id IS NULL OR length(p_device_id) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid arguments');
    END IF;

    v_token := encode(extensions.gen_random_bytes(24), 'hex');

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
