-- Add new columns to purchase_voucher_items table

-- Add stock_location column (branch id) - branches.id is bigint
ALTER TABLE purchase_voucher_items
ADD COLUMN IF NOT EXISTS stock_location BIGINT REFERENCES branches(id);

-- Add stock_person column (user who manages stock)
ALTER TABLE purchase_voucher_items
ADD COLUMN IF NOT EXISTS stock_person UUID REFERENCES users(id);

-- Add issued_to column (customer or recipient)
ALTER TABLE purchase_voucher_items
ADD COLUMN IF NOT EXISTS issued_to UUID REFERENCES customers(id);

-- Add issued_by column (user who issued the voucher)
ALTER TABLE purchase_voucher_items
ADD COLUMN IF NOT EXISTS issued_by UUID REFERENCES users(id);

-- Create indexes for foreign keys
CREATE INDEX IF NOT EXISTS idx_pvi_stock_location ON purchase_voucher_items(stock_location);
CREATE INDEX IF NOT EXISTS idx_pvi_stock_person ON purchase_voucher_items(stock_person);
CREATE INDEX IF NOT EXISTS idx_pvi_issued_to ON purchase_voucher_items(issued_to);
CREATE INDEX IF NOT EXISTS idx_pvi_issued_by ON purchase_voucher_items(issued_by);
