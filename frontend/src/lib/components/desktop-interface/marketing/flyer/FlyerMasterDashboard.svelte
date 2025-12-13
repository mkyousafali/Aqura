<script lang="ts">
  import { supabase } from '$lib/utils/supabase';
  import { onMount } from 'svelte';
  
  // Stats
  let totalProducts = 0;
  let activeOffers = 0;
  let generatedFlyers = 0;
  let templates = 0;
  let isLoadingStats = true;
  
  // Load stats
  async function loadStats() {
    isLoadingStats = true;
    try {
      // Count total products
      const { count: productsCount, error: productsError } = await supabase
        .from('products')
        .select('*', { count: 'exact', head: true });
      
      if (!productsError) {
        totalProducts = productsCount || 0;
      }
      
      // Count active offers
      const { count: offersCount, error: offersError } = await supabase
        .from('flyer_offers')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true);
      
      if (!offersError) {
        activeOffers = offersCount || 0;
      }
      
      // Count generated flyers (if you have a flyers table)
      // For now, set to 0
      generatedFlyers = 0;
      
      // Count templates (flyer templates)
      // For now, set to 0
      templates = 0;
      
    } catch (error) {
      console.error('Error loading stats:', error);
    }
    isLoadingStats = false;
  }
  
  onMount(() => {
    loadStats();
  });
</script>

<div class="flyer-master-dashboard h-full overflow-auto bg-gradient-to-br from-blue-50 via-purple-50 to-pink-50 p-8">
  <!-- Header -->
  <div class="mb-8">
    <h1 class="text-4xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent mb-2">
      🚀 Flyer Master
    </h1>
    <p class="text-gray-600 text-lg">
      AI-Powered Flyer Creation & Management System
    </p>
    <p class="text-gray-500 text-sm mt-2">
      All features are now accessible from the Media section in the sidebar
    </p>
  </div>
  
  <!-- Quick Stats -->
  <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
    <div class="bg-white rounded-xl p-6 shadow-md border border-gray-100">
      <div class="text-sm text-gray-600 mb-1">Total Products</div>
      <div class="text-3xl font-bold text-blue-600">
        {#if isLoadingStats}
          <svg class="animate-spin w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        {:else}
          {totalProducts}
        {/if}
      </div>
    </div>
    <div class="bg-white rounded-xl p-6 shadow-md border border-gray-100">
      <div class="text-sm text-gray-600 mb-1">Active Offers</div>
      <div class="text-3xl font-bold text-green-600">
        {#if isLoadingStats}
          <svg class="animate-spin w-6 h-6 text-green-600" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        {:else}
          {activeOffers}
        {/if}
      </div>
    </div>
    <div class="bg-white rounded-xl p-6 shadow-md border border-gray-100">
      <div class="text-sm text-gray-600 mb-1">Generated Flyers</div>
      <div class="text-3xl font-bold text-purple-600">
        {#if isLoadingStats}
          <svg class="animate-spin w-6 h-6 text-purple-600" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        {:else}
          {generatedFlyers}
        {/if}
      </div>
    </div>
    <div class="bg-white rounded-xl p-6 shadow-md border border-gray-100">
      <div class="text-sm text-gray-600 mb-1">Templates</div>
      <div class="text-3xl font-bold text-orange-600">
        {#if isLoadingStats}
          <svg class="animate-spin w-6 h-6 text-orange-600" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        {:else}
          {templates}
        {/if}
      </div>
    </div>
  </div>

  <!-- Info Box -->
  <div class="mt-8 bg-blue-50 border border-blue-200 rounded-xl p-6">
    <h2 class="text-xl font-bold text-blue-900 mb-3">📍 Quick Access Guide</h2>
    <p class="text-blue-800 mb-4">Access all Flyer Master features from the Media section in the sidebar:</p>
    <div class="grid md:grid-cols-2 gap-4">
      <div class="bg-white rounded-lg p-4 border border-blue-100">
        <h3 class="font-semibold text-blue-900 mb-2">📊 Manage</h3>
        <ul class="text-sm text-gray-700 space-y-1">
          <li>• Product Master</li>
          <li>• Variation Manager</li>
          <li>• Offer Manager</li>
          <li>• Flyer Templates</li>
          <li>• Settings</li>
        </ul>
      </div>
      <div class="bg-white rounded-lg p-4 border border-blue-100">
        <h3 class="font-semibold text-blue-900 mb-2">⚡ Operations</h3>
        <ul class="text-sm text-gray-700 space-y-1">
          <li>• Offer Product Editor</li>
          <li>• Create New Offer</li>
          <li>• Pricing Manager</li>
          <li>• Generate Flyers</li>
          <li>• Shelf Paper Manager</li>
        </ul>
      </div>
    </div>
  </div>
</div>
