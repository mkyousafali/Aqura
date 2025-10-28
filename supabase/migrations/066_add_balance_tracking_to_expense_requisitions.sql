-- Add balance tracking fields to expense_requisitions table
ALTER TABLE public.expense_requisitions 
ADD COLUMN IF NOT EXISTS used_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS remaining_balance NUMERIC DEFAULT 0;

-- Update existing records to set initial balance values
UPDATE public.expense_requisitions 
SET 
  used_amount = 0,
  remaining_balance = amount
WHERE used_amount IS NULL OR remaining_balance IS NULL;

-- Create index for balance queries
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_remaining_balance 
ON public.expense_requisitions(remaining_balance);

-- Add comment to new columns
COMMENT ON COLUMN public.expense_requisitions.used_amount IS 'Total amount used from this requisition across all scheduled bills';
COMMENT ON COLUMN public.expense_requisitions.remaining_balance IS 'Remaining balance available for new bills (amount - used_amount)';

-- Create function to update requisition balance when bills are saved
CREATE OR REPLACE FUNCTION update_requisition_balance()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if requisition_id is not null
  IF NEW.requisition_id IS NOT NULL THEN
    -- Update the expense_requisitions table
    UPDATE public.expense_requisitions
    SET 
      used_amount = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.expense_scheduler
        WHERE requisition_id = NEW.requisition_id
          AND status != 'cancelled'
      ),
      remaining_balance = amount - (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.expense_scheduler
        WHERE requisition_id = NEW.requisition_id
          AND status != 'cancelled'
      ),
      updated_at = now()
    WHERE id = NEW.requisition_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update balance when bills are saved
DROP TRIGGER IF EXISTS trigger_update_requisition_balance ON public.expense_scheduler;
CREATE TRIGGER trigger_update_requisition_balance
  AFTER INSERT OR UPDATE OR DELETE ON public.expense_scheduler
  FOR EACH ROW
  EXECUTE FUNCTION update_requisition_balance();

-- Also create function to handle old row in UPDATE/DELETE cases
CREATE OR REPLACE FUNCTION update_requisition_balance_old()
RETURNS TRIGGER AS $$
BEGIN
  -- Handle the old requisition_id if it exists and is different
  IF OLD.requisition_id IS NOT NULL AND (TG_OP = 'DELETE' OR OLD.requisition_id != NEW.requisition_id) THEN
    UPDATE public.expense_requisitions
    SET 
      used_amount = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.expense_scheduler
        WHERE requisition_id = OLD.requisition_id
          AND status != 'cancelled'
      ),
      remaining_balance = amount - (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.expense_scheduler
        WHERE requisition_id = OLD.requisition_id
          AND status != 'cancelled'
      ),
      updated_at = now()
    WHERE id = OLD.requisition_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create trigger for handling old values
DROP TRIGGER IF EXISTS trigger_update_requisition_balance_old ON public.expense_scheduler;
CREATE TRIGGER trigger_update_requisition_balance_old
  BEFORE UPDATE OR DELETE ON public.expense_scheduler
  FOR EACH ROW
  EXECUTE FUNCTION update_requisition_balance_old();