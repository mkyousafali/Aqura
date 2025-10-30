/**
 * Complete Database Tables Scanner
 * This script queries the actual Supabase database to find ALL existing tables
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

async function getAllActualTables() {
    console.log('🚀 Scanning ALL actual tables in Supabase database...\n');
    
    try {
        // Method 1: Query pg_tables directly using raw SQL
        console.log('📋 Method 1: Querying pg_tables system catalog...');
        
        const { data: pgTablesResult, error: pgTablesError } = await supabase.rpc('exec_sql', {
            query: `
                SELECT 
                    schemaname,
                    tablename,
                    tableowner,
                    hasindexes,
                    hasrules,
                    hastriggers
                FROM pg_tables 
                WHERE schemaname = 'public'
                ORDER BY tablename;
            `
        });
        
        if (!pgTablesError && pgTablesResult) {
            console.log('✅ Method 1 successful - found tables via pg_tables!');
            return pgTablesResult;
        }
        
        console.log(`⚠️ Method 1 failed: ${pgTablesError?.message || 'Unknown error'}`);
        console.log('📋 Method 2: Querying information_schema...');
        
        // Method 2: Use information_schema.tables
        const { data: schemaResult, error: schemaError } = await supabase.rpc('exec_sql', {
            query: `
                SELECT 
                    table_schema as schemaname,
                    table_name as tablename,
                    table_type
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                AND table_type = 'BASE TABLE'
                ORDER BY table_name;
            `
        });
        
        if (!schemaError && schemaResult) {
            console.log('✅ Method 2 successful - found tables via information_schema!');
            return schemaResult;
        }
        
        console.log(`⚠️ Method 2 failed: ${schemaError?.message || 'Unknown error'}`);
        console.log('📋 Method 3: Alternative SQL approach...');
        
        // Method 3: Different SQL approach
        const { data: altResult, error: altError } = await supabase.rpc('exec_sql', {
            query: `
                SELECT 
                    n.nspname as schemaname,
                    c.relname as tablename
                FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relkind = 'r'
                AND n.nspname = 'public'
                ORDER BY c.relname;
            `
        });
        
        if (!altError && altResult) {
            console.log('✅ Method 3 successful - found tables via pg_class!');
            return altResult;
        }
        
        console.log(`⚠️ Method 3 failed: ${altError?.message || 'Unknown error'}`);
        console.log('📋 Method 4: Direct table probing...');
        
        // Method 4: Try common table names and see what exists
        const commonTables = [
            // HR tables
            'hr_employees', 'hr_departments', 'hr_positions', 'hr_attendance', 'hr_payroll',
            'hr_leaves', 'hr_evaluations', 'hr_benefits', 'hr_training', 'hr_contracts',
            
            // User/Auth tables
            'users', 'profiles', 'auth_users', 'user_profiles', 'accounts',
            
            // Business tables
            'vendors', 'customers', 'branches', 'locations', 'companies',
            'invoices', 'payments', 'orders', 'products', 'services',
            
            // Warning/Task tables
            'employee_warnings', 'warnings', 'tasks', 'assignments', 'notifications',
            
            // Finance tables
            'transactions', 'accounts_payable', 'accounts_receivable', 'expenses',
            'budgets', 'financial_records', 'bills', 'receipts',
            
            // System tables
            'settings', 'configurations', 'logs', 'audit_trail', 'sessions',
            
            // Communication tables
            'messages', 'emails', 'sms', 'push_notifications',
            
            // Approval/Workflow tables
            'approvals', 'workflows', 'approval_requests', 'approval_history'
        ];
        
        const existingTables = [];
        console.log('   Probing for existing tables...');
        
        for (const tableName of commonTables) {
            try {
                const { data, error } = await supabase
                    .from(tableName)
                    .select('*')
                    .limit(1);
                
                if (!error || (error.message && (
                    error.message.includes('row-level security') ||
                    error.message.includes('permission denied') ||
                    error.message.includes('policy')
                ))) {
                    // Table exists (might have RLS preventing access, but table exists)
                    existingTables.push({
                        tablename: tableName,
                        schemaname: 'public'
                    });
                    console.log(`   ✅ ${tableName}`);
                }
            } catch (e) {
                // Ignore - table doesn't exist
            }
        }
        
        return existingTables;
        
    } catch (error) {
        console.error('❌ Error during database scan:', error.message);
        return [];
    }
}

async function scanDatabase() {
    try {
        const tables = await getAllActualTables();
        
        console.log('\n' + '='.repeat(70));
        console.log('📊 COMPLETE DATABASE TABLES ANALYSIS');
        console.log('='.repeat(70));
        
        if (tables.length === 0) {
            console.log('❌ No tables found in the public schema');
            return [];
        }
        
        console.log(`✅ Found ${tables.length} table(s) in the public schema:\n`);
        
        // Sort tables alphabetically
        const sortedTables = tables.sort((a, b) => a.tablename.localeCompare(b.tablename));
        
        sortedTables.forEach((table, index) => {
            console.log(`${(index + 1).toString().padStart(3)}. ${table.tablename}`);
        });
        
        // Categorize tables by prefix
        console.log('\n📋 TABLES BY PREFIX:');
        console.log('-'.repeat(50));
        
        const prefixes = {};
        sortedTables.forEach(table => {
            const parts = table.tablename.split('_');
            const prefix = parts.length > 1 ? parts[0] : 'no_prefix';
            
            if (!prefixes[prefix]) {
                prefixes[prefix] = [];
            }
            prefixes[prefix].push(table.tablename);
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
                    console.log(`   • ${table}`);
                });
            });
        
        // Highlight HR tables specifically
        const hrTables = sortedTables.filter(table => table.tablename.startsWith('hr_'));
        if (hrTables.length > 0) {
            console.log('\n🎯 HR TABLES SPECIFICALLY:');
            console.log('-'.repeat(30));
            hrTables.forEach((table, index) => {
                console.log(`${index + 1}. ${table.tablename}`);
            });
        }
        
        console.log('\n' + '='.repeat(70));
        console.log(`📈 TOTAL TABLES IN DATABASE: ${tables.length}`);
        console.log(`📈 HR TABLES: ${hrTables.length}`);
        console.log('='.repeat(70));
        
        return tables;
        
    } catch (error) {
        console.error('❌ Database scan failed:', error.message);
        return [];
    }
}

// Run the complete database scan
scanDatabase()
    .then((tables) => {
        console.log(`\n✅ Complete database scan finished! Found ${tables.length} total tables.`);
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n❌ Database scan failed:', error.message);
        process.exit(1);
    });

export { getAllActualTables, scanDatabase };