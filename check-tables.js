import { createClient } from '@supabase/supabase-js'

// Configuration from .env file
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ'

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function checkDatabaseTables() {
  try {
    console.log('🔍 Checking database tables...\n')
    
    // Use raw SQL query to get table information
    const { data: tables, error } = await supabase.rpc('get_database_schema')

    if (error) {
      console.log('⚠️  get_database_schema function not available, trying alternative method...\n')
      
      // Alternative: Use a direct SQL query via the REST API
      const { data: tablesAlt, error: errorAlt } = await supabase
        .from('pg_tables')
        .select('tablename, schemaname')
        .eq('schemaname', 'public')
        .order('tablename')

      if (errorAlt) {
        console.log('⚠️  pg_tables not accessible, trying manual table listing...\n')
        
        // Try to manually list known tables by attempting to query them
        const knownTables = [
          'users', 'employees', 'tasks', 'receiving_records', 'vendors', 'branches',
          'departments', 'positions', 'task_assignments', 'notifications', 'push_subscriptions',
          'bills', 'expenses', 'warnings', 'schedules', 'visits', 'promissory_notes',
          'receiving_tasks', 'quick_tasks', 'overdue_reminders', 'notification_read_states',
          'app_functions', 'system_roles', 'user_roles', 'employee_documents', 'clearance_certificates'
        ]
        
        const existingTables = []
        
        for (const tableName of knownTables) {
          try {
            const { error: tableError } = await supabase
              .from(tableName)
              .select('*')
              .limit(1)
            
            if (!tableError) {
              existingTables.push(tableName)
            }
          } catch (e) {
            // Table doesn't exist or not accessible
          }
        }
        
        console.log(`📊 Found ${existingTables.length} accessible tables:\n`)
        console.log('📋 List of accessible tables:')
        console.log('=' .repeat(50))
        
        existingTables.forEach((table, index) => {
          console.log(`${(index + 1).toString().padStart(3, ' ')}. ${table}`)
        })
        
        console.log('\n' + '=' .repeat(50))
        console.log(`📈 Summary: Found ${existingTables.length} accessible tables`)
        console.log('ℹ️  Note: This is based on known table names. There may be additional tables.')
        
        return
      }
      
      console.log(`� Total number of tables in public schema: ${tablesAlt.length}\n`)
      
      console.log('📋 List of all tables:')
      console.log('=' .repeat(50))
      
      tablesAlt.forEach((table, index) => {
        console.log(`${(index + 1).toString().padStart(3, ' ')}. ${table.tablename}`)
      })
      
      console.log('\n' + '=' .repeat(50))
      console.log(`📈 Summary: Found ${tablesAlt.length} tables in the database`)
      
      return
    }

    console.log(`📊 Total number of tables in public schema: ${tables.tables.length}\n`)
    
    console.log('📋 Complete list of all tables:')
    console.log('=' .repeat(60))
    
    tables.tables.forEach((table, index) => {
      console.log(`${(index + 1).toString().padStart(3, ' ')}. ${table.table_name}`)
    })
    
    console.log('\n' + '=' .repeat(60))
    console.log(`📈 FINAL COUNT: ${tables.tables.length} tables exist in the database`)
    console.log('✅ This is the actual count from the database schema')

  } catch (err) {
    console.error('❌ Unexpected error:', err)
  }
}

// Run the check
checkDatabaseTables()