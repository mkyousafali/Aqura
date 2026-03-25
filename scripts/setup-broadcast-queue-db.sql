-- Create broadcast queue system (lightweight - uses existing DB)
-- Run this ONCE to set up infrastructure

CREATE TABLE IF NOT EXISTS broadcast_queue_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id UUID NOT NULL,
  template_name TEXT NOT NULL,
  language TEXT NOT NULL,
  account_id UUID NOT NULL,
  total_recipients INT NOT NULL,
  processed_count INT DEFAULT 0,
  failed_count INT DEFAULT 0,
  deadline_at TIMESTAMP NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed
  worker_id TEXT,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT fk_broadcast FOREIGN KEY (broadcast_id) REFERENCES wa_broadcasts(id),
  CONSTRAINT fk_account FOREIGN KEY (account_id) REFERENCES wa_accounts(id)
);

-- Index for queue polling
CREATE INDEX IF NOT EXISTS idx_broadcast_queue_status_deadline 
  ON broadcast_queue_jobs(status, deadline_at) 
  WHERE status IN ('pending', 'processing');

-- Track queue worker lock (prevents duplicate processing)
CREATE TABLE IF NOT EXISTS broadcast_queue_worker_lock (
  job_id UUID PRIMARY KEY,
  worker_id TEXT NOT NULL,
  locked_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '5 minutes',
  
  CONSTRAINT fk_job FOREIGN KEY (job_id) REFERENCES broadcast_queue_jobs(id)
);

-- Cleanup old locks
CREATE INDEX IF NOT EXISTS idx_worker_lock_expiry 
  ON broadcast_queue_worker_lock(expires_at) 
  WHERE expires_at <= NOW();

-- Audit log for debugging
CREATE TABLE IF NOT EXISTS broadcast_queue_audit (
  id BIGSERIAL PRIMARY KEY,
  job_id UUID NOT NULL,
  event_type TEXT NOT NULL, -- started, batch_sent, batch_failed, completed, error
  message TEXT,
  recipients_count INT,
  created_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT fk_job FOREIGN KEY (job_id) REFERENCES broadcast_queue_jobs(id)
);

-- RLS policies (allow service role only)
ALTER TABLE broadcast_queue_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE broadcast_queue_worker_lock ENABLE ROW LEVEL SECURITY;
ALTER TABLE broadcast_queue_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY broadcast_queue_service_only ON broadcast_queue_jobs
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY worker_lock_service_only ON broadcast_queue_worker_lock
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY audit_service_only ON broadcast_queue_audit
  FOR ALL USING (auth.role() = 'service_role');

-- Notify on job completion (for real-time UI updates)
CREATE OR REPLACE FUNCTION notify_broadcast_queue_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' THEN
    PERFORM pg_notify('broadcast_queue_completed', json_build_object(
      'job_id', NEW.id,
      'broadcast_id', NEW.broadcast_id,
      'processed_count', NEW.processed_count,
      'failed_count', NEW.failed_count
    )::text);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER broadcast_queue_completion_trigger
AFTER UPDATE ON broadcast_queue_jobs
FOR EACH ROW
EXECUTE FUNCTION notify_broadcast_queue_completed();
