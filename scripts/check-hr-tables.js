/**
 * Check HR Tables in Supabase
 * This script connects to Supabase and lists all tables that start with "hr_"
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Supabase configuration
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Missing required environment variables:');
    console.error('   - SUPABASE_URL:', supabaseUrl ? '✅ Found' : '❌ Missing');
    console.error('   - SUPABASE_SERVICE_ROLE_KEY:', supabaseServiceKey ? '✅ Found' : '❌ Missing');
    process.exit(1);
}

// Create Supabase client with service role key (has admin privileges)
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkHrTables() {
    try {
        console.log('🔍 Connecting to Supabase...');
        console.log('📍 URL:', supabaseUrl);
        
        // Query to get all tables that start with "hr_"
        const { data, error } = await supabase
            .rpc('get_hr_tables'); // We'll create this function or use direct SQL
        
        if (error) {
            // If the function doesn't exist, try direct query
            console.log('📋 Querying tables directly...');
            
            // Direct SQL query to information_schema
            const { data: tables, error: queryError } = await supabase
                .from('information_schema.tables')
                .select('table_name, table_schema')
                .eq('table_schema', 'public')
                .like('table_name', 'hr_%')
                .order('table_name');
            
            if (queryError) {
                // Alternative approach using raw SQL
                const { data: rawData, error: rawError } = await supabase
                    .rpc('exec_sql', {
                        query: `
                            SELECT table_name, table_schema
                            FROM information_schema.tables 
                            WHERE table_schema = 'public' 
                            AND table_name LIKE 'hr_%'
                            ORDER BY table_name;
                        `
                    });
                
                if (rawError) {
                    console.error('❌ Error querying tables:', rawError.message);
                    return;
                }
                
                return rawData;
            }
            
            return tables;
        }
        
        return data;
        
    } catch (err) {
        console.error('❌ Connection error:', err.message);
        return null;
    }
}

async function listHrTables() {
    try {
        console.log('🚀 Starting HR tables check...\n');
        
        // Try multiple approaches to get table information
        const approaches = [
            // Approach 1: Direct query to pg_tables (PostgreSQL system table)
            async () => {
                const { data, error } = await supabase
                    .rpc('get_tables_starting_with', { prefix: 'hr_' });
                
                if (error) throw error;
                return data;
            },
            
            // Approach 2: Raw SQL query
            async () => {
                const { data, error } = await supabase
                    .rpc('exec_raw_sql', {
                        sql: `
                            SELECT schemaname, tablename 
                            FROM pg_tables 
                            WHERE schemaname = 'public' 
                            AND tablename LIKE 'hr_%'
                            ORDER BY tablename;
                        `
                    });
                
                if (error) throw error;
                return data;
            },
            
            // Approach 3: Simple table check (try to select from known HR tables)
            async () => {
                const commonHrTables = [
                    'hr_employees',
                    'hr_departments',
                    'hr_positions',
                    'hr_attendance',
                    'hr_payroll',
                    'hr_leaves',
                    'hr_evaluations'
                ];
                
                const existingTables = [];
                
                for (const tableName of commonHrTables) {
                    try {
                        const { data, error } = await supabase
                            .from(tableName)
                            .select('*')
                            .limit(1);
                        
                        if (!error) {
                            existingTables.push({
                                tablename: tableName,
                                schemaname: 'public'
                            });
                        }
                    } catch (e) {
                        // Table doesn't exist, skip
                    }
                }
                
                return existingTables;
            }
        ];
        
        let tables = null;
        let approach = 0;
        
        // Try each approach until one works
        for (const tryApproach of approaches) {
            approach++;
            try {
                console.log(`📋 Trying approach ${approach}...`);
                tables = await tryApproach();
                if (tables && tables.length >= 0) {
                    console.log(`✅ Approach ${approach} successful!`);
                    break;
                }
            } catch (error) {
                console.log(`❌ Approach ${approach} failed:`, error.message);
            }
        }
        
        if (!tables) {
            console.log('❌ All approaches failed. Unable to retrieve table information.');
            return;
        }
        
        // Display results
        console.log('\n' + '='.repeat(50));
        console.log('📊 HR TABLES ANALYSIS');
        console.log('='.repeat(50));
        
        if (tables.length === 0) {
            console.log('❌ No tables found starting with "hr_"');
        } else {
            console.log(`✅ Found ${tables.length} table(s) starting with "hr_":\n`);
            
            tables.forEach((table, index) => {
                console.log(`${index + 1}. ${table.tablename || table.table_name}`);
            });
        }
        
        console.log('\n' + '='.repeat(50));
        console.log(`📈 Total HR tables: ${tables.length}`);
        console.log('='.repeat(50));
        
    } catch (error) {
        console.error('❌ Fatal error:', error.message);
    }
}

// Run the function
listHrTables()
    .then(() => {
        console.log('\n✅ HR tables check completed!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n❌ Script failed:', error.message);
        process.exit(1);
    });

export {
    checkHrTables,
    listHrTables
};