-- Fix RLS policies for vendor_payment_schedule to match box_operations pattern

-- Drop existing duplicate policies
DROP POLICY IF EXISTS allow_delete ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS allow_insert ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS allow_select ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS allow_update ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS rls_delete ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS rls_insert ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS rls_select ON public.vendor_payment_schedule;
DROP POLICY IF EXISTS rls_update ON public.vendor_payment_schedule;

-- Create new policies matching box_operations pattern
CREATE POLICY vendor_payment_schedule_select ON public.vendor_payment_schedule
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY vendor_payment_schedule_insert ON public.vendor_payment_schedule
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY vendor_payment_schedule_update ON public.vendor_payment_schedule
  FOR UPDATE
  TO public
  USING (true);

CREATE POLICY vendor_payment_schedule_delete ON public.vendor_payment_schedule
  FOR DELETE
  TO public
  USING (true);
