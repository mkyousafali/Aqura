-- ================================================================
-- TABLE SCHEMA: role_permissions
-- Generated: 2025-11-06T11:09:39.022Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.role_permissions (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    role_id uuid NOT NULL,
    function_id uuid NOT NULL,
    can_view boolean DEFAULT false,
    can_add boolean DEFAULT false,
    can_edit boolean DEFAULT false,
    can_delete boolean DEFAULT false,
    can_export boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.role_permissions IS 'Table for role permissions management';

-- Column comments
COMMENT ON COLUMN public.role_permissions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.role_permissions.role_id IS 'Foreign key reference to role table';
COMMENT ON COLUMN public.role_permissions.function_id IS 'Foreign key reference to function table';
COMMENT ON COLUMN public.role_permissions.can_view IS 'Boolean flag';
COMMENT ON COLUMN public.role_permissions.can_add IS 'Boolean flag';
COMMENT ON COLUMN public.role_permissions.can_edit IS 'Boolean flag';
COMMENT ON COLUMN public.role_permissions.can_delete IS 'Boolean flag';
COMMENT ON COLUMN public.role_permissions.can_export IS 'Boolean flag';
COMMENT ON COLUMN public.role_permissions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.role_permissions.updated_at IS 'Timestamp when record was last updated';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS role_permissions_pkey ON public.role_permissions USING btree (id);

-- Foreign key index for role_id
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON public.role_permissions USING btree (role_id);

-- Foreign key index for function_id
CREATE INDEX IF NOT EXISTS idx_role_permissions_function_id ON public.role_permissions USING btree (function_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for role_permissions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "role_permissions_select_policy" ON public.role_permissions
    FOR SELECT USING (true);

CREATE POLICY "role_permissions_insert_policy" ON public.role_permissions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "role_permissions_update_policy" ON public.role_permissions
    FOR UPDATE USING (true);

CREATE POLICY "role_permissions_delete_policy" ON public.role_permissions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for role_permissions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.role_permissions (role_id, function_id, can_view)
VALUES ('uuid-example', 'uuid-example', true);
*/

-- Select example
/*
SELECT * FROM public.role_permissions 
WHERE role_id = $1;
*/

-- Update example
/*
UPDATE public.role_permissions 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF ROLE_PERMISSIONS SCHEMA
-- ================================================================
