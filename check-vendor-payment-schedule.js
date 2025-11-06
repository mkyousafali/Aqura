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

async function getVendorPaymentScheduleInfo() {
  try {
    console.log('🔍 Getting vendor_payment_schedule table information...\n')
    
    // 1. Get table structure
    console.log('📋 TABLE STRUCTURE:')
    console.log('=' .repeat(80))
    
    const { data: schemaData, error: schemaError } = await supabase.rpc('get_database_schema')
    
    if (!schemaError && schemaData && schemaData.tables) {
      const vendorTable = schemaData.tables.find(t => t.table_name === 'vendor_payment_schedule')
      
      if (vendorTable) {
        console.log(`Table: ${vendorTable.table_name}`)
        console.log('\nColumns:')
        vendorTable.columns.forEach((col, index) => {
          console.log(`${(index + 1).toString().padStart(3, ' ')}. ${col.column_name.padEnd(25)} | ${col.data_type.padEnd(15)} | ${col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL'} | ${col.column_default || 'No default'}`)
        })
      } else {
        console.log('❌ Table vendor_payment_schedule not found in schema')
      }
    }
    
    // 2. Get triggers
    console.log('\n\n🔧 TRIGGERS:')
    console.log('=' .repeat(80))
    
    const { data: triggers, error: triggerError } = await supabase.rpc('get_database_triggers')
    
    if (!triggerError && triggers) {
      const vendorTriggers = triggers.filter(t => t.table_name === 'vendor_payment_schedule')
      
      if (vendorTriggers.length > 0) {
        vendorTriggers.forEach((trigger, index) => {
          console.log(`${index + 1}. Trigger Name: ${trigger.trigger_name}`)
          console.log(`   Event: ${trigger.event_manipulation}`)
          console.log(`   Timing: ${trigger.action_timing}`)
          console.log(`   Function: ${trigger.action_statement}`)
          console.log('')
        })
      } else {
        console.log('No triggers found for vendor_payment_schedule table')
      }
    } else {
      console.log('❌ Could not retrieve triggers:', triggerError?.message || 'Unknown error')
    }
    
    // 3. Get related functions
    console.log('\n⚙️  RELATED FUNCTIONS:')
    console.log('=' .repeat(80))
    
    const { data: functions, error: functionsError } = await supabase.rpc('get_database_functions')
    
    if (!functionsError && functions) {
      console.log('Functions data structure:', typeof functions, Array.isArray(functions))
      
      if (Array.isArray(functions)) {
        // Filter functions that might be related to vendor_payment_schedule
        const vendorFunctions = functions.filter(f => 
          f && f.function_name && 
          f.function_name.toLowerCase().includes('vendor') && 
          f.function_name.toLowerCase().includes('payment')
        )
        
        if (vendorFunctions.length > 0) {
          console.log('Functions related to vendor payments:')
          vendorFunctions.forEach((func, index) => {
            console.log(`${index + 1}. ${func.function_name}`)
            console.log(`   Schema: ${func.schema_name || 'N/A'}`)
            console.log(`   Return Type: ${func.data_type || 'N/A'}`)
            if (func.function_arguments) {
              console.log(`   Arguments: ${func.function_arguments}`)
            }
            console.log('')
          })
        } else {
          console.log('No specific vendor payment functions found')
        }
        
        // Also look for general vendor functions
        const allVendorFunctions = functions.filter(f => 
          f && f.function_name && f.function_name.toLowerCase().includes('vendor')
        )
        
        if (allVendorFunctions.length > 0) {
          console.log('\nAll vendor-related functions:')
          allVendorFunctions.forEach((func, index) => {
            console.log(`${index + 1}. ${func.function_name}`)
          })
        } else {
          console.log('\nNo vendor-related functions found')
        }
      } else {
        console.log('Functions data:', functions)
      }
    } else {
      console.log('❌ Could not retrieve functions:', functionsError?.message || 'Unknown error')
    }
    
    // 4. Sample data (first 5 rows)
    console.log('\n\n📊 SAMPLE DATA (First 5 rows):')
    console.log('=' .repeat(80))
    
    const { data: sampleData, error: sampleError } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .limit(5)
    
    if (!sampleError && sampleData) {
      if (sampleData.length > 0) {
        console.log(`Found ${sampleData.length} sample records:`)
        sampleData.forEach((row, index) => {
          console.log(`\nRecord ${index + 1}:`)
          Object.entries(row).forEach(([key, value]) => {
            console.log(`  ${key}: ${value}`)
          })
        })
      } else {
        console.log('No data found in vendor_payment_schedule table')
      }
    } else {
      console.log('❌ Could not retrieve sample data:', sampleError?.message || 'Unknown error')
    }
    
    // 5. Record count
    console.log('\n\n📈 TABLE STATISTICS:')
    console.log('=' .repeat(80))
    
    const { count, error: countError } = await supabase
      .from('vendor_payment_schedule')
      .select('*', { count: 'exact', head: true })
    
    if (!countError) {
      console.log(`Total records: ${count}`)
    } else {
      console.log('❌ Could not get record count:', countError?.message || 'Unknown error')
    }

  } catch (err) {
    console.error('❌ Unexpected error:', err)
  }
}

// Run the check
getVendorPaymentScheduleInfo()