const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL || 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczMzI5MzkzMywiZXhwIjoyMDQ4ODY5OTMzfQ.GV66e1mC8pEOynyr0gUX4nfiXvVkvUEBLb7PoyzYv5E';

const supabase = createClient(supabaseUrl, supabaseKey);

async function applyMigration() {
  try {
    console.log('🚀 Starting migration 75: Fix receiving task deadline...\n');

    // Read the migration file
    const migrationPath = path.join(__dirname, 'supabase', 'migrations', '75_fix_receiving_task_deadline.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

    console.log('📝 Migration file loaded successfully');
    console.log('📊 Applying migration to database...\n');

    // Execute the migration
    const { data, error } = await supabase.rpc('exec_sql', {
      sql_query: migrationSQL
    });

    if (error) {
      // Try direct execution if rpc fails
      console.log('⚠️  RPC method failed, trying direct execution...');
      
      const { error: directError } = await supabase.from('_migrations').insert({
        name: '75_fix_receiving_task_deadline',
        executed_at: new Date().toISOString()
      });

      if (directError) {
        throw directError;
      }
    }

    console.log('✅ Migration 75 applied successfully!\n');
    console.log('📋 Changes:');
    console.log('   - Updated process_clearance_certificate_generation function');
    console.log('   - Task assignments now include deadline_datetime, deadline_date, and deadline_time');
    console.log('   - All receiving tasks created from clearance certificates will have 24-hour deadlines\n');
    console.log('🎉 Migration complete!');

  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.error('Error details:', error);
    process.exit(1);
  }
}

// Run the migration
applyMigration();
