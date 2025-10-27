-- Fix automatic calculation of total_return_amount and final_bill_amount
-- This trigger ensures these values are always calculated automatically

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS calculate_receiving_amounts_trigger ON receiving_records;
DROP FUNCTION IF EXISTS calculate_receiving_amounts();

-- Create function to calculate amounts
CREATE OR REPLACE FUNCTION calculate_receiving_amounts()
RETURNS TRIGGER AS 
BEGIN
    -- Calculate total_return_amount
    NEW.total_return_amount := 
        COALESCE(NEW.expired_return_amount, 0) +
        COALESCE(NEW.near_expiry_return_amount, 0) +
        COALESCE(NEW.over_stock_return_amount, 0) +
        COALESCE(NEW.damage_return_amount, 0);
    
    -- Calculate final_bill_amount (bill_amount - total_return_amount)
    NEW.final_bill_amount := NEW.bill_amount - NEW.total_return_amount;
    
    -- Ensure final amount is not negative
    IF NEW.final_bill_amount < 0 THEN
        NEW.final_bill_amount := 0;
    END IF;
    
    RETURN NEW;
END;
 LANGUAGE plpgsql;

-- Create trigger that fires BEFORE INSERT or UPDATE
CREATE TRIGGER calculate_receiving_amounts_trigger
    BEFORE INSERT OR UPDATE ON receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION calculate_receiving_amounts();

-- Update existing records to calculate these values
UPDATE receiving_records
SET 
    total_return_amount = 
        COALESCE(expired_return_amount, 0) +
        COALESCE(near_expiry_return_amount, 0) +
        COALESCE(over_stock_return_amount, 0) +
        COALESCE(damage_return_amount, 0),
    final_bill_amount = bill_amount - (
        COALESCE(expired_return_amount, 0) +
        COALESCE(near_expiry_return_amount, 0) +
        COALESCE(over_stock_return_amount, 0) +
        COALESCE(damage_return_amount, 0)
    )
WHERE 
    total_return_amount IS NULL 
    OR final_bill_amount IS NULL
    OR total_return_amount != (
        COALESCE(expired_return_amount, 0) +
        COALESCE(near_expiry_return_amount, 0) +
        COALESCE(over_stock_return_amount, 0) +
        COALESCE(damage_return_amount, 0)
    )
    OR final_bill_amount != (bill_amount - (
        COALESCE(expired_return_amount, 0) +
        COALESCE(near_expiry_return_amount, 0) +
        COALESCE(over_stock_return_amount, 0) +
        COALESCE(damage_return_amount, 0)
    ));

-- Verify the trigger was created
DO 
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Receiving Calculations Trigger Created Successfully';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Function: calculate_receiving_amounts()';
    RAISE NOTICE '   → Automatically calculates total_return_amount';
    RAISE NOTICE '   → Automatically calculates final_bill_amount';
    RAISE NOTICE '   → Fires BEFORE INSERT or UPDATE on receiving_records';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Calculations:';
    RAISE NOTICE '   → total_return_amount = expired + near_expiry + over_stock + damage';
    RAISE NOTICE '   → final_bill_amount = bill_amount - total_return_amount';
    RAISE NOTICE '';
    RAISE NOTICE '✨ Existing records have been updated with calculated values';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END ;
