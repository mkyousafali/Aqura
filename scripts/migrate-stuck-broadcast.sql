-- Migrate stuck broadcast to queue system
-- This marks 19,003 pending recipients to be processed by queue worker

-- Step 1: Verify broadcast status
SELECT id, name, status, sent_count, failed_count, total_recipients
FROM wa_broadcasts
WHERE name = 'salaryoffermonththree'
LIMIT 1;

-- Step 2: Create queue job record
INSERT INTO broadcast_queue_jobs (
  broadcast_id,
  template_name,
  language,
  account_id,
  total_recipients,
  deadline_at,
  status,
  created_at
)
SELECT 
  wb.id,
  wt.name,
  wt.language,
  wb.wa_account_id,
  (SELECT COUNT(*) FROM wa_broadcast_recipients WHERE broadcast_id = wb.id AND status = 'pending'),
  NOW() + INTERVAL '23 hours 30 minutes', -- 11:30 PM today (safety buffer before 11:59 PM)
  'pending',
  NOW()
FROM wa_broadcasts wb
LEFT JOIN wa_templates wt ON wb.template_id = wt.id
WHERE wb.name = 'salaryoffermonththree'
  AND wb.status = 'sending'
RETURNING id, broadcast_id, total_recipients, deadline_at;

-- Step 3: Verify pending recipients count
SELECT COUNT(*) as pending_count
FROM wa_broadcast_recipients
WHERE broadcast_id = (SELECT id FROM wa_broadcasts WHERE name = 'salaryoffermonththree')
  AND status = 'pending';

-- Step 4: Update broadcast record to mark as "queued"
UPDATE wa_broadcasts
SET 
  status = 'queued',
  updated_at = NOW()
WHERE name = 'salaryoffermonththree'
  AND status = 'sending'
RETURNING name, status, updated_at;
