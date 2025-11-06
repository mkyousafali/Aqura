-- ================================================================
-- TABLE SCHEMA: non_approved_payment_scheduler
-- Generated: 2025-11-06T11:09:39.014Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.non_approved_payment_scheduler (
    id bigint NOT NULL DEFAULT nextval('non_approved_payment_scheduler_id_seq'::regclass),
    schedule_type text NOT NULL,
    branch_id bigint NOT NULL,
    branch_name text NOT NULL,
    expense_category_id bigint NOT NULL,
    expense_category_name_en text,
    expense_category_name_ar text,
    co_user_id uuid,
    co_user_name text,
    bill_type text,
    bill_number text,
    bill_date date,
    payment_method text,
    due_date date,
    credit_period integer,
    amount numeric NOT NULL,
    bill_file_url text,
    bank_name text,
    iban text,
    description text,
    notes text,
    recurring_type text,
    recurring_metadata jsonb,
    approver_id uuid NOT NULL,
    approver_name text NOT NULL,
    approval_status text DEFAULT 'pending'::text,
    approved_at timestamp with time zone,
    approved_by uuid,
    rejection_reason text,
    expense_scheduler_id bigint,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.non_approved_payment_scheduler IS 'Table for non approved payment scheduler management';

-- Column comments
COMMENT ON COLUMN public.non_approved_payment_scheduler.id IS 'Primary key identifier';
COMMENT ON COLUMN public.non_approved_payment_scheduler.schedule_type IS 'schedule type field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.non_approved_payment_scheduler.branch_name IS 'Name field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.expense_category_id IS 'Foreign key reference to expense_category table';
COMMENT ON COLUMN public.non_approved_payment_scheduler.expense_category_name_en IS 'Name field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.expense_category_name_ar IS 'Name field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.co_user_id IS 'Foreign key reference to co_user table';
COMMENT ON COLUMN public.non_approved_payment_scheduler.co_user_name IS 'Name field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.bill_type IS 'bill type field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.bill_number IS 'Reference number';
COMMENT ON COLUMN public.non_approved_payment_scheduler.bill_date IS 'Date field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.payment_method IS 'payment method field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.due_date IS 'Date field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.credit_period IS 'credit period field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.amount IS 'Monetary amount';
COMMENT ON COLUMN public.non_approved_payment_scheduler.bill_file_url IS 'URL or file path';
COMMENT ON COLUMN public.non_approved_payment_scheduler.bank_name IS 'Name field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.iban IS 'iban field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.description IS 'description field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.non_approved_payment_scheduler.recurring_type IS 'recurring type field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.recurring_metadata IS 'JSON data structure';
COMMENT ON COLUMN public.non_approved_payment_scheduler.approver_id IS 'Foreign key reference to approver table';
COMMENT ON COLUMN public.non_approved_payment_scheduler.approver_name IS 'Name field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.approval_status IS 'Status indicator';
COMMENT ON COLUMN public.non_approved_payment_scheduler.approved_at IS 'approved at field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.approved_by IS 'approved by field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.rejection_reason IS 'rejection reason field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.expense_scheduler_id IS 'Foreign key reference to expense_scheduler table';
COMMENT ON COLUMN public.non_approved_payment_scheduler.created_by IS 'created by field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.non_approved_payment_scheduler.updated_by IS 'Date field';
COMMENT ON COLUMN public.non_approved_payment_scheduler.updated_at IS 'Timestamp when record was last updated';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS non_approved_payment_scheduler_pkey ON public.non_approved_payment_scheduler USING btree (id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_branch_id ON public.non_approved_payment_scheduler USING btree (branch_id);

-- Foreign key index for expense_category_id
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_expense_category_id ON public.non_approved_payment_scheduler USING btree (expense_category_id);

-- Foreign key index for co_user_id
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_co_user_id ON public.non_approved_payment_scheduler USING btree (co_user_id);

-- Foreign key index for approver_id
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_approver_id ON public.non_approved_payment_scheduler USING btree (approver_id);

-- Foreign key index for expense_scheduler_id
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_expense_scheduler_id ON public.non_approved_payment_scheduler USING btree (expense_scheduler_id);

-- Date index for bill_date
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_bill_date ON public.non_approved_payment_scheduler USING btree (bill_date);

-- Date index for due_date
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_due_date ON public.non_approved_payment_scheduler USING btree (due_date);

-- Date index for approved_at
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_approved_at ON public.non_approved_payment_scheduler USING btree (approved_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for non_approved_payment_scheduler

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.non_approved_payment_scheduler ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "non_approved_payment_scheduler_select_policy" ON public.non_approved_payment_scheduler
    FOR SELECT USING (true);

CREATE POLICY "non_approved_payment_scheduler_insert_policy" ON public.non_approved_payment_scheduler
    FOR INSERT WITH CHECK (true);

CREATE POLICY "non_approved_payment_scheduler_update_policy" ON public.non_approved_payment_scheduler
    FOR UPDATE USING (true);

CREATE POLICY "non_approved_payment_scheduler_delete_policy" ON public.non_approved_payment_scheduler
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for non_approved_payment_scheduler

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.non_approved_payment_scheduler (schedule_type, branch_id, branch_name)
VALUES ('example text', 'example', 'example text');
*/

-- Select example
/*
SELECT * FROM public.non_approved_payment_scheduler 
WHERE branch_id = $1;
*/

-- Update example
/*
UPDATE public.non_approved_payment_scheduler 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF NON_APPROVED_PAYMENT_SCHEDULER SCHEMA
-- ================================================================
