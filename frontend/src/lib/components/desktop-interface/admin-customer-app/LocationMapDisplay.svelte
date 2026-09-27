<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { browser } from '$app/environment';
  import { fetchGoogleMapsKey } from '$lib/utils/googleMapsKey';

  export let locations: Array<{ name: string; lat: number; lng: number; url: string }> = [];
  export let selectedIndex: number = 0;
  export let onLocationClick: ((index: number) => void) | null = null;
  export let language: string = 'ar';
  export let height: string = '300px';

  let map: any = null;
  let markers: any[] = [];
  let mapContainer: HTMLDivElement;
  let isLoading = true;
  let error = '';

  console.log('🗺️ [LocationMapDisplay] Component initialized');
  console.log('🗺️ Locations:', locations);
  console.log('🗺️ Height:', height);

  const texts = language === 'ar' ? {
    loading: 'جاري تحميل الخريطة...',
    error: 'فشل تحميل الخريطة',
    noLocations: 'لا توجد مواقع محفوظة',
    noApiKey: 'لم يتم العثور على مفتاح API للخرائط'
  } : {
    loading: 'Loading map...',
    error: 'Failed to load map',
    noLocations: 'No saved locations',
    noApiKey: 'Google Maps API key not found'
  };

  async function loadGoogleMapsScript(): Promise<void> {
    // Reuse an already-loaded Maps SDK, otherwise fetch the active table key.
    if ((window as any).google?.maps) return;
    let apiKey: string;
    try {
      apiKey = await fetchGoogleMapsKey();
    } catch {
      throw new Error(texts.noApiKey);
    }

    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&libraries=places&language=${language}`;
      script.async = true;
      script.defer = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error(texts.error));
      document.head.appendChild(script);
    });
  }

  function initMap() {
    if (!mapContainer || !browser || locations.length === 0) {
      console.log('🗺️ [LocationMapDisplay] initMap - Early return:', { 
        mapContainer: !!mapContainer, 
        browser, 
        locationsLength: locations.length 
      });
      return;
    }

    console.log('🗺️ [LocationMapDisplay] Initializing map with locations:', locations);

    const bounds = new (window as any).google.maps.LatLngBounds();
    const firstLocation = locations[0];

    const mapOptions = {
      center: { lat: firstLocation.lat, lng: firstLocation.lng },
      zoom: 13,
      mapTypeId: 'satellite',
      mapTypeControl: false,
      streetViewControl: false,
      fullscreenControl: false,
      zoomControl: false,
    };

    // @ts-ignore
    map = new google.maps.Map(mapContainer, mapOptions);

    // Clear existing markers
    markers.forEach(m => m.setMap(null));
    markers = [];

    // Add markers for each location
    locations.forEach((location, index) => {
      // @ts-ignore
      const marker = new google.maps.Marker({
        position: { lat: location.lat, lng: location.lng },
        map: map,
        title: location.name,
        // Use smaller custom icons
        icon: index === selectedIndex 
          ? {
              url: "http://maps.google.com/mapfiles/ms/icons/red-dot.png",
              scaledSize: new google.maps.Size(32, 32)
            }
          : {
              url: "http://maps.google.com/mapfiles/ms/icons/blue-dot.png",
              scaledSize: new google.maps.Size(32, 32)
            }
      });

      // Add click listener
      marker.addListener('click', () => {
        if (onLocationClick) {
          onLocationClick(index);
        }
      });

      // Add info window
      // @ts-ignore
      const infoWindow = new google.maps.InfoWindow({
        content: `<div style="padding: 0.5rem;">
          <strong style="color: #16a34a;">${location.name}</strong><br>
          <small style="color: #6b7280;">${location.lat.toFixed(6)}, ${location.lng.toFixed(6)}</small>
        </div>`
      });

      marker.addListener('mouseover', () => {
        infoWindow.open(map, marker);
      });

      marker.addListener('mouseout', () => {
        infoWindow.close();
      });

      markers.push(marker);
      bounds.extend({ lat: location.lat, lng: location.lng });
    });

    // Fit map to show all markers
    if (locations.length > 1) {
      map.fitBounds(bounds);
    } else {
      map.setZoom(15);
    }
  }

  function updateMarkerStyles() {
    markers.forEach((marker, index) => {
      // Set smaller pin icons
      marker.setIcon(
        index === selectedIndex 
          ? {
              url: "http://maps.google.com/mapfiles/ms/icons/red-dot.png",
              scaledSize: new (window as any).google.maps.Size(32, 32)
            }
          : {
              url: "http://maps.google.com/mapfiles/ms/icons/blue-dot.png",
              scaledSize: new (window as any).google.maps.Size(32, 32)
            }
      );
    });
  }

  onMount(async () => {
    if (!browser || locations.length === 0) {
      console.log('🗺️ [LocationMapDisplay] onMount - Skipping:', { browser, locationsLength: locations.length });
      isLoading = false;
      return;
    }

    console.log('🗺️ [LocationMapDisplay] onMount - Loading Google Maps...');

    try {
      await loadGoogleMapsScript();
      console.log('🗺️ [LocationMapDisplay] Google Maps script loaded successfully');
      
      // Wait for mapContainer to be available in the DOM
      await new Promise(resolve => setTimeout(resolve, 100));
      
      if (mapContainer) {
        initMap();
        console.log('🗺️ [LocationMapDisplay] Map initialized successfully');
      } else {
        console.error('❌ [LocationMapDisplay] mapContainer not available after delay');
        error = 'Map container not ready';
      }
      
      isLoading = false;
    } catch (err) {
      console.error('❌ [LocationMapDisplay] Failed to load Google Maps:', err);
      error = err instanceof Error ? err.message : texts.error;
      isLoading = false;
    }
  });

  onDestroy(() => {
    markers.forEach(m => m.setMap(null));
    if (map) map = null;
  });

  // Initialize map when container becomes available
  $: if (mapContainer && locations.length > 0 && !map && !isLoading) {
    console.log('🗺️ [LocationMapDisplay] Reactive: mapContainer now available, initializing map');
    (async () => {
      try {
        await loadGoogleMapsScript();
        initMap();
      } catch (err) {
        console.error('❌ [LocationMapDisplay] Reactive init failed:', err);
      }
    })();
  }

  // Update marker styles when selectedIndex changes
  $: if (map && markers.length > 0) {
    updateMarkerStyles();
  }

  // Reinitialize map when locations change
  $: if (locations.length > 0 && map) {
    initMap();
  }
</script>

<div class="map-display" style="height: {height};">
  <div class="map-container" bind:this={mapContainer} style="display: {isLoading || error || locations.length === 0 ? 'none' : 'block'}; width: 100%; height: 100%;"></div>
  
  {#if isLoading}
    <div class="status-message">
      <div class="spinner"></div>
      <p>{texts.loading}</p>
    </div>
  {:else if error}
    <div class="status-message error">
      <p>❌ {error}</p>
    </div>
  {:else if locations.length === 0}
    <div class="status-message">
      <p>📍 {texts.noLocations}</p>
    </div>
  {/if}
</div>

<style>
  .map-display {
    width: 100%;
    position: relative;
    border-radius: 12px;
    overflow: hidden;
  }

  .map-container {
    width: 100%;
    height: 100%;
    position: relative;
  }

  .status-message {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: 1rem;
    background: #f9fafb;
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
  }

  .status-message p {
    margin: 0;
    color: #6b7280;
    font-size: 0.9rem;
  }

  .status-message.error p {
    color: #dc2626;
    font-weight: 600;
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

  .map-container {
    width: 100%;
    height: 100%;
  }

  /* Hide Google Maps UI elements in thumbnails */
  .map-container :global(a[href^="https://maps.google.com"]),
  .map-container :global(.gmnoprint),
  .map-container :global(.gm-style-cc) {
    display: none !important;
  }
</style>
