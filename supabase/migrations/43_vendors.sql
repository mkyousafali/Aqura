-- Migration: Create vendors table
-- File: 43_vendors.sql
-- Description: Creates the vendors table for managing vendor information and relationships

BEGIN;

-- Create vendors table
CREATE TABLE public.vendors (
  erp_vendor_id integer NOT NULL,
  vendor_name text NOT NULL,
  salesman_name text NULL,
  salesman_contact text NULL,
  supervisor_name text NULL,
  supervisor_contact text NULL,
  vendor_contact_number text NULL,
  payment_method text NULL,
  credit_period integer NULL,
  bank_name text NULL,
  iban text NULL,
  status text NULL DEFAULT 'Active'::text,
  last_visit timestamp without time zone NULL,
  categories text[] NULL,
  delivery_modes text[] NULL,
  place text NULL,
  location_link text NULL,
  return_expired_products text NULL,
  return_expired_products_note text NULL,
  return_near_expiry_products text NULL,
  return_near_expiry_products_note text NULL,
  return_over_stock text NULL,
  return_over_stock_note text NULL,
  return_damage_products text NULL,
  return_damage_products_note text NULL,
  no_return boolean NULL DEFAULT false,
  no_return_note text NULL,
  vat_applicable text NULL DEFAULT 'VAT Applicable'::text,
  vat_number text NULL,
  no_vat_note text NULL,
  created_at timestamp without time zone NULL DEFAULT now(),
  updated_at timestamp without time zone NULL DEFAULT now(),
  branch_id bigint NOT NULL,
  CONSTRAINT vendors_pkey PRIMARY KEY (erp_vendor_id, branch_id),
  CONSTRAINT vendors_erp_vendor_branch_unique UNIQUE (erp_vendor_id, branch_id),
  CONSTRAINT vendors_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_vendors_branch_id 
ON public.vendors USING btree (branch_id) 
TABLESPACE pg_default
WHERE (branch_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_vendors_branch_status 
ON public.vendors USING btree (branch_id, status) 
TABLESPACE pg_default
WHERE (branch_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_vendors_erp_vendor_id 
ON public.vendors USING btree (erp_vendor_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_status 
ON public.vendors USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_vendor_name 
ON public.vendors USING btree (vendor_name) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_payment_method 
ON public.vendors USING gin (to_tsvector('english'::regconfig, payment_method)) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_vat_applicable 
ON public.vendors USING btree (vat_applicable) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_vendors_created_at 
ON public.vendors USING btree (created_at) 
TABLESPACE pg_default;

COMMIT;