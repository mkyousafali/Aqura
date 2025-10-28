-- Migration: Fix null due_date values in expense_scheduler table
-- Date: 2025-01-29
-- Description: Updates null due_date values by calculating them based on bill_date (if available) 
--              or created_at date plus credit_period. If no dates available, uses created_at as fallback.

-- Update records where due_date is null
-- Priority 1: Use bill_date + credit_period
UPDATE public.expense_scheduler
SET due_date = (bill_date::date + COALESCE(credit_period, 0))::date
WHERE due_date IS NULL 
  AND bill_date IS NOT NULL;

-- Priority 2: Use created_at + credit_period for remaining null due_dates
UPDATE public.expense_scheduler
SET due_date = (created_at::date + COALESCE(credit_period, 0))::date
WHERE due_date IS NULL 
  AND bill_date IS NULL;

-- Add a comment to track this migration
COMMENT ON COLUMN public.expense_scheduler.due_date IS 'Payment due date - calculated based on bill_date or created_at plus credit_period';

-- Log the number of records updated
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO updated_count
    FROM public.expense_scheduler
    WHERE due_date IS NOT NULL;
    
    RAISE NOTICE 'Fixed due_date for expense_scheduler records. Total records with due_date: %', updated_count;
END $$;
