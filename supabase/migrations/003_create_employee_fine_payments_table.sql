-- Create employee_fine_payments table
CREATE TABLE IF NOT EXISTS public.employee_fine_payments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  warning_id UUID,
  payment_method VARCHAR(255),
  payment_amount NUMERIC NOT NULL,
  payment_currency VARCHAR(255) DEFAULT 'USD',
  payment_date TIMESTAMP DEFAULT now(),
  payment_reference VARCHAR(255),
  payment_notes TEXT,
  processed_by UUID,
  processed_by_username VARCHAR(255),
  account_code VARCHAR(255),
  transaction_id VARCHAR(255),
  receipt_number VARCHAR(255),
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for employee_fine_payments
CREATE INDEX IF NOT EXISTS idx_employee_fine_payments_warning_id ON public.employee_fine_payments(warning_id);
CREATE INDEX IF NOT EXISTS idx_employee_fine_payments_transaction_id ON public.employee_fine_payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_employee_fine_payments_created_at ON public.employee_fine_payments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.employee_fine_payments ENABLE ROW LEVEL SECURITY;
