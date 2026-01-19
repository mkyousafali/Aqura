-- Add can_add_missing_punches permission to approval_permissions table

ALTER TABLE approval_permissions 
ADD COLUMN can_add_missing_punches boolean NOT NULL DEFAULT false;

-- Create index for the new permission
CREATE INDEX IF NOT EXISTS idx_approval_permissions_add_missing_punches ON approval_permissions 
USING btree (can_add_missing_punches) 
WHERE (can_add_missing_punches = true AND is_active = true);
