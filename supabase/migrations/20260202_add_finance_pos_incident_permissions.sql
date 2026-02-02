-- Add incident report receiver permission columns for Finance and Customer/POS incident types
ALTER TABLE public.approval_permissions
ADD COLUMN IF NOT EXISTS can_receive_finance_incidents boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS can_receive_pos_incidents boolean NOT NULL DEFAULT false;

-- Create indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_approval_permissions_finance_incidents 
ON public.approval_permissions USING btree (can_receive_finance_incidents) 
TABLESPACE pg_default
WHERE (can_receive_finance_incidents = true AND is_active = true);

CREATE INDEX IF NOT EXISTS idx_approval_permissions_pos_incidents 
ON public.approval_permissions USING btree (can_receive_pos_incidents) 
TABLESPACE pg_default
WHERE (can_receive_pos_incidents = true AND is_active = true);

-- Comments on the columns
COMMENT ON COLUMN public.approval_permissions.can_receive_finance_incidents IS 'Permission to receive and review finance department incident reports (IN8)';
COMMENT ON COLUMN public.approval_permissions.can_receive_pos_incidents IS 'Permission to receive and review customer/POS incident reports (IN9)';
