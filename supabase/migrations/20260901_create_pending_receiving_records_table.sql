-- Create "Pending Receiving Records" table — an exact structural copy of receiving_records.
-- Used when the Start Receiving intro screen's bill type is anything OTHER than "Original Bill":
-- the final posting step will insert into this table instead of receiving_records.
--
-- Scope notes (deliberate, to avoid breaking the existing system):
--   * Columns, defaults, check constraints, and the self-contained
--     calculate_receiving_amounts trigger are replicated exactly.
--   * The auto_create_payment_schedule trigger is intentionally NOT attached here:
--     it inserts into vendor_payment_schedule via a FK that points at receiving_records(id).
--     Attaching it to this table would either break (FK violation) or silently create
--     payment-schedule rows that look like they belong to the live table. Out of scope
--     for "exact copy of the table" — can be revisited later if pending records need
--     their own payment-schedule flow.
--   * receiving_tasks / vendor_payment_schedule are NOT touched and do NOT reference this
--     new table — no downstream automation is wired to it yet.
--   * Not added to the branch_sync / supabase_realtime publications — unclear blast radius,
--     left out until actually needed.

CREATE TABLE IF NOT EXISTS public.pending_receiving_records (
    id                                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                             uuid NOT NULL,
    branch_id                           integer NOT NULL,
    vendor_id                           integer NOT NULL,
    bill_date                           date NOT NULL,
    bill_amount                         numeric(15,2) NOT NULL,
    bill_number                         character varying(100),
    payment_method                      character varying(100),
    credit_period                       integer,
    due_date                            date,
    bank_name                           character varying(200),
    iban                                character varying(50),
    vendor_vat_number                   character varying(50),
    bill_vat_number                     character varying(50),
    vat_numbers_match                   boolean,
    vat_mismatch_reason                 text,
    branch_manager_user_id              uuid,
    shelf_stocker_user_ids              uuid[] DEFAULT '{}'::uuid[],
    accountant_user_id                  uuid,
    purchasing_manager_user_id          uuid,
    expired_return_amount               numeric(12,2) DEFAULT 0,
    near_expiry_return_amount           numeric(12,2) DEFAULT 0,
    over_stock_return_amount            numeric(12,2) DEFAULT 0,
    damage_return_amount                numeric(12,2) DEFAULT 0,
    total_return_amount                 numeric(12,2) DEFAULT 0,
    final_bill_amount                   numeric(12,2) DEFAULT 0,
    expired_erp_document_type           character varying(10),
    expired_erp_document_number         character varying(100),
    expired_vendor_document_number      character varying(100),
    near_expiry_erp_document_type       character varying(10),
    near_expiry_erp_document_number     character varying(100),
    near_expiry_vendor_document_number  character varying(100),
    over_stock_erp_document_type        character varying(10),
    over_stock_erp_document_number      character varying(100),
    over_stock_vendor_document_number   character varying(100),
    damage_erp_document_type            character varying(10),
    damage_erp_document_number          character varying(100),
    damage_vendor_document_number       character varying(100),
    has_expired_returns                 boolean DEFAULT false,
    has_near_expiry_returns             boolean DEFAULT false,
    has_over_stock_returns              boolean DEFAULT false,
    has_damage_returns                  boolean DEFAULT false,
    created_at                          timestamp with time zone NOT NULL DEFAULT now(),
    inventory_manager_user_id           uuid,
    night_supervisor_user_ids           uuid[] DEFAULT '{}'::uuid[],
    warehouse_handler_user_ids          uuid[] DEFAULT '{}'::uuid[],
    certificate_url                     text,
    certificate_generated_at            timestamp with time zone,
    certificate_file_name               text,
    original_bill_url                   text,
    erp_purchase_invoice_reference      character varying(255),
    updated_at                          timestamp with time zone DEFAULT now(),
    pr_excel_file_url                   text,
    erp_purchase_invoice_uploaded       boolean DEFAULT false,
    pr_excel_file_uploaded              boolean DEFAULT false,
    original_bill_uploaded              boolean DEFAULT false,

    -- Same check constraints as receiving_records
    CONSTRAINT check_pending_credit_period_positive CHECK (credit_period IS NULL OR credit_period >= 0),
    CONSTRAINT check_pending_damage_return_amount CHECK (damage_return_amount >= 0::numeric),
    CONSTRAINT check_pending_due_date_after_bill_date CHECK (due_date IS NULL OR bill_date IS NULL OR due_date >= bill_date),
    CONSTRAINT check_pending_expired_return_amount CHECK (expired_return_amount >= 0::numeric),
    CONSTRAINT check_pending_final_bill_amount CHECK (final_bill_amount >= 0::numeric),
    CONSTRAINT check_pending_near_expiry_return_amount CHECK (near_expiry_return_amount >= 0::numeric),
    CONSTRAINT check_pending_over_stock_return_amount CHECK (over_stock_return_amount >= 0::numeric),
    CONSTRAINT check_pending_return_not_exceed_bill CHECK (total_return_amount <= bill_amount),
    CONSTRAINT check_pending_total_return_amount CHECK (total_return_amount >= 0::numeric),
    CONSTRAINT check_pending_vat_mismatch_reason CHECK (
        vat_numbers_match IS NULL OR vat_numbers_match = true OR
        (vat_numbers_match = false AND vat_mismatch_reason IS NOT NULL AND length(TRIM(BOTH FROM vat_mismatch_reason)) > 0)
    ),

    -- Same foreign keys as receiving_records (still reference the real, shared tables)
    CONSTRAINT pending_receiving_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT pending_receiving_records_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE RESTRICT,
    CONSTRAINT pending_receiving_records_vendor_fkey FOREIGN KEY (vendor_id, branch_id) REFERENCES vendors(erp_vendor_id, branch_id) ON DELETE RESTRICT,
    CONSTRAINT pending_receiving_records_branch_manager_user_id_fkey FOREIGN KEY (branch_manager_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT pending_receiving_records_accountant_user_id_fkey FOREIGN KEY (accountant_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT pending_receiving_records_purchasing_manager_user_id_fkey FOREIGN KEY (purchasing_manager_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT pending_receiving_records_inventory_manager_user_id_fkey FOREIGN KEY (inventory_manager_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Indexes (mirroring receiving_records' index set)
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_accountant_user_id ON public.pending_receiving_records (accountant_user_id);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_bank_name ON public.pending_receiving_records (bank_name);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_bill_amount ON public.pending_receiving_records (bill_amount);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_bill_date ON public.pending_receiving_records (bill_date);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_bill_number ON public.pending_receiving_records (bill_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_bill_vat_number ON public.pending_receiving_records (bill_vat_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_branch_id ON public.pending_receiving_records (branch_id);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_branch_manager_user_id ON public.pending_receiving_records (branch_manager_user_id);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_created_at ON public.pending_receiving_records (created_at);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_credit_period ON public.pending_receiving_records (credit_period);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_damage_erp_document_number ON public.pending_receiving_records (damage_erp_document_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_damage_vendor_document_number ON public.pending_receiving_records (damage_vendor_document_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_due_date ON public.pending_receiving_records (due_date);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_erp_purchase_invoice_reference ON public.pending_receiving_records (erp_purchase_invoice_reference);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_erp_purchase_invoice_uploaded ON public.pending_receiving_records (erp_purchase_invoice_uploaded);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_expired_erp_document_number ON public.pending_receiving_records (expired_erp_document_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_expired_vendor_document_number ON public.pending_receiving_records (expired_vendor_document_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_final_bill_amount ON public.pending_receiving_records (final_bill_amount);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_iban ON public.pending_receiving_records (iban);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_inventory_manager_user_id ON public.pending_receiving_records (inventory_manager_user_id);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_near_expiry_erp_document_number ON public.pending_receiving_records (near_expiry_erp_document_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_near_expiry_vendor_document_number ON public.pending_receiving_records (near_expiry_vendor_document_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_night_supervisor_user_ids ON public.pending_receiving_records USING gin (night_supervisor_user_ids);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_original_bill_uploaded ON public.pending_receiving_records (original_bill_uploaded);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_original_bill_url ON public.pending_receiving_records (original_bill_url);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_over_stock_erp_document_number ON public.pending_receiving_records (over_stock_erp_document_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_over_stock_vendor_document_number ON public.pending_receiving_records (over_stock_vendor_document_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_payment_method ON public.pending_receiving_records (payment_method);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_pr_excel_file_uploaded ON public.pending_receiving_records (pr_excel_file_uploaded);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_pr_excel_file_url ON public.pending_receiving_records (pr_excel_file_url) WHERE pr_excel_file_url IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_purchasing_manager_user_id ON public.pending_receiving_records (purchasing_manager_user_id);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_shelf_stocker_user_ids ON public.pending_receiving_records USING gin (shelf_stocker_user_ids);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_total_return_amount ON public.pending_receiving_records (total_return_amount);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_updated_at ON public.pending_receiving_records (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_user_id ON public.pending_receiving_records (user_id);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_vat_numbers_match ON public.pending_receiving_records (vat_numbers_match);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_vendor_id ON public.pending_receiving_records (vendor_id);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_vendor_vat_number ON public.pending_receiving_records (vendor_vat_number);
CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_warehouse_handler_user_ids ON public.pending_receiving_records USING gin (warehouse_handler_user_ids);

-- Reuse the existing, self-contained calculate_receiving_amounts() trigger function
-- (only touches NEW.* fields that also exist on this table — safe to reuse as-is).
DROP TRIGGER IF EXISTS calculate_pending_receiving_amounts_trigger ON public.pending_receiving_records;
CREATE TRIGGER calculate_pending_receiving_amounts_trigger
    BEFORE INSERT OR UPDATE ON public.pending_receiving_records
    FOR EACH ROW EXECUTE FUNCTION public.calculate_receiving_amounts();

-- Row Level Security — same permissive policies as receiving_records
ALTER TABLE public.pending_receiving_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS allow_select ON public.pending_receiving_records;
DROP POLICY IF EXISTS allow_insert ON public.pending_receiving_records;
DROP POLICY IF EXISTS allow_update ON public.pending_receiving_records;
DROP POLICY IF EXISTS allow_delete ON public.pending_receiving_records;

CREATE POLICY allow_select ON public.pending_receiving_records FOR SELECT USING (true);
CREATE POLICY allow_insert ON public.pending_receiving_records FOR INSERT WITH CHECK (true);
CREATE POLICY allow_update ON public.pending_receiving_records FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY allow_delete ON public.pending_receiving_records FOR DELETE USING (true);

-- Grants — same as receiving_records
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pending_receiving_records TO anon;
GRANT SELECT ON public.pending_receiving_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER, TRUNCATE ON public.pending_receiving_records TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER, TRUNCATE ON public.pending_receiving_records TO supabase_admin;

COMMENT ON TABLE public.pending_receiving_records IS
  'Structural copy of receiving_records. Used for Start Receiving submissions whose bill type is NOT "Original Bill" (Delivery Note / Duplicate Bill / Without Bill) — those get posted here instead of receiving_records at the final step.';
