-- ================================================================
-- TABLE SCHEMA: quick_task_user_preferences
-- Generated: 2025-11-06T11:09:39.019Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.quick_task_user_preferences (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    default_branch_id bigint,
    default_price_tag character varying,
    default_issue_type character varying,
    default_priority character varying,
    selected_user_ids ARRAY,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.quick_task_user_preferences IS 'Table for quick task user preferences management';

-- Column comments
COMMENT ON COLUMN public.quick_task_user_preferences.id IS 'Primary key identifier';
COMMENT ON COLUMN public.quick_task_user_preferences.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.quick_task_user_preferences.default_branch_id IS 'Foreign key reference to default_branch table';
COMMENT ON COLUMN public.quick_task_user_preferences.default_price_tag IS 'default price tag field';
COMMENT ON COLUMN public.quick_task_user_preferences.default_issue_type IS 'default issue type field';
COMMENT ON COLUMN public.quick_task_user_preferences.default_priority IS 'default priority field';
COMMENT ON COLUMN public.quick_task_user_preferences.selected_user_ids IS 'selected user ids field';
COMMENT ON COLUMN public.quick_task_user_preferences.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.quick_task_user_preferences.updated_at IS 'Timestamp when record was last updated';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS quick_task_user_preferences_pkey ON public.quick_task_user_preferences USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_user_id ON public.quick_task_user_preferences USING btree (user_id);

-- Foreign key index for default_branch_id
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_default_branch_id ON public.quick_task_user_preferences USING btree (default_branch_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for quick_task_user_preferences

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.quick_task_user_preferences ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "quick_task_user_preferences_select_policy" ON public.quick_task_user_preferences
    FOR SELECT USING (true);

CREATE POLICY "quick_task_user_preferences_insert_policy" ON public.quick_task_user_preferences
    FOR INSERT WITH CHECK (true);

CREATE POLICY "quick_task_user_preferences_update_policy" ON public.quick_task_user_preferences
    FOR UPDATE USING (true);

CREATE POLICY "quick_task_user_preferences_delete_policy" ON public.quick_task_user_preferences
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for quick_task_user_preferences

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.quick_task_user_preferences (user_id, default_branch_id, default_price_tag)
VALUES ('uuid-example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.quick_task_user_preferences 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.quick_task_user_preferences 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF QUICK_TASK_USER_PREFERENCES SCHEMA
-- ================================================================
