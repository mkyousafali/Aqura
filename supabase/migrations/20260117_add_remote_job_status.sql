-- Add 'Remote Job', 'Job (No Finger)', and 'Job (With Finger)' to employment_status check constraint
ALTER TABLE public.hr_employee_master 
DROP CONSTRAINT IF EXISTS employment_status_values;

-- Update existing 'Job' to 'Job (With Finger)'
UPDATE public.hr_employee_master 
SET employment_status = 'Job (With Finger)' 
WHERE employment_status = 'Job';

ALTER TABLE public.hr_employee_master 
ADD CONSTRAINT employment_status_values 
CHECK (employment_status IN ('Resigned', 'Job (With Finger)', 'Vacation', 'Terminated', 'Run Away', 'Remote Job', 'Job (No Finger)'));
