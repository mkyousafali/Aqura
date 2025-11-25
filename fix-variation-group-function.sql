-- Fix create_variation_group function to set parent_product_barcode for parent product
-- This ensures that queries for variations include the parent product itself

CREATE OR REPLACE FUNCTION create_variation_group(
  p_parent_barcode TEXT,
  p_variation_barcodes TEXT[],
  p_group_name_en TEXT,
  p_group_name_ar TEXT,
  p_image_override TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  affected_count INTEGER
) AS $$
DECLARE
  v_affected_count INTEGER := 0;
  v_barcode TEXT;
  v_order INTEGER := 1;
BEGIN
  -- Validate parent product exists
  IF NOT EXISTS (SELECT 1 FROM flyer_products WHERE barcode = p_parent_barcode) THEN
    RETURN QUERY SELECT false, 'Parent product barcode does not exist', 0;
    RETURN;
  END IF;

  -- Validate no circular references
  IF p_parent_barcode = ANY(p_variation_barcodes) THEN
    -- Remove parent from variations array if present
    p_variation_barcodes := array_remove(p_variation_barcodes, p_parent_barcode);
  END IF;

  -- Update parent product (FIXED: set parent_product_barcode to itself for query consistency)
  UPDATE flyer_products
  SET 
    is_variation = true,
    parent_product_barcode = p_parent_barcode,  -- Parent references itself
    variation_group_name_en = p_group_name_en,
    variation_group_name_ar = p_group_name_ar,
    variation_order = 0,
    variation_image_override = p_image_override,
    created_by = COALESCE(p_user_id, created_by),
    modified_by = p_user_id,
    modified_at = NOW()
  WHERE barcode = p_parent_barcode;

  v_affected_count := v_affected_count + 1;

  -- Update variation products
  FOREACH v_barcode IN ARRAY p_variation_barcodes
  LOOP
    UPDATE flyer_products
    SET 
      is_variation = true,
      parent_product_barcode = p_parent_barcode,
      variation_group_name_en = p_group_name_en,
      variation_group_name_ar = p_group_name_ar,
      variation_order = v_order,
      created_by = COALESCE(p_user_id, created_by),
      modified_by = p_user_id,
      modified_at = NOW()
    WHERE barcode = v_barcode;

    v_order := v_order + 1;
    v_affected_count := v_affected_count + 1;
  END LOOP;

  -- Log to audit trail
  INSERT INTO variation_audit_log (
    action_type,
    affected_barcodes,
    parent_barcode,
    group_name_en,
    group_name_ar,
    user_id,
    details
  ) VALUES (
    'create_group',
    array_prepend(p_parent_barcode, p_variation_barcodes),
    p_parent_barcode,
    p_group_name_en,
    p_group_name_ar,
    p_user_id,
    jsonb_build_object(
      'image_override', p_image_override,
      'variation_count', array_length(p_variation_barcodes, 1) + 1
    )
  );

  RETURN QUERY SELECT true, 'Variation group created successfully', v_affected_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_variation_group IS 'Creates a new variation group with parent and child products. Parent references itself for query consistency.';
