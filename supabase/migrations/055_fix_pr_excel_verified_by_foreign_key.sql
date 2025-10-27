-- Fix foreign key constraint for pr_excel_verified_by to point to public.users instead of auth.users

-- Drop the existing constraint
ALTER TABLE public.vendor_payment_schedule
DROP CONSTRAINT IF EXISTS vendor_payment_schedule_pr_excel_verified_by_fkey;

-- Add the correct constraint pointing to public.users
ALTER TABLE public.vendor_payment_schedule
ADD CONSTRAINT vendor_payment_schedule_pr_excel_verified_by_fkey 
FOREIGN KEY (pr_excel_verified_by) REFERENCES public.users(id);
