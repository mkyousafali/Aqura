import { createClient } from '@supabase/supabase-js'
import fs from 'fs'
import path from 'path'

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

// Output directory for table schemas
const outputDir = 'D:\\Aqura\\supabase\\migrations\\table-schemas'

async function createTableSchemaFiles() {
  try {
    console.log('🔍 Starting table schema extraction...\n')
    
    // Create output directory if it doesn't exist
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true })
      console.log(`📁 Created directory: ${outputDir}`)
    }
    
    // Get database schema
    const { data: schemaData, error: schemaError } = await supabase.rpc('get_database_schema')
    
    if (schemaError || !schemaData || !schemaData.tables) {
      console.error('❌ Error getting database schema:', schemaError)
      return
    }
    
    // Get triggers
    const { data: triggers, error: triggerError } = await supabase.rpc('get_database_triggers')
    
    // Get functions
    const { data: functions, error: functionsError } = await supabase.rpc('get_database_functions')
    
    console.log(`📊 Found ${schemaData.tables.length} tables to process\n`)
    
    // Process each table
    for (const table of schemaData.tables) {
      console.log(`📋 Processing table: ${table.table_name}`)
      
      // Generate SQL content for the table
      const sqlContent = generateTableSQL(table, triggers, functions)
      
      // Write to file
      const fileName = `${table.table_name}.sql`
      const filePath = path.join(outputDir, fileName)
      
      fs.writeFileSync(filePath, sqlContent, 'utf8')
      console.log(`   ✅ Created: ${fileName}`)
    }
    
    console.log(`\n🎉 Successfully created ${schemaData.tables.length} table schema files!`)
    console.log(`📁 Location: ${outputDir}`)
    
  } catch (err) {
    console.error('❌ Unexpected error:', err)
  }
}

function generateTableSQL(table, triggers, functions) {
  const tableName = table.table_name
  const currentDate = new Date().toISOString()
  
  let sql = `-- ================================================================
-- TABLE SCHEMA: ${tableName}
-- Generated: ${currentDate}
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

`

  // 1. CREATE TABLE statement
  sql += `-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.${tableName} (
`

  // Add columns
  const columnDefinitions = table.columns.map(col => {
    let def = `    ${col.column_name} ${col.data_type}`
    
    // Add constraints
    if (col.is_nullable === 'NO') {
      def += ' NOT NULL'
    }
    
    // Add default value
    if (col.column_default) {
      def += ` DEFAULT ${col.column_default}`
    }
    
    return def
  })
  
  sql += columnDefinitions.join(',\n')
  sql += `\n);\n\n`
  
  // 2. Add table comment
  sql += `-- Table comment
COMMENT ON TABLE public.${tableName} IS 'Table for ${tableName.replace(/_/g, ' ')} management';\n\n`
  
  // 3. Add column comments
  sql += `-- Column comments\n`
  table.columns.forEach(col => {
    const comment = generateColumnComment(col)
    sql += `COMMENT ON COLUMN public.${tableName}.${col.column_name} IS '${comment}';\n`
  })
  sql += '\n'
  
  // 4. Add indexes (common patterns)
  sql += `-- ================================================================
-- INDEXES
-- ================================================================

`
  
  // Primary key index (assuming id column)
  const idColumn = table.columns.find(col => col.column_name === 'id')
  if (idColumn) {
    sql += `-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS ${tableName}_pkey ON public.${tableName} USING btree (id);

`
  }
  
  // Common foreign key indexes
  const fkColumns = table.columns.filter(col => 
    col.column_name.endsWith('_id') && col.column_name !== 'id'
  )
  
  fkColumns.forEach(col => {
    sql += `-- Foreign key index for ${col.column_name}
CREATE INDEX IF NOT EXISTS idx_${tableName}_${col.column_name} ON public.${tableName} USING btree (${col.column_name});

`
  })
  
  // Date indexes
  const dateColumns = table.columns.filter(col => 
    col.data_type.includes('timestamp') || col.data_type.includes('date')
  )
  
  dateColumns.forEach(col => {
    if (!col.column_name.includes('updated_at') && !col.column_name.includes('created_at')) {
      sql += `-- Date index for ${col.column_name}
CREATE INDEX IF NOT EXISTS idx_${tableName}_${col.column_name} ON public.${tableName} USING btree (${col.column_name});

`
    }
  })
  
  // 5. Add triggers
  sql += `-- ================================================================
-- TRIGGERS
-- ================================================================

`
  
  if (triggers && Array.isArray(triggers)) {
    const tableTriggers = triggers.filter(t => t.table_name === tableName)
    
    if (tableTriggers.length > 0) {
      tableTriggers.forEach(trigger => {
        sql += `-- Trigger: ${trigger.trigger_name}
-- Event: ${trigger.event_manipulation}
-- Timing: ${trigger.action_timing}
${trigger.action_statement}

`
      })
    } else {
      sql += `-- No triggers defined for ${tableName}

`
    }
  } else {
    sql += `-- Trigger information not available

`
  }
  
  // 6. Add Row Level Security
  sql += `-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.${tableName} ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "${tableName}_select_policy" ON public.${tableName}
    FOR SELECT USING (true);

CREATE POLICY "${tableName}_insert_policy" ON public.${tableName}
    FOR INSERT WITH CHECK (true);

CREATE POLICY "${tableName}_update_policy" ON public.${tableName}
    FOR UPDATE USING (true);

CREATE POLICY "${tableName}_delete_policy" ON public.${tableName}
    FOR DELETE USING (true);

`
  
  // 7. Add related functions
  sql += `-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

`
  
  if (functions && Array.isArray(functions)) {
    const relatedFunctions = functions.filter(f => {
      if (!f || !f.function_name) return false
      const funcName = f.function_name.toLowerCase()
      const tableNameLower = tableName.toLowerCase()
      
      // Look for functions that contain the table name or are clearly related
      return funcName.includes(tableNameLower) || 
             funcName.includes(tableNameLower.replace('_', '')) ||
             (tableNameLower.includes('vendor') && funcName.includes('vendor')) ||
             (tableNameLower.includes('task') && funcName.includes('task')) ||
             (tableNameLower.includes('user') && funcName.includes('user')) ||
             (tableNameLower.includes('notification') && funcName.includes('notification'))
    })
    
    if (relatedFunctions.length > 0) {
      sql += `-- Related functions for ${tableName}:\n`
      relatedFunctions.forEach(func => {
        sql += `-- * ${func.function_name}\n`
      })
      sql += `\n-- To get function definitions, run:\n`
      relatedFunctions.forEach(func => {
        sql += `-- SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = '${func.function_name}';\n`
      })
    } else {
      sql += `-- No specific related functions found for ${tableName}`
    }
  } else {
    sql += `-- Function information not available`
  }
  
  sql += `

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.${tableName} (${table.columns.slice(1, 4).map(c => c.column_name).join(', ')})
VALUES (${table.columns.slice(1, 4).map(c => getExampleValue(c)).join(', ')});
*/

-- Select example
/*
SELECT * FROM public.${tableName} 
WHERE ${table.columns.find(c => c.column_name.endsWith('_id'))?.column_name || 'id'} = $1;
*/

-- Update example
/*
UPDATE public.${tableName} 
SET ${table.columns.find(c => c.column_name === 'updated_at')?.column_name || table.columns[table.columns.length - 1].column_name} = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF ${tableName.toUpperCase()} SCHEMA
-- ================================================================
`
  
  return sql
}

function generateColumnComment(col) {
  const colName = col.column_name
  const dataType = col.data_type
  
  // Generate meaningful comments based on column name patterns
  if (colName === 'id') return 'Primary key identifier'
  if (colName.endsWith('_id')) return `Foreign key reference to ${colName.replace('_id', '')} table`
  if (colName === 'created_at') return 'Timestamp when record was created'
  if (colName === 'updated_at') return 'Timestamp when record was last updated'
  if (colName.includes('email')) return 'Email address'
  if (colName.includes('name')) return 'Name field'
  if (colName.includes('status')) return 'Status indicator'
  if (colName.includes('date')) return 'Date field'
  if (colName.includes('amount')) return 'Monetary amount'
  if (colName.includes('number')) return 'Reference number'
  if (colName.includes('url')) return 'URL or file path'
  if (colName.includes('notes')) return 'Additional notes or comments'
  if (colName.includes('phone')) return 'Phone number'
  if (colName.includes('address')) return 'Address information'
  if (dataType === 'boolean') return 'Boolean flag'
  if (dataType === 'jsonb') return 'JSON data structure'
  
  return `${colName.replace(/_/g, ' ')} field`
}

function getExampleValue(col) {
  const dataType = col.data_type
  
  if (dataType.includes('uuid')) return "'uuid-example'"
  if (dataType.includes('varchar') || dataType.includes('text')) return "'example text'"
  if (dataType.includes('integer') || dataType.includes('numeric')) return '123'
  if (dataType.includes('boolean')) return 'true'
  if (dataType.includes('date') || dataType.includes('timestamp')) return "'2025-11-06'"
  if (dataType.includes('jsonb')) return "'{}'"
  
  return "'example'"
}

// Run the extraction
createTableSchemaFiles()