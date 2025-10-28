-- Migration: Create non_approved_payment_scheduler table
-- Date: 2025-01-29
-- Description: Table to store payment schedules that require approval before being posted to expense_scheduler

CREATE TABLE IF NOT EXISTS public.non_approved_payment_scheduler (
  id BIGSERIAL PRIMARY KEY,
  
  -- Schedule identification
  schedule_type TEXT NOT NULL, -- 'single_bill', 'multiple_bill', 'recurring'
  
  -- Step 1: Branch and Category
  branch_id BIGINT NOT NULL,
  branch_name TEXT NOT NULL,
  expense_category_id BIGINT NOT NULL,
  expense_category_name_en TEXT,
  expense_category_name_ar TEXT,
  
  -- Step 2: User (only for single/multiple bills)
  co_user_id UUID,
  co_user_name TEXT,
  
  -- Step 3: Bill/Payment Details
  bill_type TEXT, -- 'vat_applicable', 'no_vat', 'no_bill'
  bill_number TEXT,
  bill_date DATE,
  payment_method TEXT,
  due_date DATE,
  credit_period INTEGER,
  amount NUMERIC NOT NULL,
  bill_file_url TEXT,
  bank_name TEXT,
  iban TEXT,
  
  -- Additional fields
  description TEXT,
  notes TEXT,
  
  -- Recurring schedule fields
  recurring_type TEXT, -- 'daily', 'weekly', 'monthly_date', 'monthly_day', 'yearly', 'half_yearly', 'quarterly', 'custom'
  recurring_metadata JSONB, -- Store recurring schedule details
  
  -- Approval workflow
  approver_id UUID NOT NULL,
  approver_name TEXT NOT NULL,
  approval_status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  approved_at TIMESTAMPTZ,
  approved_by UUID,
  rejection_reason TEXT,
  
  -- Tracking
  expense_scheduler_id BIGINT, -- Link to expense_scheduler after approval
  
  -- Audit fields
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID,
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  -- Foreign key constraints
  CONSTRAINT fk_non_approved_scheduler_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT,
  CONSTRAINT fk_non_approved_scheduler_category FOREIGN KEY (expense_category_id) REFERENCES public.expense_sub_categories(id) ON DELETE RESTRICT,
  CONSTRAINT fk_non_approved_scheduler_co_user FOREIGN KEY (co_user_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_non_approved_scheduler_approver FOREIGN KEY (approver_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_non_approved_scheduler_created_by FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_non_approved_scheduler_approved_by FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT fk_non_approved_scheduler_expense_scheduler FOREIGN KEY (expense_scheduler_id) REFERENCES public.expense_scheduler(id) ON DELETE SET NULL,
  
  -- Check constraints
  CONSTRAINT check_non_approved_schedule_type CHECK (schedule_type IN ('single_bill', 'multiple_bill', 'recurring')),
  CONSTRAINT check_non_approved_approval_status CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  CONSTRAINT check_non_approved_recurring_type CHECK (
    recurring_type IS NULL OR 
    recurring_type IN ('daily', 'weekly', 'monthly_date', 'monthly_day', 'yearly', 'half_yearly', 'quarterly', 'custom')
  ),
  CONSTRAINT check_non_approved_co_user_for_non_recurring CHECK (
    (schedule_type = 'recurring') OR 
    (schedule_type IN ('single_bill', 'multiple_bill') AND co_user_id IS NOT NULL AND co_user_name IS NOT NULL)
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_branch_id ON public.non_approved_payment_scheduler(branch_id);
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_category_id ON public.non_approved_payment_scheduler(expense_category_id);
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_co_user_id ON public.non_approved_payment_scheduler(co_user_id) WHERE co_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_approver_id ON public.non_approved_payment_scheduler(approver_id);
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_created_by ON public.non_approved_payment_scheduler(created_by);
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_approval_status ON public.non_approved_payment_scheduler(approval_status);
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_schedule_type ON public.non_approved_payment_scheduler(schedule_type);
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_created_at ON public.non_approved_payment_scheduler(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_non_approved_scheduler_expense_scheduler_id ON public.non_approved_payment_scheduler(expense_scheduler_id) WHERE expense_scheduler_id IS NOT NULL;

-- Enable Row Level Security
ALTER TABLE public.non_approved_payment_scheduler ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to read non approved scheduler" ON public.non_approved_payment_scheduler;
DROP POLICY IF EXISTS "Allow authenticated users to create non approved scheduler" ON public.non_approved_payment_scheduler;
DROP POLICY IF EXISTS "Allow authenticated users to update non approved scheduler" ON public.non_approved_payment_scheduler;
DROP POLICY IF EXISTS "Service role has full access to non approved scheduler" ON public.non_approved_payment_scheduler;

-- Create RLS Policies
CREATE POLICY "Allow authenticated users to read non approved scheduler"
ON public.non_approved_payment_scheduler
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to create non approved scheduler"
ON public.non_approved_payment_scheduler
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update non approved scheduler"
ON public.non_approved_payment_scheduler
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Service role has full access to non approved scheduler"
ON public.non_approved_payment_scheduler
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_non_approved_scheduler_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS non_approved_scheduler_updated_at ON public.non_approved_payment_scheduler;

CREATE TRIGGER non_approved_scheduler_updated_at
BEFORE UPDATE ON public.non_approved_payment_scheduler
FOR EACH ROW
EXECUTE FUNCTION update_non_approved_scheduler_updated_at();

-- Add comments
COMMENT ON TABLE public.non_approved_payment_scheduler IS 'Stores payment schedules that require approval before being posted to expense_scheduler';
COMMENT ON COLUMN public.non_approved_payment_scheduler.schedule_type IS 'Type of schedule: single_bill, multiple_bill, or recurring';
COMMENT ON COLUMN public.non_approved_payment_scheduler.approval_status IS 'Approval status: pending, approved, rejected';
COMMENT ON COLUMN public.non_approved_payment_scheduler.expense_scheduler_id IS 'Links to expense_scheduler after approval';

-- Log the migration
DO $$
BEGIN
    RAISE NOTICE 'Created non_approved_payment_scheduler table for approval workflow';
END $$;
