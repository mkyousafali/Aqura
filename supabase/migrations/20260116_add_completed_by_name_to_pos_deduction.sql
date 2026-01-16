-- Add completed_by_name column to pos_deduction_transfers table

ALTER TABLE pos_deduction_transfers 
ADD COLUMN IF NOT EXISTS completed_by_name VARCHAR(255);

-- Enable realtime for pos_deduction_transfers table
ALTER PUBLICATION supabase_realtime ADD TABLE pos_deduction_transfers;
