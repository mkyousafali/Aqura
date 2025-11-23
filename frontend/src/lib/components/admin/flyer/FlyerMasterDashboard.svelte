<script lang="ts">
  import { openWindow } from '$lib/utils/windowManagerUtils';
  import ProductMaster from './ProductMaster.svelte';
  import OfferTemplates from './OfferTemplates.svelte';
  import OfferProductSelector from './OfferProductSelector.svelte';
  import OfferManager from './OfferManager.svelte';
  import PricingManager from './PricingManager.svelte';
  import FlyerGenerator from './FlyerGenerator.svelte';
  import FlyerTemplates from './FlyerTemplates.svelte';
  import FlyerSettings from './FlyerSettings.svelte';
  
  interface NavCard {
    id: string;
    title: string;
    description: string;
    icon: string;
    color: string;
    component: any;
  }
  
  const navCards: NavCard[] = [
    {
      id: 'products',
      title: 'Product Master',
      description: 'Manage products, import from Excel, add images',
      icon: '📦',
      color: 'from-blue-500 to-purple-500',
      component: ProductMaster
    },
    {
      id: 'offers',
      title: 'Offer Templates',
      description: 'Create and manage offer templates',
      icon: '🏷️',
      color: 'from-green-500 to-emerald-500',
      component: OfferTemplates
    },
    {
      id: 'offer-selector',
      title: 'Offer Product Selector',
      description: 'Select products for specific offers',
      icon: '✅',
      color: 'from-purple-500 to-pink-500',
      component: OfferProductSelector
    },
    {
      id: 'offer-manager',
      title: 'Offer Manager',
      description: 'Manage active offers and linked products',
      icon: '🎯',
      color: 'from-orange-500 to-red-500',
      component: OfferManager
    },
    {
      id: 'pricing-manager',
      title: 'Pricing Manager',
      description: 'Set pricing, calculate profits for offers',
      icon: '💵',
      color: 'from-yellow-500 to-orange-500',
      component: PricingManager
    },
    {
      id: 'flyers',
      title: 'Generate Flyers',
      description: 'Create and export flyer designs',
      icon: '📄',
      color: 'from-indigo-500 to-blue-500',
      component: FlyerGenerator
    },
    {
      id: 'templates',
      title: 'Flyer Templates',
      description: 'Design templates for flyer layouts',
      icon: '🎨',
      color: 'from-pink-500 to-purple-500',
      component: FlyerTemplates
    },
    {
      id: 'settings',
      title: 'Settings',
      description: 'Configure Flyer Master preferences',
      icon: '⚙️',
      color: 'from-gray-500 to-slate-500',
      component: FlyerSettings
    }
  ];
  
  function generateWindowId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.random().toString(36).substring(7)}`;
  }
  
  function openFeature(card: NavCard) {
    const windowId = generateWindowId(`flyer-${card.id}`);
    const instanceNumber = Math.floor(Math.random() * 1000) + 1;
    
    openWindow({
      id: windowId,
      title: `${card.title} #${instanceNumber}`,
      component: card.component,
      icon: card.icon,
      size: { width: 1400, height: 900 },
      position: { 
        x: 50 + (Math.random() * 100),
        y: 50 + (Math.random() * 100) 
      },
      resizable: true,
      minimizable: true,
      maximizable: true,
      closable: true
    });
  }
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
  </div>
  
  <!-- Navigation Cards Grid -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
    {#each navCards as card (card.id)}
      <button
        on:click={() => openFeature(card)}
        class="group relative bg-white rounded-2xl p-6 shadow-lg hover:shadow-2xl transition-all duration-300 hover:-translate-y-2 border border-gray-100 text-left overflow-hidden"
      >
        <!-- Gradient Background -->
        <div class="absolute inset-0 bg-gradient-to-br {card.color} opacity-0 group-hover:opacity-10 transition-opacity duration-300"></div>
        
        <!-- Content -->
        <div class="relative z-10">
          <!-- Icon -->
          <div class="w-16 h-16 bg-gradient-to-br {card.color} rounded-xl flex items-center justify-center mb-4 shadow-md group-hover:scale-110 transition-transform duration-300">
            <span class="text-3xl">{card.icon}</span>
          </div>
          
          <!-- Title -->
          <h3 class="text-xl font-bold text-gray-800 mb-2 group-hover:text-blue-600 transition-colors">
            {card.title}
          </h3>
          
          <!-- Description -->
          <p class="text-sm text-gray-600 leading-relaxed">
            {card.description}
          </p>
          
          <!-- Arrow Icon -->
          <div class="mt-4 flex items-center text-blue-600 font-semibold text-sm opacity-0 group-hover:opacity-100 transition-opacity">
            Open
            <svg class="w-4 h-4 ml-1 group-hover:translate-x-1 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </div>
      </button>
    {/each}
  </div>
  
  <!-- Quick Stats (Optional) -->
  <div class="mt-8 grid grid-cols-1 md:grid-cols-4 gap-4">
    <div class="bg-white rounded-xl p-4 shadow-md border border-gray-100">
      <div class="text-sm text-gray-600">Total Products</div>
      <div class="text-2xl font-bold text-blue-600">0</div>
    </div>
    <div class="bg-white rounded-xl p-4 shadow-md border border-gray-100">
      <div class="text-sm text-gray-600">Active Offers</div>
      <div class="text-2xl font-bold text-green-600">0</div>
    </div>
    <div class="bg-white rounded-xl p-4 shadow-md border border-gray-100">
      <div class="text-sm text-gray-600">Generated Flyers</div>
      <div class="text-2xl font-bold text-purple-600">0</div>
    </div>
    <div class="bg-white rounded-xl p-4 shadow-md border border-gray-100">
      <div class="text-sm text-gray-600">Templates</div>
      <div class="text-2xl font-bold text-orange-600">0</div>
    </div>
  </div>
</div>
