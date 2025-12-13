const OpenAI = require('openai');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const categories = [
  "Baking",
  "Bath Soap",
  "Biscuits",
  "Body Care",
  "Body Wash",
  "Breakfast Cereals",
  "Cake Mixes",
  "Canned Food",
  "Canned Seafood",
  "Cheese",
  "Chips",
  "Coffee",
  "Coffee Mixes",
  "Concentrated Drinks",
  "Condiments",
  "Cooking Fats",
  "Cooking Oil",
  "Creams",
  "Deodorants & Fragrances",
  "Dessert Mix",
  "Dishwashing",
  "Disinfectants",
  "Disposable",
  "Drain Care",
  "Dry Fruits",
  "Fabric Care",
  "Fabric Softener",
  "Fast Food",
  "Feminine Hygiene",
  "Flavored Milk",
  "Floor Care",
  "Flour",
  "Food Packaging",
  "Frozen Foods",
  "Fruit Jams",
  "Grains",
  "Hair Care",
  "Hand Wash",
  "Honey",
  "Instant Noodles",
  "Juice",
  "Kitchen Appliances",
  "Laundry Additives",
  "Laundry Detergents",
  "Milk",
  "Milk Powder",
  "Nut Butters",
  "Oils",
  "Outdoor/BBQ",
  "Packaged Cakes",
  "Paper Products",
  "Pasta",
  "Pest Control",
  "Poultry",
  "Powdered Drinks",
  "Rice",
  "Skincare",
  "Spices & Seasonings",
  "Spreads",
  "Stocks & Bouillon",
  "Sugar",
  "Sugar Alternatives",
  "Surface Cleaners",
  "Tea",
  "Tea Mixes",
  "Wafers",
  "Water"
];

async function translateCategories() {
  console.log('🌐 Translating 67 categories to Arabic using OpenAI...\n');
  
  const prompt = `Translate these grocery product category names from English to Arabic. Return ONLY a JSON array with objects containing "english" and "arabic" keys. Keep translations concise and appropriate for grocery store categories.

Categories:
${categories.map((cat, i) => `${i + 1}. ${cat}`).join('\n')}

Return format:
[
  {"english": "Baking", "arabic": "الخبز"},
  ...
]`;

  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: 'You are a professional translator specializing in grocery and retail product categories. Translate to Modern Standard Arabic used in Gulf countries.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3
    });

    const content = response.choices[0].message.content;
    const translations = JSON.parse(content.replace(/```json\n?|\n?```/g, ''));
    
    console.log('✅ Translation complete!\n');
    console.log('='.repeat(80));
    console.log('\nTRANSLATIONS:\n');
    
    translations.forEach((item, i) => {
      console.log(`${i + 1}. ${item.english.padEnd(30)} => ${item.arabic}`);
    });
    
    console.log('\n' + '='.repeat(80));
    console.log('\n📋 SQL INSERT statements:\n');
    
    translations.forEach((item, i) => {
      const id = i + 1;
      const nameEn = item.english.replace(/'/g, "''");
      const nameAr = item.arabic.replace(/'/g, "''");
      console.log(`INSERT INTO product_categories (id, name_en, name_ar, display_order, is_active) VALUES (${id}, '${nameEn}', '${nameAr}', ${id}, true);`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

translateCategories();
