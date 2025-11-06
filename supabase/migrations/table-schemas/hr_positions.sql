-- ================================================================
-- TABLE SCHEMA: hr_positions
-- Generated: 2025-11-06T11:09:39.013Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_positions (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    position_title_en character varying NOT NULL,
    position_title_ar character varying NOT NULL,
    department_id uuid NOT NULL,
    level_id uuid NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.hr_positions IS 'Table for hr positions management';

-- Column comments
COMMENT ON COLUMN public.hr_positions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_positions.position_title_en IS 'position title en field';
COMMENT ON COLUMN public.hr_positions.position_title_ar IS 'position title ar field';
COMMENT ON COLUMN public.hr_positions.department_id IS 'Foreign key reference to department table';
COMMENT ON COLUMN public.hr_positions.level_id IS 'Foreign key reference to level table';
COMMENT ON COLUMN public.hr_positions.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.hr_positions.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_positions_pkey ON public.hr_positions USING btree (id);

-- Foreign key index for department_id
CREATE INDEX IF NOT EXISTS idx_hr_positions_department_id ON public.hr_positions USING btree (department_id);

-- Foreign key index for level_id
CREATE INDEX IF NOT EXISTS idx_hr_positions_level_id ON public.hr_positions USING btree (level_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_positions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_positions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_positions_select_policy" ON public.hr_positions
    FOR SELECT USING (true);

CREATE POLICY "hr_positions_insert_policy" ON public.hr_positions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_positions_update_policy" ON public.hr_positions
    FOR UPDATE USING (true);

CREATE POLICY "hr_positions_delete_policy" ON public.hr_positions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_positions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_positions (position_title_en, position_title_ar, department_id)
VALUES ('example', 'example', 'uuid-example');
*/

-- Select example
/*
SELECT * FROM public.hr_positions 
WHERE department_id = $1;
*/

-- Update example
/*
UPDATE public.hr_positions 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_POSITIONS SCHEMA
-- ================================================================
