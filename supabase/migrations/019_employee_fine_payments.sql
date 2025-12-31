-- Employee Fine Payments Table Schema
CREATE TABLE IF NOT EXISTS employee_fine_payments (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  warning_id UUID,
  payment_method VARCHAR,
  payment_amount NUMERIC NOT NULL,
  payment_currency VARCHAR DEFAULT 'USD',
  payment_date TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  payment_reference VARCHAR,
  payment_notes TEXT,
  processed_by UUID,
  processed_by_username VARCHAR,
  account_code VARCHAR,
  transaction_id VARCHAR,
  receipt_number VARCHAR,
  created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
