-- Add indexes for due_date columns to speed up queries in MonthlyManager
-- This will dramatically improve performance when filtering by date

-- Index for vendor_payment_schedule.due_date
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_due_date 
ON vendor_payment_schedule(due_date);

-- Index for expense_scheduler.due_date
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_due_date 
ON expense_scheduler(due_date);

-- Composite index for vendor_payment_schedule (due_date + is_paid) for faster filtering
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_due_date_paid 
ON vendor_payment_schedule(due_date, is_paid);

-- Composite index for expense_scheduler (due_date + is_paid) for faster filtering
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_due_date_paid 
ON expense_scheduler(due_date, is_paid);

-- Index for faster branch lookups
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_branch_id 
ON vendor_payment_schedule(branch_id);

CREATE INDEX IF NOT EXISTS idx_expense_scheduler_branch_id 
ON expense_scheduler(branch_id);
