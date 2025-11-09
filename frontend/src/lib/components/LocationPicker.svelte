<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { browser } from '$app/environment';

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

  const GOOGLE_MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;
  
  // Debug: Log the API key availability immediately
  console.log('🔑 [LocationPicker] VITE_GOOGLE_MAPS_API_KEY:', GOOGLE_MAPS_API_KEY ? 'Present (length: ' + GOOGLE_MAPS_API_KEY.length + ')' : 'MISSING!');
  console.log('🔑 [LocationPicker] All env vars:', import.meta.env);

  const texts = language === 'ar' ? {
    searchPlaceholder: 'ابحث عن موقع...',
    loading: 'جاري تحميل الخريطة...',
    clickToSelect: 'انقر على الخريطة لتحديد الموقع',
    dragInstruction: '📍 اسحب الدبوس إلى موقعك الدقيق، أو انقر على الخريطة، ثم احفظ الموقع',
    locationDenied: '⚠️ تعذر الوصول إلى موقعك. يرجى البحث عن موقعك أو النقر على الخريطة.',
    error: 'فشل تحميل الخريطة',
    noApiKey: 'لم يتم العثور على مفتاح API للخرائط'
  } : {
    searchPlaceholder: 'Search for a location...',
    loading: 'Loading map...',
    clickToSelect: 'Click on the map to select location',
    dragInstruction: '📍 Drag the pin to your exact location, or click on the map, then save the location',
    locationDenied: '⚠️ Could not access your location. Please search for your location or click on the map.',
    error: 'Failed to load map',
    noApiKey: 'Google Maps API key not found'
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
        zoom: 15,
        mapTypeControl: false,
        streetViewControl: false,
        fullscreenControl: true,
        zoomControl: true,
      };

      // @ts-ignore
      map = new google.maps.Map(mapContainer, mapOptions);
      console.log('✅ [LocationPicker] Map created successfully');

      // Add marker at initial position
      // @ts-ignore
      marker = new google.maps.Marker({
        position: { lat: initialLat, lng: initialLng },
        map: map,
        draggable: true,
        // @ts-ignore
        animation: google.maps.Animation.DROP,
      });

      // Don't auto-select - let user click to select their exact location
      // This ensures accuracy instead of relying on potentially inaccurate geolocation

      // Listen for map clicks
      map.addListener('click', (e: GoogleMapMouseEvent) => {
        if (e.latLng) {
          updateMarkerPosition(e.latLng);
        }
      });

      // Listen for marker drag
      marker.addListener('dragend', (e: GoogleMapMouseEvent) => {
        if (e.latLng) {
          updateMarkerPosition(e.latLng);
        }
      });

      // Initialize autocomplete
      if (searchInput) {
        // @ts-ignore
        autocomplete = new google.maps.places.Autocomplete(searchInput, {
          fields: ['formatted_address', 'geometry', 'name'],
          componentRestrictions: { country: 'sa' }, // Restrict to Saudi Arabia
        });

        autocomplete.addListener('place_changed', () => {
          const place = autocomplete?.getPlace();
          if (place?.geometry?.location) {
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
      // Get user's current location first
      if (navigator.geolocation) {
        console.log('📍 [LocationPicker] Requesting user location...');
        console.log('📍 [LocationPicker] Current initialLat/Lng:', initialLat, initialLng);
        try {
          const position = await new Promise<GeolocationPosition>((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, {
              timeout: 10000,
              enableHighAccuracy: true,
              maximumAge: 0
            });
          });
          console.log('✅ [LocationPicker] Got user location:', position.coords);
          console.log('✅ [LocationPicker] Latitude:', position.coords.latitude);
          console.log('✅ [LocationPicker] Longitude:', position.coords.longitude);
          initialLat = position.coords.latitude;
          initialLng = position.coords.longitude;
          console.log('✅ [LocationPicker] Updated initialLat/Lng:', initialLat, initialLng);
        } catch (err: any) {
          console.error('❌ [LocationPicker] Geolocation error:', err);
          console.warn('⚠️ [LocationPicker] Error code:', err.code);
          console.warn('⚠️ [LocationPicker] Error message:', err.message);
          console.warn('⚠️ [LocationPicker] Using default Riyadh location');
          locationDenied = true;
          // Continue with default Riyadh location
        }
      } else {
        console.warn('⚠️ [LocationPicker] Geolocation not available in this browser');
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
    } catch (err) {
      console.error('❌ [LocationPicker] Failed to load Google Maps:', err);
      error = err instanceof Error ? err.message : texts.error;
      isLoading = false;
    }
  });

  onDestroy(() => {
    // Clean up map instance
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
    <div class="instruction-box">
      <p class="instruction">{texts.dragInstruction}</p>
    </div>
    <div class="map-container" bind:this={mapContainer}></div>
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

  .map-container {
    width: 100%;
    height: 400px;
    border-radius: 12px;
    overflow: hidden;
    border: 2px solid rgba(22, 163, 74, 0.2);
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
</style>
