-- Migration 3: Create Variation Audit Log Table
-- This migration creates a table to track all variation group changes

-- Create variation_audit_log table
CREATE TABLE IF NOT EXISTS variation_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_type TEXT NOT NULL CHECK (action_type IN (
    'create_group',
    'edit_group',
    'delete_group',
    'add_variation',
    'remove_variation',
    'reorder_variations',
    'change_parent',
    'update_image_override'
  )),
  variation_group_id UUID,
  affected_barcodes TEXT[],
  parent_barcode TEXT,
  group_name_en TEXT,
  group_name_ar TEXT,
  user_id UUID REFERENCES users(id),
  timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes for audit log queries
CREATE INDEX IF NOT EXISTS idx_variation_audit_log_timestamp 
  ON variation_audit_log(timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_variation_audit_log_user_id 
  ON variation_audit_log(user_id);

CREATE INDEX IF NOT EXISTS idx_variation_audit_log_action_type 
  ON variation_audit_log(action_type);

CREATE INDEX IF NOT EXISTS idx_variation_audit_log_variation_group_id 
  ON variation_audit_log(variation_group_id) 
  WHERE variation_group_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_variation_audit_log_parent_barcode 
  ON variation_audit_log(parent_barcode) 
  WHERE parent_barcode IS NOT NULL;

-- Add comment documentation
COMMENT ON TABLE variation_audit_log IS 'Audit trail for all variation group operations';
COMMENT ON COLUMN variation_audit_log.action_type IS 'Type of action performed on variation group';
COMMENT ON COLUMN variation_audit_log.variation_group_id IS 'UUID of the variation group affected';
COMMENT ON COLUMN variation_audit_log.affected_barcodes IS 'Array of product barcodes affected by this action';
COMMENT ON COLUMN variation_audit_log.parent_barcode IS 'Parent product barcode for reference';
COMMENT ON COLUMN variation_audit_log.group_name_en IS 'English name of the group at time of action';
COMMENT ON COLUMN variation_audit_log.group_name_ar IS 'Arabic name of the group at time of action';
COMMENT ON COLUMN variation_audit_log.user_id IS 'User who performed the action';
COMMENT ON COLUMN variation_audit_log.details IS 'Additional details stored as JSON (before/after state, etc.)';
