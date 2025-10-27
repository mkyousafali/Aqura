-- Create vendors table
CREATE TABLE IF NOT EXISTS public.vendors (
  erp_vendor_id INTEGER NOT NULL,
  vendor_name TEXT NOT NULL,
  salesman_name TEXT,
  salesman_contact TEXT,
  supervisor_name TEXT,
  supervisor_contact TEXT,
  vendor_contact_number TEXT,
  payment_method TEXT,
  credit_period INTEGER,
  bank_name TEXT,
  iban TEXT,
  status TEXT DEFAULT 'Active',
  last_visit TIMESTAMP,
  categories TEXT[],
  delivery_modes TEXT[],
  place TEXT,
  location_link TEXT,
  return_expired_products TEXT,
  return_expired_products_note TEXT,
  return_near_expiry_products TEXT,
  return_near_expiry_products_note TEXT,
  return_over_stock TEXT,
  return_over_stock_note TEXT,
  return_damage_products TEXT,
  return_damage_products_note TEXT,
  no_return BOOLEAN DEFAULT false,
  no_return_note TEXT,
  vat_applicable TEXT DEFAULT 'VAT Applicable',
  vat_number TEXT,
  no_vat_note TEXT,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  branch_id BIGINT NOT NULL
);

-- Indexes for vendors
CREATE INDEX IF NOT EXISTS idx_vendors_erp_vendor_id ON public.vendors(erp_vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendors_branch_id ON public.vendors(branch_id);
CREATE INDEX IF NOT EXISTS idx_vendors_created_at ON public.vendors(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
