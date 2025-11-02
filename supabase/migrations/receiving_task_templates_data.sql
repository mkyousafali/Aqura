-- =====================================================
-- POPULATE RECEIVING TASK TEMPLATES
-- =====================================================
-- Insert 7 task templates, one for each role type
-- These templates are used to generate actual receiving tasks
-- =====================================================

INSERT INTO public.receiving_task_templates (
  id,
  role_type,
  title_template,
  description_template,
  require_erp_reference,
  require_original_bill_upload,
  require_task_finished_mark,
  priority,
  deadline_hours
) VALUES

-- =====================================================
-- 1. BRANCH MANAGER
-- =====================================================
(
  gen_random_uuid(),
  'branch_manager',
  'New Delivery Arrived – Start Placing',
  '🧾 Task for Branch Manager

Manage the delivery placement process for this receiving record.

Branch: {branch_name}
Vendor: {vendor_name} (ID: {vendor_id})
Bill Amount: {bill_amount}
Bill Number: {bill_number}
Received Date: {bill_date}
Received By: {received_by}
Deadline: {deadline} (24 hours from assignment)

Ensure all received products are verified, placed correctly, and shelves are updated accordingly.
Once the placement is completed, confirm task completion in the system.

Clearance Certificate: {certificate_url}',
  false,
  false,
  true,
  'high',
  24
),

-- =====================================================
-- 2. PURCHASE MANAGER
-- =====================================================
(
  gen_random_uuid(),
  'purchase_manager',
  'New Delivery Arrived – Price Check',
  '🧾 Task for Purchase Manager

Review pricing and verify purchase order details for this receiving record.

Branch: {branch_name}
Vendor: {vendor_name} (ID: {vendor_id})
Bill Amount: {bill_amount}
Bill Number: {bill_number}
Received Date: {bill_date}
Received By: {received_by}
Deadline: {deadline} (72 hours from assignment)

Tasks Required:
1. Verify bill amounts match purchase order
2. Check pricing accuracy against contracts
3. Validate product specifications
4. Confirm task completion in system

Clearance Certificate: {certificate_url}',
  false,
  false,
  true,
  'high',
  72
),

-- =====================================================
-- 3. INVENTORY MANAGER
-- =====================================================
(
  gen_random_uuid(),
  'inventory_manager',
  'New Delivery Arrived – Confirm Product is Placed',
  '🧾 Task for Inventory Manager

Verify inventory placement and stock levels for this receiving record.

Branch: {branch_name}
Vendor: {vendor_name} (ID: {vendor_id})
Bill Amount: {bill_amount}
Bill Number: {bill_number}
Received Date: {bill_date}
Received By: {received_by}
Deadline: {deadline} (24 hours from assignment)

Tasks Required:
1. Confirm all products are correctly placed
2. Update inventory system with new stock
3. Verify quantities against delivery note
4. Mark task as completed in system

Clearance Certificate: {certificate_url}',
  false,
  false,
  true,
  'high',
  24
),

-- =====================================================
-- 4. NIGHT SUPERVISOR
-- =====================================================
(
  gen_random_uuid(),
  'night_supervisor',
  'New Delivery Arrived – Night Shift Verification',
  '🧾 Task for Night Supervisor

Conduct night shift verification for this receiving record.

Branch: {branch_name}
Vendor: {vendor_name} (ID: {vendor_id})
Bill Amount: {bill_amount}
Bill Number: {bill_number}
Received Date: {bill_date}
Received By: {received_by}
Deadline: {deadline} (24 hours from assignment)

Tasks Required:
1. Verify overnight storage conditions
2. Check for any discrepancies
3. Ensure security of received goods
4. Confirm task completion in system

Clearance Certificate: {certificate_url}',
  false,
  false,
  true,
  'high',
  24
),

-- =====================================================
-- 5. WAREHOUSE HANDLER
-- =====================================================
(
  gen_random_uuid(),
  'warehouse_handler',
  'New Delivery Arrived – Handle Warehouse Storage',
  '🧾 Task for Warehouse Handler

Manage warehouse storage for this receiving record.

Branch: {branch_name}
Vendor: {vendor_name} (ID: {vendor_id})
Bill Amount: {bill_amount}
Bill Number: {bill_number}
Received Date: {bill_date}
Received By: {received_by}
Deadline: {deadline} (24 hours from assignment)

Tasks Required:
1. Move products to designated warehouse areas
2. Organize storage locations
3. Update warehouse management system
4. Confirm task completion in system

Clearance Certificate: {certificate_url}',
  false,
  false,
  true,
  'high',
  24
),

-- =====================================================
-- 6. SHELF STOCKER
-- =====================================================
(
  gen_random_uuid(),
  'shelf_stocker',
  'New Delivery Arrived – Stock Shelves',
  '🧾 Task for Shelf Stocker

Stock shelves with newly received products for this receiving record.

Branch: {branch_name}
Vendor: {vendor_name} (ID: {vendor_id})
Bill Amount: {bill_amount}
Bill Number: {bill_number}
Received Date: {bill_date}
Received By: {received_by}
Deadline: {deadline} (24 hours from assignment)

Tasks Required:
1. Place products on appropriate shelves
2. Ensure proper product rotation (FIFO)
3. Update shelf tags and pricing
4. Confirm task completion in system

Clearance Certificate: {certificate_url}',
  false,
  false,
  true,
  'high',
  24
),

-- =====================================================
-- 7. ACCOUNTANT
-- =====================================================
(
  gen_random_uuid(),
  'accountant',
  'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill',
  '🧾 Task for Accountant

Process payment and documentation for this receiving record.

Branch: {branch_name}
Vendor: {vendor_name} (ID: {vendor_id})
Bill Amount: {bill_amount}
Bill Number: {bill_number}
Received Date: {bill_date}
Received By: {received_by}
Deadline: {deadline} (24 hours from assignment)

Tasks Required:
1. Enter payment details into Purchase ERP system
2. Upload original bill document
3. Update ERP reference number
4. Confirm task completion in system

Clearance Certificate: {certificate_url}',
  true,
  true,
  true,
  'high',
  24
);

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Verify all 7 templates were inserted
DO $$
DECLARE
  template_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO template_count FROM public.receiving_task_templates;
  
  IF template_count = 7 THEN
    RAISE NOTICE '✅ Successfully inserted 7 receiving task templates';
  ELSE
    RAISE EXCEPTION '❌ Expected 7 templates, found %', template_count;
  END IF;
END $$;
