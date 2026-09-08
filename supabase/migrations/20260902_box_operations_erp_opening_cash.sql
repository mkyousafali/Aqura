-- Add the ERP counter's opening cash (as entered by the cashier in the ERP
-- when they opened the shift) to box_operations, alongside the other
-- erp_* columns added in 20260902_box_operations_erp_counter_details.sql.

ALTER TABLE public.box_operations
    ADD COLUMN IF NOT EXISTS erp_opening_cash_physical numeric(15,2),
    ADD COLUMN IF NOT EXISTS erp_opening_cash_system numeric(15,2);

COMMENT ON COLUMN public.box_operations.erp_opening_cash_physical IS 'ERP CounterShift.OpenCashPhysical - cash the cashier physically entered when opening the counter in the ERP';
COMMENT ON COLUMN public.box_operations.erp_opening_cash_system IS 'ERP CounterShift.OpeningCashBySystem - expected opening cash per ERP system';
