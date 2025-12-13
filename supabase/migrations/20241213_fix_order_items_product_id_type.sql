-- Migration: Fix order_items column types to match products table
-- Purpose: Change product_id and unit_id from UUID to VARCHAR to match products table column types
-- Date: 2024-12-13

BEGIN;

-- Drop the foreign key constraints first
ALTER TABLE order_items
DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;

-- Change product_id column type from UUID to VARCHAR
ALTER TABLE order_items
ALTER COLUMN product_id TYPE character varying(50);

-- Change unit_id column type from UUID to VARCHAR
ALTER TABLE order_items
ALTER COLUMN unit_id TYPE character varying(50);

-- Recreate the product_id foreign key constraint
ALTER TABLE order_items
ADD CONSTRAINT order_items_product_id_fkey 
FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT;

-- Recreate the unit_id foreign key constraint
ALTER TABLE order_items
ADD CONSTRAINT order_items_unit_id_fkey 
FOREIGN KEY (unit_id) REFERENCES product_units(id) ON DELETE SET NULL;

-- Update the indexes if needed
DROP INDEX IF EXISTS idx_order_items_product_id;
CREATE INDEX idx_order_items_product_id ON public.order_items USING btree (product_id);

DROP INDEX IF EXISTS idx_order_items_unit_id;
CREATE INDEX idx_order_items_unit_id ON public.order_items USING btree (unit_id);

COMMIT;
