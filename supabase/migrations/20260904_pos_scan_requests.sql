-- Tracks individual "Send Scan Request" requests from the Close Box Bank
-- Reconciliation card: a desktop cashier/supervisor asks a mobile user to
-- photograph a card-terminal reconciliation slip, Gemini extracts the
-- Date/Time/Terminal ID/Statement match number, the mobile user reviews and
-- fills in the payment amounts, then the completed row is picked up in real
-- time by CloseBox.svelte and turned into a normal bank_reconciliations entry.
-- Each request is its own row so multiple simultaneous requests (even for the
-- same box) never overwrite or mix with each other.

CREATE TABLE IF NOT EXISTS public.pos_scan_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    box_operation_id uuid NOT NULL REFERENCES public.box_operations(id) ON DELETE CASCADE,
    branch_id integer,
    box_number integer,
    pos_number integer,
    status text NOT NULL DEFAULT 'pending', -- pending | completed
    requested_by uuid,
    photo_url text,
    -- Gemini's raw read of the slip
    extracted_date date,
    extracted_time time,
    extracted_terminal_id text,
    extracted_statement_match_number text,
    -- What the mobile user actually saved (may differ from extracted_* if edited)
    final_date date,
    final_time time,
    final_terminal_id text,
    final_statement_match_number text,
    final_mada numeric(15,2),
    final_visa numeric(15,2),
    final_mastercard numeric(15,2),
    final_google_pay numeric(15,2),
    final_other numeric(15,2),
    completed_by uuid,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_scan_requests_box_operation ON public.pos_scan_requests(box_operation_id);
CREATE INDEX IF NOT EXISTS idx_pos_scan_requests_branch_status ON public.pos_scan_requests(branch_id, status);

ALTER TABLE public.pos_scan_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to pos_scan_requests" ON public.pos_scan_requests;
CREATE POLICY "Allow all access to pos_scan_requests" ON public.pos_scan_requests USING (true) WITH CHECK (true);

GRANT ALL ON public.pos_scan_requests TO authenticated, anon, service_role;

-- Realtime so CloseBox.svelte (desktop) and the mobile Scan Request page both
-- get instant updates without polling.
ALTER PUBLICATION supabase_realtime ADD TABLE public.pos_scan_requests;

-- Photo storage for the captured reconciliation slip
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('pos-scan-photos', 'pos-scan-photos', true, 20971520, '{image/jpeg,image/jpg,image/png,image/webp}')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE public.pos_scan_requests IS 'Desktop-to-mobile scan requests for Bank Reconciliation card terminal slips (Send Scan Request flow)';
