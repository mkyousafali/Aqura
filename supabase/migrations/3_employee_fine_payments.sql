-- Create employee_fine_payments table for managing employee fine payment records
-- This table stores payment information for employee warnings and fines

-- Create the employee_fine_payments table
CREATE TABLE IF NOT EXISTS public.employee_fine_payments (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    warning_id UUID NULL,
    payment_method CHARACTER VARYING(50) NULL,
    payment_amount NUMERIC(10, 2) NOT NULL,
    payment_currency CHARACTER VARYING(3) NULL DEFAULT 'USD'::character varying,
    payment_date TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT CURRENT_TIMESTAMP,
    payment_reference CHARACTER VARYING(100) NULL,
    payment_notes TEXT NULL,
    processed_by UUID NULL,
    processed_by_username CHARACTER VARYING(255) NULL,
    account_code CHARACTER VARYING(50) NULL,
    transaction_id CHARACTER VARYING(100) NULL,
    receipt_number CHARACTER VARYING(100) NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT employee_fine_payments_pkey PRIMARY KEY (id),
    CONSTRAINT employee_fine_payments_processed_by_fkey 
        FOREIGN KEY (processed_by) REFERENCES users (id) ON DELETE SET NULL
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_fine_payments_warning_id 
ON public.employee_fine_payments USING btree (warning_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fine_payments_payment_date 
ON public.employee_fine_payments USING btree (payment_date) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fine_payments_processed_by 
ON public.employee_fine_payments USING btree (processed_by) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_fine_payments_payment_method 
ON public.employee_fine_payments (payment_method) 
WHERE payment_method IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fine_payments_transaction_id 
ON public.employee_fine_payments (transaction_id) 
WHERE transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fine_payments_receipt_number 
ON public.employee_fine_payments (receipt_number) 
WHERE receipt_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fine_payments_amount_currency 
ON public.employee_fine_payments (payment_amount, payment_currency);

CREATE INDEX IF NOT EXISTS idx_fine_payments_created_at 
ON public.employee_fine_payments (created_at DESC);

-- Create trigger for automatic updated_at timestamp
CREATE OR REPLACE FUNCTION update_employee_fine_payments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_employee_fine_payments_updated_at 
BEFORE UPDATE ON employee_fine_payments 
FOR EACH ROW 
EXECUTE FUNCTION update_employee_fine_payments_updated_at();

-- Add table and column comments for documentation
COMMENT ON TABLE public.employee_fine_payments IS 'Payment records for employee warnings and fines';
COMMENT ON COLUMN public.employee_fine_payments.id IS 'Unique identifier for the payment record';
COMMENT ON COLUMN public.employee_fine_payments.warning_id IS 'Reference to the warning this payment is for';
COMMENT ON COLUMN public.employee_fine_payments.payment_method IS 'Method used for payment (cash, bank transfer, etc.)';
COMMENT ON COLUMN public.employee_fine_payments.payment_amount IS 'Amount paid for the fine';
COMMENT ON COLUMN public.employee_fine_payments.payment_currency IS 'Currency code for the payment amount';
COMMENT ON COLUMN public.employee_fine_payments.payment_date IS 'Date and time when payment was made';
COMMENT ON COLUMN public.employee_fine_payments.payment_reference IS 'External payment reference number';
COMMENT ON COLUMN public.employee_fine_payments.payment_notes IS 'Additional notes about the payment';
COMMENT ON COLUMN public.employee_fine_payments.processed_by IS 'User ID who processed the payment';
COMMENT ON COLUMN public.employee_fine_payments.processed_by_username IS 'Username of who processed the payment';
COMMENT ON COLUMN public.employee_fine_payments.account_code IS 'Accounting code for the payment';
COMMENT ON COLUMN public.employee_fine_payments.transaction_id IS 'Unique transaction identifier';
COMMENT ON COLUMN public.employee_fine_payments.receipt_number IS 'Receipt number for the payment';
COMMENT ON COLUMN public.employee_fine_payments.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.employee_fine_payments.updated_at IS 'Timestamp when the record was last updated';

-- Add constraints for data validation
ALTER TABLE public.employee_fine_payments 
ADD CONSTRAINT chk_payment_amount_positive 
CHECK (payment_amount > 0);

ALTER TABLE public.employee_fine_payments 
ADD CONSTRAINT chk_payment_currency_format 
CHECK (payment_currency ~ '^[A-Z]{3}$');

-- Create unique constraint for transaction_id to prevent duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_fine_payments_unique_transaction 
ON public.employee_fine_payments (transaction_id) 
WHERE transaction_id IS NOT NULL;

-- Table, indexes, constraints, and trigger created successfully
RAISE NOTICE 'employee_fine_payments table created with indexes, constraints, and trigger';