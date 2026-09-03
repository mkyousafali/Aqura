-- Add ERP counter/shift columns to box_operations so the exact ERP counter
-- session a cashier had open (fetched via the ERP tunnel in CounterCheck.svelte)
-- is stored on the row itself instead of only inside the free-text notes JSON.

ALTER TABLE public.box_operations
    ADD COLUMN IF NOT EXISTS erp_counter_id integer,
    ADD COLUMN IF NOT EXISTS erp_counter_shift_id bigint,
    ADD COLUMN IF NOT EXISTS erp_counter_name text,
    ADD COLUMN IF NOT EXISTS erp_shift_name text,
    ADD COLUMN IF NOT EXISTS erp_shift_start_date date,
    ADD COLUMN IF NOT EXISTS erp_shift_start_time time without time zone,
    ADD COLUMN IF NOT EXISTS erp_branch_id integer;

COMMENT ON COLUMN public.box_operations.erp_counter_id IS 'ERP CounterID (Counter table) the cashier had open, fetched from ERP at Start time';
COMMENT ON COLUMN public.box_operations.erp_counter_shift_id IS 'ERP CounterShift.CounterShiftID for the open shift used for this operation';
COMMENT ON COLUMN public.box_operations.erp_counter_name IS 'ERP Counter.CounterName, e.g. POS-2';
COMMENT ON COLUMN public.box_operations.erp_shift_name IS 'ERP CounterShift.ShiftName, e.g. Shift3';
COMMENT ON COLUMN public.box_operations.erp_shift_start_date IS 'ERP CounterShift.TransactionDate (shift open date)';
COMMENT ON COLUMN public.box_operations.erp_shift_start_time IS 'ERP CounterShift.OpenTime (shift open time, time-only)';
COMMENT ON COLUMN public.box_operations.erp_branch_id IS 'ERP BranchID the counter/shift belongs to (from user_erp_credentials.erp_branch_id)';
