-- Customer Recovery Requests Table Schema
CREATE TABLE IF NOT EXISTS customer_recovery_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID,
  whatsapp_number VARCHAR NOT NULL,
  customer_name TEXT,
  request_type TEXT NOT NULL DEFAULT 'account_recovery',
  verification_status TEXT NOT NULL DEFAULT 'pending',
  verification_notes TEXT,
  processed_by UUID,
  processed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
