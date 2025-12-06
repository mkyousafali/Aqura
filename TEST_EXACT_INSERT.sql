-- ============================================================================
-- FINAL DIAGNOSTIC: Test INSERT directly in database
-- ============================================================================

-- Insert a test record with the EXACT same data
INSERT INTO receiving_records (
  user_id,
  branch_id,
  vendor_id,
  bill_date,
  bill_amount,
  bill_number,
  payment_method,
  due_date,
  bank_name,
  iban,
  vendor_vat_number,
  bill_vat_number,
  vat_numbers_match,
  vat_mismatch_reason,
  branch_manager_user_id,
  accountant_user_id,
  purchasing_manager_user_id,
  shelf_stocker_user_ids,
  inventory_manager_user_id,
  night_supervisor_user_ids,
  warehouse_handler_user_ids,
  expired_return_amount,
  near_expiry_return_amount,
  over_stock_return_amount,
  damage_return_amount,
  has_expired_returns,
  has_near_expiry_returns,
  has_over_stock_returns,
  has_damage_returns
) VALUES (
  'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f'::uuid,
  1,
  1617,
  '2025-12-07'::date,
  100,
  '5454',
  'Cash on Delivery',
  '2025-12-06'::date,
  'N/A',
  'N/A',
  '310256664545',
  '5454',
  false,
  'df',
  '069ec45a-899b-4973-b930-bb34e1f7db93'::uuid,
  'bc3d6349-8237-407a-aeef-96dab9d51adf'::uuid,
  '807af948-0f5f-4f36-8925-747b152513c1'::uuid,
  ARRAY['4b8c78cc-f0ea-4337-b677-3ef45d718fdf'::uuid],
  '1c5ed1c1-65db-42a9-b530-d2ca29d7fb30'::uuid,
  ARRAY['93a5e7f7-7cde-4e72-a249-d1a03ebc9346'::uuid],
  ARRAY['90c7c901-3474-4fee-bca3-ac859964dfeb'::uuid],
  0,
  0,
  0,
  0,
  false,
  false,
  false,
  false
);

-- ============================================================================
-- If this INSERT works in SQL but fails in REST API:
-- -> Problem is Supabase Postgrest API configuration
-- -> NOT the RLS policy
-- ============================================================================

SELECT COUNT(*) as total_receiving_records FROM receiving_records;
