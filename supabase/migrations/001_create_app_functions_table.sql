-- Create app_functions table
CREATE TABLE IF NOT EXISTS public.app_functions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  function_name VARCHAR(255) NOT NULL,
  function_code VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(255),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for app_functions
CREATE INDEX IF NOT EXISTS idx_app_functions_created_at ON public.app_functions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.app_functions ENABLE ROW LEVEL SECURITY;
