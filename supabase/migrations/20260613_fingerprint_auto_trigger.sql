-- ============================================================
-- Trigger: auto-call process-fingerprints when a new row
-- is inserted into hr_fingerprint_transactions.
--
-- Uses pg_net for async HTTP (non-blocking, fire-and-forget).
-- Debounced via a control table: only fires if the last call
-- was more than 30 seconds ago, avoiding floods on bulk inserts.
-- ============================================================

-- 1. Debounce control table
CREATE TABLE IF NOT EXISTS public.edge_function_trigger_log (
    function_name TEXT PRIMARY KEY,
    last_called_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Trigger function
CREATE OR REPLACE FUNCTION public.trigger_process_fingerprints()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_last_called TIMESTAMPTZ;
    v_supabase_url TEXT;
    v_service_key  TEXT;
    v_request_id   BIGINT;
BEGIN
    -- Read env-like values stored as Supabase secrets via vault or app.settings
    -- These must be set via: ALTER DATABASE postgres SET app.supabase_url = '...';
    --                        ALTER DATABASE postgres SET app.service_role_key = '...';
    BEGIN
        v_supabase_url := current_setting('app.supabase_url', true);
        v_service_key  := current_setting('app.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        -- Settings not configured — skip silently
        RETURN NEW;
    END;

    IF v_supabase_url IS NULL OR v_supabase_url = '' THEN
        RETURN NEW;
    END IF;

    -- Debounce: skip if called within the last 30 seconds
    SELECT last_called_at INTO v_last_called
    FROM public.edge_function_trigger_log
    WHERE function_name = 'process-fingerprints';

    IF v_last_called IS NOT NULL AND
       (NOW() - v_last_called) < INTERVAL '30 seconds' THEN
        -- Too soon — skip this call, the recent one covers it
        RETURN NEW;
    END IF;

    -- Update (or insert) the debounce timestamp
    INSERT INTO public.edge_function_trigger_log (function_name, last_called_at)
    VALUES ('process-fingerprints', NOW())
    ON CONFLICT (function_name)
    DO UPDATE SET last_called_at = NOW();

    -- Fire async HTTP call to the process-fingerprints edge function
    SELECT net.http_post(
        url     := v_supabase_url || '/functions/v1/process-fingerprints',
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || v_service_key
        ),
        body    := '{"rollingDays":3}'::jsonb
    ) INTO v_request_id;

    RETURN NEW;
END;
$$;

-- 3. Attach trigger to hr_fingerprint_transactions
DROP TRIGGER IF EXISTS trg_auto_process_fingerprints ON public.hr_fingerprint_transactions;

CREATE TRIGGER trg_auto_process_fingerprints
AFTER INSERT ON public.hr_fingerprint_transactions
FOR EACH STATEMENT          -- fires once per INSERT statement, not per row
EXECUTE FUNCTION public.trigger_process_fingerprints();

-- 4. Grant pg_net usage to postgres role (needed to call net.http_post)
GRANT USAGE ON SCHEMA net TO postgres;
