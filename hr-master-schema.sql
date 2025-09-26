-- =====================================================
-- HR MASTER FUNCTIONS - DATABASE SCHEMA
-- Complete HR Management System for Aqura
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. HR DEPARTMENTS SCHEMA
-- =====================================================

CREATE TABLE hr_departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_code VARCHAR(20) UNIQUE NOT NULL,
    department_name_en VARCHAR(100) NOT NULL,
    department_name_ar VARCHAR(100) NOT NULL,
    parent_department_id UUID REFERENCES hr_departments(id),
    branch_id UUID NOT NULL, -- References branches.id from original schema
    department_head_id UUID, -- References hr_employees.id (self-referencing)
    cost_center VARCHAR(20),
    budget_allocated DECIMAL(15,2),
    description_en TEXT,
    description_ar TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID, -- References users.id from original schema
    updated_by UUID  -- References users.id from original schema
);

-- Create indexes for departments
CREATE INDEX idx_hr_departments_branch_id ON hr_departments(branch_id);
CREATE INDEX idx_hr_departments_parent_id ON hr_departments(parent_department_id);
CREATE INDEX idx_hr_departments_code ON hr_departments(department_code);

-- =====================================================
-- 2. HR LEVELS SCHEMA  
-- =====================================================

CREATE TABLE hr_levels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    level_code VARCHAR(20) UNIQUE NOT NULL,
    level_name_en VARCHAR(100) NOT NULL,
    level_name_ar VARCHAR(100) NOT NULL,
    level_order INTEGER NOT NULL, -- Hierarchy order (1 = highest)
    parent_level_id UUID REFERENCES hr_levels(id),
    branch_id UUID NOT NULL, -- References branches.id
    salary_band_min DECIMAL(12,2),
    salary_band_max DECIMAL(12,2),
    grade_points INTEGER,
    benefits_package JSONB, -- Store benefits as JSON
    reporting_structure JSONB, -- Store reporting rules as JSON
    description_en TEXT,
    description_ar TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

-- Create indexes for levels
CREATE INDEX idx_hr_levels_branch_id ON hr_levels(branch_id);
CREATE INDEX idx_hr_levels_order ON hr_levels(level_order);
CREATE INDEX idx_hr_levels_code ON hr_levels(level_code);

-- =====================================================
-- 3. HR POSITIONS SCHEMA
-- =====================================================

CREATE TABLE hr_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    position_code VARCHAR(20) UNIQUE NOT NULL,
    position_title_en VARCHAR(100) NOT NULL,
    position_title_ar VARCHAR(100) NOT NULL,
    department_id UUID NOT NULL REFERENCES hr_departments(id),
    level_id UUID NOT NULL REFERENCES hr_levels(id),
    branch_id UUID NOT NULL, -- References branches.id
    reports_to_position_id UUID REFERENCES hr_positions(id),
    employment_type VARCHAR(20) DEFAULT 'FULL_TIME', -- FULL_TIME, PART_TIME, CONTRACT
    job_description_en TEXT,
    job_description_ar TEXT,
    required_qualifications JSONB, -- Store qualifications as JSON
    required_skills JSONB, -- Store skills as JSON
    responsibilities JSONB, -- Store responsibilities as JSON
    kpi_metrics JSONB, -- Store KPIs as JSON
    salary_range_min DECIMAL(12,2),
    salary_range_max DECIMAL(12,2),
    headcount_authorized INTEGER DEFAULT 1,
    headcount_filled INTEGER DEFAULT 0,
    is_critical_position BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

-- Create indexes for positions
CREATE INDEX idx_hr_positions_department_id ON hr_positions(department_id);
CREATE INDEX idx_hr_positions_level_id ON hr_positions(level_id);
CREATE INDEX idx_hr_positions_branch_id ON hr_positions(branch_id);
CREATE INDEX idx_hr_positions_code ON hr_positions(position_code);

-- =====================================================
-- 4. HR EMPLOYEES SCHEMA
-- =====================================================

CREATE TABLE hr_employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id VARCHAR(50) UNIQUE NOT NULL,
    employee_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- Personal Information
    first_name_en VARCHAR(100) NOT NULL,
    last_name_en VARCHAR(100) NOT NULL,
    first_name_ar VARCHAR(100),
    last_name_ar VARCHAR(100),
    full_name_en VARCHAR(200) GENERATED ALWAYS AS (first_name_en || ' ' || last_name_en) STORED,
    full_name_ar VARCHAR(200),
    
    -- Identification
    national_id VARCHAR(50),
    passport_number VARCHAR(50),
    iqama_number VARCHAR(50),
    visa_number VARCHAR(50),
    
    -- Personal Details
    date_of_birth DATE,
    gender VARCHAR(10), -- MALE, FEMALE
    nationality VARCHAR(50),
    marital_status VARCHAR(20), -- SINGLE, MARRIED, DIVORCED, WIDOWED
    religion VARCHAR(50),
    blood_group VARCHAR(10),
    
    -- Contact Information
    phone_primary VARCHAR(20),
    phone_secondary VARCHAR(20),
    email_personal VARCHAR(100),
    email_work VARCHAR(100),
    address_current JSONB, -- Store address as JSON
    address_permanent JSONB,
    emergency_contact JSONB, -- Store emergency contacts as JSON
    
    -- Employment Information
    branch_id UUID NOT NULL, -- References branches.id
    hire_date DATE NOT NULL,
    probation_end_date DATE,
    employment_status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, TERMINATED, RESIGNED
    employee_type VARCHAR(20) DEFAULT 'PERMANENT', -- PERMANENT, CONTRACT, PROBATION, INTERN
    work_schedule VARCHAR(20) DEFAULT 'FULL_TIME', -- FULL_TIME, PART_TIME, SHIFT
    
    -- Reporting Structure
    direct_manager_id UUID REFERENCES hr_employees(id),
    indirect_manager_id UUID REFERENCES hr_employees(id),
    
    -- System Information
    user_account_id UUID, -- References users.id from original schema
    access_card_number VARCHAR(50),
    fingerprint_template BYTEA, -- Store fingerprint data
    photo_url TEXT,
    
    -- Status and Metadata
    is_active BOOLEAN DEFAULT true,
    termination_date DATE,
    termination_reason TEXT,
    rehire_eligible BOOLEAN DEFAULT true,
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Constraints
    CONSTRAINT chk_hr_employees_gender CHECK (gender IN ('MALE', 'FEMALE')),
    CONSTRAINT chk_hr_employees_status CHECK (employment_status IN ('ACTIVE', 'INACTIVE', 'TERMINATED', 'RESIGNED')),
    CONSTRAINT chk_hr_employees_type CHECK (employee_type IN ('PERMANENT', 'CONTRACT', 'PROBATION', 'INTERN')),
    CONSTRAINT chk_hr_employees_schedule CHECK (work_schedule IN ('FULL_TIME', 'PART_TIME', 'SHIFT'))
);

-- Create indexes for employees
CREATE INDEX idx_hr_employees_employee_id ON hr_employees(employee_id);
CREATE INDEX idx_hr_employees_branch_id ON hr_employees(branch_id);
CREATE INDEX idx_hr_employees_manager_id ON hr_employees(direct_manager_id);
CREATE INDEX idx_hr_employees_status ON hr_employees(employment_status);
CREATE INDEX idx_hr_employees_name_en ON hr_employees(full_name_en);
CREATE INDEX idx_hr_employees_national_id ON hr_employees(national_id);

-- =====================================================
-- 5. HR POSITION ASSIGNMENTS SCHEMA
-- =====================================================

CREATE TABLE hr_position_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    position_id UUID NOT NULL REFERENCES hr_positions(id),
    department_id UUID NOT NULL REFERENCES hr_departments(id),
    level_id UUID NOT NULL REFERENCES hr_levels(id),
    branch_id UUID NOT NULL, -- References branches.id
    
    -- Assignment Details
    assignment_type VARCHAR(20) DEFAULT 'PRIMARY', -- PRIMARY, SECONDARY, ACTING, TEMPORARY
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    is_current BOOLEAN DEFAULT true,
    
    -- Position-specific details
    job_title_override_en VARCHAR(100), -- Custom title if different from position
    job_title_override_ar VARCHAR(100),
    reporting_manager_id UUID REFERENCES hr_employees(id),
    cost_center VARCHAR(20),
    work_location VARCHAR(100),
    
    -- Performance and KPIs
    performance_metrics JSONB,
    targets JSONB,
    
    -- Status
    assignment_status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, SUSPENDED, TERMINATED
    status_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    CONSTRAINT chk_hr_assignments_type CHECK (assignment_type IN ('PRIMARY', 'SECONDARY', 'ACTING', 'TEMPORARY')),
    CONSTRAINT chk_hr_assignments_status CHECK (assignment_status IN ('ACTIVE', 'SUSPENDED', 'TERMINATED')),
    CONSTRAINT chk_hr_assignments_dates CHECK (end_date IS NULL OR end_date >= effective_date)
);

-- Create indexes for position assignments
CREATE INDEX idx_hr_assignments_employee_id ON hr_position_assignments(employee_id);
CREATE INDEX idx_hr_assignments_position_id ON hr_position_assignments(position_id);
CREATE INDEX idx_hr_assignments_current ON hr_position_assignments(is_current);
CREATE INDEX idx_hr_assignments_effective_date ON hr_position_assignments(effective_date);

-- =====================================================
-- 6. HR REPORTING MAP SCHEMA
-- =====================================================

CREATE TABLE hr_reporting_map (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subordinate_id UUID NOT NULL REFERENCES hr_employees(id),
    manager_id UUID NOT NULL REFERENCES hr_employees(id),
    branch_id UUID NOT NULL, -- References branches.id
    
    -- Reporting Details
    reporting_type VARCHAR(20) DEFAULT 'DIRECT', -- DIRECT, DOTTED, MATRIX, FUNCTIONAL
    relationship_level INTEGER NOT NULL DEFAULT 1, -- 1 = direct report, 2 = skip level, etc.
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    
    -- Delegation and Authority
    delegation_level JSONB, -- Store delegation permissions as JSON
    approval_limits JSONB, -- Store approval limits as JSON
    
    -- Performance Management
    performance_review_cycle VARCHAR(20) DEFAULT 'ANNUAL', -- ANNUAL, SEMI_ANNUAL, QUARTERLY
    next_review_date DATE,
    
    -- Metadata
    reporting_reason VARCHAR(100), -- PROMOTION, TRANSFER, RESTRUCTURE, etc.
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    CONSTRAINT chk_hr_reporting_type CHECK (reporting_type IN ('DIRECT', 'DOTTED', 'MATRIX', 'FUNCTIONAL')),
    CONSTRAINT chk_hr_reporting_cycle CHECK (performance_review_cycle IN ('ANNUAL', 'SEMI_ANNUAL', 'QUARTERLY', 'MONTHLY')),
    CONSTRAINT chk_hr_reporting_dates CHECK (end_date IS NULL OR end_date >= effective_date),
    CONSTRAINT chk_hr_reporting_self CHECK (subordinate_id != manager_id)
);

-- Create indexes for reporting map
CREATE INDEX idx_hr_reporting_subordinate ON hr_reporting_map(subordinate_id);
CREATE INDEX idx_hr_reporting_manager ON hr_reporting_map(manager_id);
CREATE INDEX idx_hr_reporting_active ON hr_reporting_map(is_active);
CREATE INDEX idx_hr_reporting_level ON hr_reporting_map(relationship_level);

-- =====================================================
-- 7. HR FINGERPRINT TRANSACTIONS SCHEMA
-- =====================================================

CREATE TABLE hr_fingerprint_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    branch_id UUID NOT NULL, -- References branches.id
    
    -- Transaction Details
    transaction_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    transaction_date DATE NOT NULL GENERATED ALWAYS AS (DATE(transaction_datetime)) STORED,
    transaction_type VARCHAR(20) NOT NULL, -- CHECK_IN, CHECK_OUT, BREAK_START, BREAK_END
    
    -- Device Information
    device_id VARCHAR(50),
    device_location VARCHAR(100),
    fingerprint_quality INTEGER, -- Quality score 0-100
    
    -- Verification Details
    verification_method VARCHAR(20) DEFAULT 'FINGERPRINT', -- FINGERPRINT, CARD, PIN, FACE
    verification_status VARCHAR(20) DEFAULT 'SUCCESS', -- SUCCESS, FAILED, DUPLICATE
    confidence_score DECIMAL(5,2), -- Verification confidence percentage
    
    -- Time and Attendance
    shift_code VARCHAR(20),
    expected_time TIME,
    actual_time TIME NOT NULL GENERATED ALWAYS AS (TIME(transaction_datetime)) STORED,
    time_difference INTEGER, -- Difference in minutes from expected time
    late_minutes INTEGER DEFAULT 0,
    early_departure_minutes INTEGER DEFAULT 0,
    
    -- Location and Context
    gps_coordinates JSONB, -- Store GPS location as JSON
    ip_address INET,
    user_agent TEXT,
    
    -- Processing Status
    processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by UUID,
    processing_notes TEXT,
    
    -- Validation and Exceptions
    is_exception BOOLEAN DEFAULT false,
    exception_type VARCHAR(50), -- MANUAL_ENTRY, SYSTEM_ERROR, DUPLICATE, etc.
    exception_reason TEXT,
    approved_by UUID,
    approval_notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT chk_hr_fingerprint_type CHECK (transaction_type IN ('CHECK_IN', 'CHECK_OUT', 'BREAK_START', 'BREAK_END')),
    CONSTRAINT chk_hr_fingerprint_method CHECK (verification_method IN ('FINGERPRINT', 'CARD', 'PIN', 'FACE')),
    CONSTRAINT chk_hr_fingerprint_status CHECK (verification_status IN ('SUCCESS', 'FAILED', 'DUPLICATE'))
);

-- Create indexes for fingerprint transactions
CREATE INDEX idx_hr_fingerprint_employee_id ON hr_fingerprint_transactions(employee_id);
CREATE INDEX idx_hr_fingerprint_datetime ON hr_fingerprint_transactions(transaction_datetime);
CREATE INDEX idx_hr_fingerprint_date ON hr_fingerprint_transactions(transaction_date);
CREATE INDEX idx_hr_fingerprint_type ON hr_fingerprint_transactions(transaction_type);
CREATE INDEX idx_hr_fingerprint_processed ON hr_fingerprint_transactions(processed);

-- =====================================================
-- 8. HR EMPLOYEE CONTACTS SCHEMA
-- =====================================================

CREATE TABLE hr_employee_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    
    -- Contact Details
    contact_type VARCHAR(20) NOT NULL, -- PRIMARY, EMERGENCY, FAMILY, REFERENCE
    relationship VARCHAR(50), -- SPOUSE, FATHER, MOTHER, SIBLING, FRIEND, etc.
    contact_name_en VARCHAR(100) NOT NULL,
    contact_name_ar VARCHAR(100),
    
    -- Contact Information
    phone_primary VARCHAR(20),
    phone_secondary VARCHAR(20),
    email VARCHAR(100),
    address JSONB, -- Store address as JSON
    
    -- Additional Details
    priority_order INTEGER DEFAULT 1, -- 1 = highest priority
    is_authorized_contact BOOLEAN DEFAULT false, -- Can be contacted for official matters
    can_collect_salary BOOLEAN DEFAULT false,
    has_medical_authority BOOLEAN DEFAULT false, -- Can make medical decisions
    
    -- Emergency Contact Specific
    medical_conditions TEXT, -- Any medical conditions to be aware of
    blood_group VARCHAR(10),
    preferred_hospital VARCHAR(100),
    insurance_details JSONB,
    
    -- Status and Metadata
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    CONSTRAINT chk_hr_contacts_type CHECK (contact_type IN ('PRIMARY', 'EMERGENCY', 'FAMILY', 'REFERENCE'))
);

-- Create indexes for employee contacts
CREATE INDEX idx_hr_contacts_employee_id ON hr_employee_contacts(employee_id);
CREATE INDEX idx_hr_contacts_type ON hr_employee_contacts(contact_type);
CREATE INDEX idx_hr_contacts_priority ON hr_employee_contacts(priority_order);

-- =====================================================
-- 9. HR EMPLOYEE DOCUMENTS SCHEMA
-- =====================================================

CREATE TABLE hr_employee_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    
    -- Document Classification
    document_category VARCHAR(50) NOT NULL, -- ID_DOCUMENTS, EDUCATIONAL, MEDICAL, CONTRACTS, etc.
    document_type VARCHAR(100) NOT NULL, -- PASSPORT, RESUME, HEALTH_CARD, etc.
    document_name_en VARCHAR(200) NOT NULL,
    document_name_ar VARCHAR(200),
    
    -- File Information
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_size INTEGER, -- File size in bytes
    file_type VARCHAR(50), -- PDF, JPG, PNG, DOC, etc.
    mime_type VARCHAR(100),
    
    -- Document Details
    document_number VARCHAR(100), -- Passport number, ID number, etc.
    issuing_authority VARCHAR(200),
    issue_date DATE,
    expiry_date DATE,
    is_renewable BOOLEAN DEFAULT true,
    
    -- Validation and Verification
    is_verified BOOLEAN DEFAULT false,
    verified_by UUID,
    verified_at TIMESTAMP WITH TIME ZONE,
    verification_notes TEXT,
    
    -- Document Status
    document_status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, EXPIRED, INVALID, REPLACED
    replacement_document_id UUID REFERENCES hr_employee_documents(id),
    
    -- Access Control
    confidentiality_level VARCHAR(20) DEFAULT 'INTERNAL', -- PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
    access_permissions JSONB, -- Store access rules as JSON
    
    -- Reminders and Notifications
    reminder_days INTEGER DEFAULT 30, -- Days before expiry to remind
    last_reminder_sent TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    description_en TEXT,
    description_ar TEXT,
    tags JSONB, -- Store searchable tags as JSON
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    CONSTRAINT chk_hr_documents_status CHECK (document_status IN ('ACTIVE', 'EXPIRED', 'INVALID', 'REPLACED')),
    CONSTRAINT chk_hr_documents_confidentiality CHECK (confidentiality_level IN ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'))
);

-- Create indexes for employee documents
CREATE INDEX idx_hr_documents_employee_id ON hr_employee_documents(employee_id);
CREATE INDEX idx_hr_documents_category ON hr_employee_documents(document_category);
CREATE INDEX idx_hr_documents_type ON hr_employee_documents(document_type);
CREATE INDEX idx_hr_documents_expiry ON hr_employee_documents(expiry_date);
CREATE INDEX idx_hr_documents_status ON hr_employee_documents(document_status);

-- =====================================================
-- 10. HR SALARY & WAGES SCHEMA
-- =====================================================

CREATE TABLE hr_salary_wages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    branch_id UUID NOT NULL, -- References branches.id
    
    -- Salary Structure
    basic_salary DECIMAL(12,2) NOT NULL,
    currency_code VARCHAR(3) DEFAULT 'SAR',
    salary_frequency VARCHAR(20) DEFAULT 'MONTHLY', -- MONTHLY, WEEKLY, DAILY, HOURLY
    
    -- Effective Period
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_current BOOLEAN DEFAULT true,
    
    -- Salary Components Summary
    total_allowances DECIMAL(12,2) DEFAULT 0,
    total_deductions DECIMAL(12,2) DEFAULT 0,
    gross_salary DECIMAL(12,2) GENERATED ALWAYS AS (basic_salary + total_allowances) STORED,
    net_salary DECIMAL(12,2) GENERATED ALWAYS AS (basic_salary + total_allowances - total_deductions) STORED,
    
    -- Payment Details
    payment_method VARCHAR(20) DEFAULT 'BANK_TRANSFER', -- BANK_TRANSFER, CASH, CHEQUE
    bank_account_number VARCHAR(50),
    bank_name VARCHAR(100),
    iban VARCHAR(50),
    
    -- Approval Workflow
    approval_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    approved_by UUID,
    approved_at TIMESTAMP WITH TIME ZONE,
    approval_notes TEXT,
    
    -- Metadata
    revision_number INTEGER DEFAULT 1,
    previous_salary_id UUID REFERENCES hr_salary_wages(id),
    change_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    CONSTRAINT chk_hr_salary_frequency CHECK (salary_frequency IN ('MONTHLY', 'WEEKLY', 'DAILY', 'HOURLY')),
    CONSTRAINT chk_hr_salary_payment CHECK (payment_method IN ('BANK_TRANSFER', 'CASH', 'CHEQUE')),
    CONSTRAINT chk_hr_salary_approval CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT chk_hr_salary_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

-- Create indexes for salary wages
CREATE INDEX idx_hr_salary_employee_id ON hr_salary_wages(employee_id);
CREATE INDEX idx_hr_salary_current ON hr_salary_wages(is_current);
CREATE INDEX idx_hr_salary_effective ON hr_salary_wages(effective_from, effective_to);

-- =====================================================
-- HR SALARY COMPONENTS SCHEMA (Allowances & Deductions)
-- =====================================================

CREATE TABLE hr_salary_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salary_id UUID NOT NULL REFERENCES hr_salary_wages(id),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    
    -- Component Details
    component_type VARCHAR(20) NOT NULL, -- ALLOWANCE, DEDUCTION
    component_name_en VARCHAR(100) NOT NULL,
    component_name_ar VARCHAR(100),
    component_code VARCHAR(20),
    
    -- Amount Details
    amount DECIMAL(12,2) NOT NULL,
    calculation_method VARCHAR(20) DEFAULT 'FIXED', -- FIXED, PERCENTAGE, FORMULA
    calculation_base DECIMAL(12,2), -- Base amount for percentage calculations
    calculation_percentage DECIMAL(5,2), -- Percentage if calculation_method = PERCENTAGE
    
    -- Application Period (for Deductions only)
    has_application_period BOOLEAN DEFAULT false,
    application_type VARCHAR(20), -- SINGLE_MONTH, MULTIPLE_MONTHS
    single_month DATE, -- For single month applications (YYYY-MM-01 format)
    start_month DATE, -- For multiple month applications (YYYY-MM-01 format)
    end_month DATE, -- For multiple month applications (YYYY-MM-01 format)
    
    -- Status and Control
    is_enabled BOOLEAN DEFAULT true,
    is_mandatory BOOLEAN DEFAULT false,
    is_taxable BOOLEAN DEFAULT true,
    
    -- Metadata
    description_en TEXT,
    description_ar TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    CONSTRAINT chk_hr_components_type CHECK (component_type IN ('ALLOWANCE', 'DEDUCTION')),
    CONSTRAINT chk_hr_components_calc CHECK (calculation_method IN ('FIXED', 'PERCENTAGE', 'FORMULA')),
    CONSTRAINT chk_hr_components_app_type CHECK (application_type IN ('SINGLE_MONTH', 'MULTIPLE_MONTHS')),
    CONSTRAINT chk_hr_components_dates CHECK (
        CASE 
            WHEN application_type = 'MULTIPLE_MONTHS' THEN end_month >= start_month
            ELSE true
        END
    ),
    -- Application period only for deductions
    CONSTRAINT chk_hr_components_period CHECK (
        CASE 
            WHEN component_type = 'ALLOWANCE' THEN has_application_period = false
            ELSE true
        END
    )
);

-- Create indexes for salary components
CREATE INDEX idx_hr_components_salary_id ON hr_salary_components(salary_id);
CREATE INDEX idx_hr_components_employee_id ON hr_salary_components(employee_id);
CREATE INDEX idx_hr_components_type ON hr_salary_components(component_type);
CREATE INDEX idx_hr_components_enabled ON hr_salary_components(is_enabled);

-- =====================================================
-- FOREIGN KEY RELATIONSHIPS TO ORIGINAL SCHEMA
-- =====================================================

-- Add foreign key constraints to original tables (to be uncommented after integration)
-- ALTER TABLE hr_departments ADD CONSTRAINT fk_hr_departments_branch FOREIGN KEY (branch_id) REFERENCES branches(id);
-- ALTER TABLE hr_departments ADD CONSTRAINT fk_hr_departments_head FOREIGN KEY (department_head_id) REFERENCES hr_employees(id);
-- ALTER TABLE hr_departments ADD CONSTRAINT fk_hr_departments_created_by FOREIGN KEY (created_by) REFERENCES users(id);
-- ALTER TABLE hr_departments ADD CONSTRAINT fk_hr_departments_updated_by FOREIGN KEY (updated_by) REFERENCES users(id);

-- Similar constraints to be added for all other tables...

-- =====================================================
-- TRIGGERS AND FUNCTIONS
-- =====================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add update triggers to all tables
CREATE TRIGGER update_hr_departments_updated_at BEFORE UPDATE ON hr_departments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_levels_updated_at BEFORE UPDATE ON hr_levels FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_positions_updated_at BEFORE UPDATE ON hr_positions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_employees_updated_at BEFORE UPDATE ON hr_employees FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_position_assignments_updated_at BEFORE UPDATE ON hr_position_assignments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_reporting_map_updated_at BEFORE UPDATE ON hr_reporting_map FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_employee_contacts_updated_at BEFORE UPDATE ON hr_employee_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_employee_documents_updated_at BEFORE UPDATE ON hr_employee_documents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_salary_wages_updated_at BEFORE UPDATE ON hr_salary_wages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hr_salary_components_updated_at BEFORE UPDATE ON hr_salary_components FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON TABLE hr_departments IS 'HR Master table for organizational departments';
COMMENT ON TABLE hr_levels IS 'HR Master table for organizational hierarchy levels';
COMMENT ON TABLE hr_positions IS 'HR Master table for job positions and roles';
COMMENT ON TABLE hr_employees IS 'HR Master table for employee information';
COMMENT ON TABLE hr_position_assignments IS 'HR table for employee-position assignments';
COMMENT ON TABLE hr_reporting_map IS 'HR table for manager-subordinate reporting relationships';
COMMENT ON TABLE hr_fingerprint_transactions IS 'HR table for attendance tracking via fingerprint';
COMMENT ON TABLE hr_employee_contacts IS 'HR table for employee contact information';
COMMENT ON TABLE hr_employee_documents IS 'HR table for employee document management';
COMMENT ON TABLE hr_salary_wages IS 'HR Master table for employee salary information';
COMMENT ON TABLE hr_salary_components IS 'HR table for salary allowances and deductions';

-- =====================================================
-- END OF HR MASTER FUNCTIONS SCHEMA
-- =====================================================