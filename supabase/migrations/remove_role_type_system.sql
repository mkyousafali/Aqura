-- Migration: Remove role_type system and replace with boolean flags
-- Date: 2025-12-12
-- Purpose: Simplify user access control by removing role_type, keeping button and approval permissions

-- ============================================================
-- STEP 1: Add new boolean columns to users table
-- ============================================================
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_master_admin BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- ============================================================
-- STEP 2: Migrate existing data from role_type to boolean columns
-- ============================================================
-- Set is_master_admin for Master Admin users
UPDATE users 
SET is_master_admin = true 
WHERE role_type = 'Master Admin';

-- Set is_admin for Admin users (excluding Master Admins)
UPDATE users 
SET is_admin = true 
WHERE role_type = 'Admin' AND is_master_admin = false;

-- ============================================================
-- STEP 3: Create indexes on new columns for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_users_is_master_admin ON users(is_master_admin);
CREATE INDEX IF NOT EXISTS idx_users_is_admin ON users(is_admin);

-- ============================================================
-- STEP 4: Drop RLS policies that depend on role_type
-- ============================================================
-- Flyer templates policies
DROP POLICY IF EXISTS "Admins can delete flyer templates" ON flyer_templates;
DROP POLICY IF EXISTS "Admins can insert flyer templates" ON flyer_templates;
DROP POLICY IF EXISTS "Admins can update flyer templates" ON flyer_templates;
DROP POLICY IF EXISTS "Admins can view all flyer templates" ON flyer_templates;

-- Approval permissions policies
DROP POLICY IF EXISTS "Master Admins can manage approval permissions" ON approval_permissions;

-- Archive policies
DROP POLICY IF EXISTS "Only admins can delete from archive" ON deleted_bundle_offers;

-- Offer bundles policies
DROP POLICY IF EXISTS "admin_all_offer_bundles" ON offer_bundles;
DROP POLICY IF EXISTS "offer_bundles_delete_policy" ON offer_bundles;
DROP POLICY IF EXISTS "offer_bundles_insert_policy" ON offer_bundles;
DROP POLICY IF EXISTS "offer_bundles_select_policy" ON offer_bundles;
DROP POLICY IF EXISTS "offer_bundles_update_policy" ON offer_bundles;

-- Offer usage logs policies
DROP POLICY IF EXISTS "admin_all_offer_usage_logs" ON offer_usage_logs;

-- Offers policies
DROP POLICY IF EXISTS "admin_all_offers" ON offers;

-- Coupon campaigns policies
DROP POLICY IF EXISTS "admins_delete_campaigns" ON coupon_campaigns;
DROP POLICY IF EXISTS "admins_insert_campaigns" ON coupon_campaigns;
DROP POLICY IF EXISTS "admins_update_campaigns" ON coupon_campaigns;
DROP POLICY IF EXISTS "admins_view_all_campaigns" ON coupon_campaigns;

-- Coupon products policies
DROP POLICY IF EXISTS "admins_delete_products" ON coupon_products;
DROP POLICY IF EXISTS "admins_insert_products" ON coupon_products;
DROP POLICY IF EXISTS "admins_update_products" ON coupon_products;
DROP POLICY IF EXISTS "admins_view_all_products" ON coupon_products;

-- Coupon eligible customers policies
DROP POLICY IF EXISTS "admins_import_customers" ON coupon_eligible_customers;

-- Orders policies
DROP POLICY IF EXISTS "admins_view_all_orders" ON orders;

-- Coupon claims policies
DROP POLICY IF EXISTS "users_view_own_claims" ON coupon_claims;

-- Delivery settings policies
DROP POLICY IF EXISTS "delivery_settings_admin_all" ON delivery_service_settings;

-- Delivery fee tiers policies
DROP POLICY IF EXISTS "delivery_tiers_admin_all" ON delivery_fee_tiers;

-- Offer cart tiers policies
DROP POLICY IF EXISTS "offer_cart_tiers_delete_policy" ON offer_cart_tiers;
DROP POLICY IF EXISTS "offer_cart_tiers_insert_policy" ON offer_cart_tiers;
DROP POLICY IF EXISTS "offer_cart_tiers_select_policy" ON offer_cart_tiers;
DROP POLICY IF EXISTS "offer_cart_tiers_update_policy" ON offer_cart_tiers;

-- ============================================================
-- STEP 5: Drop view that depends on role_type
-- ============================================================
DROP VIEW IF EXISTS user_management_view CASCADE;

-- ============================================================
-- STEP 6: Drop foreign key constraints before dropping tables
-- ============================================================
ALTER TABLE IF EXISTS role_permissions 
DROP CONSTRAINT IF EXISTS role_permissions_role_id_fkey;

ALTER TABLE IF EXISTS role_permissions 
DROP CONSTRAINT IF EXISTS role_permissions_function_id_fkey;

-- Drop position_id foreign key if it exists
ALTER TABLE IF EXISTS users 
DROP CONSTRAINT IF EXISTS fk_users_position_id;

-- ============================================================
-- STEP 7: Drop role-based tables (in order of dependencies)
-- ============================================================
DROP TABLE IF EXISTS role_permissions CASCADE;
DROP TABLE IF EXISTS app_functions CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;

-- ============================================================
-- STEP 8: Drop role_type column from users table
-- ============================================================
ALTER TABLE users 
DROP COLUMN IF EXISTS role_type;

-- ============================================================
-- STEP 9: Recreate user_management_view without role_type
-- ============================================================
CREATE OR REPLACE VIEW user_management_view AS
SELECT 
  u.id,
  u.username,
  u.quick_access_code,
  u.status,
  u.is_master_admin,
  u.is_admin,
  u.branch_id,
  u.employee_id,
  u.position_id,
  u.created_at,
  u.updated_at,
  u.failed_login_attempts,
  u.is_first_login,
  u.last_login_at,
  e.name as employee_name,
  b.name_en as branch_name,
  p.position_title_en,
  p.position_title_ar
FROM users u
LEFT JOIN hr_employees e ON u.employee_id = e.id
LEFT JOIN branches b ON u.branch_id = b.id
LEFT JOIN hr_positions p ON u.position_id = p.id;

-- ============================================================
-- STEP 7: Verify migration success
-- ============================================================
-- Check that new columns exist and data migrated correctly
-- SELECT 
--   id, 
--   username, 
--   is_master_admin, 
--   is_admin, 
--   created_at 
-- FROM users 
-- ORDER BY created_at DESC 
-- LIMIT 10;

-- ============================================================
-- STEP 8: Notes
-- ============================================================
-- Task role_type system remains intact (inventory_manager, purchase_manager, etc.)
-- These are stored in tasks table and are completely separate from user role_type
-- 
-- Approval permissions system remains intact
-- Button permissions system remains intact
-- 
-- If rollback needed: restore from backup (this migration is destructive)
