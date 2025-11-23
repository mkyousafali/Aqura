-- =====================================================
-- Flyer Master: Products Table
-- Created: 2025-11-23
-- Description: Creates flyer_products table for flyer/catalog management
-- =====================================================

-- Create flyer_products table
CREATE TABLE IF NOT EXISTS public.flyer_products (
    -- Primary Key
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Product Identification
    barcode TEXT NOT NULL UNIQUE,
    
    -- Product Names (Bilingual)
    product_name_en TEXT NULL,
    product_name_ar TEXT NULL,
    
    -- Unit Information
    unit_name TEXT NULL,
    
    -- Image Management
    image_url TEXT NULL,
    
    -- Category Hierarchy
    parent_category TEXT NOT NULL,
    parent_sub_category TEXT NOT NULL,
    sub_category TEXT NOT NULL,
    
    -- Optional: Link to Aqura products table (for future integration)
    -- aqura_product_id BIGINT NULL REFERENCES products(id) ON DELETE SET NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT flyer_products_pkey PRIMARY KEY (id),
    CONSTRAINT flyer_products_barcode_key UNIQUE (barcode)
) TABLESPACE pg_default;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_flyer_products_parent_category 
    ON public.flyer_products USING btree (parent_category) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_flyer_products_parent_sub_category 
    ON public.flyer_products USING btree (parent_sub_category) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_flyer_products_sub_category 
    ON public.flyer_products USING btree (sub_category) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_flyer_products_barcode 
    ON public.flyer_products USING btree (barcode) 
    TABLESPACE pg_default;

-- Add trigger for auto-updating updated_at
CREATE TRIGGER update_flyer_products_updated_at
    BEFORE UPDATE ON public.flyer_products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE public.flyer_products IS 'Stores product information for flyer and catalog management';
COMMENT ON COLUMN public.flyer_products.barcode IS 'Unique product barcode identifier';
COMMENT ON COLUMN public.flyer_products.parent_category IS 'Top-level category for product organization';
COMMENT ON COLUMN public.flyer_products.parent_sub_category IS 'Mid-level category for product organization';
COMMENT ON COLUMN public.flyer_products.sub_category IS 'Detailed category for product organization';
