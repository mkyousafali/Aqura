// Run this in the browser console to check vendor count for branch ID 3
console.log('🔍 Checking vendor count for branch ID 3...');

// Using the existing supabase client from the app
supabase
  .from('vendors')
  .select('erp_vendor_id', { count: 'exact' })
  .eq('branch_id', 3)
  .then(({ data, error, count }) => {
    if (error) {
      console.error('❌ Error:', error);
    } else {
      console.log(`✅ Total vendors for branch ID 3: ${count}`);
      console.log(`📊 First few vendor IDs:`, data?.slice(0, 10).map(v => v.erp_vendor_id));
    }
  });

// Also check total vendor count without branch filter
supabase
  .from('vendors')
  .select('erp_vendor_id', { count: 'exact' })
  .then(({ data, error, count }) => {
    if (error) {
      console.error('❌ Error:', error);
    } else {
      console.log(`✅ Total vendors in database: ${count}`);
    }
  });

// Check vendor count by all branches
supabase
  .from('vendors')
  .select('branch_id')
  .then(({ data, error }) => {
    if (error) {
      console.error('❌ Error:', error);
    } else {
      const branchCounts = data.reduce((acc, vendor) => {
        const branchId = vendor.branch_id || 'null';
        acc[branchId] = (acc[branchId] || 0) + 1;
        return acc;
      }, {});
      console.log('📊 Vendor count by branch:', branchCounts);
    }
  });