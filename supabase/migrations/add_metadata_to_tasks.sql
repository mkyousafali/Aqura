-- =====================================================
-- Add metadata column to tasks table
-- =====================================================
-- Purpose: Store additional task information like payment_schedule_id
-- for payment-related tasks
-- =====================================================

-- Add metadata column to tasks table (JSONB type for flexible data storage)
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT NULL;

-- Create an index on metadata for better query performance
CREATE INDEX IF NOT EXISTS idx_tasks_metadata ON tasks USING GIN (metadata);

-- Add comment to explain the column
COMMENT ON COLUMN tasks.metadata IS 'JSONB field to store task-specific metadata like payment_schedule_id, payment_type, etc.';

-- Example metadata structure for payment tasks:
-- {
--   "payment_schedule_id": "uuid-of-payment-record",
--   "payment_type": "vendor_payment",
--   "bill_number": "INV-2025-001",
--   "vendor_name": "ABC Suppliers"
-- }
