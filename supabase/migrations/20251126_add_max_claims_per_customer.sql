-- ================================================
-- ADD MAX CLAIMS PER CUSTOMER SUPPORT
-- Created: November 26, 2025
-- Description: Allow customers to claim multiple times per campaign
--              up to a configurable limit
-- ================================================

-- Step 1: Add max_claims_per_customer column to coupon_campaigns
ALTER TABLE coupon_campaigns 
ADD COLUMN IF NOT EXISTS max_claims_per_customer INTEGER DEFAULT 1;

-- Add constraint to ensure positive values
ALTER TABLE coupon_campaigns
ADD CONSTRAINT valid_max_claims CHECK (max_claims_per_customer > 0);

-- Step 2: Drop the unique constraint on coupon_claims
-- This allows multiple claims per customer per campaign
ALTER TABLE coupon_claims
DROP CONSTRAINT IF EXISTS unique_customer_claim;

-- Step 3: Create index for efficient claim counting
CREATE INDEX IF NOT EXISTS idx_coupon_claims_customer_campaign 
ON coupon_claims(campaign_id, customer_mobile);

-- Step 4: Update validate_coupon_eligibility function
CREATE OR REPLACE FUNCTION validate_coupon_eligibility(
  p_campaign_code VARCHAR,
  p_mobile_number VARCHAR
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_campaign_id UUID;
  v_campaign_name VARCHAR;
  v_is_active BOOLEAN;
  v_validity_start TIMESTAMP WITH TIME ZONE;
  v_validity_end TIMESTAMP WITH TIME ZONE;
  v_max_claims_per_customer INTEGER;
  v_is_eligible BOOLEAN;
  v_current_claim_count INTEGER;
BEGIN
  -- Get campaign details
  SELECT 
    id, 
    campaign_name, 
    is_active,
    validity_start_date,
    validity_end_date,
    COALESCE(max_claims_per_customer, 1)
  INTO 
    v_campaign_id,
    v_campaign_name,
    v_is_active,
    v_validity_start,
    v_validity_end,
    v_max_claims_per_customer
  FROM coupon_campaigns
  WHERE campaign_code = p_campaign_code
    AND deleted_at IS NULL;
  
  -- Check if campaign exists
  IF v_campaign_id IS NULL THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'error_message', 'Campaign code not found'
    );
  END IF;
  
  -- Check if campaign is active
  IF NOT v_is_active THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'error_message', 'Campaign is not active'
    );
  END IF;
  
  -- Check if within validity period
  IF now() < v_validity_start OR now() > v_validity_end THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'error_message', 'Campaign is not valid at this time'
    );
  END IF;
  
  -- Check if customer is in eligible list
  SELECT EXISTS(
    SELECT 1 
    FROM coupon_eligible_customers
    WHERE campaign_id = v_campaign_id
      AND mobile_number = p_mobile_number
  ) INTO v_is_eligible;
  
  IF NOT v_is_eligible THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'error_message', 'Customer is not eligible for this campaign'
    );
  END IF;
  
  -- Count current claims
  SELECT COUNT(*)
  INTO v_current_claim_count
  FROM coupon_claims
  WHERE campaign_id = v_campaign_id
    AND customer_mobile = p_mobile_number;
  
  -- Check if reached maximum claims
  IF v_current_claim_count >= v_max_claims_per_customer THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'already_claimed', true,
      'current_claims', v_current_claim_count,
      'max_claims', v_max_claims_per_customer,
      'error_message', 'Customer has reached the maximum number of claims (' || v_current_claim_count || '/' || v_max_claims_per_customer || ')'
    );
  END IF;
  
  -- All checks passed
  RETURN jsonb_build_object(
    'eligible', true,
    'campaign_id', v_campaign_id,
    'campaign_name', v_campaign_name,
    'already_claimed', false,
    'current_claims', v_current_claim_count,
    'max_claims', v_max_claims_per_customer,
    'remaining_claims', v_max_claims_per_customer - v_current_claim_count
  );
END;
$$;

-- Step 5: Update claim_coupon function to check claim limit
CREATE OR REPLACE FUNCTION claim_coupon(
  p_campaign_id UUID,
  p_mobile_number VARCHAR,
  p_product_id UUID,
  p_branch_id BIGINT,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_claim_id UUID;
  v_product_details JSONB;
  v_stock_remaining INTEGER;
  v_max_claims_per_customer INTEGER;
  v_current_claim_count INTEGER;
BEGIN
  -- Get max claims per customer for this campaign
  SELECT COALESCE(max_claims_per_customer, 1)
  INTO v_max_claims_per_customer
  FROM coupon_campaigns
  WHERE id = p_campaign_id;
  
  -- Count current claims
  SELECT COUNT(*)
  INTO v_current_claim_count
  FROM coupon_claims
  WHERE campaign_id = p_campaign_id
    AND customer_mobile = p_mobile_number;
  
  -- Check if reached maximum claims
  IF v_current_claim_count >= v_max_claims_per_customer THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_message', 'Customer has already claimed ' || v_current_claim_count || ' time(s). Maximum allowed: ' || v_max_claims_per_customer
    );
  END IF;
  
  -- Check product stock
  SELECT stock_remaining INTO v_stock_remaining
  FROM coupon_products
  WHERE id = p_product_id
    AND is_active = true
    AND deleted_at IS NULL
  FOR UPDATE;
  
  IF v_stock_remaining IS NULL OR v_stock_remaining <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_message', 'Product is out of stock'
    );
  END IF;
  
  -- Insert claim record
  INSERT INTO coupon_claims (
    campaign_id,
    customer_mobile,
    product_id,
    branch_id,
    claimed_by_user,
    validity_date,
    status
  ) VALUES (
    p_campaign_id,
    p_mobile_number,
    p_product_id,
    p_branch_id,
    p_user_id,
    CURRENT_DATE,
    'claimed'
  )
  RETURNING id INTO v_claim_id;
  
  -- Decrement stock
  UPDATE coupon_products
  SET 
    stock_remaining = stock_remaining - 1,
    updated_at = now()
  WHERE id = p_product_id;
  
  -- Get product details for receipt
  SELECT jsonb_build_object(
    'product_id', id,
    'product_name_en', product_name_en,
    'product_name_ar', product_name_ar,
    'product_image_url', product_image_url,
    'original_price', original_price,
    'offer_price', offer_price,
    'special_barcode', special_barcode,
    'savings', (original_price - offer_price)
  )
  INTO v_product_details
  FROM coupon_products
  WHERE id = p_product_id;
  
  -- Return success with details
  RETURN jsonb_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'product_details', v_product_details,
    'validity_date', CURRENT_DATE,
    'current_claims', v_current_claim_count + 1,
    'remaining_claims', v_max_claims_per_customer - v_current_claim_count - 1
  );
END;
$$;

-- Step 6: Update get_campaign_statistics to include claim limit info
CREATE OR REPLACE FUNCTION get_campaign_statistics(
  p_campaign_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_stats JSONB;
  v_products JSONB;
  v_max_claims INTEGER;
BEGIN
  -- Get campaign max claims
  SELECT COALESCE(max_claims_per_customer, 1)
  INTO v_max_claims
  FROM coupon_campaigns
  WHERE id = p_campaign_id;
  
  -- Get overall campaign stats
  SELECT jsonb_build_object(
    'max_claims_per_customer', v_max_claims,
    'total_eligible_customers', (
      SELECT COUNT(*) 
      FROM coupon_eligible_customers 
      WHERE campaign_id = p_campaign_id
    ),
    'total_claims', (
      SELECT COUNT(*) 
      FROM coupon_claims 
      WHERE campaign_id = p_campaign_id
    ),
    'unique_customers_claimed', (
      SELECT COUNT(DISTINCT customer_mobile)
      FROM coupon_claims
      WHERE campaign_id = p_campaign_id
    ),
    'remaining_potential_claims', (
      SELECT COUNT(*) * v_max_claims
      FROM coupon_eligible_customers ec
      WHERE ec.campaign_id = p_campaign_id
    ) - (
      SELECT COUNT(*)
      FROM coupon_claims
      WHERE campaign_id = p_campaign_id
    ),
    'total_stock_limit', (
      SELECT COALESCE(SUM(stock_limit), 0)
      FROM coupon_products
      WHERE campaign_id = p_campaign_id
        AND deleted_at IS NULL
    ),
    'total_stock_remaining', (
      SELECT COALESCE(SUM(stock_remaining), 0)
      FROM coupon_products
      WHERE campaign_id = p_campaign_id
        AND deleted_at IS NULL
    )
  ) INTO v_stats;
  
  -- Get per-product stats
  SELECT jsonb_agg(
    jsonb_build_object(
      'product_id', p.id,
      'product_name_en', p.product_name_en,
      'product_name_ar', p.product_name_ar,
      'stock_limit', p.stock_limit,
      'stock_remaining', p.stock_remaining,
      'claims_count', (
        SELECT COUNT(*) 
        FROM coupon_claims 
        WHERE product_id = p.id
      )
    )
  )
  INTO v_products
  FROM coupon_products p
  WHERE p.campaign_id = p_campaign_id
    AND p.deleted_at IS NULL;
  
  -- Combine and return
  RETURN v_stats || jsonb_build_object('products', COALESCE(v_products, '[]'::jsonb));
END;
$$;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Max Claims Per Customer feature added successfully!';
  RAISE NOTICE 'Updated tables: coupon_campaigns (added max_claims_per_customer column)';
  RAISE NOTICE 'Updated tables: coupon_claims (removed unique constraint)';
  RAISE NOTICE 'Updated functions: validate_coupon_eligibility, claim_coupon, get_campaign_statistics';
END $$;
