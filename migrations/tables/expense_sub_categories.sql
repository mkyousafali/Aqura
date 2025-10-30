-- Migration for table: expense_sub_categories
-- Generated on: 2025-10-30T21:55:45.305Z

CREATE TABLE IF NOT EXISTS public.expense_sub_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    parent_category_id NUMERIC NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_expense_sub_categories_created_at ON public.expense_sub_categories(created_at);
CREATE INDEX IF NOT EXISTS idx_expense_sub_categories_updated_at ON public.expense_sub_categories(updated_at);

-- Enable Row Level Security
ALTER TABLE public.expense_sub_categories ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_expense_sub_categories_updated_at
    BEFORE UPDATE ON public.expense_sub_categories
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.expense_sub_categories IS 'Generated from Aqura schema analysis';
