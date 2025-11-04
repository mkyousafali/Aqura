-- CORRECT FUNCTION: Always use bill_amount as base and calculate final_bill_amount
-- Set original_final_amount to bill_amount to satisfy the constraint

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
  total_deductions NUMERIC;
  calculated_final_amount NUMERIC;
BEGIN
  -- Get the bill_amount (this is always our base for calculation)
  SELECT bill_amount
  INTO current_bill_amount
  FROM vendor_payment_schedule
  WHERE id = payment_id;
  
  -- STEP 1: First reset final_bill_amount to bill_amount (original amount)
  UPDATE vendor_payment_schedule
  SET final_bill_amount = current_bill_amount
  WHERE id = payment_id;
  
  -- STEP 2: Calculate total deductions using bill_amount as base
  total_deductions := COALESCE(new_discount_amount, 0) + COALESCE(new_grr_amount, 0) + COALESCE(new_pri_amount, 0);
  
  -- STEP 3: Calculate final amount after deductions: bill_amount - deductions
  calculated_final_amount := current_bill_amount - total_deductions;
  
  -- Validate that final amount is not negative
  IF calculated_final_amount < 0 THEN
    RAISE EXCEPTION 'Total deductions (%) exceed the bill amount (%). Final amount would be negative.', 
      total_deductions, current_bill_amount;
  END IF;
  
  -- STEP 4: Apply deductions and set final_bill_amount after deductions
  UPDATE vendor_payment_schedule
  SET 
    original_final_amount = current_bill_amount,  -- Preserve original bill amount for constraint
    final_bill_amount = calculated_final_amount,  -- Set final amount after deductions
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