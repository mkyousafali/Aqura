-- =====================================================
-- Extend offer_usage_logs Table Migration
-- Created: 2025-11-20
-- Description: Adds order_id column to offer_usage_logs to link offers to orders
-- =====================================================

-- Add order_id column to offer_usage_logs table
ALTER TABLE offer_usage_logs
ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES orders(id) ON DELETE SET NULL;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_offer_usage_logs_order_id ON offer_usage_logs(order_id);

-- Create composite index for common queries
CREATE INDEX IF NOT EXISTS idx_offer_usage_logs_order_offer ON offer_usage_logs(order_id, offer_id);

-- Add column comment
COMMENT ON COLUMN offer_usage_logs.order_id IS 'Links offer usage to the order where it was applied (NULL for non-order usage)';
