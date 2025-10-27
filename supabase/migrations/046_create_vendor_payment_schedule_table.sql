-- Create vendor_payment_schedule table
CREATE TABLE IF NOT EXISTS public.vendor_payment_schedule (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  receiving_record_id UUID,
  bill_number VARCHAR(255),
  vendor_id VARCHAR(255),
  vendor_name VARCHAR(255),
  branch_id INTEGER,
  branch_name VARCHAR(255),
  bill_date DATE,
  bill_amount NUMERIC,
  final_bill_amount NUMERIC,
  payment_method VARCHAR(255),
  bank_name VARCHAR(255),
  iban VARCHAR(255),
  due_date DATE,
  credit_period INTEGER,
  vat_number VARCHAR(255),
  scheduled_date TIMESTAMP DEFAULT now(),
  paid_date TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  original_due_date DATE,
  original_bill_amount NUMERIC,
  original_final_amount NUMERIC,
  is_paid BOOLEAN DEFAULT false,
  payment_reference VARCHAR(255),
  task_id UUID,
  task_assignment_id UUID,
  receiver_user_id UUID,
  accountant_user_id UUID,
  verification_status TEXT DEFAULT 'pending',
  verified_by UUID,
  verified_date TIMESTAMPTZ,
  transaction_date TIMESTAMPTZ,
  original_bill_url TEXT,
  created_by UUID,
  pr_excel_verified BOOLEAN DEFAULT false,
  pr_excel_verified_by UUID REFERENCES public.users(id),
  pr_excel_verified_date TIMESTAMPTZ,
  PRIMARY KEY (id)
);

-- Indexes for vendor_payment_schedule
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_receiving_record_id ON public.vendor_payment_schedule(receiving_record_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_vendor_id ON public.vendor_payment_schedule(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_branch_id ON public.vendor_payment_schedule(branch_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_task_id ON public.vendor_payment_schedule(task_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_task_assignment_id ON public.vendor_payment_schedule(task_assignment_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_receiver_user_id ON public.vendor_payment_schedule(receiver_user_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_accountant_user_id ON public.vendor_payment_schedule(accountant_user_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_created_at ON public.vendor_payment_schedule(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.vendor_payment_schedule ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to read vendor payment schedule" ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS "Allow authenticated users to insert vendor payment schedule" ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS "Allow authenticated users to update vendor payment schedule" ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS "Service role has full access to vendor payment schedule" ON public.vendor_payment_schedule;

-- Create RLS Policies for vendor_payment_schedule

-- Policy: Allow authenticated users to read all payment schedule entries
CREATE POLICY "Allow authenticated users to read vendor payment schedule"
ON public.vendor_payment_schedule
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert payment schedule entries
CREATE POLICY "Allow authenticated users to insert vendor payment schedule"
ON public.vendor_payment_schedule
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update payment schedule entries
CREATE POLICY "Allow authenticated users to update vendor payment schedule"
ON public.vendor_payment_schedule
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow service role full access
CREATE POLICY "Service role has full access to vendor payment schedule"
ON public.vendor_payment_schedule
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
