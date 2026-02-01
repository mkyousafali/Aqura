-- Create ENUM type for resolution status
CREATE TYPE public.resolution_status AS ENUM ('reported', 'claimed', 'resolved');

-- Create incidents table
CREATE TABLE IF NOT EXISTS public.incidents (
    id TEXT PRIMARY KEY,
    incident_type_id TEXT NOT NULL REFERENCES public.incident_types(id),
    employee_id TEXT NOT NULL REFERENCES public.hr_employee_master(id),
    branch_id BIGINT NOT NULL REFERENCES public.branches(id),
    violation_id TEXT REFERENCES public.warning_violation(id),
    what_happened JSONB NOT NULL,
    witness_details JSONB,
    report_type TEXT NOT NULL DEFAULT 'employee_related',
    reports_to_user_ids UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],
    claims_status TEXT,
    claimed_user_id UUID,
    resolution_status public.resolution_status NOT NULL DEFAULT 'reported',
    user_statuses JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_incidents_incident_type_id 
ON public.incidents USING btree (incident_type_id);

CREATE INDEX IF NOT EXISTS idx_incidents_employee_id 
ON public.incidents USING btree (employee_id);

CREATE INDEX IF NOT EXISTS idx_incidents_branch_id 
ON public.incidents USING btree (branch_id);

CREATE INDEX IF NOT EXISTS idx_incidents_violation_id 
ON public.incidents USING btree (violation_id);

CREATE INDEX IF NOT EXISTS idx_incidents_resolution_status 
ON public.incidents USING btree (resolution_status);

CREATE INDEX IF NOT EXISTS idx_incidents_created_at 
ON public.incidents USING btree (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_incidents_reports_to_user_ids 
ON public.incidents USING GIN (reports_to_user_ids);

-- Comments
COMMENT ON TABLE public.incidents IS 'Stores incident reports submitted by employees and other incident types';
COMMENT ON COLUMN public.incidents.id IS 'Unique identifier for incident (INS1, INS2, etc.)';
COMMENT ON COLUMN public.incidents.incident_type_id IS 'Type of incident (references incident_types table)';
COMMENT ON COLUMN public.incidents.employee_id IS 'Employee involved in or reporting the incident';
COMMENT ON COLUMN public.incidents.branch_id IS 'Branch where incident occurred';
COMMENT ON COLUMN public.incidents.violation_id IS 'Associated violation ID (for employee-related incidents)';
COMMENT ON COLUMN public.incidents.what_happened IS 'JSONB: Detailed description of what happened';
COMMENT ON COLUMN public.incidents.witness_details IS 'JSONB: Information about witnesses';
COMMENT ON COLUMN public.incidents.report_type IS 'Type of report (e.g., employee_related)';
COMMENT ON COLUMN public.incidents.reports_to_user_ids IS 'Array of user IDs who should receive this incident report';
COMMENT ON COLUMN public.incidents.claims_status IS 'Status of claims related to the incident';
COMMENT ON COLUMN public.incidents.claimed_user_id IS 'User ID of person who claimed the incident';
COMMENT ON COLUMN public.incidents.resolution_status IS 'Status: reported, claimed, or resolved';
COMMENT ON COLUMN public.incidents.user_statuses IS 'JSONB: Individual status for each user in reports_to_user_ids';
