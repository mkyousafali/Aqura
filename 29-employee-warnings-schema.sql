-- Employee Warnings and Fines Tracking Schema
-- This table tracks all warning records issued to employees with fine information

-- ===============================================
-- Employee Warnings Table
-- ===============================================
CREATE TABLE IF NOT EXISTS employee_warnings (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    
    -- User and Employee Information
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES hr_employees(id) ON DELETE SET NULL,
    username VARCHAR(255), -- Fallback if no employee mapping
    
    -- Warning Details
    warning_type VARCHAR(50) NOT NULL CHECK (warning_type IN (
        'overall_performance_no_fine',
        'overall_performance_fine_threat', 
        'overall_performance_with_fine'
    )),
    
    -- Fine Information
    has_fine BOOLEAN DEFAULT FALSE,
    fine_amount DECIMAL(10,2) DEFAULT NULL,
    fine_currency VARCHAR(3) DEFAULT 'USD',
    fine_status VARCHAR(20) DEFAULT 'pending' CHECK (fine_status IN ('pending', 'paid', 'waived', 'cancelled')),
    fine_due_date DATE DEFAULT NULL,
    fine_paid_date TIMESTAMP DEFAULT NULL,
    fine_paid_amount DECIMAL(10,2) DEFAULT NULL,
    
    -- Warning Content
    warning_text TEXT NOT NULL,
    language_code VARCHAR(5) NOT NULL DEFAULT 'en',
    
    -- Task Information (for task-specific warnings) - Made optional as tasks table may not exist
    task_id UUID NULL, -- No foreign key constraint as tasks table may not exist yet
    task_title VARCHAR(500),
    task_description TEXT,
    assignment_id UUID NULL, -- No foreign key constraint as task_assignments table may not exist yet
    
    -- Performance Data (snapshot at time of warning)
    total_tasks_assigned INTEGER DEFAULT 0,
    total_tasks_completed INTEGER DEFAULT 0,
    total_tasks_overdue INTEGER DEFAULT 0,
    completion_rate DECIMAL(5,2) DEFAULT 0,
    
    -- Administrative Information
    issued_by UUID REFERENCES users(id) ON DELETE SET NULL,
    issued_by_username VARCHAR(255),
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Workflow and Status
    warning_status VARCHAR(20) DEFAULT 'active' CHECK (warning_status IN ('active', 'acknowledged', 'resolved', 'escalated', 'cancelled')),
    acknowledged_at TIMESTAMP DEFAULT NULL,
    acknowledged_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Resolution Information
    resolved_at TIMESTAMP DEFAULT NULL,
    resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    resolution_notes TEXT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Branch and Department Context - Updated to match existing schema
    branch_id BIGINT REFERENCES branches(id) ON DELETE SET NULL, -- Changed from UUID to BIGINT to match branches.id
    department_id UUID NULL, -- Made optional as hr_departments table may not exist yet
    
    -- Additional Context
    severity_level VARCHAR(10) DEFAULT 'medium' CHECK (severity_level IN ('low', 'medium', 'high', 'critical')),
    follow_up_required BOOLEAN DEFAULT FALSE,
    follow_up_date DATE DEFAULT NULL,
    
    -- Audit Trail
    warning_reference VARCHAR(50) UNIQUE, -- Auto-generated reference number
    warning_document_url TEXT, -- Link to generated warning document
    
    -- System Fields
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP DEFAULT NULL,
    deleted_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- ===============================================
-- Indexes for Performance
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_id ON employee_warnings(user_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_employee_id ON employee_warnings(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_username ON employee_warnings(username);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_type ON employee_warnings(warning_type);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_status ON employee_warnings(warning_status);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_has_fine ON employee_warnings(has_fine);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_status ON employee_warnings(fine_status);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_at ON employee_warnings(issued_at);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_task_id ON employee_warnings(task_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_assignment_id ON employee_warnings(assignment_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_branch_id ON employee_warnings(branch_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_reference ON employee_warnings(warning_reference);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_deleted ON employee_warnings(is_deleted);

-- ===============================================
-- Warning History Table (for tracking changes)
-- ===============================================
CREATE TABLE IF NOT EXISTS employee_warning_history (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    warning_id UUID REFERENCES employee_warnings(id) ON DELETE CASCADE,
    action_type VARCHAR(50) NOT NULL, -- 'created', 'updated', 'acknowledged', 'resolved', 'fine_paid', etc.
    old_values JSONB,
    new_values JSONB,
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    changed_by_username VARCHAR(255),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    ip_address INET,
    user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_warning_history_warning_id ON employee_warning_history(warning_id);
CREATE INDEX IF NOT EXISTS idx_warning_history_action_type ON employee_warning_history(action_type);
CREATE INDEX IF NOT EXISTS idx_warning_history_changed_at ON employee_warning_history(changed_at);

-- ===============================================
-- Fine Payment History Table
-- ===============================================
CREATE TABLE IF NOT EXISTS employee_fine_payments (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    warning_id UUID REFERENCES employee_warnings(id) ON DELETE CASCADE,
    payment_method VARCHAR(50), -- 'cash', 'bank_transfer', 'deduction', 'credit_card', etc.
    payment_amount DECIMAL(10,2) NOT NULL,
    payment_currency VARCHAR(3) DEFAULT 'USD',
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_reference VARCHAR(100),
    payment_notes TEXT,
    processed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    processed_by_username VARCHAR(255),
    
    -- Accounting Information
    account_code VARCHAR(50),
    transaction_id VARCHAR(100),
    receipt_number VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_fine_payments_warning_id ON employee_fine_payments(warning_id);
CREATE INDEX IF NOT EXISTS idx_fine_payments_payment_date ON employee_fine_payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_fine_payments_processed_by ON employee_fine_payments(processed_by);

-- ===============================================
-- Triggers for Audit Trail
-- ===============================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_warning_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
CREATE TRIGGER trigger_update_warning_updated_at
    BEFORE UPDATE ON employee_warnings
    FOR EACH ROW
    EXECUTE FUNCTION update_warning_updated_at();

-- Function to generate warning reference number
CREATE OR REPLACE FUNCTION generate_warning_reference()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.warning_reference IS NULL THEN
        NEW.warning_reference = 'WRN-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || 
                               LPAD(EXTRACT(DOY FROM CURRENT_DATE)::TEXT, 3, '0') || '-' ||
                               LPAD((EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) % 86400)::INTEGER::TEXT, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for warning reference generation
CREATE TRIGGER trigger_generate_warning_reference
    BEFORE INSERT ON employee_warnings
    FOR EACH ROW
    EXECUTE FUNCTION generate_warning_reference();

-- Function to create history entry
CREATE OR REPLACE FUNCTION create_warning_history()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO employee_warning_history (warning_id, action_type, new_values, changed_by, changed_by_username)
        VALUES (NEW.id, 'created', to_jsonb(NEW), NEW.issued_by, NEW.issued_by_username);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO employee_warning_history (warning_id, action_type, old_values, new_values, changed_by, changed_by_username)
        VALUES (NEW.id, 'updated', to_jsonb(OLD), to_jsonb(NEW), NEW.updated_at, 'system');
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO employee_warning_history (warning_id, action_type, old_values, changed_by, changed_by_username)
        VALUES (OLD.id, 'deleted', to_jsonb(OLD), OLD.deleted_by, 'system');
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for history tracking
CREATE TRIGGER trigger_create_warning_history
    AFTER INSERT OR UPDATE OR DELETE ON employee_warnings
    FOR EACH ROW
    EXECUTE FUNCTION create_warning_history();

-- ===============================================
-- Row Level Security (RLS) Policies
-- ===============================================

-- Enable RLS
ALTER TABLE employee_warnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_warning_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_fine_payments ENABLE ROW LEVEL SECURITY;

-- Policy for users to see their own warnings
CREATE POLICY "Users can view their own warnings" ON employee_warnings
    FOR SELECT
    USING (auth.uid()::text = user_id::text);

-- Policy for HR and managers to view all warnings - Simplified as user_roles may not exist
CREATE POLICY "Admins can view all warnings" ON employee_warnings
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = auth.uid()
            AND u.user_type = 'global'
        )
    );

-- Policy for warning issuers to view warnings they created
CREATE POLICY "Warning issuers can view their issued warnings" ON employee_warnings
    FOR SELECT
    USING (auth.uid()::text = issued_by::text);

-- Similar policies for history and payments tables
CREATE POLICY "Users can view their own warning history" ON employee_warning_history
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM employee_warnings ew
            WHERE ew.id = warning_id
            AND auth.uid()::text = ew.user_id::text
        )
    );

CREATE POLICY "Admins can view all warning history" ON employee_warning_history
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = auth.uid()
            AND u.user_type = 'global'
        )
    );

-- Policies for fine payments
CREATE POLICY "Users can view their own fine payments" ON employee_fine_payments
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM employee_warnings ew
            WHERE ew.id = warning_id
            AND auth.uid()::text = ew.user_id::text
        )
    );

CREATE POLICY "Admins can manage all fine payments" ON employee_fine_payments
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = auth.uid()
            AND u.user_type = 'global'
        )
    );

-- ===============================================
-- Useful Views
-- ===============================================

-- View for active warnings with employee details
CREATE OR REPLACE VIEW active_warnings_with_details AS
SELECT 
    ew.*,
    u.username as user_username,
    he.name as employee_name, -- Changed from first_name/last_name to name
    he.employee_id as employee_code,
    b.name_en as branch_name,
    issuer.username as issued_by_username_full
FROM employee_warnings ew
LEFT JOIN users u ON ew.user_id = u.id
LEFT JOIN hr_employees he ON ew.employee_id = he.id
LEFT JOIN branches b ON ew.branch_id = b.id
LEFT JOIN users issuer ON ew.issued_by = issuer.id
WHERE ew.warning_status = 'active' 
AND ew.is_deleted = FALSE;

-- View for outstanding fines
CREATE OR REPLACE VIEW outstanding_fines AS
SELECT 
    ew.*,
    u.username as user_username,
    he.name as employee_name, -- Changed from first_name/last_name to name
    (ew.fine_amount - COALESCE(SUM(efp.payment_amount), 0)) as outstanding_amount
FROM employee_warnings ew
LEFT JOIN users u ON ew.user_id = u.id
LEFT JOIN hr_employees he ON ew.employee_id = he.id
LEFT JOIN employee_fine_payments efp ON ew.id = efp.warning_id
WHERE ew.has_fine = TRUE 
AND ew.fine_status IN ('pending', 'partial')
AND ew.is_deleted = FALSE
GROUP BY ew.id, u.username, he.name
HAVING (ew.fine_amount - COALESCE(SUM(efp.payment_amount), 0)) > 0;

-- ===============================================
-- Sample Functions for Common Operations
-- ===============================================

-- Function to acknowledge a warning
CREATE OR REPLACE FUNCTION acknowledge_warning(
    warning_id_param UUID,
    acknowledged_by_param UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE employee_warnings 
    SET 
        warning_status = 'acknowledged',
        acknowledged_at = CURRENT_TIMESTAMP,
        acknowledged_by = acknowledged_by_param,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = warning_id_param
    AND warning_status = 'active';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to record fine payment
CREATE OR REPLACE FUNCTION record_fine_payment(
    warning_id_param UUID,
    payment_amount_param DECIMAL(10,2),
    payment_method_param VARCHAR(50),
    payment_reference_param VARCHAR(100),
    processed_by_param UUID
)
RETURNS UUID AS $$
DECLARE
    payment_id UUID;
    total_paid DECIMAL(10,2);
    fine_amount DECIMAL(10,2);
BEGIN
    -- Get the fine amount
    SELECT ew.fine_amount INTO fine_amount
    FROM employee_warnings ew
    WHERE ew.id = warning_id_param;
    
    -- Insert payment record
    INSERT INTO employee_fine_payments (
        warning_id, payment_amount, payment_method, 
        payment_reference, processed_by
    ) VALUES (
        warning_id_param, payment_amount_param, payment_method_param,
        payment_reference_param, processed_by_param
    ) RETURNING id INTO payment_id;
    
    -- Calculate total paid
    SELECT COALESCE(SUM(payment_amount), 0) INTO total_paid
    FROM employee_fine_payments
    WHERE warning_id = warning_id_param;
    
    -- Update warning status based on payment
    UPDATE employee_warnings
    SET 
        fine_paid_amount = total_paid,
        fine_status = CASE 
            WHEN total_paid >= fine_amount THEN 'paid'
            WHEN total_paid > 0 THEN 'partial'
            ELSE 'pending'
        END,
        fine_paid_date = CASE 
            WHEN total_paid >= fine_amount THEN CURRENT_TIMESTAMP
            ELSE fine_paid_date
        END,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = warning_id_param;
    
    RETURN payment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===============================================
-- Comments for Documentation
-- ===============================================

COMMENT ON TABLE employee_warnings IS 'Stores all employee warning records with fine tracking and performance context';
COMMENT ON COLUMN employee_warnings.warning_type IS 'Type of warning: overall performance or task-specific, with or without fines';
COMMENT ON COLUMN employee_warnings.warning_reference IS 'Auto-generated unique reference number for the warning';
COMMENT ON COLUMN employee_warnings.fine_status IS 'Status of any associated fine: pending, paid, waived, or cancelled';
COMMENT ON TABLE employee_warning_history IS 'Audit trail for all changes made to warning records';
COMMENT ON TABLE employee_fine_payments IS 'Payment history for fines associated with warnings';