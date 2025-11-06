-- ================================================================
-- TABLE SCHEMA: hr_employee_contacts
-- Generated: 2025-11-06T11:09:39.010Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_employee_contacts (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    employee_id uuid NOT NULL,
    email character varying,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    whatsapp_number character varying,
    contact_number character varying
);

-- Table comment
COMMENT ON TABLE public.hr_employee_contacts IS 'Table for hr employee contacts management';

-- Column comments
COMMENT ON COLUMN public.hr_employee_contacts.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_employee_contacts.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.hr_employee_contacts.email IS 'Email address';
COMMENT ON COLUMN public.hr_employee_contacts.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.hr_employee_contacts.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.hr_employee_contacts.whatsapp_number IS 'Reference number';
COMMENT ON COLUMN public.hr_employee_contacts.contact_number IS 'Reference number';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_employee_contacts_pkey ON public.hr_employee_contacts USING btree (id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_hr_employee_contacts_employee_id ON public.hr_employee_contacts USING btree (employee_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_employee_contacts

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_employee_contacts ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_employee_contacts_select_policy" ON public.hr_employee_contacts
    FOR SELECT USING (true);

CREATE POLICY "hr_employee_contacts_insert_policy" ON public.hr_employee_contacts
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_employee_contacts_update_policy" ON public.hr_employee_contacts
    FOR UPDATE USING (true);

CREATE POLICY "hr_employee_contacts_delete_policy" ON public.hr_employee_contacts
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_employee_contacts

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_employee_contacts (employee_id, email, is_active)
VALUES ('uuid-example', 'example', true);
*/

-- Select example
/*
SELECT * FROM public.hr_employee_contacts 
WHERE employee_id = $1;
*/

-- Update example
/*
UPDATE public.hr_employee_contacts 
SET contact_number = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_EMPLOYEE_CONTACTS SCHEMA
-- ================================================================
