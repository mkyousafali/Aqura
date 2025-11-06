-- ================================================================
-- TABLE SCHEMA: branches
-- Generated: 2025-11-06T11:09:38.999Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.branches (
    id bigint NOT NULL DEFAULT nextval('branches_id_seq'::regclass),
    name_en character varying NOT NULL,
    name_ar character varying NOT NULL,
    location_en character varying NOT NULL,
    location_ar character varying NOT NULL,
    is_active boolean DEFAULT true,
    is_main_branch boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by bigint,
    updated_by bigint,
    vat_number character varying
);

-- Table comment
COMMENT ON TABLE public.branches IS 'Table for branches management';

-- Column comments
COMMENT ON COLUMN public.branches.id IS 'Primary key identifier';
COMMENT ON COLUMN public.branches.name_en IS 'Name field';
COMMENT ON COLUMN public.branches.name_ar IS 'Name field';
COMMENT ON COLUMN public.branches.location_en IS 'location en field';
COMMENT ON COLUMN public.branches.location_ar IS 'location ar field';
COMMENT ON COLUMN public.branches.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.branches.is_main_branch IS 'Boolean flag';
COMMENT ON COLUMN public.branches.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.branches.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.branches.created_by IS 'created by field';
COMMENT ON COLUMN public.branches.updated_by IS 'Date field';
COMMENT ON COLUMN public.branches.vat_number IS 'Reference number';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS branches_pkey ON public.branches USING btree (id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for branches

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "branches_select_policy" ON public.branches
    FOR SELECT USING (true);

CREATE POLICY "branches_insert_policy" ON public.branches
    FOR INSERT WITH CHECK (true);

CREATE POLICY "branches_update_policy" ON public.branches
    FOR UPDATE USING (true);

CREATE POLICY "branches_delete_policy" ON public.branches
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for branches

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.branches (name_en, name_ar, location_en)
VALUES ('example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.branches 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.branches 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF BRANCHES SCHEMA
-- ================================================================
