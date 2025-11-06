-- ================================================================
-- TABLE SCHEMA: receiving_records
-- Generated: 2025-11-06T11:09:39.019Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.receiving_records (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    branch_id integer NOT NULL,
    vendor_id integer NOT NULL,
    bill_date date NOT NULL,
    bill_amount numeric NOT NULL,
    bill_number character varying,
    payment_method character varying,
    credit_period integer,
    due_date date,
    bank_name character varying,
    iban character varying,
    vendor_vat_number character varying,
    bill_vat_number character varying,
    vat_numbers_match boolean,
    vat_mismatch_reason text,
    branch_manager_user_id uuid,
    shelf_stocker_user_ids ARRAY DEFAULT '{}'::uuid[],
    accountant_user_id uuid,
    purchasing_manager_user_id uuid,
    expired_return_amount numeric DEFAULT 0,
    near_expiry_return_amount numeric DEFAULT 0,
    over_stock_return_amount numeric DEFAULT 0,
    damage_return_amount numeric DEFAULT 0,
    total_return_amount numeric DEFAULT 0,
    final_bill_amount numeric DEFAULT 0,
    expired_erp_document_type character varying,
    expired_erp_document_number character varying,
    expired_vendor_document_number character varying,
    near_expiry_erp_document_type character varying,
    near_expiry_erp_document_number character varying,
    near_expiry_vendor_document_number character varying,
    over_stock_erp_document_type character varying,
    over_stock_erp_document_number character varying,
    over_stock_vendor_document_number character varying,
    damage_erp_document_type character varying,
    damage_erp_document_number character varying,
    damage_vendor_document_number character varying,
    has_expired_returns boolean DEFAULT false,
    has_near_expiry_returns boolean DEFAULT false,
    has_over_stock_returns boolean DEFAULT false,
    has_damage_returns boolean DEFAULT false,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    inventory_manager_user_id uuid,
    night_supervisor_user_ids ARRAY DEFAULT '{}'::uuid[],
    warehouse_handler_user_ids ARRAY DEFAULT '{}'::uuid[],
    certificate_url text,
    certificate_generated_at timestamp with time zone,
    certificate_file_name text,
    original_bill_url text,
    erp_purchase_invoice_reference character varying,
    updated_at timestamp with time zone DEFAULT now(),
    pr_excel_file_url text,
    erp_purchase_invoice_uploaded boolean DEFAULT false,
    pr_excel_file_uploaded boolean DEFAULT false,
    original_bill_uploaded boolean DEFAULT false
);

-- Table comment
COMMENT ON TABLE public.receiving_records IS 'Table for receiving records management';

-- Column comments
COMMENT ON COLUMN public.receiving_records.id IS 'Primary key identifier';
COMMENT ON COLUMN public.receiving_records.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.receiving_records.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.receiving_records.vendor_id IS 'Foreign key reference to vendor table';
COMMENT ON COLUMN public.receiving_records.bill_date IS 'Date field';
COMMENT ON COLUMN public.receiving_records.bill_amount IS 'Monetary amount';
COMMENT ON COLUMN public.receiving_records.bill_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.payment_method IS 'payment method field';
COMMENT ON COLUMN public.receiving_records.credit_period IS 'credit period field';
COMMENT ON COLUMN public.receiving_records.due_date IS 'Date field';
COMMENT ON COLUMN public.receiving_records.bank_name IS 'Name field';
COMMENT ON COLUMN public.receiving_records.iban IS 'iban field';
COMMENT ON COLUMN public.receiving_records.vendor_vat_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.bill_vat_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.vat_numbers_match IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.vat_mismatch_reason IS 'vat mismatch reason field';
COMMENT ON COLUMN public.receiving_records.branch_manager_user_id IS 'Foreign key reference to branch_manager_user table';
COMMENT ON COLUMN public.receiving_records.shelf_stocker_user_ids IS 'shelf stocker user ids field';
COMMENT ON COLUMN public.receiving_records.accountant_user_id IS 'Foreign key reference to accountant_user table';
COMMENT ON COLUMN public.receiving_records.purchasing_manager_user_id IS 'Foreign key reference to purchasing_manager_user table';
COMMENT ON COLUMN public.receiving_records.expired_return_amount IS 'Monetary amount';
COMMENT ON COLUMN public.receiving_records.near_expiry_return_amount IS 'Monetary amount';
COMMENT ON COLUMN public.receiving_records.over_stock_return_amount IS 'Monetary amount';
COMMENT ON COLUMN public.receiving_records.damage_return_amount IS 'Monetary amount';
COMMENT ON COLUMN public.receiving_records.total_return_amount IS 'Monetary amount';
COMMENT ON COLUMN public.receiving_records.final_bill_amount IS 'Monetary amount';
COMMENT ON COLUMN public.receiving_records.expired_erp_document_type IS 'expired erp document type field';
COMMENT ON COLUMN public.receiving_records.expired_erp_document_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.expired_vendor_document_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.near_expiry_erp_document_type IS 'near expiry erp document type field';
COMMENT ON COLUMN public.receiving_records.near_expiry_erp_document_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.near_expiry_vendor_document_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.over_stock_erp_document_type IS 'over stock erp document type field';
COMMENT ON COLUMN public.receiving_records.over_stock_erp_document_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.over_stock_vendor_document_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.damage_erp_document_type IS 'damage erp document type field';
COMMENT ON COLUMN public.receiving_records.damage_erp_document_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.damage_vendor_document_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_records.has_expired_returns IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_records.has_near_expiry_returns IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_records.has_over_stock_returns IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_records.has_damage_returns IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_records.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.receiving_records.inventory_manager_user_id IS 'Foreign key reference to inventory_manager_user table';
COMMENT ON COLUMN public.receiving_records.night_supervisor_user_ids IS 'night supervisor user ids field';
COMMENT ON COLUMN public.receiving_records.warehouse_handler_user_ids IS 'warehouse handler user ids field';
COMMENT ON COLUMN public.receiving_records.certificate_url IS 'URL or file path';
COMMENT ON COLUMN public.receiving_records.certificate_generated_at IS 'certificate generated at field';
COMMENT ON COLUMN public.receiving_records.certificate_file_name IS 'Name field';
COMMENT ON COLUMN public.receiving_records.original_bill_url IS 'URL or file path';
COMMENT ON COLUMN public.receiving_records.erp_purchase_invoice_reference IS 'erp purchase invoice reference field';
COMMENT ON COLUMN public.receiving_records.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.receiving_records.pr_excel_file_url IS 'URL or file path';
COMMENT ON COLUMN public.receiving_records.erp_purchase_invoice_uploaded IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_records.pr_excel_file_uploaded IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_records.original_bill_uploaded IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS receiving_records_pkey ON public.receiving_records USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_receiving_records_user_id ON public.receiving_records USING btree (user_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_receiving_records_branch_id ON public.receiving_records USING btree (branch_id);

-- Foreign key index for vendor_id
CREATE INDEX IF NOT EXISTS idx_receiving_records_vendor_id ON public.receiving_records USING btree (vendor_id);

-- Foreign key index for branch_manager_user_id
CREATE INDEX IF NOT EXISTS idx_receiving_records_branch_manager_user_id ON public.receiving_records USING btree (branch_manager_user_id);

-- Foreign key index for accountant_user_id
CREATE INDEX IF NOT EXISTS idx_receiving_records_accountant_user_id ON public.receiving_records USING btree (accountant_user_id);

-- Foreign key index for purchasing_manager_user_id
CREATE INDEX IF NOT EXISTS idx_receiving_records_purchasing_manager_user_id ON public.receiving_records USING btree (purchasing_manager_user_id);

-- Foreign key index for inventory_manager_user_id
CREATE INDEX IF NOT EXISTS idx_receiving_records_inventory_manager_user_id ON public.receiving_records USING btree (inventory_manager_user_id);

-- Date index for bill_date
CREATE INDEX IF NOT EXISTS idx_receiving_records_bill_date ON public.receiving_records USING btree (bill_date);

-- Date index for due_date
CREATE INDEX IF NOT EXISTS idx_receiving_records_due_date ON public.receiving_records USING btree (due_date);

-- Date index for certificate_generated_at
CREATE INDEX IF NOT EXISTS idx_receiving_records_certificate_generated_at ON public.receiving_records USING btree (certificate_generated_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for receiving_records

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.receiving_records ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "receiving_records_select_policy" ON public.receiving_records
    FOR SELECT USING (true);

CREATE POLICY "receiving_records_insert_policy" ON public.receiving_records
    FOR INSERT WITH CHECK (true);

CREATE POLICY "receiving_records_update_policy" ON public.receiving_records
    FOR UPDATE USING (true);

CREATE POLICY "receiving_records_delete_policy" ON public.receiving_records
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for receiving_records

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.receiving_records (user_id, branch_id, vendor_id)
VALUES ('uuid-example', 123, 123);
*/

-- Select example
/*
SELECT * FROM public.receiving_records 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.receiving_records 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF RECEIVING_RECORDS SCHEMA
-- ================================================================
