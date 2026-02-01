-- Create incident types table
CREATE TABLE IF NOT EXISTS public.incident_types (
    id TEXT PRIMARY KEY,
    incident_type_en TEXT NOT NULL UNIQUE,
    incident_type_ar TEXT NOT NULL UNIQUE,
    description_en TEXT,
    description_ar TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create index for active types
CREATE INDEX IF NOT EXISTS idx_incident_types_is_active 
ON public.incident_types USING btree (is_active) 
WHERE (is_active = true);

-- Insert incident types
INSERT INTO public.incident_types (id, incident_type_en, incident_type_ar, is_active) VALUES
    ('IN1', 'Customer Incidents', 'حوادث العملاء', true),
    ('IN2', 'Employee Incidents', 'حوادث الموظفين', true),
    ('IN3', 'Maintenance Incidents', 'حوادث الصيانة', true),
    ('IN4', 'Vendor Incidents', 'حوادث الموردين', true),
    ('IN5', 'Vehicle Incidents', 'حوادث المركبات', true),
    ('IN6', 'Government Incidents', 'حوادث حكومية', true),
    ('IN7', 'Other Incidents', 'حوادث أخرى', true)
ON CONFLICT (id) DO NOTHING;

-- Add comment
COMMENT ON TABLE public.incident_types IS 'Stores the types of incidents that can be reported in the system';
COMMENT ON COLUMN public.incident_types.id IS 'Unique identifier for incident type (IN1, IN2, etc.)';
COMMENT ON COLUMN public.incident_types.incident_type_en IS 'English name of the incident type';
COMMENT ON COLUMN public.incident_types.incident_type_ar IS 'Arabic name of the incident type';
