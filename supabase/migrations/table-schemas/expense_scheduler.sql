-- ================================================================
-- TABLE SCHEMA: expense_scheduler
-- Generated: 2025-11-06T11:09:39.009Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.expense_scheduler (
    id bigint NOT NULL DEFAULT nextval('expense_scheduler_id_seq'::regclass),
    branch_id bigint NOT NULL,
    branch_name text NOT NULL,
    expense_category_id bigint,
    expense_category_name_en text,
    expense_category_name_ar text,
    requisition_id bigint,
    requisition_number text,
    co_user_id uuid,
    co_user_name text,
    bill_type text NOT NULL,
    bill_number text,
    bill_date date,
    payment_method text,
    due_date date,
    credit_period integer,
    amount numeric NOT NULL,
    bill_file_url text,
    description text,
    notes text,
    is_paid boolean DEFAULT false,
    paid_date timestamp with time zone,
    status text DEFAULT 'pending'::text,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now(),
    bank_name text,
    iban text,
    payment_reference character varying,
    schedule_type text DEFAULT 'single_bill'::text,
    recurring_type text,
    recurring_metadata jsonb,
    approver_id uuid,
    approver_name text
);

-- Table comment
COMMENT ON TABLE public.expense_scheduler IS 'Table for expense scheduler management';

-- Column comments
COMMENT ON COLUMN public.expense_scheduler.id IS 'Primary key identifier';
COMMENT ON COLUMN public.expense_scheduler.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.expense_scheduler.branch_name IS 'Name field';
COMMENT ON COLUMN public.expense_scheduler.expense_category_id IS 'Foreign key reference to expense_category table';
COMMENT ON COLUMN public.expense_scheduler.expense_category_name_en IS 'Name field';
COMMENT ON COLUMN public.expense_scheduler.expense_category_name_ar IS 'Name field';
COMMENT ON COLUMN public.expense_scheduler.requisition_id IS 'Foreign key reference to requisition table';
COMMENT ON COLUMN public.expense_scheduler.requisition_number IS 'Reference number';
COMMENT ON COLUMN public.expense_scheduler.co_user_id IS 'Foreign key reference to co_user table';
COMMENT ON COLUMN public.expense_scheduler.co_user_name IS 'Name field';
COMMENT ON COLUMN public.expense_scheduler.bill_type IS 'bill type field';
COMMENT ON COLUMN public.expense_scheduler.bill_number IS 'Reference number';
COMMENT ON COLUMN public.expense_scheduler.bill_date IS 'Date field';
COMMENT ON COLUMN public.expense_scheduler.payment_method IS 'payment method field';
COMMENT ON COLUMN public.expense_scheduler.due_date IS 'Date field';
COMMENT ON COLUMN public.expense_scheduler.credit_period IS 'credit period field';
COMMENT ON COLUMN public.expense_scheduler.amount IS 'Monetary amount';
COMMENT ON COLUMN public.expense_scheduler.bill_file_url IS 'URL or file path';
COMMENT ON COLUMN public.expense_scheduler.description IS 'description field';
COMMENT ON COLUMN public.expense_scheduler.notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.expense_scheduler.is_paid IS 'Boolean flag';
COMMENT ON COLUMN public.expense_scheduler.paid_date IS 'Date field';
COMMENT ON COLUMN public.expense_scheduler.status IS 'Status indicator';
COMMENT ON COLUMN public.expense_scheduler.created_by IS 'created by field';
COMMENT ON COLUMN public.expense_scheduler.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.expense_scheduler.updated_by IS 'Date field';
COMMENT ON COLUMN public.expense_scheduler.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.expense_scheduler.bank_name IS 'Name field';
COMMENT ON COLUMN public.expense_scheduler.iban IS 'iban field';
COMMENT ON COLUMN public.expense_scheduler.payment_reference IS 'payment reference field';
COMMENT ON COLUMN public.expense_scheduler.schedule_type IS 'schedule type field';
COMMENT ON COLUMN public.expense_scheduler.recurring_type IS 'recurring type field';
COMMENT ON COLUMN public.expense_scheduler.recurring_metadata IS 'JSON data structure';
COMMENT ON COLUMN public.expense_scheduler.approver_id IS 'Foreign key reference to approver table';
COMMENT ON COLUMN public.expense_scheduler.approver_name IS 'Name field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS expense_scheduler_pkey ON public.expense_scheduler USING btree (id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_branch_id ON public.expense_scheduler USING btree (branch_id);

-- Foreign key index for expense_category_id
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_expense_category_id ON public.expense_scheduler USING btree (expense_category_id);

-- Foreign key index for requisition_id
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_requisition_id ON public.expense_scheduler USING btree (requisition_id);

-- Foreign key index for co_user_id
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_co_user_id ON public.expense_scheduler USING btree (co_user_id);

-- Foreign key index for approver_id
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_approver_id ON public.expense_scheduler USING btree (approver_id);

-- Date index for bill_date
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_bill_date ON public.expense_scheduler USING btree (bill_date);

-- Date index for due_date
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_due_date ON public.expense_scheduler USING btree (due_date);

-- Date index for paid_date
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_paid_date ON public.expense_scheduler USING btree (paid_date);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for expense_scheduler

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.expense_scheduler ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "expense_scheduler_select_policy" ON public.expense_scheduler
    FOR SELECT USING (true);

CREATE POLICY "expense_scheduler_insert_policy" ON public.expense_scheduler
    FOR INSERT WITH CHECK (true);

CREATE POLICY "expense_scheduler_update_policy" ON public.expense_scheduler
    FOR UPDATE USING (true);

CREATE POLICY "expense_scheduler_delete_policy" ON public.expense_scheduler
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for expense_scheduler

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.expense_scheduler (branch_id, branch_name, expense_category_id)
VALUES ('example', 'example text', 'example');
*/

-- Select example
/*
SELECT * FROM public.expense_scheduler 
WHERE branch_id = $1;
*/

-- Update example
/*
UPDATE public.expense_scheduler 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF EXPENSE_SCHEDULER SCHEMA
-- ================================================================
