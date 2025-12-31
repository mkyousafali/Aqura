-- Offers Table Schema
CREATE TABLE IF NOT EXISTS offers (
  id INTEGER PRIMARY KEY DEFAULT nextval('offers_id_seq'),
  type VARCHAR NOT NULL,
  name_ar VARCHAR NOT NULL,
  name_en VARCHAR NOT NULL,
  description_ar TEXT,
  description_en TEXT,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  max_uses_per_customer INTEGER,
  max_total_uses INTEGER,
  current_total_uses INTEGER DEFAULT 0,
  branch_id INTEGER,
  service_type VARCHAR DEFAULT 'both',
  show_on_product_page BOOLEAN DEFAULT true,
  show_in_carousel BOOLEAN DEFAULT false,
  send_push_notification BOOLEAN DEFAULT false,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
