-- Add PR Excel verification columns to vendor_payment_schedule table
ALTER TABLE public.vendor_payment_schedule
ADD COLUMN IF NOT EXISTS pr_excel_verified BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS pr_excel_verified_by UUID REFERENCES public.users(id),
ADD COLUMN IF NOT EXISTS pr_excel_verified_date TIMESTAMPTZ;

-- Create index for PR Excel verification status
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_pr_excel_verified 
ON public.vendor_payment_schedule(pr_excel_verified);

-- Create index for PR Excel verified by
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_pr_excel_verified_by 
ON public.vendor_payment_schedule(pr_excel_verified_by);
