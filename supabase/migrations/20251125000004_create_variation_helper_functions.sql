-- Migration 4: Create Helper Functions for Variation Management
-- This migration creates database functions for common variation queries

-- Function 1: Get all variations in a product group
CREATE OR REPLACE FUNCTION get_product_variations(p_barcode TEXT)
RETURNS TABLE (
  id UUID,
  barcode TEXT,
  product_name_en TEXT,
  product_name_ar TEXT,
  unit_name TEXT,
  image_url TEXT,
  variation_order INTEGER,
  is_parent BOOLEAN,
  parent_barcode TEXT,
  group_name_en TEXT,
  group_name_ar TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH target_product AS (
    SELECT 
      COALESCE(fp.parent_product_barcode, fp.barcode) as parent_ref
    FROM flyer_products fp
    WHERE fp.barcode = p_barcode
  )
  SELECT 
    fp.id,
    fp.barcode,
    fp.product_name_en,
    fp.product_name_ar,
    fp.unit_name,
    fp.image_url,
    fp.variation_order,
    (fp.barcode = (SELECT parent_ref FROM target_product)) as is_parent,
    fp.parent_product_barcode as parent_barcode,
    fp.variation_group_name_en as group_name_en,
    fp.variation_group_name_ar as group_name_ar
  FROM flyer_products fp
  WHERE fp.is_variation = true
    AND (fp.parent_product_barcode = (SELECT parent_ref FROM target_product)
         OR fp.barcode = (SELECT parent_ref FROM target_product))
  ORDER BY fp.variation_order ASC, fp.product_name_en ASC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_product_variations IS 'Returns all products in the same variation group as the given barcode';

-- Function 2: Get variation group info summary
CREATE OR REPLACE FUNCTION get_variation_group_info(p_barcode TEXT)
RETURNS TABLE (
  parent_barcode TEXT,
  group_name_en TEXT,
  group_name_ar TEXT,
  total_variations INTEGER,
  variation_image_override TEXT,
  created_by UUID,
  modified_by UUID,
  modified_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  WITH parent_info AS (
    SELECT 
      COALESCE(fp.parent_product_barcode, fp.barcode) as parent_ref
    FROM flyer_products fp
    WHERE fp.barcode = p_barcode
  )
  SELECT 
    parent.barcode as parent_barcode,
    parent.variation_group_name_en as group_name_en,
    parent.variation_group_name_ar as group_name_ar,
    COUNT(DISTINCT variations.barcode)::INTEGER as total_variations,
    parent.variation_image_override,
    parent.created_by,
    parent.modified_by,
    parent.modified_at
  FROM flyer_products parent
  LEFT JOIN flyer_products variations 
    ON variations.parent_product_barcode = parent.barcode 
    OR variations.barcode = parent.barcode
  WHERE parent.barcode = (SELECT parent_ref FROM parent_info)
    AND parent.is_variation = true
  GROUP BY 
    parent.barcode,
    parent.variation_group_name_en,
    parent.variation_group_name_ar,
    parent.variation_image_override,
    parent.created_by,
    parent.modified_by,
    parent.modified_at;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_variation_group_info IS 'Returns summary information about a variation group';

-- Function 3: Validate variation prices in an offer
CREATE OR REPLACE FUNCTION validate_variation_prices(p_offer_id INTEGER, p_group_id UUID)
RETURNS TABLE (
  barcode TEXT,
  product_name_en TEXT,
  offer_price NUMERIC,
  offer_percentage NUMERIC,
  price_mismatch BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  WITH group_prices AS (
    SELECT 
      op.offer_price,
      op.offer_percentage,
      COUNT(DISTINCT op.offer_price) OVER () as price_count,
      COUNT(DISTINCT op.offer_percentage) OVER () as percentage_count
    FROM offer_products op
    WHERE op.offer_id = p_offer_id
      AND op.variation_group_id = p_group_id
    LIMIT 1
  )
  SELECT 
    fp.barcode,
    fp.product_name_en,
    op.offer_price,
    op.offer_percentage,
    CASE 
      WHEN gp.price_count > 1 OR gp.percentage_count > 1 THEN true
      ELSE false
    END as price_mismatch
  FROM offer_products op
  JOIN flyer_products fp ON op.product_id = fp.id
  CROSS JOIN group_prices gp
  WHERE op.offer_id = p_offer_id
    AND op.variation_group_id = p_group_id
  ORDER BY fp.variation_order, fp.product_name_en;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION validate_variation_prices IS 'Checks if all variations in a group have matching prices within an offer';

-- Function 4: Get offer variation summary
CREATE OR REPLACE FUNCTION get_offer_variation_summary(p_offer_id INTEGER)
RETURNS TABLE (
  variation_group_id UUID,
  parent_barcode TEXT,
  group_name_en TEXT,
  group_name_ar TEXT,
  selected_count INTEGER,
  total_count INTEGER,
  has_price_mismatch BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  WITH variation_groups AS (
    SELECT DISTINCT 
      op.variation_group_id,
      op.variation_parent_barcode
    FROM offer_products op
    WHERE op.offer_id = p_offer_id
      AND op.is_part_of_variation_group = true
      AND op.variation_group_id IS NOT NULL
  ),
  selected_variations AS (
    SELECT 
      op.variation_group_id,
      COUNT(DISTINCT op.product_id) as selected_count,
      COUNT(DISTINCT op.offer_price) as price_count,
      COUNT(DISTINCT op.offer_percentage) as percentage_count
    FROM offer_products op
    WHERE op.offer_id = p_offer_id
      AND op.variation_group_id IS NOT NULL
    GROUP BY op.variation_group_id
  ),
  total_variations AS (
    SELECT 
      vg.variation_group_id,
      COUNT(DISTINCT fp.id) as total_count
    FROM variation_groups vg
    JOIN flyer_products fp ON fp.parent_product_barcode = vg.variation_parent_barcode
      OR fp.barcode = vg.variation_parent_barcode
    WHERE fp.is_variation = true
    GROUP BY vg.variation_group_id
  )
  SELECT 
    vg.variation_group_id,
    vg.variation_parent_barcode as parent_barcode,
    fp.variation_group_name_en as group_name_en,
    fp.variation_group_name_ar as group_name_ar,
    sv.selected_count::INTEGER,
    tv.total_count::INTEGER,
    CASE 
      WHEN sv.price_count > 1 OR sv.percentage_count > 1 THEN true
      ELSE false
    END as has_price_mismatch
  FROM variation_groups vg
  JOIN flyer_products fp ON fp.barcode = vg.variation_parent_barcode
  LEFT JOIN selected_variations sv ON sv.variation_group_id = vg.variation_group_id
  LEFT JOIN total_variations tv ON tv.variation_group_id = vg.variation_group_id
  ORDER BY fp.variation_group_name_en;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_offer_variation_summary IS 'Returns summary of all variation groups in an offer with selection status';

-- Function 5: Check for orphaned variations
CREATE OR REPLACE FUNCTION check_orphaned_variations()
RETURNS TABLE (
  barcode TEXT,
  product_name_en TEXT,
  product_name_ar TEXT,
  parent_product_barcode TEXT,
  reason TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fp.barcode,
    fp.product_name_en,
    fp.product_name_ar,
    fp.parent_product_barcode,
    CASE 
      WHEN fp.parent_product_barcode IS NOT NULL 
           AND NOT EXISTS (
             SELECT 1 FROM flyer_products parent 
             WHERE parent.barcode = fp.parent_product_barcode
           ) THEN 'Parent product does not exist'
      WHEN fp.parent_product_barcode = fp.barcode THEN 'Self-referencing parent'
      ELSE 'Unknown issue'
    END as reason
  FROM flyer_products fp
  WHERE fp.is_variation = true
    AND (
      (fp.parent_product_barcode IS NOT NULL 
       AND NOT EXISTS (
         SELECT 1 FROM flyer_products parent 
         WHERE parent.barcode = fp.parent_product_barcode
       ))
      OR fp.parent_product_barcode = fp.barcode
    )
  ORDER BY fp.product_name_en;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION check_orphaned_variations IS 'Finds variation products with invalid parent references for cleanup';

-- Function 6: Create variation group (atomic operation)
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

  -- Update parent product (set parent_product_barcode to itself for query consistency)
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

COMMENT ON FUNCTION create_variation_group IS 'Creates a new variation group with parent and child products';
