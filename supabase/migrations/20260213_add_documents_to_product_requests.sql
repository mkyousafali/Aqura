-- Add document_url column to all product request tables
-- Stores a single document URL (invoice, BT report, etc.)

ALTER TABLE product_request_po
ADD COLUMN IF NOT EXISTS document_url TEXT DEFAULT NULL;

ALTER TABLE product_request_st
ADD COLUMN IF NOT EXISTS document_url TEXT DEFAULT NULL;

ALTER TABLE product_request_bt
ADD COLUMN IF NOT EXISTS document_url TEXT DEFAULT NULL;
