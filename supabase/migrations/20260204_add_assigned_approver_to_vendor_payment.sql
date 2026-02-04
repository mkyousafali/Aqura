-- Add assigned_approver_id to vendor_payment_schedule table
-- This stores which specific approver was assigned to approve this payment

ALTER TABLE public.vendor_payment_schedule
ADD COLUMN assigned_approver_id uuid NULL;

-- Add foreign key constraint
ALTER TABLE public.vendor_payment_schedule
ADD CONSTRAINT vendor_payment_assigned_approver_fkey 
FOREIGN KEY (assigned_approver_id) 
REFERENCES users (id) 
ON DELETE SET NULL;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_vendor_payment_assigned_approver 
ON public.vendor_payment_schedule 
USING btree (assigned_approver_id) 
TABLESPACE pg_default;

-- Add comment
COMMENT ON COLUMN public.vendor_payment_schedule.assigned_approver_id IS 'The specific user assigned to approve this vendor payment';
