-- Add payment_priority column to vendors table
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS payment_priority TEXT DEFAULT 'Normal' 
CHECK (payment_priority IN ('Most', 'Medium', 'Normal', 'Low'));

-- Create index for payment_priority
CREATE INDEX IF NOT EXISTS idx_vendors_payment_priority ON public.vendors(payment_priority);

-- Set all existing vendors to 'Normal' priority
UPDATE public.vendors 
SET payment_priority = 'Normal' 
WHERE payment_priority IS NULL;

-- Add comment to column
COMMENT ON COLUMN public.vendors.payment_priority IS 'Payment priority level: Most, Medium, Normal (default), Low';
