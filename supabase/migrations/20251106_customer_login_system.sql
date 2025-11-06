-- ================================================================
-- MIGRATION: Add Customer Login System Tables
-- Created: 2025-11-06
-- Description: Creates customers and interface_permissions tables for customer login system
-- ================================================================

-- ================================================================
-- TABLE: customers
-- Purpose: Store customer-specific data including access codes and registration info
-- ================================================================

CREATE TABLE IF NOT EXISTS public.customers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    access_code character varying(6) UNIQUE,
    whatsapp_number character varying(20),
    registration_status text NOT NULL DEFAULT 'pending',
    registration_notes text,
    approved_by uuid REFERENCES public.users(id),
    approved_at timestamp with time zone,
    access_code_generated_at timestamp with time zone,
    access_code_generated_by uuid REFERENCES public.users(id),
    last_access_code_request timestamp with time zone,
    access_code_request_count integer DEFAULT 0,
    access_code_regeneration_count integer DEFAULT 0,
    rejection_notes text,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- Constraints
    CONSTRAINT customers_registration_status_check 
        CHECK (registration_status IN ('pending', 'approved', 'rejected', 'suspended')),
    CONSTRAINT customers_access_code_format_check 
        CHECK (access_code ~ '^[0-9]{6}$'),
    CONSTRAINT customers_whatsapp_format_check 
        CHECK (whatsapp_number ~ '^\+?[1-9]\d{1,14}$')
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_customers_user_id ON public.customers(user_id);
CREATE INDEX IF NOT EXISTS idx_customers_access_code ON public.customers(access_code) WHERE access_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_customers_whatsapp ON public.customers(whatsapp_number) WHERE whatsapp_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_customers_registration_status ON public.customers(registration_status);
CREATE INDEX IF NOT EXISTS idx_customers_approved_by ON public.customers(approved_by);

-- Comments
COMMENT ON TABLE public.customers IS 'Customer information and access codes for customer login system';
COMMENT ON COLUMN public.customers.access_code IS 'Unique 6-digit access code for customer login';
COMMENT ON COLUMN public.customers.whatsapp_number IS 'Customer WhatsApp number for notifications';
COMMENT ON COLUMN public.customers.registration_status IS 'Customer registration approval status';

-- ================================================================
-- TABLE: interface_permissions
-- Purpose: Control user access to different interfaces (desktop, mobile, customer)
-- ================================================================

CREATE TABLE IF NOT EXISTS public.interface_permissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    desktop_enabled boolean NOT NULL DEFAULT true,
    mobile_enabled boolean NOT NULL DEFAULT true,
    customer_enabled boolean NOT NULL DEFAULT false,
    updated_by uuid NOT NULL REFERENCES public.users(id),
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- Ensure one record per user
    CONSTRAINT interface_permissions_user_unique UNIQUE (user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_interface_permissions_user_id ON public.interface_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_interface_permissions_updated_by ON public.interface_permissions(updated_by);
CREATE INDEX IF NOT EXISTS idx_interface_permissions_desktop ON public.interface_permissions(desktop_enabled);
CREATE INDEX IF NOT EXISTS idx_interface_permissions_mobile ON public.interface_permissions(mobile_enabled);
CREATE INDEX IF NOT EXISTS idx_interface_permissions_customer ON public.interface_permissions(customer_enabled);

-- Comments
COMMENT ON TABLE public.interface_permissions IS 'User access permissions for different application interfaces';
COMMENT ON COLUMN public.interface_permissions.desktop_enabled IS 'Whether user can access desktop interface';
COMMENT ON COLUMN public.interface_permissions.mobile_enabled IS 'Whether user can access mobile interface';
COMMENT ON COLUMN public.interface_permissions.customer_enabled IS 'Whether user can access customer interface';

-- ================================================================
-- TRIGGERS
-- ================================================================

-- Updated timestamp trigger for customers
CREATE OR REPLACE FUNCTION update_customers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_update_customers_updated_at
    BEFORE UPDATE ON public.customers
    FOR EACH ROW
    EXECUTE FUNCTION update_customers_updated_at();

-- Updated timestamp trigger for interface_permissions
CREATE OR REPLACE FUNCTION update_interface_permissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_update_interface_permissions_updated_at
    BEFORE UPDATE ON public.interface_permissions
    FOR EACH ROW
    EXECUTE FUNCTION update_interface_permissions_updated_at();

-- Auto-create interface permissions for new users
CREATE OR REPLACE FUNCTION create_default_interface_permissions()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.interface_permissions (user_id, updated_by)
    VALUES (NEW.id, NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_create_default_interface_permissions
    AFTER INSERT ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION create_default_interface_permissions();

-- ================================================================
-- TABLE: customer_access_code_history
-- Purpose: Track access code changes for audit trail
-- ================================================================

CREATE TABLE IF NOT EXISTS public.customer_access_code_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    old_access_code character varying(6),
    new_access_code character varying(6) NOT NULL,
    generated_by uuid NOT NULL REFERENCES public.users(id),
    reason text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    
    -- Constraints
    CONSTRAINT customer_access_code_history_reason_check 
        CHECK (reason IN ('initial_generation', 'admin_regeneration', 'security_reset', 'customer_request'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_customer_access_code_history_customer_id ON public.customer_access_code_history(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_access_code_history_generated_by ON public.customer_access_code_history(generated_by);
CREATE INDEX IF NOT EXISTS idx_customer_access_code_history_created_at ON public.customer_access_code_history(created_at);

-- Comments
COMMENT ON TABLE public.customer_access_code_history IS 'Audit trail of customer access code changes';
COMMENT ON COLUMN public.customer_access_code_history.reason IS 'Reason for access code change';

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interface_permissions ENABLE ROW LEVEL SECURITY;

-- Customers policies
DROP POLICY IF EXISTS "customers_select_policy" ON public.customers;
CREATE POLICY "customers_select_policy" ON public.customers
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "customers_insert_policy" ON public.customers;
CREATE POLICY "customers_insert_policy" ON public.customers
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "customers_update_policy" ON public.customers;
CREATE POLICY "customers_update_policy" ON public.customers
    FOR UPDATE USING (true);

DROP POLICY IF EXISTS "customers_delete_policy" ON public.customers;
CREATE POLICY "customers_delete_policy" ON public.customers
    FOR DELETE USING (true);

-- Interface permissions policies
DROP POLICY IF EXISTS "interface_permissions_select_policy" ON public.interface_permissions;
CREATE POLICY "interface_permissions_select_policy" ON public.interface_permissions
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "interface_permissions_insert_policy" ON public.interface_permissions;
CREATE POLICY "interface_permissions_insert_policy" ON public.interface_permissions
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "interface_permissions_update_policy" ON public.interface_permissions;
CREATE POLICY "interface_permissions_update_policy" ON public.interface_permissions
    FOR UPDATE USING (true);

DROP POLICY IF EXISTS "interface_permissions_delete_policy" ON public.interface_permissions;
CREATE POLICY "interface_permissions_delete_policy" ON public.interface_permissions
    FOR DELETE USING (true);

-- Customer access code history policies
ALTER TABLE public.customer_access_code_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "customer_access_code_history_select_policy" ON public.customer_access_code_history;
CREATE POLICY "customer_access_code_history_select_policy" ON public.customer_access_code_history
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "customer_access_code_history_insert_policy" ON public.customer_access_code_history;
CREATE POLICY "customer_access_code_history_insert_policy" ON public.customer_access_code_history
    FOR INSERT WITH CHECK (true);

-- ================================================================
-- INITIAL DATA
-- ================================================================

-- Create default interface permissions for existing users (if any)
INSERT INTO public.interface_permissions (user_id, updated_by, desktop_enabled, mobile_enabled, customer_enabled)
SELECT 
    u.id as user_id,
    u.id as updated_by,
    true as desktop_enabled,
    true as mobile_enabled,
    false as customer_enabled
FROM public.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.interface_permissions ip WHERE ip.user_id = u.id
);

-- ================================================================
-- COMPLETED MIGRATION
-- ================================================================