-- ================================================================
-- TABLE SCHEMA: user_roles
-- Generated: 2025-11-06T11:09:39.025Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_roles (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    role_name character varying NOT NULL,
    role_code character varying NOT NULL,
    description text,
    is_system_role boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Table comment
COMMENT ON TABLE public.user_roles IS 'Table for user roles management';

-- Column comments
COMMENT ON COLUMN public.user_roles.id IS 'Primary key identifier';
COMMENT ON COLUMN public.user_roles.role_name IS 'Name field';
COMMENT ON COLUMN public.user_roles.role_code IS 'role code field';
COMMENT ON COLUMN public.user_roles.description IS 'description field';
COMMENT ON COLUMN public.user_roles.is_system_role IS 'Boolean flag';
COMMENT ON COLUMN public.user_roles.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.user_roles.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.user_roles.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.user_roles.created_by IS 'created by field';
COMMENT ON COLUMN public.user_roles.updated_by IS 'Date field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS user_roles_pkey ON public.user_roles USING btree (id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for user_roles

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "user_roles_select_policy" ON public.user_roles
    FOR SELECT USING (true);

CREATE POLICY "user_roles_insert_policy" ON public.user_roles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "user_roles_update_policy" ON public.user_roles
    FOR UPDATE USING (true);

CREATE POLICY "user_roles_delete_policy" ON public.user_roles
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for user_roles

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.user_roles (role_name, role_code, description)
VALUES ('example', 'example', 'example text');
*/

-- Select example
/*
SELECT * FROM public.user_roles 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.user_roles 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF USER_ROLES SCHEMA
-- ================================================================
