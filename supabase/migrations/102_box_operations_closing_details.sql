-- =============================================
-- BOX OPERATIONS - ADD CLOSING DETAILS
-- Created: 2026-01-05
-- Description: Add fields to store closing box details
-- =============================================

ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_details JSONB;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS supervisor_verified_at TIMESTAMPTZ;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS supervisor_id UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_start_date DATE;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_start_time TIME;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_end_date DATE;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_end_time TIME;

-- Recharge cards details
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS recharge_opening_balance DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS recharge_close_balance DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS recharge_sales DECIMAL(15, 2);

-- Bank reconciliation
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS bank_mada DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS bank_visa DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS bank_mastercard DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS bank_google_pay DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS bank_other DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS bank_total DECIMAL(15, 2);

-- ERP closing details
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS system_cash_sales DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS system_card_sales DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS system_return DECIMAL(15, 2);

-- Differences
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS difference_cash_sales DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS difference_card_sales DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS total_difference DECIMAL(15, 2);

-- Closing cash breakdown
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_total DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_500 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_200 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_100 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_50 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_20 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_10 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_5 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_2 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_1 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_050 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_cash_025 INT;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS closing_coins INT;

-- Cash sales vs per closing count
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS total_cash_sales DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS cash_sales_per_count DECIMAL(15, 2);

-- Vouchers
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS vouchers_total DECIMAL(15, 2);

-- ERP closing summary
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS total_erp_cash_sales DECIMAL(15, 2);
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS total_erp_sales DECIMAL(15, 2);

-- Suspense details
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS suspense_paid JSONB;
ALTER TABLE box_operations ADD COLUMN IF NOT EXISTS suspense_received JSONB;

COMMENT ON TABLE box_operations IS 'Stores complete box closing operation details including cash counts, bank reconciliation, ERP comparison, and supervisor verification';
COMMENT ON COLUMN box_operations.closing_details IS 'JSON containing all closing form data';
COMMENT ON COLUMN box_operations.supervisor_verified_at IS 'Timestamp when supervisor code was verified';
COMMENT ON COLUMN box_operations.supervisor_id IS 'ID of supervisor who verified the closing';
COMMENT ON COLUMN box_operations.difference_cash_sales IS 'Difference between total cash sales and system cash sales';
COMMENT ON COLUMN box_operations.difference_card_sales IS 'Difference between bank total and system card sales';
COMMENT ON COLUMN box_operations.total_difference IS 'Total of cash and card differences';
