-- Add receiving_record_id and pr_excel_verified columns to vendor_payment_schedule
ALTER TABLE public.vendor_payment_schedule
ADD COLUMN receiving_record_id UUID REFERENCES public.receiving_records(id) ON DELETE CASCADE,
ADD COLUMN pr_excel_verified BOOLEAN DEFAULT false;

-- Add index for faster lookups by receiving_record_id
CREATE INDEX idx_vendor_payment_schedule_receiving_record_id 
ON public.vendor_payment_schedule(receiving_record_id);

-- Add comment
COMMENT ON COLUMN public.vendor_payment_schedule.receiving_record_id IS 'Link to the receiving record for PR tracking';
COMMENT ON COLUMN public.vendor_payment_schedule.pr_excel_verified IS 'Whether the PR Excel file has been verified by purchase manager';
