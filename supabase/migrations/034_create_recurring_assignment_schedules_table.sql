-- Create recurring_assignment_schedules table
CREATE TABLE IF NOT EXISTS public.recurring_assignment_schedules (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  assignment_id UUID NOT NULL,
  repeat_type TEXT NOT NULL,
  repeat_interval INTEGER NOT NULL DEFAULT 1,
  repeat_on_days TEXT[],
  repeat_on_date INTEGER,
  repeat_on_month INTEGER,
  execute_time TIME NOT NULL DEFAULT '09:00:00',
  timezone TEXT DEFAULT 'UTC',
  start_date DATE NOT NULL,
  end_date DATE,
  max_occurrences INTEGER,
  is_active BOOLEAN DEFAULT true,
  last_executed_at TIMESTAMPTZ,
  next_execution_at TIMESTAMPTZ NOT NULL,
  executions_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_by TEXT NOT NULL,
  PRIMARY KEY (id)
);

-- Indexes for recurring_assignment_schedules
CREATE INDEX IF NOT EXISTS idx_recurring_assignment_schedules_assignment_id ON public.recurring_assignment_schedules(assignment_id);
CREATE INDEX IF NOT EXISTS idx_recurring_assignment_schedules_created_at ON public.recurring_assignment_schedules(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.recurring_assignment_schedules ENABLE ROW LEVEL SECURITY;
