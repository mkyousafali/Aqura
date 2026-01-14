-- Create hr_basic_salary table
CREATE TABLE IF NOT EXISTS public.hr_basic_salary (
    employee_id VARCHAR(50) PRIMARY KEY REFERENCES public.hr_employee_master(id) ON DELETE CASCADE,
    basic_salary NUMERIC(10, 2) NOT NULL,
    payment_mode VARCHAR(20) NOT NULL CHECK (payment_mode IN ('Bank', 'Cash')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add payment_mode column if it doesn't exist (for existing tables)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'hr_basic_salary' 
        AND column_name = 'payment_mode'
    ) THEN
        ALTER TABLE public.hr_basic_salary 
        ADD COLUMN payment_mode VARCHAR(20) NOT NULL DEFAULT 'Bank' CHECK (payment_mode IN ('Bank', 'Cash'));
    END IF;
END $$;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_hr_basic_salary_employee_id ON public.hr_basic_salary(employee_id);

-- Enable Row Level Security
ALTER TABLE public.hr_basic_salary ENABLE ROW LEVEL SECURITY;

-- Drop existing policy to start fresh
DROP POLICY IF EXISTS "Allow all access to hr_basic_salary" ON public.hr_basic_salary;

-- Simple permissive policy for all operations (matches app pattern)
CREATE POLICY "Allow all access to hr_basic_salary"
    ON public.hr_basic_salary
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON public.hr_basic_salary TO authenticated;
GRANT ALL ON public.hr_basic_salary TO service_role;
GRANT ALL ON public.hr_basic_salary TO anon;

-- Add comment to table
COMMENT ON TABLE public.hr_basic_salary IS 'Stores basic salary information for employees';
COMMENT ON COLUMN public.hr_basic_salary.employee_id IS 'References hr_employee_master.id';
COMMENT ON COLUMN public.hr_basic_salary.basic_salary IS 'Employee basic salary amount';
COMMENT ON COLUMN public.hr_basic_salary.payment_mode IS 'Payment mode: Bank or Cash';
