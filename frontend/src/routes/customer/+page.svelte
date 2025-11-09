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
  let rotationTimer = null; // timer for auto-rotation
  
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
    goto('/customer/start');
  }

  function goSupport(event) {
    event?.preventDefault();
    event?.stopPropagation();
    console.log('Go support clicked');
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
                    loop={false}
                    on:ended={advanceMediaNow}
                    on:error={handleVideoError}
                  ></video>
                {:else if media.type === 'image'}
                  <img
                    style="display: {index === currentMediaIndex ? 'block' : 'none'};"
                    src={media.src}
                    alt={media.title}
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

    /* Base background - Light mint green */
    background: linear-gradient(180deg, #86efac 0%, #6ee7b7 50%, #34d399 100%);
  }

  /* Orange wave - bottom layer with realistic wave animation */
  .home-container::before {
    content: '';
    position: absolute;
    width: 200%;
    height: 120px;
    bottom: 0;
    left: -50%;
    z-index: 0;
    background: #FF5C00;
    border-radius: 50% 50% 0 0 / 100% 100% 0 0;
    animation: wave 8s ease-in-out infinite;
  }

  /* Second wave layer - faster animation */
  .home-container::after {
    content: '';
    position: absolute;
    width: 200%;
    height: 100px;
    bottom: 0;
    left: -50%;
    z-index: 1;
    background: rgba(255, 92, 0, 0.7);
    border-radius: 50% 50% 0 0 / 100% 100% 0 0;
    animation: wave2 6s ease-in-out infinite;
  }

  @keyframes wave {
    0%, 100% {
      transform: translateX(0) translateY(0) rotate(0deg);
    }
    25% {
      transform: translateX(5%) translateY(-10px) rotate(1deg);
    }
    50% {
      transform: translateX(0) translateY(0) rotate(0deg);
    }
    75% {
      transform: translateX(-5%) translateY(-10px) rotate(-1deg);
    }
  }

  @keyframes wave2 {
    0%, 100% {
      transform: translateX(-5%) translateY(0) rotate(0deg);
    }
    25% {
      transform: translateX(0) translateY(-8px) rotate(-0.8deg);
    }
    50% {
      transform: translateX(-5%) translateY(0) rotate(0deg);
    }
    75% {
      transform: translateX(-10%) translateY(-8px) rotate(0.8deg);
    }
  }

  /* Ensure full-width background coverage */
  :global(body) {
    background: linear-gradient(180deg, #86efac 0%, #6ee7b7 50%, #34d399 100%) !important;
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
    
    .home-container::before {
      height: 100px;
      bottom: 0;
      width: 200%;
      left: -50%;
    }
    
    .home-container::after {
      height: 80px;
      bottom: 0;
      width: 200%;
      left: -50%;
    }
    
    :global(body) {
      background: linear-gradient(180deg, #86efac 0%, #6ee7b7 50%, #34d399 100%) !important;
      overflow: hidden;
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
    
    .home-container::before {
      height: 140px;
      bottom: 0;
      width: 200%;
      left: -50%;
    }
    
    .home-container::after {
      height: 120px;
      bottom: 0;
      width: 200%;
      left: -50%;
    }
    
    :global(body) {
      background: linear-gradient(180deg, #86efac 0%, #6ee7b7 50%, #34d399 100%) !important;
      overflow: hidden;
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