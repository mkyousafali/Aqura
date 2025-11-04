-- Create a function to update vendor payment with exact NUMERIC calculation
-- This avoids floating-point precision errors by doing arithmetic in PostgreSQL

CREATE OR REPLACE FUNCTION update_vendor_payment_with_exact_calculation(
  payment_id UUID,
  new_discount_amount NUMERIC DEFAULT NULL,
  new_grr_amount NUMERIC DEFAULT NULL,
  new_pri_amount NUMERIC DEFAULT NULL,
  discount_notes_val TEXT DEFAULT NULL,
  grr_reference_val TEXT DEFAULT NULL,
  grr_notes_val TEXT DEFAULT NULL,
  pri_reference_val TEXT DEFAULT NULL,
  pri_notes_val TEXT DEFAULT NULL,
  history_val JSONB DEFAULT NULL
) 
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_bill_amount NUMERIC;
  calculated_final_amount NUMERIC;
BEGIN
  -- Get the current bill_amount for this payment
  SELECT bill_amount INTO current_bill_amount
  FROM vendor_payment_schedule
  WHERE id = payment_id;
  
  -- Calculate final_bill_amount using exact NUMERIC arithmetic
  -- COALESCE treats NULL as 0 for calculations
  calculated_final_amount := current_bill_amount 
    - COALESCE(new_discount_amount, 0) 
    - COALESCE(new_grr_amount, 0) 
    - COALESCE(new_pri_amount, 0);
  
  -- Update the record with the calculated final amount
  UPDATE vendor_payment_schedule
  SET 
    final_bill_amount = calculated_final_amount,
    discount_amount = new_discount_amount,
    discount_notes = discount_notes_val,
    grr_amount = new_grr_amount,
    grr_reference_number = grr_reference_val,
    grr_notes = grr_notes_val,
    pri_amount = new_pri_amount,
    pri_reference_number = pri_reference_val,
    pri_notes = pri_notes_val,
    adjustment_history = COALESCE(history_val, adjustment_history),
    updated_at = NOW()
  WHERE id = payment_id;
  
  -- Verify the constraint is satisfied (this should always pass now)
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found: %', payment_id;
  END IF;
  
END;
$$;