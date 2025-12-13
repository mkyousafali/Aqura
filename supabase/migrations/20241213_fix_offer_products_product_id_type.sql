-- Migration: Fix offer_products table schema
-- Purpose: Change product_id column type from UUID to VARCHAR to match products table
-- Date: 2024-12-13

BEGIN;

-- Drop the foreign key constraint
ALTER TABLE offer_products
DROP CONSTRAINT IF EXISTS offer_products_product_id_fkey;

-- Change product_id column type from UUID to VARCHAR
ALTER TABLE offer_products
ALTER COLUMN product_id TYPE character varying(50);

-- Recreate the product_id foreign key constraint
ALTER TABLE offer_products
ADD CONSTRAINT offer_products_product_id_fkey 
FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;

-- Drop and recreate the index
DROP INDEX IF EXISTS idx_offer_products_product_id;
CREATE INDEX idx_offer_products_product_id ON public.offer_products USING btree (product_id);

-- Verify the change
DO $$
DECLARE
    col_type TEXT;
BEGIN
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_name = 'offer_products' AND column_name = 'product_id';
    
    RAISE NOTICE 'offer_products.product_id column type: %', col_type;
END $$;

COMMIT;
