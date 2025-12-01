#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createClient } from '@supabase/supabase-js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Read environment variables from frontend/.env
const envPath = path.join(__dirname, '..', 'frontend', '.env');
let envContent = '';

try {
  envContent = fs.readFileSync(envPath, 'utf-8');
} catch (err) {
  console.error('❌ Error reading .env file:', err.message);
  process.exit(1);
}

const envVars = {};
envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in .env');
  process.exit(1);
}

// Create Supabase client
const supabase = createClient(supabaseUrl, supabaseServiceKey);

(async () => {
  try {
    console.log('🔍 Querying database schema...\n');

    // Call the get_database_schema function
    const { data, error } = await supabase.rpc('get_database_schema');

    if (error) {
      console.error('❌ Error fetching schema:', error);
      process.exit(1);
    }

    if (!data || !Array.isArray(data)) {
      console.error('❌ Unexpected response format');
      process.exit(1);
    }

    console.log(`✅ Retrieved schema for ${data.length} column definitions\n`);

    // Group columns by table
    const tablesByName = {};
    
    data.forEach(item => {
      const tableName = item.table_name;
      if (!tablesByName[tableName]) {
        tablesByName[tableName] = [];
      }
      tablesByName[tableName].push({
        name: item.column_name,
        type: item.data_type,
        nullable: item.is_nullable
      });
    });

    const tables = Object.keys(tablesByName).sort();

    // Generate markdown content
    let markdownContent = `# Supabase Database Schema

**Generated:** ${new Date().toLocaleString()}  
**Total Tables:** ${tables.length}  
**Total Columns:** ${data.length}

---

## Table of Contents

`;

    // Add table of contents
    tables.forEach((tableName, index) => {
      markdownContent += `${index + 1}. [${tableName}](#${tableName})\n`;
    });

    markdownContent += `\n---\n\n`;

    // Generate table documentation
    tables.forEach(tableName => {
      const columns = tablesByName[tableName];
      
      markdownContent += `## ${tableName}\n\n`;
      markdownContent += `**Total Columns:** ${columns.length}\n\n`;
      markdownContent += `| Column Name | Data Type | Nullable |\n`;
      markdownContent += `|---|---|---|\n`;
      
      columns.forEach(col => {
        const nullable = col.nullable ? '✓ Yes' : '✗ No';
        markdownContent += `| \`${col.name}\` | \`${col.type}\` | ${nullable} |\n`;
      });
      
      markdownContent += `\n`;
    });

    // Write to file
    const outputPath = path.join(__dirname, '..', 'DATABASE_SCHEMA.md');
    fs.writeFileSync(outputPath, markdownContent, 'utf-8');

    console.log(`✅ Markdown file created successfully!`);
    console.log(`📄 File: ${outputPath}`);
    console.log(`📊 Total tables: ${tables.length}`);
    console.log(`📋 Total columns: ${data.length}`);

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
