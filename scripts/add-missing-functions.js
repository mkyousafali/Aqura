// Script to add missing functions to app_functions table
// Run with: node add-missing-functions.js

const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables
const envPath = './frontend/.env';
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Define all missing functions
const newFunctions = [
  // Operations (4)
  { name: 'Receiving Management', code: 'RECEIVING_MGMT', desc: 'Manage receiving records and workflow', category: 'Operations' },
  { name: 'Vendor Management', code: 'VENDOR_MGMT', desc: 'Manage vendor information and payment schedules', category: 'Operations' },
  { name: 'Purchase Orders', code: 'PURCHASE_ORDERS', desc: 'Create and manage purchase orders', category: 'Operations' },
  { name: 'Inventory Control', code: 'INVENTORY_CTRL', desc: 'Monitor and control inventory levels', category: 'Operations' },
  
  // Finance (5)
  { name: 'Expense Management', code: 'EXPENSE_MGMT', desc: 'Track and manage company expenses', category: 'Finance' },
  { name: 'Requisitions', code: 'REQUISITION_MGMT', desc: 'Handle expense requisitions and approvals', category: 'Finance' },
  { name: 'Payment Scheduler', code: 'PAYMENT_SCHEDULER', desc: 'Schedule and track payments', category: 'Finance' },
  { name: 'Budget Tracking', code: 'BUDGET_TRACKING', desc: 'Monitor budgets and spending', category: 'Finance' },
  { name: 'Financial Reports', code: 'FINANCIAL_REPORTS', desc: 'Generate financial reports and analytics', category: 'Finance' },
  
  // Customer (4)
  { name: 'Customer Management', code: 'CUSTOMER_MGMT', desc: 'Manage customer accounts and profiles', category: 'Customer' },
  { name: 'Customer Registration', code: 'CUSTOMER_REG', desc: 'Register new customers', category: 'Customer' },
  { name: 'Customer Recovery', code: 'CUSTOMER_RECOVERY', desc: 'Handle customer account recovery requests', category: 'Customer' },
  { name: 'Customer Access Control', code: 'CUSTOMER_ACCESS', desc: 'Manage customer access codes and authentication', category: 'Customer' },
  
  // Product (5)
  { name: 'Product Management', code: 'PRODUCT_MGMT', desc: 'Manage product catalog and inventory', category: 'Product' },
  { name: 'Product Categories', code: 'PRODUCT_CATEGORIES', desc: 'Organize products into categories', category: 'Product' },
  { name: 'Product Units', code: 'PRODUCT_UNITS', desc: 'Define product measurement units', category: 'Product' },
  { name: 'Tax Categories', code: 'TAX_CATEGORIES', desc: 'Configure tax categories and rates', category: 'Product' },
  { name: 'Price Management', code: 'PRICE_MGMT', desc: 'Manage product pricing and special prices', category: 'Product' },
  
  // Offers & Promotions (6)
  { name: 'Offer Management', code: 'OFFER_MGMT', desc: 'Create and manage promotional offers', category: 'Offers & Promotions' },
  { name: 'Bundle Offers', code: 'BUNDLE_OFFERS', desc: 'Create product bundle offers', category: 'Offers & Promotions' },
  { name: 'BOGO Offers', code: 'BOGO_OFFERS', desc: 'Buy One Get One promotional offers', category: 'Offers & Promotions' },
  { name: 'Cart Tier Offers', code: 'CART_TIER_OFFERS', desc: 'Cart value-based discount tiers', category: 'Offers & Promotions' },
  { name: 'Coupon Management', code: 'COUPON_MGMT', desc: 'Manage promotional coupons', category: 'Offers & Promotions' },
  { name: 'Coupon Redemption', code: 'COUPON_REDEMPTION', desc: 'Process coupon redemptions at cashier', category: 'Offers & Promotions' },
  
  // Notifications (4)
  { name: 'Notification Center', code: 'NOTIFICATION_CENTER', desc: 'View and manage notifications', category: 'Notifications' },
  { name: 'Push Notifications', code: 'PUSH_NOTIFICATIONS', desc: 'Send push notifications to users', category: 'Notifications' },
  { name: 'Notification Queue', code: 'NOTIFICATION_QUEUE', desc: 'Manage notification queue and delivery', category: 'Notifications' },
  { name: 'Notification Templates', code: 'NOTIFICATION_TEMPLATES', desc: 'Create and manage notification templates', category: 'Notifications' },
  
  // Reports (5)
  { name: 'Sales Reports', code: 'SALES_REPORTS', desc: 'Generate sales analytics and reports', category: 'Reports' },
  { name: 'HR Reports', code: 'HR_REPORTS', desc: 'Employee and HR analytics reports', category: 'Reports' },
  { name: 'Financial Reports', code: 'FINANCIAL_REPORTS_2', desc: 'Detailed financial reports and statements', category: 'Reports' },
  { name: 'Inventory Reports', code: 'INVENTORY_REPORTS', desc: 'Stock and inventory analytics', category: 'Reports' },
  { name: 'Customer Reports', code: 'CUSTOMER_REPORTS', desc: 'Customer behavior and analytics', category: 'Reports' },
  
  // System (4)
  { name: 'Audit Logs', code: 'AUDIT_LOGS', desc: 'View system audit logs and activity', category: 'System' },
  { name: 'Session Management', code: 'SESSION_MGMT', desc: 'Manage user sessions and devices', category: 'System' },
  { name: 'Device Management', code: 'DEVICE_MGMT', desc: 'Manage user devices and access', category: 'System' },
  { name: 'Backup & Restore', code: 'BACKUP_RESTORE', desc: 'Backup and restore system data', category: 'System' }
];

async function addMissingFunctions() {
  console.log('🚀 Starting to add missing functions to app_functions table...\n');
  
  let successCount = 0;
  let skipCount = 0;
  let errorCount = 0;
  
  for (const func of newFunctions) {
    try {
      // Check if function already exists
      const { data: existing } = await supabase
        .from('app_functions')
        .select('id, function_code')
        .eq('function_code', func.code)
        .single();
      
      if (existing) {
        console.log(`⏭️  Skipped: ${func.name} (${func.code}) - Already exists`);
        skipCount++;
        continue;
      }
      
      // Insert new function
      const { data, error } = await supabase
        .from('app_functions')
        .insert({
          function_name: func.name,
          function_code: func.code,
          description: func.desc,
          category: func.category,
          is_active: true
        })
        .select()
        .single();
      
      if (error) {
        console.error(`❌ Error adding ${func.name}:`, error.message);
        errorCount++;
      } else {
        console.log(`✅ Added: ${func.name} (${func.code})`);
        successCount++;
      }
      
    } catch (err) {
      console.error(`❌ Exception adding ${func.name}:`, err.message);
      errorCount++;
    }
  }
  
  console.log('\n📊 Summary:');
  console.log(`   ✅ Successfully added: ${successCount}`);
  console.log(`   ⏭️  Skipped (existing): ${skipCount}`);
  console.log(`   ❌ Errors: ${errorCount}`);
  console.log(`   📝 Total processed: ${newFunctions.length}`);
  
  // Now add default permissions for Master Admin and Admin
  if (successCount > 0) {
    console.log('\n🔐 Adding default role permissions...');
    await addDefaultPermissions();
  }
}

async function addDefaultPermissions() {
  try {
    // Get Master Admin and Admin role IDs
    const { data: roles } = await supabase
      .from('user_roles')
      .select('id, role_code, role_name')
      .in('role_code', ['MASTER_ADMIN', 'ADMIN']);
    
    if (!roles || roles.length === 0) {
      console.log('⚠️  Warning: Master Admin or Admin roles not found');
      return;
    }
    
    // Get all newly added functions
    const functionCodes = newFunctions.map(f => f.code);
    const { data: functions } = await supabase
      .from('app_functions')
      .select('id, function_code')
      .in('function_code', functionCodes);
    
    let permissionCount = 0;
    
    for (const role of roles) {
      for (const func of functions) {
        // Check if permission already exists
        const { data: existing } = await supabase
          .from('role_permissions')
          .select('id')
          .eq('role_id', role.id)
          .eq('function_id', func.id)
          .single();
        
        if (existing) {
          continue; // Skip if already exists
        }
        
        // Master Admin gets full access, Admin gets limited access
        const isMasterAdmin = role.role_code === 'MASTER_ADMIN';
        
        const { error } = await supabase
          .from('role_permissions')
          .insert({
            role_id: role.id,
            function_id: func.id,
            can_view: true,
            can_add: isMasterAdmin || true,
            can_edit: isMasterAdmin || true,
            can_delete: isMasterAdmin, // Only Master Admin can delete
            can_export: true
          });
        
        if (!error) {
          permissionCount++;
        }
      }
    }
    
    console.log(`✅ Added ${permissionCount} default role permissions`);
    
  } catch (err) {
    console.error('❌ Error adding default permissions:', err.message);
  }
}

// Run the script
addMissingFunctions()
  .then(() => {
    console.log('\n✨ Script completed successfully!');
    process.exit(0);
  })
  .catch(err => {
    console.error('\n💥 Script failed:', err);
    process.exit(1);
  });
