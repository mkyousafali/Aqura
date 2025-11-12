-- Fix BOGO Constraint Issue
-- Purpose: Remove obsolete bogo_quantities_required constraint
-- Date: 2025-11-12

-- The old constraint requires bogo_buy_quantity and bogo_get_quantity to be NOT NULL
-- But we're now using the bogo_offer_rules table instead of these fields
-- So we need to remove this constraint

ALTER TABLE offers DROP CONSTRAINT IF EXISTS bogo_quantities_required;

-- Verify the constraint is removed
-- SELECT constraint_name FROM information_schema.table_constraints 
-- WHERE table_name = 'offers' AND constraint_name = 'bogo_quantities_required';
