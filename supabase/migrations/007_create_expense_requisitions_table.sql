-- Create expense_requisitions table
CREATE TABLE IF NOT EXISTS public.expense_requisitions (
  id BIGSERIAL PRIMARY KEY,
  requisition_number TEXT NOT NULL,
  branch_id BIGINT NOT NULL,
  branch_name TEXT NOT NULL,
  approver_id UUID,
  approver_name TEXT,
  expense_category_id BIGINT,
  expense_category_name_en TEXT,
  expense_category_name_ar TEXT,
  requester_id TEXT NOT NULL,
  requester_name TEXT NOT NULL,
  requester_contact TEXT NOT NULL,
  vat_applicable BOOLEAN DEFAULT false,
  amount NUMERIC NOT NULL,
  payment_category TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending',
  image_url TEXT,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  credit_period INTEGER,
  bank_name TEXT,
  iban TEXT
);

-- Indexes for expense_requisitions
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_branch_id ON public.expense_requisitions(branch_id);
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_approver_id ON public.expense_requisitions(approver_id);
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_expense_category_id ON public.expense_requisitions(expense_category_id);
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_requester_id ON public.expense_requisitions(requester_id);
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_created_at ON public.expense_requisitions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.expense_requisitions ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies for expense_requisitions

-- Policy: Allow authenticated users to read all requisitions
CREATE POLICY "Allow authenticated users to read expense requisitions"
ON public.expense_requisitions
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert requisitions
CREATE POLICY "Allow authenticated users to create expense requisitions"
ON public.expense_requisitions
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update requisitions
CREATE POLICY "Allow authenticated users to update expense requisitions"
ON public.expense_requisitions
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow service role full access
CREATE POLICY "Service role has full access to expense requisitions"
ON public.expense_requisitions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
