-- Clean up duplicate payment transactions
-- Migration: 60_cleanup_duplicate_payment_transactions.sql

-- Delete duplicate payment transactions, keeping only the first one for each payment_schedule_id
DELETE FROM payment_transactions 
WHERE id NOT IN (
    SELECT DISTINCT ON (payment_schedule_id) id
    FROM payment_transactions
    ORDER BY payment_schedule_id, created_at ASC
);

-- Add a unique constraint to prevent future duplicates
ALTER TABLE payment_transactions 
ADD CONSTRAINT unique_payment_schedule_transaction 
UNIQUE (payment_schedule_id);