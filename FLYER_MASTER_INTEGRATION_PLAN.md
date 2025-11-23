# Flyer Master Integration Plan - Complete Implementation Guide

**Project:** Integrate Flyer Master into Aqura System  
**Date:** November 23, 2025  
**Status:** Ready for Implementation  
**Critical Goal:** Make Flyer Master work EXACTLY as it currently works in the standalone app

---

## Table of Contents

1. [Current Status](#current-status)
2. [Integration Architecture](#integration-architecture)
3. [Sidebar Navigation Setup](#sidebar-navigation-setup)
4. [Phase-by-Phase Implementation](#phase-by-phase-implementation)
5. [Component Migration Details](#component-migration-details)
6. [Database & API Integration](#database--api-integration)
7. [Feature Preservation Checklist](#feature-preservation-checklist)
8. [Testing & Verification](#testing--verification)
9. [Timeline & Effort Estimates](#timeline--effort-estimates)

---

## Current Status

### ✅ Completed Infrastructure

**Database Tables Created:**
- `flyer_products` - Product catalog with barcode, bilingual names, 3-level categories, image URLs
- `flyer_offers` - Offer templates with date ranges, is_active status
- `flyer_offer_products` - Junction table with pricing logic (cost, sales_price, offer_price, profit calculations, quantities)

**Storage Configuration:**
- Bucket: `flyer-product-images`
- Size Limit: 20MB
- Access: Public
- Formats: PNG, JPEG, JPG, WEBP

**Environment Variables Configured:**
- ✅ VITE_GOOGLE_MAPS_API_KEY
- ✅ VITE_OPENAI_API_KEY
- ✅ REMOVE_BG_API_KEY (7r9uJ1ZEmMg5ZddCAuLBGeG2) - **50 uses/month limit**
- ✅ GOOGLE_API_KEY
- ✅ GOOGLE_SEARCH_ENGINE_ID (a4b279612d92f4367)
- ✅ Supabase credentials (URL, Anon Key, Service Role Key)
- ✅ VAPID keys

**Verification Status:**
- All 3 tables exist (0 records)
- Storage bucket operational (20MB, public, 4 mime types)
- Development server running on localhost:5173

### 📦 Source Location
- **Flyer Master App:** `D:\Aqura\Flyer Master\src`
- **Routes (Pages):** `D:\Aqura\Flyer Master\src\routes\`
  - `/` - Dashboard (home page)
  - `/products` - Product Master
  - `/offers` - Offer Templates
  - `/offer-selector` - Offer Product Selector
  - `/offer-manager` - Offer Manager ✨
  - `/pricing-manager` - Pricing Manager
  - `/flyers` - Flyer Generator
  - `/templates` - Flyer Templates
  - `/settings` - Settings
- **Components:** `D:\Aqura\Flyer Master\src\lib\components\`
  - ProductMaster.svelte
  - OfferSelector.svelte
  - PriceMaker.svelte
- **Supabase Client:** `D:\Aqura\Flyer Master\src\lib\supabaseClient.ts`

---

## Integration Architecture

### Strategy: Windowed MDI Integration

Flyer Master will integrate into Aqura as a **windowed application** following the existing pattern:
- Opens in a draggable, resizable window
- Managed by WindowManager
- Accessible from sidebar menu
- Full-screen capable
- Can be popped out to separate browser window

### Navigation Path
```
Sidebar Menu
└── Marketing Master (Parent Menu Item)
    └── Flyer Master (Sub-menu Item) ✨ NEW
        └── Opens FlyerMasterDashboard window
```

### Component Hierarchy
```
+layout.svelte
├── Sidebar.svelte
│   └── Marketing Master Menu
│       └── Flyer Master (onClick: openFlyerMaster)
├── WindowManager.svelte
│   └── FlyerMasterDashboard.svelte (Main Dashboard Window)
│       └── Opens child windows on card click:
│           ├── ProductMaster.svelte
│           ├── OfferTemplates.svelte
│           ├── OfferProductSelector.svelte
│           ├── OfferManager.svelte ✨
│           ├── PricingManager.svelte
│           ├── FlyerGenerator.svelte
│           ├── FlyerTemplates.svelte
│           └── FlyerSettings.svelte
```

---

## Sidebar Navigation Setup

### Location in Aqura
The sidebar menu is likely in one of these files:
- `frontend/src/lib/components/Sidebar.svelte`
- `frontend/src/routes/+layout.svelte` (inline menu)

### Menu Structure to Add

**New Top-Level "Marketing Master" Section**
```javascript
{
  id: 'marketing-master',
  title: 'Marketing Master',
  icon: '📢', // or appropriate icon
  children: [
    {
      id: 'flyer-master',
      title: 'Flyer Master',
      icon: '🏷️',
      onClick: () => openWindow({
        id: 'flyer-master',
        componentName: 'FlyerMasterDashboard',
        title: 'Flyer Master',
        icon: '🏷️',
        width: 1400,
        height: 900
      })
    }
  ]
}
```

### Implementation Steps

1. **Locate Sidebar Menu Definition**
   - Search for menu items array in Sidebar.svelte or +layout.svelte
   - Identify the menu structure pattern

2. **Add Marketing Master Section**
   - Create new menu item with `id: 'marketing-master'`
   - Add Flyer Master as child item

3. **Connect Window Opener**
   - Import `openWindow` from windowManagerUtils
   - Configure window parameters (size, component, title)

4. **Register Component in +layout.svelte**
   - Add dynamic import for FlyerMasterDashboard
   - Map componentName to import statement

---

## Phase-by-Phase Implementation

### Phase 1: Dependencies Installation (15 minutes)

**Install Required Packages:**
```bash
cd frontend
pnpm add exceljs @imgly/background-removal jsbarcode xlsx
```

**Packages Purpose:**
- `exceljs` - Excel file import/export operations
- `@imgly/background-removal` - Remove.bg API integration for product images
- `jsbarcode` - Barcode generation for products
- `xlsx` - Alternative Excel parsing

**Verification:**
```bash
# Check package.json includes all dependencies
grep -E "exceljs|background-removal|jsbarcode|xlsx" package.json
```

---

### Phase 2: Component Migration (2-3 hours)

**Step 2.1: Create Directory Structure**
```bash
# Create flyer components directory
mkdir -p frontend/src/lib/components/admin/flyer
```

**Step 2.2: Copy/Create Core Components**

Create component files in `frontend\src\lib\components\admin\flyer\`:

**From existing Flyer Master app:**
- Copy `ProductMaster.svelte` from `D:\Aqura\Flyer Master\src\lib\components\`
- Copy `OfferSelector.svelte` from `D:\Aqura\Flyer Master\src\lib\components\`
- Copy `PriceMaker.svelte` from `D:\Aqura\Flyer Master\src\lib\components\`

**From Flyer Master routes (migrate route pages to components):**
- Migrate `/products/+page.svelte` → `ProductMaster.svelte`
- Migrate `/offers/+page.svelte` → `OfferTemplates.svelte`
- Migrate `/offer-selector/+page.svelte` → `OfferProductSelector.svelte`
- Migrate `/offer-manager/+page.svelte` → `OfferManager.svelte` ✨
- Migrate `/pricing-manager/+page.svelte` → `PricingManager.svelte`
- Migrate `/flyers/+page.svelte` → `FlyerGenerator.svelte`
- Migrate `/templates/+page.svelte` → `FlyerTemplates.svelte`
- Migrate `/settings/+page.svelte` → `FlyerSettings.svelte`

**Note:** Each route page needs to be converted to a standalone component that can be opened in a window.

**Step 2.3: Create Dashboard Component**

Create `frontend/src/lib/components/admin/flyer/FlyerMasterDashboard.svelte`:

This is the main dashboard with navigation cards to access all Flyer Master features:

```svelte
<script lang="ts">
  import { openWindow } from '$lib/utils/windowManagerUtils';
  
  interface NavCard {
    id: string;
    title: string;
    description: string;
    icon: string;
    color: string;
    component: string;
  }
  
  const navCards: NavCard[] = [
    {
      id: 'products',
      title: 'Product Master',
      description: 'Manage products, import from Excel, add images',
      icon: '📦',
      color: 'from-blue-500 to-purple-500',
      component: 'ProductMaster'
    },
    {
      id: 'offers',
      title: 'Offer Templates',
      description: 'Create and manage offer templates',
      icon: '🏷️',
      color: 'from-green-500 to-emerald-500',
      component: 'OfferTemplates'
    },
    {
      id: 'offer-selector',
      title: 'Offer Product Selector',
      description: 'Select products for specific offers',
      icon: '✅',
      color: 'from-purple-500 to-pink-500',
      component: 'OfferProductSelector'
    },
    {
      id: 'offer-manager',
      title: 'Offer Manager',
      description: 'Manage active offers and linked products',
      icon: '🎯',
      color: 'from-orange-500 to-red-500',
      component: 'OfferManager'
    },
    {
      id: 'pricing-manager',
      title: 'Pricing Manager',
      description: 'Set pricing, calculate profits for offers',
      icon: '💵',
      color: 'from-yellow-500 to-orange-500',
      component: 'PricingManager'
    },
    {
      id: 'flyers',
      title: 'Generate Flyers',
      description: 'Create and export flyer designs',
      icon: '📄',
      color: 'from-indigo-500 to-blue-500',
      component: 'FlyerGenerator'
    },
    {
      id: 'templates',
      title: 'Flyer Templates',
      description: 'Design templates for flyer layouts',
      icon: '🎨',
      color: 'from-pink-500 to-purple-500',
      component: 'FlyerTemplates'
    },
    {
      id: 'settings',
      title: 'Settings',
      description: 'Configure Flyer Master preferences',
      icon: '⚙️',
      color: 'from-gray-500 to-slate-500',
      component: 'FlyerSettings'
    }
  ];
  
  function openFeature(card: NavCard) {
    openWindow({
      id: `flyer-${card.id}`,
      componentName: card.component,
      title: card.title,
      icon: card.icon,
      width: 1400,
      height: 900
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
```

**Step 2.4: Update All Import Paths**

In each copied component, replace:
```typescript
// OLD (Flyer Master standalone)
import { supabase } from '$lib/supabaseClient';

// NEW (Aqura integrated)
import { supabase } from '$lib/supabaseClient';
// Note: Aqura already has this, verify it's using the same Supabase instance
```

**Step 2.5: Update Table References**

Search and replace in all components:
- No changes needed! We're using `flyer_products`, `flyer_offers`, `flyer_offer_products` which already match our migrations

---

### Phase 3: Supabase Client Integration (30 minutes)

**Step 3.1: Verify Supabase Client**

Check `frontend/src/lib/supabaseClient.ts` exists and is configured:
```typescript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
```

**Step 3.2: Test Database Connection**

Create test script `frontend/src/lib/components/admin/flyer/test-connection.ts`:
```typescript
import { supabase } from '$lib/supabaseClient';

export async function testFlyerConnection() {
  const { data: products, error: prodError } = await supabase
    .from('flyer_products')
    .select('*')
    .limit(1);
    
  const { data: offers, error: offerError } = await supabase
    .from('flyer_offers')
    .select('*')
    .limit(1);
    
  console.log('🧪 Flyer Tables Test:', {
    products: prodError ? 'ERROR' : 'OK',
    offers: offerError ? 'ERROR' : 'OK'
  });
}
```

---

### Phase 4: ProductMaster.svelte - Full Feature Implementation (3-4 hours)

**Current State Analysis:**
The component has basic CRUD UI but needs database integration.

**Required Features to Implement:**

#### 4.1 Database CRUD Operations

**Load Products:**
```typescript
import { supabase } from '$lib/supabaseClient';
import { onMount } from 'svelte';

let products = [];
let loading = false;

onMount(async () => {
  await loadProducts();
});

async function loadProducts() {
  loading = true;
  try {
    const { data, error } = await supabase
      .from('flyer_products')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (error) throw error;
    products = data || [];
  } catch (err) {
    console.error('Failed to load products:', err);
    // TODO: Show error toast
  } finally {
    loading = false;
  }
}
```

**Add Product:**
```typescript
async function addProduct() {
  if (!newProductName || !newProductCategory) {
    alert('Please fill all fields');
    return;
  }
  
  try {
    const { data, error } = await supabase
      .from('flyer_products')
      .insert([{
        barcode: generateBarcode(), // Implement barcode generation
        product_name_en: newProductName,
        product_name_ar: newProductNameAr || newProductName,
        main_category: newProductCategory,
        sub_category: newSubCategory || null,
        final_category: newFinalCategory || null,
        image_url: null
      }])
      .select()
      .single();
    
    if (error) throw error;
    
    products = [data, ...products];
    resetForm();
    // TODO: Show success toast
  } catch (err) {
    console.error('Failed to add product:', err);
  }
}
```

**Delete Product:**
```typescript
async function removeProduct(id: string) {
  if (!confirm('Delete this product?')) return;
  
  try {
    const { error } = await supabase
      .from('flyer_products')
      .delete()
      .eq('id', id);
    
    if (error) throw error;
    
    products = products.filter(p => p.id !== id);
    // TODO: Show success toast
  } catch (err) {
    console.error('Failed to delete product:', err);
  }
}
```

#### 4.2 Excel Import/Export

**Import from Excel:**
```typescript
import * as XLSX from 'xlsx';

async function importFromExcel(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (!file) return;
  
  try {
    const data = await file.arrayBuffer();
    const workbook = XLSX.read(data);
    const worksheet = workbook.Sheets[workbook.SheetNames[0]];
    const jsonData = XLSX.utils.sheet_to_json(worksheet);
    
    // Map Excel columns to database fields
    const products = jsonData.map(row => ({
      barcode: row['Barcode'] || generateBarcode(),
      product_name_en: row['Product Name (EN)'],
      product_name_ar: row['Product Name (AR)'],
      main_category: row['Main Category'],
      sub_category: row['Sub Category'],
      final_category: row['Final Category'],
      image_url: null
    }));
    
    // Bulk insert
    const { data: inserted, error } = await supabase
      .from('flyer_products')
      .insert(products)
      .select();
    
    if (error) throw error;
    
    await loadProducts(); // Reload
    alert(`Imported ${inserted.length} products`);
  } catch (err) {
    console.error('Import failed:', err);
    alert('Import failed: ' + err.message);
  }
}
```

**Export to Excel:**
```typescript
import * as ExcelJS from 'exceljs';

async function exportToExcel() {
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet('Products');
  
  // Define columns
  worksheet.columns = [
    { header: 'Barcode', key: 'barcode', width: 15 },
    { header: 'Product Name (EN)', key: 'product_name_en', width: 30 },
    { header: 'Product Name (AR)', key: 'product_name_ar', width: 30 },
    { header: 'Main Category', key: 'main_category', width: 20 },
    { header: 'Sub Category', key: 'sub_category', width: 20 },
    { header: 'Final Category', key: 'final_category', width: 20 },
    { header: 'Image URL', key: 'image_url', width: 40 }
  ];
  
  // Add rows
  products.forEach(product => {
    worksheet.addRow(product);
  });
  
  // Style header row
  worksheet.getRow(1).font = { bold: true };
  worksheet.getRow(1).fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFE0E0E0' }
  };
  
  // Download
  const buffer = await workbook.xlsx.writeBuffer();
  const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `products_${new Date().toISOString().split('T')[0]}.xlsx`;
  a.click();
  window.URL.revokeObjectURL(url);
}
```

#### 4.3 Image Upload & Management

**Upload Image to Supabase Storage:**
```typescript
async function uploadProductImage(productId: string, file: File) {
  try {
    // Generate unique filename
    const fileExt = file.name.split('.').pop();
    const fileName = `${productId}_${Date.now()}.${fileExt}`;
    const filePath = `products/${fileName}`;
    
    // Upload to storage
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from('flyer-product-images')
      .upload(filePath, file, {
        cacheControl: '3600',
        upsert: false
      });
    
    if (uploadError) throw uploadError;
    
    // Get public URL
    const { data: urlData } = supabase.storage
      .from('flyer-product-images')
      .getPublicUrl(filePath);
    
    // Update product record
    const { error: updateError } = await supabase
      .from('flyer_products')
      .update({ image_url: urlData.publicUrl })
      .eq('id', productId);
    
    if (updateError) throw updateError;
    
    await loadProducts(); // Reload to show new image
    alert('Image uploaded successfully!');
  } catch (err) {
    console.error('Image upload failed:', err);
    alert('Upload failed: ' + err.message);
  }
}
```

#### 4.4 Google Image Search Integration

**Search Google for Product Images:**
```typescript
async function searchProductImage(productName: string) {
  try {
    const apiKey = import.meta.env.GOOGLE_API_KEY;
    const searchEngineId = import.meta.env.GOOGLE_SEARCH_ENGINE_ID;
    
    const response = await fetch(
      `https://www.googleapis.com/customsearch/v1?` +
      `key=${apiKey}&cx=${searchEngineId}&q=${encodeURIComponent(productName)}&searchType=image&num=10`
    );
    
    if (!response.ok) throw new Error('Search failed');
    
    const data = await response.json();
    const images = data.items?.map(item => ({
      url: item.link,
      thumbnail: item.image.thumbnailLink,
      title: item.title
    })) || [];
    
    // Show image picker modal with results
    showImagePicker(images);
  } catch (err) {
    console.error('Image search failed:', err);
    alert('Search failed: ' + err.message);
  }
}
```

#### 4.5 Background Removal (Remove.bg Integration)

**⚠️ IMPORTANT: 50 uses/month limit on API key**

```typescript
import { removeBackground } from '@imgly/background-removal';

async function removeImageBackground(imageUrl: string, productId: string) {
  // Confirm before using (limited API calls)
  if (!confirm('Remove background? (Limited to 50 uses/month)')) return;
  
  try {
    // Fetch image
    const response = await fetch(imageUrl);
    const blob = await response.blob();
    
    // Remove background
    const resultBlob = await removeBackground(blob, {
      apiKey: import.meta.env.REMOVE_BG_API_KEY,
      model: 'isnet-general-use',
      output: {
        format: 'png',
        type: 'blob'
      }
    });
    
    // Upload processed image
    const file = new File([resultBlob], 'background-removed.png', { type: 'image/png' });
    await uploadProductImage(productId, file);
    
  } catch (err) {
    console.error('Background removal failed:', err);
    alert('Background removal failed: ' + err.message);
  }
}
```

#### 4.6 Barcode Generation

```typescript
import JsBarcode from 'jsbarcode';

function generateBarcode(): string {
  // Generate 13-digit EAN barcode
  const prefix = '200'; // Internal product prefix
  const random = Math.floor(Math.random() * 1000000000).toString().padStart(9, '0');
  const barcode = prefix + random;
  
  // Calculate check digit
  const checkDigit = calculateEAN13CheckDigit(barcode);
  return barcode + checkDigit;
}

function calculateEAN13CheckDigit(barcode: string): string {
  let sum = 0;
  for (let i = 0; i < 12; i++) {
    const digit = parseInt(barcode[i]);
    sum += (i % 2 === 0) ? digit : digit * 3;
  }
  const checkDigit = (10 - (sum % 10)) % 10;
  return checkDigit.toString();
}

function renderBarcode(barcode: string, canvasId: string) {
  JsBarcode(`#${canvasId}`, barcode, {
    format: 'EAN13',
    width: 2,
    height: 100,
    displayValue: true
  });
}
```

#### 4.7 Product Search & Filtering

```typescript
let searchTerm = '';
let categoryFilter = 'all';

$: filteredProducts = products.filter(product => {
  const matchesSearch = !searchTerm || 
    product.product_name_en.toLowerCase().includes(searchTerm.toLowerCase()) ||
    product.product_name_ar.includes(searchTerm) ||
    product.barcode.includes(searchTerm);
  
  const matchesCategory = categoryFilter === 'all' || 
    product.main_category === categoryFilter;
  
  return matchesSearch && matchesCategory;
});

$: categories = [...new Set(products.map(p => p.main_category))];
```

---

### Phase 5: OfferSelector.svelte - Full Feature Implementation (2-3 hours)

**Current State Analysis:**
Component has UI for selecting offers but needs database integration and template system.

**Required Features:**

#### 5.1 Load Offers from Database

```typescript
import { supabase } from '$lib/supabaseClient';
import { onMount } from 'svelte';

let offers = [];
let loading = false;

onMount(async () => {
  await loadOffers();
});

async function loadOffers() {
  loading = true;
  try {
    const { data, error } = await supabase
      .from('flyer_offers')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (error) throw error;
    
    // Transform to UI format
    offers = data.map(offer => ({
      id: offer.id,
      template_id: offer.template_id,
      title: offer.template_name,
      discount: offer.discount_text || 'Special Offer',
      description: offer.description || '',
      icon: offer.icon_emoji || '🎁',
      color: offer.color_gradient || 'from-blue-500 to-purple-500',
      selected: false,
      startDate: offer.start_date,
      endDate: offer.end_date,
      isActive: offer.is_active
    }));
  } catch (err) {
    console.error('Failed to load offers:', err);
  } finally {
    loading = false;
  }
}
```

#### 5.2 Create New Offer Template

```typescript
async function createOffer(templateData: {
  template_name: string;
  description: string;
  start_date: string;
  end_date: string;
  discount_text?: string;
  icon_emoji?: string;
  color_gradient?: string;
}) {
  try {
    // Generate unique template_id
    const template_id = `TEMPLATE_${Date.now()}`;
    
    const { data, error } = await supabase
      .from('flyer_offers')
      .insert([{
        template_id,
        template_name: templateData.template_name,
        description: templateData.description,
        start_date: templateData.start_date,
        end_date: templateData.end_date,
        is_active: true,
        discount_text: templateData.discount_text || null,
        icon_emoji: templateData.icon_emoji || '🎁',
        color_gradient: templateData.color_gradient || 'from-blue-500 to-purple-500'
      }])
      .select()
      .single();
    
    if (error) throw error;
    
    await loadOffers(); // Reload
    alert('Offer template created!');
  } catch (err) {
    console.error('Failed to create offer:', err);
    alert('Failed to create offer: ' + err.message);
  }
}
```

#### 5.3 Toggle Offer Selection & Link Products

```typescript
let selectedProducts = []; // From ProductMaster

async function linkProductsToOffer(offerId: string, productBarcodes: string[]) {
  try {
    // Prepare offer_product records
    const records = productBarcodes.map(barcode => ({
      offer_id: offerId,
      product_barcode: barcode,
      cost: 0, // To be filled by user
      sales_price: 0,
      offer_price: 0,
      profit_amount: 0,
      profit_percent: 0,
      profit_after_offer: 0,
      decrease_amount: 0,
      offer_qty: 0,
      limit_qty: 0,
      free_qty: 0
    }));
    
    const { data, error } = await supabase
      .from('flyer_offer_products')
      .insert(records)
      .select();
    
    if (error) throw error;
    
    alert(`Linked ${data.length} products to offer`);
  } catch (err) {
    console.error('Failed to link products:', err);
    alert('Failed to link products: ' + err.message);
  }
}
```

#### 5.4 Activate/Deactivate Offers

```typescript
async function toggleOfferStatus(offerId: string, isActive: boolean) {
  try {
    const { error } = await supabase
      .from('flyer_offers')
      .update({ is_active: isActive })
      .eq('id', offerId);
    
    if (error) throw error;
    
    await loadOffers(); // Reload
  } catch (err) {
    console.error('Failed to toggle offer:', err);
  }
}
```

#### 5.5 Date Range Validation

```typescript
function validateDateRange(startDate: string, endDate: string): boolean {
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  if (start > end) {
    alert('End date must be after start date');
    return false;
  }
  
  return true;
}

$: activeOffers = offers.filter(offer => {
  if (!offer.isActive) return false;
  
  const now = new Date();
  const start = new Date(offer.startDate);
  const end = new Date(offer.endDate);
  
  return now >= start && now <= end;
});
```

---

### Phase 6: PriceMaker.svelte - Full Feature Implementation (2-3 hours)

**Current State Analysis:**
Component has pricing calculation UI but needs integration with offer system.

**Required Features:**

#### 6.1 Load Product Pricing from Database

```typescript
import { supabase } from '$lib/supabaseClient';

let selectedProductBarcode = '';
let offerProducts = [];

async function loadProductPricing(productBarcode: string, offerId: string) {
  try {
    const { data, error } = await supabase
      .from('flyer_offer_products')
      .select('*')
      .eq('product_barcode', productBarcode)
      .eq('offer_id', offerId)
      .single();
    
    if (error) throw error;
    
    if (data) {
      priceConfig = {
        originalPrice: data.sales_price,
        cost: data.cost,
        offerPrice: data.offer_price,
        profitAmount: data.profit_amount,
        profitPercent: data.profit_percent,
        profitAfterOffer: data.profit_after_offer,
        decreaseAmount: data.decrease_amount,
        offerQty: data.offer_qty,
        limitQty: data.limit_qty,
        freeQty: data.free_qty
      };
    }
  } catch (err) {
    console.error('Failed to load pricing:', err);
  }
}
```

#### 6.2 Calculate Profit & Discount

```typescript
type PriceConfig = {
  cost: number;
  salesPrice: number;
  offerPrice: number;
  offerQty: number;
  limitQty: number;
  freeQty: number;
};

let priceConfig: PriceConfig = {
  cost: 0,
  salesPrice: 0,
  offerPrice: 0,
  offerQty: 0,
  limitQty: 0,
  freeQty: 0
};

// Reactive calculations
$: profitAmount = priceConfig.salesPrice - priceConfig.cost;
$: profitPercent = priceConfig.cost > 0 
  ? ((profitAmount / priceConfig.cost) * 100).toFixed(2) 
  : 0;

$: offerDiscount = priceConfig.salesPrice - priceConfig.offerPrice;
$: offerDiscountPercent = priceConfig.salesPrice > 0
  ? ((offerDiscount / priceConfig.salesPrice) * 100).toFixed(2)
  : 0;

$: profitAfterOffer = priceConfig.offerPrice - priceConfig.cost;
$: profitAfterOfferPercent = priceConfig.cost > 0
  ? ((profitAfterOffer / priceConfig.cost) * 100).toFixed(2)
  : 0;

$: decreaseAmount = profitAmount - profitAfterOffer;
$: decreasePercent = profitAmount > 0
  ? ((decreaseAmount / profitAmount) * 100).toFixed(2)
  : 0;
```

#### 6.3 Save Pricing to Database

```typescript
async function savePricing(productBarcode: string, offerId: string) {
  try {
    const { error } = await supabase
      .from('flyer_offer_products')
      .update({
        cost: priceConfig.cost,
        sales_price: priceConfig.salesPrice,
        offer_price: priceConfig.offerPrice,
        profit_amount: profitAmount,
        profit_percent: parseFloat(profitPercent),
        profit_after_offer: profitAfterOffer,
        decrease_amount: decreaseAmount,
        offer_qty: priceConfig.offerQty,
        limit_qty: priceConfig.limitQty,
        free_qty: priceConfig.freeQty
      })
      .eq('product_barcode', productBarcode)
      .eq('offer_id', offerId);
    
    if (error) throw error;
    
    alert('Pricing saved successfully!');
  } catch (err) {
    console.error('Failed to save pricing:', err);
    alert('Failed to save pricing: ' + err.message);
  }
}
```

#### 6.4 Bulk Pricing Operations

**Apply Pricing to Multiple Products:**
```typescript
async function bulkUpdatePricing(
  productBarcodes: string[],
  offerId: string,
  pricingTemplate: Partial<PriceConfig>
) {
  try {
    const updates = productBarcodes.map(barcode => ({
      product_barcode: barcode,
      offer_id: offerId,
      ...pricingTemplate,
      // Recalculate profit fields
      profit_amount: pricingTemplate.salesPrice - pricingTemplate.cost,
      profit_after_offer: pricingTemplate.offerPrice - pricingTemplate.cost
    }));
    
    const { error } = await supabase
      .from('flyer_offer_products')
      .upsert(updates);
    
    if (error) throw error;
    
    alert(`Updated pricing for ${updates.length} products`);
  } catch (err) {
    console.error('Bulk update failed:', err);
    alert('Bulk update failed: ' + err.message);
  }
}
```

#### 6.5 Pricing Templates

```typescript
const pricingTemplates = [
  {
    name: 'Standard Markup',
    description: '30% profit margin',
    calculateOfferPrice: (cost: number) => cost * 1.30
  },
  {
    name: 'Clearance Sale',
    description: '10% profit margin',
    calculateOfferPrice: (cost: number) => cost * 1.10
  },
  {
    name: 'Premium Pricing',
    description: '50% profit margin',
    calculateOfferPrice: (cost: number) => cost * 1.50
  },
  {
    name: 'Break Even',
    description: '0% profit',
    calculateOfferPrice: (cost: number) => cost
  }
];

function applyPricingTemplate(template: typeof pricingTemplates[0]) {
  priceConfig.offerPrice = template.calculateOfferPrice(priceConfig.cost);
}
```

---

### Phase 7: Window Registration in +layout.svelte (30 minutes)

**Step 7.1: Add Dynamic Import**

In `frontend/src/routes/+layout.svelte`, add to the switch statement:

```typescript
case 'FlyerMasterDashboard':
  const { default: FlyerMasterDashboard } = await import('$lib/components/admin/flyer/FlyerMasterDashboard.svelte');
  component = FlyerMasterDashboard;
  break;
```

**Step 7.2: Add to Component Map**

If using a component map pattern:
```typescript
const componentMap = {
  // ... existing components ...
  'FlyerMasterDashboard': () => import('$lib/components/admin/flyer/FlyerMasterDashboard.svelte')
};
```

---

### Phase 8: i18n Translation Setup (1 hour)

**Step 8.1: Locate Translation Files**

Find translation JSON files (likely in `frontend/src/lib/i18n/` or similar).

**Step 8.2: Add Flyer Master Translations**

**English (en.json):**
```json
{
  "flyer_master": {
    "title": "Flyer Master",
    "tabs": {
      "products": "Product Master",
      "offers": "Offer Selector",
      "pricing": "Price Maker"
    },
    "products": {
      "add_product": "Add Product",
      "product_name_en": "Product Name (English)",
      "product_name_ar": "Product Name (Arabic)",
      "barcode": "Barcode",
      "category": "Category",
      "main_category": "Main Category",
      "sub_category": "Sub Category",
      "final_category": "Final Category",
      "image": "Image",
      "upload_image": "Upload Image",
      "search_image": "Search Image",
      "remove_background": "Remove Background",
      "import_excel": "Import from Excel",
      "export_excel": "Export to Excel",
      "delete_confirm": "Are you sure you want to delete this product?"
    },
    "offers": {
      "create_offer": "Create Offer",
      "template_name": "Template Name",
      "start_date": "Start Date",
      "end_date": "End Date",
      "discount_text": "Discount Text",
      "description": "Description",
      "is_active": "Active",
      "select_all": "Select All",
      "clear_selection": "Clear Selection",
      "link_products": "Link Products"
    },
    "pricing": {
      "cost": "Cost",
      "sales_price": "Sales Price",
      "offer_price": "Offer Price",
      "profit": "Profit",
      "profit_margin": "Profit Margin",
      "discount": "Discount",
      "offer_qty": "Offer Quantity",
      "limit_qty": "Limit per Customer",
      "free_qty": "Free Quantity",
      "save_pricing": "Save Pricing",
      "bulk_update": "Bulk Update",
      "apply_template": "Apply Template"
    }
  }
}
```

**Arabic (ar.json):**
```json
{
  "flyer_master": {
    "title": "إدارة المنشورات",
    "tabs": {
      "products": "إدارة المنتجات",
      "offers": "محدد العروض",
      "pricing": "صانع الأسعار"
    },
    "products": {
      "add_product": "إضافة منتج",
      "product_name_en": "اسم المنتج (إنجليزي)",
      "product_name_ar": "اسم المنتج (عربي)",
      "barcode": "الباركود",
      "category": "الفئة",
      "main_category": "الفئة الرئيسية",
      "sub_category": "الفئة الفرعية",
      "final_category": "الفئة النهائية",
      "image": "الصورة",
      "upload_image": "رفع صورة",
      "search_image": "بحث عن صورة",
      "remove_background": "إزالة الخلفية",
      "import_excel": "استيراد من Excel",
      "export_excel": "تصدير إلى Excel",
      "delete_confirm": "هل أنت متأكد من حذف هذا المنتج؟"
    },
    "offers": {
      "create_offer": "إنشاء عرض",
      "template_name": "اسم القالب",
      "start_date": "تاريخ البداية",
      "end_date": "تاريخ النهاية",
      "discount_text": "نص الخصم",
      "description": "الوصف",
      "is_active": "نشط",
      "select_all": "تحديد الكل",
      "clear_selection": "مسح التحديد",
      "link_products": "ربط المنتجات"
    },
    "pricing": {
      "cost": "التكلفة",
      "sales_price": "سعر البيع",
      "offer_price": "سعر العرض",
      "profit": "الربح",
      "profit_margin": "هامش الربح",
      "discount": "الخصم",
      "offer_qty": "كمية العرض",
      "limit_qty": "الحد للعميل",
      "free_qty": "الكمية المجانية",
      "save_pricing": "حفظ التسعير",
      "bulk_update": "تحديث جماعي",
      "apply_template": "تطبيق القالب"
    }
  }
}
```

**Step 8.3: Use Translations in Components**

```svelte
<script lang="ts">
  import { t } from '$lib/i18n';
  
  // Use translations
  $: title = $t('flyer_master.title');
  $: addButtonText = $t('flyer_master.products.add_product');
</script>

<button>{addButtonText}</button>
```

---

### Phase 9: API Routes (Optional - 1 hour)

If server-side operations are needed:

**Create API Route: `frontend/src/routes/api/flyer/products/+server.ts`**

```typescript
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/supabaseClient';

export const GET: RequestHandler = async ({ url }) => {
  const category = url.searchParams.get('category');
  
  let query = supabase.from('flyer_products').select('*');
  
  if (category && category !== 'all') {
    query = query.eq('main_category', category);
  }
  
  const { data, error } = await query;
  
  if (error) {
    return json({ error: error.message }, { status: 500 });
  }
  
  return json({ products: data });
};

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json();
  
  const { data, error } = await supabase
    .from('flyer_products')
    .insert([body])
    .select()
    .single();
  
  if (error) {
    return json({ error: error.message }, { status: 500 });
  }
  
  return json({ product: data });
};
```

Similar routes for `/api/flyer/offers` and `/api/flyer/pricing`.

---

### Phase 10: Styling Integration (1 hour)

**Ensure components match Aqura's design system:**

1. **Check Aqura's TailwindCSS config** (`frontend/tailwind.config.js`)
2. **Verify color palette** matches existing components
3. **Update gradients** to use Aqura's brand colors
4. **Adjust spacing** to match window padding

**Global Styles for Flyer Master:**

Create `frontend/src/lib/components/admin/flyer/flyer-styles.css`:
```css
.flyer-master-dashboard {
  @apply bg-gray-50 h-full overflow-hidden;
}

.tabs-header {
  @apply flex space-x-2 bg-white border-b border-gray-200 p-4;
}

.tabs-header button {
  @apply px-6 py-3 rounded-lg font-semibold transition-all;
  @apply hover:bg-gray-100;
}

.tabs-header button.active {
  @apply bg-gradient-to-r from-blue-600 to-purple-600 text-white;
}

.tab-content {
  @apply flex-1 overflow-auto p-6;
}

.flyer-card {
  @apply bg-white rounded-xl shadow-lg border border-gray-200 p-6;
}

.flyer-button-primary {
  @apply px-6 py-3 bg-gradient-to-r from-blue-600 to-purple-600 text-white font-semibold rounded-lg;
  @apply hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200;
}

.flyer-button-secondary {
  @apply px-6 py-3 bg-gray-200 text-gray-700 font-semibold rounded-lg;
  @apply hover:bg-gray-300 transition-all duration-200;
}

.flyer-input {
  @apply px-4 py-2 border border-gray-300 rounded-lg;
  @apply focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none;
}
```

Import in components:
```svelte
<style>
  @import './flyer-styles.css';
</style>
```

---

### Phase 11: Testing & Verification (2-3 hours)

#### Test Checklist:

**ProductMaster.svelte:**
- [ ] Load all products from database
- [ ] Add new product (EN & AR names)
- [ ] Edit existing product
- [ ] Delete product with confirmation
- [ ] Upload product image
- [ ] Search image via Google API
- [ ] Remove background from image
- [ ] Generate barcode
- [ ] Import products from Excel
- [ ] Export products to Excel
- [ ] Search/filter products
- [ ] Category filtering
- [ ] Responsive layout

**OfferSelector.svelte:**
- [ ] Load all offers
- [ ] Create new offer template
- [ ] Set date range (with validation)
- [ ] Toggle offer active status
- [ ] Select/deselect offers
- [ ] Link products to offers
- [ ] View active vs inactive offers
- [ ] Delete offer (with cascade check)

**PriceMaker.svelte:**
- [ ] Load product pricing for offer
- [ ] Calculate profit automatically
- [ ] Calculate profit after offer
- [ ] Calculate discount percent
- [ ] Set offer quantity
- [ ] Set limit per customer
- [ ] Set free quantity
- [ ] Save pricing to database
- [ ] Apply pricing templates
- [ ] Bulk update multiple products
- [ ] Validate cost < sales price

**Integration Tests:**
- [ ] Window opens from sidebar menu
- [ ] Window is draggable/resizable
- [ ] Tabs switch correctly
- [ ] Data persists between tabs
- [ ] i18n translations work (EN/AR)
- [ ] Images display correctly
- [ ] Excel import/export works
- [ ] API calls succeed
- [ ] Error handling works
- [ ] Loading states display
- [ ] Toasts show success/error messages

**Database Tests:**
- [ ] RLS policies allow operations
- [ ] Storage bucket accessible
- [ ] Foreign key constraints work
- [ ] CASCADE deletes work correctly
- [ ] Unique constraints enforced
- [ ] Date validations work
- [ ] Quantity validations work

---

### Phase 12: Documentation (1 hour)

**Create User Guide: `FLYER_MASTER_USER_GUIDE.md`**

```markdown
# Flyer Master User Guide

## Accessing Flyer Master

1. Open Aqura application
2. Navigate to **Sidebar → Marketing Master → Flyer Master**
3. Window opens with 3 tabs: Product Master, Offer Selector, Price Maker

## Product Master

### Adding Products
1. Enter product name (English & Arabic)
2. Select category hierarchy
3. Click "Add Product" - barcode generated automatically
4. Upload image or search via Google

### Importing Products
1. Click "Import from Excel"
2. Use template: Barcode, Name (EN), Name (AR), Main Category, Sub Category, Final Category
3. Upload Excel file
4. Products imported to database

### Image Management
1. Click "Search Image" on product
2. Select from Google search results
3. Click "Remove Background" (limited to 50/month)
4. Processed image uploaded to storage

## Offer Selector

### Creating Offers
1. Click "Create Offer"
2. Enter template name & description
3. Set date range
4. Choose discount text & icon
5. Save template

### Linking Products
1. Select products from Product Master
2. Click "Link to Offer"
3. Choose offer template
4. Products added to offer

## Price Maker

### Setting Pricing
1. Select product & offer
2. Enter cost price
3. Enter sales price (profit calculated automatically)
4. Enter offer price
5. System calculates:
   - Profit amount & percentage
   - Profit after offer
   - Discount amount & percentage
6. Set quantities (offer qty, limit, free)
7. Click "Save Pricing"

### Bulk Pricing
1. Select multiple products
2. Choose pricing template
3. Apply to all selected
```

---

## Feature Preservation Checklist

### ✅ Must Work Exactly As Current App

**Product Management:**
- ✅ Bilingual support (EN/AR)
- ✅ 3-level category hierarchy
- ✅ Barcode generation (EAN-13)
- ✅ Image upload to Supabase Storage
- ✅ Google image search integration
- ✅ Remove.bg background removal (50/month limit)
- ✅ Excel import (bulk products)
- ✅ Excel export (full catalog)
- ✅ Product search & filtering

**Offer Management:**
- ✅ Template-based offer system
- ✅ Date range validation
- ✅ Active/inactive toggle
- ✅ Multi-product linking
- ✅ Offer selection interface

**Pricing System:**
- ✅ Cost/sales/offer price fields
- ✅ Automatic profit calculations
- ✅ Profit after offer calculations
- ✅ Discount percentage calculations
- ✅ Quantity controls (offer/limit/free)
- ✅ Pricing templates
- ✅ Bulk pricing updates

**Data Persistence:**
- ✅ All data stored in Supabase
- ✅ Images in Storage bucket
- ✅ RLS policies enabled
- ✅ Foreign key relationships
- ✅ CASCADE deletes

---

## Database & API Integration

### Tables Created (Already Exists)

**flyer_products:**
```sql
- id (UUID, PK)
- barcode (TEXT, UNIQUE)
- product_name_en (TEXT)
- product_name_ar (TEXT)
- main_category (TEXT)
- sub_category (TEXT, nullable)
- final_category (TEXT, nullable)
- image_url (TEXT, nullable)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
```

**flyer_offers:**
```sql
- id (UUID, PK)
- template_id (TEXT, UNIQUE)
- template_name (TEXT)
- description (TEXT, nullable)
- start_date (DATE)
- end_date (DATE)
- is_active (BOOLEAN)
- discount_text (TEXT, nullable)
- icon_emoji (TEXT, nullable)
- color_gradient (TEXT, nullable)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
```

**flyer_offer_products:**
```sql
- id (UUID, PK)
- offer_id (UUID, FK → flyer_offers)
- product_barcode (TEXT, FK → flyer_products.barcode)
- cost (NUMERIC)
- sales_price (NUMERIC)
- offer_price (NUMERIC)
- profit_amount (NUMERIC)
- profit_percent (NUMERIC)
- profit_after_offer (NUMERIC)
- decrease_amount (NUMERIC)
- offer_qty (INTEGER)
- limit_qty (INTEGER)
- free_qty (INTEGER)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
- UNIQUE(offer_id, product_barcode)
```

### Storage Bucket (Already Exists)

**flyer-product-images:**
- Public access
- 20MB file size limit
- Allowed: PNG, JPEG, JPG, WEBP

### RLS Policies (Already Created)

**flyer_products:**
- Public SELECT
- Authenticated INSERT/UPDATE/DELETE

**flyer_offers:**
- Public SELECT (only is_active = true)
- Authenticated CRUD (all records)

**flyer_offer_products:**
- Public SELECT
- Authenticated INSERT/UPDATE/DELETE

---

## Timeline & Effort Estimates

### Total Estimated Time: 15-20 hours

**Phase 1:** Dependencies Installation - **15 minutes**  
**Phase 2:** Component Migration - **2-3 hours**  
**Phase 3:** Supabase Integration - **30 minutes**  
**Phase 4:** ProductMaster Implementation - **3-4 hours**  
  - Database CRUD: 1 hour
  - Excel Import/Export: 1 hour
  - Image Upload: 30 minutes
  - Google Image Search: 45 minutes
  - Background Removal: 30 minutes
  - Barcode Generation: 30 minutes
  
**Phase 5:** OfferSelector Implementation - **2-3 hours**  
  - Database CRUD: 1 hour
  - Template System: 1 hour
  - Product Linking: 1 hour
  
**Phase 6:** PriceMaker Implementation - **2-3 hours**  
  - Pricing Calculations: 1 hour
  - Database Integration: 1 hour
  - Bulk Operations: 1 hour
  
**Phase 7:** Window Registration - **30 minutes**  
**Phase 8:** i18n Translations - **1 hour**  
**Phase 9:** API Routes (Optional) - **1 hour**  
**Phase 10:** Styling Integration - **1 hour**  
**Phase 11:** Testing & Verification - **2-3 hours**  
**Phase 12:** Documentation - **1 hour**

### Recommended Implementation Order

**Day 1 (4-5 hours):**
1. Install dependencies
2. Migrate components
3. Create dashboard wrapper
4. Register window in +layout
5. Add sidebar menu item
6. Test window opens

**Day 2 (5-6 hours):**
1. Implement ProductMaster database operations
2. Add Excel import/export
3. Add image upload
4. Test product CRUD

**Day 3 (4-5 hours):**
1. Implement OfferSelector database operations
2. Add offer template system
3. Implement PriceMaker calculations
4. Test offer & pricing features

**Day 4 (2-3 hours):**
1. Add Google image search
2. Add background removal
3. Add i18n translations
4. Comprehensive testing
5. Write documentation

---

## Critical Implementation Notes

### ⚠️ API Limits

**Remove.bg API:**
- **50 uses per month** on provided key
- Show confirmation before using
- Display remaining uses counter
- Provide alternative: manual image editing

**Google Custom Search:**
- **100 searches/day free tier**
- Consider caching results
- Show quota warnings

### 🔒 Security Considerations

1. **RLS Policies:** Already configured, verify they work
2. **Storage Policies:** Public read, authenticated write
3. **API Keys:** All in .env file, never expose in client code
4. **File Upload Validation:** Check file size/type before upload

### 🎨 UI/UX Considerations

1. **Loading States:** Show spinners during API calls
2. **Error Handling:** Display user-friendly error messages
3. **Confirmation Dialogs:** For delete/destructive actions
4. **Toast Notifications:** Success/error feedback
5. **Responsive Design:** Ensure components work in smaller windows
6. **RTL Support:** Arabic text direction handled correctly

### 📊 Performance Optimization

1. **Lazy Loading:** Load products on scroll for large catalogs
2. **Image Optimization:** Compress before upload
3. **Caching:** Cache Google search results
4. **Pagination:** Limit initial load to 50 products
5. **Debounce Search:** Wait 300ms before filtering

---

## Success Criteria

**Integration is complete when:**

✅ Flyer Master opens from sidebar menu  
✅ All 3 tabs (Products, Offers, Pricing) functional  
✅ Products can be added/edited/deleted  
✅ Images can be uploaded and searched  
✅ Background removal works (with limit warning)  
✅ Excel import/export works  
✅ Offers can be created with templates  
✅ Products can be linked to offers  
✅ Pricing calculations accurate  
✅ All data persists in database  
✅ Bilingual (EN/AR) support works  
✅ Window behaves like other Aqura windows  
✅ No console errors  
✅ All tests pass  
✅ User guide written  

---

## Support & Troubleshooting

### Common Issues

**Issue: Window doesn't open**
- Check componentName matches import in +layout.svelte
- Verify FlyerMasterDashboard.svelte exists
- Check browser console for errors

**Issue: Database operations fail**
- Verify Supabase credentials in .env
- Check RLS policies enabled
- Verify table names match exactly

**Issue: Images don't upload**
- Check storage bucket name: `flyer-product-images`
- Verify storage policies allow INSERT
- Check file size < 20MB

**Issue: Excel import fails**
- Verify exceljs installed: `pnpm list exceljs`
- Check Excel file has correct columns
- Validate data types match database schema

**Issue: Background removal fails**
- Check API key valid: `REMOVE_BG_API_KEY`
- Verify monthly limit not exceeded (50 uses)
- Check internet connection

**Issue: Translations missing**
- Verify i18n files updated (en.json, ar.json)
- Check $t() function imported
- Restart dev server after i18n changes

---

## Next Steps After Integration

**Future Enhancements:**

1. **Flyer Generation:** Auto-generate PDF flyers from offers
2. **Analytics:** Track offer performance metrics
3. **Integration with Orders:** Link to customer orders system
4. **Inventory Sync:** Connect with inventory management
5. **Price History:** Track pricing changes over time
6. **Template Library:** Pre-built offer templates
7. **Email Marketing:** Send flyers via email campaigns
8. **Mobile App:** View flyers on customer mobile app
9. **Print Layout:** Design print-ready flyer layouts
10. **Multi-language:** Add more language support

---

## Conclusion

This plan ensures **Flyer Master works exactly as it currently does** while being fully integrated into Aqura's windowed MDI system. All features preserved, all data persisted, all APIs integrated.

**Ready to implement?** Start with Phase 1 (Dependencies) and work through sequentially. Each phase is independent and can be completed before moving to the next.

**Questions or blockers?** Refer to the Troubleshooting section or review the component implementation details above.

---

**Document Version:** 1.0  
**Last Updated:** November 23, 2025  
**Status:** Ready for Implementation ✅
