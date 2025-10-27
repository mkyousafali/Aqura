-- Create branches table
CREATE TABLE IF NOT EXISTS public.branches (
  id BIGSERIAL PRIMARY KEY,
  name_en VARCHAR(255) NOT NULL,
  name_ar VARCHAR(255) NOT NULL,
  location_en VARCHAR(255) NOT NULL,
  location_ar VARCHAR(255) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  is_main_branch BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_by BIGINT,
  updated_by BIGINT,
  vat_number VARCHAR(255)
);

-- Indexes for branches
CREATE INDEX IF NOT EXISTS idx_branches_created_at ON public.branches(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
