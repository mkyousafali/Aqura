-- ================================================================
-- TABLE SCHEMA: hr_fingerprint_transactions
-- Generated: 2025-11-06T11:09:39.012Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_fingerprint_transactions (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    employee_id character varying NOT NULL,
    name character varying,
    branch_id bigint NOT NULL,
    transaction_date date NOT NULL,
    transaction_time time without time zone NOT NULL,
    punch_state character varying NOT NULL,
    device_id character varying,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.hr_fingerprint_transactions IS 'Table for hr fingerprint transactions management';

-- Column comments
COMMENT ON COLUMN public.hr_fingerprint_transactions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_fingerprint_transactions.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.hr_fingerprint_transactions.name IS 'Name field';
COMMENT ON COLUMN public.hr_fingerprint_transactions.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.hr_fingerprint_transactions.transaction_date IS 'Date field';
COMMENT ON COLUMN public.hr_fingerprint_transactions.transaction_time IS 'transaction time field';
COMMENT ON COLUMN public.hr_fingerprint_transactions.punch_state IS 'punch state field';
COMMENT ON COLUMN public.hr_fingerprint_transactions.device_id IS 'Foreign key reference to device table';
COMMENT ON COLUMN public.hr_fingerprint_transactions.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_fingerprint_transactions_pkey ON public.hr_fingerprint_transactions USING btree (id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_transactions_employee_id ON public.hr_fingerprint_transactions USING btree (employee_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_transactions_branch_id ON public.hr_fingerprint_transactions USING btree (branch_id);

-- Foreign key index for device_id
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_transactions_device_id ON public.hr_fingerprint_transactions USING btree (device_id);

-- Date index for transaction_date
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_transactions_transaction_date ON public.hr_fingerprint_transactions USING btree (transaction_date);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_fingerprint_transactions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_fingerprint_transactions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_fingerprint_transactions_select_policy" ON public.hr_fingerprint_transactions
    FOR SELECT USING (true);

CREATE POLICY "hr_fingerprint_transactions_insert_policy" ON public.hr_fingerprint_transactions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_fingerprint_transactions_update_policy" ON public.hr_fingerprint_transactions
    FOR UPDATE USING (true);

CREATE POLICY "hr_fingerprint_transactions_delete_policy" ON public.hr_fingerprint_transactions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_fingerprint_transactions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_fingerprint_transactions (employee_id, name, branch_id)
VALUES ('example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.hr_fingerprint_transactions 
WHERE employee_id = $1;
*/

-- Update example
/*
UPDATE public.hr_fingerprint_transactions 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_FINGERPRINT_TRANSACTIONS SCHEMA
-- ================================================================
