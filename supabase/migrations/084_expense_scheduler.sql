-- Expense Scheduler Table Schema
CREATE TABLE IF NOT EXISTS expense_scheduler (
  id INTEGER PRIMARY KEY DEFAULT nextval('expense_scheduler_id_seq'),
  requisition_id INTEGER NOT NULL,
  scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
  status VARCHAR NOT NULL DEFAULT 'pending',
  email_sent BOOLEAN NOT NULL DEFAULT false,
  notification_sent BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
