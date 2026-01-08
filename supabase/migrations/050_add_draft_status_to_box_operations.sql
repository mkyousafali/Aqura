-- Add 'draft' status to box_operations table CHECK constraint

ALTER TABLE box_operations
DROP CONSTRAINT box_operations_status_check;

ALTER TABLE box_operations
ADD CONSTRAINT box_operations_status_check CHECK (
  status IN (
    'in_use',
    'pending_close',
    'completed',
    'cancelled',
    'draft'
  )
);
