-- ================================================================
-- TABLE SCHEMA: expense_sub_categories
-- Generated: 2025-11-06T11:09:39.010Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.expense_sub_categories (
    id bigint NOT NULL DEFAULT nextval('expense_sub_categories_id_seq'::regclass),
    parent_category_id bigint NOT NULL,
    name_en text NOT NULL,
    name_ar text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_active boolean DEFAULT true
);

-- Table comment
COMMENT ON TABLE public.expense_sub_categories IS 'Table for expense sub categories management';

-- Column comments
COMMENT ON COLUMN public.expense_sub_categories.id IS 'Primary key identifier';
COMMENT ON COLUMN public.expense_sub_categories.parent_category_id IS 'Foreign key reference to parent_category table';
COMMENT ON COLUMN public.expense_sub_categories.name_en IS 'Name field';
COMMENT ON COLUMN public.expense_sub_categories.name_ar IS 'Name field';
COMMENT ON COLUMN public.expense_sub_categories.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.expense_sub_categories.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.expense_sub_categories.is_active IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS expense_sub_categories_pkey ON public.expense_sub_categories USING btree (id);

-- Foreign key index for parent_category_id
CREATE INDEX IF NOT EXISTS idx_expense_sub_categories_parent_category_id ON public.expense_sub_categories USING btree (parent_category_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for expense_sub_categories

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.expense_sub_categories ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "expense_sub_categories_select_policy" ON public.expense_sub_categories
    FOR SELECT USING (true);

CREATE POLICY "expense_sub_categories_insert_policy" ON public.expense_sub_categories
    FOR INSERT WITH CHECK (true);

CREATE POLICY "expense_sub_categories_update_policy" ON public.expense_sub_categories
    FOR UPDATE USING (true);

CREATE POLICY "expense_sub_categories_delete_policy" ON public.expense_sub_categories
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for expense_sub_categories

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.expense_sub_categories (parent_category_id, name_en, name_ar)
VALUES ('example', 'example text', 'example text');
*/

-- Select example
/*
SELECT * FROM public.expense_sub_categories 
WHERE parent_category_id = $1;
*/

-- Update example
/*
UPDATE public.expense_sub_categories 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF EXPENSE_SUB_CATEGORIES SCHEMA
-- ================================================================
