-- Add related_party column to incidents table for storing related party details
-- This stores different data based on incident type:
-- - Customer incidents: { name, contact_number }
-- - Other incidents: { details }

ALTER TABLE public.incidents 
ADD COLUMN IF NOT EXISTS related_party JSONB DEFAULT NULL;

-- Add comment explaining the column
COMMENT ON COLUMN public.incidents.related_party IS 'Stores related party details as JSONB. For customer incidents: {name, contact_number}. For other incidents: {details}';

-- Create index for querying related party data
CREATE INDEX IF NOT EXISTS idx_incidents_related_party 
ON public.incidents USING gin (related_party) 
WHERE related_party IS NOT NULL;
