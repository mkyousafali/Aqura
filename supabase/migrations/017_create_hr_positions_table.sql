-- Create hr_positions table
CREATE TABLE IF NOT EXISTS public.hr_positions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  position_title_en VARCHAR(255) NOT NULL,
  position_title_ar VARCHAR(255) NOT NULL,
  department_id UUID NOT NULL,
  level_id UUID NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for hr_positions
CREATE INDEX IF NOT EXISTS idx_hr_positions_department_id ON public.hr_positions(department_id);
CREATE INDEX IF NOT EXISTS idx_hr_positions_level_id ON public.hr_positions(level_id);
CREATE INDEX IF NOT EXISTS idx_hr_positions_created_at ON public.hr_positions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_positions ENABLE ROW LEVEL SECURITY;
