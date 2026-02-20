<script lang="ts">
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { userStore, userActions } from '$lib/stores/user.js';
  import { supabase } from '$lib/utils/supabase';
  import FeaturedOffers from '$lib/components/customer-interface/shopping/FeaturedOffers.svelte';
  import OfferDetailModal from '$lib/components/customer-interface/shopping/OfferDetailModal.svelte';
  import LocationPicker from '$lib/components/desktop-interface/admin-customer-app/LocationPicker.svelte';

  let currentLanguage = 'ar';
  let videoContainer;

  // Location setup state
  let showLocationSetupModal = false;
  let pickedLocation = null;
  let customLocationName = '';
  let savingLocation = false;
  let customerId = '';
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

  // Check if customer has at least one saved location
  async function checkCustomerLocation() {
    try {
      const session = localStorage.getItem('customer_session');
      if (!session) return;
      const parsed = JSON.parse(session);
      customerId = parsed?.customer_id;
      if (!customerId) return;

      const { data, error } = await supabase
        .from('customers')
        .select('location1_lat, location1_lng, location2_lat, location2_lng, location3_lat, location3_lng')
        .eq('id', customerId)
        .single();

      if (error) {
        console.error('❌ [Home] Error checking locations:', error);
        return;
      }

      // Check if at least one location has lat/lng
      const hasLocation = (data.location1_lat && data.location1_lng) ||
                          (data.location2_lat && data.location2_lng) ||
                          (data.location3_lat && data.location3_lng);

      if (!hasLocation) {
        console.log('📍 [Home] No saved locations, showing location setup modal');
        showLocationSetupModal = true;
      }
    } catch (e) {
      console.error('❌ [Home] Exception checking location:', e);
    }
  }

  function handleLocationPicked(location) {
    pickedLocation = location;
  }

  async function saveSetupLocation() {
    if (!pickedLocation || !customerId) return;

    const locationName = customLocationName.trim() || pickedLocation.name;

    try {
      savingLocation = true;
      const { error } = await supabase
        .from('customers')
        .update({
          location1_name: locationName,
          location1_url: pickedLocation.url,
          location1_lat: pickedLocation.lat,
          location1_lng: pickedLocation.lng,
        })
        .eq('id', customerId);

      if (error) {
        console.error('❌ [Home] Failed to save location:', error);
        alert(currentLanguage === 'ar' ? 'فشل حفظ الموقع' : 'Failed to save location');
      } else {
        showLocationSetupModal = false;
        pickedLocation = null;
        customLocationName = '';
      }
    } catch (e) {
      console.error('❌ [Home] Exception saving location:', e);
      alert(currentLanguage === 'ar' ? 'حدث خطأ غير متوقع' : 'Unexpected error');
    } finally {
      savingLocation = false;
    }
  }

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }

    // Check authentication and load user data
    const isAuthenticated = userActions.loadFromStorage();
    if (!isAuthenticated) {
      goto("/customer-interface/login");
      return;
    }

    // Check if customer has at least one saved location
    await checkCustomerLocation();

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
    title: 'الرئيسية - ايربن ماركت',
    greeting: `مرحباً ${userName}`,
    shopNow: 'ابدأ التسوق',
    support: 'الدعم والمساعدة',
    startSubtitle: 'اكتشف العروض والمنتجات المميزة',
    specialOffers: 'العروض المميزة',
    browseCategories: 'تصفح الأقسام',
    allProducts: 'جميع المنتجات',
    showAds: 'عرض الإعلانات',
  } : {
    title: 'Home - Urban Market',
    greeting: `Welcome ${userName}`,
    shopNow: 'Shop Now',
    support: 'Support',
    startSubtitle: 'Discover deals & featured products',
    specialOffers: 'Special Offers',
    browseCategories: 'Browse Categories',
    allProducts: 'All Products',
    showAds: 'Show Ads',
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
    goto("/customer-interface/login");
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
  </div>
{:else}
  <div class="home-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Soft ambient background shapes -->
    <div class="ambient-bg">
      <div class="ambient-shape shape-1"></div>
      <div class="ambient-shape shape-2"></div>
      <div class="ambient-shape shape-3"></div>
    </div>

    <!-- Hero Header with Logo -->
    <header class="hero-header">
      <div class="logo-container">
        <img src="/icons/logo.png" alt="Urban Market" class="hero-logo" />
      </div>
      <h1 class="hero-title">{texts.greeting}</h1>
      <p class="hero-subtitle">{texts.startSubtitle}</p>
    </header>

    <!-- Shop Now CTA -->
    <div class="cta-section">
      <button class="cta-btn" on:click={goStartShopping} type="button">
        <span class="cta-icon">🛒</span>
        <span>{texts.shopNow}</span>
        <svg class="cta-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <path d="M5 12h14M12 5l7 7-7 7" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
    </div>

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
      <div class="show-ads-toggle">
        <button 
          class="show-ads-btn" 
          on:click={showVideo}
          on:touchstart={handleShowVideoTouch}
          type="button"
        >
          <span class="show-ads-icon">📺</span>
          <span>{texts.showAds}</span>
        </button>
      </div>
    {/if}

  </div>
{/if}

<!-- Offer Detail Modal -->
{#if showOfferModal && selectedOffer}
  <OfferDetailModal 
    offer={selectedOffer}
    onClose={closeOfferModal}
  />
{/if}

<!-- Location Setup Modal (shown when customer has no saved locations) -->
{#if showLocationSetupModal}
  <div class="loc-setup-overlay">
    <div class="loc-setup-modal">
      <div class="loc-setup-header">
        <h3>📍 {currentLanguage === 'ar' ? 'حدد موقعك' : 'Set Your Location'}</h3>
      </div>
      <div class="loc-setup-notice">
        <span class="loc-setup-notice-icon">ℹ️</span>
        <p>{currentLanguage === 'ar' ? 'يرجى تحديد موقع التوصيل الخاص بك للمتابعة' : 'Please set your delivery location to continue'}</p>
      </div>
      <div class="loc-setup-body">
        <LocationPicker
          initialLat={24.7136}
          initialLng={46.6753}
          onLocationSelect={handleLocationPicked}
          language={currentLanguage}
        />
        {#if pickedLocation}
          <div class="picked-location-info">
            <label for="setup-location-name" class="location-name-label">
              {currentLanguage === 'ar' ? 'اسم الموقع (اختياري)' : 'Location Name (optional)'}
            </label>
            <input
              id="setup-location-name"
              type="text"
              bind:value={customLocationName}
              placeholder={currentLanguage === 'ar' ? 'مثل: المنزل، المكتب' : 'e.g. Home, Office'}
              class="location-name-input"
            />
            <p class="location-address-label"><strong>{currentLanguage === 'ar' ? 'العنوان:' : 'Address:'}</strong></p>
            <p class="location-address">{pickedLocation.name}</p>
            <p class="location-coords">{pickedLocation.lat.toFixed(6)}, {pickedLocation.lng.toFixed(6)}</p>
          </div>
        {/if}
      </div>
      <div class="loc-setup-footer">
        <button class="loc-save-btn" disabled={!pickedLocation || savingLocation} on:click={saveSetupLocation}>
          {savingLocation ? (currentLanguage === 'ar' ? 'جاري الحفظ...' : 'Saving...') : (currentLanguage === 'ar' ? '✅ حفظ الموقع والمتابعة' : '✅ Save Location & Continue')}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  /* ===== Location Setup Modal ===== */
  .loc-setup-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.7);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 99999;
    padding: 1rem;
  }
  .loc-setup-modal {
    background: white;
    border-radius: 16px;
    width: 100%;
    max-width: 500px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
    overflow: hidden;
  }
  .loc-setup-header {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #e5e7eb;
    background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
  }
  .loc-setup-header h3 {
    margin: 0;
    font-size: 1.1rem;
    color: #16a34a;
    font-weight: 700;
  }
  .loc-setup-notice {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1.25rem;
    background: #fffbeb;
    border-bottom: 1px solid #fde68a;
  }
  .loc-setup-notice-icon {
    font-size: 1.1rem;
    flex-shrink: 0;
  }
  .loc-setup-notice p {
    margin: 0;
    font-size: 0.8rem;
    color: #92400e;
    font-weight: 500;
  }
  .loc-setup-body {
    flex: 1;
    overflow-y: auto;
    padding: 1.25rem;
  }
  .loc-setup-footer {
    padding: 1rem 1.25rem;
    border-top: 1px solid #e5e7eb;
  }
  .loc-save-btn {
    width: 100%;
    padding: 0.875rem;
    border-radius: 10px;
    font-size: 0.95rem;
    font-weight: 700;
    background: linear-gradient(135deg, #16a34a 0%, #22c55e 100%);
    color: white;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .loc-save-btn:hover:not(:disabled) {
    background: linear-gradient(135deg, #15803d 0%, #16a34a 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(22, 163, 74, 0.3);
  }
  .loc-save-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .picked-location-info {
    margin-top: 1rem;
    padding: 1rem;
    background: #f0fdf4;
    border-radius: 8px;
    border: 1px solid #bbf7d0;
  }
  .location-name-label {
    display: block;
    font-size: 0.75rem;
    font-weight: 600;
    color: #16a34a;
    margin-bottom: 0.5rem;
  }
  .location-name-input {
    width: 100%;
    padding: 0.625rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 0.875rem;
    margin-bottom: 0.75rem;
    box-sizing: border-box;
  }
  .location-name-input:focus {
    outline: none;
    border-color: #16a34a;
    box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.1);
  }
  .location-address-label {
    font-size: 0.75rem;
    margin: 0 0 0.25rem 0;
    color: #16a34a;
  }
  .location-address {
    font-size: 0.8rem;
    color: #374151;
    margin: 0 0 0.5rem 0;
  }
  .location-coords {
    font-size: 0.7rem;
    color: #6b7280;
    margin: 0;
    font-family: monospace;
  }

  /* ===== Brand Palette ===== */
  :root {
    --green: #16a34a;
    --green-dark: #15803d;
    --green-light: #22c55e;
    --orange: #f59e0b;
    --orange-dark: #d97706;
  }

  /* ===== Loading ===== */
  .loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    gap: 1rem;
    background: #f0fdf4;
  }

  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid #e5e7eb;
    border-top-color: var(--green);
    border-radius: 50%;
    animation: spin 0.7s linear infinite;
  }

  @keyframes spin { to { transform: rotate(360deg); } }

  /* ===== Page Container ===== */
  .home-container {
    position: relative;
    width: 100%;
    min-height: calc(100vh - 45px);
    overflow-x: hidden;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    background: #f8fafc;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding-bottom: 2rem;
  }

  /* ===== Ambient Background ===== */
  .ambient-bg {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 0;
    overflow: hidden;
  }

  .ambient-shape {
    position: absolute;
    border-radius: 50%;
    opacity: 0.18;
    filter: blur(60px);
  }

  .shape-1 { width: 260px; height: 260px; background: #4ade80; top: -80px; right: -40px; animation: drift 20s ease-in-out infinite alternate; }
  .shape-2 { width: 220px; height: 220px; background: #fbbf24; bottom: 10%; left: -60px; animation: drift 25s ease-in-out infinite alternate-reverse; }
  .shape-3 { width: 200px; height: 200px; background: #86efac; top: 40%; right: 20%; animation: drift 18s ease-in-out infinite alternate; }

  @keyframes drift {
    0% { transform: translate(0, 0) scale(1); }
    100% { transform: translate(30px, 20px) scale(1.08); }
  }

  /* ===== Hero Header ===== */
  .hero-header {
    position: relative;
    z-index: 10;
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 1.75rem 1.5rem 1.25rem;
    background: linear-gradient(170deg, var(--green) 0%, var(--green-dark) 100%);
    border-radius: 0 0 32px 32px;
    box-shadow: 0 8px 32px rgba(22, 163, 74, 0.3);
  }

  .logo-container {
    width: 64px;
    height: 64px;
    background: white;
    border-radius: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.15);
    margin-bottom: 0.6rem;
    animation: logoEntry 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  @keyframes logoEntry {
    0% { opacity: 0; transform: scale(0.5) translateY(20px); }
    100% { opacity: 1; transform: scale(1) translateY(0); }
  }

  .hero-logo {
    width: 46px;
    height: 46px;
    object-fit: contain;
  }

  .hero-title {
    margin: 0;
    font-size: 1.35rem;
    font-weight: 800;
    color: white;
    text-align: center;
    line-height: 1.3;
  }

  .hero-subtitle {
    margin: 0.3rem 0 0;
    font-size: 0.82rem;
    color: rgba(255, 255, 255, 0.85);
    font-weight: 500;
    text-align: center;
  }

  /* ===== CTA Section ===== */
  .cta-section {
    position: relative;
    z-index: 10;
    width: 100%;
    max-width: 420px;
    padding: 1rem 1rem 0;
  }

  .cta-btn {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.6rem;
    padding: 0.9rem 1.5rem;
    background: linear-gradient(135deg, var(--green) 0%, var(--green-light) 100%);
    color: white;
    border: none;
    border-radius: 14px;
    font-size: 1.05rem;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 6px 20px rgba(22, 163, 74, 0.30);
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    position: relative;
    overflow: hidden;
  }

  .cta-btn::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.25), transparent);
    animation: shimmer 3s infinite;
  }

  @keyframes shimmer {
    0% { left: -100%; }
    100% { left: 100%; }
  }

  .cta-btn:active { transform: scale(0.97); }
  .cta-btn:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(22, 163, 74, 0.40); }

  .cta-icon { font-size: 1.3rem; }

  .cta-arrow {
    width: 18px;
    height: 18px;
    flex-shrink: 0;
  }

  /* ===== Show Ads Toggle ===== */
  .show-ads-toggle {
    position: relative;
    z-index: 10;
    width: 100%;
    max-width: 420px;
    padding: 1rem 1rem 0;
    text-align: center;
  }

  .show-ads-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.6rem 1.25rem;
    background: white;
    color: #6b7280;
    border: 1.5px solid #e5e7eb;
    border-radius: 10px;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
  }

  .show-ads-btn:active { transform: scale(0.96); }
  .show-ads-btn:hover { border-color: var(--green); color: var(--green); }

  .show-ads-icon { font-size: 1rem; }

  /* ===== Advertisement LED Screen ===== */
  .advertisement-section {
    position: relative;
    z-index: 10;
    width: 100%;
    max-width: 420px;
    padding: 1rem 1rem 0;
  }

  .led-screen-container {
    position: relative;
    width: 100%;
    max-width: 280px;
    margin: 0 auto;
  }

  .led-frame {
    position: relative;
    background: #111;
    padding: 6px;
    border-radius: 18px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.22);
    border: 1.5px solid #333;
  }

  .video-content {
    position: relative;
    width: 100%;
    height: 400px;
    aspect-ratio: 9/16;
    border-radius: 14px;
    overflow: hidden;
    background: #000;
    isolation: isolate;
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
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(45deg, #1a1a2e, #16213e);
    z-index: 2;
  }

  .fallback-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    z-index: 2;
    color: var(--green);
  }

  .fallback-icon { font-size: 3.5rem; margin-bottom: 0.75rem; opacity: 0.8; }
  .fallback-title { font-size: 1.1rem; font-weight: bold; margin-bottom: 0.4rem; }
  .fallback-subtitle { font-size: 0.85rem; opacity: 0.7; }

  .hide-btn {
    position: absolute;
    top: 0.4rem;
    left: 0.4rem;
    background: rgba(239, 68, 68, 0.85);
    color: white;
    border: none;
    border-radius: 50%;
    width: 32px;
    height: 32px;
    font-size: 0.85rem;
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
    backdrop-filter: blur(8px);
    box-shadow: 0 2px 8px rgba(239, 68, 68, 0.4);
  }

  .hide-btn:active { transform: scale(0.9); }

  .screen-glow {
    position: absolute;
    top: -4px;
    left: -4px;
    right: -4px;
    bottom: -4px;
    background: linear-gradient(45deg, var(--green), var(--orange), var(--green));
    border-radius: 20px;
    opacity: 0.15;
    filter: blur(8px);
    z-index: -1;
    animation: screenGlow 4s ease-in-out infinite;
  }

  @keyframes screenGlow {
    0%, 100% { opacity: 0.15; }
    50% { opacity: 0.3; }
  }

  .led-dots {
    position: absolute;
    inset: 0;
    background-image: radial-gradient(circle at 2px 2px, rgba(255, 255, 255, 0.08) 1px, transparent 1px);
    background-size: 8px 8px;
    pointer-events: none;
    z-index: 3;
  }

  /* ===== Mobile Optimizations ===== */
  @media (max-width: 480px) {
    .hero-header {
      padding: 1.25rem 1rem 1rem;
      border-radius: 0 0 24px 24px;
    }

    .logo-container { width: 56px; height: 56px; border-radius: 16px; }
    .hero-logo { width: 40px; height: 40px; }
    .hero-title { font-size: 1.15rem; }
    .hero-subtitle { font-size: 0.78rem; }

    .cta-section { padding: 0.75rem 0.75rem 0; }
    .cta-btn { padding: 0.8rem 1.25rem; font-size: 0.95rem; }

    .advertisement-section { padding: 0.75rem 0.75rem 0; }
    .led-screen-container { max-width: 250px; }
    .video-content { height: 380px; }
    .led-frame { padding: 5px; }

    .hide-btn { width: 28px; height: 28px; font-size: 0.75rem; }
  }

  /* ===== Tablet+ ===== */
  @media (min-width: 768px) {
    .home-container { max-width: 600px; margin: 0 auto; }

    .hero-header {
      border-radius: 0 0 40px 40px;
      padding: 2rem 2rem 1.5rem;
    }
  }
</style>
