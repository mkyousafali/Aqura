-- ================================================================
-- TABLE SCHEMA: hr_position_reporting_template
-- Generated: 2025-11-06T11:09:39.013Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_position_reporting_template (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    subordinate_position_id uuid NOT NULL,
    manager_position_1 uuid,
    manager_position_2 uuid,
    manager_position_3 uuid,
    manager_position_4 uuid,
    manager_position_5 uuid,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.hr_position_reporting_template IS 'Table for hr position reporting template management';

-- Column comments
COMMENT ON COLUMN public.hr_position_reporting_template.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_position_reporting_template.subordinate_position_id IS 'Foreign key reference to subordinate_position table';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_1 IS 'manager position 1 field';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_2 IS 'manager position 2 field';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_3 IS 'manager position 3 field';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_4 IS 'manager position 4 field';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_5 IS 'manager position 5 field';
COMMENT ON COLUMN public.hr_position_reporting_template.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.hr_position_reporting_template.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_position_reporting_template_pkey ON public.hr_position_reporting_template USING btree (id);

-- Foreign key index for subordinate_position_id
CREATE INDEX IF NOT EXISTS idx_hr_position_reporting_template_subordinate_position_id ON public.hr_position_reporting_template USING btree (subordinate_position_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_position_reporting_template

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_position_reporting_template ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_position_reporting_template_select_policy" ON public.hr_position_reporting_template
    FOR SELECT USING (true);

CREATE POLICY "hr_position_reporting_template_insert_policy" ON public.hr_position_reporting_template
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_position_reporting_template_update_policy" ON public.hr_position_reporting_template
    FOR UPDATE USING (true);

CREATE POLICY "hr_position_reporting_template_delete_policy" ON public.hr_position_reporting_template
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_position_reporting_template

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_position_reporting_template (subordinate_position_id, manager_position_1, manager_position_2)
VALUES ('uuid-example', 'uuid-example', 'uuid-example');
*/

-- Select example
/*
SELECT * FROM public.hr_position_reporting_template 
WHERE subordinate_position_id = $1;
*/

-- Update example
/*
UPDATE public.hr_position_reporting_template 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_POSITION_REPORTING_TEMPLATE SCHEMA
-- ================================================================
