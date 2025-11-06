-- ================================================================
-- TABLE SCHEMA: receiving_task_templates
-- Generated: 2025-11-06T11:09:39.020Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.receiving_task_templates (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    role_type character varying NOT NULL,
    title_template text NOT NULL,
    description_template text NOT NULL,
    require_erp_reference boolean NOT NULL DEFAULT false,
    require_original_bill_upload boolean NOT NULL DEFAULT false,
    require_task_finished_mark boolean NOT NULL DEFAULT true,
    priority character varying NOT NULL DEFAULT 'high'::character varying,
    deadline_hours integer NOT NULL DEFAULT 24,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    depends_on_role_types ARRAY DEFAULT '{}'::text[],
    require_photo_upload boolean DEFAULT false
);

-- Table comment
COMMENT ON TABLE public.receiving_task_templates IS 'Table for receiving task templates management';

-- Column comments
COMMENT ON COLUMN public.receiving_task_templates.id IS 'Primary key identifier';
COMMENT ON COLUMN public.receiving_task_templates.role_type IS 'role type field';
COMMENT ON COLUMN public.receiving_task_templates.title_template IS 'title template field';
COMMENT ON COLUMN public.receiving_task_templates.description_template IS 'description template field';
COMMENT ON COLUMN public.receiving_task_templates.require_erp_reference IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_task_templates.require_original_bill_upload IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_task_templates.require_task_finished_mark IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_task_templates.priority IS 'priority field';
COMMENT ON COLUMN public.receiving_task_templates.deadline_hours IS 'deadline hours field';
COMMENT ON COLUMN public.receiving_task_templates.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.receiving_task_templates.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.receiving_task_templates.depends_on_role_types IS 'depends on role types field';
COMMENT ON COLUMN public.receiving_task_templates.require_photo_upload IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS receiving_task_templates_pkey ON public.receiving_task_templates USING btree (id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for receiving_task_templates

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.receiving_task_templates ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "receiving_task_templates_select_policy" ON public.receiving_task_templates
    FOR SELECT USING (true);

CREATE POLICY "receiving_task_templates_insert_policy" ON public.receiving_task_templates
    FOR INSERT WITH CHECK (true);

CREATE POLICY "receiving_task_templates_update_policy" ON public.receiving_task_templates
    FOR UPDATE USING (true);

CREATE POLICY "receiving_task_templates_delete_policy" ON public.receiving_task_templates
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for receiving_task_templates

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.receiving_task_templates (role_type, title_template, description_template)
VALUES ('example', 'example text', 'example text');
*/

-- Select example
/*
SELECT * FROM public.receiving_task_templates 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.receiving_task_templates 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF RECEIVING_TASK_TEMPLATES SCHEMA
-- ================================================================
