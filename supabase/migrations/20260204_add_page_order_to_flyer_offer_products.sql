-- Add page_number and page_order columns to flyer_offer_products table
-- This allows tracking which page and position each product appears in the flyer

ALTER TABLE flyer_offer_products
ADD COLUMN IF NOT EXISTS page_number INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS page_order INTEGER DEFAULT 1;

-- Add comment for clarity
COMMENT ON COLUMN flyer_offer_products.page_number IS 'The page number where this product appears in the flyer';
COMMENT ON COLUMN flyer_offer_products.page_order IS 'The order/position of this product on its page';

-- Create index for efficient page-based queries
CREATE INDEX IF NOT EXISTS idx_flyer_offer_products_page 
ON flyer_offer_products(offer_id, page_number, page_order);
