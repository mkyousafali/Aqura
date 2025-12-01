#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

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

console.log('🔍 Fetching database schema from Supabase...\n');

const apiUrl = `${supabaseUrl}/rest/v1/rpc/get_database_schema`;

try {
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${supabaseServiceKey}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'apikey': supabaseServiceKey,
    },
    body: JSON.stringify({}),
  });

  if (!response.ok) {
    console.error(`❌ HTTP Error: ${response.status} ${response.statusText}`);
    const error = await response.text();
    console.error('Error details:', error);
    process.exit(1);
  }

  const data = await response.json();
  
  // The function returns an object with a 'tables' property containing the array
  let schemaArray = data.tables || (Array.isArray(data) ? data : []);
  
  if (typeof schemaArray === 'string') {
    try {
      schemaArray = JSON.parse(schemaArray);
    } catch (e) {
      console.error('❌ Could not parse response');
      console.error('Response:', schemaArray);
      process.exit(1);
    }
  }

  if (!Array.isArray(schemaArray)) {
    console.error('❌ Expected array response from database');
    console.error('Got:', typeof schemaArray);
    process.exit(1);
  }

  console.log(`✅ Retrieved schema for ${schemaArray.length} tables\n`);

  // Sort tables by name
  const sortedTables = schemaArray.sort((a, b) => 
    a.table_name.localeCompare(b.table_name)
  );

  // Generate markdown content
  let markdownContent = `# Supabase Database Schema

**Generated:** ${new Date().toLocaleString('en-US', { 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })}  
**Total Tables:** ${sortedTables.length}  
**Total Columns:** ${schemaArray.reduce((sum, t) => sum + (t.columns?.length || 0), 0)}

---

## Table of Contents

`;

  // Add table of contents
  sortedTables.forEach((table, index) => {
    const columnCount = table.columns?.length || 0;
    markdownContent += `${index + 1}. [${table.table_name}](#${table.table_name}) - ${columnCount} columns\n`;
  });

  markdownContent += `\n---\n\n`;

  // Generate table documentation
  sortedTables.forEach(table => {
    const columns = table.columns || [];
    
    markdownContent += `## ${table.table_name}\n\n`;
    markdownContent += `**Total Columns:** ${columns.length}\n\n`;
    markdownContent += `| Column Name | Data Type | Nullable | Default |\n`;
    markdownContent += `|---|---|---|---|\n`;
    
    columns.forEach(col => {
      const nullable = col.is_nullable === 'YES' ? '✓ Yes' : '✗ No';
      const defaultValue = col.column_default ? `\`${col.column_default}\`` : '-';
      markdownContent += `| \`${col.column_name}\` | \`${col.data_type}\` | ${nullable} | ${defaultValue} |\n`;
    });
    
    markdownContent += `\n`;
  });

  // Write to file
  const outputPath = path.join(__dirname, '..', 'DATABASE_SCHEMA.md');
  fs.writeFileSync(outputPath, markdownContent, 'utf-8');

  console.log(`✅ Markdown file created successfully!\n`);
  console.log(`📄 File: DATABASE_SCHEMA.md`);
  console.log(`📊 Total tables: ${sortedTables.length}`);
  console.log(`📋 Total columns: ${schemaArray.reduce((sum, t) => sum + (t.columns?.length || 0), 0)}`);
  console.log(`💾 File size: ${(markdownContent.length / 1024).toFixed(2)} KB`);

} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
