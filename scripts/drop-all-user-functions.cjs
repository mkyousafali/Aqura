const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function dropAllCreateUserFunctions() {
  console.log('🔍 Attempting to drop all create_user functions...\n');

  // Try different signatures
  const signatures = [
    'create_user(character varying, character varying, character varying, character varying, integer, character varying, character varying, character varying)',
    'create_user(varchar, varchar, varchar, varchar, integer, varchar, varchar, varchar)',
    'create_user(text, text, text, text, integer, text, text, text)',
    'create_user(character varying, character varying, character varying, character varying, integer, character varying, character varying)',
    'create_user(varchar, varchar, varchar, varchar, integer, varchar, varchar)',
  ];

  for (const sig of signatures) {
    console.log(`Trying: DROP FUNCTION IF EXISTS ${sig} CASCADE;`);
    const { error } = await supabase.rpc('exec_sql', {
      sql: `DROP FUNCTION IF EXISTS ${sig} CASCADE;`
    }).single();
    
    if (error && !error.message.includes('does not exist')) {
      console.log(`  ⚠️  Error: ${error.message}`);
    } else if (!error) {
      console.log(`  ✅ Dropped successfully`);
    } else {
      console.log(`  ℹ️  Function does not exist`);
    }
  }

  // Try a more aggressive approach - drop by name pattern
  console.log('\n🔨 Trying aggressive drop using DO block...');
  const doBlock = `
DO $$ 
DECLARE 
  func_name text;
BEGIN
  FOR func_name IN 
    SELECT oid::regprocedure::text 
    FROM pg_proc 
    WHERE proname IN ('create_user', 'update_user') 
      AND pg_function_is_visible(oid)
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || func_name || ' CASCADE';
    RAISE NOTICE 'Dropped: %', func_name;
  END LOOP;
END $$;
  `;

  console.log('Executing DO block to drop all versions...');
  const { error: doError } = await supabase.rpc('exec_sql', {
    sql: doBlock
  }).single();

  if (doError) {
    console.log(`❌ Error: ${doError.message}`);
  } else {
    console.log('✅ DO block executed successfully');
  }

  console.log('\n✅ Process complete. Try running your CREATE statements now.');
}

dropAllCreateUserFunctions().catch(console.error);
