-- Migration 71: Fix Existing Cash-on-Delivery Payments
-- Description: One-time update to mark existing COD payments as paid
-- Date: 2025-10-23
-- Version: 1.0.11
--
-- PROBLEM: Existing COD payments created BEFORE migration 70 are still showing is_paid = FALSE
-- SOLUTION: Update existing COD payments to trigger the auto-payment mechanism
--
-- This will:
-- 1. Find all COD payments with is_paid = FALSE
-- 2. Update them (trigger will fire and create transactions/tasks/notifications)
--
-- IMPORTANT: Apply Migration 72 FIRST to fix the trigger pattern matching!

BEGIN;

-- Update existing cash-on-delivery payments to trigger the automation
-- The BEFORE UPDATE trigger will detect the change and create transactions/tasks/notifications
UPDATE vendor_payment_schedule
SET 
    is_paid = TRUE,
    paid_date = NOW(),
    payment_status = 'paid',
    updated_at = NOW()
WHERE 
    -- Find cash-on-delivery payments (case-insensitive pattern matching)
    payment_method IS NOT NULL
    AND (
        payment_method ILIKE '%cash on delivery%'
        OR payment_method ILIKE '%cash-on-delivery%'
        OR payment_method ILIKE '%cod%'
        OR payment_method ILIKE 'cash on delivery'
        OR payment_method ILIKE 'cash-on-delivery'
        OR payment_method ILIKE 'cod'
    )
    -- That are not yet marked as paid
    AND (is_paid IS FALSE OR is_paid IS NULL)
    -- And don't already have transactions (prevent duplicates)
    AND NOT EXISTS (
        SELECT 1 
        FROM payment_transactions pt 
        WHERE pt.payment_schedule_id = vendor_payment_schedule.id
    );

-- Log the results
DO $$
DECLARE
    v_updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Migration 71 completed!';
    RAISE NOTICE '   - Updated % existing COD payments', v_updated_count;
    RAISE NOTICE '   - Transactions, tasks, and notifications have been created automatically';
END $$;

COMMIT;
