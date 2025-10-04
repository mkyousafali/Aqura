-- Vendors Schema
-- This table manages vendor/supplier information with contact details and status tracking

CREATE TABLE public.vendors (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  company character varying(255) NOT NULL,
  contact_person character varying(255) NULL,
  email character varying(255) NULL,
  phone character varying(50) NULL,
  address text NULL,
  status public.vendor_status_enum NOT NULL DEFAULT 'active'::vendor_status_enum,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT vendors_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_vendors_company ON public.vendors USING btree (company) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_status ON public.vendors USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_created_at ON public.vendors USING btree (created_at) TABLESPACE pg_default;