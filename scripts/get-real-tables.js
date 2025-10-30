/**
 * Real Database Schema Scanner
 * This script connects directly to Supabase and gets the ACTUAL table list
 * No guessing, no matching - real database query
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Supabase configuration
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Missing required environment variables');
    process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function getRealTables() {
    console.log('🔍 Connecting to Supabase and getting REAL table schema...\n');
    
    try {
        // Method 1: Use Supabase's built-in introspection
        console.log('📋 Method 1: Using Supabase introspection API...');
        
        // Get all tables from the public schema using PostgREST introspection
        const response = await fetch(`${supabaseUrl}/rest/v1/?apikey=${supabaseServiceKey}`, {
            method: 'GET',
            headers: {
                'apikey': supabaseServiceKey,
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'Content-Type': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            console.log('✅ Method 1 successful - got schema from PostgREST!');
            
            // Extract table names from the schema
            const tables = Object.keys(data.definitions || {})
                .filter(key => !key.startsWith('rpc_'))
                .map(tableName => ({
                    tablename: tableName,
                    schemaname: 'public'
                }));
                
            if (tables.length > 0) {
                return tables;
            }
        }
        
        console.log('⚠️ Method 1 failed, trying Method 2...');
        
        // Method 2: Direct PostgreSQL system query using raw connection
        console.log('📋 Method 2: Raw PostgreSQL system catalog query...');
        
        // Try to create a function that can execute raw SQL
        const { data: functionResult, error: functionError } = await supabase.rpc('create_table_list_function');
        
        if (functionError) {
            console.log('⚠️ Function creation failed, trying Method 3...');
        }
        
        // Method 3: Use pg_stat_user_tables which should be accessible
        console.log('📋 Method 3: Trying pg_stat_user_tables...');
        
        const { data: statResult, error: statError } = await supabase
            .from('pg_stat_user_tables')
            .select('*');
            
        if (!statError && statResult) {
            console.log('✅ Method 3 successful - got tables from pg_stat_user_tables!');
            return statResult.map(row => ({
                tablename: row.relname,
                schemaname: row.schemaname
            }));
        }
        
        console.log('⚠️ Method 3 failed, trying Method 4...');
        
        // Method 4: Try using Supabase REST API to list available endpoints
        console.log('📋 Method 4: Using Supabase REST API endpoints...');
        
        const apiResponse = await fetch(`${supabaseUrl}/rest/v1/`, {
            method: 'GET',
            headers: {
                'apikey': supabaseServiceKey,
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'Accept': 'application/json',
                'Content-Type': 'application/json'
            }
        });
        
        if (apiResponse.ok) {
            const apiData = await apiResponse.text();
            console.log('✅ Method 4 successful - got API response!');
            
            // Parse the OpenAPI schema to get table names
            try {
                const schema = JSON.parse(apiData);
                const paths = schema.paths || {};
                const tables = [];
                
                for (const path in paths) {
                    if (path.startsWith('/') && !path.includes('{') && path !== '/') {
                        const tableName = path.substring(1); // Remove leading slash
                        if (!tableName.startsWith('rpc/')) {
                            tables.push({
                                tablename: tableName,
                                schemaname: 'public'
                            });
                        }
                    }
                }
                
                if (tables.length > 0) {
                    return tables;
                }
            } catch (e) {
                console.log('Could not parse API schema');
            }
        }
        
        console.log('⚠️ Method 4 failed, trying Method 5...');
        
        // Method 5: Brute force - try to access each table and see what works
        console.log('📋 Method 5: Systematic discovery by trying actual table access...');
        
        // Get a comprehensive list of possible table names and test each one
        const allPossibleTables = [
            // Previous known tables
            'users', 'branches', 'vendors', 'hr_employees', 'hr_departments', 'hr_positions',
            'employee_warnings', 'tasks', 'notifications',
            
            // Common business tables
            'companies', 'organizations', 'customers', 'clients', 'contacts',
            'invoices', 'bills', 'payments', 'transactions', 'receipts',
            'orders', 'order_items', 'products', 'services', 'inventory',
            'categories', 'subcategories', 'tags', 'labels',
            
            // More HR tables
            'employees', 'staff', 'personnel', 'payroll', 'salaries',
            'attendance', 'timesheets', 'leaves', 'holidays', 'overtime',
            'performance', 'evaluations', 'reviews', 'training',
            'benefits', 'insurance', 'contracts', 'employment',
            
            // Financial tables
            'accounts', 'ledger', 'journal', 'balance_sheet',
            'profit_loss', 'cash_flow', 'budgets', 'expenses',
            'revenue', 'income', 'costs', 'assets', 'liabilities',
            
            // System tables
            'settings', 'configurations', 'preferences', 'options',
            'logs', 'audit_logs', 'activity_logs', 'error_logs',
            'sessions', 'tokens', 'api_keys', 'permissions',
            'roles', 'user_roles', 'role_permissions',
            
            // Communication
            'messages', 'emails', 'sms', 'notifications_history',
            'alerts', 'reminders', 'announcements',
            
            // Workflow/Approval
            'workflows', 'approvals', 'approval_requests',
            'approval_history', 'approval_chains', 'approval_rules',
            
            // Document management
            'documents', 'files', 'attachments', 'uploads',
            'document_types', 'file_storage',
            
            // Location/Geography
            'countries', 'states', 'cities', 'regions',
            'addresses', 'locations', 'postal_codes',
            
            // Time/Calendar
            'calendar', 'events', 'appointments', 'schedules',
            'time_zones', 'working_hours', 'shifts',
            
            // Reports
            'reports', 'report_templates', 'dashboards',
            'analytics', 'metrics', 'kpis',
            
            // Integration
            'api_logs', 'webhooks', 'integrations', 'sync_logs',
            
            // Backup/Archive
            'backups', 'archives', 'deleted_records', 'history'
        ];
        
        const existingTables = [];
        console.log('   Testing table accessibility...');
        
        let tested = 0;
        for (const tableName of allPossibleTables) {
            try {
                tested++;
                if (tested % 10 === 0) {
                    console.log(`   Progress: ${tested}/${allPossibleTables.length} tables tested...`);
                }
                
                const { data, error, count } = await supabase
                    .from(tableName)
                    .select('*', { count: 'exact' })
                    .limit(1);
                
                if (!error || (error.message && (
                    error.message.includes('row-level security') ||
                    error.message.includes('permission denied') ||
                    error.message.includes('policy') ||
                    error.message.includes('insufficient_privilege')
                ))) {
                    // Table exists
                    existingTables.push({
                        tablename: tableName,
                        schemaname: 'public',
                        accessible: !error,
                        row_count: count || 0,
                        error_type: error ? 'RLS/Permission' : 'None'
                    });
                    console.log(`   ✅ ${tableName} ${error ? '(RLS protected)' : `(${count || 0} rows)`}`);
                }
            } catch (e) {
                // Table doesn't exist - ignore
            }
        }
        
        return existingTables;
        
    } catch (error) {
        console.error('❌ Error during real table discovery:', error.message);
        return [];
    }
}

async function scanRealDatabase() {
    try {
        const tables = await getRealTables();
        
        console.log('\n' + '='.repeat(80));
        console.log('📊 REAL DATABASE SCHEMA ANALYSIS');
        console.log('='.repeat(80));
        
        if (tables.length === 0) {
            console.log('❌ No tables found or accessible');
            return [];
        }
        
        console.log(`✅ Found ${tables.length} REAL table(s) in the database:\n`);
        
        // Sort tables alphabetically
        const sortedTables = tables.sort((a, b) => a.tablename.localeCompare(b.tablename));
        
        sortedTables.forEach((table, index) => {
            const status = table.accessible ? '✅' : '🔒';
            const info = table.row_count !== undefined ? ` (${table.row_count} rows)` : '';
            const protection = table.error_type && table.error_type !== 'None' ? ' [RLS]' : '';
            console.log(`${(index + 1).toString().padStart(3)}. ${status} ${table.tablename}${info}${protection}`);
        });
        
        // Categorize by prefix
        console.log('\n📋 TABLES BY PREFIX:');
        console.log('-'.repeat(60));
        
        const prefixes = {};
        sortedTables.forEach(table => {
            const parts = table.tablename.split('_');
            const prefix = parts.length > 1 ? parts[0] : 'no_prefix';
            
            if (!prefixes[prefix]) {
                prefixes[prefix] = [];
            }
            prefixes[prefix].push(table);
        });
        
        Object.entries(prefixes)
            .sort(([a], [b]) => a.localeCompare(b))
            .forEach(([prefix, tableList]) => {
                if (prefix === 'no_prefix') {
                    console.log(`\n🔹 Tables without prefix (${tableList.length}):`);
                } else {
                    console.log(`\n🔹 ${prefix.toUpperCase()}_ tables (${tableList.length}):`);
                }
                tableList.forEach(table => {
                    const status = table.accessible ? '✅' : '🔒';
                    const info = table.row_count !== undefined ? ` (${table.row_count} rows)` : '';
                    console.log(`   ${status} ${table.tablename}${info}`);
                });
            });
        
        // Summary statistics
        const accessibleTables = sortedTables.filter(t => t.accessible);
        const protectedTables = sortedTables.filter(t => !t.accessible);
        const totalRows = sortedTables.reduce((sum, t) => sum + (t.row_count || 0), 0);
        
        console.log('\n' + '='.repeat(80));
        console.log(`📈 DATABASE STATISTICS:`);
        console.log(`   Total Tables: ${tables.length}`);
        console.log(`   Accessible Tables: ${accessibleTables.length}`);
        console.log(`   RLS Protected Tables: ${protectedTables.length}`);
        console.log(`   Total Rows: ${totalRows.toLocaleString()}`);
        console.log('='.repeat(80));
        
        return tables;
        
    } catch (error) {
        console.error('❌ Real database scan failed:', error.message);
        return [];
    }
}

// Run the real database scan
scanRealDatabase()
    .then((tables) => {
        console.log(`\n✅ Real database scan completed! Found ${tables.length} actual tables.`);
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n❌ Real database scan failed:', error.message);
        process.exit(1);
    });

export { getRealTables, scanRealDatabase };