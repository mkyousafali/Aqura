-- Add GOSI percentage columns to hr_basic_salary table
ALTER TABLE public.hr_basic_salary
ADD COLUMN IF NOT EXISTS gosi_is_percentage BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS gosi_percentage NUMERIC(5,2) DEFAULT 0;

-- Add comment
COMMENT ON COLUMN public.hr_basic_salary.gosi_is_percentage IS 'Whether GOSI deduction is calculated as percentage of (basic_salary + accommodation_allowance)';
COMMENT ON COLUMN public.hr_basic_salary.gosi_percentage IS 'GOSI percentage when gosi_is_percentage is TRUE';
