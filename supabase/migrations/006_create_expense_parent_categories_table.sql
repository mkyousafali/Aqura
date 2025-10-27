-- Create expense_parent_categories table
CREATE TABLE IF NOT EXISTS public.expense_parent_categories (
  id BIGSERIAL PRIMARY KEY,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for expense_parent_categories
CREATE INDEX IF NOT EXISTS idx_expense_parent_categories_created_at ON public.expense_parent_categories(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.expense_parent_categories ENABLE ROW LEVEL SECURITY;
