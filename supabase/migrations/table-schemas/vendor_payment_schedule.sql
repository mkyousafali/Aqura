-- ================================================================
-- TABLE SCHEMA: vendor_payment_schedule
-- Generated: 2025-11-06T11:09:39.026Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.vendor_payment_schedule (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    receiving_record_id uuid,
    bill_number character varying,
    vendor_id character varying,
    vendor_name character varying,
    branch_id integer,
    branch_name character varying,
    bill_date date,
    bill_amount numeric,
    final_bill_amount numeric,
    payment_method character varying,
    bank_name character varying,
    iban character varying,
    due_date date,
    credit_period integer,
    vat_number character varying,
    scheduled_date timestamp without time zone DEFAULT now(),
    paid_date timestamp without time zone,
    notes text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    original_due_date date,
    original_bill_amount numeric,
    original_final_amount numeric,
    is_paid boolean DEFAULT false,
    payment_reference character varying,
    task_id uuid,
    task_assignment_id uuid,
    receiver_user_id uuid,
    accountant_user_id uuid,
    verification_status text DEFAULT 'pending'::text,
    verified_by uuid,
    verified_date timestamp with time zone,
    transaction_date timestamp with time zone,
    original_bill_url text,
    created_by uuid,
    pr_excel_verified boolean DEFAULT false,
    pr_excel_verified_by uuid,
    pr_excel_verified_date timestamp with time zone,
    discount_amount numeric DEFAULT 0,
    discount_notes text,
    grr_amount numeric DEFAULT 0,
    grr_reference_number text,
    grr_notes text,
    pri_amount numeric DEFAULT 0,
    pri_reference_number text,
    pri_notes text,
    last_adjustment_date timestamp with time zone,
    last_adjusted_by uuid,
    adjustment_history jsonb DEFAULT '[]'::jsonb,
    approval_status text NOT NULL DEFAULT 'pending'::text,
    approval_requested_by uuid,
    approval_requested_at timestamp with time zone,
    approved_by uuid,
    approved_at timestamp with time zone,
    approval_notes text
);

-- Table comment
COMMENT ON TABLE public.vendor_payment_schedule IS 'Table for vendor payment schedule management';

-- Column comments
COMMENT ON COLUMN public.vendor_payment_schedule.id IS 'Primary key identifier';
COMMENT ON COLUMN public.vendor_payment_schedule.receiving_record_id IS 'Foreign key reference to receiving_record table';
COMMENT ON COLUMN public.vendor_payment_schedule.bill_number IS 'Reference number';
COMMENT ON COLUMN public.vendor_payment_schedule.vendor_id IS 'Foreign key reference to vendor table';
COMMENT ON COLUMN public.vendor_payment_schedule.vendor_name IS 'Name field';
COMMENT ON COLUMN public.vendor_payment_schedule.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.vendor_payment_schedule.branch_name IS 'Name field';
COMMENT ON COLUMN public.vendor_payment_schedule.bill_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.bill_amount IS 'Monetary amount';
COMMENT ON COLUMN public.vendor_payment_schedule.final_bill_amount IS 'Monetary amount';
COMMENT ON COLUMN public.vendor_payment_schedule.payment_method IS 'payment method field';
COMMENT ON COLUMN public.vendor_payment_schedule.bank_name IS 'Name field';
COMMENT ON COLUMN public.vendor_payment_schedule.iban IS 'iban field';
COMMENT ON COLUMN public.vendor_payment_schedule.due_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.credit_period IS 'credit period field';
COMMENT ON COLUMN public.vendor_payment_schedule.vat_number IS 'Reference number';
COMMENT ON COLUMN public.vendor_payment_schedule.scheduled_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.paid_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.vendor_payment_schedule.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.vendor_payment_schedule.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.vendor_payment_schedule.original_due_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.original_bill_amount IS 'Monetary amount';
COMMENT ON COLUMN public.vendor_payment_schedule.original_final_amount IS 'Monetary amount';
COMMENT ON COLUMN public.vendor_payment_schedule.is_paid IS 'Boolean flag';
COMMENT ON COLUMN public.vendor_payment_schedule.payment_reference IS 'payment reference field';
COMMENT ON COLUMN public.vendor_payment_schedule.task_id IS 'Foreign key reference to task table';
COMMENT ON COLUMN public.vendor_payment_schedule.task_assignment_id IS 'Foreign key reference to task_assignment table';
COMMENT ON COLUMN public.vendor_payment_schedule.receiver_user_id IS 'Foreign key reference to receiver_user table';
COMMENT ON COLUMN public.vendor_payment_schedule.accountant_user_id IS 'Foreign key reference to accountant_user table';
COMMENT ON COLUMN public.vendor_payment_schedule.verification_status IS 'Status indicator';
COMMENT ON COLUMN public.vendor_payment_schedule.verified_by IS 'verified by field';
COMMENT ON COLUMN public.vendor_payment_schedule.verified_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.transaction_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.original_bill_url IS 'URL or file path';
COMMENT ON COLUMN public.vendor_payment_schedule.created_by IS 'created by field';
COMMENT ON COLUMN public.vendor_payment_schedule.pr_excel_verified IS 'Boolean flag';
COMMENT ON COLUMN public.vendor_payment_schedule.pr_excel_verified_by IS 'pr excel verified by field';
COMMENT ON COLUMN public.vendor_payment_schedule.pr_excel_verified_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.discount_amount IS 'Monetary amount';
COMMENT ON COLUMN public.vendor_payment_schedule.discount_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.vendor_payment_schedule.grr_amount IS 'Monetary amount';
COMMENT ON COLUMN public.vendor_payment_schedule.grr_reference_number IS 'Reference number';
COMMENT ON COLUMN public.vendor_payment_schedule.grr_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.vendor_payment_schedule.pri_amount IS 'Monetary amount';
COMMENT ON COLUMN public.vendor_payment_schedule.pri_reference_number IS 'Reference number';
COMMENT ON COLUMN public.vendor_payment_schedule.pri_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.vendor_payment_schedule.last_adjustment_date IS 'Date field';
COMMENT ON COLUMN public.vendor_payment_schedule.last_adjusted_by IS 'last adjusted by field';
COMMENT ON COLUMN public.vendor_payment_schedule.adjustment_history IS 'JSON data structure';
COMMENT ON COLUMN public.vendor_payment_schedule.approval_status IS 'Status indicator';
COMMENT ON COLUMN public.vendor_payment_schedule.approval_requested_by IS 'approval requested by field';
COMMENT ON COLUMN public.vendor_payment_schedule.approval_requested_at IS 'approval requested at field';
COMMENT ON COLUMN public.vendor_payment_schedule.approved_by IS 'approved by field';
COMMENT ON COLUMN public.vendor_payment_schedule.approved_at IS 'approved at field';
COMMENT ON COLUMN public.vendor_payment_schedule.approval_notes IS 'Additional notes or comments';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS vendor_payment_schedule_pkey ON public.vendor_payment_schedule USING btree (id);

-- Foreign key index for receiving_record_id
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_receiving_record_id ON public.vendor_payment_schedule USING btree (receiving_record_id);

-- Foreign key index for vendor_id
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_vendor_id ON public.vendor_payment_schedule USING btree (vendor_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_branch_id ON public.vendor_payment_schedule USING btree (branch_id);

-- Foreign key index for task_id
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_task_id ON public.vendor_payment_schedule USING btree (task_id);

-- Foreign key index for task_assignment_id
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_task_assignment_id ON public.vendor_payment_schedule USING btree (task_assignment_id);

-- Foreign key index for receiver_user_id
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_receiver_user_id ON public.vendor_payment_schedule USING btree (receiver_user_id);

-- Foreign key index for accountant_user_id
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_accountant_user_id ON public.vendor_payment_schedule USING btree (accountant_user_id);

-- Date index for bill_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_bill_date ON public.vendor_payment_schedule USING btree (bill_date);

-- Date index for due_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_due_date ON public.vendor_payment_schedule USING btree (due_date);

-- Date index for scheduled_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_scheduled_date ON public.vendor_payment_schedule USING btree (scheduled_date);

-- Date index for paid_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_paid_date ON public.vendor_payment_schedule USING btree (paid_date);

-- Date index for original_due_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_original_due_date ON public.vendor_payment_schedule USING btree (original_due_date);

-- Date index for verified_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_verified_date ON public.vendor_payment_schedule USING btree (verified_date);

-- Date index for transaction_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_transaction_date ON public.vendor_payment_schedule USING btree (transaction_date);

-- Date index for pr_excel_verified_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_pr_excel_verified_date ON public.vendor_payment_schedule USING btree (pr_excel_verified_date);

-- Date index for last_adjustment_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_last_adjustment_date ON public.vendor_payment_schedule USING btree (last_adjustment_date);

-- Date index for approval_requested_at
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_approval_requested_at ON public.vendor_payment_schedule USING btree (approval_requested_at);

-- Date index for approved_at
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_approved_at ON public.vendor_payment_schedule USING btree (approved_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for vendor_payment_schedule

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.vendor_payment_schedule ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "vendor_payment_schedule_select_policy" ON public.vendor_payment_schedule
    FOR SELECT USING (true);

CREATE POLICY "vendor_payment_schedule_insert_policy" ON public.vendor_payment_schedule
    FOR INSERT WITH CHECK (true);

CREATE POLICY "vendor_payment_schedule_update_policy" ON public.vendor_payment_schedule
    FOR UPDATE USING (true);

CREATE POLICY "vendor_payment_schedule_delete_policy" ON public.vendor_payment_schedule
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for vendor_payment_schedule

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.vendor_payment_schedule (receiving_record_id, bill_number, vendor_id)
VALUES ('uuid-example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.vendor_payment_schedule 
WHERE receiving_record_id = $1;
*/

-- Update example
/*
UPDATE public.vendor_payment_schedule 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF VENDOR_PAYMENT_SCHEDULE SCHEMA
-- ================================================================
