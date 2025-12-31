<script lang="ts">
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { userStore, userActions } from '$lib/stores/user.js';
  import { supabase } from '$lib/utils/supabase';
  import FeaturedOffers from '$lib/components/customer-interface/shopping/FeaturedOffers.svelte';
  import OfferDetailModal from '$lib/components/customer-interface/shopping/OfferDetailModal.svelte';

  let currentLanguage = 'ar';
  let videoContainer;
  let currentVideoIndex = 0;
  let currentMediaIndex = 0;
  let isVideoHidden = false;
  let videoError = false;
  let userName = 'Guest';
  let loading = true;
  let mediaItems = []; // Combined video and image items from database
  let rotationTimer = null; // timer for auto-rotation
  
  // Featured offers state
  let featuredOffers: any[] = [];
  let isLoadingOffers = true;
  let selectedOffer: any = null;
  let showOfferModal = false;
  
  // Touch tracking for scroll vs click detection
  let touchStartY = 0;
  let touchStartX = 0;
  let isTouchMoving = false;

  // Convert English numbers to Arabic numerals
  function toArabicNumerals(num: number | string): string {
    const arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return String(num).replace(/\d/g, (digit) => arabicNumerals[parseInt(digit)]);
  }

  // Format price to hide .00 if no decimals
  function formatPrice(price: number): string {
    const formatted = price.toFixed(2);
    return formatted.endsWith('.00') ? formatted.slice(0, -3) : formatted;
  }

  // Calculate time remaining until offer expires
  function getExpiryCountdown(endDate: string): string {
    // Get current time in Saudi timezone
    const now = new Date();
    const saudiNow = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
    
    // Parse end date (stored in UTC) and convert to Saudi time
    const endUTC = new Date(endDate);
    const endSaudi = new Date(endUTC.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
    
    const diff = endSaudi.getTime() - saudiNow.getTime();
    
    if (diff <= 0) {
      return currentLanguage === 'ar' ? 'انتهى العرض' : 'Expired';
    }
    
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    
    if (days > 0) {
      if (currentLanguage === 'ar') {
        return `ينتهي خلال ${toArabicNumerals(days)} ${days === 1 ? 'يوم' : 'أيام'} ${toArabicNumerals(hours)} ${hours === 1 ? 'ساعة' : 'ساعات'}`;
      } else {
        return `Expires in ${days} ${days === 1 ? 'day' : 'days'} ${hours} ${hours === 1 ? 'hr' : 'hrs'}`;
      }
    } else if (hours > 0) {
      if (currentLanguage === 'ar') {
        return `ينتهي خلال ${toArabicNumerals(hours)} ${hours === 1 ? 'ساعة' : 'ساعات'} ${toArabicNumerals(minutes)} ${minutes === 1 ? 'دقيقة' : 'دقائق'}`;
      } else {
        return `Expires in ${hours} ${hours === 1 ? 'hr' : 'hrs'} ${minutes} ${minutes === 1 ? 'min' : 'mins'}`;
      }
    } else {
      if (currentLanguage === 'ar') {
        return `ينتهي خلال ${toArabicNumerals(minutes)} ${minutes === 1 ? 'دقيقة' : 'دقائق'}`;
      } else {
        return `Expires in ${minutes} ${minutes === 1 ? 'minute' : 'minutes'}`;
      }
    }
  }

  // Product categories
  const categories = [
    { id: 'beverages', nameAr: 'المشروبات', nameEn: 'Beverages', icon: '🥤' },
    { id: 'water', nameAr: 'المياه', nameEn: 'Water', icon: '💧' },
    { id: 'juice', nameAr: 'العصائر', nameEn: 'Juices', icon: '🧃' },
    { id: 'coffee', nameAr: 'القهوة', nameEn: 'Coffee', icon: '☕' },
    { id: 'tea', nameAr: 'الشاي', nameEn: 'Tea', icon: '🍵' },
    { id: 'energy', nameAr: 'مشروبات الطاقة', nameEn: 'Energy Drinks', icon: '⚡' },
    { id: 'soft-drinks', nameAr: 'المشروبات الغازية', nameEn: 'Soft Drinks', icon: '🥤' },
    { id: 'milk', nameAr: 'منتجات الألبان', nameEn: 'Dairy Products', icon: '🥛' },
    { id: 'smoothies', nameAr: 'العصائر المخلوطة', nameEn: 'Smoothies', icon: '🥤' },
    { id: 'sports', nameAr: 'المشروبات الرياضية', nameEn: 'Sports Drinks', icon: '🏃' },
    { id: 'healthy', nameAr: 'المشروبات الصحية', nameEn: 'Healthy Drinks', icon: '🌱' },
    { id: 'seasonal', nameAr: 'المشروبات الموسمية', nameEn: 'Seasonal Drinks', icon: '🍂' },
    { id: 'premium', nameAr: 'المشروبات الممتازة', nameEn: 'Premium Drinks', icon: '⭐' },
    { id: 'organic', nameAr: 'المشروبات العضوية', nameEn: 'Organic Drinks', icon: '🌿' },
    { id: 'functional', nameAr: 'المشروبات الوظيفية', nameEn: 'Functional Drinks', icon: '💪' },
    { id: 'international', nameAr: 'المشروبات العالمية', nameEn: 'International Drinks', icon: '🌍' },
    { id: 'hot-beverages', nameAr: 'المشروبات الساخنة', nameEn: 'Hot Beverages', icon: '🔥' },
    { id: 'cold-beverages', nameAr: 'المشروبات الباردة', nameEn: 'Cold Beverages', icon: '🧊' }
  ];

  // Load language and user data
  // Load media items from database
  async function loadMediaItems() {
    try {
      const { data, error } = await supabase.rpc('get_active_customer_media');
      
      if (error) {
        console.error('Error loading media:', error);
        mediaItems = [];
        return;
      }
      
      // Transform database records to match expected format
      mediaItems = (data || []).map(item => ({
        id: item.id,
        src: item.file_url,
        type: item.media_type, // 'video' or 'image'
        title: `Slot ${item.slot_number}`,
        titleEn: `Slot ${item.slot_number}`,
        duration: item.duration || 5, // Default 5 seconds for images
        slot_number: item.slot_number
      }));
      
      console.log(`Loaded ${mediaItems.length} active media items`);
    } catch (err) {
      console.error('Failed to load media:', err);
      mediaItems = [];
    }
  }

  // Load featured offers
  async function loadFeaturedOffers() {
    isLoadingOffers = true;
    console.log('🎁 [Customer Offers] Starting to load featured offers...');
    try {
      // Add cache busting timestamp to force fresh data
      const cacheBuster = Date.now();
      const response = await fetch(`/api/customer/featured-offers?limit=5&_t=${cacheBuster}`, {
        cache: 'no-store' // Disable caching
      });
      console.log('🎁 [Customer Offers] API Response status:', response.status);
      const data = await response.json();
      console.log('🎁 [Customer Offers] API Response data:', data);
      
      if (data.success && data.offers) {
        featuredOffers = data.offers;
        console.log('🎁 [Customer Offers] Loaded offers:', featuredOffers.length, 'offers');
        
        // Convert each product in each offer to a media item
        const productMediaItems = [];
        let slotNumber = 100; // Start slot numbers at 100
        
        featuredOffers.forEach((offer) => {
          console.log(`🎁 [Offer ${offer.id}] Type: ${offer.type}, Name: ${offer.name_en}`);
          console.log(`  📋 Offer data:`, {
            products: offer.products?.length || 0,
            bundles: offer.bundles?.length || 0,
            bogo_rules: offer.bogo_rules?.length || 0
          });
          
          // Handle product offers (percentage and special price)
          if (offer.type === 'product' && offer.products && offer.products.length > 0) {
            console.log(`🎁 [Offer ${offer.id}] ${offer.name_en} has ${offer.products.length} products`);
            
            offer.products.forEach((offerProduct) => {
              console.log(`  📦 Processing product:`, offerProduct);
              const product = offerProduct.products; // Product details are nested
              if (product) {
                console.log(`  ✅ Product found:`, product.product_name_en);
                // Calculate discounted price
                // Priority: offer_percentage > offer_price
                let finalPrice = product.sale_price;
                let discountPercentage = null;
                
                if (offerProduct.offer_percentage && offerProduct.offer_percentage > 0) {
                  // Use percentage discount
                  discountPercentage = offerProduct.offer_percentage;
                  finalPrice = product.sale_price * (1 - discountPercentage / 100);
                } else if (offerProduct.offer_price && offerProduct.offer_price < product.sale_price) {
                  // Use special price only if it's lower than original
                  finalPrice = offerProduct.offer_price;
                }
                
                // If offer_qty > 1, multiply prices by quantity for total display
                const offerQty = offerProduct.offer_qty || 1;
                const displayOriginalPrice = product.sale_price * offerQty;
                const displayFinalPrice = finalPrice * offerQty;
                
                // Determine discount type based on offerProduct data
                const discountType = offerProduct.offer_percentage ? 'percentage' : 'fixed';
                const discountValue = offerProduct.offer_percentage || offerProduct.offer_price;
                
                const mediaItem = {
                  id: `offer-product-${offer.id}-${product.id}`,
                  src: product.image_url || '', // Product image
                  type: 'offer-product', // New type for offer products
                  title: currentLanguage === 'ar' ? product.product_name_ar : product.product_name_en,
                  titleEn: product.product_name_en,
                  titleAr: product.product_name_ar,
                  duration: 5, // Show each product for 5 seconds
                  slot_number: slotNumber++,
                  productData: product,
                  offerData: offer, // Keep offer data for modal
                  offerProductData: offerProduct, // Keep offer_product data for pricing
                  discountInfo: {
                    type: discountType, // Get from offerProduct, not offer
                    value: discountValue, // Get from offerProduct, not offer
                    originalPrice: displayOriginalPrice, // Total price for offer_qty
                    finalPrice: displayFinalPrice, // Total discounted price
                    offerPercentage: discountPercentage,
                    offerPrice: offerProduct.offer_price && offerProduct.offer_price < product.sale_price ? offerProduct.offer_price : null
                  }
                };
                console.log(`  🎬 Created media item:`, mediaItem.id);
                productMediaItems.push(mediaItem);
              } else {
                console.log(`  ❌ Product details missing for product_id:`, offerProduct.product_id);
              }
            });
          }
          
          // Handle bundle offers - create ONE card with ALL products
          if (offer.type === 'bundle' && offer.bundles && offer.bundles.length > 0) {
            console.log(`🎁 [Offer ${offer.id}] Bundle offer with ${offer.bundles.length} bundles`);
            
            offer.bundles.forEach((bundle) => {
              console.log(`  📦 Processing bundle:`, bundle);
              if (bundle.items_with_details && bundle.items_with_details.length > 0) {
                console.log(`  ✅ Bundle has ${bundle.items_with_details.length} items`);
                
                // Calculate original total and bundle final price
                // Each product has individual discount applied
                let originalTotal = 0;
                let bundlePrice = 0;
                
                bundle.items_with_details.forEach(item => {
                  const product = item.product;
                  if (product) {
                    const itemOriginal = product.sale_price * item.quantity;
                    originalTotal += itemOriginal;
                    
                    // Apply individual product discount
                    let itemFinal = itemOriginal;
                    if (item.discount_type === 'percentage') {
                      itemFinal = itemOriginal * (1 - item.discount_value / 100);
                    } else if (item.discount_type === 'amount') {
                      itemFinal = itemOriginal - item.discount_value;
                    }
                    bundlePrice += itemFinal;
                  }
                });
                
                // Bundle discount_value from database is the final price (already calculated)
                // Use it if available, otherwise use our calculation
                if (bundle.discount_value && bundle.discount_value > 0) {
                  bundlePrice = bundle.discount_value;
                }
                
                const totalDiscount = originalTotal - bundlePrice;
                const bundleDiscountPercentage = Math.round((totalDiscount / originalTotal) * 100);
                
                console.log(`  💰 Bundle pricing: Original ${originalTotal} SAR → Final ${bundlePrice} SAR (${bundleDiscountPercentage}% off)`);
                
                // Create ONE media item for the entire bundle with all products
                const mediaItem = {
                  id: `offer-bundle-${offer.id}-${bundle.id}`,
                  src: '', // Will show multiple images
                  type: 'offer-bundle', // New type for bundle display
                  title: currentLanguage === 'ar' ? bundle.bundle_name_ar : bundle.bundle_name_en,
                  titleEn: bundle.bundle_name_en,
                  titleAr: bundle.bundle_name_ar,
                  duration: 5,
                  slot_number: slotNumber++,
                  bundleData: bundle,
                  bundleProducts: bundle.items_with_details, // All products in bundle
                  offerData: offer,
                  discountInfo: {
                    type: 'bundle',
                    value: totalDiscount,
                    originalPrice: originalTotal,
                    finalPrice: bundlePrice,
                    offerPercentage: bundleDiscountPercentage,
                    offerPrice: bundlePrice
                  }
                };
                console.log(`  🎬 Created bundle media item with ${bundle.items_with_details.length} products`);
                productMediaItems.push(mediaItem);
              } else {
                console.log(`  ❌ Bundle missing items_with_details`);
              }
            });
          }
          
          // Handle BOGO (Buy X Get Y) offers
          if ((offer.type === 'bogo' || offer.type === 'buy_x_get_y') && offer.bogo_rules && offer.bogo_rules.length > 0) {
            console.log(`🎁 [Offer ${offer.id}] BOGO offer with ${offer.bogo_rules.length} rules`);
            
            offer.bogo_rules.forEach((rule) => {
              console.log(`  📦 Processing BOGO rule:`, rule);
              const buyProduct = rule.buy_product;
              const getProduct = rule.get_product;
              
              if (buyProduct && getProduct) {
                console.log(`  ✅ BOGO products found: Buy ${buyProduct.product_name_en}, Get ${getProduct.product_name_en}`);
                
                // Calculate savings (discount_type can be 'free' or 'percentage')
                let getDiscount = 100; // Default to free
                if (rule.discount_type === 'percentage') {
                  getDiscount = rule.discount_value || 100;
                } else if (rule.discount_type === 'amount') {
                  getDiscount = (rule.discount_value / getProduct.sale_price) * 100;
                } else if (rule.discount_type === 'free') {
                  getDiscount = 100; // Free = 100% discount
                }
                
                const totalOriginal = (buyProduct.sale_price * rule.buy_quantity) + (getProduct.sale_price * rule.get_quantity);
                const totalFinal = (buyProduct.sale_price * rule.buy_quantity) + (getProduct.sale_price * rule.get_quantity * (1 - getDiscount / 100));
                
                // Create BOGO products array for display
                const bogoProducts = [
                  {
                    product: buyProduct,
                    quantity: rule.buy_quantity,
                    isBuyProduct: true,
                    discount_value: 0 // No discount on buy product
                  },
                  {
                    product: getProduct,
                    quantity: rule.get_quantity,
                    isBuyProduct: false,
                    discount_value: getDiscount // Discount on get product
                  }
                ];
                
                const mediaItem = {
                  id: `offer-bogo-${offer.id}-${rule.id}`,
                  src: '', // Will show both products
                  type: 'offer-bogo', // Special BOGO type
                  title: currentLanguage === 'ar' 
                    ? `${offer.name_ar || 'عرض اشتري واحصل'}`
                    : `${offer.name_en || 'Buy & Get Offer'}`,
                  titleEn: offer.name_en || `Buy ${rule.buy_quantity} Get ${rule.get_quantity}`,
                  titleAr: offer.name_ar || `اشتري ${rule.buy_quantity} احصل ${rule.get_quantity}`,
                  duration: 5,
                  slot_number: slotNumber++,
                  bogoData: rule,
                  bogoProducts: bogoProducts, // Both buy and get products
                  offerData: offer,
                  discountInfo: {
                    type: 'bogo',
                    value: totalOriginal - totalFinal,
                    originalPrice: totalOriginal,
                    finalPrice: totalFinal,
                    offerPercentage: getDiscount,
                    offerPrice: totalFinal
                  }
                };
                console.log(`  🎬 Created BOGO media item with Buy ${rule.buy_quantity} Get ${rule.get_quantity}`);
                productMediaItems.push(mediaItem);
              } else {
                console.log(`  ❌ BOGO products missing:`, { buyProduct, getProduct });
              }
            });
          }
        });
        
        console.log('🎁 [Customer Offers] Created', productMediaItems.length, 'product media items from offers');
        
        // Add product media items to mediaItems
        mediaItems = [...mediaItems, ...productMediaItems];
        console.log('🎁 [Customer Offers] Total media items:', mediaItems.length);
      } else {
        console.warn('🎁 [Customer Offers] No offers returned:', data);
        featuredOffers = [];
      }
    } catch (error) {
      console.error('🎁 [Customer Offers] Error loading offers:', error);
      featuredOffers = [];
    } finally {
      isLoadingOffers = false;
      console.log('🎁 [Customer Offers] Loading complete. Offers count:', featuredOffers.length);
    }
  }

  function handleViewOffer(event: CustomEvent) {
    selectedOffer = event.detail;
    showOfferModal = true;
  }

  function closeOfferModal() {
    showOfferModal = false;
    selectedOffer = null;
  }

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }

    // Check authentication and load user data
    const isAuthenticated = userActions.loadFromStorage();
    if (!isAuthenticated) {
      goto("/customer-login");
      return;
    }

    // Load media from database
    await loadMediaItems();
    
    // Load featured offers
    await loadFeaturedOffers();
    
    loading = false;

    // Subscribe to user store for reactive updates
    userStore.subscribe(user => {
      userName = user.customer_name || user.name || user.phone || 'Guest';
    });

    // Reset video error state on mount
    videoError = false;
    
    // Start media rotation
    startMediaRotation();

    // Load video visibility preference
    const videoHiddenPref = localStorage.getItem('videoHidden');
    if (videoHiddenPref === 'true') {
      isVideoHidden = true;
    }
    
    // Subscribe to real-time offer changes
    const offersChannel = supabase
      .channel('offers-changes')
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'offers' },
        async (payload) => {
          console.log('🔄 [Real-time] Offer changed:', payload);
          await loadMediaItems();
          await loadFeaturedOffers();
        }
      )
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'offer_products' },
        async (payload) => {
          console.log('🔄 [Real-time] Offer product changed:', payload);
          await loadMediaItems();
          await loadFeaturedOffers();
        }
      )
      .subscribe();
    
    // Reload offers when page becomes visible (user switches back to tab)
    const handleVisibilityChange = async () => {
      if (!document.hidden) {
        console.log('🔄 [Customer Offers] Page visible again, reloading offers...');
        await loadMediaItems();
        await loadFeaturedOffers();
      }
    };
    
    document.addEventListener('visibilitychange', handleVisibilityChange);
    
    // Listen for broadcast messages from admin panel to refresh offers
    let channel;
    if (typeof BroadcastChannel !== 'undefined') {
      channel = new BroadcastChannel('aqura-offers-update');
      channel.onmessage = async (event) => {
        if (event.data === 'refresh-offers') {
          console.log('🔄 [Customer Offers] Refresh triggered by admin...');
          await loadMediaItems();
          await loadFeaturedOffers();
        }
      };
    }
    
    // Cleanup function
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      offersChannel.unsubscribe();
      if (channel) channel.close();
    };
  });

  // Listen for language changes
  function handleStorageChange(event) {
    if (event.key === 'language') {
      currentLanguage = event.newValue || 'ar';
    }
  }

  // Media rotation functionality (handles both videos and images)
  function scheduleNextMedia() {
    if (mediaItems.length === 0) return;
    const currentMedia = mediaItems[currentMediaIndex] || { duration: 5 };
    const duration = (currentMedia.duration || 5) * 1000 + 2000; // Add 2 seconds buffer
    clearTimeout(rotationTimer);
    rotationTimer = setTimeout(() => {
      nextMedia();
      scheduleNextMedia();
    }, duration);
  }

  function startMediaRotation() {
    scheduleNextMedia();
  }
  
  function nextMedia() {
    currentMediaIndex = (currentMediaIndex + 1) % mediaItems.length;
    updateMediaDisplay();
  }
  function advanceMediaNow() {
    // Manually go to next media and reschedule rotation
    clearTimeout(rotationTimer);
    nextMedia();
    scheduleNextMedia();
  }

  function handleMediaClick(event) {
    event?.preventDefault();
    event?.stopPropagation();
    advanceMediaNow();
  }

  function handleMediaTouchEnd(event) {
    event?.preventDefault();
    event?.stopPropagation();
    advanceMediaNow();
  }
  
  function updateMediaDisplay() {
    if (videoContainer && mediaItems.length > 0) {
      const currentMedia = mediaItems[currentMediaIndex];
      
      if (currentMedia.type === 'video') {
        const video = videoContainer.querySelector('video');
        const img = videoContainer.querySelector('img');
        
        // Hide image if visible
        if (img) img.style.display = 'none';
        
        if (video) {
          video.style.display = 'block';
          video.src = currentMedia.src;
          video.load();
          video.play().catch(e => {
            console.log('Video autoplay prevented:', e);
            videoError = false;
          });
        }
      } else if (currentMedia.type === 'image') {
        const video = videoContainer.querySelector('video');
        const img = videoContainer.querySelector('img');
        
        // Hide video if playing
        if (video) {
          video.pause();
          video.style.display = 'none';
        }
        
        if (img) {
          img.style.display = 'block';
          img.src = currentMedia.src;
        }
      }
    }
  }

  function handleVideoError() {
    console.log('Media failed to load');
    videoError = false;
  }
  
  function hideVideo(event) {
    event?.preventDefault();
    event?.stopPropagation();
    isVideoHidden = true;
    localStorage.setItem('videoHidden', 'true');
  }

  function showVideo(event) {
    event?.preventDefault();
    event?.stopPropagation();
    console.log('Show video clicked');
    isVideoHidden = false;
    localStorage.removeItem('videoHidden');
  }

  function handleShowVideoTouch(event) {
    event.preventDefault();
    event.stopPropagation();
    console.log('Show video touched');
    isVideoHidden = false;
    localStorage.removeItem('videoHidden');
  }

  onMount(() => {
    window.addEventListener('storage', handleStorageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  });

  // Language texts
  $: texts = currentLanguage === 'ar' ? {
    title: 'الرئيسية - أكوا إكسبرس',
    greeting: `مرحباً ${userName} 👋`,
    shopNow: 'ابدأ التسوق',
    support: 'الدعم والمساعدة',
    startSubtitle: 'اختر الفرع والخدمة ثم أضف المنتجات',
  } : {
    title: 'Home - Aqua Express',
    greeting: `Welcome ${userName} 👋`,
    shopNow: 'Shop Now',
    support: 'Support',
    startSubtitle: 'Pick a branch and service, then add products',
  };

  // Touch event handlers for scroll detection
  function handleTouchStart(event) {
    touchStartY = event.touches[0].clientY;
    touchStartX = event.touches[0].clientX;
    isTouchMoving = false;
  }

  function handleTouchMove(event) {
    const touchEndY = event.touches[0].clientY;
    const touchEndX = event.touches[0].clientX;
    const diffY = Math.abs(touchEndY - touchStartY);
    const diffX = Math.abs(touchEndX - touchStartX);
    
    // If finger moved more than 10px, consider it as scrolling
    if (diffY > 10 || diffX > 10) {
      isTouchMoving = true;
    }
  }

  function handleCategoryClick(categoryId, event) {
    // Prevent navigation if user was scrolling
    if (isTouchMoving) {
      event?.preventDefault();
      event?.stopPropagation();
      return;
    }
    
    console.log('Category clicked:', categoryId);
    event?.preventDefault();
    event?.stopPropagation();
    try {
      goto(`/customer/products?category=${categoryId}`);
    } catch (error) {
      console.error('Navigation error:', error);
    }
  }

  function goStartShopping(event) {
    event?.preventDefault();
    event?.stopPropagation();
    console.log('Go shopping clicked');
    goto('/customer-interface/start');
  }

  function goSupport(event) {
    event?.preventDefault();
    event?.stopPropagation();
    console.log('Go support clicked');
    goto('/customer-interface/support');
  }

  function logout() {
    userActions.logout();
    goto("/customer-login");
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
</svelte:head>

{#if loading}
  <div class="loading-container">
    <div class="spinner"></div>
    <p>Loading...</p>
  </div>
{:else}
  <!-- Individual floating bubbles -->
  <div class="floating-bubbles">
    <div class="bubble bubble-orange bubble-1"></div>
    <div class="bubble bubble-blue bubble-2"></div>
    <div class="bubble bubble-green bubble-3"></div>
    <div class="bubble bubble-pink bubble-4"></div>
    <div class="bubble bubble-orange bubble-5"></div>
    <div class="bubble bubble-blue bubble-6"></div>
    <div class="bubble bubble-green bubble-7"></div>
    <div class="bubble bubble-pink bubble-8"></div>
    <div class="bubble bubble-orange bubble-9"></div>
    <div class="bubble bubble-blue bubble-10"></div>
    <div class="bubble bubble-green bubble-11"></div>
    <div class="bubble bubble-pink bubble-12"></div>
    <div class="bubble bubble-orange bubble-13"></div>
    <div class="bubble bubble-blue bubble-14"></div>
    <div class="bubble bubble-green bubble-15"></div>
    <div class="bubble bubble-pink bubble-16"></div>
    <div class="bubble bubble-orange bubble-17"></div>
    <div class="bubble bubble-blue bubble-18"></div>
    <div class="bubble bubble-green bubble-19"></div>
    <div class="bubble bubble-pink bubble-20"></div>
  </div>

  <div class="home-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
    <!-- LED Screen Media Section -->
    {#if !isVideoHidden && mediaItems.length > 0}
      <section class="advertisement-section">
        <div class="led-screen-container">
          <div class="led-frame">
            <button class="hide-btn" on:click={hideVideo} type="button">
              <span>✕</span>
            </button>
            <div class="screen-glow"></div>
            <div class="video-content" bind:this={videoContainer} on:click={handleMediaClick} on:touchend={handleMediaTouchEnd}>
              <div class="led-dots"></div>
              {#each mediaItems as media, index}
                {#if media.type === 'video'}
                  <video
                    style="display: {index === currentMediaIndex ? 'block' : 'none'};"
                    src={media.src}
                    playsinline
                    muted
                    loop
                    preload="auto"
                    class="media-video"
                  />
                {:else if media.type === 'offer-product'}
                  <!-- Product Card Display (from offer) -->
                  <div 
                    class="product-card-display {media.discountInfo.type === 'bundle' ? 'bundle-offer' : ''}"
                    style="display: {index === currentMediaIndex ? 'flex' : 'none'};"
                  >
                    <!-- Moving Watermark Logo -->
                    {#if index === currentMediaIndex}
                      <div class="watermark-logo">
                        <img src="/icons/logo.png" alt="Aqura" class="watermark-image" />
                      </div>
                    {/if}
                    
                    <div class="product-card-content">
                      <!-- Product Image at Top -->
                      <div class="product-image-wrapper {media.discountInfo.type === 'bundle' ? 'bundle-product' : ''}">
                        <!-- Discount Badge on Image (Top Right) -->
                        <div class="discount-badge">
                          {#if media.discountInfo.offerPercentage}
                            <span class="badge-text">{currentLanguage === 'ar' ? toArabicNumerals(media.discountInfo.offerPercentage) : media.discountInfo.offerPercentage}%</span>
                          {:else if media.discountInfo.offerPrice && media.discountInfo.offerPrice < media.discountInfo.originalPrice}
                            <span class="badge-text">{currentLanguage === 'ar' ? 'سعر خاص' : 'SPECIAL PRICE'}</span>
                          {:else if media.discountInfo.type === 'percentage'}
                            <span class="badge-text">{currentLanguage === 'ar' ? toArabicNumerals(media.discountInfo.value) : media.discountInfo.value}%</span>
                          {:else if media.discountInfo.type === 'fixed'}
                            <span class="badge-text">{currentLanguage === 'ar' ? toArabicNumerals(media.discountInfo.value) : media.discountInfo.value} {currentLanguage === 'ar' ? 'ريال' : 'SAR'}</span>
                          {/if}
                        </div>
                        
                        <!-- Usage Limit Badge (Bottom Center) -->
                        {#if media.offerProductData.max_uses}
                          <div class="usage-limit-badge">
                            <span class="usage-text">
                              {#if currentLanguage === 'ar'}
                                محدود: {toArabicNumerals(media.offerProductData.max_uses)} فقط
                              {:else}
                                Limited: {media.offerProductData.max_uses} only
                              {/if}
                            </span>
                          </div>
                        {/if}
                        
                        {#if media.src}
                          <img src={media.src} alt={media.title} class="product-image" />
                        {:else}
                          <div class="product-placeholder">
                            <span class="product-emoji">🛍️</span>
                          </div>
                        {/if}
                      </div>
                      
                      <!-- Product Info Below Image -->
                      <div class="product-info-overlay">
                        <h3 class="product-title">{currentLanguage === 'ar' ? media.titleAr : media.titleEn}</h3>
                        
                        <!-- Unit Details -->
                        {#if media.offerProductData.offer_qty || media.productData.unit_name_en}
                          <div class="unit-details">
                            {#if media.offerProductData.offer_qty && media.offerProductData.offer_qty > 1}
                              <span>{currentLanguage === 'ar' ? toArabicNumerals(media.offerProductData.offer_qty) : media.offerProductData.offer_qty}</span>
                              {#if media.productData.unit_qty && media.productData.unit_qty > 1}
                                <span> × {currentLanguage === 'ar' ? toArabicNumerals(media.productData.unit_qty) : media.productData.unit_qty} {currentLanguage === 'ar' ? (media.productData.unit_name_ar || 'قطعة') : (media.productData.unit_name_en || 'Unit')}</span>
                              {:else if media.productData.unit_name_en}
                                <span> {currentLanguage === 'ar' ? (media.productData.unit_name_ar || 'قطعة') : (media.productData.unit_name_en || 'Unit')}</span>
                              {/if}
                            {:else if media.productData.unit_qty && media.productData.unit_qty > 1}
                              <span>{currentLanguage === 'ar' ? toArabicNumerals(media.productData.unit_qty) : media.productData.unit_qty} {currentLanguage === 'ar' ? (media.productData.unit_name_ar || 'قطعة') : (media.productData.unit_name_en || 'Unit')}</span>
                            {:else if media.productData.unit_name_en}
                              <span>{currentLanguage === 'ar' ? (media.productData.unit_name_ar || 'قطعة') : (media.productData.unit_name_en || 'Unit')}</span>
                            {/if}
                          </div>
                        {/if}
                        
                        <!-- Sale Price (crossed out) -->
                        {#if media.discountInfo.finalPrice < media.discountInfo.originalPrice}
                          <span class="original-price">
                            {#if currentLanguage === 'ar'}
                              {toArabicNumerals(formatPrice(media.discountInfo.originalPrice))}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                              {formatPrice(media.discountInfo.originalPrice)}
                            {/if}
                          </span>
                        {/if}
                        
                        <!-- Offer Price (large green) -->
                        <div class="offer-price">
                          {#if media.discountInfo.finalPrice < media.discountInfo.originalPrice}
                            {#if currentLanguage === 'ar'}
                              <span class="discounted-price">{toArabicNumerals(formatPrice(media.discountInfo.finalPrice))}</span>
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                              <span class="discounted-price">{formatPrice(media.discountInfo.finalPrice)}</span>
                            {/if}
                          {:else}
                            {#if currentLanguage === 'ar'}
                              <span class="current-price">{toArabicNumerals(formatPrice(media.discountInfo.originalPrice))}</span>
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                              <span class="current-price">{formatPrice(media.discountInfo.originalPrice)}</span>
                            {/if}
                          {/if}
                        </div>
                        
                        <!-- Expiry Countdown -->
                        {#if media.offerData.end_date}
                          <div class="expiry-countdown">
                            ⏰ {getExpiryCountdown(media.offerData.end_date)}
                          </div>
                        {/if}
                      </div>
                    </div>
                  </div>
                {:else if media.type === 'offer-bundle'}
                  <!-- Bundle Card Display (multiple products) -->
                  <div 
                    class="product-card-display bundle-offer-card"
                    style="display: {index === currentMediaIndex ? 'flex' : 'none'};"
                  >
                    <!-- Moving Watermark Logo -->
                    {#if index === currentMediaIndex}
                      <div class="watermark-logo">
                        <img src="/icons/logo.png" alt="Aqura" class="watermark-image" />
                      </div>
                    {/if}
                    
                    <div class="bundle-card-content">
                      <!-- Discount Badge (Top Right) -->
                      <div class="discount-badge bundle-badge">
                        <span class="badge-text">{currentLanguage === 'ar' ? 'عرض حزمة' : 'Bundle Offer'}</span>
                      </div>
                      
                      <!-- Products Grid (No Bundle Title) -->
                      <div class="bundle-products-grid">
                        {#each media.bundleProducts as item}
                          {#if item.product}
                            <div class="bundle-product-item">
                              <div class="bundle-product-image-wrapper">
                                <!-- Individual Product Discount Badge -->
                                {#if item.discount_type === 'percentage' && item.discount_value > 0}
                                  <div class="product-discount-tag">
                                    <span class="tag-text">
                                      {currentLanguage === 'ar' ? toArabicNumerals(item.discount_value) : item.discount_value}%
                                    </span>
                                  </div>
                                {/if}
                                
                                {#if item.product.image_url}
                                  <img src={item.product.image_url} alt={item.product.product_name_en} class="bundle-product-image" />
                                {:else}
                                  <div class="product-placeholder-small">
                                    <span class="product-emoji-small">📦</span>
                                  </div>
                                {/if}
                              </div>
                              <div class="bundle-product-info">
                                <p class="bundle-product-name">{currentLanguage === 'ar' ? item.product.product_name_ar : item.product.product_name_en}</p>
                                <p class="bundle-product-qty">
                                  {currentLanguage === 'ar' ? toArabicNumerals(item.quantity || 1) : (item.quantity || 1)} × 
                                  {#if item.product.unit_qty && item.product.unit_qty > 1}
                                    {currentLanguage === 'ar' ? toArabicNumerals(item.product.unit_qty) : item.product.unit_qty}
                                  {/if}
                                  {currentLanguage === 'ar' ? (item.product.unit_name_ar || 'قطعة') : (item.product.unit_name_en || 'Piece')}
                                </p>
                              </div>
                            </div>
                          {/if}
                        {/each}
                      </div>
                      
                      <!-- Bundle Pricing (Match percentage offer style) -->
                      <div class="product-info-overlay">
                        <!-- Sale Price (crossed out) -->
                        {#if media.discountInfo.finalPrice < media.discountInfo.originalPrice}
                          <span class="original-price">
                            {#if currentLanguage === 'ar'}
                              {toArabicNumerals(formatPrice(media.discountInfo.originalPrice))}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                              {formatPrice(media.discountInfo.originalPrice)}
                            {/if}
                          </span>
                        {/if}
                        
                        <!-- Offer Price (large green) -->
                        <div class="offer-price">
                          {#if media.discountInfo.finalPrice < media.discountInfo.originalPrice}
                            {#if currentLanguage === 'ar'}
                              <span class="discounted-price">{toArabicNumerals(formatPrice(media.discountInfo.finalPrice))}</span>
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                              <span class="discounted-price">{formatPrice(media.discountInfo.finalPrice)}</span>
                            {/if}
                          {:else}
                            {#if currentLanguage === 'ar'}
                              <span class="current-price">{toArabicNumerals(formatPrice(media.discountInfo.originalPrice))}</span>
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                              <span class="current-price">{formatPrice(media.discountInfo.originalPrice)}</span>
                            {/if}
                          {/if}
                        </div>
                        
                        <!-- Expiry Countdown -->
                        {#if media.offerData.end_date}
                          <div class="expiry-countdown">
                            ⏰ {getExpiryCountdown(media.offerData.end_date)}
                          </div>
                        {/if}
                      </div>
                    </div>
                  </div>
                {:else if media.type === 'offer-bogo'}
                  <!-- BOGO Card Display (Buy X Get Y) -->
                  <div 
                    class="product-card-display bogo-offer-card"
                    style="display: {index === currentMediaIndex ? 'flex' : 'none'};"
                  >
                    <!-- Moving Watermark Logo -->
                    {#if index === currentMediaIndex}
                      <div class="watermark-logo">
                        <img src="/icons/logo.png" alt="Aqura" class="watermark-image" />
                      </div>
                    {/if}
                    
                    <div class="bogo-card-content">
                      <!-- BOGO Badge (Top Right) -->
                      <div class="discount-badge bogo-badge">
                        <span class="badge-text">{currentLanguage === 'ar' ? 'اشتري واحصل' : 'Buy & Get'}</span>
                      </div>
                      
                      <!-- BOGO Products Display -->
                      <div class="bogo-products-container">
                        {#each media.bogoProducts as item}
                          <div class="bogo-product-section {item.isBuyProduct ? 'buy-section' : 'get-section'}">
                            <div class="bogo-label">
                              {#if item.isBuyProduct}
                                <span class="buy-label">{currentLanguage === 'ar' ? 'اشتري' : 'BUY'}</span>
                              {:else}
                                <span class="get-label">{currentLanguage === 'ar' ? 'احصل' : 'GET'}</span>
                              {/if}
                            </div>
                            
                            <div class="bogo-product-card">
                              <div class="bogo-product-image-wrapper">
                                <!-- Discount tag for GET product -->
                                {#if !item.isBuyProduct && item.discount_value > 0}
                                  <div class="product-discount-tag free-tag">
                                    <span class="tag-text">
                                      {item.discount_value === 100 ? (currentLanguage === 'ar' ? 'مجاني' : 'FREE') : `${currentLanguage === 'ar' ? toArabicNumerals(item.discount_value) : item.discount_value}%`}
                                    </span>
                                  </div>
                                {/if}
                                
                                {#if item.product.image_url}
                                  <img src={item.product.image_url} alt={item.product.product_name_en} class="bogo-product-image" />
                                {:else}
                                  <div class="product-placeholder-medium">
                                    <span class="product-emoji-medium">🎁</span>
                                  </div>
                                {/if}
                              </div>
                              
                              <div class="bogo-product-info">
                                <p class="bogo-product-name">{currentLanguage === 'ar' ? item.product.product_name_ar : item.product.product_name_en}</p>
                                <p class="bogo-product-qty">
                                  {currentLanguage === 'ar' ? toArabicNumerals(item.quantity || 1) : (item.quantity || 1)} × 
                                  {#if item.product.unit_qty && item.product.unit_qty > 1}
                                    {currentLanguage === 'ar' ? toArabicNumerals(item.product.unit_qty) : item.product.unit_qty}
                                  {/if}
                                  {currentLanguage === 'ar' ? (item.product.unit_name_ar || 'قطعة') : (item.product.unit_name_en || 'Piece')}
                                </p>
                              </div>
                            </div>
                          </div>
                        {/each}
                      </div>
                      
                      <!-- BOGO Pricing (Match percentage offer style) -->
                      <div class="product-info-overlay">
                        <!-- Sale Price (crossed out) -->
                        {#if media.discountInfo.finalPrice < media.discountInfo.originalPrice}
                          <span class="original-price">
                            {#if currentLanguage === 'ar'}
                              {toArabicNumerals(formatPrice(media.discountInfo.originalPrice))}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                              {formatPrice(media.discountInfo.originalPrice)}
                            {/if}
                          </span>
                        {/if}
                        
                        <!-- Offer Price (large green) -->
                        <div class="offer-price">
                          {#if media.discountInfo.finalPrice < media.discountInfo.originalPrice}
                            {#if currentLanguage === 'ar'}
                              <span class="discounted-price">{toArabicNumerals(formatPrice(media.discountInfo.finalPrice))}</span>
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                              <span class="discounted-price">{formatPrice(media.discountInfo.finalPrice)}</span>
                            {/if}
                          {:else}
                            {#if currentLanguage === 'ar'}
                              <span class="current-price">{toArabicNumerals(formatPrice(media.discountInfo.originalPrice))}</span>
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                            {:else}
                              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                              <span class="current-price">{formatPrice(media.discountInfo.originalPrice)}</span>
                            {/if}
                          {/if}
                        </div>
                        
                        <!-- Expiry Countdown -->
                        {#if media.offerData.end_date}
                          <div class="expiry-countdown">
                            ⏰ {getExpiryCountdown(media.offerData.end_date)}
                          </div>
                        {/if}
                      </div>
                    </div>
                  </div>
                {:else}
                  <!-- Image Display -->
                  <img
                    style="display: {index === currentMediaIndex ? 'block' : 'none'};"
                    src={media.src}
                    alt={media.title}
                    class="media-image"
                  />
                {/if}
              {/each}
              {#if videoError || mediaItems.length === 0}
                <div class="video-fallback">
                  <div class="fallback-content">
                    <div class="fallback-icon">🎬</div>
                    <div class="fallback-title">Coming Soon</div>
                    <div class="fallback-subtitle">Stay tuned for exciting updates!</div>
                  </div>
                </div>
              {/if}
            </div>
          </div>
        </div>
      </section>
    {:else if isVideoHidden}
      <section class="show-video-section">
        <button 
          class="show-video-btn" 
          on:click={showVideo}
          on:touchstart={handleShowVideoTouch}
          type="button"
        >
          <span class="video-icon">📺</span>
          Show Advertisements
        </button>
      </section>
    {/if}

    <!-- Action Buttons -->
    <div class="action-buttons">
      <button class="action-btn primary" on:click={goStartShopping} type="button">
        🛒 {texts.shopNow}
      </button>
    </div>
  </div>
{/if}

<!-- Offer Detail Modal -->
{#if showOfferModal && selectedOffer}
  <OfferDetailModal 
    offer={selectedOffer}
    onClose={closeOfferModal}
  />
{/if}

<style>
  .loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    gap: 1rem;
    background: var(--color-surface);
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 4px solid var(--color-border);
    border-top: 4px solid var(--color-primary);
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .home-container {
    /* Brand palette derived from logo */
    --brand-green: #16a34a; /* primary */
    --brand-green-dark: #15803d;
    --brand-green-light: #22c55e;
    --brand-orange: #f59e0b; /* accent */
    --brand-orange-dark: #d97706;
    --brand-orange-light: #fbbf24;

    /* Remap app variables for this page to brand colors */
    --color-primary: var(--brand-green);
    --color-primary-dark: var(--brand-green-dark);
    --color-accent: var(--brand-orange);

    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: flex-start;
    padding: 1rem 1rem 0 1rem;
    width: 100%;
    height: calc(100vh - 45px);
    max-height: calc(100vh - 45px);
    gap: 1rem;
    position: relative;
    overflow-x: hidden;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    touch-action: pan-y;

    /* Simple neutral background */
    background: #f8fafc;
    position: relative;
    overflow: hidden;
  }

  /* Floating bubbles container */
  .floating-bubbles {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    pointer-events: none;
    z-index: 1;
  }

  /* Individual bubble styles */
  .bubble {
    position: absolute;
    border-radius: 50%;
    pointer-events: none;
    animation-timing-function: ease-in-out;
    animation-iteration-count: infinite;
    animation-fill-mode: both;
    /* Water bubble effects */
    backdrop-filter: blur(2px);
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.4),
      inset 5px 5px 10px rgba(0, 0, 0, 0.1),
      0 0 15px rgba(255, 255, 255, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.5);
  }

  /* Water bubble colors with transparency */
  .bubble-orange { 
    background: radial-gradient(circle at 30% 30%, rgba(255, 200, 100, 0.8), rgba(255, 165, 0, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(255, 100, 0, 0.2),
      0 0 20px rgba(255, 165, 0, 0.4);
  }
  
  .bubble-blue { 
    background: radial-gradient(circle at 30% 30%, rgba(150, 200, 255, 0.8), rgba(0, 123, 255, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(0, 50, 200, 0.2),
      0 0 20px rgba(0, 123, 255, 0.4);
  }
  
  .bubble-green { 
    background: radial-gradient(circle at 30% 30%, rgba(150, 255, 150, 0.8), rgba(40, 167, 69, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(0, 100, 20, 0.2),
      0 0 20px rgba(40, 167, 69, 0.4);
  }
  
  .bubble-pink { 
    background: radial-gradient(circle at 30% 30%, rgba(255, 180, 200, 0.8), rgba(255, 20, 147, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(200, 0, 100, 0.2),
      0 0 20px rgba(255, 20, 147, 0.4);
  }

  /* Individual bubble animations and positions - BIGGER SIZES */
  .bubble-1 {
    width: 25px; height: 25px;
    left: 10%; top: 20%;
    animation: float1 8s infinite;
  }

  .bubble-2 {
    width: 18px; height: 18px;
    left: 80%; top: 15%;
    animation: float2 10s infinite;
  }

  .bubble-3 {
    width: 32px; height: 32px;
    left: 25%; top: 60%;
    animation: float3 12s infinite;
  }

  .bubble-4 {
    width: 22px; height: 22px;
    left: 90%; top: 45%;
    animation: float4 9s infinite;
  }

  .bubble-5 {
    width: 15px; height: 15px;
    left: 15%; top: 80%;
    animation: float5 11s infinite;
  }

  .bubble-6 {
    width: 28px; height: 28px;
    left: 70%; top: 25%;
    animation: float6 7s infinite;
  }

  .bubble-7 {
    width: 20px; height: 20px;
    left: 45%; top: 10%;
    animation: float7 13s infinite;
  }

  .bubble-8 {
    width: 24px; height: 24px;
    left: 60%; top: 75%;
    animation: float8 8s infinite;
  }

  .bubble-9 {
    width: 16px; height: 16px;
    left: 5%; top: 50%;
    animation: float9 10s infinite;
  }

  .bubble-10 {
    width: 30px; height: 30px;
    left: 85%; top: 70%;
    animation: float10 9s infinite;
  }

  .bubble-11 {
    width: 19px; height: 19px;
    left: 35%; top: 30%;
    animation: float11 11s infinite;
  }

  .bubble-12 {
    width: 35px; height: 35px;
    left: 75%; top: 55%;
    animation: float12 7s infinite;
  }

  .bubble-13 {
    width: 12px; height: 12px;
    left: 20%; top: 40%;
    animation: float13 14s infinite;
  }

  .bubble-14 {
    width: 26px; height: 26px;
    left: 95%; top: 20%;
    animation: float14 8s infinite;
  }

  .bubble-15 {
    width: 21px; height: 21px;
    left: 50%; top: 85%;
    animation: float15 12s infinite;
  }

  .bubble-16 {
    width: 17px; height: 17px;
    left: 30%; top: 5%;
    animation: float16 10s infinite;
  }

  .bubble-17 {
    width: 14px; height: 14px;
    left: 65%; top: 90%;
    animation: float17 9s infinite;
  }

  .bubble-18 {
    width: 29px; height: 29px;
    left: 40%; top: 65%;
    animation: float18 11s infinite;
  }

  .bubble-19 {
    width: 13px; height: 13px;
    left: 55%; top: 35%;
    animation: float19 13s infinite;
  }

  .bubble-20 {
    width: 23px; height: 23px;
    left: 12%; top: 70%;
    animation: float20 8s infinite;
  }

  /* Floating animations - each unique */
  @keyframes float1 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(20px, -30px) scale(1.1); }
    50% { transform: translate(-15px, -10px) scale(0.9); }
    75% { transform: translate(10px, -25px) scale(1.05); }
  }

  @keyframes float2 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    33% { transform: translate(-25px, 20px) scale(0.85); }
    66% { transform: translate(15px, -15px) scale(1.15); }
  }

  @keyframes float3 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    20% { transform: translate(30px, 10px) scale(1.2); }
    40% { transform: translate(-20px, -20px) scale(0.8); }
    60% { transform: translate(25px, 15px) scale(1.1); }
    80% { transform: translate(-10px, -5px) scale(0.95); }
  }

  @keyframes float4 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(-30px, -40px) scale(1.3); }
  }

  @keyframes float5 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(15px, -25px) scale(0.7); }
    70% { transform: translate(-20px, 10px) scale(1.4); }
  }

  @keyframes float6 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(-15px, 25px) scale(1.1); }
    75% { transform: translate(20px, -15px) scale(0.9); }
  }

  @keyframes float7 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    40% { transform: translate(25px, 30px) scale(1.2); }
    80% { transform: translate(-15px, -20px) scale(0.8); }
  }

  @keyframes float8 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    35% { transform: translate(-20px, -30px) scale(1.15); }
    65% { transform: translate(30px, 20px) scale(0.85); }
  }

  @keyframes float9 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    45% { transform: translate(35px, -15px) scale(1.3); }
    90% { transform: translate(-25px, 25px) scale(0.7); }
  }

  @keyframes float10 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(-30px, 15px) scale(0.9); }
    60% { transform: translate(20px, -25px) scale(1.2); }
  }

  @keyframes float11 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(10px, 35px) scale(1.1); }
  }

  @keyframes float12 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(-35px, -10px) scale(0.8); }
    75% { transform: translate(15px, 30px) scale(1.25); }
  }

  @keyframes float13 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    40% { transform: translate(20px, -35px) scale(1.4); }
    80% { transform: translate(-30px, 20px) scale(0.6); }
  }

  @keyframes float14 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    33% { transform: translate(25px, 25px) scale(1.1); }
    66% { transform: translate(-20px, -30px) scale(0.9); }
  }

  @keyframes float15 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    20% { transform: translate(-25px, -20px) scale(1.2); }
    80% { transform: translate(30px, 10px) scale(0.8); }
  }

  @keyframes float16 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(-10px, 40px) scale(1.3); }
  }

  @keyframes float17 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    35% { transform: translate(30px, -25px) scale(0.85); }
    70% { transform: translate(-20px, 15px) scale(1.15); }
  }

  @keyframes float18 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(15px, -30px) scale(1.05); }
    75% { transform: translate(-25px, 20px) scale(0.95); }
  }

  @keyframes float19 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    45% { transform: translate(-15px, 30px) scale(1.25); }
    90% { transform: translate(35px, -15px) scale(0.75); }
  }

  @keyframes float20 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(20px, 20px) scale(1.1); }
    70% { transform: translate(-30px, -25px) scale(0.9); }
  }

  /* Action Buttons */
  .action-buttons {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
    justify-content: center;
    width: 100%;
    max-width: 400px;
    position: relative;
    z-index: 10;
  }
  
  .action-btn {
    flex: 1;
    min-width: 140px;
    border: none;
    border-radius: 16px;
    padding: 1.25rem 1.5rem;
    font-size: 1.05rem;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    position: relative;
    z-index: 10;
    overflow: hidden;
  }

  .action-btn::before {
    content: '';
    position: absolute;
    top: 50%;
    left: 50%;
    width: 0;
    height: 0;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.3);
    transform: translate(-50%, -50%);
    transition: width 0.6s, height 0.6s;
  }

  .action-btn:active::before {
    width: 300px;
    height: 300px;
  }
  
  .action-btn.primary {
    background: linear-gradient(135deg, var(--brand-green) 0%, var(--brand-green-dark) 100%);
    color: #fff;
    box-shadow: 0 8px 24px rgba(22, 163, 74, 0.35),
                0 0 30px rgba(22, 163, 74, 0.15);
    animation: heartbeat 1.5s ease-in-out infinite;
  }

  @keyframes heartbeat {
    0%, 100% {
      transform: scale(1);
    }
    10% {
      transform: scale(1.05);
    }
    20% {
      transform: scale(1);
    }
    30% {
      transform: scale(1.05);
    }
    40% {
      transform: scale(1);
    }
  }
  
  .action-btn.secondary {
    background: linear-gradient(135deg, #ffffff 0%, #fef3c7 100%);
    color: var(--brand-orange-dark);
    border: 3px solid var(--brand-orange);
    box-shadow: 0 6px 20px rgba(245, 158, 11, 0.25),
                0 0 25px rgba(245, 158, 11, 0.12);
  }

  .action-btn:active {
    transform: scale(0.96);
  }
  
  .action-btn.primary:hover {
    background: linear-gradient(135deg, var(--brand-green-light) 0%, var(--brand-green) 100%);
    transform: translateY(-3px);
    box-shadow: 0 12px 28px rgba(22, 163, 74, 0.40),
                0 0 40px rgba(22, 163, 74, 0.20);
  }
  
  .action-btn.secondary:hover {
    background: linear-gradient(135deg, #fef3c7 0%, var(--brand-orange-light) 100%);
    border-color: var(--brand-orange-dark);
    transform: translateY(-3px);
    box-shadow: 0 8px 24px rgba(245, 158, 11, 0.35),
                0 0 35px rgba(245, 158, 11, 0.18);
  }

  /* Advertisement LED Screen Styles */
  .advertisement-section {
    margin: 0;
    padding: 0;
    width: 100%;
    position: relative;
    top: 0;
    z-index: 10;
    flex-shrink: 0;
  }

  .led-screen-container {
    position: relative;
    width: 100%;
    max-width: 280px;
    margin: 0 auto;
  }

  .led-frame {
    position: relative;
    background: #000;
    padding: 8px;
    border-radius: 20px;
    box-shadow: 0 0 30px rgba(0, 0, 0, 0.5);
    border: 2px solid #333;
  }

  .video-content {
    position: relative;
    width: 100%;
    height: 420px;
    aspect-ratio: 9/16;
    border-radius: 12px;
    overflow: hidden;
    background: #000 !important;
    isolation: isolate;
    margin: 0;
    padding: 0;
  }

  .video-content video {
    width: 100%;
    height: 100%;
    object-fit: cover;
    cursor: pointer;
    transition: transform 0.3s ease;
    position: absolute;
    top: 0;
    left: 0;
    z-index: 1;
    border-radius: 12px;
  }

  /* Offer Card in LED Screen */
  .offer-card-display {
    width: 100%;
    height: 100%;
    position: absolute;
    top: 0;
    left: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #FFD700 0%, #FFA500 100%);
    z-index: 2;
  }

  .offer-card-content {
    width: 100%;
    height: 100%;
    position: relative;
    display: flex;
    flex-direction: column;
  }

  .offer-image {
    width: 100%;
    height: 70%;
    object-fit: cover;
  }

  .offer-placeholder {
    width: 100%;
    height: 70%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #667EEA 0%, #764BA2 100%);
  }

  .offer-emoji {
    font-size: 6rem;
    animation: bounce 2s ease-in-out infinite;
  }

  @keyframes bounce {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-10px); }
  }

  .offer-info-overlay {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    padding: 1.5rem;
    background: linear-gradient(to top, rgba(0, 0, 0, 0.9), rgba(0, 0, 0, 0.7));
    color: white;
    text-align: center;
  }

  .offer-title {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 0 0 0.5rem 0;
    color: #FFD700;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
  }

  .offer-desc {
    font-size: 1rem;
    margin: 0 0 1rem 0;
    line-height: 1.4;
    color: rgba(255, 255, 255, 0.9);
  }

  .shop-now-btn {
    background: linear-gradient(135deg, #10B981 0%, #059669 100%);
    color: white;
    border: none;
    padding: 0.75rem 2rem;
    border-radius: 25px;
    font-size: 1rem;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
  }

  .shop-now-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(16, 185, 129, 0.6);
  }

  .shop-now-btn:active {
    transform: translateY(0);
  }

  /* Product Card in LED Screen (from offers) */
  .product-card-display {
    width: 100%;
    height: 100%;
    position: absolute;
    top: 0;
    left: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: white;
    z-index: 2;
    overflow: hidden;
  }

  /* Moving Watermark Logo */
  .watermark-logo {
    position: absolute;
    width: 120px;
    height: auto;
    opacity: 0.5;
    z-index: 1;
    pointer-events: none;
    animation: floatUpward 10s infinite linear;
    left: 50%;
    transform: translateX(-50%);
  }

  .watermark-image {
    width: 100%;
    height: auto;
    object-fit: contain;
    display: block;
  }

  @keyframes floatUpward {
    0% {
      bottom: -100px;
    }
    100% {
      bottom: 100%;
    }
  }

  .product-card-content {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
    gap: 1rem;
    background: transparent;
    position: relative;
    z-index: 2;
  }

  .product-image-wrapper {
    position: relative;
    width: 120px;
    height: 120px;
    flex-shrink: 0;
  }

  /* Smaller images for bundle products */
  .product-image-wrapper.bundle-product {
    width: 100px;
    height: 100px;
  }

  .product-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    background: white;
    border-radius: 16px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }
  
  /* Bundle offer indicator */
  .product-card-display.bundle-offer .product-card-content {
    gap: 1rem;
  }

  .product-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #F59E0B 0%, #EF4444 100%);
    border-radius: 16px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .product-emoji {
    font-size: 4rem;
    animation: pulse 2s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.1); }
  }

  .discount-badge {
    position: absolute;
    top: -0.5rem;
    right: -0.5rem;
    background: linear-gradient(135deg, #EF4444 0%, #DC2626 100%);
    color: white;
    padding: 0.3rem 0.6rem;
    border-radius: 12px;
    font-weight: 700;
    font-size: 0.75rem;
    box-shadow: 0 2px 8px rgba(239, 68, 68, 0.4);
    z-index: 10;
  }

  .badge-text {
    text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.3);
  }

  .usage-limit-badge {
    position: absolute;
    bottom: -0.5rem;
    left: 50%;
    transform: translateX(-50%);
    background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%);
    color: white;
    padding: 0.35rem 0.75rem;
    border-radius: 12px;
    font-weight: 700;
    font-size: 0.75rem;
    box-shadow: 0 2px 8px rgba(245, 158, 11, 0.4);
    z-index: 10;
    white-space: nowrap;
  }

  .usage-text {
    text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.3);
  }

  .product-info-overlay {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 0.75rem;
    width: 100%;
  }

  .offer-tag {
    display: flex;
    align-items: center;
    justify-content: flex-start;
    gap: 0.5rem;
    background: #FEF3C7;
    padding: 0.5rem 1rem;
    border-radius: 12px;
    border: 2px solid #FCD34D;
    align-self: flex-start;
  }

  .offer-tag .offer-emoji {
    font-size: 1.3rem;
    animation: none;
  }

  .offer-name {
    font-size: 1rem;
    font-weight: 700;
    color: #B45309;
  }

  .product-title {
    font-size: 1.35rem;
    font-weight: 700;
    margin: 0;
    color: #059669;
    line-height: 1.2;
    max-width: 100%;
    word-wrap: break-word;
  }

  .unit-details {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.9rem;
    color: #EA580C;
    font-weight: 500;
    padding: 0.4rem 0.8rem;
    background: #FFF7ED;
    border-radius: 8px;
  }

  .original-price {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 1.3rem;
    color: #EF4444;
    position: relative;
    font-weight: 600;
  }
  
  .original-price::after {
    content: '';
    position: absolute;
    left: -2px;
    right: -2px;
    top: 50%;
    height: 1.5px;
    background: linear-gradient(to bottom right, #EF4444 0%, #EF4444 100%);
    transform: translateY(-50%) rotate(-10deg);
    transform-origin: center;
  }

  .offer-price {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.3rem;
    padding: 0.6rem 1.2rem;
    background: #F0FDF4;
    border: 2px solid #059669;
    border-radius: 12px;
  }

  .expiry-countdown {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.2rem;
    font-size: 0.55rem;
    font-weight: 600;
    color: #DC2626;
    background: linear-gradient(135deg, #FEF2F2 0%, #FEE2E2 100%);
    border: 1px solid #FCA5A5;
    border-radius: 4px;
    padding: 0.2rem 0.4rem;
    box-shadow: 0 1px 2px rgba(220, 38, 38, 0.08);
    margin-top: 0.25rem;
    animation: heartbeat 1.5s ease-in-out infinite;
  }

  @keyframes heartbeat {
    0%, 100% { 
      transform: scale(1);
      box-shadow: 0 1px 2px rgba(220, 38, 38, 0.08);
    }
    10% { 
      transform: scale(1.05);
      box-shadow: 0 2px 4px rgba(220, 38, 38, 0.15);
    }
    20% { 
      transform: scale(1);
      box-shadow: 0 1px 2px rgba(220, 38, 38, 0.08);
    }
    30% { 
      transform: scale(1.05);
      box-shadow: 0 2px 4px rgba(220, 38, 38, 0.15);
    }
    40%, 100% { 
      transform: scale(1);
      box-shadow: 0 1px 2px rgba(220, 38, 38, 0.08);
    }
  }

  .discounted-price {
    font-size: 1.75rem;
    font-weight: 900;
    color: #059669;
    line-height: 1;
  }

  .current-price {
    font-size: 1.75rem;
    font-weight: 900;
    color: #111827;
    line-height: 1;
  }

  .currency {
    font-size: 1rem;
    font-weight: 600;
    color: #059669;
  }

  .currency-icon {
    width: 20px;
    height: 20px;
    object-fit: contain;
    vertical-align: middle;
  }

  .currency-icon-small {
    width: 14px;
    height: 14px;
    object-fit: contain;
    vertical-align: middle;
  }

  /* Bundle Card Styles */
  .bundle-offer-card {
    background: linear-gradient(135deg, #F0FDF4 0%, #ECFDF5 100%);
    max-height: 100%;
    overflow: hidden;
  }

  .bundle-card-content {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: space-between;
    padding: 3rem 1rem 1rem 1rem;
    gap: 0.6rem;
    position: relative;
    z-index: 2;
  }

  .bundle-products-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.6rem;
    width: 100%;
    max-width: 100%;
    padding: 0;
    flex-shrink: 0;
  }

  .bundle-product-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.3rem;
    background: white;
    padding: 0.4rem;
    border-radius: 8px;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
    min-height: 0;
  }

  .bundle-product-image-wrapper {
    width: 55px;
    height: 55px;
    flex-shrink: 0;
    border-radius: 6px;
    overflow: hidden;
    position: relative;
  }

  .product-discount-tag {
    position: absolute;
    top: 3px;
    right: 3px;
    background: #EF4444;
    border-radius: 4px;
    padding: 3px 5px;
    z-index: 10;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  .product-discount-tag .tag-text {
    font-size: 0.7rem;
    font-weight: 700;
    color: white;
    line-height: 1;
    display: block;
  }

  .bundle-product-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .product-placeholder-small {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #F59E0B 0%, #EF4444 100%);
  }

  .product-emoji-small {
    font-size: 2.5rem;
  }

  .bundle-product-info {
    text-align: center;
    width: 100%;
    min-height: 0;
  }

  .bundle-product-name {
    font-size: 0.65rem;
    font-weight: 600;
    color: #111827;
    margin: 0;
    line-height: 1.1;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    max-height: 2.2em;
  }

  .bundle-product-qty {
    font-size: 0.5rem;
    color: #EA580C;
    font-weight: 500;
    margin: 0.15rem 0 0 0;
    padding: 0.12rem 0.3rem;
    background: #FFF7ED;
    border-radius: 4px;
    display: inline-block;
    line-height: 1.1;
  }

  .bundle-pricing {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.3rem;
    padding: 0.5rem 0.9rem;
    background: white;
    border-radius: 8px;
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.1);
  }

  .bundle-original-price {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.75rem;
    color: #EF4444;
    text-decoration: line-through;
    text-decoration-color: #059669;
    text-decoration-thickness: 2px;
    font-weight: 500;
  }

  .bundle-final-price {
    display: flex;
    align-items: center;
    gap: 0.3rem;
  }

  .bundle-discounted-price {
    font-size: 1.4rem;
    font-weight: 900;
    color: #059669;
    line-height: 1;
  }

  .bundle-badge {
    top: 1rem;
    right: 1rem;
  }

  /* BOGO Offer Styles */
  .bogo-offer-card {
    background: linear-gradient(135deg, #FEF3C7 0%, #FDE68A 100%);
  }

  .bogo-card-content {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1rem;
    gap: 0.4rem;
    position: relative;
    z-index: 2;
  }

  .bogo-badge {
    top: 0.75rem;
    right: 0.75rem;
    background: #F59E0B;
  }

  .bogo-products-container {
    display: flex;
    gap: 0.6rem;
    align-items: center;
    justify-content: center;
    width: 100%;
  }

  .bogo-product-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.35rem;
  }

  .bogo-label {
    font-size: 0.7rem;
    font-weight: 700;
    padding: 0.25rem 0.6rem;
    border-radius: 5px;
    text-align: center;
  }

  .buy-label {
    color: #1F2937;
    background: white;
    padding: 0.25rem 0.6rem;
    border-radius: 5px;
    display: inline-block;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .get-label {
    color: white;
    background: #10B981;
    padding: 0.25rem 0.6rem;
    border-radius: 5px;
    display: inline-block;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .bogo-product-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.3rem;
    background: white;
    padding: 0.5rem;
    border-radius: 8px;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
    min-width: 90px;
  }

  .bogo-product-image-wrapper {
    width: 60px;
    height: 60px;
    flex-shrink: 0;
    border-radius: 6px;
    overflow: hidden;
    position: relative;
  }

  .bogo-product-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .product-placeholder-medium {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #F59E0B 0%, #EF4444 100%);
    border-radius: 8px;
  }

  .product-emoji-medium {
    font-size: 2.5rem;
  }

  .free-tag {
    background: #10B981;
  }

  .bogo-product-info {
    text-align: center;
    width: 100%;
  }

  .bogo-product-name {
    font-size: 0.7rem;
    font-weight: 600;
    color: #111827;
    margin: 0;
    line-height: 1.2;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .bogo-product-qty {
    font-size: 0.55rem;
    color: #EA580C;
    font-weight: 500;
    margin: 0.15rem 0 0 0;
    padding: 0.15rem 0.35rem;
    background: #FFF7ED;
    border-radius: 4px;
    display: inline-block;
    line-height: 1.2;
  }

  .bogo-pricing {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
    padding: 0.5rem 0.8rem;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .bogo-original-price {
    display: flex;
    align-items: center;
    gap: 0.2rem;
    font-size: 0.7rem;
    color: #EF4444;
    text-decoration: line-through;
    text-decoration-color: #10B981;
    text-decoration-thickness: 2px;
    font-weight: 500;
  }

  .bogo-final-price {
    display: flex;
    align-items: center;
    gap: 0.3rem;
  }

  .bogo-discounted-price {
    font-size: 1.35rem;
    font-weight: 900;
    color: #10B981;
    line-height: 1;
  }

  /* Media Image */
  .media-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    position: absolute;
    top: 0;
    left: 0;
    z-index: 1;
    border-radius: 12px;
  }

  .video-content:hover video {
    transform: scale(1.02);
  }

  .video-fallback {
    width: 100%;
    height: 100%;
    position: absolute;
    top: 0;
    left: 0;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(45deg, #1a1a1a, #2d2d2d);
    transition: transform 0.3s ease;
    z-index: 2;
  }

  .video-fallback:hover {
    transform: scale(1.02);
  }

  .fallback-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    z-index: 2;
    color: var(--color-primary);
  }

  .fallback-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
    opacity: 0.8;
  }

  .fallback-title {
    font-size: 1.2rem;
    font-weight: bold;
    margin-bottom: 0.5rem;
    text-shadow: 0 0 10px var(--color-primary);
  }

  .fallback-subtitle {
    font-size: 0.9rem;
    opacity: 0.7;
    font-style: italic;
  }

  .hide-btn {
    position: absolute;
    top: 0.5rem;
    left: 0.5rem;
    background: rgba(239, 68, 68, 0.9);
    color: white;
    border: none;
    border-radius: 50%;
    width: 36px;
    height: 36px;
    font-size: 1rem;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
    backdrop-filter: blur(10px);
    box-shadow: 0 2px 8px rgba(239, 68, 68, 0.5);
  }

  .hide-btn:hover {
    background: rgba(220, 38, 38, 1);
    transform: scale(1.1);
    box-shadow: 0 4px 12px rgba(239, 68, 68, 0.7);
  }

  .hide-btn span {
    text-shadow: 0 0 5px #ef4444;
    font-weight: bold;
  }

  /* Show Video Section Styles */
  .show-video-section {
    margin: 2rem 0;
    padding: 0;
    text-align: center;
    width: 100%;
    max-width: 400px;
  }

  .show-video-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.75rem;
    padding: 1rem 2rem;
    background: linear-gradient(45deg, #1a1a1a, #2d2d2d);
    color: var(--color-primary);
    border: 2px solid var(--color-primary);
    border-radius: 12px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 0 20px rgba(16, 179, 0, 0.3);
    text-shadow: 0 0 5px var(--color-primary);
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    position: relative;
    z-index: 10;
  }

  .show-video-btn:active {
    transform: scale(0.95);
    box-shadow: 0 0 15px rgba(16, 179, 0, 0.4);
  }

  .show-video-btn:hover {
    background: linear-gradient(45deg, #2d2d2d, #1a1a1a);
    transform: translateY(-2px);
    box-shadow: 0 0 30px rgba(16, 179, 0, 0.5);
  }

  .video-icon {
    font-size: 1.2rem;
    filter: brightness(1.2);
  }

  .led-dots {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-image: 
      radial-gradient(circle at 2px 2px, rgba(255, 255, 255, 0.1) 1px, transparent 1px);
    background-size: 8px 8px;
    pointer-events: none;
    opacity: 0.1;
    z-index: 2;
  }

  .screen-glow {
    position: absolute;
    top: -5px;
    left: -5px;
    right: -5px;
    bottom: -5px;
    background: linear-gradient(45deg, var(--color-primary), var(--color-accent), var(--color-primary));
    border-radius: 16px;
    opacity: 0.2;
    filter: blur(8px);
    z-index: -1;
    animation: screenGlow 3s ease-in-out infinite;
  }

  @keyframes screenGlow {
    0%, 100% { opacity: 0.2; }
    50% { opacity: 0.4; }
  }

  .category-selection-section {
    margin-bottom: 1.5rem;
  }

  .category-subtitle {
    font-size: 1rem;
    color: var(--color-ink-light);
    line-height: 1.5;
    text-align: center;
    margin-bottom: 1rem;
    margin-top: 0;
  }

  .all-products-btn {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.75rem;
    padding: 1.25rem;
    background: linear-gradient(135deg, var(--brand-green) 0%, var(--brand-green-light) 100%);
    color: white;
    border: none;
    border-radius: 16px;
    font-size: 1.15rem;
    font-weight: 700;
    margin-bottom: 1.5rem;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 6px 20px rgba(22, 163, 74, 0.30),
                0 0 30px rgba(22, 163, 74, 0.15);
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    position: relative;
    z-index: 10;
    overflow: hidden;
  }

  .all-products-btn::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.3), transparent);
    transition: left 0.5s;
  }

  .all-products-btn:hover::before {
    left: 100%;
  }

  .all-products-btn:hover {
    background: linear-gradient(135deg, var(--brand-green-light) 0%, var(--brand-green) 100%);
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(22, 163, 74, 0.40),
                0 0 40px rgba(22, 163, 74, 0.20);
  }

  .all-products-btn:active {
    transform: translateY(0) scale(0.98);
  }

  .btn-icon {
    font-size: 1.5rem;
  }

  .categories-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }

  .category-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1.5rem 1rem;
    background: linear-gradient(135deg, #ffffff 0%, #fefefe 100%);
    border: 2px solid transparent;
    border-radius: 20px;
    cursor: pointer;
    transition: all 0.3s ease;
    text-decoration: none;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08),
                inset 0 1px 0 rgba(255, 255, 255, 0.9);
    min-height: 120px;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    position: relative;
    z-index: 10;
    overflow: hidden;
  }

  .category-card::before {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.05) 0%, rgba(245, 158, 11, 0.05) 100%);
    opacity: 0;
    transition: opacity 0.3s ease;
    border-radius: 20px;
  }

  .category-card:hover::before {
    opacity: 1;
  }

  .category-card:hover {
    border-color: var(--brand-green);
    transform: translateY(-4px) scale(1.02);
    box-shadow: 0 8px 24px rgba(22, 163, 74, 0.20),
                0 0 30px rgba(22, 163, 74, 0.10),
                inset 0 1px 0 rgba(255, 255, 255, 1);
  }

  .category-card:active {
    transform: translateY(-2px) scale(0.99);
  }

  .category-icon {
    font-size: 3rem;
    margin-bottom: 0.75rem;
    filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.1));
    transition: transform 0.3s ease;
  }

  .category-card:hover .category-icon {
    transform: scale(1.15) rotate(5deg);
  }

  .category-card h3 {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--color-ink);
    text-align: center;
    line-height: 1.3;
    margin: 0;
  }

  /* Mobile optimizations */
  @media (max-width: 480px) {
    .home-container {
      padding: 0.75rem 1rem 0 1rem;
      gap: 0.75rem;
      width: 100%;
      height: calc(100vh - 45px);
      max-height: calc(100vh - 45px);
    }

    /* Smaller bubbles on mobile */
    .bubble {
      transform: scale(0.6);
      box-shadow: 
        inset -3px -3px 6px rgba(255, 255, 255, 0.4),
        inset 3px 3px 6px rgba(0, 0, 0, 0.1),
        0 0 8px rgba(255, 255, 255, 0.3);
    }

    .advertisement-section {
      margin: 0;
    }
    
    .led-screen-container {
      max-width: 240px;
    }
    
    .video-content {
      height: 360px;
    }

    .led-screen-container {
      max-width: 250px;
    }

    .video-content {
      height: 400px;
    }

    .hide-btn {
      width: 35px;
      height: 35px;
      font-size: 0.9rem;
      top: 0.5rem;
      left: 0.5rem;
    }

    .show-video-btn {
      padding: 0.75rem 1.5rem;
      font-size: 0.9rem;
    }

    .led-frame {
      padding: 6px;
      margin: 0 auto;
    }

    .action-buttons {
      gap: 0.75rem;
      padding: 0 0.5rem;
    }

    .action-btn {
      min-width: 120px;
      padding: 0.875rem 1.25rem;
      font-size: 0.95rem;
    }

    .category-card {
      padding: 1.25rem 0.75rem;
      min-height: 110px;
    }

    .category-icon {
      font-size: 2.25rem;
      margin-bottom: 0.5rem;
    }

    .category-card h3 {
      font-size: 0.85rem;
    }
  }

  /* Tablet and larger screens */
  @media (min-width: 768px) {
    .home-container {
      max-width: 1200px;
      padding: 0 2rem;
      gap: 2rem;
      margin: 0 auto;
      height: 100vh;
      max-height: 100vh;
    }

    .categories-grid {
      grid-template-columns: repeat(3, 1fr);
      gap: 1.5rem;
    }

    .category-card {
      padding: 2rem 1.5rem;
      min-height: 140px;
    }

    .category-icon {
      font-size: 3rem;
      margin-bottom: 1rem;
    }

    .category-card h3 {
      font-size: 1rem;
    }
  }

  @media (min-width: 1024px) {
    .categories-grid {
      grid-template-columns: repeat(4, 1fr);
    }
  }
</style>
