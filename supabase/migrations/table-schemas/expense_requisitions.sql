-- ================================================================
-- TABLE SCHEMA: expense_requisitions
-- Generated: 2025-11-06T11:09:39.009Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.expense_requisitions (
    id bigint NOT NULL DEFAULT nextval('expense_requisitions_id_seq'::regclass),
    requisition_number text NOT NULL,
    branch_id bigint NOT NULL,
    branch_name text NOT NULL,
    approver_id uuid,
    approver_name text,
    expense_category_id bigint,
    expense_category_name_en text,
    expense_category_name_ar text,
    requester_id text NOT NULL,
    requester_name text NOT NULL,
    requester_contact text NOT NULL,
    vat_applicable boolean DEFAULT false,
    amount numeric NOT NULL,
    payment_category text NOT NULL,
    description text,
    status text DEFAULT 'pending'::text,
    image_url text,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    credit_period integer,
    bank_name text,
    iban text,
    used_amount numeric DEFAULT 0,
    remaining_balance numeric DEFAULT 0,
    requester_ref_id uuid,
    is_active boolean NOT NULL DEFAULT true,
    due_date date,
    internal_user_id uuid,
    request_type text DEFAULT 'external'::text
);

-- Table comment
COMMENT ON TABLE public.expense_requisitions IS 'Table for expense requisitions management';

-- Column comments
COMMENT ON COLUMN public.expense_requisitions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.expense_requisitions.requisition_number IS 'Reference number';
COMMENT ON COLUMN public.expense_requisitions.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.expense_requisitions.branch_name IS 'Name field';
COMMENT ON COLUMN public.expense_requisitions.approver_id IS 'Foreign key reference to approver table';
COMMENT ON COLUMN public.expense_requisitions.approver_name IS 'Name field';
COMMENT ON COLUMN public.expense_requisitions.expense_category_id IS 'Foreign key reference to expense_category table';
COMMENT ON COLUMN public.expense_requisitions.expense_category_name_en IS 'Name field';
COMMENT ON COLUMN public.expense_requisitions.expense_category_name_ar IS 'Name field';
COMMENT ON COLUMN public.expense_requisitions.requester_id IS 'Foreign key reference to requester table';
COMMENT ON COLUMN public.expense_requisitions.requester_name IS 'Name field';
COMMENT ON COLUMN public.expense_requisitions.requester_contact IS 'requester contact field';
COMMENT ON COLUMN public.expense_requisitions.vat_applicable IS 'Boolean flag';
COMMENT ON COLUMN public.expense_requisitions.amount IS 'Monetary amount';
COMMENT ON COLUMN public.expense_requisitions.payment_category IS 'payment category field';
COMMENT ON COLUMN public.expense_requisitions.description IS 'description field';
COMMENT ON COLUMN public.expense_requisitions.status IS 'Status indicator';
COMMENT ON COLUMN public.expense_requisitions.image_url IS 'URL or file path';
COMMENT ON COLUMN public.expense_requisitions.created_by IS 'created by field';
COMMENT ON COLUMN public.expense_requisitions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.expense_requisitions.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.expense_requisitions.credit_period IS 'credit period field';
COMMENT ON COLUMN public.expense_requisitions.bank_name IS 'Name field';
COMMENT ON COLUMN public.expense_requisitions.iban IS 'iban field';
COMMENT ON COLUMN public.expense_requisitions.used_amount IS 'Monetary amount';
COMMENT ON COLUMN public.expense_requisitions.remaining_balance IS 'remaining balance field';
COMMENT ON COLUMN public.expense_requisitions.requester_ref_id IS 'Foreign key reference to requester_ref table';
COMMENT ON COLUMN public.expense_requisitions.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.expense_requisitions.due_date IS 'Date field';
COMMENT ON COLUMN public.expense_requisitions.internal_user_id IS 'Foreign key reference to internal_user table';
COMMENT ON COLUMN public.expense_requisitions.request_type IS 'request type field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS expense_requisitions_pkey ON public.expense_requisitions USING btree (id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_branch_id ON public.expense_requisitions USING btree (branch_id);

-- Foreign key index for approver_id
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_approver_id ON public.expense_requisitions USING btree (approver_id);

-- Foreign key index for expense_category_id
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_expense_category_id ON public.expense_requisitions USING btree (expense_category_id);

-- Foreign key index for requester_id
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_requester_id ON public.expense_requisitions USING btree (requester_id);

-- Foreign key index for requester_ref_id
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_requester_ref_id ON public.expense_requisitions USING btree (requester_ref_id);

-- Foreign key index for internal_user_id
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_internal_user_id ON public.expense_requisitions USING btree (internal_user_id);

-- Date index for due_date
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_due_date ON public.expense_requisitions USING btree (due_date);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for expense_requisitions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.expense_requisitions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "expense_requisitions_select_policy" ON public.expense_requisitions
    FOR SELECT USING (true);

CREATE POLICY "expense_requisitions_insert_policy" ON public.expense_requisitions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "expense_requisitions_update_policy" ON public.expense_requisitions
    FOR UPDATE USING (true);

CREATE POLICY "expense_requisitions_delete_policy" ON public.expense_requisitions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for expense_requisitions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.expense_requisitions (requisition_number, branch_id, branch_name)
VALUES ('example text', 'example', 'example text');
*/

-- Select example
/*
SELECT * FROM public.expense_requisitions 
WHERE branch_id = $1;
*/

-- Update example
/*
UPDATE public.expense_requisitions 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF EXPENSE_REQUISITIONS SCHEMA
-- ================================================================
