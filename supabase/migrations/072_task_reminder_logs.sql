-- Task Reminder Logs Table Schema
CREATE TABLE IF NOT EXISTS task_reminder_logs (
  id INTEGER PRIMARY KEY DEFAULT nextval('task_reminder_logs_id_seq'),
  task_id INTEGER NOT NULL,
  assignment_id INTEGER NOT NULL,
  reminder_type VARCHAR NOT NULL,
  reminder_date TIMESTAMP WITH TIME ZONE NOT NULL,
  sent_to UUID NOT NULL,
  delivery_status VARCHAR NOT NULL DEFAULT 'pending',
  sent_at TIMESTAMP WITH TIME ZONE,
  acknowledged BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
