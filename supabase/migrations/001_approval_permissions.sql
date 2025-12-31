-- Approval Permissions Table Schema
CREATE TABLE IF NOT EXISTS approval_permissions (
  id BIGINT PRIMARY KEY DEFAULT nextval('approval_permissions_id_seq'),
  user_id UUID NOT NULL,
  can_approve_requisitions BOOLEAN NOT NULL DEFAULT false,
  requisition_amount_limit NUMERIC DEFAULT 0.00,
  can_approve_single_bill BOOLEAN NOT NULL DEFAULT false,
  single_bill_amount_limit NUMERIC DEFAULT 0.00,
  can_approve_multiple_bill BOOLEAN NOT NULL DEFAULT false,
  multiple_bill_amount_limit NUMERIC DEFAULT 0.00,
  can_approve_recurring_bill BOOLEAN NOT NULL DEFAULT false,
  recurring_bill_amount_limit NUMERIC DEFAULT 0.00,
  can_approve_vendor_payments BOOLEAN NOT NULL DEFAULT false,
  vendor_payment_amount_limit NUMERIC DEFAULT 0.00,
  can_approve_leave_requests BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID,
  updated_by UUID,
  is_active BOOLEAN NOT NULL DEFAULT true
);
