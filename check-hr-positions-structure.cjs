const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjgyMjI4MDksImV4cCI6MjA0Mzc5ODgwOX0.VzHG8wJOC_pHpEXhP5QI0cK0xyNIyCLa1_9DZKH8DyE';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkHrPositionsStructure() {
    console.log('🔍 Checking hr_positions table structure...\n');
    
    try {
        // Check if hr_positions table exists and get its structure
        const { data: columns, error: columnsError } = await supabase
            .rpc('exec_sql', {
                sql: `
                    SELECT column_name, data_type, is_nullable, column_default
                    FROM information_schema.columns 
                    WHERE table_name = 'hr_positions' 
                    ORDER BY ordinal_position;
                `
            });

        if (columnsError) {
            console.log('❌ Error getting hr_positions structure via RPC, trying direct query...');
            
            // Try direct query to hr_positions table
            const { data: positionsData, error: directError } = await supabase
                .from('hr_positions')
                .select('*')
                .limit(3);

            if (directError) {
                console.log('❌ hr_positions table query failed:', directError);
                console.log('📝 The hr_positions table might not exist or might have different structure');
                
                // Check what position-related tables exist
                console.log('\n🔍 Checking for other position-related tables...');
                const { data: tables, error: tablesError } = await supabase
                    .rpc('exec_sql', {
                        sql: `
                            SELECT table_name 
                            FROM information_schema.tables 
                            WHERE table_schema = 'public' 
                            AND table_name LIKE '%position%' 
                            OR table_name LIKE '%hr%'
                            ORDER BY table_name;
                        `
                    });

                if (!tablesError && tables) {
                    console.log('📋 Available HR/Position tables:', tables);
                }
            } else {
                console.log('✅ hr_positions table exists! Sample data:');
                console.log(JSON.stringify(positionsData, null, 2));
            }
        } else {
            console.log('✅ hr_positions table structure:');
            console.log(JSON.stringify(columns, null, 2));
        }

        // Also check hr_position_assignments structure to understand the relationship
        console.log('\n🔍 Checking hr_position_assignments structure...');
        const { data: assignments, error: assignmentsError } = await supabase
            .from('hr_position_assignments')
            .select('*')
            .limit(3);

        if (assignmentsError) {
            console.log('❌ hr_position_assignments error:', assignmentsError);
        } else {
            console.log('✅ hr_position_assignments sample data:');
            console.log(JSON.stringify(assignments, null, 2));
        }

    } catch (error) {
        console.error('❌ Error:', error);
    }
}

checkHrPositionsStructure();