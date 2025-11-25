import { readFileSync } from 'fs';

console.log('🔍 Checking SQL Migration Files for Syntax Issues...\n');

const migrations = [
  { file: '20251125000001_add_variation_columns_to_flyer_products.sql', name: 'Add Variation Columns' },
  { file: '20251125000002_add_variation_tracking_to_offer_products.sql', name: 'Add Offer Tracking' },
  { file: '20251125000003_create_variation_audit_log.sql', name: 'Create Audit Log' },
  { file: '20251125000004_create_variation_helper_functions.sql', name: 'Create Helper Functions' },
  { file: '20251125000005_update_rls_policies_for_variations.sql', name: 'Update RLS Policies' }
];

let allValid = true;

for (const migration of migrations) {
  const filePath = `./supabase/migrations/${migration.file}`;
  
  try {
    const content = readFileSync(filePath, 'utf-8');
    
    console.log(`📄 ${migration.name}`);
    console.log(`   File: ${migration.file}`);
    console.log(`   Size: ${(content.length / 1024).toFixed(2)} KB`);
    
    // Basic SQL syntax checks
    const lines = content.split('\n').length;
    const hasComments = content.includes('--') || content.includes('/*');
    const hasCreateStatements = content.match(/CREATE\s+(TABLE|INDEX|FUNCTION|POLICY)/gi);
    const hasAlterStatements = content.match(/ALTER\s+TABLE/gi);
    
    console.log(`   Lines: ${lines}`);
    console.log(`   Comments: ${hasComments ? '✅' : '❌'}`);
    
    if (hasCreateStatements) {
      console.log(`   CREATE statements: ${hasCreateStatements.length}`);
    }
    if (hasAlterStatements) {
      console.log(`   ALTER statements: ${hasAlterStatements.length}`);
    }
    
    // Check for common SQL issues
    const issues = [];
    
    // Check for unmatched parentheses
    const openParens = (content.match(/\(/g) || []).length;
    const closeParens = (content.match(/\)/g) || []).length;
    if (openParens !== closeParens) {
      issues.push(`Unmatched parentheses (${openParens} open, ${closeParens} close)`);
    }
    
    // Check for unmatched quotes
    const singleQuotes = (content.match(/'/g) || []).length;
    if (singleQuotes % 2 !== 0) {
      issues.push(`Unmatched single quotes (${singleQuotes})`);
    }
    
    // Check for plpgsql function syntax
    if (content.includes('LANGUAGE plpgsql')) {
      const hasDollarQuotes = content.includes('$$');
      if (!hasDollarQuotes) {
        issues.push('PL/pgSQL function missing $$ delimiters');
      }
    }
    
    if (issues.length > 0) {
      console.log('   ⚠️  Potential Issues:');
      issues.forEach(issue => console.log(`      - ${issue}`));
      allValid = false;
    } else {
      console.log('   ✅ No obvious syntax issues detected');
    }
    
    console.log('');
  } catch (error) {
    console.log(`   ❌ Error reading file: ${error.message}\n`);
    allValid = false;
  }
}

console.log('═══════════════════════════════════════════════════');
if (allValid) {
  console.log('✅ All migration files appear syntactically valid');
  console.log('\n📋 Next Steps:');
  console.log('   1. Apply migrations via Supabase Dashboard SQL Editor');
  console.log('   2. Run: node verify-variation-migrations.js');
  console.log('   3. Proceed to Day 2 UI implementation');
} else {
  console.log('⚠️  Some files have potential issues');
  console.log('   Review the warnings above before applying migrations');
}
console.log('═══════════════════════════════════════════════════');
