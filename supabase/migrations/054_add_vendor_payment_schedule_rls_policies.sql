-- Add RLS policies to vendor_payment_schedule table

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to read vendor payment schedule" ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS "Allow authenticated users to insert vendor payment schedule" ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS "Allow authenticated users to update vendor payment schedule" ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS "Service role has full access to vendor payment schedule" ON public.vendor_payment_schedule;

-- Create RLS Policies for vendor_payment_schedule

-- Policy: Allow authenticated users to read all payment schedule entries
CREATE POLICY "Allow authenticated users to read vendor payment schedule"
ON public.vendor_payment_schedule
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert payment schedule entries
CREATE POLICY "Allow authenticated users to insert vendor payment schedule"
ON public.vendor_payment_schedule
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update payment schedule entries
CREATE POLICY "Allow authenticated users to update vendor payment schedule"
ON public.vendor_payment_schedule
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow service role full access
CREATE POLICY "Service role has full access to vendor payment schedule"
ON public.vendor_payment_schedule
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
