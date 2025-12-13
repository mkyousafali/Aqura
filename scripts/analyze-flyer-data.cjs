/**
 * Analyze flyer_products parent_sub_category data
 * Check unique values and distribution
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function analyzeParentSubCategory() {
  console.log('🔍 ANALYZING flyer_products.parent_sub_category\n');
  console.log('='.repeat(80));

  try {
    // Get all parent_sub_category values
    const { data, error } = await supabase
      .from('flyer_products')
      .select('parent_sub_category, parent_category, sub_category');

    if (error) {
      console.error('❌ Error:', error);
      return;
    }

    console.log(`\n📊 Total products: ${data.length}`);

    // Count unique parent_sub_category values
    const parentSubCategorySet = new Set();
    const parentCategorySet = new Set();
    const subCategorySet = new Set();
    const categoryStats = {};

    data.forEach(row => {
      if (row.parent_sub_category) {
        parentSubCategorySet.add(row.parent_sub_category);
        
        if (!categoryStats[row.parent_sub_category]) {
          categoryStats[row.parent_sub_category] = {
            count: 0,
            parent_categories: new Set(),
            sub_categories: new Set()
          };
        }
        categoryStats[row.parent_sub_category].count++;
        if (row.parent_category) {
          categoryStats[row.parent_sub_category].parent_categories.add(row.parent_category);
        }
        if (row.sub_category) {
          categoryStats[row.parent_sub_category].sub_categories.add(row.sub_category);
        }
      }
      if (row.parent_category) parentCategorySet.add(row.parent_category);
      if (row.sub_category) subCategorySet.add(row.sub_category);
    });

    console.log(`\n📋 Unique parent_sub_category values: ${parentSubCategorySet.size}`);
    console.log(`📋 Unique parent_category values: ${parentCategorySet.size}`);
    console.log(`📋 Unique sub_category values: ${subCategorySet.size}`);

    console.log('\n' + '='.repeat(80));
    console.log('📊 PARENT_SUB_CATEGORY DISTRIBUTION:\n');

    const sortedCategories = Object.entries(categoryStats)
      .sort((a, b) => b[1].count - a[1].count);

    sortedCategories.forEach(([category, stats], index) => {
      console.log(`${index + 1}. "${category}"`);
      console.log(`   Products: ${stats.count}`);
      console.log(`   Parent categories: ${Array.from(stats.parent_categories).join(', ')}`);
      console.log(`   Sub categories: ${Array.from(stats.sub_categories).join(', ')}`);
      console.log('');
    });

    console.log('='.repeat(80));
    console.log('\n📋 ALL UNIQUE PARENT_SUB_CATEGORY VALUES:\n');
    Array.from(parentSubCategorySet).sort().forEach((val, i) => {
      console.log(`${i + 1}. "${val}"`);
    });

    console.log('\n' + '='.repeat(80));
    console.log('\n📋 ALL UNIQUE PARENT_CATEGORY VALUES:\n');
    Array.from(parentCategorySet).sort().forEach((val, i) => {
      console.log(`${i + 1}. "${val}"`);
    });

    console.log('\n' + '='.repeat(80));
    console.log('\n📋 ALL UNIQUE SUB_CATEGORY VALUES:\n');
    Array.from(subCategorySet).sort().forEach((val, i) => {
      console.log(`${i + 1}. "${val}"`);
    });

    console.log('\n' + '='.repeat(80));

  } catch (error) {
    console.error('❌ Analysis failed:', error);
  }
}

analyzeParentSubCategory();
