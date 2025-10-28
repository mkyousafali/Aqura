-- Migration: Add recurring schedule fields to expense_scheduler table
-- Date: 2025-01-29
-- Description: Add fields to support recurring expense schedules and schedule type tracking with approval workflow

-- Add schedule_type column to identify the source/type of schedule
ALTER TABLE public.expense_scheduler
ADD COLUMN IF NOT EXISTS schedule_type TEXT DEFAULT 'single_bill';

-- Add recurring_type column for recurring schedules
ALTER TABLE public.expense_scheduler
ADD COLUMN IF NOT EXISTS recurring_type TEXT;

-- Add recurring_metadata column to store type-specific data as JSON
ALTER TABLE public.expense_scheduler
ADD COLUMN IF NOT EXISTS recurring_metadata JSONB;

-- Add approver fields for recurring schedules
ALTER TABLE public.expense_scheduler
ADD COLUMN IF NOT EXISTS approver_id UUID;

ALTER TABLE public.expense_scheduler
ADD COLUMN IF NOT EXISTS approver_name TEXT;

-- Add foreign key constraint for approver
ALTER TABLE public.expense_scheduler
ADD CONSTRAINT fk_expense_scheduler_approver 
FOREIGN KEY (approver_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Make co_user_id and co_user_name nullable for recurring schedules
ALTER TABLE public.expense_scheduler
ALTER COLUMN co_user_id DROP NOT NULL;

ALTER TABLE public.expense_scheduler
ALTER COLUMN co_user_name DROP NOT NULL;

-- Add check constraint to ensure schedule_type has valid values
ALTER TABLE public.expense_scheduler
ADD CONSTRAINT check_schedule_type_values
CHECK (
  schedule_type IN ('single_bill', 'multiple_bill', 'recurring')
);

-- Add check constraint to ensure co_user fields are provided for non-recurring schedules
ALTER TABLE public.expense_scheduler
ADD CONSTRAINT check_co_user_for_non_recurring 
CHECK (
  (schedule_type = 'recurring') OR 
  (schedule_type IN ('single_bill', 'multiple_bill') AND co_user_id IS NOT NULL AND co_user_name IS NOT NULL)
);

-- Add check constraint for recurring_type (only for recurring schedules)
ALTER TABLE public.expense_scheduler
ADD CONSTRAINT check_recurring_type_values
CHECK (
  (schedule_type != 'recurring' AND recurring_type IS NULL) OR
  (schedule_type = 'recurring' AND recurring_type IN ('daily', 'weekly', 'monthly_date', 'monthly_day', 'yearly', 'half_yearly', 'quarterly', 'custom'))
);

-- Add check constraint to ensure approver is provided for recurring schedules
ALTER TABLE public.expense_scheduler
ADD CONSTRAINT check_approver_for_recurring 
CHECK (
  (schedule_type != 'recurring') OR 
  (schedule_type = 'recurring' AND approver_id IS NOT NULL AND approver_name IS NOT NULL)
);

-- Create index for schedule_type
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_schedule_type 
ON public.expense_scheduler(schedule_type);

CREATE INDEX IF NOT EXISTS idx_expense_scheduler_recurring_type 
ON public.expense_scheduler(recurring_type) 
WHERE recurring_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_expense_scheduler_approver_id 
ON public.expense_scheduler(approver_id)
WHERE approver_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN public.expense_scheduler.schedule_type IS 'Type of schedule: single_bill (from Single Bill Scheduling), multiple_bill (from Multiple Bill Scheduling), recurring (from Recurring Expense Scheduler)';
COMMENT ON COLUMN public.expense_scheduler.recurring_type IS 'Type of recurring schedule: daily, weekly, monthly_date, monthly_day, yearly, half_yearly, quarterly, custom. Only applies when schedule_type is recurring';
COMMENT ON COLUMN public.expense_scheduler.recurring_metadata IS 'JSON metadata for recurring schedule details (until_date, weekday, month_position, etc.)';
COMMENT ON COLUMN public.expense_scheduler.approver_id IS 'User ID of the approver for recurring schedules. Required for recurring schedules.';
COMMENT ON COLUMN public.expense_scheduler.approver_name IS 'Name of the approver for recurring schedules. Required for recurring schedules.';

-- Update existing records to have schedule_type = 'single_bill'
UPDATE public.expense_scheduler
SET schedule_type = 'single_bill'
WHERE schedule_type IS NULL;

-- Log the migration
DO $$
BEGIN
    RAISE NOTICE 'Added schedule_type, recurring fields, and approval workflow to expense_scheduler table';
END $$;

