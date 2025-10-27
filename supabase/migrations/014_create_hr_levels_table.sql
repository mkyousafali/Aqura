-- Create hr_levels table
CREATE TABLE IF NOT EXISTS public.hr_levels (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  level_name_en VARCHAR(255) NOT NULL,
  level_name_ar VARCHAR(255) NOT NULL,
  level_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for hr_levels
CREATE INDEX IF NOT EXISTS idx_hr_levels_created_at ON public.hr_levels(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_levels ENABLE ROW LEVEL SECURITY;
