-- Create receiving_records table
CREATE TABLE IF NOT EXISTS public.receiving_records (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  branch_id INTEGER NOT NULL,
  vendor_id INTEGER NOT NULL,
  bill_date DATE NOT NULL,
  bill_amount NUMERIC NOT NULL,
  bill_number VARCHAR(255),
  payment_method VARCHAR(255),
  credit_period INTEGER,
  due_date DATE,
  bank_name VARCHAR(255),
  iban VARCHAR(255),
  vendor_vat_number VARCHAR(255),
  bill_vat_number VARCHAR(255),
  vat_numbers_match BOOLEAN,
  vat_mismatch_reason TEXT,
  branch_manager_user_id UUID,
  shelf_stocker_user_ids TEXT[] DEFAULT '{}',
  accountant_user_id UUID,
  purchasing_manager_user_id UUID,
  expired_return_amount NUMERIC DEFAULT 0,
  near_expiry_return_amount NUMERIC DEFAULT 0,
  over_stock_return_amount NUMERIC DEFAULT 0,
  damage_return_amount NUMERIC DEFAULT 0,
  total_return_amount NUMERIC DEFAULT 0,
  final_bill_amount NUMERIC DEFAULT 0,
  expired_erp_document_type VARCHAR(255),
  expired_erp_document_number VARCHAR(255),
  expired_vendor_document_number VARCHAR(255),
  near_expiry_erp_document_type VARCHAR(255),
  near_expiry_erp_document_number VARCHAR(255),
  near_expiry_vendor_document_number VARCHAR(255),
  over_stock_erp_document_type VARCHAR(255),
  over_stock_erp_document_number VARCHAR(255),
  over_stock_vendor_document_number VARCHAR(255),
  damage_erp_document_type VARCHAR(255),
  damage_erp_document_number VARCHAR(255),
  damage_vendor_document_number VARCHAR(255),
  has_expired_returns BOOLEAN DEFAULT false,
  has_near_expiry_returns BOOLEAN DEFAULT false,
  has_over_stock_returns BOOLEAN DEFAULT false,
  has_damage_returns BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  inventory_manager_user_id UUID,
  night_supervisor_user_ids TEXT[] DEFAULT '{}',
  warehouse_handler_user_ids TEXT[] DEFAULT '{}',
  certificate_url TEXT,
  certificate_generated_at TIMESTAMPTZ,
  certificate_file_name TEXT,
  original_bill_url TEXT,
  erp_purchase_invoice_reference VARCHAR(255),
  updated_at TIMESTAMPTZ DEFAULT now(),
  pr_excel_file_url TEXT,
  PRIMARY KEY (id)
);

-- Indexes for receiving_records
CREATE INDEX IF NOT EXISTS idx_receiving_records_user_id ON public.receiving_records(user_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_branch_id ON public.receiving_records(branch_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_vendor_id ON public.receiving_records(vendor_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_branch_manager_user_id ON public.receiving_records(branch_manager_user_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_accountant_user_id ON public.receiving_records(accountant_user_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_purchasing_manager_user_id ON public.receiving_records(purchasing_manager_user_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_inventory_manager_user_id ON public.receiving_records(inventory_manager_user_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_created_at ON public.receiving_records(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.receiving_records ENABLE ROW LEVEL SECURITY;
