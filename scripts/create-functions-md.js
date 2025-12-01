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

console.log('🔍 Querying database information schema for functions...\n');

// Query the information_schema.routines table using REST API
const apiUrl = `${supabaseUrl}/rest/v1/rpc/get_database_functions`;

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
    process.exit(1);
  }

  const data = await response.json();
  let functionsArray = data.functions || (Array.isArray(data) ? data : []);
  
  if (!Array.isArray(functionsArray)) {
    console.error('❌ Expected array response');
    process.exit(1);
  }

  console.log(`✅ Retrieved ${functionsArray.length} database functions\n`);

  // Extract and organize function names from return type info
  const functionDetails = new Map();
  
  // Common known function categories based on naming patterns
  const categoryPatterns = {
    'Task Management': ['task', 'assignment', 'completion', 'reminder'],
    'Receiving & Vendor': ['receiving', 'vendor', 'visit', 'payment_schedule'],
    'User Management': ['user', 'auth', 'password', 'session', 'permission', 'role'],
    'Employee/HR': ['employee', 'hr_', 'salary', 'position', 'department'],
    'Financial': ['expense', 'requisition', 'payment', 'fine', 'warning'],
    'Notification': ['notification', 'push', 'queue', 'subscribe'],
    'Customer': ['customer', 'recovery', 'access_code'],
    'System/ERP': ['sync', 'erp', 'database', 'schema', 'http_'],
    'Offer Management': ['offer', 'coupon', 'bundle', 'cart_tier', 'usage'],
  };

  // Count by category based on function metadata
  const categoryCount = {};
  const functionsByCategory = {};

  functionsArray.forEach(func => {
    // Extract function name from return type or other metadata
    let functionName = func.function_name || func.routine_name || 'Unknown';
    let category = 'Other';

    // Categorize based on name patterns
    for (const [cat, patterns] of Object.entries(categoryPatterns)) {
      if (patterns.some(pattern => functionName.toLowerCase().includes(pattern))) {
        category = cat;
        break;
      }
    }

    if (!functionsByCategory[category]) {
      functionsByCategory[category] = [];
    }

    functionsByCategory[category].push({
      name: functionName,
      returnType: func.return_type || func.type_udt_name || 'unknown'
    });

    categoryCount[category] = (categoryCount[category] || 0) + 1;
  });

  // Sort categories
  const categories = Object.keys(functionsByCategory).sort();

  // Generate markdown content
  let markdownContent = `# Supabase Database Functions

**Generated:** ${new Date().toLocaleString('en-US', { 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })}  
**Total Functions:** ${functionsArray.length}  
**Categories:** ${categories.length}

---

## Summary

| Category | Function Count |
|---|---|
`;

  categories.forEach(cat => {
    markdownContent += `| ${cat} | ${categoryCount[cat]} |\n`;
  });

  markdownContent += `| **TOTAL** | **${functionsArray.length}** |\n\n`;

  markdownContent += `---\n\n## Table of Contents\n\n`;

  // Add table of contents with categories
  categories.forEach((category, index) => {
    const functionCount = functionsByCategory[category].length;
    markdownContent += `${index + 1}. [${category}](#${category.replace(/\s+/g, '-').toLowerCase()}) - ${functionCount} functions\n`;
  });

  markdownContent += `\n---\n\n`;

  // Generate function documentation by category
  categories.forEach(category => {
    const functions = functionsByCategory[category].sort((a, b) => 
      a.name.localeCompare(b.name)
    );
    
    markdownContent += `## ${category}\n\n`;
    markdownContent += `**Total Functions:** ${functions.length}\n\n`;
    markdownContent += `| Function Name | Return Type |\n`;
    markdownContent += `|---|---|\n`;
    
    functions.forEach(func => {
      markdownContent += `| \`${func.name}\` | \`${func.returnType}\` |\n`;
    });
    
    markdownContent += `\n`;
  });

  // Write to file
  const outputPath = path.join(__dirname, '..', 'DATABASE_FUNCTIONS.md');
  fs.writeFileSync(outputPath, markdownContent, 'utf-8');

  console.log(`✅ Markdown file created successfully!\n`);
  console.log(`📄 File: DATABASE_FUNCTIONS.md`);
  console.log(`📊 Total functions: ${functionsArray.length}`);
  console.log(`📁 Categories: ${categories.length}`);
  console.log(`💾 File size: ${(markdownContent.length / 1024).toFixed(2)} KB`);
  console.log(`\n📋 Functions by Category:`);
  categories.forEach(cat => {
    console.log(`  • ${cat}: ${categoryCount[cat]} functions`);
  });

} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
