-- Migration: Fix receiving_records vendor relationship
-- File: 56_fix_receiving_records_vendor_relationship.sql
-- Description: Fixes the foreign key relationship between receiving_records and vendors tables

BEGIN;

-- Add the missing foreign key constraint for vendor relationship
-- The vendors table has a composite primary key (erp_vendor_id, branch_id)
-- So we need to reference both fields in the receiving_records table

-- Since receiving_records.vendor_id should reference vendors.erp_vendor_id
-- and receiving_records.branch_id should reference vendors.branch_id
-- we can create a foreign key constraint using both fields

ALTER TABLE public.receiving_records 
ADD CONSTRAINT receiving_records_vendor_fkey 
FOREIGN KEY (vendor_id, branch_id) 
REFERENCES vendors (erp_vendor_id, branch_id) 
ON DELETE RESTRICT;

-- Add comment to clarify the relationship
COMMENT ON CONSTRAINT receiving_records_vendor_fkey ON receiving_records IS 
'Foreign key constraint linking receiving_records to vendors using composite key (vendor_id -> erp_vendor_id, branch_id -> branch_id)';

COMMIT;