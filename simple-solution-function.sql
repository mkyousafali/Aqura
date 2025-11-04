-- SIMPLE SOLUTION: Set original_final_amount to preserve the reference amount
-- This way the constraint will always check against the original amount

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
  current_original_final_amount NUMERIC;
  total_deductions NUMERIC;
  calculated_final_amount NUMERIC;
BEGIN
  -- Get the current values for this payment
  SELECT 
    bill_amount, 
    original_final_amount
  INTO 
    current_bill_amount, 
    current_original_final_amount
  FROM vendor_payment_schedule
  WHERE id = payment_id;
  
  -- Calculate total deductions
  total_deductions := COALESCE(new_discount_amount, 0) + COALESCE(new_grr_amount, 0) + COALESCE(new_pri_amount, 0);
  
  -- Calculate the new final amount from bill_amount
  calculated_final_amount := current_bill_amount - total_deductions;
  
  -- Ensure calculated final amount is not negative
  IF calculated_final_amount < 0 THEN
    RAISE EXCEPTION 'Total deductions (%) exceed the bill amount (%). Cannot proceed.', 
      total_deductions, current_bill_amount;
  END IF;
  
  -- Update the record - SET original_final_amount to bill_amount if it's null
  -- This ensures the constraint uses bill_amount as reference
  UPDATE vendor_payment_schedule
  SET 
    original_final_amount = COALESCE(current_original_final_amount, current_bill_amount),
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
  
  -- Verify the update succeeded
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found: %', payment_id;
  END IF;
  
END;
$$;