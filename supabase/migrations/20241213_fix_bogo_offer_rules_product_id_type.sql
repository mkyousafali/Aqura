-- Migration: Fix bogo_offer_rules table schema
-- Purpose: Change buy_product_id and get_product_id column types from UUID to VARCHAR
-- Date: 2024-12-13

BEGIN;

-- Drop the foreign key constraints
ALTER TABLE bogo_offer_rules
DROP CONSTRAINT IF EXISTS bogo_offer_rules_buy_product_id_fkey;

ALTER TABLE bogo_offer_rules
DROP CONSTRAINT IF EXISTS bogo_offer_rules_get_product_id_fkey;

-- Change buy_product_id column type from UUID to VARCHAR
ALTER TABLE bogo_offer_rules
ALTER COLUMN buy_product_id TYPE character varying(50);

-- Change get_product_id column type from UUID to VARCHAR
ALTER TABLE bogo_offer_rules
ALTER COLUMN get_product_id TYPE character varying(50);

-- Recreate the foreign key constraints
ALTER TABLE bogo_offer_rules
ADD CONSTRAINT bogo_offer_rules_buy_product_id_fkey 
FOREIGN KEY (buy_product_id) REFERENCES products(id) ON DELETE CASCADE;

ALTER TABLE bogo_offer_rules
ADD CONSTRAINT bogo_offer_rules_get_product_id_fkey 
FOREIGN KEY (get_product_id) REFERENCES products(id) ON DELETE CASCADE;

-- Drop and recreate indexes
DROP INDEX IF EXISTS idx_bogo_offer_rules_buy_product_id;
DROP INDEX IF EXISTS idx_bogo_offer_rules_get_product_id;

CREATE INDEX idx_bogo_offer_rules_buy_product_id ON public.bogo_offer_rules USING btree (buy_product_id);
CREATE INDEX idx_bogo_offer_rules_get_product_id ON public.bogo_offer_rules USING btree (get_product_id);

-- Verify the changes
DO $$
DECLARE
    col_type_buy TEXT;
    col_type_get TEXT;
BEGIN
    SELECT data_type INTO col_type_buy
    FROM information_schema.columns
    WHERE table_name = 'bogo_offer_rules' AND column_name = 'buy_product_id';
    
    SELECT data_type INTO col_type_get
    FROM information_schema.columns
    WHERE table_name = 'bogo_offer_rules' AND column_name = 'get_product_id';
    
    RAISE NOTICE 'bogo_offer_rules.buy_product_id column type: %', col_type_buy;
    RAISE NOTICE 'bogo_offer_rules.get_product_id column type: %', col_type_get;
END $$;

COMMIT;
