-- Delivery Service Settings Table Schema
CREATE TABLE IF NOT EXISTS delivery_service_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  minimum_order_amount NUMERIC NOT NULL DEFAULT 15.00,
  is_24_hours BOOLEAN NOT NULL DEFAULT true,
  operating_start_time TIME WITHOUT TIME ZONE,
  operating_end_time TIME WITHOUT TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  display_message_ar TEXT DEFAULT 'التوصيل متاح على مدار الساعة (24/7)',
  display_message_en TEXT DEFAULT 'Delivery available 24/7',
  updated_by UUID,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
