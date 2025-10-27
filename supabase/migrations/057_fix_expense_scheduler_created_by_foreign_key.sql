-- Fix foreign key constraint for created_by to point to public.users instead of auth.users

-- Drop the existing constraint
ALTER TABLE public.expense_scheduler
DROP CONSTRAINT IF EXISTS fk_expense_scheduler_created_by;

-- Add the correct constraint pointing to public.users
ALTER TABLE public.expense_scheduler
ADD CONSTRAINT fk_expense_scheduler_created_by 
FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;
