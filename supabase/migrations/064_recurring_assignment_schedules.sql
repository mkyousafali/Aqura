-- Recurring Assignment Schedules Table Schema
CREATE TABLE IF NOT EXISTS recurring_assignment_schedules (
  id INTEGER PRIMARY KEY DEFAULT nextval('recurring_assignment_schedules_id_seq'),
  assignment_name VARCHAR NOT NULL,
  description TEXT,
  assigned_to UUID NOT NULL,
  task_id UUID NOT NULL,
  frequency VARCHAR NOT NULL,
  schedule_pattern JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
