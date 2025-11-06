-- ================================================================
-- TABLE SCHEMA: vendors
-- Generated: 2025-11-06T11:09:39.027Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.vendors (
    erp_vendor_id integer NOT NULL,
    vendor_name text NOT NULL,
    salesman_name text,
    salesman_contact text,
    supervisor_name text,
    supervisor_contact text,
    vendor_contact_number text,
    payment_method text,
    credit_period integer,
    bank_name text,
    iban text,
    status text DEFAULT 'Active'::text,
    last_visit timestamp without time zone,
    categories ARRAY,
    delivery_modes ARRAY,
    place text,
    location_link text,
    return_expired_products text,
    return_expired_products_note text,
    return_near_expiry_products text,
    return_near_expiry_products_note text,
    return_over_stock text,
    return_over_stock_note text,
    return_damage_products text,
    return_damage_products_note text,
    no_return boolean DEFAULT false,
    no_return_note text,
    vat_applicable text DEFAULT 'VAT Applicable'::text,
    vat_number text,
    no_vat_note text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    branch_id bigint NOT NULL,
    payment_priority text DEFAULT 'Normal'::text
);

-- Table comment
COMMENT ON TABLE public.vendors IS 'Table for vendors management';

-- Column comments
COMMENT ON COLUMN public.vendors.erp_vendor_id IS 'Foreign key reference to erp_vendor table';
COMMENT ON COLUMN public.vendors.vendor_name IS 'Name field';
COMMENT ON COLUMN public.vendors.salesman_name IS 'Name field';
COMMENT ON COLUMN public.vendors.salesman_contact IS 'salesman contact field';
COMMENT ON COLUMN public.vendors.supervisor_name IS 'Name field';
COMMENT ON COLUMN public.vendors.supervisor_contact IS 'supervisor contact field';
COMMENT ON COLUMN public.vendors.vendor_contact_number IS 'Reference number';
COMMENT ON COLUMN public.vendors.payment_method IS 'payment method field';
COMMENT ON COLUMN public.vendors.credit_period IS 'credit period field';
COMMENT ON COLUMN public.vendors.bank_name IS 'Name field';
COMMENT ON COLUMN public.vendors.iban IS 'iban field';
COMMENT ON COLUMN public.vendors.status IS 'Status indicator';
COMMENT ON COLUMN public.vendors.last_visit IS 'last visit field';
COMMENT ON COLUMN public.vendors.categories IS 'categories field';
COMMENT ON COLUMN public.vendors.delivery_modes IS 'delivery modes field';
COMMENT ON COLUMN public.vendors.place IS 'place field';
COMMENT ON COLUMN public.vendors.location_link IS 'location link field';
COMMENT ON COLUMN public.vendors.return_expired_products IS 'return expired products field';
COMMENT ON COLUMN public.vendors.return_expired_products_note IS 'return expired products note field';
COMMENT ON COLUMN public.vendors.return_near_expiry_products IS 'return near expiry products field';
COMMENT ON COLUMN public.vendors.return_near_expiry_products_note IS 'return near expiry products note field';
COMMENT ON COLUMN public.vendors.return_over_stock IS 'return over stock field';
COMMENT ON COLUMN public.vendors.return_over_stock_note IS 'return over stock note field';
COMMENT ON COLUMN public.vendors.return_damage_products IS 'return damage products field';
COMMENT ON COLUMN public.vendors.return_damage_products_note IS 'return damage products note field';
COMMENT ON COLUMN public.vendors.no_return IS 'Boolean flag';
COMMENT ON COLUMN public.vendors.no_return_note IS 'no return note field';
COMMENT ON COLUMN public.vendors.vat_applicable IS 'vat applicable field';
COMMENT ON COLUMN public.vendors.vat_number IS 'Reference number';
COMMENT ON COLUMN public.vendors.no_vat_note IS 'no vat note field';
COMMENT ON COLUMN public.vendors.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.vendors.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.vendors.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.vendors.payment_priority IS 'payment priority field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Foreign key index for erp_vendor_id
CREATE INDEX IF NOT EXISTS idx_vendors_erp_vendor_id ON public.vendors USING btree (erp_vendor_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_vendors_branch_id ON public.vendors USING btree (branch_id);

-- Date index for last_visit
CREATE INDEX IF NOT EXISTS idx_vendors_last_visit ON public.vendors USING btree (last_visit);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for vendors

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "vendors_select_policy" ON public.vendors
    FOR SELECT USING (true);

CREATE POLICY "vendors_insert_policy" ON public.vendors
    FOR INSERT WITH CHECK (true);

CREATE POLICY "vendors_update_policy" ON public.vendors
    FOR UPDATE USING (true);

CREATE POLICY "vendors_delete_policy" ON public.vendors
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for vendors

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.vendors (vendor_name, salesman_name, salesman_contact)
VALUES ('example text', 'example text', 'example text');
*/

-- Select example
/*
SELECT * FROM public.vendors 
WHERE erp_vendor_id = $1;
*/

-- Update example
/*
UPDATE public.vendors 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF VENDORS SCHEMA
-- ================================================================
