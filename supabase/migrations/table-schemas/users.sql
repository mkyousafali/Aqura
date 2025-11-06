-- ================================================================
-- TABLE SCHEMA: users
-- Generated: 2025-11-06T11:09:39.025Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.users (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    username character varying NOT NULL,
    password_hash character varying NOT NULL,
    salt character varying NOT NULL,
    quick_access_code character varying NOT NULL,
    quick_access_salt character varying NOT NULL,
    user_type USER-DEFINED NOT NULL DEFAULT 'branch_specific'::user_type_enum,
    employee_id uuid,
    branch_id bigint,
    role_type USER-DEFINED DEFAULT 'Position-based'::role_type_enum,
    position_id uuid,
    avatar text,
    avatar_small_url text,
    avatar_medium_url text,
    avatar_large_url text,
    is_first_login boolean DEFAULT true,
    failed_login_attempts integer DEFAULT 0,
    locked_at timestamp with time zone,
    locked_by uuid,
    last_login_at timestamp with time zone,
    password_expires_at timestamp with time zone,
    last_password_change timestamp with time zone DEFAULT now(),
    created_by bigint,
    updated_by bigint,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    status character varying NOT NULL DEFAULT 'active'::character varying,
    ai_translation_enabled boolean NOT NULL DEFAULT false
);

-- Table comment
COMMENT ON TABLE public.users IS 'Table for users management';

-- Column comments
COMMENT ON COLUMN public.users.id IS 'Primary key identifier';
COMMENT ON COLUMN public.users.username IS 'Name field';
COMMENT ON COLUMN public.users.password_hash IS 'password hash field';
COMMENT ON COLUMN public.users.salt IS 'salt field';
COMMENT ON COLUMN public.users.quick_access_code IS 'quick access code field';
COMMENT ON COLUMN public.users.quick_access_salt IS 'quick access salt field';
COMMENT ON COLUMN public.users.user_type IS 'user type field';
COMMENT ON COLUMN public.users.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.users.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.users.role_type IS 'role type field';
COMMENT ON COLUMN public.users.position_id IS 'Foreign key reference to position table';
COMMENT ON COLUMN public.users.avatar IS 'avatar field';
COMMENT ON COLUMN public.users.avatar_small_url IS 'URL or file path';
COMMENT ON COLUMN public.users.avatar_medium_url IS 'URL or file path';
COMMENT ON COLUMN public.users.avatar_large_url IS 'URL or file path';
COMMENT ON COLUMN public.users.is_first_login IS 'Boolean flag';
COMMENT ON COLUMN public.users.failed_login_attempts IS 'failed login attempts field';
COMMENT ON COLUMN public.users.locked_at IS 'locked at field';
COMMENT ON COLUMN public.users.locked_by IS 'locked by field';
COMMENT ON COLUMN public.users.last_login_at IS 'last login at field';
COMMENT ON COLUMN public.users.password_expires_at IS 'password expires at field';
COMMENT ON COLUMN public.users.last_password_change IS 'last password change field';
COMMENT ON COLUMN public.users.created_by IS 'created by field';
COMMENT ON COLUMN public.users.updated_by IS 'Date field';
COMMENT ON COLUMN public.users.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.users.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.users.status IS 'Status indicator';
COMMENT ON COLUMN public.users.ai_translation_enabled IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS users_pkey ON public.users USING btree (id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_users_employee_id ON public.users USING btree (employee_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_users_branch_id ON public.users USING btree (branch_id);

-- Foreign key index for position_id
CREATE INDEX IF NOT EXISTS idx_users_position_id ON public.users USING btree (position_id);

-- Date index for locked_at
CREATE INDEX IF NOT EXISTS idx_users_locked_at ON public.users USING btree (locked_at);

-- Date index for last_login_at
CREATE INDEX IF NOT EXISTS idx_users_last_login_at ON public.users USING btree (last_login_at);

-- Date index for password_expires_at
CREATE INDEX IF NOT EXISTS idx_users_password_expires_at ON public.users USING btree (password_expires_at);

-- Date index for last_password_change
CREATE INDEX IF NOT EXISTS idx_users_last_password_change ON public.users USING btree (last_password_change);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for users

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "users_select_policy" ON public.users
    FOR SELECT USING (true);

CREATE POLICY "users_insert_policy" ON public.users
    FOR INSERT WITH CHECK (true);

CREATE POLICY "users_update_policy" ON public.users
    FOR UPDATE USING (true);

CREATE POLICY "users_delete_policy" ON public.users
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for users

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.users (username, password_hash, salt)
VALUES ('example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.users 
WHERE employee_id = $1;
*/

-- Update example
/*
UPDATE public.users 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF USERS SCHEMA
-- ================================================================
