-- ================================================================
-- TABLE SCHEMA: hr_levels
-- Generated: 2025-11-06T11:09:39.012Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_levels (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    level_name_en character varying NOT NULL,
    level_name_ar character varying NOT NULL,
    level_order integer NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.hr_levels IS 'Table for hr levels management';

-- Column comments
COMMENT ON COLUMN public.hr_levels.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_levels.level_name_en IS 'Name field';
COMMENT ON COLUMN public.hr_levels.level_name_ar IS 'Name field';
COMMENT ON COLUMN public.hr_levels.level_order IS 'level order field';
COMMENT ON COLUMN public.hr_levels.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.hr_levels.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_levels_pkey ON public.hr_levels USING btree (id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_levels

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_levels ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_levels_select_policy" ON public.hr_levels
    FOR SELECT USING (true);

CREATE POLICY "hr_levels_insert_policy" ON public.hr_levels
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_levels_update_policy" ON public.hr_levels
    FOR UPDATE USING (true);

CREATE POLICY "hr_levels_delete_policy" ON public.hr_levels
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_levels

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_levels (level_name_en, level_name_ar, level_order)
VALUES ('example', 'example', 123);
*/

-- Select example
/*
SELECT * FROM public.hr_levels 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.hr_levels 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_LEVELS SCHEMA
-- ================================================================
