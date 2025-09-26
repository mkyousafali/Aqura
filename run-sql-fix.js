// Temporary script to run the database fix
import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'fs'

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjczNTAwMTIsImV4cCI6MjA0MjkyNjAxMn0.QvCl5vNMX1-JQyMSDq8cUoL3G_Vdn1WaXPWUBTTh6GA'

const supabase = createClient(supabaseUrl, supabaseKey)

async function runFix() {
  console.log('Checking current data types...')
  
  // Check current data types
  const { data: typeCheck, error: typeError } = await supabase
    .from('information_schema.columns')
    .select('table_name, column_name, data_type')
    .or('and(table_name.eq.hr_fingerprint_transactions,column_name.eq.branch_id),and(table_name.eq.branches,column_name.eq.id)')
  
  if (typeError) {
    console.error('Error checking types:', typeError)
    return
  }
  
  console.log('Current data types:', typeCheck)
  
  // Delete existing data
  console.log('Deleting existing fingerprint data...')
  const { error: deleteError } = await supabase
    .from('hr_fingerprint_transactions')
    .delete()
    .neq('id', '00000000-0000-0000-0000-000000000000') // Delete all
  
  if (deleteError) {
    console.error('Error deleting data:', deleteError)
  }
  
  // The ALTER TABLE commands need to be run via the SQL editor in Supabase dashboard
  console.log('Please run these SQL commands in Supabase SQL editor:')
  console.log('ALTER TABLE hr_fingerprint_transactions ALTER COLUMN branch_id TYPE bigint USING NULL;')
  console.log('ALTER TABLE hr_fingerprint_transactions ADD CONSTRAINT hr_fingerprint_transactions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id);')
}

runFix().catch(console.error)