-- Break Security QR Code System
-- Uses a secret seed + server time to generate a rolling code every 10 seconds.
-- No cron/edge function needed — code is computed on-the-fly.

-- 1. Table to store the secret seed (one row only)
CREATE TABLE IF NOT EXISTS public.break_security_seed (
    id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- enforce single row
    seed text NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    created_at timestamptz DEFAULT now()
);

-- Insert the seed row (only once)
INSERT INTO public.break_security_seed (id, seed) 
VALUES (1, encode(gen_random_bytes(32), 'hex'))
ON CONFLICT (id) DO NOTHING;

-- 2. Function to get current break security code (changes every 10 seconds)
CREATE OR REPLACE FUNCTION public.get_break_security_code()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_seed text;
    v_epoch bigint;
    v_code text;
    v_ttl integer;
BEGIN
    SELECT seed INTO v_seed FROM break_security_seed WHERE id = 1;
    
    IF v_seed IS NULL THEN
        RETURN jsonb_build_object('error', 'No security seed configured');
    END IF;
    
    -- Current 10-second epoch
    v_epoch := floor(extract(epoch from now()) / 10)::bigint;
    
    -- Generate code: md5 of seed + epoch, take first 12 chars
    v_code := substring(md5(v_seed || v_epoch::text) from 1 for 12);
    
    -- Time remaining in this window (seconds)
    v_ttl := 10 - (extract(epoch from now())::integer % 10);
    
    RETURN jsonb_build_object(
        'code', v_code,
        'ttl', v_ttl,
        'epoch', v_epoch
    );
END;
$$;

-- 3. Function to validate a scanned break code (accepts current + previous window)
CREATE OR REPLACE FUNCTION public.validate_break_code(p_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_seed text;
    v_epoch bigint;
    v_current_code text;
    v_previous_code text;
BEGIN
    SELECT seed INTO v_seed FROM break_security_seed WHERE id = 1;
    
    IF v_seed IS NULL THEN
        RETURN false;
    END IF;
    
    v_epoch := floor(extract(epoch from now()) / 10)::bigint;
    
    -- Current 10-sec window code
    v_current_code := substring(md5(v_seed || v_epoch::text) from 1 for 12);
    
    -- Previous 10-sec window code (for network delay tolerance)
    v_previous_code := substring(md5(v_seed || (v_epoch - 1)::text) from 1 for 12);
    
    RETURN (p_code = v_current_code OR p_code = v_previous_code);
END;
$$;

-- 4. Update end_break to require security code
CREATE OR REPLACE FUNCTION public.end_break(p_user_id uuid, p_security_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_break_id uuid;
    v_start_time timestamptz;
    v_duration integer;
BEGIN
    -- Validate security code (required)
    IF p_security_code IS NULL OR p_security_code = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Security code is required. Please scan the QR code.');
    END IF;
    
    IF NOT validate_break_code(p_security_code) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid or expired QR code. Please scan the current QR code displayed on the screen.');
    END IF;

    -- Find the open break
    SELECT id, start_time INTO v_break_id, v_start_time
    FROM break_register
    WHERE user_id = p_user_id AND status = 'open'
    ORDER BY start_time DESC
    LIMIT 1;

    IF v_break_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No open break found');
    END IF;

    -- Calculate duration
    v_duration := EXTRACT(EPOCH FROM (NOW() - v_start_time))::integer;

    -- Close the break
    UPDATE break_register
    SET end_time = NOW(),
        duration_seconds = v_duration,
        status = 'closed'
    WHERE id = v_break_id;

    RETURN jsonb_build_object('success', true, 'break_id', v_break_id, 'duration_seconds', v_duration);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_break_security_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_break_security_code() TO anon;
GRANT EXECUTE ON FUNCTION public.validate_break_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_break_code(text) TO anon;
GRANT EXECUTE ON FUNCTION public.end_break(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.end_break(uuid, text) TO anon;

-- RLS on seed table (no direct access — only via SECURITY DEFINER functions)
ALTER TABLE public.break_security_seed ENABLE ROW LEVEL SECURITY;
-- No RLS policies = no direct access from API, which is what we want
