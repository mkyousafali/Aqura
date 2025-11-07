<script lang="ts">
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { userStore, userActions } from '$lib/stores/user.js';

  let currentLanguage = 'ar';
  let videoContainer;
  let currentVideoIndex = 0;
  let isVideoHidden = false;
  let videoError = false;
  let userName = 'Guest';
  let loading = true;

  // Advertisement videos data
  const advertisementVideos = [
    {
      id: 1,
      src: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      title: 'عروض أكوا الخاصة',
      titleEn: 'Aqua Special Offers',
      duration: 15,
      fileSize: '8.2 MB',
      uploadTime: '2024-11-01 14:30'
    },
    {
      id: 2,
      src: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      title: 'خدماتنا المتميزة',
      titleEn: 'Our Premium Services',
      duration: 12,
      fileSize: '6.8 MB',
      uploadTime: '2024-11-01 15:45'
    },
    {
      id: 3,
      src: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      title: 'أحدث المنتجات',
      titleEn: 'Latest Products',
      duration: 18,
      fileSize: '5.1 MB',
      uploadTime: '2024-11-01 16:20'
    }
  ];

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
  onMount(() => {
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

    loading = false;

    // Subscribe to user store for reactive updates
    userStore.subscribe(user => {
      userName = user.customer_name || user.name || user.phone || 'Guest';
    });

    // Reset video error state on mount
    videoError = false;
    
    // Start video rotation
    startVideoRotation();

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

  // Video rotation functionality
  function startVideoRotation() {
    if (advertisementVideos.length === 0) return;
    
    function scheduleNextVideo() {
      const currentVideo = advertisementVideos[currentVideoIndex];
      const duration = currentVideo.duration * 1000 + 2000;
      
      setTimeout(() => {
        nextVideo();
        scheduleNextVideo();
      }, duration);
    }
    
    scheduleNextVideo();
  }
  
  function nextVideo() {
    currentVideoIndex = (currentVideoIndex + 1) % advertisementVideos.length;
    updateVideoDisplay();
  }
  
  function updateVideoDisplay() {
    if (videoContainer) {
      const video = videoContainer.querySelector('video');
      if (video) {
        video.src = advertisementVideos[currentVideoIndex].src;
        video.load();
        video.play().catch(e => {
          console.log('Video autoplay prevented:', e);
          videoError = false;
        });
      }
    }
  }

  function handleVideoError() {
    console.log('Video failed to load');
    videoError = false;
  }
  
  function handleVideoClick() {
    goto('/customer/products');
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
    subtitle: 'اختر فئة المنتجات التي تريد التسوق منها',
    allProducts: 'جميع المنتجات',
    hideVideo: 'إخفاء الفيديو',
    showVideo: 'إظهار الفيديو'
  } : {
    title: 'Home - Aqua Express',
    greeting: `Welcome ${userName} 👋`,
    subtitle: 'Choose a product category to shop from',
    allProducts: 'All Products',
    hideVideo: 'Hide Video',
    showVideo: 'Show Video'
  };

  function handleCategoryClick(categoryId, event) {
    console.log('Category clicked:', categoryId);
    event?.preventDefault();
    event?.stopPropagation();
    try {
      goto(`/customer/products?category=${categoryId}`);
    } catch (error) {
      console.error('Navigation error:', error);
    }
  }

  function handleAllProducts(event) {
    console.log('All products clicked');
    event?.preventDefault();
    event?.stopPropagation();
    try {
      goto('/customer/products');
    } catch (error) {
      console.error('Navigation error:', error);
    }
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
    <!-- Header Section with LED Welcome Message -->
    <div class="header-section">
      <div class="led-welcome-container">
        <div class="led-border">
          <div class="welcome-content">
            <div class="logo-container">
              <img src="/icons/logo.png" alt="Aqura Logo" class="app-logo" />
            </div>
            <h1 class="welcome-text">{texts.greeting}</h1>
          </div>
        </div>
      </div>
    </div>

    <!-- Advertisement Video Section (LED Screen Style) -->
    {#if !isVideoHidden}
      <div class="advertisement-section" bind:this={videoContainer}>
        <div class="led-screen-container">
          <div class="led-frame">
            <div class="video-content">
              {#if !videoError}
                <video 
                  autoplay 
                  muted 
                  loop
                  playsinline
                  on:click={handleVideoClick}
                  on:error={handleVideoError}
                  src={advertisementVideos[currentVideoIndex]?.src}
                >
                  <source src={advertisementVideos[currentVideoIndex]?.src} type="video/mp4">
                  Your browser does not support the video tag.
                </video>
              {:else}
                <div class="video-fallback" on:click={handleVideoClick}>
                  <div class="fallback-content">
                    <div class="fallback-icon">�</div>
                    <div class="fallback-title">
                      {currentLanguage === 'ar' 
                        ? advertisementVideos[currentVideoIndex]?.title 
                        : advertisementVideos[currentVideoIndex]?.titleEn}
                    </div>
                    <div class="fallback-subtitle">
                      {currentLanguage === 'ar' ? 'انقر للمشاهدة' : 'Click to Watch'}
                    </div>
                  </div>
                </div>
              {/if}
              
              <!-- Next Button -->
              <button class="next-btn" on:click={nextVideo} title="Next Video">
                <span>▶</span>
              </button>

              <!-- Hide Button -->
              <button class="hide-btn" on:click={hideVideo} title={texts.hideVideo}>
                <span>✕</span>
              </button>
              
              <!-- LED Screen Effects -->
              <div class="led-dots"></div>
              <div class="screen-glow"></div>
            </div>
          </div>
        </div>
      </div>
    {:else}
      <!-- Show Video Button when hidden -->
      <div class="show-video-section">
        <button class="show-video-btn" on:click={showVideo}>
          <span class="video-icon">�</span>
          <span>{texts.showVideo}</span>
        </button>
      </div>
    {/if}

    <!-- Category Selection Section -->
    <div class="category-selection-section">
      <p class="category-subtitle">{texts.subtitle}</p>
      <!-- All Products Button -->
      <button 
        class="all-products-btn" 
        on:click={handleAllProducts}
        on:touchend={handleAllProducts}
        type="button"
      >
        <div class="btn-icon">🛒</div>
        <span>{texts.allProducts}</span>
      </button>
    </div>

    <!-- Categories Grid -->
    <div class="categories-grid">
      {#each categories as category}
        <button 
          class="category-card" 
          on:click={(e) => handleCategoryClick(category.id, e)}
          on:touchend={(e) => handleCategoryClick(category.id, e)}
          type="button"
        >
          <div class="category-icon">{category.icon}</div>
          <h3>{currentLanguage === 'ar' ? category.nameAr : category.nameEn}</h3>
        </button>
      {/each}
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
    padding: 1rem;
    max-width: 100%;
    margin: 0 auto;
    min-height: 100vh;
    background: var(--color-surface);
  }

  .header-section {
    text-align: center;
    margin-bottom: 1.5rem;
    padding: 1rem 0;
    width: 100%;
  }

  .led-welcome-container {
    display: flex;
    justify-content: center;
    align-items: center;
    margin: 0 auto 1.5rem auto;
    padding: 0 1rem;
    width: 100%;
    max-width: 800px;
  }

  .led-border {
    position: relative;
    width: min(500px, 95vw);
    height: 100px;
    border-radius: 25px;
    padding: 12px;
    background: linear-gradient(45deg, 
      var(--color-primary) 0%, 
      var(--color-primary) 25%, 
      var(--color-secondary) 50%, 
      var(--color-secondary) 75%, 
      var(--color-primary) 100%
    );
    background-size: 400% 400%;
    animation: ledGlow 3s ease-in-out infinite;
    box-shadow: 
      0 0 35px rgba(16, 179, 0, 0.5),
      0 0 70px rgba(200, 162, 50, 0.3),
      inset 0 0 25px rgba(255, 255, 255, 0.15);
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto;
  }

  .led-border::before {
    content: '';
    position: absolute;
    top: 5px;
    left: 5px;
    right: 5px;
    bottom: 5px;
    border-radius: 20px;
    background: linear-gradient(135deg, #f8f9fa 0%, #ffffff 100%);
    z-index: 1;
  }

  .welcome-content {
    position: relative;
    z-index: 2;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
    width: 100%;
    height: 100%;
    padding: 0 0.75rem;
  }

  .logo-container {
    flex-shrink: 0;
  }

  .app-logo {
    width: 60px;
    height: 60px;
    object-fit: contain;
    border-radius: 10px;
  }

  .welcome-text {
    font-size: clamp(1.3rem, 4.5vw, 1.8rem);
    font-weight: 700;
    color: var(--color-primary);
    margin: 0;
    text-align: center;
    line-height: 1.2;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    background: linear-gradient(45deg, var(--color-primary), var(--color-accent));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    filter: drop-shadow(0 3px 6px rgba(0, 0, 0, 0.15));
  }

  @keyframes ledGlow {
    0% {
      background-position: 0% 50%;
      box-shadow: 
        0 0 35px rgba(16, 179, 0, 0.8),
        0 0 70px rgba(16, 179, 0, 0.5),
        inset 0 0 25px rgba(255, 255, 255, 0.15);
    }
    50% {
      background-position: 100% 50%;
      box-shadow: 
        0 0 35px rgba(200, 162, 50, 0.8),
        0 0 70px rgba(200, 162, 50, 0.5),
        inset 0 0 25px rgba(255, 255, 255, 0.15);
    }
    100% {
      background-position: 0% 50%;
      box-shadow: 
        0 0 35px rgba(16, 179, 0, 0.8),
        0 0 70px rgba(16, 179, 0, 0.5),
        inset 0 0 25px rgba(255, 255, 255, 0.15);
    }
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

  .next-btn {
    position: absolute;
    top: 50%;
    right: 1rem;
    transform: translateY(-50%);
    background: rgba(16, 179, 0, 0.2);
    color: var(--color-primary);
    border: 2px solid var(--color-primary);
    border-radius: 50%;
    width: 50px;
    height: 50px;
    font-size: 1.2rem;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 5;
    backdrop-filter: blur(10px);
    box-shadow: 0 0 15px rgba(16, 179, 0, 0.4);
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

  .next-btn:hover {
    background: rgba(16, 179, 0, 0.4);
    transform: translateY(-50%) scale(1.1);
    box-shadow: 0 0 20px rgba(16, 179, 0, 0.6);
  }

  .next-btn span {
    text-shadow: 0 0 5px var(--color-primary);
    margin-left: 2px;
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

    .header-section {
      padding: 0.75rem 0;
      margin-bottom: 1rem;
    }

    .led-welcome-container {
      padding: 0 0.5rem;
      max-width: 100%;
    }

    .led-border {
      width: min(420px, 90vw);
      height: 85px;
      border-radius: 20px;
      padding: 10px;
      margin: 0 auto;
    }

    .app-logo {
      width: 45px;
      height: 45px;
    }

    .welcome-content {
      gap: 0.75rem;
      padding: 0 0.5rem;
    }

    .led-border::before {
      top: 4px;
      left: 4px;
      right: 4px;
      bottom: 4px;
      border-radius: 16px;
    }

    .welcome-text {
      font-size: clamp(1.1rem, 4vw, 1.4rem);
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

    .next-btn {
      width: 40px;
      height: 40px;
      font-size: 1rem;
      right: 0.5rem;
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