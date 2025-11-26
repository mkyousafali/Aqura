-- ================================================
-- COUPON MANAGEMENT SYSTEM - COMPLETE MIGRATION
-- Created: November 26, 2025
-- Description: Campaign-based coupon system with customer eligibility,
--              random product selection, and thermal receipt printing
-- ================================================

-- ================================================
-- SECTION 1: CREATE TABLES
-- ================================================

-- 1. COUPON CAMPAIGNS TABLE
-- Stores promotional campaign configurations
CREATE TABLE IF NOT EXISTS coupon_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_name VARCHAR(255) NOT NULL,
  campaign_code VARCHAR(50) UNIQUE NOT NULL,
  description TEXT,
  validity_start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  validity_end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  terms_conditions_en TEXT,
  terms_conditions_ar TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  
  CONSTRAINT valid_campaign_dates CHECK (validity_end_date > validity_start_date)
);

-- 2. COUPON ELIGIBLE CUSTOMERS TABLE
-- Tracks which customers are eligible for each campaign
CREATE TABLE IF NOT EXISTS coupon_eligible_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES coupon_campaigns(id) ON DELETE CASCADE NOT NULL,
  mobile_number VARCHAR(20) NOT NULL,
  customer_name VARCHAR(255),
  import_batch_id UUID,
  imported_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  imported_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  CONSTRAINT unique_customer_campaign UNIQUE(campaign_id, mobile_number)
);

-- 3. COUPON PRODUCTS TABLE
-- Products available as gifts with stock control
CREATE TABLE IF NOT EXISTS coupon_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES coupon_campaigns(id) ON DELETE CASCADE NOT NULL,
  product_name_en VARCHAR(255) NOT NULL,
  product_name_ar VARCHAR(255) NOT NULL,
  product_image_url TEXT,
  original_price DECIMAL(10, 2) NOT NULL,
  offer_price DECIMAL(10, 2) NOT NULL,
  special_barcode VARCHAR(50) UNIQUE NOT NULL,
  stock_limit INTEGER NOT NULL DEFAULT 0,
  stock_remaining INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  
  CONSTRAINT valid_stock CHECK (stock_remaining >= 0 AND stock_remaining <= stock_limit),
  CONSTRAINT valid_price CHECK (offer_price >= 0 AND original_price >= offer_price)
);

-- 4. COUPON CLAIMS TABLE
-- Audit trail of all coupon redemptions (immutable)
CREATE TABLE IF NOT EXISTS coupon_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES coupon_campaigns(id) ON DELETE CASCADE NOT NULL,
  customer_mobile VARCHAR(20) NOT NULL,
  product_id UUID REFERENCES coupon_products(id) ON DELETE SET NULL,
  branch_id BIGINT REFERENCES branches(id) ON DELETE SET NULL,
  claimed_by_user UUID REFERENCES users(id) ON DELETE SET NULL,
  claimed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  print_count INTEGER DEFAULT 1,
  barcode_scanned BOOLEAN DEFAULT false,
  validity_date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'claimed',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  CONSTRAINT unique_customer_claim UNIQUE(campaign_id, customer_mobile),
  CONSTRAINT valid_status CHECK (status IN ('claimed', 'redeemed', 'expired'))
);

-- ================================================
-- SECTION 2: CREATE INDEXES
-- ================================================

-- Campaign indexes
CREATE INDEX IF NOT EXISTS idx_campaigns_code ON coupon_campaigns(campaign_code);
CREATE INDEX IF NOT EXISTS idx_campaigns_active ON coupon_campaigns(is_active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_campaigns_validity ON coupon_campaigns(validity_start_date, validity_end_date);

-- Eligible customers indexes
CREATE INDEX IF NOT EXISTS idx_eligible_customers_mobile ON coupon_eligible_customers(mobile_number);
CREATE INDEX IF NOT EXISTS idx_eligible_customers_campaign ON coupon_eligible_customers(campaign_id);

-- Products indexes
CREATE INDEX IF NOT EXISTS idx_coupon_products_campaign ON coupon_products(campaign_id);
CREATE INDEX IF NOT EXISTS idx_coupon_products_barcode ON coupon_products(special_barcode);
CREATE INDEX IF NOT EXISTS idx_coupon_products_stock ON coupon_products(stock_remaining) WHERE is_active = true;

-- Claims indexes
CREATE INDEX IF NOT EXISTS idx_coupon_claims_mobile ON coupon_claims(customer_mobile);
CREATE INDEX IF NOT EXISTS idx_coupon_claims_campaign ON coupon_claims(campaign_id);
CREATE INDEX IF NOT EXISTS idx_coupon_claims_date ON coupon_claims(claimed_at);
CREATE INDEX IF NOT EXISTS idx_coupon_claims_product ON coupon_claims(product_id);
CREATE INDEX IF NOT EXISTS idx_coupon_claims_branch ON coupon_claims(branch_id);

-- ================================================
-- SECTION 3: CREATE STORAGE BUCKET
-- ================================================

-- Create storage bucket for product images (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('coupon-product-images', 'coupon-product-images', true)
ON CONFLICT (id) DO NOTHING;

-- ================================================
-- SECTION 4: DATABASE FUNCTIONS
-- ================================================

-- FUNCTION 1: Generate unique campaign code
CREATE OR REPLACE FUNCTION generate_campaign_code()
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
  new_code VARCHAR(8);
  code_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate 8 character alphanumeric code
    new_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));
    
    -- Check if code already exists
    SELECT EXISTS(SELECT 1 FROM coupon_campaigns WHERE campaign_code = new_code)
    INTO code_exists;
    
    EXIT WHEN NOT code_exists;
  END LOOP;
  
  RETURN new_code;
END;
$$;

-- FUNCTION 2: Validate coupon eligibility
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
  v_is_eligible BOOLEAN;
  v_already_claimed BOOLEAN;
BEGIN
  -- Get campaign details
  SELECT 
    id, 
    campaign_name, 
    is_active,
    validity_start_date,
    validity_end_date
  INTO 
    v_campaign_id,
    v_campaign_name,
    v_is_active,
    v_validity_start,
    v_validity_end
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
  
  -- Check if already claimed
  SELECT EXISTS(
    SELECT 1
    FROM coupon_claims
    WHERE campaign_id = v_campaign_id
      AND customer_mobile = p_mobile_number
  ) INTO v_already_claimed;
  
  IF v_already_claimed THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'already_claimed', true,
      'error_message', 'Customer has already claimed a gift from this campaign'
    );
  END IF;
  
  -- All checks passed
  RETURN jsonb_build_object(
    'eligible', true,
    'campaign_id', v_campaign_id,
    'campaign_name', v_campaign_name,
    'already_claimed', false
  );
END;
$$;

-- FUNCTION 3: Select random product with stock
CREATE OR REPLACE FUNCTION select_random_product(
  p_campaign_id UUID
)
RETURNS TABLE (
  id UUID,
  product_name_en VARCHAR,
  product_name_ar VARCHAR,
  product_image_url TEXT,
  original_price DECIMAL,
  offer_price DECIMAL,
  special_barcode VARCHAR,
  stock_remaining INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.product_name_en,
    p.product_name_ar,
    p.product_image_url,
    p.original_price,
    p.offer_price,
    p.special_barcode,
    p.stock_remaining
  FROM coupon_products p
  WHERE p.campaign_id = p_campaign_id
    AND p.is_active = true
    AND p.stock_remaining > 0
    AND p.deleted_at IS NULL
  ORDER BY RANDOM()
  LIMIT 1
  FOR UPDATE SKIP LOCKED;
END;
$$;

-- FUNCTION 4: Claim coupon (atomic transaction)
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
BEGIN
  -- Double-check eligibility (race condition protection)
  IF EXISTS(
    SELECT 1 
    FROM coupon_claims 
    WHERE campaign_id = p_campaign_id 
      AND customer_mobile = p_mobile_number
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_message', 'Customer has already claimed from this campaign'
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
    'validity_date', CURRENT_DATE
  );
END;
$$;

-- FUNCTION 5: Get campaign statistics
CREATE OR REPLACE FUNCTION get_campaign_statistics(
  p_campaign_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_stats JSONB;
  v_products JSONB;
BEGIN
  -- Get overall campaign stats
  SELECT jsonb_build_object(
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
    'remaining_claims', (
      SELECT COUNT(*) 
      FROM coupon_eligible_customers ec
      WHERE ec.campaign_id = p_campaign_id
        AND NOT EXISTS (
          SELECT 1 
          FROM coupon_claims cc 
          WHERE cc.campaign_id = p_campaign_id 
            AND cc.customer_mobile = ec.mobile_number
        )
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

-- ================================================
-- SECTION 5: TRIGGERS
-- ================================================

-- Trigger to update updated_at timestamp for campaigns
CREATE OR REPLACE FUNCTION update_coupon_campaigns_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_coupon_campaigns_updated_at
  BEFORE UPDATE ON coupon_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_coupon_campaigns_updated_at();

-- Trigger to update updated_at timestamp for products
CREATE OR REPLACE FUNCTION update_coupon_products_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_coupon_products_updated_at
  BEFORE UPDATE ON coupon_products
  FOR EACH ROW
  EXECUTE FUNCTION update_coupon_products_updated_at();

-- Trigger to prevent claim updates/deletes (immutable audit)
CREATE OR REPLACE FUNCTION prevent_coupon_claim_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Coupon claims cannot be modified or deleted (immutable audit trail)';
END;
$$;

CREATE TRIGGER trigger_prevent_coupon_claim_update
  BEFORE UPDATE ON coupon_claims
  FOR EACH ROW
  EXECUTE FUNCTION prevent_coupon_claim_modification();

CREATE TRIGGER trigger_prevent_coupon_claim_delete
  BEFORE DELETE ON coupon_claims
  FOR EACH ROW
  EXECUTE FUNCTION prevent_coupon_claim_modification();

-- ================================================
-- SECTION 6: ROW LEVEL SECURITY (RLS) POLICIES
-- ================================================

-- Enable RLS on all tables
ALTER TABLE coupon_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_eligible_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_claims ENABLE ROW LEVEL SECURITY;

-- ===== COUPON_CAMPAIGNS POLICIES =====

-- Authenticated users can view active campaigns
CREATE POLICY "authenticated_view_active_campaigns"
  ON coupon_campaigns FOR SELECT
  TO authenticated
  USING (is_active = true AND deleted_at IS NULL);

-- Admins can view all campaigns
CREATE POLICY "admins_view_all_campaigns"
  ON coupon_campaigns FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admins can insert campaigns
CREATE POLICY "admins_insert_campaigns"
  ON coupon_campaigns FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admins can update campaigns
CREATE POLICY "admins_update_campaigns"
  ON coupon_campaigns FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admins can delete campaigns (soft delete)
CREATE POLICY "admins_delete_campaigns"
  ON coupon_campaigns FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- ===== COUPON_ELIGIBLE_CUSTOMERS POLICIES =====

-- Authenticated users can check eligibility
CREATE POLICY "authenticated_check_eligibility"
  ON coupon_eligible_customers FOR SELECT
  TO authenticated
  USING (true);

-- Admins can import customers
CREATE POLICY "admins_import_customers"
  ON coupon_eligible_customers FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- ===== COUPON_PRODUCTS POLICIES =====

-- Authenticated users can view active products
CREATE POLICY "authenticated_view_active_products"
  ON coupon_products FOR SELECT
  TO authenticated
  USING (is_active = true AND deleted_at IS NULL);

-- Admins can view all products
CREATE POLICY "admins_view_all_products"
  ON coupon_products FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admins can insert products
CREATE POLICY "admins_insert_products"
  ON coupon_products FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admins can update products
CREATE POLICY "admins_update_products"
  ON coupon_products FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admins can delete products (soft delete)
CREATE POLICY "admins_delete_products"
  ON coupon_products FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- ===== COUPON_CLAIMS POLICIES =====

-- Users can view their own claims
CREATE POLICY "users_view_own_claims"
  ON coupon_claims FOR SELECT
  TO authenticated
  USING (
    claimed_by_user = auth.uid() OR
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Authenticated users can create claims (via function)
CREATE POLICY "authenticated_create_claims"
  ON coupon_claims FOR INSERT
  TO authenticated
  WITH CHECK (claimed_by_user = auth.uid());

-- ===== STORAGE POLICIES =====

-- Public read access to product images
CREATE POLICY "public_view_coupon_images"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'coupon-product-images');

-- Admins can upload images
CREATE POLICY "admins_upload_coupon_images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'coupon-product-images' AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admins can update images
CREATE POLICY "admins_update_coupon_images"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'coupon-product-images' AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admins can delete images
CREATE POLICY "admins_delete_coupon_images"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'coupon-product-images' AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- ================================================
-- SECTION 7: SAMPLE DATA (Optional - for testing)
-- ================================================

-- Uncomment to insert sample data for testing

-- INSERT INTO coupon_campaigns (
--   campaign_name,
--   campaign_code,
--   description,
--   validity_start_date,
--   validity_end_date,
--   is_active,
--   terms_conditions_en,
--   terms_conditions_ar
-- ) VALUES (
--   'Summer Gift 2025',
--   'GIFT2025',
--   'Special summer promotion with exclusive gifts',
--   '2025-06-01 00:00:00+03',
--   '2025-08-31 23:59:59+03',
--   true,
--   'Present this coupon at checkout. Valid for one-time use only. Cannot be exchanged for cash.',
--   'قدم هذا الكوبون عند الدفع. صالح لاستخدام واحد فقط. لا يمكن استبداله نقداً.'
-- );

-- ================================================
-- MIGRATION COMPLETE
-- ================================================

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON coupon_campaigns TO authenticated;
GRANT ALL ON coupon_eligible_customers TO authenticated;
GRANT ALL ON coupon_products TO authenticated;
GRANT ALL ON coupon_claims TO authenticated;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Coupon Management System migration completed successfully!';
  RAISE NOTICE 'Created tables: coupon_campaigns, coupon_eligible_customers, coupon_products, coupon_claims';
  RAISE NOTICE 'Created functions: generate_campaign_code, validate_coupon_eligibility, select_random_product, claim_coupon, get_campaign_statistics';
  RAISE NOTICE 'Created storage bucket: coupon-product-images';
  RAISE NOTICE 'Applied RLS policies for all tables';
END $$;
