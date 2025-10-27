-- Add is_active column to expense_parent_categories if not exists
ALTER TABLE public.expense_parent_categories 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add is_active column to expense_sub_categories if not exists
ALTER TABLE public.expense_sub_categories 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Create indexes for is_active columns
CREATE INDEX IF NOT EXISTS idx_expense_parent_categories_is_active 
ON public.expense_parent_categories(is_active);

CREATE INDEX IF NOT EXISTS idx_expense_sub_categories_is_active 
ON public.expense_sub_categories(is_active);

-- Update existing records to be active
UPDATE public.expense_parent_categories 
SET is_active = true 
WHERE is_active IS NULL;

UPDATE public.expense_sub_categories 
SET is_active = true 
WHERE is_active IS NULL;

-- Create expense_scheduler table
CREATE TABLE IF NOT EXISTS public.expense_scheduler (
  id BIGSERIAL PRIMARY KEY,
  
  -- Step 1: Branch and Category
  branch_id BIGINT NOT NULL,
  branch_name TEXT NOT NULL,
  expense_category_id BIGINT NOT NULL,
  expense_category_name_en TEXT,
  expense_category_name_ar TEXT,
  
  -- Step 2: Request and User
  requisition_id BIGINT, -- Optional: link to expense_requisitions
  requisition_number TEXT,
  co_user_id UUID NOT NULL, -- c/o user (mandatory)
  co_user_name TEXT NOT NULL,
  
  -- Step 3: Bill Details
  bill_type TEXT NOT NULL, -- 'vat_applicable', 'no_vat', 'no_bill'
  bill_number TEXT,
  bill_date DATE,
  payment_method TEXT, -- 'advance_cash', 'advance_bank', 'advance_cash_credit', etc.
  due_date DATE, -- Calculated based on payment method
  credit_period INTEGER, -- For credit calculations
  amount NUMERIC NOT NULL,
  bill_file_url TEXT, -- Storage URL for uploaded bill (image/PDF)
  bank_name TEXT, -- Optional bank name
  iban TEXT, -- Optional IBAN
  
  -- Additional fields
  description TEXT,
  notes TEXT,
  
  -- Payment tracking
  is_paid BOOLEAN DEFAULT false,
  paid_date TIMESTAMPTZ,
  
  -- Status tracking
  status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'paid'
  
  -- Audit fields
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID,
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  -- Foreign key constraints
  CONSTRAINT fk_expense_scheduler_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_scheduler_category FOREIGN KEY (expense_category_id) REFERENCES public.expense_sub_categories(id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_scheduler_requisition FOREIGN KEY (requisition_id) REFERENCES public.expense_requisitions(id) ON DELETE SET NULL,
  CONSTRAINT fk_expense_scheduler_co_user FOREIGN KEY (co_user_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_scheduler_created_by FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT
);

-- Indexes for expense_scheduler
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_branch_id ON public.expense_scheduler(branch_id);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_category_id ON public.expense_scheduler(expense_category_id);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_requisition_id ON public.expense_scheduler(requisition_id);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_co_user_id ON public.expense_scheduler(co_user_id);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_created_by ON public.expense_scheduler(created_by);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_status ON public.expense_scheduler(status);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_is_paid ON public.expense_scheduler(is_paid);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_created_at ON public.expense_scheduler(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_due_date ON public.expense_scheduler(due_date);

-- Enable Row Level Security
ALTER TABLE public.expense_scheduler ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to read expense scheduler" ON public.expense_scheduler;
DROP POLICY IF EXISTS "Allow authenticated users to create expense scheduler" ON public.expense_scheduler;
DROP POLICY IF EXISTS "Allow authenticated users to update expense scheduler" ON public.expense_scheduler;
DROP POLICY IF EXISTS "Service role has full access to expense scheduler" ON public.expense_scheduler;

-- Create RLS Policies for expense_scheduler

-- Policy: Allow authenticated users to read all scheduler entries
CREATE POLICY "Allow authenticated users to read expense scheduler"
ON public.expense_scheduler
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert scheduler entries
CREATE POLICY "Allow authenticated users to create expense scheduler"
ON public.expense_scheduler
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update scheduler entries
CREATE POLICY "Allow authenticated users to update expense scheduler"
ON public.expense_scheduler
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow service role full access
CREATE POLICY "Service role has full access to expense scheduler"
ON public.expense_scheduler
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_expense_scheduler_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS expense_scheduler_updated_at ON public.expense_scheduler;

CREATE TRIGGER expense_scheduler_updated_at
BEFORE UPDATE ON public.expense_scheduler
FOR EACH ROW
EXECUTE FUNCTION update_expense_scheduler_updated_at();
