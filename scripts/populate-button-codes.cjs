const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);

// Button data structure
const buttonData = {
  DELIVERY: {
    DASHBOARD: [],
    MANAGE: [
      { code: 'CUSTOMER_MASTER', name: 'Customer Master' },
      { code: 'AD_MANAGER', name: 'Ad Manager' },
      { code: 'PRODUCTS_MANAGER', name: 'Products Manager' },
      { code: 'DELIVERY_SETTINGS', name: 'Delivery Settings' }
    ],
    OPERATIONS: [
      { code: 'ORDERS_MANAGER', name: 'Orders Manager' },
      { code: 'OFFER_MANAGEMENT', name: 'Offer Management' }
    ],
    REPORTS: []
  },
  VENDOR: {
    DASHBOARD: [
      { code: 'RECEIVING', name: 'Receiving' }
    ],
    MANAGE: [
      { code: 'UPLOAD_VENDOR', name: 'Upload Vendor' },
      { code: 'CREATE_VENDOR', name: 'Create Vendor' },
      { code: 'MANAGE_VENDOR', name: 'Manage Vendor' }
    ],
    OPERATIONS: [
      { code: 'START_RECEIVING', name: 'Start Receiving' },
      { code: 'RECEIVING_RECORDS', name: 'Receiving Records' }
    ],
    REPORTS: [
      { code: 'VENDOR_RECORDS', name: 'Vendor Records' }
    ]
  },
  MEDIA: {
    DASHBOARD: [],
    MANAGE: [
      { code: 'PRODUCT_MASTER', name: 'Product Master' },
      { code: 'VARIATION_MANAGER', name: 'Variation Manager' },
      { code: 'OFFER_MANAGER', name: 'Offer Manager' },
      { code: 'FLYER_TEMPLATES', name: 'Flyer Templates' },
      { code: 'SETTINGS', name: 'Settings' }
    ],
    OPERATIONS: [
      { code: 'OFFER_PRODUCT_EDITOR', name: 'Offer Product Editor' },
      { code: 'CREATE_NEW_OFFER', name: 'Create New Offer' },
      { code: 'PRICING_MANAGER', name: 'Pricing Manager' },
      { code: 'GENERATE_FLYERS', name: 'Generate Flyers' },
      { code: 'SHELF_PAPER_MANAGER', name: 'Shelf Paper Manager' }
    ],
    REPORTS: []
  },
  PROMO: {
    DASHBOARD: [
      { code: 'COUPON_DASHBOARD', name: 'Coupon Dashboard' }
    ],
    MANAGE: [
      { code: 'MANAGE_CAMPAIGNS', name: 'Manage Campaigns' }
    ],
    OPERATIONS: [
      { code: 'IMPORT_CUSTOMERS', name: 'Import Customers' },
      { code: 'MANAGE_PRODUCTS', name: 'Manage Products' }
    ],
    REPORTS: [
      { code: 'REPORTS_STATS', name: 'Reports & Stats' }
    ]
  },
  FINANCE: {
    DASHBOARD: [],
    MANAGE: [],
    OPERATIONS: [
      { code: 'MANUAL_SCHEDULING', name: 'Manual Scheduling' },
      { code: 'DAY_BUDGET_PLANNER', name: 'Day Budget Planner' },
      { code: 'MONTHLY_MANAGER', name: 'Monthly Manager' },
      { code: 'EXPENSE_MANAGER', name: 'Expense Manager' },
      { code: 'PAID_MANAGER', name: 'Paid Manager' }
    ],
    REPORTS: [
      { code: 'EXPENSE_TRACKER', name: 'Expense Tracker' },
      { code: 'SALES_REPORT', name: 'Sales Report' },
      { code: 'MONTHLY_BREAKDOWN', name: 'Monthly Breakdown' },
      { code: 'OVER_DUES', name: 'Over dues' },
      { code: 'VENDOR_PAYMENTS', name: 'Vendor Payments' }
    ]
  },
  HR: {
    DASHBOARD: [],
    MANAGE: [
      { code: 'UPLOAD_EMPLOYEES', name: 'Upload Employees' },
      { code: 'CREATE_DEPARTMENT', name: 'Create Department' },
      { code: 'CREATE_LEVEL', name: 'Create Level' },
      { code: 'CREATE_POSITION', name: 'Create Position' },
      { code: 'REPORTING_MAP', name: 'Reporting Map' },
      { code: 'ASSIGN_POSITIONS', name: 'Assign Positions' },
      { code: 'CONTACT_MANAGEMENT', name: 'Contact Management' },
      { code: 'DOCUMENT_MANAGEMENT', name: 'Document Management' }
    ],
    OPERATIONS: [
      { code: 'EMPLOYEE_ACTIONS', name: 'Employee Actions' },
      { code: 'BULK_OPERATIONS', name: 'Bulk Operations' }
    ],
    REPORTS: [
      { code: 'EMPLOYEE_REPORT', name: 'Employee Report' },
      { code: 'DEPARTMENT_REPORT', name: 'Department Report' },
      { code: 'ATTENDANCE_REPORT', name: 'Attendance Report' }
    ]
  },
  TASKS: {
    DASHBOARD: [
      { code: 'TASK_DASHBOARD', name: 'Task Dashboard' }
    ],
    MANAGE: [
      { code: 'CREATE_TASK', name: 'Create Task' },
      { code: 'TASK_TEMPLATES', name: 'Task Templates' },
      { code: 'TASK_CATEGORIES', name: 'Task Categories' },
      { code: 'TASK_PRIORITY', name: 'Task Priority' }
    ],
    OPERATIONS: [
      { code: 'ASSIGN_TASKS', name: 'Assign Tasks' },
      { code: 'TRACK_TASKS', name: 'Track Tasks' },
      { code: 'BULK_TASKS', name: 'Bulk Tasks' }
    ],
    REPORTS: [
      { code: 'TASK_COMPLETION_REPORT', name: 'Task Completion Report' },
      { code: 'TASK_PERFORMANCE', name: 'Task Performance' },
      { code: 'OVERDUE_TASKS', name: 'Overdue Tasks' }
    ]
  },
  NOTIFICATIONS: {
    DASHBOARD: [
      { code: 'NOTIFICATION_CENTER', name: 'Notification Center' }
    ],
    MANAGE: [
      { code: 'NOTIFICATION_TEMPLATES', name: 'Notification Templates' },
      { code: 'NOTIFICATION_RULES', name: 'Notification Rules' }
    ],
    OPERATIONS: [
      { code: 'SEND_NOTIFICATIONS', name: 'Send Notifications' },
      { code: 'SCHEDULE_NOTIFICATIONS', name: 'Schedule Notifications' }
    ],
    REPORTS: [
      { code: 'NOTIFICATION_LOGS', name: 'Notification Logs' },
      { code: 'DELIVERY_REPORT', name: 'Delivery Report' }
    ]
  },
  USER: {
    DASHBOARD: [],
    MANAGE: [
      { code: 'USER_MANAGEMENT', name: 'User Management' },
      { code: 'ROLE_MANAGEMENT', name: 'Role Management' },
      { code: 'PERMISSION_MANAGEMENT', name: 'Permission Management' }
    ],
    OPERATIONS: [
      { code: 'CREATE_USER', name: 'Create User' },
      { code: 'ASSIGN_ROLES', name: 'Assign Roles' },
      { code: 'BULK_USER_IMPORT', name: 'Bulk User Import' }
    ],
    REPORTS: [
      { code: 'USER_ACTIVITY_REPORT', name: 'User Activity Report' },
      { code: 'LOGIN_REPORT', name: 'Login Report' },
      { code: 'AUDIT_LOG', name: 'Audit Log' }
    ]
  },
  CONTROLS: {
    DASHBOARD: [],
    MANAGE: [
      { code: 'SYSTEM_SETTINGS', name: 'System Settings' },
      { code: 'BACKUP_SETTINGS', name: 'Backup Settings' },
      { code: 'MAINTENANCE', name: 'Maintenance' }
    ],
    OPERATIONS: [
      { code: 'DATA_CLEANUP', name: 'Data Cleanup' },
      { code: 'CACHE_MANAGEMENT', name: 'Cache Management' },
      { code: 'ERROR_LOGS', name: 'Error Logs' }
    ],
    REPORTS: [
      { code: 'SYSTEM_HEALTH', name: 'System Health' },
      { code: 'PERFORMANCE_REPORT', name: 'Performance Report' }
    ]
  }
};

async function updateButtons() {
  try {
    // Get all existing buttons with IDs
    const { data: existingButtons } = await supabase
      .from('sidebar_buttons')
      .select('id')
      .order('id');

    console.log(`Found ${existingButtons?.length || 0} existing button records\n`);

    if (!existingButtons || existingButtons.length === 0) {
      console.log('No buttons found to update');
      return;
    }

    // Flatten our button data into array
    const buttonsList = [];
    Object.entries(buttonData).forEach(([section, subsections]) => {
      Object.entries(subsections).forEach(([subsection, buttons]) => {
        buttons.forEach(btn => {
          buttonsList.push({
            section,
            subsection,
            ...btn
          });
        });
      });
    });

    console.log(`Total buttons to populate: ${buttonsList.length}\n`);

    // Update each existing button record with data
    let updated = 0;
    for (let i = 0; i < existingButtons.length && i < buttonsList.length; i++) {
      const btn = buttonsList[i];
      const { error } = await supabase
        .from('sidebar_buttons')
        .update({
          code: btn.code,
          name: btn.name,
          section: btn.section,
          subsection: btn.subsection
        })
        .eq('id', existingButtons[i].id);

      if (!error) {
        updated++;
        if ((updated) % 10 === 0) {
          console.log(`Updated ${updated} buttons...`);
        }
      } else {
        console.error(`Error updating button ${existingButtons[i].id}:`, error);
      }
    }

    console.log(`\n✓ Successfully updated ${updated} buttons`);

    // Verify the update
    const { data: verifyButtons } = await supabase
      .from('sidebar_buttons')
      .select('*')
      .limit(5);

    console.log('\nVerification - First 5 updated buttons:');
    verifyButtons?.forEach(b => {
      console.log(`  ID: ${b.id}, Code: ${b.code}, Name: ${b.name}`);
    });

  } catch (err) {
    console.error('Error:', err);
  }
}

updateButtons();
