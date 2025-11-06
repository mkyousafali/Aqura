-- ================================================================
-- TABLE SCHEMA: app_functions
-- Generated: 2025-11-06T11:09:38.996Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.app_functions (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    function_name character varying NOT NULL,
    function_code character varying NOT NULL,
    description text,
    category character varying,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.app_functions IS 'Table for app functions management';

-- Column comments
COMMENT ON COLUMN public.app_functions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.app_functions.function_name IS 'Name field';
COMMENT ON COLUMN public.app_functions.function_code IS 'function code field';
COMMENT ON COLUMN public.app_functions.description IS 'description field';
COMMENT ON COLUMN public.app_functions.category IS 'category field';
COMMENT ON COLUMN public.app_functions.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.app_functions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.app_functions.updated_at IS 'Timestamp when record was last updated';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS app_functions_pkey ON public.app_functions USING btree (id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for app_functions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.app_functions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "app_functions_select_policy" ON public.app_functions
    FOR SELECT USING (true);

CREATE POLICY "app_functions_insert_policy" ON public.app_functions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "app_functions_update_policy" ON public.app_functions
    FOR UPDATE USING (true);

CREATE POLICY "app_functions_delete_policy" ON public.app_functions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for app_functions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.app_functions (function_name, function_code, description)
VALUES ('example', 'example', 'example text');
*/

-- Select example
/*
SELECT * FROM public.app_functions 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.app_functions 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF APP_FUNCTIONS SCHEMA
-- ================================================================
