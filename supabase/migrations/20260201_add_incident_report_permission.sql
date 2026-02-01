-- Add incident report receiver permission column to approval_permissions table
ALTER TABLE public.approval_permissions
ADD COLUMN IF NOT EXISTS can_receive_incident_reports boolean NOT NULL DEFAULT false;

-- Create index for the new column
CREATE INDEX IF NOT EXISTS idx_approval_permissions_receive_incidents 
ON public.approval_permissions USING btree (can_receive_incident_reports) 
TABLESPACE pg_default
WHERE (can_receive_incident_reports = true AND is_active = true);

-- Comment on the column
COMMENT ON COLUMN public.approval_permissions.can_receive_incident_reports IS 'Permission to receive and review HR incident reports submitted by employees';
