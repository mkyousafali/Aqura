const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://supabase.urbanaqura.com',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRhaWdraHNicWxnZGJlaW1mbGp1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyMzkwNzUyOCwiZXhwIjoyMDM5NDgzNTI4fQ.JmRxFYpgWdG-4bhVbD-x5y_X7nJ1TFXzPQNdHR7oH8A'
);

async function findForeignKeys() {
  console.log('🔍 FINDING FOREIGN KEYS TO flyer_products.id\n');
  console.log('=' .repeat(80));

  const query = `
    SELECT 
      tc.table_name,
      kcu.column_name,
      tc.constraint_name,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' 
      AND ccu.table_name = 'flyer_products'
      AND ccu.column_name = 'id'
      AND tc.table_schema = 'public'
  `;

  const { data, error } = await supabase.rpc('exec_sql', { query });

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  if (!data || data.length === 0) {
    console.log('✅ No foreign keys found referencing flyer_products.id');
  } else {
    console.log('⚠️  FOUND FOREIGN KEYS:\n');
    data.forEach((fk, i) => {
      console.log(`${i + 1}. Table: ${fk.table_name}`);
      console.log(`   Column: ${fk.column_name}`);
      console.log(`   Constraint: ${fk.constraint_name}`);
      console.log(`   References: ${fk.foreign_table_name}.${fk.foreign_column_name}\n`);
    });
  }

  console.log('=' .repeat(80));
}

findForeignKeys().catch(console.error);
