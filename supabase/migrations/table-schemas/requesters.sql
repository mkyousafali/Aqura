-- ================================================================
-- TABLE SCHEMA: requesters
-- Generated: 2025-11-06T11:09:39.021Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.requesters (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    requester_id character varying NOT NULL,
    requester_name character varying NOT NULL,
    contact_number character varying,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by uuid,
    updated_by uuid
);

-- Table comment
COMMENT ON TABLE public.requesters IS 'Table for requesters management';

-- Column comments
COMMENT ON COLUMN public.requesters.id IS 'Primary key identifier';
COMMENT ON COLUMN public.requesters.requester_id IS 'Foreign key reference to requester table';
COMMENT ON COLUMN public.requesters.requester_name IS 'Name field';
COMMENT ON COLUMN public.requesters.contact_number IS 'Reference number';
COMMENT ON COLUMN public.requesters.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.requesters.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.requesters.created_by IS 'created by field';
COMMENT ON COLUMN public.requesters.updated_by IS 'Date field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS requesters_pkey ON public.requesters USING btree (id);

-- Foreign key index for requester_id
CREATE INDEX IF NOT EXISTS idx_requesters_requester_id ON public.requesters USING btree (requester_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for requesters

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.requesters ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "requesters_select_policy" ON public.requesters
    FOR SELECT USING (true);

CREATE POLICY "requesters_insert_policy" ON public.requesters
    FOR INSERT WITH CHECK (true);

CREATE POLICY "requesters_update_policy" ON public.requesters
    FOR UPDATE USING (true);

CREATE POLICY "requesters_delete_policy" ON public.requesters
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for requesters

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.requesters (requester_id, requester_name, contact_number)
VALUES ('example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.requesters 
WHERE requester_id = $1;
*/

-- Update example
/*
UPDATE public.requesters 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF REQUESTERS SCHEMA
-- ================================================================
