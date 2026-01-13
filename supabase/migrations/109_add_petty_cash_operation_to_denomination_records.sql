-- Add petty_cash_operation column to denomination_records table
-- This column stores details about petty cash transfers including:
-- - transferred_from_box_number: the source box number
-- - transferred_from_user_id: the user ID of the cashier
-- - closing_details: the closing details from the source box

ALTER TABLE public.denomination_records
ADD COLUMN IF NOT EXISTS petty_cash_operation jsonb DEFAULT NULL;

-- Create index for efficient querying of petty cash operations
CREATE INDEX IF NOT EXISTS idx_denomination_records_petty_cash_operation 
ON public.denomination_records USING gin (petty_cash_operation);

-- Add comment to clarify the column structure
COMMENT ON COLUMN public.denomination_records.petty_cash_operation IS 'JSONB column storing petty cash operation details: {transferred_from_box_number, transferred_from_user_id, closing_details}';
