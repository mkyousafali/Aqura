-- Privilege Cards Master Table Schema
CREATE TABLE IF NOT EXISTS privilege_cards_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_number VARCHAR NOT NULL UNIQUE,
  privilege_type VARCHAR NOT NULL,
  balance NUMERIC NOT NULL DEFAULT 0.0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  issued_by UUID,
  issued_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  expires_at TIMESTAMP WITH TIME ZONE,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
