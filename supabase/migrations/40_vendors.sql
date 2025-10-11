-- Create fresh vendors table with all required columns
CREATE TABLE vendors (
    erp_vendor_id INTEGER PRIMARY KEY,
    vendor_name TEXT NOT NULL,
    salesman_name TEXT,
    salesman_contact TEXT,
    supervisor_name TEXT,
    supervisor_contact TEXT,
    vendor_contact_number TEXT,
    -- Updated to support multiple payment methods as comma-separated values
    payment_method TEXT, -- Can contain multiple methods: 'Cash on Delivery,Bank Credit,Cash Credit'
    credit_period INTEGER, -- Credit period in days (for credit payment methods)
    bank_name TEXT, -- Bank name (for bank-related payment methods)
    iban TEXT, -- IBAN for bank transfers
    status TEXT DEFAULT 'Active',
    last_visit TIMESTAMP,
    categories TEXT[], -- Array of category names
    delivery_modes TEXT[], -- Array of delivery mode names
    place TEXT, -- Vendor place/area
    location_link TEXT, -- Google Maps or location link
    -- Return Policy Fields
    return_expired_products TEXT,
    return_expired_products_note TEXT,
    return_near_expiry_products TEXT,
    return_near_expiry_products_note TEXT,
    return_over_stock TEXT,
    return_over_stock_note TEXT,
    return_damage_products TEXT,
    return_damage_products_note TEXT,
    no_return BOOLEAN DEFAULT FALSE,
    no_return_note TEXT,
    -- VAT Fields
    vat_applicable TEXT DEFAULT 'VAT Applicable',
    vat_number TEXT,
    no_vat_note TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_vendors_status ON vendors (status);
CREATE INDEX idx_vendors_vendor_name ON vendors (vendor_name);
CREATE INDEX idx_vendors_payment_method ON vendors USING gin (to_tsvector('english', payment_method));
CREATE INDEX idx_vendors_vat_applicable ON vendors (vat_applicable);
CREATE INDEX idx_vendors_created_at ON vendors (created_at);

-- Add table and column comments for documentation
COMMENT ON TABLE vendors IS 'Vendor management table with support for multiple payment methods, return policies, and VAT information';
COMMENT ON COLUMN vendors.payment_method IS 'Comma-separated list of payment methods: Cash on Delivery, Bank on Delivery, Cash Credit, Bank Credit';
COMMENT ON COLUMN vendors.credit_period IS 'Credit period in days for credit-based payment methods';
COMMENT ON COLUMN vendors.bank_name IS 'Bank name for bank-related payment methods';
COMMENT ON COLUMN vendors.iban IS 'International Bank Account Number for bank transfers';
COMMENT ON COLUMN vendors.no_return IS 'When TRUE, vendor does not accept any returns regardless of other return policy settings';
COMMENT ON COLUMN vendors.vat_applicable IS 'VAT applicability status for the vendor';
COMMENT ON COLUMN vendors.vat_number IS 'VAT registration number when VAT is applicable';

-- Payment method validation function (for future use if needed)
CREATE OR REPLACE FUNCTION validate_payment_methods(payment_methods TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    valid_methods TEXT[] := ARRAY['Cash on Delivery', 'Bank on Delivery', 'Cash Credit', 'Bank Credit'];
    method TEXT;
    methods TEXT[];
BEGIN
    IF payment_methods IS NULL OR LENGTH(TRIM(payment_methods)) = 0 THEN
        RETURN TRUE;
    END IF;
    
    -- Split comma-separated values
    methods := string_to_array(payment_methods, ',');
    
    -- Check each method
    FOREACH method IN ARRAY methods
    LOOP
        IF TRIM(method) != ANY(valid_methods) THEN
            RETURN FALSE;
        END IF;
    END LOOP;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;