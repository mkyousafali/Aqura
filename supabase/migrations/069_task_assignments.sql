-- Task Assignments Table Schema
CREATE TABLE IF NOT EXISTS task_assignments (
  id INTEGER PRIMARY KEY DEFAULT nextval('task_assignments_id_seq'),
  task_id INTEGER NOT NULL,
  assigned_to UUID NOT NULL,
  assigned_by UUID,
  assignment_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
  due_date TIMESTAMP WITH TIME ZONE,
  priority VARCHAR NOT NULL DEFAULT 'medium',
  status VARCHAR NOT NULL DEFAULT 'assigned',
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
