create table public.receiving_records (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  branch_id integer not null,
  vendor_id integer not null,
  bill_date date not null,
  bill_amount numeric(15, 2) not null,
  bill_number character varying(100) null,
  payment_method character varying(100) null,
  credit_period integer null,
  due_date date null,
  bank_name character varying(200) null,
  iban character varying(50) null,
  vendor_vat_number character varying(50) null,
  bill_vat_number character varying(50) null,
  vat_numbers_match boolean null,
  vat_mismatch_reason text null,
  branch_manager_user_id uuid null,
  shelf_stocker_user_ids uuid[] null default '{}'::uuid[],
  accountant_user_id uuid null,
  purchasing_manager_user_id uuid null,
  expired_return_amount numeric(12, 2) null default 0,
  near_expiry_return_amount numeric(12, 2) null default 0,
  over_stock_return_amount numeric(12, 2) null default 0,
  damage_return_amount numeric(12, 2) null default 0,
  total_return_amount numeric(12, 2) null default 0,
  final_bill_amount numeric(12, 2) null default 0,
  expired_erp_document_type character varying(10) null,
  expired_erp_document_number character varying(100) null,
  expired_vendor_document_number character varying(100) null,
  near_expiry_erp_document_type character varying(10) null,
  near_expiry_erp_document_number character varying(100) null,
  near_expiry_vendor_document_number character varying(100) null,
  over_stock_erp_document_type character varying(10) null,
  over_stock_erp_document_number character varying(100) null,
  over_stock_vendor_document_number character varying(100) null,
  damage_erp_document_type character varying(10) null,
  damage_erp_document_number character varying(100) null,
  damage_vendor_document_number character varying(100) null,
  has_expired_returns boolean null default false,
  has_near_expiry_returns boolean null default false,
  has_over_stock_returns boolean null default false,
  has_damage_returns boolean null default false,
  created_at timestamp with time zone not null default now(),
  inventory_manager_user_id uuid null,
  night_supervisor_user_ids uuid[] null default '{}'::uuid[],
  warehouse_handler_user_ids uuid[] null default '{}'::uuid[],
  certificate_url text null,
  certificate_generated_at timestamp with time zone null,
  certificate_file_name text null,
  original_bill_url text null,
  erp_purchase_invoice_reference character varying(255) null,
  updated_at timestamp with time zone null default now(),
  pr_excel_file_url text null,
  constraint receiving_records_pkey primary key (id),
  constraint receiving_records_branch_id_fkey foreign KEY (branch_id) references branches (id) on delete RESTRICT,
  constraint receiving_records_branch_manager_user_id_fkey foreign KEY (branch_manager_user_id) references users (id) on delete set null,
  constraint receiving_records_inventory_manager_user_id_fkey foreign KEY (inventory_manager_user_id) references users (id) on delete set null,
  constraint receiving_records_purchasing_manager_user_id_fkey foreign KEY (purchasing_manager_user_id) references users (id) on delete set null,
  constraint receiving_records_user_id_fkey foreign KEY (user_id) references users (id) on delete RESTRICT,
  constraint receiving_records_accountant_user_id_fkey foreign KEY (accountant_user_id) references users (id) on delete set null,
  constraint receiving_records_vendor_fkey foreign KEY (vendor_id, branch_id) references vendors (erp_vendor_id, branch_id) on delete RESTRICT,
  constraint check_total_return_amount check ((total_return_amount >= (0)::numeric)),
  constraint check_credit_period_positive check (
    (
      (credit_period is null)
      or (credit_period >= 0)
    )
  ),
  constraint check_vat_mismatch_reason check (
    (
      (vat_numbers_match is null)
      or (vat_numbers_match = true)
      or (
        (vat_numbers_match = false)
        and (vat_mismatch_reason is not null)
        and (
          length(
            TRIM(
              both
              from
                vat_mismatch_reason
            )
          ) > 0
        )
      )
    )
  ),
  constraint check_damage_return_amount check ((damage_return_amount >= (0)::numeric)),
  constraint check_due_date_after_bill_date check (
    (
      (due_date is null)
      or (bill_date is null)
      or (due_date >= bill_date)
    )
  ),
  constraint check_expired_return_amount check ((expired_return_amount >= (0)::numeric)),
  constraint check_final_bill_amount check ((final_bill_amount >= (0)::numeric)),
  constraint check_near_expiry_return_amount check ((near_expiry_return_amount >= (0)::numeric)),
  constraint check_over_stock_return_amount check ((over_stock_return_amount >= (0)::numeric)),
  constraint check_return_not_exceed_bill check ((total_return_amount <= bill_amount))
) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_pr_excel_file_url on public.receiving_records using btree (pr_excel_file_url) TABLESPACE pg_default
where
  (pr_excel_file_url is not null);

create index IF not exists idx_receiving_records_user_id on public.receiving_records using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_branch_id on public.receiving_records using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_vendor_id on public.receiving_records using btree (vendor_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_branch_manager_user_id on public.receiving_records using btree (branch_manager_user_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_accountant_user_id on public.receiving_records using btree (accountant_user_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_purchasing_manager_user_id on public.receiving_records using btree (purchasing_manager_user_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_bill_date on public.receiving_records using btree (bill_date) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_due_date on public.receiving_records using btree (due_date) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_bill_amount on public.receiving_records using btree (bill_amount) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_bill_number on public.receiving_records using btree (bill_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_payment_method on public.receiving_records using btree (payment_method) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_credit_period on public.receiving_records using btree (credit_period) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_bank_name on public.receiving_records using btree (bank_name) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_iban on public.receiving_records using btree (iban) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_vendor_vat_number on public.receiving_records using btree (vendor_vat_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_bill_vat_number on public.receiving_records using btree (bill_vat_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_vat_numbers_match on public.receiving_records using btree (vat_numbers_match) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_expired_erp_document_number on public.receiving_records using btree (expired_erp_document_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_expired_vendor_document_number on public.receiving_records using btree (expired_vendor_document_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_near_expiry_erp_document_number on public.receiving_records using btree (near_expiry_erp_document_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_near_expiry_vendor_document_number on public.receiving_records using btree (near_expiry_vendor_document_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_over_stock_erp_document_number on public.receiving_records using btree (over_stock_erp_document_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_over_stock_vendor_document_number on public.receiving_records using btree (over_stock_vendor_document_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_damage_erp_document_number on public.receiving_records using btree (damage_erp_document_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_damage_vendor_document_number on public.receiving_records using btree (damage_vendor_document_number) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_total_return_amount on public.receiving_records using btree (total_return_amount) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_final_bill_amount on public.receiving_records using btree (final_bill_amount) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_created_at on public.receiving_records using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_shelf_stocker_user_ids on public.receiving_records using gin (shelf_stocker_user_ids) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_inventory_manager_user_id on public.receiving_records using btree (inventory_manager_user_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_night_supervisor_user_ids on public.receiving_records using gin (night_supervisor_user_ids) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_warehouse_handler_user_ids on public.receiving_records using gin (warehouse_handler_user_ids) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_original_bill_url on public.receiving_records using btree (original_bill_url) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_erp_purchase_invoice_reference on public.receiving_records using btree (erp_purchase_invoice_reference) TABLESPACE pg_default;

create index IF not exists idx_receiving_records_updated_at on public.receiving_records using btree (updated_at desc) TABLESPACE pg_default;

create trigger calculate_receiving_amounts_trigger BEFORE INSERT
or
update on receiving_records for EACH row
execute FUNCTION calculate_receiving_amounts ();

create trigger trigger_auto_create_payment_schedule
after INSERT
or
update OF certificate_url on receiving_records for EACH row
execute FUNCTION auto_create_payment_schedule ();