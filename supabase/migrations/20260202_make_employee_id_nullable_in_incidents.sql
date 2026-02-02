-- Make employee_id nullable in incidents table to support non-employee incidents
-- Non-employee incidents (Customer, Maintenance, Vendor, Vehicle, Government, Other) don't have an employee

ALTER TABLE public.incidents 
ALTER COLUMN employee_id DROP NOT NULL;

-- Also make violation_id nullable if it isn't already (non-employee incidents don't have violations)
ALTER TABLE public.incidents 
ALTER COLUMN violation_id DROP NOT NULL;

-- Add comment explaining the change
COMMENT ON COLUMN public.incidents.employee_id IS 'Employee ID - NULL for non-employee incidents (Customer, Maintenance, Vendor, Vehicle, Government, Other)';
COMMENT ON COLUMN public.incidents.violation_id IS 'Violation ID - NULL for non-employee incidents';
