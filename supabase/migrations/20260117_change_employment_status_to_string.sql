-- Change is_currently_employed from boolean to employment_status as text
-- This migration updates the column to store employment status values: Resigned, Job, Vacation, Terminated, Run Away

-- Add new column first
ALTER TABLE public.hr_employee_master 
ADD COLUMN employment_status TEXT DEFAULT 'Resigned';

-- Update existing data: convert boolean to employment status
UPDATE public.hr_employee_master 
SET employment_status = CASE 
  WHEN is_currently_employed = true THEN 'Job (With Finger)'
  WHEN is_currently_employed = false THEN 'Resigned'
  ELSE 'Resigned'
END;

-- Drop the old boolean column
ALTER TABLE public.hr_employee_master 
DROP COLUMN is_currently_employed;

-- Rename the new column to maintain compatibility if needed
-- Or we can keep it as employment_status
-- ALTER TABLE public.hr_employee_master 
-- RENAME COLUMN employment_status TO is_currently_employed;

-- Add constraint to ensure only valid values
ALTER TABLE public.hr_employee_master 
ADD CONSTRAINT employment_status_values 
CHECK (employment_status IN ('Resigned', 'Job (With Finger)', 'Vacation', 'Terminated', 'Run Away'));

-- Create an index for faster queries
CREATE INDEX idx_employment_status ON public.hr_employee_master(employment_status);
