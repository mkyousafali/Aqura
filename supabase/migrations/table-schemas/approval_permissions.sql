-- ================================================================
-- TABLE SCHEMA: approval_permissions
-- Generated: 2025-11-06T11:09:38.999Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.approval_permissions (
    id bigint NOT NULL DEFAULT nextval('approval_permissions_id_seq'::regclass),
    user_id uuid NOT NULL,
    can_approve_requisitions boolean NOT NULL DEFAULT false,
    requisition_amount_limit numeric DEFAULT 0.00,
    can_approve_single_bill boolean NOT NULL DEFAULT false,
    single_bill_amount_limit numeric DEFAULT 0.00,
    can_approve_multiple_bill boolean NOT NULL DEFAULT false,
    multiple_bill_amount_limit numeric DEFAULT 0.00,
    can_approve_recurring_bill boolean NOT NULL DEFAULT false,
    recurring_bill_amount_limit numeric DEFAULT 0.00,
    can_approve_vendor_payments boolean NOT NULL DEFAULT false,
    vendor_payment_amount_limit numeric DEFAULT 0.00,
    can_approve_leave_requests boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    updated_by uuid,
    is_active boolean NOT NULL DEFAULT true
);

-- Table comment
COMMENT ON TABLE public.approval_permissions IS 'Table for approval permissions management';

-- Column comments
COMMENT ON COLUMN public.approval_permissions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.approval_permissions.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.approval_permissions.can_approve_requisitions IS 'Boolean flag';
COMMENT ON COLUMN public.approval_permissions.requisition_amount_limit IS 'Monetary amount';
COMMENT ON COLUMN public.approval_permissions.can_approve_single_bill IS 'Boolean flag';
COMMENT ON COLUMN public.approval_permissions.single_bill_amount_limit IS 'Monetary amount';
COMMENT ON COLUMN public.approval_permissions.can_approve_multiple_bill IS 'Boolean flag';
COMMENT ON COLUMN public.approval_permissions.multiple_bill_amount_limit IS 'Monetary amount';
COMMENT ON COLUMN public.approval_permissions.can_approve_recurring_bill IS 'Boolean flag';
COMMENT ON COLUMN public.approval_permissions.recurring_bill_amount_limit IS 'Monetary amount';
COMMENT ON COLUMN public.approval_permissions.can_approve_vendor_payments IS 'Boolean flag';
COMMENT ON COLUMN public.approval_permissions.vendor_payment_amount_limit IS 'Monetary amount';
COMMENT ON COLUMN public.approval_permissions.can_approve_leave_requests IS 'Boolean flag';
COMMENT ON COLUMN public.approval_permissions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.approval_permissions.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.approval_permissions.created_by IS 'created by field';
COMMENT ON COLUMN public.approval_permissions.updated_by IS 'Date field';
COMMENT ON COLUMN public.approval_permissions.is_active IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS approval_permissions_pkey ON public.approval_permissions USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_approval_permissions_user_id ON public.approval_permissions USING btree (user_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for approval_permissions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.approval_permissions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "approval_permissions_select_policy" ON public.approval_permissions
    FOR SELECT USING (true);

CREATE POLICY "approval_permissions_insert_policy" ON public.approval_permissions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "approval_permissions_update_policy" ON public.approval_permissions
    FOR UPDATE USING (true);

CREATE POLICY "approval_permissions_delete_policy" ON public.approval_permissions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for approval_permissions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.approval_permissions (user_id, can_approve_requisitions, requisition_amount_limit)
VALUES ('uuid-example', true, 123);
*/

-- Select example
/*
SELECT * FROM public.approval_permissions 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.approval_permissions 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF APPROVAL_PERMISSIONS SCHEMA
-- ================================================================
