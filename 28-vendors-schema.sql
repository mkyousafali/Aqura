-- =====================================================
-- Table: vendors
-- Description: Basic vendor/supplier management
-- =====================================================

CREATE TYPE public.vendor_status_enum AS ENUM (
    'active',
    'inactive',
    'suspended',
    'blacklisted'
);

CREATE TABLE public.vendors (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    company VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    status public.vendor_status_enum NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT vendors_pkey PRIMARY KEY (id)
);

-- Create indexes
CREATE INDEX idx_vendors_company ON public.vendors(company);
CREATE INDEX idx_vendors_status ON public.vendors(status);
CREATE INDEX idx_vendors_created_at ON public.vendors(created_at);

-- Add some sample data
INSERT INTO public.vendors (company, contact_person, email, phone, status) VALUES
('ABC Supplies Ltd', 'John Smith', 'john@abcsupplies.com', '+1234567890', 'active'),
('XYZ Corporation', 'Jane Doe', 'jane@xyz.com', '+1234567891', 'active'),
('Tech Solutions Inc', 'Mike Johnson', 'mike@techsolutions.com', '+1234567892', 'active');

-- Comments
COMMENT ON TABLE public.vendors IS 'Vendor/supplier management table';
COMMENT ON COLUMN public.vendors.id IS 'Primary key - UUID';
COMMENT ON COLUMN public.vendors.company IS 'Company/business name';
COMMENT ON COLUMN public.vendors.contact_person IS 'Primary contact person';
COMMENT ON COLUMN public.vendors.email IS 'Contact email address';
COMMENT ON COLUMN public.vendors.phone IS 'Contact phone number';
COMMENT ON COLUMN public.vendors.address IS 'Business address';
COMMENT ON COLUMN public.vendors.status IS 'Vendor status (active, inactive, suspended, blacklisted)';