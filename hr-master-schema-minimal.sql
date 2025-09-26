-- =====================================================
-- HR MASTER FUNCTIONS - MINIMAL DATABASE SCHEMA
-- Only Essential Columns Based on Frontend Requirements
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. HR DEPARTMENTS (Create Department Function)
-- =====================================================
CREATE TABLE hr_departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_name_en VARCHAR(100) NOT NULL,
    department_name_ar VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. HR LEVELS (Create Level Function)
-- =====================================================
CREATE TABLE hr_levels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    level_name_en VARCHAR(100) NOT NULL,
    level_name_ar VARCHAR(100) NOT NULL,
    level_order INTEGER NOT NULL, -- 1 = highest
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. HR POSITIONS (Create Position Function)
-- =====================================================
CREATE TABLE hr_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    position_title_en VARCHAR(100) NOT NULL,
    position_title_ar VARCHAR(100) NOT NULL,
    department_id UUID NOT NULL REFERENCES hr_departments(id),
    level_id UUID NOT NULL REFERENCES hr_levels(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 4. HR EMPLOYEES (Upload Employees Function)
-- =====================================================
CREATE TABLE hr_employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id VARCHAR(10) UNIQUE NOT NULL, -- Numeric employee ID (1, 25, 120, 1251)
    name VARCHAR(200) NOT NULL, -- Employee name field
    branch_id UUID NOT NULL, -- References branches.id (automatically assigned from UI selection)
    hire_date DATE, -- Optional, updated later via another HR function
    status VARCHAR(20) DEFAULT 'active', -- active, inactive
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 5. HR POSITION ASSIGNMENTS (Assign Positions Function)
-- =====================================================
CREATE TABLE hr_position_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    position_id UUID NOT NULL REFERENCES hr_positions(id),
    department_id UUID NOT NULL REFERENCES hr_departments(id),
    level_id UUID NOT NULL REFERENCES hr_levels(id),
    branch_id UUID NOT NULL, -- References branches.id
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 6. HR REPORTING MAP (Reporting Map Function)
-- =====================================================
CREATE TABLE hr_reporting_map (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subordinate_id UUID NOT NULL REFERENCES hr_employees(id),
    manager_id UUID NOT NULL REFERENCES hr_employees(id),
    branch_id UUID NOT NULL, -- References branches.id
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_primary BOOLEAN DEFAULT true, -- TRUE for primary reporting, FALSE for secondary/dotted line reporting
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_hr_reporting_self CHECK (subordinate_id != manager_id)
);

-- =====================================================
-- HR POSITION REPORTING TEMPLATE (For Reporting Map Management frontend)
-- =====================================================
CREATE TABLE hr_position_reporting_template (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subordinate_position_id UUID NOT NULL REFERENCES hr_positions(id) UNIQUE, -- Select Position (only one entry per position)
    manager_position_1 UUID REFERENCES hr_positions(id), -- Reports To Slot 1
    manager_position_2 UUID REFERENCES hr_positions(id), -- Reports To Slot 2  
    manager_position_3 UUID REFERENCES hr_positions(id), -- Reports To Slot 3
    manager_position_4 UUID REFERENCES hr_positions(id), -- Reports To Slot 4
    manager_position_5 UUID REFERENCES hr_positions(id), -- Reports To Slot 5
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Ensure a position doesn't report to itself in any slot
    CONSTRAINT chk_no_self_report_1 CHECK (subordinate_position_id != manager_position_1),
    CONSTRAINT chk_no_self_report_2 CHECK (subordinate_position_id != manager_position_2),
    CONSTRAINT chk_no_self_report_3 CHECK (subordinate_position_id != manager_position_3),
    CONSTRAINT chk_no_self_report_4 CHECK (subordinate_position_id != manager_position_4),
    CONSTRAINT chk_no_self_report_5 CHECK (subordinate_position_id != manager_position_5)
);

-- =====================================================
-- 7. HR FINGERPRINT TRANSACTIONS (Upload Fingerprint Function)
-- =====================================================
CREATE TABLE hr_fingerprint_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id VARCHAR(10) NOT NULL, -- Numeric employee ID (1, 25, 120, 1251) - matches hr_employees
    name VARCHAR(200), -- Employee name field - matches hr_employees
    branch_id UUID NOT NULL, -- References branches.id (selected in frontend)
    transaction_date DATE NOT NULL, -- Separate date field
    transaction_time TIME NOT NULL, -- Separate time field
    punch_state VARCHAR(20) NOT NULL, -- 'Check In', 'Check Out'
    device_id VARCHAR(50), -- Optional device info
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_hr_fingerprint_punch CHECK (punch_state IN ('Check In', 'Check Out'))
);

-- =====================================================
-- 8. HR EMPLOYEE CONTACTS (Contact Management Function)
-- =====================================================
CREATE TABLE hr_employee_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    whatsapp_number VARCHAR(20), -- WhatsApp Number field
    contact_number VARCHAR(20), -- Contact Number field
    email VARCHAR(100), -- Email Address field
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 9. HR EMPLOYEE DOCUMENTS (Document Management Function)
-- =====================================================
CREATE TABLE hr_employee_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    document_type VARCHAR(50) NOT NULL, -- HEALTH_CARD, RESIDENT_ID, PASSPORT, etc.
    document_name VARCHAR(200) NOT NULL,
    file_path TEXT NOT NULL,
    expiry_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 10. HR SALARY WAGES (Salary & Wage Management Function)
-- =====================================================
CREATE TABLE hr_salary_wages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    branch_id UUID NOT NULL, -- References branches.id
    basic_salary DECIMAL(12,2) NOT NULL,
    effective_from DATE NOT NULL,
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- HR SALARY COMPONENTS (Allowances & Deductions)
-- =====================================================
CREATE TABLE hr_salary_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salary_id UUID NOT NULL REFERENCES hr_salary_wages(id),
    employee_id UUID NOT NULL REFERENCES hr_employees(id),
    component_type VARCHAR(20) NOT NULL, -- ALLOWANCE, DEDUCTION
    component_name VARCHAR(100) NOT NULL, -- bonus, food_allowance, insurance, etc.
    amount DECIMAL(12,2) NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    -- Application period for deductions only
    application_type VARCHAR(20), -- single, multiple
    single_month VARCHAR(7), -- MM-YYYY format
    start_month VARCHAR(7), -- MM-YYYY format  
    end_month VARCHAR(7), -- MM-YYYY format
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_hr_components_type CHECK (component_type IN ('ALLOWANCE', 'DEDUCTION')),
    CONSTRAINT chk_hr_components_app_type CHECK (application_type IN ('single', 'multiple'))
);

-- =====================================================
-- CREATE ESSENTIAL INDEXES
-- =====================================================
CREATE INDEX idx_hr_employees_branch_id ON hr_employees(branch_id);
CREATE INDEX idx_hr_employees_employee_id ON hr_employees(employee_id);
CREATE INDEX idx_hr_assignments_employee_id ON hr_position_assignments(employee_id);
CREATE INDEX idx_hr_reporting_subordinate ON hr_reporting_map(subordinate_id);
CREATE INDEX idx_hr_reporting_manager ON hr_reporting_map(manager_id);
CREATE INDEX idx_hr_position_reporting_subordinate ON hr_position_reporting_template(subordinate_position_id);
CREATE INDEX idx_hr_position_reporting_manager ON hr_position_reporting_template(manager_position_id);
CREATE INDEX idx_hr_fingerprint_employee_id ON hr_fingerprint_transactions(employee_id);
CREATE INDEX idx_hr_contacts_employee_id ON hr_employee_contacts(employee_id);
CREATE INDEX idx_hr_documents_employee_id ON hr_employee_documents(employee_id);
CREATE INDEX idx_hr_salary_employee_id ON hr_salary_wages(employee_id);
CREATE INDEX idx_hr_components_employee_id ON hr_salary_components(employee_id);

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON TABLE hr_departments IS 'HR Departments - minimal schema for Create Department function';
COMMENT ON TABLE hr_levels IS 'HR Levels - minimal schema for Create Level function';
COMMENT ON TABLE hr_positions IS 'HR Positions - minimal schema for Create Position function';
COMMENT ON TABLE hr_employees IS 'HR Employees - minimal schema for Upload Employees function';
COMMENT ON TABLE hr_position_assignments IS 'HR Position Assignments - minimal schema for Assign Positions function';
COMMENT ON TABLE hr_reporting_map IS 'HR Reporting Map - minimal schema for Reporting Map function';
COMMENT ON TABLE hr_fingerprint_transactions IS 'HR Fingerprint Transactions - minimal schema for Upload Fingerprint function';
COMMENT ON TABLE hr_employee_contacts IS 'HR Employee Contacts - minimal schema for Contact Management function';
COMMENT ON TABLE hr_employee_documents IS 'HR Employee Documents - minimal schema for Document Management function';
COMMENT ON TABLE hr_salary_wages IS 'HR Salary Wages - minimal schema for Salary & Wage Management function';
COMMENT ON TABLE hr_salary_components IS 'HR Salary Components - allowances and deductions with application periods';
COMMENT ON TABLE hr_position_reporting_template IS 'HR Position Reporting Template - defines reporting relationships between positions, used as template when assigning employees';

-- =====================================================
-- END OF MINIMAL HR SCHEMA
-- =====================================================