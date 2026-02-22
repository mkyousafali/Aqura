<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { browser } from '$app/environment';
  import { supabase } from '$lib/utils/supabase';

  // Type declarations for Google Maps (loaded dynamically)
  type GoogleMap = any;
  type GoogleMarker = any;
  type GoogleAutocomplete = any;
  type GoogleLatLng = any;
  type GoogleMapMouseEvent = any;

  export let initialLat: number = 24.7136; // Riyadh default
  export let initialLng: number = 46.6753;
  export let onLocationSelect: (location: { name: string; lat: number; lng: number; url: string }) => void;
  export let language: string = 'ar';

  let map: GoogleMap = null;
  let marker: GoogleMarker = null;
  let mapContainer: HTMLDivElement;
  let searchInput: HTMLInputElement;
  let autocomplete: GoogleAutocomplete = null;
  let isLoading = true;
  let error = '';
  let locationDenied = false;
  let locatingMe = false;
  let geoWatchId: number | null = null;
  let bestAccuracy = Infinity;
  let accuracyCircle: any = null;
  let currentAccuracy: number | null = null;
  let locationInaccurate = false;

  // Will be populated from DB or env fallback
  let GOOGLE_MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '';

  /** Fetch the Google API key from system_api_keys table, fallback to .env */
  async function fetchApiKey(): Promise<string> {
    try {
      const { data, error: dbErr } = await supabase
        .from('system_api_keys')
        .select('api_key')
        .eq('service_name', 'google')
        .eq('is_active', true)
        .single();
      if (!dbErr && data?.api_key) {
        console.log('🔑 [LocationPicker] Got Google API key from database');
        return data.api_key;
      }
    } catch (e) {
      console.warn('⚠️ [LocationPicker] Could not fetch key from DB, using env fallback');
    }
    return import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '';
  }

  const texts = language === 'ar' ? {
    searchPlaceholder: 'ابحث عن مدينتك أو حيك (مثل: جيزان، أبها)...',
    loading: 'جاري تحميل الخريطة...',
    clickToSelect: 'انقر على الخريطة لتحديد الموقع',
    dragInstruction: '📍 اسحب الدبوس إلى موقعك الدقيق، أو انقر على الخريطة، ثم احفظ الموقع',
    locationDenied: '⚠️ تعذر الوصول إلى موقعك. يمكنك البحث عن موقعك، النقر على الخريطة، أو سحب الدبوس إلى موقعك.',
    locationInaccurate: '⚠️ الموقع المكتشف غير دقيق. ابحث عن مدينتك أو حيك في مربع البحث أعلاه، أو انقر على الخريطة لتحديد موقعك يدوياً.',
    error: 'فشل تحميل الخريطة',
    noApiKey: 'لم يتم العثور على مفتاح API للخرائط',
    accuracy: 'الدقة',
  } : {
    searchPlaceholder: 'Search your city or area (e.g. Jizan, Abha)...',
    loading: 'Loading map...',
    clickToSelect: 'Click on the map to select location',
    dragInstruction: '📍 Drag the pin to your exact location, or click on the map, then save the location',
    locationDenied: '⚠️ Could not access your location. You can search, tap on the map, or drag the pin to set your location manually.',
    locationInaccurate: '⚠️ Detected location is inaccurate (IP-based). Please search for your city/area in the search box above, or tap on the map to set your location manually.',
    error: 'Failed to load map',
    noApiKey: 'Google Maps API key not found',
    accuracy: 'Accuracy',
  };

  function loadGoogleMapsScript(): Promise<void> {
    return new Promise((resolve, reject) => {
      console.log('🗺️ [LocationPicker] Starting to load Google Maps...');
      console.log('🗺️ [LocationPicker] API Key:', GOOGLE_MAPS_API_KEY ? 'Present' : 'Missing');
      
      // @ts-ignore - Google Maps loaded dynamically
      if (typeof google !== 'undefined' && google.maps) {
        console.log('✅ [LocationPicker] Google Maps already loaded');
        resolve();
        return;
      }

      if (!GOOGLE_MAPS_API_KEY) {
        console.error('❌ [LocationPicker] No API key found');
        reject(new Error(texts.noApiKey));
        return;
      }

      // Remove any previously loaded Google Maps script with old/expired key
      const existingScript = document.querySelector('script[src*="maps.googleapis.com"]');
      if (existingScript) {
        existingScript.remove();
      }

      console.log('📥 [LocationPicker] Loading Google Maps script...');
      const script = document.createElement('script');
      script.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&libraries=places&language=${language}`;
      script.async = true;
      script.defer = true;
      script.onload = () => {
        console.log('✅ [LocationPicker] Google Maps script loaded successfully');
        resolve();
      };
      script.onerror = (err) => {
        console.error('❌ [LocationPicker] Failed to load Google Maps script:', err);
        reject(new Error(texts.error));
      };
      document.head.appendChild(script);
    });
  }

  function initMap() {
    console.log('🗺️ [LocationPicker] initMap() called');
    console.log('🗺️ [LocationPicker] mapContainer:', mapContainer);
    console.log('🗺️ [LocationPicker] browser:', browser);
    console.log('🗺️ [LocationPicker] google object exists?', typeof google !== 'undefined');
    
    if (!mapContainer || !browser) {
      console.warn('⚠️ [LocationPicker] Cannot init map - container or browser not ready');
      console.warn('⚠️ [LocationPicker] mapContainer:', mapContainer);
      console.warn('⚠️ [LocationPicker] browser:', browser);
      return;
    }

    console.log('🗺️ [LocationPicker] Initializing map...');
    console.log('🗺️ [LocationPicker] Container:', mapContainer);
    console.log('🗺️ [LocationPicker] Initial coords:', { lat: initialLat, lng: initialLng });

    try {
      // @ts-ignore - Google Maps API loaded dynamically
      const mapOptions: any = {
        center: { lat: initialLat, lng: initialLng },
        zoom: locationInaccurate ? 6 : 15,
        mapTypeControl: false,
        streetViewControl: false,
        fullscreenControl: true,
        zoomControl: true,
      };

      // @ts-ignore
      map = new google.maps.Map(mapContainer, mapOptions);
      console.log('✅ [LocationPicker] Map created successfully');

      // Add marker at initial position (hidden if location is inaccurate)
      // @ts-ignore
      marker = new google.maps.Marker({
        position: { lat: initialLat, lng: initialLng },
        map: map,
        draggable: true,
        visible: !locationInaccurate,
        // @ts-ignore
        animation: google.maps.Animation.DROP,
      });

      // Only auto-select initial position if we have good GPS
      if (!locationInaccurate) {
        // @ts-ignore
        const latLng = new google.maps.LatLng(initialLat, initialLng);
        updateMarkerPosition(latLng);
      }

      // Listen for map clicks
      map.addListener('click', (e: GoogleMapMouseEvent) => {
        if (e.latLng) {
          if (accuracyCircle) { accuracyCircle.setMap(null); accuracyCircle = null; }
          locationInaccurate = false;
          // Show marker if it was hidden
          if (marker) marker.setVisible(true);
          updateMarkerPosition(e.latLng);
        }
      });

      // Listen for marker drag
      marker.addListener('dragend', (e: GoogleMapMouseEvent) => {
        if (e.latLng) {
          if (accuracyCircle) { accuracyCircle.setMap(null); accuracyCircle = null; }
          locationInaccurate = false;
          updateMarkerPosition(e.latLng);
        }
      });

      // Initialize autocomplete
      if (searchInput) {
        // @ts-ignore
        autocomplete = new google.maps.places.Autocomplete(searchInput, {
          fields: ['formatted_address', 'geometry', 'name'],
        });

        autocomplete.addListener('place_changed', () => {
          const place = autocomplete?.getPlace();
          if (place?.geometry?.location) {
            if (accuracyCircle) { accuracyCircle.setMap(null); accuracyCircle = null; }
            locationInaccurate = false;
            if (marker) marker.setVisible(true);
            updateMarkerPosition(place.geometry.location);
            map?.setCenter(place.geometry.location);
            map?.setZoom(16);
          }
        });
      }
    } catch (err) {
      console.error('❌ [LocationPicker] Error initializing map:', err);
      error = 'Failed to initialize map';
      isLoading = false;
    }
  }

  /** Locate me - request fresh GPS with high accuracy and watch for better fix */
  async function locateMe() {
    if (!navigator.geolocation || !map || !marker) return;
    locatingMe = true;
    bestAccuracy = Infinity;

    // Clear any previous watch
    if (geoWatchId !== null) {
      navigator.geolocation.clearWatch(geoWatchId);
      geoWatchId = null;
    }

    // Use watchPosition to get progressively more accurate fixes
    geoWatchId = navigator.geolocation.watchPosition(
      (position) => {
        const { latitude, longitude, accuracy } = position.coords;
        console.log(`📍 [LocationPicker] GPS fix: ${latitude}, ${longitude} (accuracy: ${accuracy}m)`);

        // Track accuracy for display
        currentAccuracy = accuracy;

        // If accuracy is >1km, it's IP/WiFi-based — show warning, don't move pin
        if (accuracy >= 1000) {
          locationInaccurate = true;
          console.warn('⚠️ [LocationPicker] GPS accuracy too poor (' + accuracy + 'm) - IP/WiFi-based. Not centering.');
          return;
        }

        // Good fix — update marker if better than previous
        if (accuracy < bestAccuracy) {
          bestAccuracy = accuracy;
          locationInaccurate = false;
          // @ts-ignore
          const latLng = new google.maps.LatLng(latitude, longitude);
          if (marker) marker.setVisible(true);
          updateMarkerPosition(latLng);
          map.setCenter(latLng);

          // Show accuracy circle
          if (accuracyCircle) accuracyCircle.setMap(null);
          // @ts-ignore
          accuracyCircle = new google.maps.Circle({
            map: map,
            center: { lat: latitude, lng: longitude },
            radius: accuracy,
            fillColor: accuracy < 100 ? '#4285F4' : '#FF6B35',
            fillOpacity: 0.12,
            strokeColor: accuracy < 100 ? '#4285F4' : '#FF6B35',
            strokeWeight: 1.5,
            strokeOpacity: 0.4,
            clickable: false
          });

          // Zoom based on accuracy
          if (accuracy < 20) map.setZoom(19);
          else if (accuracy < 50) map.setZoom(18);
          else if (accuracy < 100) map.setZoom(17);
          else if (accuracy < 500) map.setZoom(16);
          else map.setZoom(14);
        }

        // If accuracy is good enough (<20m), stop watching
        if (accuracy < 20) {
          if (geoWatchId !== null) {
            navigator.geolocation.clearWatch(geoWatchId);
            geoWatchId = null;
          }
          locatingMe = false;
        }
      },
      (err) => {
        console.error('❌ [LocationPicker] locateMe error:', err);
        locatingMe = false;
        locationDenied = true;
      },
      {
        enableHighAccuracy: true,
        timeout: 20000,
        maximumAge: 0
      }
    );

    // Safety timeout - stop watching after 15 seconds regardless
    setTimeout(() => {
      if (geoWatchId !== null) {
        navigator.geolocation.clearWatch(geoWatchId);
        geoWatchId = null;
      }
      locatingMe = false;
    }, 15000);
  }

  function updateMarkerPosition(latLng: GoogleLatLng) {
    if (!marker || !map) return;

    marker.setPosition(latLng);
    map.panTo(latLng);

    // Reverse geocode to get address
    // @ts-ignore
    const geocoder = new google.maps.Geocoder();
    geocoder.geocode({ location: latLng }, (results: any, status: string) => {
      if (status === 'OK' && results?.[0]) {
        const address = results[0].formatted_address;
        const lat = latLng.lat();
        const lng = latLng.lng();
        const url = `https://www.google.com/maps?q=${lat},${lng}`;

        onLocationSelect({
          name: address,
          lat,
          lng,
          url
        });
      }
    });
  }

  onMount(async () => {
    if (!browser) {
      console.warn('⚠️ [LocationPicker] Not in browser environment');
      return;
    }

    console.log('🚀 [LocationPicker] Component mounted, starting initialization...');

    try {
      // Fetch API key from database first, fallback to .env
      GOOGLE_MAPS_API_KEY = await fetchApiKey();
      console.log('🔑 [LocationPicker] API Key:', GOOGLE_MAPS_API_KEY ? 'Present (length: ' + GOOGLE_MAPS_API_KEY.length + ')' : 'MISSING!');

      // Get user's current location first - try high accuracy, fallback to low  
      let gotGoodLocation = false;
      if (navigator.geolocation) {
        console.log('📍 [LocationPicker] Requesting user location...');
        try {
          const position = await new Promise<GeolocationPosition>((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, {
              timeout: 10000,
              enableHighAccuracy: true,
              maximumAge: 0
            });
          });
          const acc = position.coords.accuracy;
          console.log('✅ [LocationPicker] Got GPS location:', position.coords.latitude, position.coords.longitude, 'accuracy:', acc, 'm');
          // Only use if accuracy is under 1km (real GPS/WiFi triangulation, not IP)
          if (acc < 1000) {
            initialLat = position.coords.latitude;
            initialLng = position.coords.longitude;
            gotGoodLocation = true;
          } else {
            console.warn('⚠️ [LocationPicker] GPS accuracy too poor (' + acc + 'm) - likely IP/WiFi-based, ignoring');
            locationInaccurate = true;
            currentAccuracy = acc;
          }
        } catch (err: any) {
          console.warn('⚠️ [LocationPicker] Geolocation failed:', err.message);
          locationInaccurate = true;
        }
      }

      // If no good location, zoom out to show Saudi Arabia so user can navigate
      if (!gotGoodLocation) {
        initialLat = 23.8859; // Center of Saudi Arabia
        initialLng = 45.0792;
      }

      await loadGoogleMapsScript();
      console.log('⏳ [LocationPicker] Google Maps loaded, showing map container...');
      
      // Set loading to false so the map container gets rendered
      isLoading = false;
      
      // Wait for the container to be rendered and bound (with timeout)
      await new Promise<void>((resolve, reject) => {
        let attempts = 0;
        const maxAttempts = 100; // 5 seconds maximum
        
        const checkContainer = () => {
          attempts++;
          if (mapContainer) {
            console.log('✅ [LocationPicker] Container found after', attempts, 'attempts');
            resolve();
          } else if (attempts >= maxAttempts) {
            console.error('❌ [LocationPicker] Container not found after', attempts, 'attempts');
            reject(new Error('Map container not found'));
          } else {
            setTimeout(checkContainer, 50);
          }
        };
        setTimeout(checkContainer, 50);
      });

      console.log('🗺️ [LocationPicker] Initializing map now...');
      initMap();

      // Automatically refine location with watchPosition after map is ready
      if (navigator.geolocation && !locationDenied) {
        locateMe();
      }
    } catch (err) {
      console.error('❌ [LocationPicker] Failed to load Google Maps:', err);
      error = err instanceof Error ? err.message : texts.error;
      isLoading = false;
    }
  });

  onDestroy(() => {
    // Clean up watch
    if (geoWatchId !== null) {
      navigator.geolocation.clearWatch(geoWatchId);
      geoWatchId = null;
    }
    // Clean up map instance
    if (accuracyCircle) accuracyCircle.setMap(null);
    if (marker) marker.setMap(null);
    if (map) map = null;
  });
</script>

<div class="location-picker">
  {#if isLoading}
    <div class="loading">
      <div class="spinner"></div>
      <p>{texts.loading}</p>
      <p class="debug-info">Checking Google Maps API...</p>
    </div>
  {:else if error}
    <div class="error">
      <p>❌ {error}</p>
      <p class="error-details">API Key present: {GOOGLE_MAPS_API_KEY ? 'Yes' : 'No'}</p>
      <p class="error-details">Please check browser console for details</p>
    </div>
  {:else}
    <div class="search-container">
      <input
        type="text"
        bind:this={searchInput}
        placeholder={texts.searchPlaceholder}
        class="search-input"
      />
      <span class="search-icon">🔍</span>
    </div>
    {#if locationDenied}
      <div class="warning-box">
        <p class="warning">{texts.locationDenied}</p>
      </div>
    {/if}
    {#if locationInaccurate && !locationDenied}
      <div class="warning-box warning-box-inaccurate">
        <p class="warning">{texts.locationInaccurate}</p>
        {#if currentAccuracy}
          <p class="accuracy-info">{texts.accuracy}: ~{currentAccuracy > 1000 ? Math.round(currentAccuracy / 1000) + 'km' : Math.round(currentAccuracy) + 'm'}</p>
        {/if}
      </div>
    {/if}
    <div class="instruction-box">
      <p class="instruction">{texts.dragInstruction}</p>
    </div>
    <div class="map-wrapper">
      <div class="map-container" bind:this={mapContainer}></div>
      <!-- My Location Button -->
      <button class="locate-me-btn" on:click={locateMe} disabled={locatingMe}
        title={language === 'ar' ? 'موقعي الحالي' : 'My Location'}>
        {#if locatingMe}
          <span class="locate-spinner"></span>
        {:else}
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="3"/>
            <path d="M12 2v3m0 14v3M2 12h3m14 0h3"/>
            <circle cx="12" cy="12" r="8"/>
          </svg>
        {/if}
      </button>
    </div>
    <p class="hint">{texts.clickToSelect}</p>
  {/if}
</div>

<style>
  .location-picker {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    position: relative;
  }

  .loading, .error {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 400px;
    gap: 1rem;
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 4px solid rgba(22, 163, 74, 0.2);
    border-top-color: #16a34a;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .error p {
    color: #dc2626;
    font-weight: 600;
  }

  .error-details, .debug-info {
    font-size: 0.85rem;
    color: #6b7280;
    margin-top: 0.5rem;
  }

  .search-container {
    position: relative;
    width: 100%;
  }

  .instruction-box {
    background: linear-gradient(135deg, #16a34a 0%, #15803d 100%);
    padding: 1rem;
    border-radius: 10px;
    box-shadow: 0 2px 8px rgba(22, 163, 74, 0.15);
    margin: 0.5rem 0;
  }

  .instruction {
    color: white;
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
    text-align: center;
    line-height: 1.5;
  }

  .warning-box {
    background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
    padding: 0.875rem;
    border-radius: 10px;
    box-shadow: 0 2px 8px rgba(245, 158, 11, 0.15);
    margin: 0.5rem 0;
  }

  .warning {
    color: white;
    font-size: 0.9rem;
    font-weight: 500;
    margin: 0;
    text-align: center;
    line-height: 1.4;
  }

  .warning-box-inaccurate {
    background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
    animation: pulse-warning 2s ease-in-out infinite;
  }

  .accuracy-info {
    color: rgba(255, 255, 255, 0.85);
    font-size: 0.8rem;
    margin: 0.25rem 0 0;
    text-align: center;
  }

  @keyframes pulse-warning {
    0%, 100% { box-shadow: 0 2px 8px rgba(239, 68, 68, 0.15); }
    50% { box-shadow: 0 2px 16px rgba(239, 68, 68, 0.35); }
  }

  .search-input {
    width: 100%;
    padding: 0.75rem 2.5rem 0.75rem 1rem;
    border: 2px solid rgba(22, 163, 74, 0.2);
    border-radius: 12px;
    font-size: 0.95rem;
    outline: none;
    transition: all 0.3s ease;
    box-sizing: border-box;
  }

  .search-input:focus {
    border-color: #16a34a;
    box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.1);
  }

  .search-icon {
    position: absolute;
    right: 1rem;
    top: 50%;
    transform: translateY(-50%);
    font-size: 1.2rem;
    pointer-events: none;
  }

  .map-wrapper {
    position: relative;
    width: 100%;
  }

  .map-container {
    width: 100%;
    height: 400px;
    border-radius: 12px;
    overflow: hidden;
    border: 2px solid rgba(22, 163, 74, 0.2);
  }

  .locate-me-btn {
    position: absolute;
    bottom: 16px;
    right: 16px;
    width: 44px;
    height: 44px;
    border-radius: 12px;
    background: white;
    border: 2px solid rgba(22, 163, 74, 0.3);
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.15);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    color: #16a34a;
    transition: all 0.2s ease;
    z-index: 10;
  }
  .locate-me-btn:hover {
    background: #f0fdf4;
    border-color: #16a34a;
    transform: scale(1.05);
  }
  .locate-me-btn:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }

  .locate-spinner {
    width: 20px;
    height: 20px;
    border: 2.5px solid rgba(22, 163, 74, 0.2);
    border-top-color: #16a34a;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .hint {
    text-align: center;
    color: #6b7280;
    font-size: 0.85rem;
    margin: 0;
    font-style: italic;
  }

  @media (max-width: 640px) {
    .map-container {
      height: 300px;
    }
  }

  /* Ensure Google Places autocomplete dropdown appears above modals */
  :global(.pac-container) {
    z-index: 1000000 !important;
  }
</style>
