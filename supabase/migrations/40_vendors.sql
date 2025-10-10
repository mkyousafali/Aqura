-- Create vendors table for comprehensive vendor and supplier management
-- This table manages vendor relationships with extensive contact and business information

-- Create the vendors table
CREATE TABLE IF NOT EXISTS public.vendors (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    company CHARACTER VARYING(255) NOT NULL,
    contact_person CHARACTER VARYING(255) NULL,
    email CHARACTER VARYING(255) NULL,
    phone CHARACTER VARYING(50) NULL,
    address TEXT NULL,
    status public.vendor_status_enum NOT NULL DEFAULT 'active'::vendor_status_enum,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT vendors_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Create original indexes
CREATE INDEX IF NOT EXISTS idx_vendors_company 
ON public.vendors USING btree (company) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_status 
ON public.vendors USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_created_at 
ON public.vendors USING btree (created_at) 
TABLESPACE pg_default;

-- Add additional columns for enhanced functionality
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS vendor_code VARCHAR(20);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS vendor_type VARCHAR(50) DEFAULT 'supplier';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS business_registration_number VARCHAR(50);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS tax_identification_number VARCHAR(50);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS website VARCHAR(255);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS industry VARCHAR(100);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS business_size VARCHAR(20) DEFAULT 'medium';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS country VARCHAR(100);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS state_province VARCHAR(100);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS city VARCHAR(100);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS billing_address TEXT;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS shipping_address TEXT;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS emergency_contact_name VARCHAR(255);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS emergency_contact_phone VARCHAR(50);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS emergency_contact_email VARCHAR(255);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS primary_contact_role VARCHAR(100);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS secondary_contact_person VARCHAR(255);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS secondary_contact_phone VARCHAR(50);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS secondary_contact_email VARCHAR(255);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS payment_terms VARCHAR(100) DEFAULT 'net_30';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS credit_limit DECIMAL(15,2);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) DEFAULT 'USD';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS preferred_payment_method VARCHAR(50);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS bank_account_info JSONB DEFAULT '{}';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS contract_start_date DATE;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS contract_end_date DATE;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS contract_terms TEXT;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS service_level_agreement TEXT;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS quality_rating DECIMAL(3,2);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS delivery_rating DECIMAL(3,2);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS price_rating DECIMAL(3,2);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS overall_rating DECIMAL(3,2);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS total_orders INTEGER DEFAULT 0;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS total_order_value DECIMAL(15,2) DEFAULT 0;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS last_order_date DATE;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS preferred_vendor BOOLEAN DEFAULT false;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS vendor_category VARCHAR(100);

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS products_services TEXT[];

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS certifications TEXT[];

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS compliance_status VARCHAR(50) DEFAULT 'pending';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS risk_level VARCHAR(20) DEFAULT 'medium';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS insurance_info JSONB DEFAULT '{}';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS performance_metrics JSONB DEFAULT '{}';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS vendor_metadata JSONB DEFAULT '{}';

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS tags TEXT[];

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS blacklisted BOOLEAN DEFAULT false;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS blacklist_reason TEXT;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS blacklisted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS blacklisted_by UUID;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS approved_by UUID;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS last_audit_date DATE;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS next_audit_date DATE;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS created_by UUID;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS updated_by UUID;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS deleted_by UUID;

-- Add foreign key constraints for user references
ALTER TABLE public.vendors 
ADD CONSTRAINT vendors_blacklisted_by_fkey 
FOREIGN KEY (blacklisted_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE public.vendors 
ADD CONSTRAINT vendors_approved_by_fkey 
FOREIGN KEY (approved_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE public.vendors 
ADD CONSTRAINT vendors_created_by_fkey 
FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE public.vendors 
ADD CONSTRAINT vendors_updated_by_fkey 
FOREIGN KEY (updated_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE public.vendors 
ADD CONSTRAINT vendors_deleted_by_fkey 
FOREIGN KEY (deleted_by) REFERENCES users (id) ON DELETE SET NULL;

-- Add validation constraints
ALTER TABLE public.vendors 
ADD CONSTRAINT chk_company_not_empty 
CHECK (TRIM(company) != '');

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_email_format 
CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_secondary_email_format 
CHECK (secondary_contact_email IS NULL OR secondary_contact_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_emergency_email_format 
CHECK (emergency_contact_email IS NULL OR emergency_contact_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_website_format 
CHECK (website IS NULL OR website ~ '^https?://.*');

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_vendor_type_valid 
CHECK (vendor_type IN ('supplier', 'contractor', 'service_provider', 'consultant', 'distributor', 'manufacturer', 'reseller'));

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_business_size_valid 
CHECK (business_size IN ('micro', 'small', 'medium', 'large', 'enterprise'));

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_payment_terms_valid 
CHECK (payment_terms IN ('net_15', 'net_30', 'net_45', 'net_60', 'net_90', 'cash_on_delivery', 'advance_payment', 'credit_card', 'custom'));

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_preferred_payment_valid 
CHECK (preferred_payment_method IS NULL OR preferred_payment_method IN ('bank_transfer', 'check', 'credit_card', 'cash', 'paypal', 'wire_transfer', 'ach'));

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_compliance_status_valid 
CHECK (compliance_status IN ('pending', 'compliant', 'non_compliant', 'under_review', 'expired'));

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_risk_level_valid 
CHECK (risk_level IN ('low', 'medium', 'high', 'critical'));

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_credit_limit_positive 
CHECK (credit_limit IS NULL OR credit_limit >= 0);

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_ratings_valid 
CHECK (
    (quality_rating IS NULL OR (quality_rating >= 0 AND quality_rating <= 5)) AND
    (delivery_rating IS NULL OR (delivery_rating >= 0 AND delivery_rating <= 5)) AND
    (price_rating IS NULL OR (price_rating >= 0 AND price_rating <= 5)) AND
    (overall_rating IS NULL OR (overall_rating >= 0 AND overall_rating <= 5))
);

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_total_orders_positive 
CHECK (total_orders >= 0);

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_total_value_positive 
CHECK (total_order_value >= 0);

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_contract_dates_valid 
CHECK (contract_end_date IS NULL OR contract_start_date IS NULL OR contract_end_date >= contract_start_date);

ALTER TABLE public.vendors 
ADD CONSTRAINT chk_vendor_code_unique 
UNIQUE (vendor_code);

-- Create additional indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_vendors_vendor_code 
ON public.vendors (vendor_code) 
WHERE vendor_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_email 
ON public.vendors (email) 
WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_phone 
ON public.vendors (phone) 
WHERE phone IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_vendor_type 
ON public.vendors (vendor_type);

CREATE INDEX IF NOT EXISTS idx_vendors_country 
ON public.vendors (country) 
WHERE country IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_city 
ON public.vendors (city) 
WHERE city IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_industry 
ON public.vendors (industry) 
WHERE industry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_preferred 
ON public.vendors (preferred_vendor) 
WHERE preferred_vendor = true;

CREATE INDEX IF NOT EXISTS idx_vendors_blacklisted 
ON public.vendors (blacklisted, blacklisted_at) 
WHERE blacklisted = true;

CREATE INDEX IF NOT EXISTS idx_vendors_compliance 
ON public.vendors (compliance_status);

CREATE INDEX IF NOT EXISTS idx_vendors_risk_level 
ON public.vendors (risk_level);

CREATE INDEX IF NOT EXISTS idx_vendors_overall_rating 
ON public.vendors (overall_rating DESC) 
WHERE overall_rating IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_last_order 
ON public.vendors (last_order_date DESC) 
WHERE last_order_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_contract_end 
ON public.vendors (contract_end_date) 
WHERE contract_end_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_next_audit 
ON public.vendors (next_audit_date) 
WHERE next_audit_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_approved 
ON public.vendors (approved_at, approved_by) 
WHERE approved_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendors_created_by 
ON public.vendors (created_by);

CREATE INDEX IF NOT EXISTS idx_vendors_updated_by 
ON public.vendors (updated_by);

CREATE INDEX IF NOT EXISTS idx_vendors_deleted 
ON public.vendors (deleted_at, deleted_by) 
WHERE deleted_at IS NOT NULL;

-- Create GIN indexes for JSONB and array columns
CREATE INDEX IF NOT EXISTS idx_vendors_bank_account 
ON public.vendors USING gin (bank_account_info);

CREATE INDEX IF NOT EXISTS idx_vendors_insurance 
ON public.vendors USING gin (insurance_info);

CREATE INDEX IF NOT EXISTS idx_vendors_performance 
ON public.vendors USING gin (performance_metrics);

CREATE INDEX IF NOT EXISTS idx_vendors_metadata 
ON public.vendors USING gin (vendor_metadata);

CREATE INDEX IF NOT EXISTS idx_vendors_products_services 
ON public.vendors USING gin (products_services);

CREATE INDEX IF NOT EXISTS idx_vendors_certifications 
ON public.vendors USING gin (certifications);

CREATE INDEX IF NOT EXISTS idx_vendors_tags 
ON public.vendors USING gin (tags);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_vendors_status_type 
ON public.vendors (status, vendor_type);

CREATE INDEX IF NOT EXISTS idx_vendors_category_status 
ON public.vendors (vendor_category, status);

CREATE INDEX IF NOT EXISTS idx_vendors_location 
ON public.vendors (country, state_province, city);

CREATE INDEX IF NOT EXISTS idx_vendors_active_preferred 
ON public.vendors (status, preferred_vendor) 
WHERE status = 'active' AND preferred_vendor = true;

-- Create text search index for company names
CREATE INDEX IF NOT EXISTS idx_vendors_company_search 
ON public.vendors USING gin (to_tsvector('english', company));

-- Add table and column comments
COMMENT ON TABLE public.vendors IS 'Comprehensive vendor and supplier management with business relationships and performance tracking';
COMMENT ON COLUMN public.vendors.id IS 'Unique identifier for the vendor';
COMMENT ON COLUMN public.vendors.company IS 'Company or business name';
COMMENT ON COLUMN public.vendors.contact_person IS 'Primary contact person name';
COMMENT ON COLUMN public.vendors.email IS 'Primary email address';
COMMENT ON COLUMN public.vendors.phone IS 'Primary phone number';
COMMENT ON COLUMN public.vendors.address IS 'Primary business address';
COMMENT ON COLUMN public.vendors.vendor_code IS 'Unique vendor identification code';
COMMENT ON COLUMN public.vendors.vendor_type IS 'Type of vendor (supplier, contractor, etc.)';
COMMENT ON COLUMN public.vendors.business_registration_number IS 'Official business registration number';
COMMENT ON COLUMN public.vendors.tax_identification_number IS 'Tax ID or VAT number';
COMMENT ON COLUMN public.vendors.website IS 'Company website URL';
COMMENT ON COLUMN public.vendors.industry IS 'Industry or business sector';
COMMENT ON COLUMN public.vendors.business_size IS 'Size classification of the business';
COMMENT ON COLUMN public.vendors.payment_terms IS 'Standard payment terms';
COMMENT ON COLUMN public.vendors.credit_limit IS 'Maximum credit limit allowed';
COMMENT ON COLUMN public.vendors.currency_code IS 'Primary transaction currency';
COMMENT ON COLUMN public.vendors.quality_rating IS 'Quality performance rating (0-5)';
COMMENT ON COLUMN public.vendors.delivery_rating IS 'Delivery performance rating (0-5)';
COMMENT ON COLUMN public.vendors.price_rating IS 'Pricing competitiveness rating (0-5)';
COMMENT ON COLUMN public.vendors.overall_rating IS 'Overall vendor rating (0-5)';
COMMENT ON COLUMN public.vendors.total_orders IS 'Total number of orders placed';
COMMENT ON COLUMN public.vendors.total_order_value IS 'Total value of all orders';
COMMENT ON COLUMN public.vendors.preferred_vendor IS 'Whether this is a preferred vendor';
COMMENT ON COLUMN public.vendors.products_services IS 'Array of products/services offered';
COMMENT ON COLUMN public.vendors.certifications IS 'Business certifications and credentials';
COMMENT ON COLUMN public.vendors.compliance_status IS 'Current compliance status';
COMMENT ON COLUMN public.vendors.risk_level IS 'Business risk assessment level';
COMMENT ON COLUMN public.vendors.blacklisted IS 'Whether vendor is blacklisted';
COMMENT ON COLUMN public.vendors.blacklist_reason IS 'Reason for blacklisting';

-- Create view for active vendors with performance metrics
CREATE OR REPLACE VIEW active_vendors_performance AS
SELECT 
    v.id,
    v.company,
    v.vendor_code,
    v.contact_person,
    v.email,
    v.phone,
    v.vendor_type,
    v.industry,
    v.country,
    v.city,
    v.status,
    v.preferred_vendor,
    v.quality_rating,
    v.delivery_rating,
    v.price_rating,
    v.overall_rating,
    v.total_orders,
    v.total_order_value,
    v.last_order_date,
    v.compliance_status,
    v.risk_level,
    v.contract_end_date,
    v.next_audit_date,
    v.created_at,
    CASE 
        WHEN v.contract_end_date IS NOT NULL AND v.contract_end_date < CURRENT_DATE + INTERVAL '30 days' THEN true
        ELSE false
    END as contract_expiring_soon,
    CASE 
        WHEN v.next_audit_date IS NOT NULL AND v.next_audit_date < CURRENT_DATE + INTERVAL '7 days' THEN true
        ELSE false
    END as audit_due_soon,
    EXTRACT(EPOCH FROM (now() - v.last_order_date)) / 86400 as days_since_last_order
FROM vendors v
WHERE v.status = 'active' 
  AND v.blacklisted = false
  AND v.deleted_at IS NULL
ORDER BY v.overall_rating DESC NULLS LAST, v.total_order_value DESC;

-- Create function to create a new vendor
CREATE OR REPLACE FUNCTION create_vendor(
    company_param VARCHAR,
    contact_person_param VARCHAR DEFAULT NULL,
    email_param VARCHAR DEFAULT NULL,
    phone_param VARCHAR DEFAULT NULL,
    address_param TEXT DEFAULT NULL,
    vendor_type_param VARCHAR DEFAULT 'supplier',
    vendor_code_param VARCHAR DEFAULT NULL,
    industry_param VARCHAR DEFAULT NULL,
    created_by_param UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    vendor_id UUID;
    generated_code VARCHAR;
BEGIN
    -- Generate vendor code if not provided
    IF vendor_code_param IS NULL THEN
        generated_code := 'VEN' || LPAD(nextval('vendor_code_seq')::TEXT, 6, '0');
    ELSE
        generated_code := vendor_code_param;
    END IF;
    
    INSERT INTO vendors (
        company,
        contact_person,
        email,
        phone,
        address,
        vendor_type,
        vendor_code,
        industry,
        created_by
    ) VALUES (
        company_param,
        contact_person_param,
        email_param,
        phone_param,
        address_param,
        vendor_type_param,
        generated_code,
        industry_param,
        created_by_param
    ) RETURNING id INTO vendor_id;
    
    RETURN vendor_id;
END;
$$ LANGUAGE plpgsql;

-- Create sequence for vendor codes
CREATE SEQUENCE IF NOT EXISTS vendor_code_seq START 1;

-- Create function to update vendor rating
CREATE OR REPLACE FUNCTION update_vendor_rating(
    vendor_id_param UUID,
    quality_rating_param DECIMAL DEFAULT NULL,
    delivery_rating_param DECIMAL DEFAULT NULL,
    price_rating_param DECIMAL DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    new_overall_rating DECIMAL;
    vendor_exists BOOLEAN;
BEGIN
    -- Calculate overall rating
    SELECT 
        (COALESCE(quality_rating_param, quality_rating, 0) + 
         COALESCE(delivery_rating_param, delivery_rating, 0) + 
         COALESCE(price_rating_param, price_rating, 0)) / 3
    INTO new_overall_rating
    FROM vendors 
    WHERE id = vendor_id_param;
    
    -- Update vendor ratings
    UPDATE vendors 
    SET 
        quality_rating = COALESCE(quality_rating_param, quality_rating),
        delivery_rating = COALESCE(delivery_rating_param, delivery_rating),
        price_rating = COALESCE(price_rating_param, price_rating),
        overall_rating = new_overall_rating,
        updated_at = now()
    WHERE id = vendor_id_param;
    
    GET DIAGNOSTICS vendor_exists = FOUND;
    RETURN vendor_exists;
END;
$$ LANGUAGE plpgsql;

-- Create function to blacklist vendor
CREATE OR REPLACE FUNCTION blacklist_vendor(
    vendor_id_param UUID,
    reason_param TEXT,
    blacklisted_by_param UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    vendor_exists BOOLEAN;
BEGIN
    UPDATE vendors 
    SET 
        blacklisted = true,
        blacklist_reason = reason_param,
        blacklisted_at = now(),
        blacklisted_by = blacklisted_by_param,
        status = 'inactive',
        updated_at = now(),
        updated_by = blacklisted_by_param
    WHERE id = vendor_id_param 
      AND blacklisted = false;
    
    GET DIAGNOSTICS vendor_exists = FOUND;
    RETURN vendor_exists;
END;
$$ LANGUAGE plpgsql;

-- Create function to get vendor statistics
CREATE OR REPLACE FUNCTION get_vendor_statistics(
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_vendors BIGINT,
    active_vendors BIGINT,
    preferred_vendors BIGINT,
    blacklisted_vendors BIGINT,
    avg_overall_rating DECIMAL,
    vendors_by_type JSONB,
    vendors_by_industry JSONB,
    vendors_by_risk_level JSONB,
    contracts_expiring_soon BIGINT,
    audits_due_soon BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_vendors,
        COUNT(*) FILTER (WHERE status = 'active' AND deleted_at IS NULL) as active_vendors,
        COUNT(*) FILTER (WHERE preferred_vendor = true AND status = 'active') as preferred_vendors,
        COUNT(*) FILTER (WHERE blacklisted = true) as blacklisted_vendors,
        AVG(overall_rating) FILTER (WHERE overall_rating IS NOT NULL) as avg_overall_rating,
        jsonb_object_agg(vendor_type, type_count) as vendors_by_type,
        jsonb_object_agg(industry, industry_count) as vendors_by_industry,
        jsonb_object_agg(risk_level, risk_count) as vendors_by_risk_level,
        COUNT(*) FILTER (WHERE contract_end_date IS NOT NULL AND contract_end_date < CURRENT_DATE + INTERVAL '30 days') as contracts_expiring_soon,
        COUNT(*) FILTER (WHERE next_audit_date IS NOT NULL AND next_audit_date < CURRENT_DATE + INTERVAL '7 days') as audits_due_soon
    FROM vendors v
    LEFT JOIN (
        SELECT vendor_type, COUNT(*) as type_count
        FROM vendors
        WHERE deleted_at IS NULL
          AND (date_from IS NULL OR created_at >= date_from)
          AND (date_to IS NULL OR created_at <= date_to)
        GROUP BY vendor_type
    ) type_stats ON true
    LEFT JOIN (
        SELECT industry, COUNT(*) as industry_count
        FROM vendors
        WHERE deleted_at IS NULL AND industry IS NOT NULL
          AND (date_from IS NULL OR created_at >= date_from)
          AND (date_to IS NULL OR created_at <= date_to)
        GROUP BY industry
    ) industry_stats ON true
    LEFT JOIN (
        SELECT risk_level, COUNT(*) as risk_count
        FROM vendors
        WHERE deleted_at IS NULL
          AND (date_from IS NULL OR created_at >= date_from)
          AND (date_to IS NULL OR created_at <= date_to)
        GROUP BY risk_level
    ) risk_stats ON true
    WHERE v.deleted_at IS NULL
      AND (date_from IS NULL OR v.created_at >= date_from)
      AND (date_to IS NULL OR v.created_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to search vendors
CREATE OR REPLACE FUNCTION search_vendors(
    search_term VARCHAR,
    vendor_type_filter VARCHAR DEFAULT NULL,
    status_filter vendor_status_enum DEFAULT NULL,
    limit_param INTEGER DEFAULT 50
)
RETURNS TABLE(
    id UUID,
    company VARCHAR,
    vendor_code VARCHAR,
    contact_person VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    vendor_type VARCHAR,
    status vendor_status_enum,
    overall_rating DECIMAL,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        v.company,
        v.vendor_code,
        v.contact_person,
        v.email,
        v.phone,
        v.vendor_type,
        v.status,
        v.overall_rating,
        ts_rank(to_tsvector('english', v.company), plainto_tsquery('english', search_term)) as rank
    FROM vendors v
    WHERE v.deleted_at IS NULL
      AND (
          v.company ILIKE '%' || search_term || '%' OR
          v.vendor_code ILIKE '%' || search_term || '%' OR
          v.contact_person ILIKE '%' || search_term || '%' OR
          to_tsvector('english', v.company) @@ plainto_tsquery('english', search_term)
      )
      AND (vendor_type_filter IS NULL OR v.vendor_type = vendor_type_filter)
      AND (status_filter IS NULL OR v.status = status_filter)
    ORDER BY rank DESC, v.overall_rating DESC NULLS LAST
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'vendors table created with comprehensive vendor management and performance tracking features';