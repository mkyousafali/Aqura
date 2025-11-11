import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const env = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      env[match[1].trim()] = match[2].trim();
    }
  }
});

const supabase = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_SERVICE_ROLE_KEY);

console.log('\n📊 Checking Offer Types...\n');
console.log('='.repeat(80));

const { data, error } = await supabase
  .from('offers')
  .select('type, name_en, name_ar');

if (error) {
  console.error('Error:', error);
  process.exit(1);
}

// Group by type
const types = {};
data.forEach(offer => {
  if (!types[offer.type]) {
    types[offer.type] = [];
  }
  types[offer.type].push({
    name_en: offer.name_en,
    name_ar: offer.name_ar
  });
});

console.log('\n🏷️  Offer Types in Database:\n');

Object.keys(types).sort().forEach(type => {
  console.log(`\n📦 ${type.toUpperCase()}`);
  console.log(`   Count: ${types[type].length} offers`);
  console.log('   Examples:');
  types[type].slice(0, 3).forEach(offer => {
    console.log(`   - ${offer.name_en}`);
    console.log(`     ${offer.name_ar}`);
  });
});

console.log('\n' + '='.repeat(80));
console.log('\n📈 Summary:\n');
console.log(`   Total unique offer types: ${Object.keys(types).length}`);

const productRelated = ['product', 'bogo', 'bundle'].filter(t => types[t]);
const cartRelated = ['cart', 'min_purchase', 'customer'].filter(t => types[t]);

console.log(`\n   🎯 Product-Related Types: ${productRelated.length}`);
productRelated.forEach(type => {
  console.log(`      - ${type} (${types[type].length} offers)`);
});

console.log(`\n   🛒 Cart-Related Types: ${cartRelated.length}`);
cartRelated.forEach(type => {
  console.log(`      - ${type} (${types[type].length} offers)`);
});

console.log('\n' + '='.repeat(80));
console.log('\n💡 Note:');
console.log('   - Product-related: One product = one offer (exclusive)');
console.log('   - Cart-related: No product restrictions, can use tier system');
console.log('');
