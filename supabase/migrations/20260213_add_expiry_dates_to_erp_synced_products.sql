-- Add expiry_dates JSONB column to erp_synced_products
-- Stores per-branch expiry dates as JSON array:
-- [{"branch_id": 5, "erp_branch_id": 4, "expiry_date": "2026-04-30"}, ...]
ALTER TABLE public.erp_synced_products
ADD COLUMN IF NOT EXISTS expiry_dates jsonb NULL DEFAULT '[]'::jsonb;

-- Index for GIN queries on expiry_dates
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_expiry_dates
ON public.erp_synced_products USING gin (expiry_dates);

-- RPC function: upsert products with expiry date merge
-- When syncing from a branch, this merges the new branch's expiry entries
-- into existing ones without wiping other branches' data.
CREATE OR REPLACE FUNCTION upsert_erp_products_with_expiry(
  p_products jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted int := 0;
  v_updated int := 0;
  v_product jsonb;
  v_existing_expiry jsonb;
  v_new_expiry jsonb;
  v_merged_expiry jsonb;
  v_branch_id bigint;
BEGIN
  FOR v_product IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    v_new_expiry := COALESCE(v_product->'expiry_dates', '[]'::jsonb);
    
    -- Try to get existing record
    SELECT expiry_dates INTO v_existing_expiry
    FROM erp_synced_products
    WHERE barcode = v_product->>'barcode';
    
    IF v_existing_expiry IS NOT NULL THEN
      -- Record exists - merge expiry dates
      -- Remove entries for the same branch_id(s) we're inserting, then append new ones
      v_merged_expiry := COALESCE(v_existing_expiry, '[]'::jsonb);
      
      FOR v_branch_id IN SELECT (elem->>'branch_id')::bigint FROM jsonb_array_elements(v_new_expiry) AS elem
      LOOP
        -- Remove existing entry for this branch_id
        SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
        INTO v_merged_expiry
        FROM jsonb_array_elements(v_merged_expiry) AS elem
        WHERE (elem->>'branch_id')::bigint != v_branch_id;
      END LOOP;
      
      -- Append new entries
      v_merged_expiry := v_merged_expiry || v_new_expiry;
      
      UPDATE erp_synced_products
      SET 
        auto_barcode = COALESCE(v_product->>'auto_barcode', auto_barcode),
        parent_barcode = COALESCE(v_product->>'parent_barcode', parent_barcode),
        product_name_en = COALESCE(v_product->>'product_name_en', product_name_en),
        product_name_ar = COALESCE(v_product->>'product_name_ar', product_name_ar),
        unit_name = COALESCE(v_product->>'unit_name', unit_name),
        unit_qty = COALESCE((v_product->>'unit_qty')::numeric, unit_qty),
        is_base_unit = COALESCE((v_product->>'is_base_unit')::boolean, is_base_unit),
        expiry_dates = v_merged_expiry,
        synced_at = NOW()
      WHERE barcode = v_product->>'barcode';
      
      v_updated := v_updated + 1;
    ELSE
      -- New record - insert
      INSERT INTO erp_synced_products (
        barcode, auto_barcode, parent_barcode, 
        product_name_en, product_name_ar,
        unit_name, unit_qty, is_base_unit, expiry_dates
      ) VALUES (
        v_product->>'barcode',
        v_product->>'auto_barcode',
        v_product->>'parent_barcode',
        v_product->>'product_name_en',
        v_product->>'product_name_ar',
        v_product->>'unit_name',
        COALESCE((v_product->>'unit_qty')::numeric, 1),
        COALESCE((v_product->>'is_base_unit')::boolean, false),
        v_new_expiry
      );
      
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;
  
  RETURN jsonb_build_object(
    'inserted', v_inserted,
    'updated', v_updated
  );
END;
$$;
