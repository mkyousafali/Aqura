-- Migration: Create receiving_records table
-- File: 29_receiving_records.sql
-- Description: Creates the receiving_records table for managing inventory receiving records with comprehensive validation

BEGIN;

-- Create trigger functions for receiving records
CREATE OR REPLACE FUNCTION calculate_return_totals()
RETURNS TRIGGER AS $$
BEGIN
    NEW.total_return_amount := COALESCE(NEW.expired_return_amount, 0) + 
                              COALESCE(NEW.near_expiry_return_amount, 0) + 
                              COALESCE(NEW.over_stock_return_amount, 0) + 
                              COALESCE(NEW.damage_return_amount, 0);
    NEW.final_bill_amount := NEW.bill_amount - NEW.total_return_amount;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_receiving_records_pr_excel_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_receiving_records_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_vendor_branch_match()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create receiving_records table
CREATE TABLE public.receiving_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  branch_id integer NOT NULL,
  vendor_id integer NOT NULL,
  bill_date date NOT NULL,
  bill_amount numeric(15, 2) NOT NULL,
  bill_number character varying(100) NULL,
  payment_method character varying(100) NULL,
  credit_period integer NULL,
  due_date date NULL,
  bank_name character varying(200) NULL,
  iban character varying(50) NULL,
  vendor_vat_number character varying(50) NULL,
  bill_vat_number character varying(50) NULL,
  vat_numbers_match boolean NULL,
  vat_mismatch_reason text NULL,
  branch_manager_user_id uuid NULL,
  shelf_stocker_user_ids uuid[] NULL DEFAULT '{}'::uuid[],
  accountant_user_id uuid NULL,
  purchasing_manager_user_id uuid NULL,
  expired_return_amount numeric(12, 2) NULL DEFAULT 0,
  near_expiry_return_amount numeric(12, 2) NULL DEFAULT 0,
  over_stock_return_amount numeric(12, 2) NULL DEFAULT 0,
  damage_return_amount numeric(12, 2) NULL DEFAULT 0,
  total_return_amount numeric(12, 2) NULL DEFAULT 0,
  final_bill_amount numeric(12, 2) NULL DEFAULT 0,
  expired_erp_document_type character varying(10) NULL,
  expired_erp_document_number character varying(100) NULL,
  expired_vendor_document_number character varying(100) NULL,
  near_expiry_erp_document_type character varying(10) NULL,
  near_expiry_erp_document_number character varying(100) NULL,
  near_expiry_vendor_document_number character varying(100) NULL,
  over_stock_erp_document_type character varying(10) NULL,
  over_stock_erp_document_number character varying(100) NULL,
  over_stock_vendor_document_number character varying(100) NULL,
  damage_erp_document_type character varying(10) NULL,
  damage_erp_document_number character varying(100) NULL,
  damage_vendor_document_number character varying(100) NULL,
  has_expired_returns boolean NULL DEFAULT false,
  has_near_expiry_returns boolean NULL DEFAULT false,
  has_over_stock_returns boolean NULL DEFAULT false,
  has_damage_returns boolean NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  inventory_manager_user_id uuid NULL,
  night_supervisor_user_ids uuid[] NULL DEFAULT '{}'::uuid[],
  warehouse_handler_user_ids uuid[] NULL DEFAULT '{}'::uuid[],
  certificate_url text NULL,
  certificate_generated_at timestamp with time zone NULL,
  certificate_file_name text NULL,
  original_bill_url text NULL,
  erp_purchase_invoice_reference character varying(255) NULL,
  updated_at timestamp with time zone NULL DEFAULT now(),
  pr_excel_file_url text NULL,
  CONSTRAINT receiving_records_pkey PRIMARY KEY (id),
  CONSTRAINT receiving_records_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE RESTRICT,
  CONSTRAINT receiving_records_branch_manager_user_id_fkey FOREIGN KEY (branch_manager_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT receiving_records_accountant_user_id_fkey FOREIGN KEY (accountant_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT receiving_records_purchasing_manager_user_id_fkey FOREIGN KEY (purchasing_manager_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT receiving_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
  CONSTRAINT receiving_records_inventory_manager_user_id_fkey FOREIGN KEY (inventory_manager_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT check_return_not_exceed_bill CHECK ((total_return_amount <= bill_amount)),
  CONSTRAINT check_credit_period_positive CHECK (
    (
      (credit_period IS NULL)
      OR (credit_period >= 0)
    )
  ),
  CONSTRAINT check_vat_mismatch_reason CHECK (
    (
      (vat_numbers_match IS NULL)
      OR (vat_numbers_match = true)
      OR (
        (vat_numbers_match = false)
        AND (vat_mismatch_reason IS NOT NULL)
        AND (
          length(
            TRIM(
              both
              FROM
                vat_mismatch_reason
            )
          ) > 0
        )
      )
    )
  ),
  CONSTRAINT check_total_return_amount CHECK ((total_return_amount >= (0)::numeric)),
  CONSTRAINT check_damage_return_amount CHECK ((damage_return_amount >= (0)::numeric)),
  CONSTRAINT check_due_date_after_bill_date CHECK (
    (
      (due_date IS NULL)
      OR (bill_date IS NULL)
      OR (due_date >= bill_date)
    )
  ),
  CONSTRAINT check_expired_return_amount CHECK ((expired_return_amount >= (0)::numeric)),
  CONSTRAINT check_final_bill_amount CHECK ((final_bill_amount >= (0)::numeric)),
  CONSTRAINT check_near_expiry_return_amount CHECK ((near_expiry_return_amount >= (0)::numeric)),
  CONSTRAINT check_over_stock_return_amount CHECK ((over_stock_return_amount >= (0)::numeric))
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_receiving_records_pr_excel_file_url 
ON public.receiving_records USING btree (pr_excel_file_url) 
TABLESPACE pg_default
WHERE (pr_excel_file_url IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_receiving_records_user_id 
ON public.receiving_records USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_branch_id 
ON public.receiving_records USING btree (branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_vendor_id 
ON public.receiving_records USING btree (vendor_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_branch_manager_user_id 
ON public.receiving_records USING btree (branch_manager_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_accountant_user_id 
ON public.receiving_records USING btree (accountant_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_purchasing_manager_user_id 
ON public.receiving_records USING btree (purchasing_manager_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_bill_date 
ON public.receiving_records USING btree (bill_date) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_due_date 
ON public.receiving_records USING btree (due_date) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_bill_amount 
ON public.receiving_records USING btree (bill_amount) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_bill_number 
ON public.receiving_records USING btree (bill_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_payment_method 
ON public.receiving_records USING btree (payment_method) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_credit_period 
ON public.receiving_records USING btree (credit_period) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_bank_name 
ON public.receiving_records USING btree (bank_name) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_iban 
ON public.receiving_records USING btree (iban) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_vendor_vat_number 
ON public.receiving_records USING btree (vendor_vat_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_bill_vat_number 
ON public.receiving_records USING btree (bill_vat_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_vat_numbers_match 
ON public.receiving_records USING btree (vat_numbers_match) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_expired_erp_document_number 
ON public.receiving_records USING btree (expired_erp_document_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_expired_vendor_document_number 
ON public.receiving_records USING btree (expired_vendor_document_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_near_expiry_erp_document_number 
ON public.receiving_records USING btree (near_expiry_erp_document_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_near_expiry_vendor_document_number 
ON public.receiving_records USING btree (near_expiry_vendor_document_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_over_stock_erp_document_number 
ON public.receiving_records USING btree (over_stock_erp_document_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_over_stock_vendor_document_number 
ON public.receiving_records USING btree (over_stock_vendor_document_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_damage_erp_document_number 
ON public.receiving_records USING btree (damage_erp_document_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_damage_vendor_document_number 
ON public.receiving_records USING btree (damage_vendor_document_number) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_total_return_amount 
ON public.receiving_records USING btree (total_return_amount) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_final_bill_amount 
ON public.receiving_records USING btree (final_bill_amount) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_created_at 
ON public.receiving_records USING btree (created_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_shelf_stocker_user_ids 
ON public.receiving_records USING gin (shelf_stocker_user_ids) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_inventory_manager_user_id 
ON public.receiving_records USING btree (inventory_manager_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_night_supervisor_user_ids 
ON public.receiving_records USING gin (night_supervisor_user_ids) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_warehouse_handler_user_ids 
ON public.receiving_records USING gin (warehouse_handler_user_ids) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_original_bill_url 
ON public.receiving_records USING btree (original_bill_url) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_erp_purchase_invoice_reference 
ON public.receiving_records USING btree (erp_purchase_invoice_reference) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_updated_at 
ON public.receiving_records USING btree (updated_at DESC) 
TABLESPACE pg_default;

-- Create triggers
CREATE TRIGGER trigger_calculate_return_totals 
BEFORE INSERT OR UPDATE ON receiving_records 
FOR EACH ROW
EXECUTE FUNCTION calculate_return_totals();

CREATE TRIGGER trigger_update_pr_excel_timestamp 
BEFORE UPDATE ON receiving_records 
FOR EACH ROW
EXECUTE FUNCTION update_receiving_records_pr_excel_timestamp();

CREATE TRIGGER trigger_update_receiving_records_updated_at 
BEFORE UPDATE ON receiving_records 
FOR EACH ROW
EXECUTE FUNCTION update_receiving_records_updated_at();

CREATE TRIGGER validate_vendor_branch_trigger 
BEFORE INSERT OR UPDATE ON receiving_records 
FOR EACH ROW
EXECUTE FUNCTION validate_vendor_branch_match();

COMMIT;