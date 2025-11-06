-- ================================================================
-- TABLE SCHEMA: expense_parent_categories
-- Generated: 2025-11-06T11:09:39.008Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.expense_parent_categories (
    id bigint NOT NULL DEFAULT nextval('expense_parent_categories_id_seq'::regclass),
    name_en text NOT NULL,
    name_ar text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_active boolean DEFAULT true
);

-- Table comment
COMMENT ON TABLE public.expense_parent_categories IS 'Table for expense parent categories management';

-- Column comments
COMMENT ON COLUMN public.expense_parent_categories.id IS 'Primary key identifier';
COMMENT ON COLUMN public.expense_parent_categories.name_en IS 'Name field';
COMMENT ON COLUMN public.expense_parent_categories.name_ar IS 'Name field';
COMMENT ON COLUMN public.expense_parent_categories.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.expense_parent_categories.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.expense_parent_categories.is_active IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS expense_parent_categories_pkey ON public.expense_parent_categories USING btree (id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for expense_parent_categories

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.expense_parent_categories ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "expense_parent_categories_select_policy" ON public.expense_parent_categories
    FOR SELECT USING (true);

CREATE POLICY "expense_parent_categories_insert_policy" ON public.expense_parent_categories
    FOR INSERT WITH CHECK (true);

CREATE POLICY "expense_parent_categories_update_policy" ON public.expense_parent_categories
    FOR UPDATE USING (true);

CREATE POLICY "expense_parent_categories_delete_policy" ON public.expense_parent_categories
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for expense_parent_categories

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.expense_parent_categories (name_en, name_ar, created_at)
VALUES ('example text', 'example text', '2025-11-06');
*/

-- Select example
/*
SELECT * FROM public.expense_parent_categories 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.expense_parent_categories 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF EXPENSE_PARENT_CATEGORIES SCHEMA
-- ================================================================
