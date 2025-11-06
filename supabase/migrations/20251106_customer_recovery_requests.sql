-- ================================================================
-- MIGRATION: Add Customer Recovery Requests Table
-- Created: 2025-11-06
-- Description: Creates table to track customer account recovery requests
-- ================================================================

-- ================================================================
-- TABLE: customer_recovery_requests
-- Purpose: Store customer account recovery requests for admin processing
-- ================================================================

CREATE TABLE IF NOT EXISTS public.customer_recovery_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    whatsapp_number character varying(20) NOT NULL,
    customer_name text NOT NULL,
    request_type text NOT NULL DEFAULT 'account_recovery',
    verification_status text NOT NULL DEFAULT 'pending',
    verification_notes text,
    processed_by uuid REFERENCES public.users(id),
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- Constraints
    CONSTRAINT customer_recovery_requests_request_type_check 
        CHECK (request_type IN ('account_recovery', 'access_code_request')),
    CONSTRAINT customer_recovery_requests_verification_status_check 
        CHECK (verification_status IN ('pending', 'verified', 'rejected', 'processed'))
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_customer_recovery_requests_customer_id ON public.customer_recovery_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_recovery_requests_whatsapp ON public.customer_recovery_requests(whatsapp_number);
CREATE INDEX IF NOT EXISTS idx_customer_recovery_requests_verification_status ON public.customer_recovery_requests(verification_status);
CREATE INDEX IF NOT EXISTS idx_customer_recovery_requests_processed_by ON public.customer_recovery_requests(processed_by);
CREATE INDEX IF NOT EXISTS idx_customer_recovery_requests_created_at ON public.customer_recovery_requests(created_at);

-- Comments
COMMENT ON TABLE public.customer_recovery_requests IS 'Customer account recovery requests for admin processing';
COMMENT ON COLUMN public.customer_recovery_requests.request_type IS 'Type of recovery request';
COMMENT ON COLUMN public.customer_recovery_requests.verification_status IS 'Admin verification status';

-- ================================================================
-- TRIGGERS
-- ================================================================

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_customer_recovery_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_update_customer_recovery_requests_updated_at
    BEFORE UPDATE ON public.customer_recovery_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_recovery_requests_updated_at();

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.customer_recovery_requests ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies
DROP POLICY IF EXISTS "customer_recovery_requests_select_policy" ON public.customer_recovery_requests;
CREATE POLICY "customer_recovery_requests_select_policy" ON public.customer_recovery_requests
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "customer_recovery_requests_insert_policy" ON public.customer_recovery_requests;
CREATE POLICY "customer_recovery_requests_insert_policy" ON public.customer_recovery_requests
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "customer_recovery_requests_update_policy" ON public.customer_recovery_requests;
CREATE POLICY "customer_recovery_requests_update_policy" ON public.customer_recovery_requests
    FOR UPDATE USING (true);

DROP POLICY IF EXISTS "customer_recovery_requests_delete_policy" ON public.customer_recovery_requests;
CREATE POLICY "customer_recovery_requests_delete_policy" ON public.customer_recovery_requests
    FOR DELETE USING (true);

-- ================================================================
-- COMPLETED MIGRATION
-- ================================================================