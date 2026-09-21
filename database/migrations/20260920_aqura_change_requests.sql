BEGIN;

CREATE TABLE IF NOT EXISTS public.aqura_change_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    requested_by_user_id uuid NOT NULL REFERENCES public.users(id),
    branch_id bigint NOT NULL REFERENCES public.branches(id),
    requested_to_user_id uuid NOT NULL REFERENCES public.users(id),
    denomination_counts jsonb NOT NULL CHECK (jsonb_typeof(denomination_counts) = 'object'),
    total_amount numeric(14,2) NOT NULL CHECK (total_amount > 0),
    status text NOT NULL DEFAULT 'Pending' CHECK (status = 'Pending'),
    requested_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS aqura_change_requests_recipient_idx
    ON public.aqura_change_requests (requested_to_user_id, status, requested_at DESC);
CREATE INDEX IF NOT EXISTS aqura_change_requests_branch_idx
    ON public.aqura_change_requests (branch_id, requested_at DESC);

ALTER TABLE public.aqura_change_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.aqura_change_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.aqura_change_requests TO service_role;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'aqura_change_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.aqura_change_requests;
    END IF;
END $$;

COMMIT;
