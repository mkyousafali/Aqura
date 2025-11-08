<script lang="ts">
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { userStore, userActions } from '$lib/stores/user.js';
  import { supabase } from '$lib/utils/supabase';

  let currentLanguage = 'ar';
  let videoContainer;
  let currentVideoIndex = 0;
  let currentMediaIndex = 0;
  let isVideoHidden = false;
  let videoError = false;
  let userName = 'Guest';
  let loading = true;
  let mediaItems = []; // Combined video and image items from database
  
  // Touch tracking for scroll vs click detection
  let touchStartY = 0;
  let touchStartX = 0;
  let isTouchMoving = false;

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
  });

  // Listen for language changes
  function handleStorageChange(event) {
    if (event.key === 'language') {
      currentLanguage = event.newValue || 'ar';
    }
  }

  // Media rotation functionality (handles both videos and images)
  function startMediaRotation() {
    if (mediaItems.length === 0) return;
    
    function scheduleNextMedia() {
      const currentMedia = mediaItems[currentMediaIndex];
      const duration = currentMedia.duration * 1000 + 2000; // Add 2 seconds buffer
      
      setTimeout(() => {
        nextMedia();
        scheduleNextMedia();
      }, duration);
    }
    
    scheduleNextMedia();
  }
  
  function nextMedia() {
    currentMediaIndex = (currentMediaIndex + 1) % mediaItems.length;
    updateMediaDisplay();
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
  
  function hideVideo() {
    isVideoHidden = true;
    localStorage.setItem('videoHidden', 'true');
  }

  function showVideo() {
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

  function goStartShopping() {
    goto('/customer/start');
  }

  function goSupport() {
    goto('/customer/support');
  }

  function logout() {
    userActions.logout();
    goto("/customer-login");
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

{#if loading}
  <div class="loading-container">
    <div class="spinner"></div>
    <p>Loading...</p>
  </div>
{:else}
  <div class="home-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
    <div class="hero">
      <h2 class="greeting">{texts.greeting}</h2>
      <p class="subtitle">{texts.startSubtitle}</p>
      <div class="cta-buttons">
        <button class="cta primary" on:click={goStartShopping} type="button">🛒 {texts.shopNow}</button>
        <button class="cta secondary" on:click={goSupport} type="button">🆘 {texts.support}</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .loading-container {
  .hero { display:flex; flex-direction:column; align-items:center; justify-content:center; min-height: 70vh; gap: 1rem; text-align:center; }
  .greeting { margin: 0; color: var(--color-ink); }
  .subtitle { margin: 0; color: var(--color-ink-light); }
  .cta-buttons { display:flex; gap: 0.75rem; flex-wrap: wrap; justify-content:center; }
  .cta { border: none; border-radius: 10px; padding: 0.85rem 1.25rem; font-weight: 700; cursor: pointer; }
  .cta.primary { background: var(--color-primary); color: #fff; }
  .cta.secondary { background: var(--color-surface); color: var(--color-ink); border:1px solid var(--color-border); }
  .cta.primary:hover { background: var(--color-primary-dark); }
  .cta.secondary:hover { background: #f6f7f9; }
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
    padding: 1rem;
    max-width: 100%;
    margin: 0 auto;
    min-height: 100vh;
    background: var(--color-surface);
  }

  /* Advertisement LED Screen Styles */
  .advertisement-section {
    margin: 1rem 0 2rem 0;
    padding: 0;
  }

  .led-screen-container {
    position: relative;
    width: 100%;
    max-width: 300px;
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
    height: 480px;
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
    top: 1rem;
    left: 1rem;
    background: rgba(239, 68, 68, 0.2);
    color: #ef4444;
    border: 2px solid #ef4444;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    font-size: 1rem;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 5;
    backdrop-filter: blur(10px);
    box-shadow: 0 0 15px rgba(239, 68, 68, 0.4);
  }

  .hide-btn:hover {
    background: rgba(239, 68, 68, 0.4);
    transform: scale(1.1);
    box-shadow: 0 0 20px rgba(239, 68, 68, 0.6);
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
    background: linear-gradient(45deg, var(--color-primary), var(--color-accent), var(--color-secondary), var(--color-primary));
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
    padding: 1rem;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 12px;
    font-size: 1.1rem;
    font-weight: 600;
    margin-bottom: 1.5rem;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    position: relative;
    z-index: 10;
  }

  .all-products-btn:hover {
    background: var(--color-primary-dark);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
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
    background: white;
    border: 2px solid var(--color-border);
    border-radius: 16px;
    cursor: pointer;
    transition: all 0.2s ease;
    text-decoration: none;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
    min-height: 120px;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    position: relative;
    z-index: 10;
  }

  .category-card:hover {
    border-color: var(--color-primary);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .category-icon {
    font-size: 2.5rem;
    margin-bottom: 0.75rem;
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
      padding: 0.75rem;
    }

    .advertisement-section {
      margin: 1rem 0 1.5rem 0;
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
      max-width: 800px;
      padding: 2rem;
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