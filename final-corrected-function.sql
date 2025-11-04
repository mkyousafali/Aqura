-- Final corrected function that properly handles the constraint
-- The constraint is: total_deductions <= COALESCE(original_final_amount, final_bill_amount, bill_amount)
-- But the issue is that final_bill_amount is being updated DURING the transaction
-- We need to ensure the constraint validation uses the RIGHT reference amount

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
  current_final_bill_amount NUMERIC;
  reference_amount NUMERIC;
  total_deductions NUMERIC;
  calculated_final_amount NUMERIC;
BEGIN
  -- Get the current values for this payment
  SELECT 
    bill_amount, 
    original_final_amount,
    final_bill_amount
  INTO 
    current_bill_amount, 
    current_original_final_amount,
    current_final_bill_amount
  FROM vendor_payment_schedule
  WHERE id = payment_id;
  
  -- Calculate total deductions
  total_deductions := COALESCE(new_discount_amount, 0) + COALESCE(new_grr_amount, 0) + COALESCE(new_pri_amount, 0);
  
  -- The reference amount should be the original amount we can deduct from
  -- If there's an original_final_amount, use that (it's the intended final amount)
  -- Otherwise, use bill_amount (the total bill amount)
  reference_amount := COALESCE(current_original_final_amount, current_bill_amount);
  
  -- Calculate the new final amount
  calculated_final_amount := reference_amount - total_deductions;
  
  -- Pre-validation: ensure this will satisfy the constraint
  -- The constraint will check: total_deductions <= COALESCE(original_final_amount, calculated_final_amount, bill_amount)
  -- Since we're setting calculated_final_amount, it will use original_final_amount if it exists, otherwise bill_amount
  IF current_original_final_amount IS NOT NULL THEN
    -- Will check against original_final_amount
    IF total_deductions > current_original_final_amount THEN
      RAISE EXCEPTION 'Total deductions (%) exceed the original final amount (%). Cannot proceed.', 
        total_deductions, current_original_final_amount;
    END IF;
  ELSE
    -- Will check against bill_amount (since we're updating final_bill_amount)
    IF total_deductions > current_bill_amount THEN
      RAISE EXCEPTION 'Total deductions (%) exceed the bill amount (%). Cannot proceed.', 
        total_deductions, current_bill_amount;
    END IF;
  END IF;
  
  -- Ensure calculated final amount is not negative
  IF calculated_final_amount < 0 THEN
    RAISE EXCEPTION 'Calculated final amount (%) would be negative. Total deductions (%) exceed reference amount (%).', 
      calculated_final_amount, total_deductions, reference_amount;
  END IF;
  
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
  
  -- Verify the update succeeded
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found: %', payment_id;
  END IF;
  
END;
$$;