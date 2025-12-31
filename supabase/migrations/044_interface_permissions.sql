-- Interface Permissions Table Schema
CREATE TABLE IF NOT EXISTS interface_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  desktop_enabled BOOLEAN NOT NULL DEFAULT true,
  mobile_enabled BOOLEAN NOT NULL DEFAULT true,
  customer_enabled BOOLEAN NOT NULL DEFAULT false,
  updated_by UUID NOT NULL,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  cashier_enabled BOOLEAN DEFAULT false
);
