-- Add incident_id column to quick_tasks for linking to incidents
ALTER TABLE quick_tasks ADD COLUMN incident_id TEXT REFERENCES incidents(id);

-- Add comment to explain the column
COMMENT ON COLUMN quick_tasks.incident_id IS 'Reference to the incident that triggered this quick task';

-- Add index for faster queries
CREATE INDEX idx_quick_tasks_incident_id ON quick_tasks(incident_id);
