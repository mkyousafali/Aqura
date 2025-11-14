// Test the products-with-offers API endpoint
const branchId = '67890123-4567-89ab-cdef-0123456789ab'; // Replace with actual branch ID
const serviceType = 'delivery';

console.log('\n🧪 Testing /api/customer/products-with-offers endpoint\n');
console.log('='.repeat(60));

fetch(`http://localhost:5173/api/customer/products-with-offers?branchId=${branchId}&serviceType=${serviceType}`)
  .then(response => response.json())
  .then(data => {
    console.log(`\n✅ API Response received:`);
    console.log(`   Total products: ${data.products?.length || 0}`);
    console.log(`   Active offers: ${data.offersCount || 0}`);
    
    const productsWithOffers = (data.products || []).filter(p => p.hasOffer);
    console.log(`   Products with offers: ${productsWithOffers.length}`);
    
    if (productsWithOffers.length > 0) {
      console.log('\n📋 Products with offers:');
      console.log('-'.repeat(60));
      productsWithOffers.forEach(p => {
        console.log(`\n   ${p.nameEn} (${p.nameAr})`);
        console.log(`   Original: ${p.originalPrice} SAR → Offer: ${p.offerPrice} SAR`);
        console.log(`   Savings: ${p.savings} SAR (${p.discountPercentage}% OFF)`);
        console.log(`   Offer Type: ${p.offerType}`);
        console.log(`   Has Offer: ${p.hasOffer}`);
      });
    } else {
      console.log('\n⚠️  No products with offers found in API response');
    }
    
    console.log('\n' + '='.repeat(60));
  })
  .catch(error => {
    console.error('❌ Error calling API:', error.message);
  });
