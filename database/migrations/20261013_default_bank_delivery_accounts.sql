begin;

alter table public.branch_default_positions
  add column if not exists bank_delivery_ledger_id bigint,
  add column if not exists bank_delivery_ledger_name text;

comment on column public.branch_default_positions.bank_delivery_ledger_id is
  'Default ERP bank ledger ID for Bank on Delivery entries in this branch.';

comment on column public.branch_default_positions.bank_delivery_ledger_name is
  'Snapshot of the default ERP bank ledger name for Bank on Delivery entries in this branch.';

commit;
