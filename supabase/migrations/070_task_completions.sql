-- Task Completions Table Schema
CREATE TABLE IF NOT EXISTS task_completions (
  id INTEGER PRIMARY KEY DEFAULT nextval('task_completions_id_seq'),
  task_id INTEGER NOT NULL,
  assignment_id INTEGER NOT NULL,
  completed_by UUID NOT NULL,
  completion_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
  completion_notes TEXT,
  quality_rating INTEGER,
  time_spent INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
