-- Remove old single column if it exists
ALTER TABLE public.approval_permissions
DROP COLUMN IF EXISTS can_receive_incident_reports;

-- Add incident report receiver permission columns for each incident type
ALTER TABLE public.approval_permissions
ADD COLUMN IF NOT EXISTS can_receive_customer_incidents boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS can_receive_employee_incidents boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS can_receive_maintenance_incidents boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS can_receive_vendor_incidents boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS can_receive_vehicle_incidents boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS can_receive_government_incidents boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS can_receive_other_incidents boolean NOT NULL DEFAULT false;

-- Create indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_approval_permissions_customer_incidents 
ON public.approval_permissions USING btree (can_receive_customer_incidents) 
TABLESPACE pg_default
WHERE (can_receive_customer_incidents = true AND is_active = true);

CREATE INDEX IF NOT EXISTS idx_approval_permissions_employee_incidents 
ON public.approval_permissions USING btree (can_receive_employee_incidents) 
TABLESPACE pg_default
WHERE (can_receive_employee_incidents = true AND is_active = true);

CREATE INDEX IF NOT EXISTS idx_approval_permissions_maintenance_incidents 
ON public.approval_permissions USING btree (can_receive_maintenance_incidents) 
TABLESPACE pg_default
WHERE (can_receive_maintenance_incidents = true AND is_active = true);

CREATE INDEX IF NOT EXISTS idx_approval_permissions_vendor_incidents 
ON public.approval_permissions USING btree (can_receive_vendor_incidents) 
TABLESPACE pg_default
WHERE (can_receive_vendor_incidents = true AND is_active = true);

CREATE INDEX IF NOT EXISTS idx_approval_permissions_vehicle_incidents 
ON public.approval_permissions USING btree (can_receive_vehicle_incidents) 
TABLESPACE pg_default
WHERE (can_receive_vehicle_incidents = true AND is_active = true);

CREATE INDEX IF NOT EXISTS idx_approval_permissions_government_incidents 
ON public.approval_permissions USING btree (can_receive_government_incidents) 
TABLESPACE pg_default
WHERE (can_receive_government_incidents = true AND is_active = true);

CREATE INDEX IF NOT EXISTS idx_approval_permissions_other_incidents 
ON public.approval_permissions USING btree (can_receive_other_incidents) 
TABLESPACE pg_default
WHERE (can_receive_other_incidents = true AND is_active = true);

-- Comments on the columns
COMMENT ON COLUMN public.approval_permissions.can_receive_customer_incidents IS 'Permission to receive and review customer-related incident reports';
COMMENT ON COLUMN public.approval_permissions.can_receive_employee_incidents IS 'Permission to receive and review employee-related incident reports';
COMMENT ON COLUMN public.approval_permissions.can_receive_maintenance_incidents IS 'Permission to receive and review maintenance-related incident reports';
COMMENT ON COLUMN public.approval_permissions.can_receive_vendor_incidents IS 'Permission to receive and review vendor-related incident reports';
COMMENT ON COLUMN public.approval_permissions.can_receive_vehicle_incidents IS 'Permission to receive and review vehicle-related incident reports';
COMMENT ON COLUMN public.approval_permissions.can_receive_government_incidents IS 'Permission to receive and review government-related incident reports';
COMMENT ON COLUMN public.approval_permissions.can_receive_other_incidents IS 'Permission to receive and review other types of incident reports';
