// Script to run database schema files
import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ'

const supabase = createClient(supabaseUrl, supabaseKey)

async function executeSQLStatement(statement) {
  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseKey}`,
        'apikey': supabaseKey
      },
      body: JSON.stringify({
        sql: statement
      })
    })

    if (!response.ok) {
      // Try direct SQL execution via Supabase API
      const sqlResponse = await fetch(`${supabaseUrl}/sql`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/sql',
          'Authorization': `Bearer ${supabaseKey}`,
          'apikey': supabaseKey
        },
        body: statement
      })

      if (!sqlResponse.ok) {
        const errorText = await sqlResponse.text()
        throw new Error(`SQL execution failed: ${sqlResponse.status} ${sqlResponse.statusText}: ${errorText}`)
      }

      return { data: await sqlResponse.json(), error: null }
    }

    return { data: await response.json(), error: null }
  } catch (error) {
    return { data: null, error: error.message }
  }
}

async function runSchemaFile(filename) {
  try {
    console.log(`Running schema file: ${filename}`)
    
    const sqlPath = join(__dirname, filename)
    const sqlContent = readFileSync(sqlPath, 'utf8')
    
    // For complex schemas, execute the entire SQL at once
    console.log('Executing complete schema...')
    
    const { data, error } = await executeSQLStatement(sqlContent)
    
    if (error) {
      console.error('Error executing schema:', error)
      
      // If full execution fails, try breaking into statements
      console.log('Attempting to execute statements individually...')
      
      const statements = sqlContent
        .split(';')
        .map(stmt => stmt.trim())
        .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'))
      
      console.log(`Found ${statements.length} SQL statements to execute`)
      
      let successCount = 0
      let errorCount = 0
      
      for (let i = 0; i < statements.length; i++) {
        const statement = statements[i]
        if (statement.trim() === '') continue
        
        try {
          console.log(`Executing statement ${i + 1}/${statements.length}`)
          console.log(`Statement preview: ${statement.substring(0, 80)}...`)
          
          const { data, error } = await executeSQLStatement(statement + ';')
          
          if (error) {
            console.error(`Error in statement ${i + 1}:`, error)
            errorCount++
          } else {
            console.log(`✓ Statement ${i + 1} executed successfully`)
            successCount++
          }
          
          // Small delay to avoid overwhelming the API
          await new Promise(resolve => setTimeout(resolve, 100))
          
        } catch (err) {
          console.error(`Exception in statement ${i + 1}:`, err.message)
          errorCount++
        }
      }
      
      console.log(`\nExecution complete:`)
      console.log(`✓ Successful: ${successCount}`)
      console.log(`✗ Errors: ${errorCount}`)
      
      return { successCount, errorCount }
    } else {
      console.log('✓ Schema executed successfully!')
      return { successCount: 1, errorCount: 0 }
    }
    
  } catch (error) {
    console.error('Error running schema file:', error.message)
    throw error
  }
}

// Get filename from command line arguments
const filename = process.argv[2]
if (!filename) {
  console.error('Usage: node run-sql-fix.js <schema-file.sql>')
  process.exit(1)
}

runSchemaFile(filename).catch(console.error)