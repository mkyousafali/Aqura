-- Migration: Fix Order Stock Adjustment
-- Purpose: Automatically decrease product stock when order items are created
-- Date: 2024-12-13

BEGIN;

-- =============================================================================
-- STEP 1: Drop existing trigger if it exists
-- =============================================================================

DROP TRIGGER IF EXISTS trigger_adjust_product_stock ON order_items;
DROP FUNCTION IF EXISTS adjust_product_stock_on_order_insert();

-- =============================================================================
-- STEP 2: Create function to adjust product stock
-- =============================================================================

CREATE OR REPLACE FUNCTION public.adjust_product_stock_on_order_insert()
RETURNS TRIGGER AS $$
DECLARE
    current_quantity INTEGER;
BEGIN
    -- Validate that product_id exists
    IF NEW.product_id IS NULL THEN
        RAISE EXCEPTION 'product_id is required';
    END IF;

    -- Get current stock
    SELECT current_stock INTO current_quantity 
    FROM products 
    WHERE id = NEW.product_id;

    -- If product not found, raise error
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product with id % does not exist', NEW.product_id;
    END IF;

    -- Decrease stock
    UPDATE products 
    SET current_stock = current_stock - NEW.quantity,
        updated_at = NOW()
    WHERE id = NEW.product_id;

    RAISE NOTICE 'Product % stock decreased by %. New stock: %', 
        NEW.product_id, NEW.quantity, (current_quantity - NEW.quantity);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- STEP 3: Create trigger to call function when order items are inserted
-- =============================================================================

CREATE TRIGGER trigger_adjust_product_stock
BEFORE INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION adjust_product_stock_on_order_insert();

COMMIT;

-- =============================================================================
-- STEP 4: Verify the trigger was created
-- =============================================================================

-- Run these queries to verify:
-- SELECT * FROM pg_trigger WHERE tgname = 'trigger_adjust_product_stock';
-- SELECT proname FROM pg_proc WHERE proname = 'adjust_product_stock_on_order_insert';
