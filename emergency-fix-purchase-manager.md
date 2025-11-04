-- =====================================================
-- EMERGENCY FIX - REMOVE PAYMENT SCHEDULE CHECK
-- =====================================================
-- Temporarily disable the payment schedule check for purchase managers
-- to allow them to complete tasks until the table name is fixed
-- =====================================================

-- Update the API endpoint to skip payment schedule validation
-- This is a temporary workaround until we can properly fix the function

-- Let's create a simple temporary fix by updating the existing function signature
-- We'll just comment out the problematic payment schedule check