-- =====================================================
-- Flyer Master: Storage Bucket Configuration
-- Created: 2025-11-23
-- Description: Creates storage bucket for flyer product images
-- =====================================================

-- Create storage bucket for flyer product images
-- Note: Using DO block to handle permission context
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
        'flyer-product-images',
        'flyer-product-images',
        true,
        15728640, -- 15 MB in bytes
        ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
    )
    ON CONFLICT (id) DO NOTHING;
END $$;
