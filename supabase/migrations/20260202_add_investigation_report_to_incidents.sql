-- Add investigation_report JSONB column to incidents table
ALTER TABLE incidents 
ADD COLUMN IF NOT EXISTS investigation_report JSONB DEFAULT NULL;

-- Add comment
COMMENT ON COLUMN incidents.investigation_report IS 'Stores investigation report details as JSON';
