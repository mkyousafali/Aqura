-- =====================================================
-- Flyer Master: Offer Products Junction Table
-- Created: 2025-11-23
-- Description: Creates flyer_offer_products table linking offers to products with pricing
-- =====================================================

-- Create flyer_offer_products table
CREATE TABLE IF NOT EXISTS public.flyer_offer_products (
    -- Primary Key
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Foreign Keys
    offer_id UUID NOT NULL,
    product_barcode TEXT NOT NULL,
    
    -- Pricing Information
    cost NUMERIC(10, 2) NULL,
    sales_price NUMERIC(10, 2) NULL,
    offer_price NUMERIC(10, 2) NULL,
    
    -- Profit Calculations
    profit_amount NUMERIC(10, 2) NULL,
    profit_percent NUMERIC(10, 2) NULL,
    profit_after_offer NUMERIC(10, 2) NULL,
    decrease_amount NUMERIC(10, 2) NULL,
    
    -- Quantity Information
    offer_qty INTEGER NOT NULL DEFAULT 1,
    limit_qty INTEGER NULL,
    free_qty INTEGER NOT NULL DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    
    -- Constraints
    CONSTRAINT flyer_offer_products_pkey PRIMARY KEY (id),
    CONSTRAINT flyer_offer_products_offer_id_product_barcode_key UNIQUE (offer_id, product_barcode),
    CONSTRAINT flyer_offer_products_offer_id_fkey 
        FOREIGN KEY (offer_id) 
        REFERENCES public.flyer_offers(id) 
        ON DELETE CASCADE,
    CONSTRAINT flyer_offer_products_product_barcode_fkey 
        FOREIGN KEY (product_barcode) 
        REFERENCES public.flyer_products(barcode) 
        ON DELETE CASCADE,
    CONSTRAINT flyer_offer_products_offer_qty_check CHECK (offer_qty >= 0),
    CONSTRAINT flyer_offer_products_free_qty_check CHECK (free_qty >= 0)
) TABLESPACE pg_default;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_flyer_offer_products_offer_id 
    ON public.flyer_offer_products USING btree (offer_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_flyer_offer_products_barcode 
    ON public.flyer_offer_products USING btree (product_barcode) 
    TABLESPACE pg_default;

-- Add comments
COMMENT ON TABLE public.flyer_offer_products IS 'Junction table linking flyer offers to products with pricing details';
COMMENT ON COLUMN public.flyer_offer_products.offer_id IS 'Reference to the flyer offer';
COMMENT ON COLUMN public.flyer_offer_products.product_barcode IS 'Reference to the product barcode';
COMMENT ON COLUMN public.flyer_offer_products.cost IS 'Product cost price';
COMMENT ON COLUMN public.flyer_offer_products.sales_price IS 'Regular sales price';
COMMENT ON COLUMN public.flyer_offer_products.offer_price IS 'Special offer price';
COMMENT ON COLUMN public.flyer_offer_products.profit_amount IS 'Profit amount in currency';
COMMENT ON COLUMN public.flyer_offer_products.profit_percent IS 'Profit as percentage';
COMMENT ON COLUMN public.flyer_offer_products.profit_after_offer IS 'Profit after applying offer discount';
COMMENT ON COLUMN public.flyer_offer_products.decrease_amount IS 'Amount decreased from regular price';
COMMENT ON COLUMN public.flyer_offer_products.offer_qty IS 'Quantity required to qualify for offer';
COMMENT ON COLUMN public.flyer_offer_products.limit_qty IS 'Maximum quantity limit per customer (nullable)';
COMMENT ON COLUMN public.flyer_offer_products.free_qty IS 'Free quantity given with purchase';
