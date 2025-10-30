/**
 * Comprehensive HR Tables Scanner
 * This script uses multiple methods to find ALL tables starting with "hr_"
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

async function getAllHrTables() {
    console.log('🚀 Starting comprehensive HR tables scan...\n');
    
    try {
        // Method 1: Direct SQL query using rpc to execute raw SQL
        console.log('📋 Method 1: Direct SQL query...');
        
        const { data: sqlResult, error: sqlError } = await supabase.rpc('exec_sql', {
            query: `
                SELECT tablename, schemaname
                FROM pg_tables 
                WHERE schemaname = 'public' 
                AND tablename LIKE 'hr_%'
                ORDER BY tablename;
            `
        });
        
        if (!sqlError && sqlResult) {
            console.log('✅ Method 1 successful!');
            return sqlResult;
        }
        
        console.log('⚠️ Method 1 failed, trying Method 2...');
        
        // Method 2: Use information_schema
        const { data: schemaResult, error: schemaError } = await supabase.rpc('exec_sql', {
            query: `
                SELECT table_name as tablename, table_schema as schemaname
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name LIKE 'hr_%'
                ORDER BY table_name;
            `
        });
        
        if (!schemaError && schemaResult) {
            console.log('✅ Method 2 successful!');
            return schemaResult;
        }
        
        console.log('⚠️ Method 2 failed, trying Method 3...');
        
        // Method 3: Try to query each possible HR table by checking for errors
        console.log('📋 Method 3: Systematic table discovery...');
        
        const potentialHrTables = [
            'hr_employees',
            'hr_departments', 
            'hr_positions',
            'hr_attendance',
            'hr_payroll',
            'hr_leaves',
            'hr_evaluations',
            'hr_benefits',
            'hr_training',
            'hr_contracts',
            'hr_holidays',
            'hr_overtime',
            'hr_timesheets',
            'hr_performance',
            'hr_recruitment',
            'hr_onboarding',
            'hr_offboarding',
            'hr_policies',
            'hr_documents',
            'hr_skills',
            'hr_certifications',
            'hr_salary_history',
            'hr_promotions',
            'hr_disciplinary',
            'hr_grievances',
            'hr_exit_interviews',
            'hr_employee_relations',
            'hr_work_schedules',
            'hr_locations',
            'hr_job_titles',
            'hr_employee_types',
            'hr_employment_status',
            'hr_emergency_contacts',
            'hr_bank_details',
            'hr_tax_info',
            'hr_insurance',
            'hr_pension',
            'hr_allowances',
            'hr_deductions',
            'hr_bonuses',
            'hr_commissions',
            'hr_expenses',
            'hr_reimbursements'
        ];
        
        const existingTables = [];
        
        for (const tableName of potentialHrTables) {
            try {
                // Try to select from the table
                const { data, error } = await supabase
                    .from(tableName)
                    .select('*')
                    .limit(1);
                
                if (!error || error.message.includes('row-level security')) {
                    // Table exists (error might be due to RLS, but table exists)
                    existingTables.push({
                        tablename: tableName,
                        schemaname: 'public'
                    });
                    console.log(`   ✅ Found: ${tableName}`);
                }
            } catch (e) {
                // Table doesn't exist or other error
                if (!e.message.includes('does not exist')) {
                    console.log(`   ⚠️ ${tableName}: ${e.message.substring(0, 50)}...`);
                }
            }
        }
        
        return existingTables;
        
    } catch (error) {
        console.error('❌ Error during scan:', error.message);
        return [];
    }
}

async function scanAllTables() {
    try {
        const tables = await getAllHrTables();
        
        console.log('\n' + '='.repeat(60));
        console.log('📊 COMPREHENSIVE HR TABLES ANALYSIS');
        console.log('='.repeat(60));
        
        if (tables.length === 0) {
            console.log('❌ No tables found starting with "hr_"');
        } else {
            console.log(`✅ Found ${tables.length} table(s) starting with "hr_":\n`);
            
            tables.forEach((table, index) => {
                console.log(`${(index + 1).toString().padStart(2)}. ${table.tablename}`);
            });
            
            // Group by category for better visualization
            console.log('\n📋 TABLES BY CATEGORY:');
            console.log('-'.repeat(40));
            
            const categories = {
                'Core HR': ['hr_employees', 'hr_departments', 'hr_positions', 'hr_job_titles'],
                'Time & Attendance': ['hr_attendance', 'hr_timesheets', 'hr_overtime', 'hr_work_schedules', 'hr_holidays'],
                'Payroll': ['hr_payroll', 'hr_salary_history', 'hr_allowances', 'hr_deductions', 'hr_bonuses'],
                'Benefits': ['hr_benefits', 'hr_insurance', 'hr_pension'],
                'Performance': ['hr_evaluations', 'hr_performance', 'hr_training', 'hr_skills'],
                'Employee Lifecycle': ['hr_recruitment', 'hr_onboarding', 'hr_offboarding', 'hr_exit_interviews'],
                'Personal Data': ['hr_emergency_contacts', 'hr_bank_details', 'hr_tax_info'],
                'Other': []
            };
            
            const foundTableNames = tables.map(t => t.tablename);
            
            for (const [category, categoryTables] of Object.entries(categories)) {
                const foundInCategory = categoryTables.filter(table => foundTableNames.includes(table));
                if (foundInCategory.length > 0) {
                    console.log(`\n🔹 ${category}:`);
                    foundInCategory.forEach(table => {
                        console.log(`   • ${table}`);
                    });
                }
            }
            
            // Check for uncategorized tables
            const categorizedTables = Object.values(categories).flat();
            const uncategorized = foundTableNames.filter(table => !categorizedTables.includes(table));
            if (uncategorized.length > 0) {
                console.log(`\n🔹 Other:`);
                uncategorized.forEach(table => {
                    console.log(`   • ${table}`);
                });
            }
        }
        
        console.log('\n' + '='.repeat(60));
        console.log(`📈 TOTAL HR TABLES: ${tables.length}`);
        console.log('='.repeat(60));
        
        return tables;
        
    } catch (error) {
        console.error('❌ Fatal error:', error.message);
        return [];
    }
}

// Run the comprehensive scan
scanAllTables()
    .then((tables) => {
        console.log(`\n✅ Comprehensive HR tables scan completed! Found ${tables.length} tables.`);
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n❌ Scan failed:', error.message);
        process.exit(1);
    });

export { getAllHrTables, scanAllTables };