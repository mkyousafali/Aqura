-- Create incident_actions table to track all incident-related actions (warnings, fines, etc.)

-- Create sequence for action IDs
CREATE SEQUENCE IF NOT EXISTS incident_actions_id_seq START 1;

-- Create the incident_actions table
CREATE TABLE IF NOT EXISTS incident_actions (
    id TEXT PRIMARY KEY DEFAULT 'ACT' || nextval('incident_actions_id_seq'),
    action_type TEXT NOT NULL CHECK (action_type IN ('warning', 'investigation', 'termination', 'other')),
    recourse_type TEXT CHECK (recourse_type IN ('warning', 'warning_fine', 'warning_fine_threat', 'warning_fine_termination_threat', 'termination')),
    
    -- The generated report/action content
    action_report JSONB DEFAULT NULL,
    
    -- Fine related fields
    has_fine BOOLEAN DEFAULT FALSE,
    fine_amount NUMERIC(10,2) DEFAULT 0,
    fine_threat_amount NUMERIC(10,2) DEFAULT 0,
    is_paid BOOLEAN DEFAULT FALSE,
    paid_at TIMESTAMPTZ DEFAULT NULL,
    paid_by TEXT DEFAULT NULL,
    
    -- Relations
    employee_id TEXT NOT NULL,
    incident_id TEXT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    incident_type_id TEXT REFERENCES incident_types(id),
    
    -- Audit fields
    created_by TEXT DEFAULT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_incident_actions_employee_id ON incident_actions(employee_id);
CREATE INDEX IF NOT EXISTS idx_incident_actions_incident_id ON incident_actions(incident_id);
CREATE INDEX IF NOT EXISTS idx_incident_actions_is_paid ON incident_actions(is_paid);
CREATE INDEX IF NOT EXISTS idx_incident_actions_has_fine ON incident_actions(has_fine);
CREATE INDEX IF NOT EXISTS idx_incident_actions_action_type ON incident_actions(action_type);

-- Add comments
COMMENT ON TABLE incident_actions IS 'Tracks all actions taken on incidents including warnings, fines, and their payment status';
COMMENT ON COLUMN incident_actions.id IS 'Auto-generated ID in format ACT1, ACT2, etc.';
COMMENT ON COLUMN incident_actions.action_type IS 'Type of action: warning, investigation, termination, other';
COMMENT ON COLUMN incident_actions.recourse_type IS 'Type of recourse for warnings';
COMMENT ON COLUMN incident_actions.action_report IS 'Full action/warning report as JSONB';
COMMENT ON COLUMN incident_actions.has_fine IS 'Whether this action includes a fine';
COMMENT ON COLUMN incident_actions.fine_amount IS 'Fine amount if applicable';
COMMENT ON COLUMN incident_actions.fine_threat_amount IS 'Threatened fine amount for warning_fine_threat type';
COMMENT ON COLUMN incident_actions.is_paid IS 'Whether the fine has been paid';
COMMENT ON COLUMN incident_actions.paid_at IS 'When the fine was paid';
COMMENT ON COLUMN incident_actions.paid_by IS 'User ID who marked the fine as paid';

-- Enable RLS
ALTER TABLE incident_actions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Enable read access for authenticated users" ON incident_actions
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable insert for authenticated users" ON incident_actions
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON incident_actions
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE incident_actions;
