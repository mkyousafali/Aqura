-- Add bank_name, iban, and credit_period columns to expense_scheduler table if they don't exist

ALTER TABLE public.expense_scheduler
ADD COLUMN IF NOT EXISTS credit_period INTEGER,
ADD COLUMN IF NOT EXISTS bank_name TEXT,
ADD COLUMN IF NOT EXISTS iban TEXT;

-- Create indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_credit_period ON public.expense_scheduler(credit_period);
