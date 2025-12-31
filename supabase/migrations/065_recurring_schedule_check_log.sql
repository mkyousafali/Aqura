-- Recurring Schedule Check Log Table Schema
CREATE TABLE IF NOT EXISTS recurring_schedule_check_log (
  id INTEGER PRIMARY KEY DEFAULT nextval('recurring_schedule_check_log_id_seq'),
  schedule_id INTEGER NOT NULL,
  check_date TIMESTAMP WITH TIME ZONE NOT NULL,
  next_execution_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR NOT NULL DEFAULT 'pending',
  log_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
