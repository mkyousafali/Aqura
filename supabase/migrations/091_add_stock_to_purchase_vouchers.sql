-- Add stock column to purchase_voucher_items (if not exists)
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'purchase_voucher_items' AND column_name = 'stock'
  ) THEN 
    ALTER TABLE purchase_voucher_items ADD COLUMN stock INTEGER DEFAULT 1;
  END IF;
END $$;

-- Add issue_type column to purchase_voucher_items (if not exists)
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'purchase_voucher_items' AND column_name = 'issue_type'
  ) THEN 
    ALTER TABLE purchase_voucher_items ADD COLUMN issue_type VARCHAR DEFAULT 'sales';
  END IF;
END $$;

-- Update status default from 'issued' to 'stocked'
ALTER TABLE purchase_voucher_items 
ALTER COLUMN status SET DEFAULT 'stocked';

-- Update existing records with status='issued' to 'stocked'
UPDATE purchase_voucher_items 
SET status = 'stocked' 
WHERE status = 'issued';
