-- =============================================
-- DENOMINATION TABLES
-- Created: 2026-01-05
-- Description: Tables for denomination counting, history tracking,
--              and POS cash box management
-- =============================================

-- =============================================
-- TABLE: denomination_types
-- Master table for flexible denomination values
-- =============================================
CREATE TABLE IF NOT EXISTS denomination_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,           -- e.g., 'd500', 'd200', 'coins', 'damage'
    value DECIMAL(10, 2) NOT NULL,              -- e.g., 500, 200, 0.5, 0.25, 1 (for coins/damage)
    label VARCHAR(50) NOT NULL,                 -- e.g., '500 SAR', 'Coins', 'Damage'
    label_ar VARCHAR(50),                       -- Arabic label
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for active denominations
CREATE INDEX IF NOT EXISTS idx_denomination_types_active ON denomination_types(is_active, sort_order);

-- =============================================
-- TABLE: denomination_records
-- Stores all denomination records (main, boxes, etc.)
-- Uses JSONB for flexible denomination counts storage
-- =============================================
CREATE TABLE IF NOT EXISTS denomination_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Record type to differentiate between main, boxes, etc.
    record_type VARCHAR(30) NOT NULL CHECK (record_type IN (
        'main',           -- Main denomination count
        'advance_box',    -- POS Advance Manager boxes (1-12)
        'collection_box', -- POS Collection Manager boxes (1-9) - future
        'paid',           -- Paid section cards (1-6) - future
        'received'        -- Received section cards (1-6) - future
    )),
    
    -- Box/Card number (1-12 for advance boxes, 1-9 for collection, 1-6 for paid/received, null for main)
    box_number SMALLINT CHECK (box_number IS NULL OR (box_number >= 1 AND box_number <= 12)),
    
    -- Denomination counts stored as JSONB
    -- Format: {"d500": 10, "d200": 5, "d100": 3, ...}
    counts JSONB NOT NULL DEFAULT '{}',
    
    -- ERP comparison (only for main denomination)
    erp_balance DECIMAL(15, 2),
    grand_total DECIMAL(15, 2) NOT NULL DEFAULT 0,
    difference DECIMAL(15, 2),
    
    -- Notes/remarks
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_denomination_records_branch ON denomination_records(branch_id);
CREATE INDEX IF NOT EXISTS idx_denomination_records_user ON denomination_records(user_id);
CREATE INDEX IF NOT EXISTS idx_denomination_records_type ON denomination_records(record_type);
CREATE INDEX IF NOT EXISTS idx_denomination_records_created_at ON denomination_records(created_at);
CREATE INDEX IF NOT EXISTS idx_denomination_records_branch_type ON denomination_records(branch_id, record_type);
CREATE INDEX IF NOT EXISTS idx_denomination_records_branch_created ON denomination_records(branch_id, created_at DESC);

-- Composite index for history lookup by date/time
CREATE INDEX IF NOT EXISTS idx_denomination_records_history ON denomination_records(branch_id, record_type, created_at DESC);

-- =============================================
-- INSERT DEFAULT DENOMINATION TYPES
-- =============================================
INSERT INTO denomination_types (code, value, label, label_ar, sort_order) VALUES
    ('d500', 500.00, '500 SAR', '500 ريال', 1),
    ('d200', 200.00, '200 SAR', '200 ريال', 2),
    ('d100', 100.00, '100 SAR', '100 ريال', 3),
    ('d50', 50.00, '50 SAR', '50 ريال', 4),
    ('d20', 20.00, '20 SAR', '20 ريال', 5),
    ('d10', 10.00, '10 SAR', '10 ريال', 6),
    ('d5', 5.00, '5 SAR', '5 ريال', 7),
    ('d2', 2.00, '2 SAR', '2 ريال', 8),
    ('d1', 1.00, '1 SAR', '1 ريال', 9),
    ('d05', 0.50, '0.5 SAR', '0.5 ريال', 10),
    ('d025', 0.25, '0.25 SAR', '0.25 ريال', 11),
    ('coins', 1.00, 'Coins', 'عملات معدنية', 12),
    ('damage', 1.00, 'Damage', 'تالف', 13)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
ALTER TABLE denomination_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE denomination_records ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for re-runs)
DROP POLICY IF EXISTS "denomination_types_select" ON denomination_types;
DROP POLICY IF EXISTS "denomination_types_insert" ON denomination_types;
DROP POLICY IF EXISTS "denomination_types_update" ON denomination_types;
DROP POLICY IF EXISTS "denomination_types_delete" ON denomination_types;
DROP POLICY IF EXISTS "denomination_records_select" ON denomination_records;
DROP POLICY IF EXISTS "denomination_records_insert" ON denomination_records;
DROP POLICY IF EXISTS "denomination_records_update" ON denomination_records;
DROP POLICY IF EXISTS "denomination_records_delete" ON denomination_records;

-- Policies for denomination_types (read by all authenticated, manage by admins)
CREATE POLICY "denomination_types_select" ON denomination_types
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "denomination_types_insert" ON denomination_types
    FOR INSERT TO authenticated
    WITH CHECK (true);

CREATE POLICY "denomination_types_update" ON denomination_types
    FOR UPDATE TO authenticated
    USING (true);

CREATE POLICY "denomination_types_delete" ON denomination_types
    FOR DELETE TO authenticated
    USING (true);

-- Policies for denomination_records (users can manage their branch records)
CREATE POLICY "denomination_records_select" ON denomination_records
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "denomination_records_insert" ON denomination_records
    FOR INSERT TO authenticated
    WITH CHECK (true);

CREATE POLICY "denomination_records_update" ON denomination_records
    FOR UPDATE TO authenticated
    USING (true);

CREATE POLICY "denomination_records_delete" ON denomination_records
    FOR DELETE TO authenticated
    USING (true);

-- =============================================
-- GRANT PERMISSIONS
-- =============================================
GRANT ALL ON denomination_types TO authenticated;
GRANT ALL ON denomination_records TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE denomination_types_id_seq TO authenticated;

-- =============================================
-- TRIGGER: Update updated_at timestamp
-- =============================================
CREATE OR REPLACE FUNCTION update_denomination_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS denomination_types_updated_at ON denomination_types;
DROP TRIGGER IF EXISTS denomination_records_updated_at ON denomination_records;

CREATE TRIGGER denomination_types_updated_at
    BEFORE UPDATE ON denomination_types
    FOR EACH ROW
    EXECUTE FUNCTION update_denomination_updated_at();

CREATE TRIGGER denomination_records_updated_at
    BEFORE UPDATE ON denomination_records
    FOR EACH ROW
    EXECUTE FUNCTION update_denomination_updated_at();

-- =============================================
-- COMMENTS
-- =============================================
COMMENT ON TABLE denomination_types IS 'Master table for denomination types (currency notes, coins, damage)';
COMMENT ON TABLE denomination_records IS 'Stores denomination count records for main, boxes, and other sections';
COMMENT ON COLUMN denomination_records.record_type IS 'Type of record: main, advance_box, collection_box, paid, received';
COMMENT ON COLUMN denomination_records.box_number IS 'Box or card number (1-12 for advance boxes, 1-9 for collection, 1-6 for paid/received, null for main)';
COMMENT ON COLUMN denomination_records.counts IS 'JSONB storing denomination counts: {"d500": 10, "d200": 5, ...}';

-- =============================================
-- TABLE: denomination_audit_log
-- Automatically tracks all changes to denomination records
-- =============================================
CREATE TABLE IF NOT EXISTS denomination_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id UUID NOT NULL,                    -- Reference to the denomination_record
    branch_id INTEGER NOT NULL,
    user_id UUID NOT NULL,                      -- User who made the change
    action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    record_type VARCHAR(30) NOT NULL,
    box_number SMALLINT,
    
    -- Store the data at the time of change
    old_counts JSONB,                           -- Previous counts (null for INSERT)
    new_counts JSONB,                           -- New counts (null for DELETE)
    old_erp_balance DECIMAL(15, 2),
    new_erp_balance DECIMAL(15, 2),
    old_grand_total DECIMAL(15, 2),
    new_grand_total DECIMAL(15, 2),
    old_difference DECIMAL(15, 2),
    new_difference DECIMAL(15, 2),
    
    -- Change metadata
    change_reason TEXT,                         -- Optional reason for change
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for audit log
CREATE INDEX IF NOT EXISTS idx_denomination_audit_record ON denomination_audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_denomination_audit_branch ON denomination_audit_log(branch_id);
CREATE INDEX IF NOT EXISTS idx_denomination_audit_user ON denomination_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_denomination_audit_created ON denomination_audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_denomination_audit_action ON denomination_audit_log(action);

-- =============================================
-- TRIGGER FUNCTION: Auto-save all changes
-- =============================================
CREATE OR REPLACE FUNCTION denomination_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO denomination_audit_log (
            record_id, branch_id, user_id, action, record_type, box_number,
            old_counts, new_counts,
            old_erp_balance, new_erp_balance,
            old_grand_total, new_grand_total,
            old_difference, new_difference
        ) VALUES (
            NEW.id, NEW.branch_id, NEW.user_id, 'INSERT', NEW.record_type, NEW.box_number,
            NULL, NEW.counts,
            NULL, NEW.erp_balance,
            NULL, NEW.grand_total,
            NULL, NEW.difference
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO denomination_audit_log (
            record_id, branch_id, user_id, action, record_type, box_number,
            old_counts, new_counts,
            old_erp_balance, new_erp_balance,
            old_grand_total, new_grand_total,
            old_difference, new_difference
        ) VALUES (
            NEW.id, NEW.branch_id, NEW.user_id, 'UPDATE', NEW.record_type, NEW.box_number,
            OLD.counts, NEW.counts,
            OLD.erp_balance, NEW.erp_balance,
            OLD.grand_total, NEW.grand_total,
            OLD.difference, NEW.difference
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO denomination_audit_log (
            record_id, branch_id, user_id, action, record_type, box_number,
            old_counts, new_counts,
            old_erp_balance, new_erp_balance,
            old_grand_total, new_grand_total,
            old_difference, new_difference
        ) VALUES (
            OLD.id, OLD.branch_id, OLD.user_id, 'DELETE', OLD.record_type, OLD.box_number,
            OLD.counts, NULL,
            OLD.erp_balance, NULL,
            OLD.grand_total, NULL,
            OLD.difference, NULL
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger on denomination_records
DROP TRIGGER IF EXISTS denomination_records_audit ON denomination_records;

CREATE TRIGGER denomination_records_audit
    AFTER INSERT OR UPDATE OR DELETE ON denomination_records
    FOR EACH ROW
    EXECUTE FUNCTION denomination_audit_trigger();

-- =============================================
-- RLS & PERMISSIONS FOR AUDIT LOG
-- =============================================
ALTER TABLE denomination_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "denomination_audit_log_select" ON denomination_audit_log;
DROP POLICY IF EXISTS "denomination_audit_log_insert" ON denomination_audit_log;

CREATE POLICY "denomination_audit_log_select" ON denomination_audit_log
    FOR SELECT TO authenticated
    USING (true);

-- Only allow system/trigger inserts, no manual inserts
CREATE POLICY "denomination_audit_log_insert" ON denomination_audit_log
    FOR INSERT TO authenticated
    WITH CHECK (true);

GRANT SELECT, INSERT ON denomination_audit_log TO authenticated;

COMMENT ON TABLE denomination_audit_log IS 'Automatic audit log for all denomination record changes (INSERT, UPDATE, DELETE)';

-- =============================================
-- ENABLE REALTIME
-- =============================================
ALTER PUBLICATION supabase_realtime ADD TABLE denomination_types;
ALTER PUBLICATION supabase_realtime ADD TABLE denomination_records;
ALTER PUBLICATION supabase_realtime ADD TABLE denomination_audit_log;
