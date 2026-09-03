-- Snapshot of the ERP shift-closing figures (fetched via the "Get Details" button in the
-- CloseBox ERP SALES card) saved at Close time, alongside the existing erp_* open-shift columns.

ALTER TABLE public.box_operations
    ADD COLUMN IF NOT EXISTS erp_closing_details jsonb;

COMMENT ON COLUMN public.box_operations.erp_closing_details IS
    'JSON snapshot of ERP shift-closing data (cash sales, card sales, total sales, counter status, closed date/time, match flags) as fetched from ERP when the Close button was pressed';
