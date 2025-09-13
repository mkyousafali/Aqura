-- Aqura Management System Database Schema
-- Run this in Supabase SQL Editor to set up the database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable Row Level Security
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Create branches table
CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    region VARCHAR(100) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    manager_id UUID,
    employee_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    established_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create employees table
CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    position VARCHAR(100),
    department VARCHAR(100),
    salary DECIMAL(10,2),
    hire_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'on_leave')),
    avatar_url TEXT,
    branch_id UUID REFERENCES branches(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create vendors table
CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    company VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    category VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending')),
    payment_terms VARCHAR(100),
    tax_id VARCHAR(50),
    registration_number VARCHAR(100),
    address TEXT,
    total_orders INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create users table (extends auth.users)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(20) DEFAULT 'employee' CHECK (role IN ('admin', 'manager', 'employee')),
    avatar_url TEXT,
    branch_id UUID REFERENCES branches(id),
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create invoices table for future use
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_number VARCHAR(100) NOT NULL UNIQUE,
    vendor_id UUID REFERENCES vendors(id),
    branch_id UUID REFERENCES branches(id),
    amount DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'cancelled')),
    due_date DATE,
    issue_date DATE DEFAULT CURRENT_DATE,
    payment_date DATE,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraint for branch manager
ALTER TABLE branches 
ADD CONSTRAINT fk_branches_manager 
FOREIGN KEY (manager_id) REFERENCES employees(id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employees_branch ON employees(branch_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department);
CREATE INDEX IF NOT EXISTS idx_vendors_category ON vendors(category);
CREATE INDEX IF NOT EXISTS idx_vendors_status ON vendors(status);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_branch ON users(branch_id);
CREATE INDEX IF NOT EXISTS idx_invoices_vendor ON invoices(vendor_id);
CREATE INDEX IF NOT EXISTS idx_invoices_branch ON invoices(branch_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers to all tables
CREATE TRIGGER update_branches_updated_at BEFORE UPDATE ON branches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vendors_updated_at BEFORE UPDATE ON vendors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security on all tables
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Branches policies
CREATE POLICY "Users can view branches" ON branches
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins and managers can manage branches" ON branches
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Employees policies
CREATE POLICY "Users can view employees" ON employees
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can view their own employee record" ON employees
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND email = employees.email
        )
    );

CREATE POLICY "Admins and managers can manage employees" ON employees
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Vendors policies
CREATE POLICY "Users can view vendors" ON vendors
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins and managers can manage vendors" ON vendors
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Users policies
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can manage all users" ON users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Invoices policies
CREATE POLICY "Users can view invoices" ON invoices
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins and managers can manage invoices" ON invoices
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, full_name, role)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        COALESCE(NEW.raw_user_meta_data->>'role', 'employee')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function on user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update employee count when employees are added/removed
CREATE OR REPLACE FUNCTION update_branch_employee_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update count for old branch (if exists)
    IF TG_OP = 'UPDATE' AND OLD.branch_id IS NOT NULL AND OLD.branch_id != NEW.branch_id THEN
        UPDATE branches 
        SET employee_count = (
            SELECT COUNT(*) FROM employees 
            WHERE branch_id = OLD.branch_id AND status = 'active'
        )
        WHERE id = OLD.branch_id;
    END IF;
    
    -- Update count for deleted employee's branch
    IF TG_OP = 'DELETE' AND OLD.branch_id IS NOT NULL THEN
        UPDATE branches 
        SET employee_count = (
            SELECT COUNT(*) FROM employees 
            WHERE branch_id = OLD.branch_id AND status = 'active'
        )
        WHERE id = OLD.branch_id;
        RETURN OLD;
    END IF;
    
    -- Update count for new/updated employee's branch
    IF NEW.branch_id IS NOT NULL THEN
        UPDATE branches 
        SET employee_count = (
            SELECT COUNT(*) FROM employees 
            WHERE branch_id = NEW.branch_id AND status = 'active'
        )
        WHERE id = NEW.branch_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for employee count updates
CREATE TRIGGER update_branch_employee_count_trigger
    AFTER INSERT OR UPDATE OR DELETE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_branch_employee_count();

-- Insert sample data
INSERT INTO branches (name, code, region, address, phone, email, established_date) VALUES
    ('الرياض المركزي', 'RYD-001', 'Central', 'شارع الملك فهد، الرياض', '+966-11-234-5678', 'riyadh@aqura.sa', '2020-01-15'),
    ('جدة الغربي', 'JED-001', 'Western', 'شارع التحلية، جدة', '+966-12-345-6789', 'jeddah@aqura.sa', '2020-03-20'),
    ('الدمام الشرقي', 'DMM-001', 'Eastern', 'شارع الملك سعود، الدمام', '+966-13-456-7890', 'dammam@aqura.sa', '2020-06-10'),
    ('أبها الجنوبي', 'AHA-001', 'Southern', 'شارع الملك عبدالعزيز، أبها', '+966-17-567-8901', 'abha@aqura.sa', '2021-01-01'),
    ('تبوك الشمالي', 'TUU-001', 'Northern', 'شارع الأمير سلطان، تبوك', '+966-14-678-9012', 'tabuk@aqura.sa', '2021-03-15');

-- Note: Replace 'your-project.supabase.co' and 'your-anon-key' in the frontend configuration
-- with your actual Supabase project URL and anon key.
