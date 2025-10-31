const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Read .env file manually
const envPath = path.join(__dirname, '..', 'frontend', '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  line = line.trim();
  if (line && !line.startsWith('#')) {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      let value = match[2].trim();
      // Remove quotes if present
      value = value.replace(/^["']|["']$/g, '');
      envVars[key] = value;
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

console.log('📋 Loaded credentials:');
console.log('   URL:', supabaseUrl ? '✓' : '✗');
console.log('   Service Key:', supabaseServiceKey ? '✓' : '✗');
console.log();

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function checkUserTypeEnum() {
  console.log('🔍 Checking user_type enum values...\n');

  try {
    // Query 1: Check enum values
    console.log('1️⃣ Checking user_type_enum values:');
    const { data: enumData, error: enumError } = await supabase.rpc('exec_sql', {
      query: `
        SELECT enumlabel as enum_value
        FROM pg_type t 
        JOIN pg_enum e ON t.oid = e.enumtypid  
        WHERE t.typname = 'user_type_enum'
        ORDER BY e.enumsortorder;
      `
    });

    if (enumError) {
      console.log('   Trying alternate query method...');
      // Try direct query
      const { data: altData, error: altError } = await supabase
        .from('pg_enum')
        .select('*')
        .limit(10);
      
      console.log('   Note: Need to run SQL directly in Supabase dashboard');
      console.log('   Run this query:');
      console.log('   ' + '-'.repeat(60));
      console.log(`
   SELECT enumlabel as enum_value
   FROM pg_type t 
   JOIN pg_enum e ON t.oid = e.enumtypid  
   WHERE t.typname = 'user_type_enum'
   ORDER BY e.enumsortorder;
      `);
      console.log('   ' + '-'.repeat(60));
    } else if (enumData) {
      enumData.forEach(row => {
        console.log(`   ✓ ${row.enum_value}`);
      });
    }

    // Query 2: Check actual user_type values in users table
    console.log('\n2️⃣ Checking actual user_type values in users table:');
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('user_type')
      .limit(1000);

    if (userError) {
      console.error('   ❌ Error:', userError.message);
    } else {
      const uniqueTypes = [...new Set(userData.map(u => u.user_type))].filter(Boolean);
      uniqueTypes.forEach(type => {
        console.log(`   ✓ ${type}`);
      });
      console.log(`\n   Total users: ${userData.length}`);
      console.log(`   Unique user types: ${uniqueTypes.length}`);
    }

    // Query 3: Check users table structure
    console.log('\n3️⃣ Checking users table columns related to type/role:');
    const { data: columnsData, error: columnsError } = await supabase
      .rpc('exec_sql', {
        query: `
          SELECT column_name, data_type, udt_name
          FROM information_schema.columns
          WHERE table_name = 'users' 
          AND (column_name LIKE '%type%' OR column_name LIKE '%role%')
          ORDER BY ordinal_position;
        `
      });

    if (columnsError) {
      console.log('   Note: Run this query in Supabase SQL Editor:');
      console.log('   ' + '-'.repeat(60));
      console.log(`
   SELECT column_name, data_type, udt_name
   FROM information_schema.columns
   WHERE table_name = 'users' 
   AND (column_name LIKE '%type%' OR column_name LIKE '%role%')
   ORDER BY ordinal_position;
      `);
      console.log('   ' + '-'.repeat(60));
    } else if (columnsData) {
      columnsData.forEach(col => {
        console.log(`   ✓ ${col.column_name}: ${col.data_type} (${col.udt_name})`);
      });
    }

    // Query 4: Sample users with their types
    console.log('\n4️⃣ Sample users with their user_type:');
    const { data: sampleUsers, error: sampleError } = await supabase
      .from('users')
      .select('id, full_name, user_type')
      .order('created_at', { ascending: false })
      .limit(5);

    if (sampleError) {
      console.error('   ❌ Error:', sampleError.message);
    } else {
      sampleUsers.forEach(user => {
        console.log(`   • ${user.full_name}: ${user.user_type}`);
      });
    }

    console.log('\n✅ Check complete!');
    console.log('\n💡 Based on the results above, update the SQL policy to use the correct enum values.');
    console.log('   Common enum values are usually: "employee", "manager", "admin", "master_admin"');

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

checkUserTypeEnum();
