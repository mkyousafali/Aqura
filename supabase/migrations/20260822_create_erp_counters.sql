-- ERP Counters cache: maps each branch's ERP CounterID -> CounterName.
-- Populated by the "Sync ERP Counters" button (Drawer Action Monitor > App Sync Status tab),
-- which pulls this from each branch's live SQL Server (via tunnel) and upserts it here.
-- The Drawer Flagger then reads counter names from this table instead of the tunnel,
-- so it keeps showing names even when a branch's tunnel connection is down.

CREATE TABLE IF NOT EXISTS public.erp_counters (
    id BIGSERIAL PRIMARY KEY,
    branch_id INTEGER NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    erp_branch_id INTEGER NOT NULL,
    counter_id INTEGER NOT NULL,
    counter_name TEXT,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (branch_id, counter_id)
);

CREATE INDEX IF NOT EXISTS idx_erp_counters_branch_id ON public.erp_counters USING btree (branch_id);

ALTER TABLE public.erp_counters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS allow_all_operations ON public.erp_counters;
CREATE POLICY allow_all_operations ON public.erp_counters USING (true) WITH CHECK (true);
