-- Add food allowance columns to hr_basic_salary table
ALTER TABLE hr_basic_salary
ADD COLUMN IF NOT EXISTS food_allowance DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS food_payment_mode TEXT DEFAULT 'Bank' CHECK (food_payment_mode IN ('Bank', 'Cash'));

-- Add comment to explain the columns
COMMENT ON COLUMN hr_basic_salary.food_allowance IS 'Food allowance amount for the employee';
COMMENT ON COLUMN hr_basic_salary.food_payment_mode IS 'Payment mode for food allowance: Bank or Cash';
