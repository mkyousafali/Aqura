-- Customer App Media Table Schema
CREATE TABLE IF NOT EXISTS customer_app_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  media_type VARCHAR NOT NULL,
  slot_number INTEGER NOT NULL,
  title_en VARCHAR NOT NULL,
  title_ar VARCHAR NOT NULL,
  description_en TEXT,
  description_ar TEXT,
  file_url TEXT NOT NULL,
  file_size BIGINT,
  file_type VARCHAR,
  duration INTEGER,
  is_active BOOLEAN DEFAULT false,
  display_order INTEGER DEFAULT 0,
  is_infinite BOOLEAN DEFAULT false,
  expiry_date TIMESTAMP WITH TIME ZONE,
  uploaded_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  activated_at TIMESTAMP WITH TIME ZONE,
  deactivated_at TIMESTAMP WITH TIME ZONE
);
