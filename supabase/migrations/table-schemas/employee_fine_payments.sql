-- ================================================================
-- TABLE SCHEMA: employee_fine_payments
-- Generated: 2025-11-06T11:09:39.000Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.employee_fine_payments (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    warning_id uuid,
    payment_method character varying,
    payment_amount numeric NOT NULL,
    payment_currency character varying DEFAULT 'USD'::character varying,
    payment_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    payment_reference character varying,
    payment_notes text,
    processed_by uuid,
    processed_by_username character varying,
    account_code character varying,
    transaction_id character varying,
    receipt_number character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

-- Table comment
COMMENT ON TABLE public.employee_fine_payments IS 'Table for employee fine payments management';

-- Column comments
COMMENT ON COLUMN public.employee_fine_payments.id IS 'Primary key identifier';
COMMENT ON COLUMN public.employee_fine_payments.warning_id IS 'Foreign key reference to warning table';
COMMENT ON COLUMN public.employee_fine_payments.payment_method IS 'payment method field';
COMMENT ON COLUMN public.employee_fine_payments.payment_amount IS 'Monetary amount';
COMMENT ON COLUMN public.employee_fine_payments.payment_currency IS 'payment currency field';
COMMENT ON COLUMN public.employee_fine_payments.payment_date IS 'Date field';
COMMENT ON COLUMN public.employee_fine_payments.payment_reference IS 'payment reference field';
COMMENT ON COLUMN public.employee_fine_payments.payment_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.employee_fine_payments.processed_by IS 'processed by field';
COMMENT ON COLUMN public.employee_fine_payments.processed_by_username IS 'Name field';
COMMENT ON COLUMN public.employee_fine_payments.account_code IS 'account code field';
COMMENT ON COLUMN public.employee_fine_payments.transaction_id IS 'Foreign key reference to transaction table';
COMMENT ON COLUMN public.employee_fine_payments.receipt_number IS 'Reference number';
COMMENT ON COLUMN public.employee_fine_payments.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.employee_fine_payments.updated_at IS 'Timestamp when record was last updated';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS employee_fine_payments_pkey ON public.employee_fine_payments USING btree (id);

-- Foreign key index for warning_id
CREATE INDEX IF NOT EXISTS idx_employee_fine_payments_warning_id ON public.employee_fine_payments USING btree (warning_id);

-- Foreign key index for transaction_id
CREATE INDEX IF NOT EXISTS idx_employee_fine_payments_transaction_id ON public.employee_fine_payments USING btree (transaction_id);

-- Date index for payment_date
CREATE INDEX IF NOT EXISTS idx_employee_fine_payments_payment_date ON public.employee_fine_payments USING btree (payment_date);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for employee_fine_payments

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.employee_fine_payments ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "employee_fine_payments_select_policy" ON public.employee_fine_payments
    FOR SELECT USING (true);

CREATE POLICY "employee_fine_payments_insert_policy" ON public.employee_fine_payments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "employee_fine_payments_update_policy" ON public.employee_fine_payments
    FOR UPDATE USING (true);

CREATE POLICY "employee_fine_payments_delete_policy" ON public.employee_fine_payments
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for employee_fine_payments

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.employee_fine_payments (warning_id, payment_method, payment_amount)
VALUES ('uuid-example', 'example', 123);
*/

-- Select example
/*
SELECT * FROM public.employee_fine_payments 
WHERE warning_id = $1;
*/

-- Update example
/*
UPDATE public.employee_fine_payments 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF EMPLOYEE_FINE_PAYMENTS SCHEMA
-- ================================================================
