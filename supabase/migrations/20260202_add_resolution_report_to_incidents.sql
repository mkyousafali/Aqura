-- Add resolution_report column to incidents table
-- This stores the resolution details as JSONB when an incident is resolved

ALTER TABLE public.incidents 
ADD COLUMN IF NOT EXISTS resolution_report JSONB DEFAULT NULL;

-- Add comment explaining the column
COMMENT ON COLUMN public.incidents.resolution_report IS 'Stores resolution report as JSONB with content, resolved_by, resolved_by_name, and resolved_at';

-- Create index for querying resolution data
CREATE INDEX IF NOT EXISTS idx_incidents_resolution_report 
ON public.incidents USING gin (resolution_report) 
WHERE resolution_report IS NOT NULL;
