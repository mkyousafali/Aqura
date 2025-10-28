-- Migration: Add payment_reference column to expense_scheduler table
-- Date: 2025-01-29
-- Description: Adds payment_reference column to allow users to track payment reference numbers for expense scheduler payments

-- Add payment_reference column to expense_scheduler table
ALTER TABLE public.expense_scheduler
ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(255);

-- Add comment to the column
COMMENT ON COLUMN public.expense_scheduler.payment_reference IS 'Payment reference number or transaction ID for tracking purposes';

-- Create index for faster lookups by payment reference
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_payment_reference 
ON public.expense_scheduler(payment_reference) 
WHERE payment_reference IS NOT NULL;
