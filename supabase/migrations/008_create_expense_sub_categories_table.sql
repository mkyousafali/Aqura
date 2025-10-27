-- Create expense_sub_categories table
CREATE TABLE IF NOT EXISTS public.expense_sub_categories (
  id BIGSERIAL PRIMARY KEY,
  parent_category_id BIGINT NOT NULL,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for expense_sub_categories
CREATE INDEX IF NOT EXISTS idx_expense_sub_categories_parent_category_id ON public.expense_sub_categories(parent_category_id);
CREATE INDEX IF NOT EXISTS idx_expense_sub_categories_created_at ON public.expense_sub_categories(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.expense_sub_categories ENABLE ROW LEVEL SECURITY;
