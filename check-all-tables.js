// Check all tables in Supabase database
import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
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

console.log('\n🔍 Fetching all tables from Supabase...');
console.log('='.repeat(80));

// Query information_schema to get all tables
const { data, error } = await supabase.rpc('get_database_schema');

if (error) {
  console.log('⚠️  RPC function not available, trying alternative method...\n');
  
  // Try to get tables by querying common tables we know exist
  const knownTables = [
    'users', 'employees', 'branches', 'vendors', 'receiving_records',
    'tasks', 'receiving_tasks', 'quick_tasks', 'notifications', 
    'notification_queue', 'push_subscriptions', 'task_assignments',
    'task_completions', 'task_images', 'task_reminder_logs',
    'hr_employees', 'hr_departments', 'hr_positions', 'hr_position_assignments',
    'hr_levels', 'hr_salary_components', 'hr_salary_wages',
    'hr_employee_contacts', 'hr_employee_documents', 'hr_fingerprint_transactions',
    'hr_position_reporting_template', 'vendor_payment_schedule',
    'expense_requisitions', 'expense_parent_categories', 'expense_sub_categories',
    'expense_scheduler', 'employee_warnings', 'employee_warning_history',
    'employee_fine_payments', 'notification_attachments', 'notification_recipients',
    'notification_read_states', 'receiving_task_templates', 'recurring_assignment_schedules',
    'recurring_schedule_check_log', 'requesters', 'role_permissions', 'user_roles',
    'user_sessions', 'user_device_sessions', 'user_password_history', 'user_audit_logs',
    'app_functions', 'approval_permissions', 'non_approved_payment_scheduler',
    'quick_task_assignments', 'quick_task_comments', 'quick_task_completions',
    'quick_task_files', 'quick_task_user_preferences'
  ];

  console.log('📊 Checking known tables...\n');
  
  const tableInfo = [];
  
  for (const tableName of knownTables) {
    const { count, error } = await supabase
      .from(tableName)
      .select('*', { count: 'exact', head: true });
    
    if (!error) {
      tableInfo.push({ table: tableName, count });
    }
  }
  
  // Sort by name
  tableInfo.sort((a, b) => a.table.localeCompare(b.table));
  
  console.log(`✅ Found ${tableInfo.length} tables:\n`);
  console.log('Table Name'.padEnd(40) + 'Record Count');
  console.log('-'.repeat(80));
  
  tableInfo.forEach(({ table, count }) => {
    console.log(`${table.padEnd(40)}${count.toLocaleString()}`);
  });
  
  console.log('\n' + '='.repeat(80));
  console.log(`📈 Total Tables: ${tableInfo.length}`);
  console.log(`📝 Total Records: ${tableInfo.reduce((sum, t) => sum + t.count, 0).toLocaleString()}`);
  
  // Group by category
  console.log('\n📂 Tables by Category:\n');
  
  const categories = {
    'HR Management': tableInfo.filter(t => t.table.startsWith('hr_')),
    'Task Management': tableInfo.filter(t => t.table.includes('task') && !t.table.startsWith('hr_')),
    'Notification System': tableInfo.filter(t => t.table.includes('notification')),
    'Receiving & Vendor': tableInfo.filter(t => t.table.includes('receiving') || t.table.includes('vendor')),
    'Finance & Expenses': tableInfo.filter(t => t.table.includes('expense') || t.table.includes('payment') || t.table.includes('requisition')),
    'User & Auth': tableInfo.filter(t => t.table.startsWith('user') || t.table === 'users'),
    'System & Config': tableInfo.filter(t => ['app_functions', 'approval_permissions', 'role_permissions', 'branches', 'requesters'].includes(t.table)),
    'Employee Management': tableInfo.filter(t => t.table.startsWith('employee_'))
  };
  
  for (const [category, tables] of Object.entries(categories)) {
    if (tables.length > 0) {
      console.log(`\n${category} (${tables.length} tables):`);
      tables.forEach(t => console.log(`  - ${t.table} (${t.count.toLocaleString()} records)`));
    }
  }
  
} else {
  console.log('✅ Retrieved schema from database');
  console.log(data);
}

console.log('\n✅ Check complete!\n');
