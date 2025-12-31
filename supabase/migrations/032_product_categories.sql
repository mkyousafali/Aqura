-- Product Categories Table Schema
CREATE TABLE IF NOT EXISTS product_categories (
  id VARCHAR PRIMARY KEY,
  name_en VARCHAR NOT NULL,
  name_ar VARCHAR NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID
);
