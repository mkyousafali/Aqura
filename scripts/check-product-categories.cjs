const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkProductCategories() {
  console.log('🔍 ANALYZING product_categories TABLE\n');
  console.log('='.repeat(80));
  
  // Get table structure
  const { data: categories, error } = await supabase
    .from('product_categories')
    .select('*')
    .limit(10);
  
  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }
  
  console.log('\n📊 Table Structure (sample data):');
  if (categories && categories.length > 0) {
    console.log('Columns:', Object.keys(categories[0]));
    console.log('\nSample records:');
    categories.forEach((cat, i) => {
      console.log(`\n${i + 1}.`, JSON.stringify(cat, null, 2));
    });
  }
  
  // Count total categories
  const { count } = await supabase
    .from('product_categories')
    .select('*', { count: 'exact', head: true });
  
  console.log('\n📋 Total categories:', count);
  
  // Get all category names
  const { data: allCategories } = await supabase
    .from('product_categories')
    .select('*')
    .order('id');
  
  if (allCategories) {
    console.log('\n📋 ALL CATEGORIES:');
    allCategories.forEach((cat, i) => {
      const nameField = cat.category_name || cat.name || cat.category_name_en || 'N/A';
      console.log(`${i + 1}. ID: ${cat.id} | Name: ${nameField}`);
    });
  }
  
  console.log('\n' + '='.repeat(80));
  
  // Compare with flyer_products parent_sub_category
  const { data: flyerCategories } = await supabase
    .from('flyer_products')
    .select('parent_sub_category')
    .order('parent_sub_category');
  
  if (flyerCategories) {
    const uniqueParentSubCategories = [...new Set(flyerCategories.map(f => f.parent_sub_category))];
    console.log('\n📊 COMPARISON:');
    console.log(`product_categories table: ${count} categories`);
    console.log(`flyer_products unique parent_sub_category: ${uniqueParentSubCategories.length} categories`);
    
    console.log('\n🔄 Categories to migrate (from flyer_products):');
    uniqueParentSubCategories.forEach((cat, i) => {
      console.log(`${i + 1}. "${cat}"`);
    });
  }
}

checkProductCategories().catch(console.error);
