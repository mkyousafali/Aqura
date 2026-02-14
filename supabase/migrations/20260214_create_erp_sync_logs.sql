-- Create erp_sync_logs table for tracking auto-sync history
-- Used by the auto-sync-erp Edge Function to log each run

CREATE TABLE IF NOT EXISTS public.erp_sync_logs (
  id              SERIAL PRIMARY KEY,
  sync_type       TEXT NOT NULL DEFAULT 'auto',          -- 'auto' (pg_cron) or 'manual'
  branches_total  INTEGER DEFAULT 0,
  branches_success INTEGER DEFAULT 0,
  branches_failed INTEGER DEFAULT 0,
  products_fetched INTEGER DEFAULT 0,
  products_inserted INTEGER DEFAULT 0,
  products_updated INTEGER DEFAULT 0,
  duration_ms     INTEGER DEFAULT 0,
  details         JSONB NULL,                             -- per-branch results array
  triggered_by    TEXT DEFAULT 'pg_cron',                 -- 'pg_cron' or 'manual-branch-5'
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for querying recent logs
CREATE INDEX IF NOT EXISTS idx_erp_sync_logs_created_at ON public.erp_sync_logs (created_at DESC);

-- Allow service role full access (Edge Function uses service role)
ALTER TABLE public.erp_sync_logs ENABLE ROW LEVEL SECURITY;

-- Policy: service role can do everything (Edge Function)
CREATE POLICY "Service role full access on erp_sync_logs"
  ON public.erp_sync_logs
  FOR ALL
  USING (true)
  WITH CHECK (true);
