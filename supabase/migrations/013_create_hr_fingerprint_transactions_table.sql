-- Create hr_fingerprint_transactions table
CREATE TABLE IF NOT EXISTS public.hr_fingerprint_transactions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  employee_id VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  branch_id BIGINT NOT NULL,
  transaction_date DATE NOT NULL,
  transaction_time TIME NOT NULL,
  punch_state VARCHAR(255) NOT NULL,
  device_id VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for hr_fingerprint_transactions
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_transactions_employee_id ON public.hr_fingerprint_transactions(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_transactions_branch_id ON public.hr_fingerprint_transactions(branch_id);
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_transactions_device_id ON public.hr_fingerprint_transactions(device_id);
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_transactions_created_at ON public.hr_fingerprint_transactions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_fingerprint_transactions ENABLE ROW LEVEL SECURITY;
