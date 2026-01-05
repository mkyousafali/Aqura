-- =============================================
-- BOX OPERATIONS TABLE
-- Created: 2026-01-05
-- Description: Tracks POS cash box operations (counter check sessions)
-- =============================================

CREATE TABLE IF NOT EXISTS box_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Box identification
    box_number SMALLINT NOT NULL CHECK (box_number >= 1 AND box_number <= 9),
    branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Related denomination record (the advance_box record)
    denomination_record_id UUID NOT NULL REFERENCES denomination_records(id) ON DELETE CASCADE,
    
    -- Counter check details
    counts_before JSONB NOT NULL,              -- Original box counts
    counts_after JSONB NOT NULL,               -- Real count entered by cashier
    total_before DECIMAL(15, 2) NOT NULL,      -- Original box total
    total_after DECIMAL(15, 2) NOT NULL,       -- Real count total
    difference DECIMAL(15, 2) NOT NULL,        -- Difference (total_before - total_after)
    
    -- Match status
    is_matched BOOLEAN NOT NULL,               -- True if matched, false if not
    
    -- Operation status
    status VARCHAR(20) NOT NULL DEFAULT 'in_use' CHECK (status IN (
        'in_use',         -- Currently active operation
        'pending_close',  -- Waiting for final close in POS Collection Manager
        'completed',      -- Operation fully completed and closed
        'cancelled'       -- Operation cancelled
    )),
    
    -- Timestamps
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_box_operations_box ON box_operations(box_number);
CREATE INDEX IF NOT EXISTS idx_box_operations_branch ON box_operations(branch_id);
CREATE INDEX IF NOT EXISTS idx_box_operations_user ON box_operations(user_id);
CREATE INDEX IF NOT EXISTS idx_box_operations_status ON box_operations(status);
CREATE INDEX IF NOT EXISTS idx_box_operations_start_time ON box_operations(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_box_operations_denomination ON box_operations(denomination_record_id);
CREATE INDEX IF NOT EXISTS idx_box_operations_active ON box_operations(branch_id, status) WHERE status = 'in_use';

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
ALTER TABLE box_operations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "box_operations_select" ON box_operations;
DROP POLICY IF EXISTS "box_operations_insert" ON box_operations;
DROP POLICY IF EXISTS "box_operations_update" ON box_operations;
DROP POLICY IF EXISTS "box_operations_delete" ON box_operations;

CREATE POLICY "box_operations_select" ON box_operations
    FOR SELECT
    USING (true);

CREATE POLICY "box_operations_insert" ON box_operations
    FOR INSERT
    WITH CHECK (true);

CREATE POLICY "box_operations_update" ON box_operations
    FOR UPDATE
    USING (true);

CREATE POLICY "box_operations_delete" ON box_operations
    FOR DELETE
    USING (true);

-- =============================================
-- GRANT PERMISSIONS
-- =============================================
GRANT ALL ON box_operations TO anon;
GRANT ALL ON box_operations TO authenticated;
GRANT ALL ON box_operations TO service_role;

-- =============================================
-- TRIGGER: Update updated_at timestamp
-- =============================================
CREATE OR REPLACE FUNCTION update_box_operations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS box_operations_updated_at ON box_operations;

CREATE TRIGGER box_operations_updated_at
    BEFORE UPDATE ON box_operations
    FOR EACH ROW
    EXECUTE FUNCTION update_box_operations_updated_at();

-- =============================================
-- COMMENTS
-- =============================================
COMMENT ON TABLE box_operations IS 'Tracks POS cash box operations and counter check sessions';
COMMENT ON COLUMN box_operations.status IS 'Operation status: in_use (active), completed, or cancelled';
COMMENT ON COLUMN box_operations.is_matched IS 'True if counter check matched, false if there was a difference';
COMMENT ON COLUMN box_operations.difference IS 'Difference between before and after totals (before - after)';

-- =============================================
-- ENABLE REALTIME
-- =============================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'box_operations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE box_operations;
    END IF;
END $$;
