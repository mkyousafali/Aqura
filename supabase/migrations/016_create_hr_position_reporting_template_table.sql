-- Create hr_position_reporting_template table
CREATE TABLE IF NOT EXISTS public.hr_position_reporting_template (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  subordinate_position_id UUID NOT NULL,
  manager_position_1 UUID,
  manager_position_2 UUID,
  manager_position_3 UUID,
  manager_position_4 UUID,
  manager_position_5 UUID,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for hr_position_reporting_template
CREATE INDEX IF NOT EXISTS idx_hr_position_reporting_template_subordinate_position_id ON public.hr_position_reporting_template(subordinate_position_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_reporting_template_created_at ON public.hr_position_reporting_template(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_position_reporting_template ENABLE ROW LEVEL SECURITY;
