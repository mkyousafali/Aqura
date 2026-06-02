-- Migration: Remove Media > Dashboard > Flyer Master and Products buttons
-- Removes button_permissions and sidebar_buttons entries for FLYER_MASTER and PRODUCTS_DASHBOARD

-- Step 1: Remove all button_permissions rows for FLYER_MASTER and PRODUCTS_DASHBOARD
DELETE FROM public.button_permissions
WHERE button_id IN (
    SELECT id FROM public.sidebar_buttons
    WHERE button_code IN ('FLYER_MASTER', 'PRODUCTS_DASHBOARD')
);

-- Step 2: Remove the sidebar_buttons rows themselves
DELETE FROM public.sidebar_buttons
WHERE button_code IN ('FLYER_MASTER', 'PRODUCTS_DASHBOARD');
