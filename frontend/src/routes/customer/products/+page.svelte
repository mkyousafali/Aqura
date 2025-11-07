<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { cartActions, cartStore } from '$lib/stores/cart.js';
  import { scrollingContent, scrollingContentActions } from '$lib/stores/scrollingContent.js';
  
  let currentLanguage = 'ar';
  let searchQuery = '';
  let selectedCategory = 'all';
  let selectedUnits = new Map();
  let categoryTabsContainer;
  let isScrolling = false;
  
  // Reactive cart items for quantity display
  $: cartItems = $cartStore;
  $: cartItemsMap = new Map(cartItems.map(item => [
    `${item.id}-${item.selectedUnit?.id || 'base'}`, 
    item.quantity
  ]));

  // Function to get item quantity from reactive cart
  function getItemQuantity(product) {
    const selectedUnit = getSelectedUnit(product);
    const key = `${product.id}-${selectedUnit.id}`;
    return cartItemsMap.get(key) || 0;
  }

  // Subscribe to scrolling content store
  $: currentScrollingContent = $scrollingContent;
  $: activeScrollingTexts = scrollingContentActions.getActiveContent(currentScrollingContent, currentLanguage);

  // Sample products data (you can replace this with real data from your API)
  const products = [
    // Water Products
    {
      id: 1,
      nameAr: 'مياه معدنية طبيعية',
      nameEn: 'Natural Mineral Water',
      image: null,
      basePrice: 5.50,
      originalPrice: 7.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل زجاجة',
        nameEn: '500ml Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 5.50,
        originalPrice: 7.00,
        stock: 100,
        lowStockThreshold: 10,
        barcode: '123456789001'
      },
      additionalUnits: [
        {
          id: 'pack6',
          nameAr: 'عبوة 6 زجاجات',
          nameEn: '6-pack',
          unitAr: 'عبوة',
          unitEn: 'pack',
          basePrice: 30.00,
          originalPrice: 36.00,
          stock: 25,
          lowStockThreshold: 5,
          barcode: '123456789002'
        }
      ],
      category: 'water'
    },
    {
      id: 2,
      nameAr: 'مياه شرب نقية',
      nameEn: 'Pure Drinking Water',
      image: null,
      basePrice: 3.50,
      originalPrice: 4.50,
      baseUnit: {
        id: 'base',
        nameAr: '1.5 لتر',
        nameEn: '1.5 Liter',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 3.50,
        originalPrice: 4.50,
        stock: 200,
        lowStockThreshold: 20,
        barcode: '123456789003'
      },
      category: 'water'
    },

    // Juice Products
    {
      id: 3,
      nameAr: 'عصير برتقال طبيعي',
      nameEn: 'Fresh Orange Juice',
      image: null,
      basePrice: 8.75,
      originalPrice: 10.00,
      baseUnit: {
        id: 'base',
        nameAr: '1 لتر',
        nameEn: '1 Liter',
        unitAr: 'لتر',
        unitEn: 'liter',
        basePrice: 8.75,
        originalPrice: 10.00,
        stock: 50,
        lowStockThreshold: 10,
        barcode: '123456789004'
      },
      category: 'juice'
    },
    {
      id: 4,
      nameAr: 'عصير تفاح طازج',
      nameEn: 'Fresh Apple Juice',
      image: null,
      basePrice: 9.25,
      originalPrice: 11.00,
      baseUnit: {
        id: 'base',
        nameAr: '1 لتر',
        nameEn: '1 Liter',
        unitAr: 'لتر',
        unitEn: 'liter',
        basePrice: 9.25,
        originalPrice: 11.00,
        stock: 35,
        lowStockThreshold: 8,
        barcode: '123456789005'
      },
      category: 'juice'
    },
    {
      id: 5,
      nameAr: 'عصير مانجو استوائي',
      nameEn: 'Tropical Mango Juice',
      image: null,
      basePrice: 12.50,
      originalPrice: 15.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل',
        nameEn: '500ml',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 12.50,
        originalPrice: 15.00,
        stock: 40,
        lowStockThreshold: 10,
        barcode: '123456789006'
      },
      category: 'juice'
    },

    // Coffee Products
    {
      id: 6,
      nameAr: 'قهوة عربية فاخرة',
      nameEn: 'Premium Arabic Coffee',
      image: null,
      basePrice: 25.00,
      originalPrice: 30.00,
      baseUnit: {
        id: 'base',
        nameAr: '250غم',
        nameEn: '250g',
        unitAr: 'غرام',
        unitEn: 'gram',
        basePrice: 25.00,
        originalPrice: 30.00,
        stock: 30,
        lowStockThreshold: 5,
        barcode: '123456789007'
      },
      category: 'coffee'
    },
    {
      id: 7,
      nameAr: 'قهوة إسبريسو إيطالية',
      nameEn: 'Italian Espresso Coffee',
      image: null,
      basePrice: 45.00,
      originalPrice: 50.00,
      baseUnit: {
        id: 'base',
        nameAr: '500غم',
        nameEn: '500g',
        unitAr: 'غرام',
        unitEn: 'gram',
        basePrice: 45.00,
        originalPrice: 50.00,
        stock: 15,
        lowStockThreshold: 3,
        barcode: '123456789008'
      },
      category: 'coffee'
    },
    {
      id: 8,
      nameAr: 'قهوة باردة جاهزة',
      nameEn: 'Ready-to-Drink Cold Coffee',
      image: null,
      basePrice: 8.50,
      baseUnit: {
        id: 'base',
        nameAr: '250مل',
        nameEn: '250ml',
        unitAr: 'علبة',
        unitEn: 'can',
        basePrice: 8.50,
        stock: 80,
        lowStockThreshold: 15,
        barcode: '123456789009'
      },
      category: 'coffee'
    },

    // Tea Products
    {
      id: 9,
      nameAr: 'شاي أخضر ياباني',
      nameEn: 'Japanese Green Tea',
      image: null,
      basePrice: 18.00,
      originalPrice: 22.00,
      baseUnit: {
        id: 'base',
        nameAr: '100غم',
        nameEn: '100g',
        unitAr: 'علبة',
        unitEn: 'box',
        basePrice: 18.00,
        originalPrice: 22.00,
        stock: 25,
        lowStockThreshold: 5,
        barcode: '123456789010'
      },
      category: 'tea'
    },
    {
      id: 10,
      nameAr: 'شاي أحمر إنجليزي',
      nameEn: 'English Black Tea',
      image: null,
      basePrice: 15.50,
      baseUnit: {
        id: 'base',
        nameAr: '20 كيس',
        nameEn: '20 Tea Bags',
        unitAr: 'علبة',
        unitEn: 'box',
        basePrice: 15.50,
        stock: 60,
        lowStockThreshold: 10,
        barcode: '123456789011'
      },
      category: 'tea'
    },

    // Energy Drinks
    {
      id: 11,
      nameAr: 'مشروب طاقة أحمر',
      nameEn: 'Red Energy Drink',
      image: null,
      basePrice: 12.00,
      originalPrice: 14.00,
      baseUnit: {
        id: 'base',
        nameAr: '250مل',
        nameEn: '250ml',
        unitAr: 'علبة',
        unitEn: 'can',
        basePrice: 12.00,
        originalPrice: 14.00,
        stock: 75,
        lowStockThreshold: 15,
        barcode: '123456789012'
      },
      category: 'energy'
    },
    {
      id: 12,
      nameAr: 'مشروب طاقة طبيعي',
      nameEn: 'Natural Energy Drink',
      image: null,
      basePrice: 15.50,
      baseUnit: {
        id: 'base',
        nameAr: '330مل',
        nameEn: '330ml',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 15.50,
        stock: 45,
        lowStockThreshold: 8,
        barcode: '123456789013'
      },
      category: 'energy'
    },

    // Soft Drinks
    {
      id: 13,
      nameAr: 'مشروب غازي كولا',
      nameEn: 'Cola Soft Drink',
      image: null,
      basePrice: 4.50,
      baseUnit: {
        id: 'base',
        nameAr: '330مل',
        nameEn: '330ml',
        unitAr: 'علبة',
        unitEn: 'can',
        basePrice: 4.50,
        stock: 150,
        lowStockThreshold: 30,
        barcode: '123456789014'
      },
      additionalUnits: [
        {
          id: 'pack12',
          nameAr: 'عبوة 12 علبة',
          nameEn: '12-pack',
          unitAr: 'عبوة',
          unitEn: 'pack',
          basePrice: 48.00,
          originalPrice: 54.00,
          stock: 20,
          lowStockThreshold: 5,
          barcode: '123456789015'
        }
      ],
      category: 'soft-drinks'
    },
    {
      id: 14,
      nameAr: 'مشروب غازي برتقال',
      nameEn: 'Orange Soft Drink',
      image: null,
      basePrice: 4.50,
      baseUnit: {
        id: 'base',
        nameAr: '330مل',
        nameEn: '330ml',
        unitAr: 'علبة',
        unitEn: 'can',
        basePrice: 4.50,
        stock: 120,
        lowStockThreshold: 25,
        barcode: '123456789016'
      },
      category: 'soft-drinks'
    },

    // Dairy Products
    {
      id: 15,
      nameAr: 'حليب طازج كامل الدسم',
      nameEn: 'Fresh Whole Milk',
      image: null,
      basePrice: 7.50,
      baseUnit: {
        id: 'base',
        nameAr: '1 لتر',
        nameEn: '1 Liter',
        unitAr: 'كرتون',
        unitEn: 'carton',
        basePrice: 7.50,
        stock: 85,
        lowStockThreshold: 20,
        barcode: '123456789017'
      },
      category: 'milk'
    },
    {
      id: 16,
      nameAr: 'لبن رائب طبيعي',
      nameEn: 'Natural Yogurt Drink',
      image: null,
      basePrice: 5.25,
      originalPrice: 6.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل',
        nameEn: '500ml',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 5.25,
        originalPrice: 6.00,
        stock: 95,
        lowStockThreshold: 18,
        barcode: '123456789018'
      },
      category: 'milk'
    },

    // Sports Drinks
    {
      id: 17,
      nameAr: 'مشروب رياضي أزرق',
      nameEn: 'Blue Sports Drink',
      image: null,
      basePrice: 8.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل',
        nameEn: '500ml',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 8.00,
        stock: 70,
        lowStockThreshold: 15,
        barcode: '123456789019'
      },
      category: 'sports'
    },
    {
      id: 18,
      nameAr: 'مشروب رياضي بنكهة البرتقال',
      nameEn: 'Orange Flavored Sports Drink',
      image: null,
      basePrice: 8.50,
      baseUnit: {
        id: 'base',
        nameAr: '600مل',
        nameEn: '600ml',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 8.50,
        stock: 55,
        lowStockThreshold: 12,
        barcode: '123456789020'
      },
      category: 'sports'
    },

    // Healthy Drinks
    {
      id: 19,
      nameAr: 'عصير أخضر صحي',
      nameEn: 'Healthy Green Juice',
      image: null,
      basePrice: 16.00,
      originalPrice: 19.00,
      baseUnit: {
        id: 'base',
        nameAr: '330مل',
        nameEn: '330ml',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 16.00,
        originalPrice: 19.00,
        stock: 30,
        lowStockThreshold: 8,
        barcode: '123456789021'
      },
      category: 'healthy'
    },
    {
      id: 20,
      nameAr: 'ماء جوز الهند الطبيعي',
      nameEn: 'Natural Coconut Water',
      image: null,
      basePrice: 12.50,
      baseUnit: {
        id: 'base',
        nameAr: '500مل',
        nameEn: '500ml',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 12.50,
        stock: 40,
        lowStockThreshold: 10,
        barcode: '123456789022'
      },
      category: 'healthy'
    },

    // Beverages (General)
    {
      id: 21,
      nameAr: 'مشروب منعش مختلط',
      nameEn: 'Refreshing Mixed Beverage',
      image: null,
      basePrice: 6.50,
      originalPrice: 8.00,
      baseUnit: {
        id: 'base',
        nameAr: '330مل علبة',
        nameEn: '330ml Can',
        unitAr: 'علبة',
        unitEn: 'can',
        basePrice: 6.50,
        originalPrice: 8.00,
        stock: 120,
        lowStockThreshold: 15,
        barcode: '123456789021'
      },
      category: 'beverages'
    },

    // Smoothies
    {
      id: 22,
      nameAr: 'سموذي المانجو والموز',
      nameEn: 'Mango Banana Smoothie',
      image: null,
      basePrice: 12.75,
      originalPrice: 15.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل زجاجة',
        nameEn: '500ml Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 12.75,
        originalPrice: 15.00,
        stock: 45,
        lowStockThreshold: 8,
        barcode: '123456789022'
      },
      category: 'smoothies'
    },
    {
      id: 23,
      nameAr: 'سموذي التوت الأزرق',
      nameEn: 'Blueberry Smoothie',
      image: null,
      basePrice: 13.25,
      originalPrice: 16.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل زجاجة',
        nameEn: '500ml Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 13.25,
        originalPrice: 16.00,
        stock: 38,
        lowStockThreshold: 8,
        barcode: '123456789023'
      },
      category: 'smoothies'
    },

    // Seasonal Drinks
    {
      id: 24,
      nameAr: 'مشروب القرفة الشتوي',
      nameEn: 'Winter Cinnamon Drink',
      image: null,
      basePrice: 9.50,
      originalPrice: 12.00,
      baseUnit: {
        id: 'base',
        nameAr: '400مل كوب',
        nameEn: '400ml Cup',
        unitAr: 'كوب',
        unitEn: 'cup',
        basePrice: 9.50,
        originalPrice: 12.00,
        stock: 60,
        lowStockThreshold: 10,
        barcode: '123456789024'
      },
      category: 'seasonal'
    },
    {
      id: 25,
      nameAr: 'مشروب البطيخ الصيفي',
      nameEn: 'Summer Watermelon Drink',
      image: null,
      basePrice: 8.25,
      originalPrice: 10.50,
      baseUnit: {
        id: 'base',
        nameAr: '500مل زجاجة',
        nameEn: '500ml Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 8.25,
        originalPrice: 10.50,
        stock: 75,
        lowStockThreshold: 12,
        barcode: '123456789025'
      },
      category: 'seasonal'
    },

    // Premium Drinks
    {
      id: 26,
      nameAr: 'مشروب الذهب الفاخر',
      nameEn: 'Premium Gold Beverage',
      image: null,
      basePrice: 25.00,
      originalPrice: 30.00,
      baseUnit: {
        id: 'base',
        nameAr: '750مل زجاجة فاخرة',
        nameEn: '750ml Premium Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 25.00,
        originalPrice: 30.00,
        stock: 20,
        lowStockThreshold: 5,
        barcode: '123456789026'
      },
      category: 'premium'
    },
    {
      id: 27,
      nameAr: 'مشروب الكافيار الفاخر',
      nameEn: 'Luxury Caviar Drink',
      image: null,
      basePrice: 35.50,
      originalPrice: 42.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل زجاجة مطلية بالذهب',
        nameEn: '500ml Gold-Plated Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 35.50,
        originalPrice: 42.00,
        stock: 15,
        lowStockThreshold: 3,
        barcode: '123456789027'
      },
      category: 'premium'
    },

    // Organic Drinks
    {
      id: 28,
      nameAr: 'عصير عضوي طبيعي',
      nameEn: 'Organic Natural Juice',
      image: null,
      basePrice: 14.75,
      originalPrice: 18.00,
      baseUnit: {
        id: 'base',
        nameAr: '1 لتر عضوي معتمد',
        nameEn: '1L Certified Organic',
        unitAr: 'لتر',
        unitEn: 'liter',
        basePrice: 14.75,
        originalPrice: 18.00,
        stock: 35,
        lowStockThreshold: 8,
        barcode: '123456789028'
      },
      category: 'organic'
    },
    {
      id: 29,
      nameAr: 'شاي أخضر عضوي',
      nameEn: 'Organic Green Tea',
      image: null,
      basePrice: 11.25,
      originalPrice: 14.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل زجاجة عضوية',
        nameEn: '500ml Organic Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 11.25,
        originalPrice: 14.00,
        stock: 50,
        lowStockThreshold: 10,
        barcode: '123456789029'
      },
      category: 'organic'
    },

    // Functional Drinks
    {
      id: 30,
      nameAr: 'مشروب تعزيز المناعة',
      nameEn: 'Immunity Booster Drink',
      image: null,
      basePrice: 16.50,
      originalPrice: 20.00,
      baseUnit: {
        id: 'base',
        nameAr: '300مل زجاجة طبية',
        nameEn: '300ml Medical Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 16.50,
        originalPrice: 20.00,
        stock: 40,
        lowStockThreshold: 8,
        barcode: '123456789030'
      },
      category: 'functional'
    },
    {
      id: 31,
      nameAr: 'مشروب تحسين التركيز',
      nameEn: 'Focus Enhancement Drink',
      image: null,
      basePrice: 18.75,
      originalPrice: 22.50,
      baseUnit: {
        id: 'base',
        nameAr: '250مل أمبولة',
        nameEn: '250ml Vial',
        unitAr: 'أمبولة',
        unitEn: 'vial',
        basePrice: 18.75,
        originalPrice: 22.50,
        stock: 25,
        lowStockThreshold: 5,
        barcode: '123456789031'
      },
      category: 'functional'
    },

    // International Drinks
    {
      id: 32,
      nameAr: 'مشروب ياباني تقليدي',
      nameEn: 'Traditional Japanese Drink',
      image: null,
      basePrice: 22.00,
      originalPrice: 26.00,
      baseUnit: {
        id: 'base',
        nameAr: '350مل زجاجة يابانية',
        nameEn: '350ml Japanese Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 22.00,
        originalPrice: 26.00,
        stock: 30,
        lowStockThreshold: 6,
        barcode: '123456789032'
      },
      category: 'international'
    },
    {
      id: 33,
      nameAr: 'مشروب إيطالي فاخر',
      nameEn: 'Luxury Italian Beverage',
      image: null,
      basePrice: 19.50,
      originalPrice: 24.00,
      baseUnit: {
        id: 'base',
        nameAr: '500مل زجاجة إيطالية',
        nameEn: '500ml Italian Bottle',
        unitAr: 'زجاجة',
        unitEn: 'bottle',
        basePrice: 19.50,
        originalPrice: 24.00,
        stock: 42,
        lowStockThreshold: 8,
        barcode: '123456789033'
      },
      category: 'international'
    },

    // Hot Beverages
    {
      id: 34,
      nameAr: 'شوكولاتة ساخنة فاخرة',
      nameEn: 'Premium Hot Chocolate',
      image: null,
      basePrice: 13.50,
      originalPrice: 16.50,
      baseUnit: {
        id: 'base',
        nameAr: '400مل كوب ساخن',
        nameEn: '400ml Hot Cup',
        unitAr: 'كوب',
        unitEn: 'cup',
        basePrice: 13.50,
        originalPrice: 16.50,
        stock: 55,
        lowStockThreshold: 10,
        barcode: '123456789034'
      },
      category: 'hot-beverages'
    },
    {
      id: 35,
      nameAr: 'قهوة تركية أصيلة',
      nameEn: 'Authentic Turkish Coffee',
      image: null,
      basePrice: 12.25,
      originalPrice: 15.00,
      baseUnit: {
        id: 'base',
        nameAr: '200مل فنجان تركي',
        nameEn: '200ml Turkish Cup',
        unitAr: 'فنجان',
        unitEn: 'cup',
        basePrice: 12.25,
        originalPrice: 15.00,
        stock: 48,
        lowStockThreshold: 9,
        barcode: '123456789035'
      },
      category: 'hot-beverages'
    },

    // Cold Beverages
    {
      id: 36,
      nameAr: 'مشروب الثلج المنعش',
      nameEn: 'Refreshing Ice Drink',
      image: null,
      basePrice: 7.75,
      originalPrice: 9.50,
      baseUnit: {
        id: 'base',
        nameAr: '500مل كوب مثلج',
        nameEn: '500ml Iced Cup',
        unitAr: 'كوب',
        unitEn: 'cup',
        basePrice: 7.75,
        originalPrice: 9.50,
        stock: 80,
        lowStockThreshold: 15,
        barcode: '123456789036'
      },
      category: 'cold-beverages'
    },
    {
      id: 37,
      nameAr: 'عصير ليمونادة باردة',
      nameEn: 'Cold Lemonade',
      image: null,
      basePrice: 6.25,
      originalPrice: 8.00,
      baseUnit: {
        id: 'base',
        nameAr: '600مل كوب بارد',
        nameEn: '600ml Cold Cup',
        unitAr: 'كوب',
        unitEn: 'cup',
        basePrice: 6.25,
        originalPrice: 8.00,
        stock: 95,
        lowStockThreshold: 18,
        barcode: '123456789037'
      },
      category: 'cold-beverages'
    }
  ];

  // Initialize selected units with first unit of each product
  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }

    // Listen for language changes
    const handleStorageChange = (event) => {
      if (event.key === 'language') {
        currentLanguage = event.newValue || 'ar';
      }
    };
    
    window.addEventListener('storage', handleStorageChange);

    // Check for category parameter in URL
    const urlParams = new URLSearchParams(window.location.search);
    const categoryParam = urlParams.get('category');
    if (categoryParam) {
      selectedCategory = categoryParam;
    }

    // Initialize selected units
    products.forEach(product => {
      selectedUnits.set(product.id, product.baseUnit);
    });
    selectedUnits = selectedUnits; // Trigger reactivity

    // Initialize selected units
    products.forEach(product => {
      selectedUnits.set(product.id, product.baseUnit);
    });
    selectedUnits = selectedUnits; // Trigger reactivity

    // Initialize selected units
    products.forEach(product => {
      selectedUnits.set(product.id, product.baseUnit);
    });
    selectedUnits = selectedUnits; // Trigger reactivity

    // Only log for debugging - no custom handlers
    if (categoryTabsContainer) {
      console.log('Container width:', categoryTabsContainer.clientWidth);
      console.log('Content width:', categoryTabsContainer.scrollWidth);
      console.log('Can scroll:', categoryTabsContainer.scrollWidth > categoryTabsContainer.clientWidth);
      
      // Simple scroll test to verify scrollbar works
      categoryTabsContainer.addEventListener('scroll', () => {
        console.log('Scrolled to position:', categoryTabsContainer.scrollLeft);
      });
    }

    // Cleanup event listener
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  });

  function selectCategory(categoryId) {
    selectedCategory = categoryId;
    
    // Auto-scroll the selected tab into view
    if (categoryTabsContainer) {
      const activeTab = categoryTabsContainer.querySelector('.category-tab.active');
      if (activeTab) {
        activeTab.scrollIntoView({ 
          behavior: 'smooth', 
          block: 'nearest',
          inline: 'center'
        });
      }
    }
  }

  // Navigation functions like Urban-Express
  function scrollLeft() {
    if (categoryTabsContainer) {
      categoryTabsContainer.scrollBy({
        left: -200,
        behavior: 'smooth'
      });
    }
  }

  function scrollRight() {
    if (categoryTabsContainer) {
      categoryTabsContainer.scrollBy({
        left: 200,
        behavior: 'smooth'
      });
    }
  }

  // Get selected unit for a product
  function getSelectedUnit(product) {
    const selectedUnitId = selectedUnits.get(product.id);
    
    if (!selectedUnitId || selectedUnitId === product.baseUnit) {
      return product.baseUnit;
    }
    
    if (product.additionalUnits) {
      const foundUnit = product.additionalUnits.find(unit => unit.id === selectedUnitId);
      if (foundUnit) return foundUnit;
    }
    
    return product.baseUnit;
  }

  // Filter products based on search and category
  $: filteredProducts = products.filter(product => {
    const matchesSearch = !searchQuery || 
      product.nameAr.toLowerCase().includes(searchQuery.toLowerCase()) ||
      product.nameEn.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesCategory = selectedCategory === 'all' || product.category === selectedCategory;
    
    return matchesSearch && matchesCategory;
  });

  // Categories for filtering
  const categories = [
    { id: 'all', nameAr: 'الكل', nameEn: 'All' },
    { id: 'beverages', nameAr: 'المشروبات', nameEn: 'Beverages' },
    { id: 'water', nameAr: 'المياه', nameEn: 'Water' },
    { id: 'juice', nameAr: 'العصائر', nameEn: 'Juices' },
    { id: 'coffee', nameAr: 'القهوة', nameEn: 'Coffee' },
    { id: 'tea', nameAr: 'الشاي', nameEn: 'Tea' },
    { id: 'energy', nameAr: 'مشروبات الطاقة', nameEn: 'Energy Drinks' },
    { id: 'soft-drinks', nameAr: 'المشروبات الغازية', nameEn: 'Soft Drinks' },
    { id: 'milk', nameAr: 'منتجات الألبان', nameEn: 'Dairy Products' },
    { id: 'smoothies', nameAr: 'العصائر المخلوطة', nameEn: 'Smoothies' },
    { id: 'sports', nameAr: 'المشروبات الرياضية', nameEn: 'Sports Drinks' },
    { id: 'healthy', nameAr: 'المشروبات الصحية', nameEn: 'Healthy Drinks' },
    { id: 'seasonal', nameAr: 'المشروبات الموسمية', nameEn: 'Seasonal Drinks' },
    { id: 'premium', nameAr: 'المشروبات الممتازة', nameEn: 'Premium Drinks' },
    { id: 'organic', nameAr: 'المشروبات العضوية', nameEn: 'Organic Drinks' },
    { id: 'functional', nameAr: 'المشروبات الوظيفية', nameEn: 'Functional Drinks' },
    { id: 'international', nameAr: 'المشروبات العالمية', nameEn: 'International Drinks' },
    { id: 'hot-beverages', nameAr: 'المشروبات الساخنة', nameEn: 'Hot Beverages' },
    { id: 'cold-beverages', nameAr: 'المشروبات الباردة', nameEn: 'Cold Beverages' }
  ];

  function addToCart(product) {
    const selectedUnit = getSelectedUnit(product);
    cartActions.addToCart(product, selectedUnit, 1);
  }

  function updateQuantity(product, change) {
    const selectedUnit = getSelectedUnit(product);
    const currentQuantity = cartActions.getItemQuantity(product.id, selectedUnit.id);
    const newQuantity = Math.max(0, currentQuantity + change);
    
    if (newQuantity === 0) {
      cartActions.removeFromCart(product.id, selectedUnit.id);
    } else {
      cartActions.updateQuantity(product.id, selectedUnit.id, newQuantity);
    }
  }

  // Language texts
  $: texts = currentLanguage === 'ar' ? {
    title: 'المنتجات - أكوا إكسبرس',
    search: 'البحث في المنتجات...',
    addToCart: 'أضف للسلة',
    sar: 'ر.س',
    inStock: 'متوفر',
    lowStock: 'كمية قليلة',
    outOfStock: 'نفد المخزون'
  } : {
    title: 'Products - Aqua Express',
    search: 'Search products...',
    addToCart: 'Add to Cart',
    sar: 'SAR',
    inStock: 'In Stock',
    lowStock: 'Low Stock',
    outOfStock: 'Out of Stock'
  };
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="products-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Search and Filters -->
  <div class="search-section">
    <div class="search-bar">
      <input 
        type="text" 
        placeholder={texts.search}
        bind:value={searchQuery}
        class="search-input"
      />
      <span class="search-icon">🔍</span>
    </div>
    
    <!-- Category Filter -->
    <div class="category-filter">
      <div class="category-container">
        <button class="nav-button nav-left" on:click={scrollLeft} aria-label="Scroll left">
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <path d="M12 16L6 10L12 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </button>
        
        <div class="category-tabs" bind:this={categoryTabsContainer}>
          {#each categories as category}
            <button 
              class="category-tab" 
              class:active={selectedCategory === category.id}
              on:click={() => {
                console.log('Category clicked:', category.id);
                selectedCategory = category.id;
              }}
              type="button"
              role="tab"
              aria-selected={selectedCategory === category.id}
            >
              {currentLanguage === 'ar' ? category.nameAr : category.nameEn}
            </button>
          {/each}
        </div>
        
        <button class="nav-button nav-right" on:click={scrollRight} aria-label="Scroll right">
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <path d="M8 4L14 10L8 16" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </button>
      </div>
    </div>
  </div>

  <!-- Products Grid -->
  <div class="products-grid">
    {#each filteredProducts as product}
      {#key $cartStore}
        {@const selectedUnit = getSelectedUnit(product)}
        {@const quantity = getItemQuantity(product)}
        {@const hasDiscount = selectedUnit.originalPrice && selectedUnit.originalPrice > selectedUnit.basePrice}
        {@const isLowStock = selectedUnit.stock <= selectedUnit.lowStockThreshold}
      {@const isOutOfStock = selectedUnit.stock === 0}
      
      <div class="product-card">
        <!-- Product Image -->
        <div class="product-image">
          {#if product.image}
            <img src={product.image} alt={currentLanguage === 'ar' ? product.nameAr : product.nameEn} />
          {:else}
            <div class="image-placeholder">📦</div>
          {/if}
          
          {#if hasDiscount}
            <div class="discount-badge">
              -{Math.round(((selectedUnit.originalPrice - selectedUnit.basePrice) / selectedUnit.originalPrice) * 100)}%
            </div>
          {/if}
        </div>

        <!-- Product Info -->
        <div class="product-info">
          <h3 class="product-name">
            {currentLanguage === 'ar' ? product.nameAr : product.nameEn}
          </h3>
          
          <div class="unit-info">
            <span class="unit-size">
              {currentLanguage === 'ar' ? selectedUnit.nameAr : selectedUnit.nameEn}
            </span>
          </div>

          <!-- Price -->
          <div class="price-section">
            <div class="current-price">
              {selectedUnit.basePrice.toFixed(2)} {texts.sar}
            </div>
            {#if hasDiscount}
              <div class="original-price">
                {selectedUnit.originalPrice.toFixed(2)} {texts.sar}
              </div>
            {/if}
          </div>

          <!-- Stock Status -->
          <div class="stock-status">
            {#if isOutOfStock}
              <span class="out-of-stock">{texts.outOfStock}</span>
            {:else if isLowStock}
              <span class="low-stock">{texts.lowStock}</span>
            {:else}
              <span class="in-stock">{texts.inStock}</span>
            {/if}
          </div>

          <!-- Add to Cart / Quantity Controls -->
          <div class="cart-controls">
            {#if quantity === 0}
              <button 
                class="add-to-cart-btn" 
                on:click={() => addToCart(product)}
                disabled={isOutOfStock}
                type="button"
              >
                {texts.addToCart}
              </button>
            {:else}
              <div class="quantity-controls">
                <button 
                  class="quantity-btn decrease" 
                  on:click={() => updateQuantity(product, -1)}
                >
                  -
                </button>
                <span class="quantity-display">{quantity}</span>
                <button 
                  class="quantity-btn increase" 
                  on:click={() => updateQuantity(product, 1)}
                  disabled={isOutOfStock}
                >
                  +
                </button>
              </div>
            {/if}
          </div>
        </div>
      </div>
      {/key}
    {/each}
  </div>
  
  {#if filteredProducts.length === 0}
    <div class="no-products">
      <div class="no-products-icon">📦</div>
      <div class="no-products-text">
        {currentLanguage === 'ar' ? 'لا توجد منتجات مطابقة' : 'No matching products found'}
      </div>
    </div>
  {/if}
</div>

<style>
  .products-container {
    padding: 0.75rem;
    max-width: 1200px;
    margin: 0 auto;
    min-height: 100vh;
    width: 100%;
    box-sizing: border-box;
  }
  
  @media (min-width: 768px) {
    .products-container {
      padding: 1rem;
    }
  }

  .search-section {
    margin-bottom: 1.25rem;
  }
  
  @media (min-width: 768px) {
    .search-section {
      margin-bottom: 2rem;
    }
  }

  .search-bar {
    position: relative;
    margin-bottom: 0.75rem;
  }
  
  @media (min-width: 768px) {
    .search-bar {
      margin-bottom: 1rem;
    }
  }

  .search-input {
    width: 100%;
    padding: 0.875rem 2.5rem 0.875rem 1rem;
    border: 2px solid var(--color-border);
    border-radius: 12px;
    font-size: 0.95rem;
    background: white;
    transition: border-color 0.2s ease;
    box-sizing: border-box;
  }
  
  @media (min-width: 768px) {
    .search-input {
      padding: 1rem 3rem 1rem 1rem;
      font-size: 1rem;
    }
  }

  .search-input:focus {
    outline: none;
    border-color: var(--color-primary);
  }

  .search-icon {
    position: absolute;
    right: 0.75rem;
    top: 50%;
    transform: translateY(-50%);
    font-size: 1.1rem;
    color: var(--color-ink-light);
    pointer-events: none;
  }
  
  @media (min-width: 768px) {
    .search-icon {
      right: 1rem;
      font-size: 1.2rem;
    }
  }

  .category-filter {
    margin-bottom: 1.25rem;
  }
  
  @media (min-width: 768px) {
    .category-filter {
      margin-bottom: 2rem;
    }
  }

  .category-container {
    position: relative;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  @media (min-width: 768px) {
    .category-container {
      gap: 1rem;
    }
  }

  .nav-button {
    flex-shrink: 0;
    width: 36px;
    height: 36px;
    background: white;
    border: 2px solid var(--color-border);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s ease;
    color: var(--color-ink);
    z-index: 2;
    -webkit-tap-highlight-color: transparent;
  }
  
  @media (min-width: 768px) {
    .nav-button {
      width: 40px;
      height: 40px;
    }
  }

  .nav-button:hover {
    border-color: var(--color-primary);
    background: var(--color-primary);
    color: white;
  }

  .category-tabs {
    display: flex;
    gap: 0.5rem;
    overflow-x: auto;
    overflow-y: hidden;
    scroll-behavior: smooth;
    -webkit-overflow-scrolling: touch;
    scrollbar-width: none;
    -ms-overflow-style: none;
    padding: 0.5rem 0;
    flex: 1;
  }

  .category-tabs::-webkit-scrollbar {
    display: none;
  }

  .category-tab {
    padding: 0.75rem 1.5rem;
    background: white;
    border: 2px solid var(--color-border);
    border-radius: 25px;
    cursor: pointer;
    transition: all 0.2s ease;
    white-space: nowrap;
    font-weight: 500;
    color: var(--color-ink);
    user-select: none;
    -webkit-user-select: none;
    flex-shrink: 0;
  }

  .category-tab:hover {
    border-color: var(--color-primary);
    color: var(--color-primary);
  }

  .category-tab.active {
    background: var(--color-primary);
    color: white;
    border-color: var(--color-primary);
  }

  .category-tab:active {
    transform: scale(0.98);
  }

  .category-tab.active {
    background: var(--color-primary);
    color: white;
    border-color: var(--color-primary);
  }

  .category-tab:hover:not(.active) {
    border-color: var(--color-primary);
    color: var(--color-primary);
  }

  .products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 1rem;
  }
  
  @media (min-width: 480px) {
    .products-grid {
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 1.25rem;
    }
  }
  
  @media (min-width: 768px) {
    .products-grid {
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 1.5rem;
    }
  }

  .product-card {
    background: white;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    transition: transform 0.2s ease;
    border: 1px solid var(--color-border-light);
    display: flex;
    flex-direction: column;
  }
  
  @media (min-width: 768px) {
    .product-card {
      border-radius: 16px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    }
  }

  .product-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15);
  }

  .product-image {
    position: relative;
    height: 140px;
    background: var(--color-background);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  
  @media (min-width: 480px) {
    .product-image {
      height: 180px;
    }
  }
  
  @media (min-width: 768px) {
    .product-image {
      height: 200px;
    }
  }

  .product-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .image-placeholder {
    font-size: 4rem;
    color: var(--color-ink-light);
    opacity: 0.5;
  }

  .discount-badge {
    position: absolute;
    top: 0.75rem;
    right: 0.75rem;
    background: var(--color-danger);
    color: white;
    padding: 0.25rem 0.5rem;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .product-info {
    padding: 0.875rem;
    display: flex;
    flex-direction: column;
    flex: 1;
  }
  
  @media (min-width: 480px) {
    .product-info {
      padding: 1.25rem;
    }
  }
  
  @media (min-width: 768px) {
    .product-info {
      padding: 1.5rem;
    }
  }

  .product-name {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 0.5rem 0;
    line-height: 1.3;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  @media (min-width: 480px) {
    .product-name {
      font-size: 1rem;
    }
  }
  
  @media (min-width: 768px) {
    .product-name {
      font-size: 1.1rem;
    }
  }

  .unit-info {
    margin-bottom: 1rem;
  }

  .unit-size {
    font-size: 0.8rem;
    color: var(--color-ink-light);
    background: var(--color-background);
    padding: 0.25rem 0.5rem;
    border-radius: 16px;
    display: inline-block;
  }
  
  @media (min-width: 768px) {
    .unit-size {
      font-size: 0.9rem;
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
    }
  }

  .price-section {
    margin-bottom: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .current-price {
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--color-primary);
  }
  
  @media (min-width: 480px) {
    .current-price {
      font-size: 1.15rem;
    }
  }
  
  @media (min-width: 768px) {
    .current-price {
      font-size: 1.25rem;
    }
  }

  .original-price {
    font-size: 0.85rem;
    color: var(--color-ink-light);
    text-decoration: line-through;
  }
  
  @media (min-width: 768px) {
    .original-price {
      font-size: 1rem;
    }
  }

  .stock-status {
    margin-bottom: 1rem;
  }

  .in-stock {
    color: var(--color-success);
    font-size: 0.875rem;
    font-weight: 500;
  }

  .low-stock {
    color: var(--color-warning);
    font-size: 0.875rem;
    font-weight: 500;
  }

  .out-of-stock {
    color: var(--color-danger);
    font-size: 0.875rem;
    font-weight: 500;
  }

  .cart-controls {
    margin-top: auto;
    position: relative;
    z-index: 10;
    pointer-events: auto;
  }

  .add-to-cart-btn {
    width: 100%;
    padding: 0.625rem;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    pointer-events: auto;
    position: relative;
    z-index: 10;
    -webkit-tap-highlight-color: transparent;
  }
  
  @media (min-width: 768px) {
    .add-to-cart-btn {
      padding: 0.75rem;
      font-size: 1rem;
    }
  }

  .add-to-cart-btn:hover:not(:disabled) {
    background: var(--color-primary-dark);
  }

  .add-to-cart-btn:disabled {
    background: var(--color-ink-light);
    opacity: 0.5;
    cursor: not-allowed;
  }

  .quantity-controls {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
    background: var(--color-background);
    border-radius: 8px;
    padding: 0.5rem;
  }

  .quantity-btn {
    width: 36px;
    height: 36px;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 50%;
    font-size: 1.1rem;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s ease;
    -webkit-tap-highlight-color: transparent;
    flex-shrink: 0;
  }
  
  @media (min-width: 768px) {
    .quantity-btn {
      width: 40px;
      height: 40px;
      font-size: 1.2rem;
    }
  }

  .quantity-btn:hover:not(:disabled) {
    background: var(--color-primary-dark);
  }

  .quantity-btn:disabled {
    background: var(--color-ink-light);
    opacity: 0.5;
    cursor: not-allowed;
  }

  .quantity-display {
    font-size: 1rem;
    font-weight: 600;
    color: var(--color-ink);
    min-width: 35px;
    text-align: center;
  }
  
  @media (min-width: 768px) {
    .quantity-display {
      font-size: 1.1rem;
      min-width: 40px;
    }
  }

  .no-products {
    text-align: center;
    padding: 4rem 2rem;
    color: var(--color-ink-light);
  }

  .no-products-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
    opacity: 0.5;
  }

  .no-products-text {
    font-size: 1.2rem;
  }
</style>