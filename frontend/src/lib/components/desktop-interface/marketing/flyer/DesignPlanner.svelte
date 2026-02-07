<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { windowManager } from '$lib/stores/windowManager';
  import ShelfPaperTemplateDesigner from '$lib/components/desktop-interface/marketing/flyer/ShelfPaperTemplateDesigner.svelte';

  interface Offer {
    id: string;
    name: string;
    start_date: string;
    end_date: string;
    is_active: boolean;
  }

  interface Product {
    barcode: string;
    product_name_en: string;
    product_name_ar: string;
    unit_name: string;
    sales_price: number;
    offer_price: number;
    offer_qty: number;
    limit_qty: number | null;
    image_url?: string;
    pdfSizes: ('a4' | 'a5' | 'a6' | 'a7')[];
    offer_end_date: string;
    copiesA4: number;
    copiesA5: number;
    copiesA6: number;
    copiesA7: number;
    page_number?: number;
    page_order?: number;
    // Variation group fields
    is_variation_group?: boolean;
    variation_count?: number;
    variation_barcodes?: string[];
    parent_product_barcode?: string;
    variation_group_name_en?: string;
    variation_group_name_ar?: string;
  }

  interface FieldSelector {
    id: string;
    label: string;
    x: number;
    y: number;
    width: number;
    height: number;
    fontSize: number;
    alignment: 'left' | 'center' | 'right';
    color: string;
    fontFamily?: string;
  }

  interface CustomFont {
    id: string;
    name: string;
    font_url: string;
  }

  let customFonts: CustomFont[] = [];

  interface SavedTemplate {
    id: string;
    name: string;
    description: string | null;
    template_image_url: string;
    field_configuration: FieldSelector[];
    metadata: { preview_width: number; preview_height: number } | null;
    created_at: string;
  }

  let offers: Offer[] = [];
  let selectedOfferId: string | null = null;
  let selectedOffer: Offer | null = null;
  let products: Product[] = [];
  let filteredProducts: Product[] = [];
  let isLoadingOffers = true;
  let isLoadingProducts = false;
  let savedTemplates: SavedTemplate[] = [];
  let selectedTemplateId: string | null = null;
  let isLoadingTemplates = false;
  let serialCounter = 1;
  let searchQuery = '';
  let searchBy: 'barcode' | 'name_en' | 'name_ar' | 'serial' = 'barcode';

  function formatDate(dateString: string): string {
    if (!dateString) return '';
    const date = new Date(dateString);
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const year = date.getFullYear();
    return `${day}-${month}-${year}`;
  }

  onMount(async () => {
    await loadActiveOffers();
    await loadTemplates();
    await loadCustomFonts();
  });

  async function loadCustomFonts() {
    try {
      const { data, error } = await supabase
        .from('shelf_paper_fonts')
        .select('id, name, font_url')
        .order('name', { ascending: true });
      if (error) throw error;
      customFonts = data || [];
    } catch (e) {
      console.error('Error loading custom fonts:', e);
    }
  }

  function buildFontFaceCss(): string {
    return customFonts.map(f => "@font-face{font-family:'" + f.name + "';src:url('" + f.font_url + "');font-display:swap;}").join('');
  }

  async function loadTemplates() {
    try {
      isLoadingTemplates = true;
      const { data, error } = await supabase
        .from('shelf_paper_templates')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false });
      
      if (error) throw error;
      savedTemplates = data || [];
    } catch (error) {
      console.error('Error loading templates:', error);
    } finally {
      isLoadingTemplates = false;
    }
  }

  async function loadActiveOffers() {
    try {
      isLoadingOffers = true;
      const { data, error } = await supabase
        .from('flyer_offers')
        .select('*, offer_names(name_en, name_ar)')
        .eq('is_active', true)
        .order('created_at', { ascending: false });

      if (error) throw error;
      offers = (data || []).map(offer => ({
        id: offer.id,
        name: offer.offer_names?.name_en || offer.offer_names?.name_ar || offer.offer_name || offer.template_name || 'Unnamed Offer',
        start_date: offer.start_date,
        end_date: offer.end_date,
        is_active: true
      }));
    } catch (error) {
      console.error('Error loading offers:', error);
      alert('Failed to load offers');
    } finally {
      isLoadingOffers = false;
    }
  }

  async function loadOfferProducts(offerId: string) {
    try {
      isLoadingProducts = true;
      selectedOfferId = offerId;
      selectedOffer = offers.find(o => o.id === offerId) || null;
      
      // Get offer products
      const { data: offerProducts, error: offerError } = await supabase
        .from('flyer_offer_products')
        .select('*')
        .eq('offer_id', offerId);

      if (offerError) throw offerError;

      if (!offerProducts || offerProducts.length === 0) {
        products = [];
        return;
      }

      // Get barcodes
      const barcodes = offerProducts.map(p => p.product_barcode);

      // Load product units for mapping
      const { data: unitsData } = await supabase
        .from('product_units')
        .select('id, name_en, name_ar');
      
      const unitMap = new Map();
      if (unitsData) {
        unitsData.forEach(unit => {
          unitMap.set(unit.id, unit.name_en);
        });
      }

      // Get product details from products (including variation fields)
      const { data: productDetails, error: productError } = await supabase
        .from('products')
        .select('barcode, product_name_en, product_name_ar, unit_id, image_url, is_variation, parent_product_barcode, variation_group_name_en, variation_group_name_ar, variation_image_override')
        .in('barcode', barcodes);

      if (productError) throw productError;

      // Combine offer data with product details
      const allProducts = offerProducts.map(offerProduct => {
        const productDetail = productDetails?.find(p => p.barcode === offerProduct.product_barcode);
        return {
          barcode: offerProduct.product_barcode,
          product_name_en: productDetail?.product_name_en || '',
          product_name_ar: productDetail?.product_name_ar || '',
          unit_name: unitMap.get(productDetail?.unit_id) || '',
          sales_price: offerProduct.sales_price || 0,
          offer_price: offerProduct.offer_price || 0,
          offer_qty: offerProduct.offer_qty || 1,
          limit_qty: offerProduct.limit_qty,
          total_sales_price: offerProduct.total_sales_price || ((offerProduct.sales_price || 0) * (offerProduct.offer_qty || 1)),
          total_offer_price: offerProduct.total_offer_price || ((offerProduct.offer_price || 0) * (offerProduct.offer_qty || 1)),
          image_url: productDetail?.image_url || productDetail?.variation_image_override,
          pdfSizes: [],
          offer_end_date: selectedOffer?.end_date || '',
          copiesA4: 1,
          copiesA5: 1,
          copiesA6: 1,
          copiesA7: 1,
          page_number: offerProduct.page_number,
          page_order: offerProduct.page_order,
          is_variation: productDetail?.is_variation,
          parent_product_barcode: productDetail?.parent_product_barcode,
          variation_group_name_en: productDetail?.variation_group_name_en,
          variation_group_name_ar: productDetail?.variation_group_name_ar
        };
      });

      // Group products by variation groups
      const variationGroups = new Map<string, typeof allProducts>();
      const standaloneProducts: typeof allProducts = [];

      allProducts.forEach(product => {
        if (product.is_variation && product.parent_product_barcode) {
          const groupKey = product.parent_product_barcode;
          if (!variationGroups.has(groupKey)) {
            variationGroups.set(groupKey, []);
          }
          variationGroups.get(groupKey)?.push(product);
        } else {
          standaloneProducts.push(product);
        }
      });

      // Consolidate variation groups into single entries
      const consolidatedProducts: Product[] = [];

      // Add standalone products
      consolidatedProducts.push(...standaloneProducts);

      // Add consolidated variation groups
      for (const [parentBarcode, groupProducts] of variationGroups.entries()) {
        if (groupProducts.length > 0) {
          const firstProduct = groupProducts[0];
          
          // ONLY use variations that are actually selected in the offer
          const offerVariationBarcodes = groupProducts.map(p => p.barcode);
          
          console.log(`🔍 Using only selected variations for parent ${parentBarcode}:`, offerVariationBarcodes.length, 'selected in offer');
          
          // Use group name if available, fallback to first product name
          const groupNameEn = firstProduct.variation_group_name_en || firstProduct.product_name_en;
          const groupNameAr = firstProduct.variation_group_name_ar || firstProduct.product_name_ar;
          
          // Find parent product or use first variation's data
          const parentProduct = groupProducts.find(p => p.barcode === parentBarcode) || firstProduct;
          
          consolidatedProducts.push({
            ...parentProduct,
            barcode: parentBarcode,
            product_name_en: groupNameEn,
            product_name_ar: groupNameAr,
            is_variation_group: true,
            variation_count: offerVariationBarcodes.length,
            variation_barcodes: offerVariationBarcodes,
            // Use parent's image or first variation's image
            image_url: parentProduct.image_url || firstProduct.image_url
          });
        }
      }

      products = consolidatedProducts.sort((a, b) => {
        // Sort by page_number first, then by page_order
        const pageCompare = (a.page_number || 1) - (b.page_number || 1);
        if (pageCompare !== 0) return pageCompare;
        return (a.page_order || 1) - (b.page_order || 1);
      });

      // Initialize filtered products
      filteredProducts = products;
      searchQuery = '';
    } catch (error) {
      console.error('Error loading products:', error);
      alert('Failed to load products');
    } finally {
      isLoadingProducts = false;
    }
  }

  function filterProducts() {
    if (!searchQuery.trim()) {
      filteredProducts = [...products].sort((a, b) => {
        // Sort by page_number first, then by page_order
        const pageCompare = (a.page_number || 1) - (b.page_number || 1);
        if (pageCompare !== 0) return pageCompare;
        return (a.page_order || 1) - (b.page_order || 1);
      });
      return;
    }

    const query = searchQuery.toLowerCase().trim();
    
    let filtered = products.filter(product => {
      switch(searchBy) {
        case 'barcode':
          return product.barcode.toLowerCase().includes(query);
        case 'name_en':
          return product.product_name_en.toLowerCase().includes(query);
        case 'name_ar':
          return product.product_name_ar.includes(query);
        case 'serial':
          // Serial number search - find the product's sorted index
          const sortedProducts = [...products].sort((a, b) => {
            const pageCompare = (a.page_number || 1) - (b.page_number || 1);
            if (pageCompare !== 0) return pageCompare;
            return (a.page_order || 1) - (b.page_order || 1);
          });
          const serialNum = (sortedProducts.indexOf(product) + 1).toString();
          return serialNum.includes(query);
        default:
          return true;
      }
    });

    // Sort filtered results by page_number and page_order
    filteredProducts = filtered.sort((a, b) => {
      const pageCompare = (a.page_number || 1) - (b.page_number || 1);
      if (pageCompare !== 0) return pageCompare;
      return (a.page_order || 1) - (b.page_order || 1);
    });
  }

  // Reactive statement to filter products when search changes
  $: {
    searchQuery;
    searchBy;
    filterProducts();
  }

  function togglePdfSize(barcode: string, size: 'a4' | 'a5' | 'a6' | 'a7', checked: boolean) {
    products = products.map(p => {
      if (p.barcode === barcode) {
        const sizes = checked 
          ? [...p.pdfSizes, size]
          : p.pdfSizes.filter(s => s !== size);
        return { ...p, pdfSizes: sizes };
      }
      return p;
    });
    filterProducts(); // Re-filter after update
  }

  function printShelfPaper() {
    if (filteredProducts.length === 0) {
      alert('No products to print');
      return;
    }

    const offerName = selectedOffer?.name || 'Shelf Paper';
    const printWindow = window.open('', '', 'height=600,width=800');
    
    if (!printWindow) {
      alert('Failed to open print window. Please check your popup settings.');
      return;
    }

    let printHTML = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Shelf Paper - ${offerName}</title>
        <style>
          @media print {
            @page { margin: 0.5cm; }
            body { margin: 0; }
          }
          body {
            font-family: Arial, sans-serif;
            padding: 20px;
          }
          h1 {
            font-size: 24px;
            margin-bottom: 10px;
            color: #333;
          }
          .info {
            margin-bottom: 20px;
            color: #666;
            font-size: 14px;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
            font-size: 11px;
          }
          th, td {
            border: 1px solid #ddd;
            padding: 6px;
            text-align: left;
          }
          th {
            background-color: #f3f4f6;
            font-weight: bold;
            color: #374151;
            font-size: 11px;
          }
          .img-cell {
            width: 70px;
            text-align: center;
          }
          img {
            max-width: 60px;
            max-height: 60px;
            object-fit: contain;
          }
          .no-image {
            color: #9ca3af;
            font-size: 10px;
          }
          .copies-col {
            width: 50px;
            text-align: center;
            background-color: #f9fafb;
          }
          .blank-col {
            width: 60px;
            background-color: #fef3c7;
          }
        </style>
      </head>
      <body>
        <h1>Shelf Paper - ${offerName}</h1>
        <div class="info">
          <div>Date: ${new Date().toLocaleDateString()}</div>
          <div>Total Products: ${filteredProducts.length}</div>
        </div>
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th class="img-cell">Image</th>
              <th>Product Name (EN)</th>
              <th>Unit</th>
              <th class="copies-col">A4</th>
              <th class="copies-col">A5</th>
              <th class="copies-col">A6</th>
              <th class="copies-col">A7</th>
            </tr>
          </thead>
          <tbody>
    `;

    // Add product rows
    filteredProducts.forEach((product, index) => {
      const imageTag = product.image_url 
        ? `<img src="${product.image_url}" alt="${product.product_name_en || ''}" />`
        : '<span class="no-image">No Image</span>';
      
      const a4Copies = product.pdfSizes.includes('a4') ? product.copiesA4 : '';
      const a5Copies = product.pdfSizes.includes('a5') ? product.copiesA5 : '';
      const a6Copies = product.pdfSizes.includes('a6') ? product.copiesA6 : '';
      const a7Copies = product.pdfSizes.includes('a7') ? product.copiesA7 : '';

      printHTML += `
        <tr>
          <td style="font-weight: bold; text-align: center;">${index + 1}</td>
          <td class="img-cell">${imageTag}</td>
          <td>
            <div style="font-weight: bold;">${product.product_name_en || '-'}</div>
            <div style="font-size: 12px; color: #6b7280; margin-top: 4px; font-weight: 600;">${product.barcode || '-'}</div>
          </td>
          <td>${product.unit_name || '-'}</td>
          <td class="copies-col">${a4Copies}</td>
          <td class="copies-col">${a5Copies}</td>
          <td class="copies-col">${a6Copies}</td>
          <td class="copies-col">${a7Copies}</td>
        </tr>
      `;
    });

    printHTML += `
          </tbody>
        </table>
      </body>
      </html>
    `;

    printWindow.document.write(printHTML);
    printWindow.document.close();
    
    // Wait for images to load before printing
    setTimeout(() => {
      printWindow.print();
    }, 500);
  }

  async function generatePDF(product: Product) {
    console.log('🔵 generatePDF called for product:', product.barcode);
    
    if (product.pdfSizes.length === 0) {
      alert('Please select at least one PDF size');
      return;
    }

    // If it's a variation group, fetch all variation images
    let variationImages: string[] = [];
    if (product.is_variation_group && product.variation_barcodes && product.variation_barcodes.length > 0) {
      console.log('🔍 Fetching variation images for barcodes:', product.variation_barcodes);
      
      try {
        const { data: variationProducts, error } = await supabase
          .from('products')
          .select('image_url, variation_order')
          .in('barcode', product.variation_barcodes)
          .order('variation_order', { ascending: true });
        
        console.log('📦 Variation products fetched:', variationProducts?.length || 0);
        
        if (!error && variationProducts) {
          variationImages = variationProducts
            .filter(p => p.image_url)
            .map(p => p.image_url);
          console.log('🖼️ Variation images extracted:', variationImages.length, 'images');
        } else if (error) {
          console.error('❌ Error fetching variation images:', error);
        }
      } catch (error) {
        console.error('💥 Exception fetching variation images:', error);
      }
    } else {
      console.log('ℹ️ Not a variation group, using single product image');
    }

    const printWindow = window.open('', '_blank', 'width=800,height=600');
    if (!printWindow) {
      alert('Please allow popups to generate PDF');
      return;
    }

    const layouts = {
      a4: { cols: 1, rows: 1, count: 1 },
      a5: { cols: 1, rows: 2, count: 2 },
      a6: { cols: 2, rows: 2, count: 4 },
      a7: { cols: 2, rows: 4, count: 8 }
    };

    const fonts = {
      a4: { n: 24, na: 22, rp: 18, op: 32, q: 20, l: 14, b: 14 },
      a5: { n: 18, na: 16, rp: 14, op: 24, q: 16, l: 12, b: 12 },
      a6: { n: 14, na: 12, rp: 12, op: 18, q: 12, l: 10, b: 10 },
      a7: { n: 12, na: 10, rp: 10, op: 14, q: 10, l: 8, b: 8 }
    };

    const layout = layouts[product.pdfSize];
    const font = fonts[product.pdfSize];

    const doc = printWindow.document;
    doc.open();
    doc.write('<!DOCTYPE html><html><head><title>Print</title></head><body><div id="root"></div></body></html>');
    doc.close();

    let allPagesHtml = '';

    // Generate a page for each selected size
    product.pdfSizes.forEach((pdfSize, pageIndex) => {
      const layout = layouts[pdfSize];
      const font = fonts[pdfSize];

      // Format end date for display
      const endDate = new Date(product.offer_end_date);
      const expireDateEn = 'Expires: ' + endDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
      const expireDateAr = 'ينتهي في: ' + endDate.toLocaleDateString('ar-SA', { month: 'long', day: 'numeric', year: 'numeric' });

      // Variation group indicator text
      const isVariationGroup = product.is_variation_group && product.variation_count;
      const variationTextEn = isVariationGroup ? 'Multiple varieties available' : '';
      const variationTextAr = isVariationGroup ? 'أصناف متعددة متوفرة' : '';

      let cardsHtml = '';
      const copiesMap = { a4: product.copiesA4, a5: product.copiesA5, a6: product.copiesA6, a7: product.copiesA7 };
      const totalCopies = layout.count * (copiesMap[pdfSize] || 1);
      for (let i = 0; i < totalCopies; i++) {
        // Create layered images for variation groups
        let imgHtml = '';
        if (isVariationGroup && variationImages.length > 0) {
          console.log('🎨 Generating layered images for variation group');
          console.log('   - isVariationGroup:', isVariationGroup);
          console.log('   - variationImages.length:', variationImages.length);
          console.log('   - variationImages:', variationImages);
          
          // Create grid layout container
          imgHtml = '<div class="img-grid" style="position:relative;width:100%;height:100%;">';
          
          // Calculate optimal grid layout based on variant count
          const totalVariants = variationImages.length;
          const cols = Math.ceil(Math.sqrt(totalVariants));
          const rows = Math.ceil(totalVariants / cols);
          const cellWidthPercent = 100 / cols;
          const cellHeightPercent = 100 / rows;
          
          console.log('   - Grid layout:', rows, 'rows x', cols, 'cols for', totalVariants, 'variants');
          console.log('   - Cell size:', cellWidthPercent + '%', 'x', cellHeightPercent + '%');
          
          variationImages.forEach((imgUrl, imgIndex) => {
            const row = Math.floor(imgIndex / cols);
            const col = imgIndex % cols;
            const left = col * cellWidthPercent;
            const top = row * cellHeightPercent;
            
            console.log('   - Image', imgIndex + 1, 'at grid[' + row + '][' + col + ']: left=' + left.toFixed(1) + '% top=' + top.toFixed(1) + '%');
            
            imgHtml += '<img src="' + imgUrl + '" style="position:absolute;left:' + left + '%;top:' + top + '%;width:' + cellWidthPercent + '%;height:' + cellHeightPercent + '%;object-fit:contain;padding:2%;" alt="Variant ' + (imgIndex + 1) + '">';
          });
          
          imgHtml += '</div>';
          console.log('✅ Generated imgHtml:', imgHtml.substring(0, 200));
        } else if (product.image_url) {
          imgHtml = '<img src="' + product.image_url + '" class="pi" alt="' + product.product_name_en + '">';
        } else {
          imgHtml = '<div style="width:100%;height:40%;background:#f0f0f0;display:flex;align-items:center;justify-content:center;font-size:48px">📦</div>';
        }
        
        const qtyHtml = product.offer_qty > 1 ? '<div class="oq">Buy ' + product.offer_qty + '</div>' : '';
        const limHtml = product.limit_qty ? '<div class="lq">Limit: ' + product.limit_qty + '</div>' : '';
        const varHtml = isVariationGroup ? '<div class="vg-en sz-' + pdfSize + '">' + variationTextEn + '</div><div class="vg-ar sz-' + pdfSize + '">' + variationTextAr + '</div>' : '';
        
        cardsHtml += '<div class="pc sz-' + pdfSize + '">' + imgHtml + '<div class="pne sz-' + pdfSize + '">' + product.product_name_en + '</div><div class="pna sz-' + pdfSize + '">' + product.product_name_ar + '</div>' + varHtml + '<div class="ps"><div class="rp sz-' + pdfSize + '">' + product.total_sales_price.toFixed(2) + ' SAR</div><div class="op sz-' + pdfSize + '">' + product.total_offer_price.toFixed(2) + ' SAR</div>' + qtyHtml + limHtml + '<div class="bc sz-' + pdfSize + '">' + product.barcode + '</div><div class="exp-en sz-' + pdfSize + '">' + expireDateEn + '</div><div class="exp-ar sz-' + pdfSize + '">' + expireDateAr + '</div></div></div>';
      }

      const pageBreak = pageIndex < product.pdfSizes.length - 1 ? ' style="page-break-after:always"' : '';
      allPagesHtml += '<div class="cnt"' + pageBreak + '>' + cardsHtml + '</div>';
    });

    const styleEl = doc.createElement('style');
    let cssText = '@page{size:A4;margin:0}@media print{html,body{width:210mm;margin:0;padding:0}}*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;margin:0;padding:0;overflow:hidden}.cnt{width:210mm;height:297mm;display:grid;gap:0;padding:0;page-break-inside:avoid;overflow:hidden}.pc{border:2px solid #333;border-radius:8px;padding:5px;display:flex;flex-direction:column;align-items:center;justify-content:space-between;background:white;margin:2mm;overflow:hidden;page-break-inside:avoid}.pi{width:90%;max-width:90%;height:35%;max-height:35%;object-fit:contain;margin-bottom:5px}.img-stack{position:relative;width:90%;height:35%;margin-bottom:5px;display:flex;align-items:center;justify-content:center;overflow:hidden}.pi-stacked{position:absolute;width:75%;height:75%;object-fit:contain;border:2px solid #e5e7eb;border-radius:8px;background:white;max-width:75%;max-height:75%}.ps{width:100%;text-align:center;margin-top:auto}';
    
    // Add size-specific styles
    Object.keys(fonts).forEach(size => {
      const f = fonts[size];
      const l = layouts[size];
      cssText += '.cnt:has(.sz-' + size + '){grid-template-columns:repeat(' + l.cols + ',1fr);grid-template-rows:repeat(' + l.rows + ',1fr)}';
      cssText += '.pne.sz-' + size + '{font-size:' + f.n + 'px;font-weight:bold;text-align:center;margin-bottom:3px;line-height:1.2}';
      cssText += '.pna.sz-' + size + '{font-size:' + f.na + 'px;font-weight:bold;text-align:center;direction:rtl;margin-bottom:5px;line-height:1.2}';
      cssText += '.rp.sz-' + size + '{text-decoration:line-through;color:#666;font-size:' + f.rp + 'px;line-height:1.2}';
      cssText += '.op.sz-' + size + '{color:#e53e3e;font-size:' + f.op + 'px;font-weight:bold;margin:3px 0;line-height:1.2}';
      cssText += '.bc.sz-' + size + '{font-size:' + f.b + 'px;color:#666;margin-top:3px}';
      cssText += '.exp-en.sz-' + size + '{font-size:' + f.b + 'px;color:#d97706;margin-top:3px;font-weight:600}';
      cssText += '.exp-ar.sz-' + size + '{font-size:' + f.b + 'px;color:#d97706;margin-top:2px;direction:rtl;font-weight:600}';
      cssText += '.vg-en.sz-' + size + '{font-size:' + (f.b - 1) + 'px;color:#059669;font-style:italic;margin:2px 0;font-weight:500}';
      cssText += '.vg-ar.sz-' + size + '{font-size:' + (f.b - 1) + 'px;color:#059669;font-style:italic;margin:2px 0;direction:rtl;font-weight:500}';
    });
    
    cssText += '.oq{background:#48bb78;color:white;padding:3px 8px;border-radius:5px;font-weight:bold;display:inline-block;margin-top:3px}.lq{background:#ed8936;color:white;padding:2px 6px;border-radius:3px;margin-top:3px}';

    
    styleEl.textContent = cssText;
    doc.head.appendChild(styleEl);

    const rootEl = doc.getElementById('root');
    if (rootEl) {
      rootEl.innerHTML = allPagesHtml;
    }

    setTimeout(() => {
      printWindow.print();
    }, 500);
  }

  async function generatePDFWithTemplate(product: Product) {
    console.log('🔵 generatePDFWithTemplate called for product:', product.barcode);
    
    if (!selectedTemplateId) {
      alert('Please select a template first');
      return;
    }

    const template = savedTemplates.find(t => t.id === selectedTemplateId);
    if (!template) {
      alert('Template not found');
      return;
    }

    // If it's a variation group, fetch all variation images
    let variationImages: string[] = [];
    if (product.is_variation_group && product.variation_barcodes && product.variation_barcodes.length > 0) {
      console.log('🔍 Fetching variation images for barcodes:', product.variation_barcodes);
      
      try {
        const { data: variationProducts, error } = await supabase
          .from('products')
          .select('image_url, variation_order')
          .in('barcode', product.variation_barcodes)
          .order('variation_order', { ascending: true });
        
        console.log('📦 Variation products fetched:', variationProducts?.length || 0);
        
        if (!error && variationProducts) {
          variationImages = variationProducts
            .filter(p => p.image_url)
            .map(p => p.image_url);
          console.log('🖼️ Variation images extracted:', variationImages.length, 'images');
        } else if (error) {
          console.error('❌ Error fetching variation images:', error);
        }
      } catch (error) {
        console.error('💥 Exception fetching variation images:', error);
      }
    } else {
      console.log('ℹ️ Not a variation group, using single product image');
    }

    const printWindow = window.open('', '_blank', 'width=800,height=600');
    if (!printWindow) {
      alert('Please allow popups to generate PDF');
      return;
    }

    const doc = printWindow.document;
    doc.open();
    doc.write('<!DOCTYPE html><html><head><title>Print - ' + product.product_name_en + '</title></head><body><div id="root"></div></body></html>');
    doc.close();

    // Load template image to get its actual dimensions
    const tempImg = new Image();
    tempImg.onload = function() {
      const originalWidth = tempImg.width;
      const originalHeight = tempImg.height;
      
      console.log('Original image dimensions:', originalWidth, 'x', originalHeight);
      
      // A4 dimensions in pixels at 96 DPI
      const a4Width = 794;
      const a4Height = 1123;
      
      // Use stored preview dimensions if available, otherwise use original image dimensions
      const previewWidth = template.metadata?.preview_width || originalWidth;
      const previewHeight = template.metadata?.preview_height || originalHeight;
      
      // Calculate scale from preview to A4
      const scaleX = a4Width / previewWidth;
      const scaleY = a4Height / previewHeight;

      // Create the page with template background
      let pageHtml = '<div class="template-page">';
      pageHtml += '<img src="' + template.template_image_url + '" class="template-bg" alt="Template">';
      
      // Add fields based on template configuration with scaling
      template.field_configuration.forEach((field, index) => {
        
        let value = '';
        const endDate = new Date(product.offer_end_date);
        
        switch(field.label) {
          case 'product_name_en':
            value = product.product_name_en;
            break;
          case 'product_name_ar':
            value = product.product_name_ar;
            break;
          case 'barcode':
            value = product.barcode;
            break;
          case 'serial_number':
            value = serialCounter.toString();
            break;
          case 'unit_name':
            value = product.unit_name;
            break;
          case 'price':
            value = product.total_sales_price.toFixed(2);
            break;
          case 'offer_price':
            value = product.total_offer_price.toFixed(2);
            break;
          case 'offer_qty':
            value = product.offer_qty ? product.offer_qty.toString() : '1';
            break;
          case 'limit_qty':
            value = product.limit_qty ? 'لكل عميل: ' + product.limit_qty + '<br>For each customer: ' + product.limit_qty : '';
            break;
          case 'expire_date':
            const dateEnglish = endDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
            const dateArabic = endDate.toLocaleDateString('ar-SA', { month: 'short', day: 'numeric', year: 'numeric' });
            value = 'ينتهي: ' + dateArabic + '<br>Expires: ' + dateEnglish;
            break;
          case 'image':
            const scaledX = Math.round(field.x * scaleX);
            const scaledY = Math.round(field.y * scaleY);
            const scaledWidth = Math.round(field.width * scaleX);
            const scaledHeight = Math.round(field.height * scaleY);
            
            // Check if this is a variation group with multiple images
            if (variationImages.length > 0) {
              console.log(`🎨 Rendering ${variationImages.length} layered images`);
              // Create layered images container (transparent, no background)
              pageHtml += '<div style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;">';
              
              if (variationImages.length === 1) {
                // Single image
                pageHtml += '<img src="' + variationImages[0] + '" style="position:absolute;left:0;top:0;width:100%;height:100%;object-fit:contain;z-index:1;" alt="Product">';
              } else {
                // Grid layout for all variant counts
                const totalVariants = variationImages.length;
                const cols = Math.ceil(Math.sqrt(totalVariants));
                const rows = Math.ceil(totalVariants / cols);
                const cellWidth = scaledWidth / cols;
                const cellHeight = scaledHeight / rows;
                
                for (let i = 0; i < variationImages.length; i++) {
                  const imgUrl = variationImages[i];
                  const row = Math.floor(i / cols);
                  const col = i % cols;
                  const left = col * cellWidth;
                  const top = row * cellHeight;
                  const padding = Math.min(cellWidth, cellHeight) * 0.05; // 5% padding
                  
                  pageHtml += '<img src="' + imgUrl + '" style="position:absolute;left:' + left + 'px;top:' + top + 'px;width:' + cellWidth + 'px;height:' + cellHeight + 'px;object-fit:contain;padding:' + padding + 'px;" alt="Variant ' + (i + 1) + '">';
                }
              }
              
              pageHtml += '</div>';
            } else if (product.image_url) {
              // Single product image (transparent background)
              pageHtml += '<div style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;"><img src="' + product.image_url + '" style="width:100%;height:100%;object-fit:contain;"></div>';
            }
            return;
        }
        
        if (value) {
          const scaledX = Math.round(field.x * scaleX);
          const scaledY = Math.round(field.y * scaleY);
          const scaledWidth = Math.round(field.width * scaleX);
          const scaledHeight = Math.round(field.height * scaleY);
          const scaledFontSize = Math.round(field.fontSize * scaleX);
          
          const justifyContent = field.alignment === 'center' ? 'center' : field.alignment === 'right' ? 'flex-end' : 'flex-start';
          const dirAttr = field.label === 'product_name_ar' ? 'direction:rtl;' : '';
          const fontWeight = field.label.includes('price') || field.label.includes('offer') ? 'font-weight:bold;' : 'font-weight:600;';
          const fontFamilyStyle = field.fontFamily ? "font-family:'" + field.fontFamily + "',sans-serif;" : '';
          
          // Add strikethrough for regular price
          const strikethrough = field.label === 'price' ? 'text-decoration:line-through;' : '';
          
          // Format offer_price with smaller decimal using flexbox baseline alignment
          let contentHtml = '';
          if (field.label === 'offer_price' && value.includes('.')) {
            const parts = value.split('.');
            const halfFontSize = Math.round(scaledFontSize * 0.5);
            // Use flexbox with baseline alignment for proper vertical alignment
            contentHtml = '<div style="display:flex;align-items:baseline;"><img src="/icons/saudi-currency.png" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR"><span style="font-size:' + scaledFontSize + 'px;">' + parts[0] + '</span><span style="font-size:' + halfFontSize + 'px;">.' + parts[1] + '</span></div>';
          } else {
            // Add currency symbol for regular price field
            const currencySymbol = field.label === 'price' 
              ? '<img src="/icons/saudi-currency.png" style="width:auto;height:' + Math.round(scaledFontSize * 0.5) + 'px;margin-right:4px;" alt="SAR">' 
              : '';
            contentHtml = currencySymbol + value;
          }
          
          pageHtml += '<div class="field-container" style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;"><div class="field-text" style="width:100%;height:100%;font-size:' + scaledFontSize + 'px;text-align:' + field.alignment + ';color:' + field.color + ';display:flex;align-items:center;justify-content:' + justifyContent + ';' + fontWeight + strikethrough + dirAttr + fontFamilyStyle + '">' + contentHtml + '</div></div>';
        }
      });
      
      pageHtml += '</div>';

      const styleEl = doc.createElement('style');
      let cssText = buildFontFaceCss() + '@page{size:A4 portrait;margin:0}@media print{html,body{width:210mm;height:297mm;margin:0;padding:0}}*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;margin:0;padding:0;width:' + a4Width + 'px;height:' + a4Height + 'px}.template-page{position:relative;width:' + a4Width + 'px;height:' + a4Height + 'px;overflow:hidden;page-break-inside:avoid;background:white;display:block}.template-bg{width:' + a4Width + 'px;height:' + a4Height + 'px;object-fit:fill;display:block;position:absolute;top:0;left:0;z-index:1}.field-container{box-sizing:border-box;z-index:10;position:absolute;background:transparent}.field-text{white-space:normal;overflow:hidden;line-height:1.2}img{background:transparent;border:none}';
      
      styleEl.textContent = cssText;
      doc.head.appendChild(styleEl);
      doc.getElementById('root').innerHTML = pageHtml;
      
      setTimeout(() => {
        printWindow.print();
        // Increment serial counter after successful generation
        serialCounter++;
      }, 1000);
    };
    
    tempImg.src = template.template_image_url;
  }

  function generateMasterPDF() {
    if (!selectedTemplateId) {
      alert('Please select a template first');
      return;
    }

    if (products.length === 0) {
      alert('No products to generate');
      return;
    }

    // Filter products that have at least one size selected
    const productsToGenerate = products.filter(p => p.pdfSizes && p.pdfSizes.length > 0);
    
    if (productsToGenerate.length === 0) {
      alert('No products with selected sizes found. Please select at least one size for products.');
      return;
    }

    // Collect all unique sizes selected across all products
    const allSizes = new Set();
    productsToGenerate.forEach(product => {
      product.pdfSizes.forEach(size => allSizes.add(size));
    });
    
    const sizesArray = Array.from(allSizes).sort();
    
    // Show dialog with buttons for each size
    const sizeButtons = sizesArray.map(size => size.toUpperCase()).join(', ');
    alert('Sizes to generate: ' + sizeButtons + '\n\nUse the size buttons (A4, A5, A6, A7) below to generate each size separately.');
  }

  function openTemplateDesigner() {
    const windowId = `shelf-template-designer-${Date.now()}`;
    windowManager.openWindow({
      id: windowId,
      title: 'Shelf Paper Template Designer',
      component: ShelfPaperTemplateDesigner,
      icon: '🎨',
      size: { width: 1400, height: 900 },
      position: { 
        x: 60 + (Math.random() * 50),
        y: 60 + (Math.random() * 50) 
      },
      resizable: true,
      minimizable: true,
      maximizable: true
    });
  }

  async function generateSizePDF(targetSize: string) {
    console.log('🔵 generateSizePDF called for size:', targetSize.toUpperCase());
    
    if (!selectedTemplateId) {
      alert('Please select a template first');
      return;
    }

    const template = savedTemplates.find(t => t.id === selectedTemplateId);
    if (!template) {
      alert('Template not found');
      return;
    }

    // Filter products that have this specific size selected
    const productsForThisSize = products.filter(p => p.pdfSizes && p.pdfSizes.includes(targetSize));
    
    if (productsForThisSize.length === 0) {
      alert('No products have ' + targetSize.toUpperCase() + ' size selected.');
      return;
    }
    
    console.log(`📋 Found ${productsForThisSize.length} products for ${targetSize.toUpperCase()}`);
    
    // Check for variation groups
    const variationGroups = productsForThisSize.filter(p => p.is_variation_group);
    if (variationGroups.length > 0) {
      console.log(`🔗 ${variationGroups.length} variation groups detected`);
    }

    // Build filename with offer name, dates, and size
    let filename = 'Shelf_Paper_' + targetSize.toUpperCase();
    
    // Try to get offer info from selectedOffer or from the first product
    const offerInfo = selectedOffer || (productsForThisSize.length > 0 && productsForThisSize[0].offer_end_date ? {
      name: 'Offer',
      start_date: null,
      end_date: productsForThisSize[0].offer_end_date
    } : null);
    
    if (offerInfo) {
      try {
        const offerName = offerInfo.name ? offerInfo.name.replace(/[^a-zA-Z0-9\u0600-\u06FF]/g, '_') : 'Offer';
        const startDate = offerInfo.start_date ? new Date(offerInfo.start_date).toISOString().split('T')[0] : 'Start';
        const endDate = offerInfo.end_date ? new Date(offerInfo.end_date).toISOString().split('T')[0] : 'End';
        filename = offerName + '_' + startDate + '_to_' + endDate + '_' + targetSize.toUpperCase();
      } catch (e) {
        console.error('Error building filename:', e, offerInfo);
      }
    } else {
      console.log('No offer info available. selectedOffer:', selectedOffer, 'products:', productsForThisSize.length);
    }

    const printWindow = window.open('', '_blank', 'width=800,height=600');
    if (!printWindow) {
      alert('Please allow popups to generate PDF');
      return;
    }

    const doc = printWindow.document;
    doc.open();
    doc.write('<!DOCTYPE html><html><head><title>' + filename + '</title></head><body><div id="root"></div></body></html>');
    doc.close();

    const tempImg = new Image();
    tempImg.onload = async function() {
      const originalWidth = tempImg.width;
      const originalHeight = tempImg.height;
      
      const a4Width = 794;
      const a4Height = 1123;
      
      const previewWidth = template.metadata?.preview_width || originalWidth;
      const previewHeight = template.metadata?.preview_height || originalHeight;
      
      const scaleX = a4Width / previewWidth;
      const scaleY = a4Height / previewHeight;

      let allPagesHtml = '';
      
      const copiesPerPage = targetSize === 'a4' ? 1 : targetSize === 'a5' ? 2 : targetSize === 'a6' ? 4 : 8;

      // Process products sequentially to handle async image fetching
      for (const product of productsForThisSize) {
        const endDate = new Date(product.offer_end_date);
        
        // Fetch variation images if this is a variation group
        let variationImages: string[] = [];
        if (product.is_variation_group && product.variation_barcodes && product.variation_barcodes.length > 0) {
          console.log(`🔍 Fetching images for variation group: ${product.product_name_en}`);
          console.log(`📦 Variation barcodes array:`, product.variation_barcodes);
          console.log(`📊 Expected ${product.variation_count} variations`);
          
          try {
            const { data: variationProducts, error } = await supabase
              .from('products')
              .select('image_url, variation_order, barcode')
              .in('barcode', product.variation_barcodes)
              .order('variation_order', { ascending: true });
            
            if (!error && variationProducts) {
              console.log(`📥 Database returned ${variationProducts.length} products:`, variationProducts);
              
              variationImages = variationProducts
                .filter(p => p.image_url)
                .map(p => p.image_url);
              console.log(`🖼️ Found ${variationImages.length} images for variation group`);
              
              if (variationImages.length < product.variation_count) {
                console.warn(`⚠️ Expected ${product.variation_count} images but only found ${variationImages.length}`);
              }
            } else if (error) {
              console.error(`❌ Database error:`, error);
            }
          } catch (error) {
            console.error('💥 Error fetching variation images:', error);
          }
        }
        
        let productFieldsHtml = '';
        
        template.field_configuration.forEach((field) => {
          let value = '';
          
          switch(field.label) {
            case 'product_name_en':
              value = product.product_name_en;
              break;
            case 'product_name_ar':
              value = product.product_name_ar;
              break;
            case 'barcode':
              value = product.barcode;
              break;
            case 'serial_number':
              value = serialCounter.toString();
              break;
            case 'unit_name':
              value = product.unit_name;
              break;
            case 'price':
              value = product.total_sales_price.toFixed(2);
              break;
            case 'offer_price':
              value = product.total_offer_price.toFixed(2);
              break;
            case 'offer_qty':
              value = product.offer_qty ? product.offer_qty.toString() : '1';
              break;
            case 'limit_qty':
              value = product.limit_qty ? 'لكل عميل: ' + product.limit_qty + '<br>For each customer: ' + product.limit_qty : '';
              break;
            case 'expire_date':
              const dateEnglish = endDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
              const dateArabic = endDate.toLocaleDateString('ar-SA', { month: 'short', day: 'numeric', year: 'numeric' });
              value = 'ينتهي: ' + dateArabic + '<br>Expires: ' + dateEnglish;
              break;
            case 'image':
              const scaledX = Math.round(field.x * scaleX);
              const scaledY = Math.round(field.y * scaleY);
              const scaledWidth = Math.round(field.width * scaleX);
              const scaledHeight = Math.round(field.height * scaleY);
              
              // Check if this is a variation group with multiple images
              if (variationImages.length > 0) {
                console.log(`🎨 Rendering ${variationImages.length} layered images`);
                // Create layered images container (transparent, no background)
                productFieldsHtml += '<div style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;">';
                
                // Show ALL variation images with layered effect
                const maxVisibleImages = variationImages.length;
                const imagesToShow = variationImages;
                
                if (maxVisibleImages === 1) {
                  // Single image - full size
                  productFieldsHtml += '<img src="' + imagesToShow[0] + '" style="position:absolute;left:0;top:0;width:100%;height:100%;object-fit:contain;z-index:1;" alt="Product">';
                  
                } else {
                  // Grid layout for all variant counts
                  const totalVariants = maxVisibleImages;
                  const cols = Math.ceil(Math.sqrt(totalVariants));
                  const rows = Math.ceil(totalVariants / cols);
                  const cellWidth = scaledWidth / cols;
                  const cellHeight = scaledHeight / rows;
                  
                  for (let i = 0; i < maxVisibleImages; i++) {
                    const imgUrl = imagesToShow[i];
                    const row = Math.floor(i / cols);
                    const col = i % cols;
                    const left = col * cellWidth;
                    const top = row * cellHeight;
                    const padding = Math.min(cellWidth, cellHeight) * 0.05; // 5% padding
                    
                    productFieldsHtml += '<img src="' + imgUrl + '" style="position:absolute;left:' + left + 'px;top:' + top + 'px;width:' + cellWidth + 'px;height:' + cellHeight + 'px;object-fit:contain;padding:' + padding + 'px;" alt="Variant ' + (i + 1) + '">';
                  }
                }
                
                productFieldsHtml += '</div>';
              } else if (product.image_url) {
                // Single product image (transparent background)
                productFieldsHtml += '<div style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;"><img src="' + product.image_url + '" style="width:100%;height:100%;object-fit:contain;"></div>';
              }
              return;
          }
          
          if (value) {
            const scaledX = Math.round(field.x * scaleX);
            const scaledY = Math.round(field.y * scaleY);
            const scaledWidth = Math.round(field.width * scaleX);
            const scaledHeight = Math.round(field.height * scaleY);
            const scaledFontSize = Math.round(field.fontSize * scaleX);
            
            const justifyContent = field.alignment === 'center' ? 'center' : field.alignment === 'right' ? 'flex-end' : 'flex-start';
            const dirAttr = field.label === 'product_name_ar' ? 'direction:rtl;' : '';
            const fontWeight = field.label.includes('price') || field.label.includes('offer') ? 'font-weight:bold;' : 'font-weight:600;';
            const strikethrough = field.label === 'price' ? 'text-decoration:line-through;' : '';
            const fontFamilyStyle = field.fontFamily ? "font-family:'" + field.fontFamily + "',sans-serif;" : '';
            
            let contentHtml = '';
            if (field.label === 'offer_price' && value.includes('.')) {
              const parts = value.split('.');
              const halfFontSize = Math.round(scaledFontSize * 0.5);
              contentHtml = '<div style="display:flex;align-items:baseline;"><img src="/icons/saudi-currency.png" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR"><span style="font-size:' + scaledFontSize + 'px;">' + parts[0] + '</span><span style="font-size:' + halfFontSize + 'px;">.' + parts[1] + '</span></div>';
            } else {
              const currencySymbol = field.label === 'price' 
                ? '<img src="/icons/saudi-currency.png" style="width:auto;height:' + Math.round(scaledFontSize * 0.5) + 'px;margin-right:4px;" alt="SAR">' 
                : '';
              contentHtml = currencySymbol + value;
            }
            
            productFieldsHtml += '<div class="field-container" style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;"><div class="field-text" style="width:100%;height:100%;font-size:' + scaledFontSize + 'px;text-align:' + field.alignment + ';color:' + field.color + ';display:flex;align-items:center;justify-content:' + justifyContent + ';' + fontWeight + strikethrough + dirAttr + fontFamilyStyle + '">' + contentHtml + '</div></div>';
          }
        });
        
        // Generate copies based on size-specific copies value
        const copiesMap = { a4: product.copiesA4, a5: product.copiesA5, a6: product.copiesA6, a7: product.copiesA7 };
        const copiesToGenerate = copiesMap[targetSize] || 1;
        
        for (let copyIndex = 0; copyIndex < copiesToGenerate; copyIndex++) {
          // Create a separate page for each copy
          let pageHtml = '<div class="template-page" style="width:794px;height:1123px;">';
          pageHtml += '<div class="copy-container" style="position:relative;width:794px;height:1123px;">';
          pageHtml += '<img src="' + template.template_image_url + '" class="template-bg" style="width:794px;height:1123px;" alt="Template">';
          pageHtml += productFieldsHtml;
          pageHtml += '</div>';
          pageHtml += '</div>';
          allPagesHtml += pageHtml;
        }
        
        serialCounter++;
      } // End of for loop (was forEach)

      const styleEl = doc.createElement('style');
      let cssText = buildFontFaceCss() + '@page{size:A4 portrait;margin:0}@media print{html,body{width:210mm;height:297mm;margin:0;padding:0}}*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;margin:0;padding:0}.template-page{position:relative;width:794px;height:1123px;overflow:hidden;page-break-after:always;background:white;display:block;margin:0 auto}.template-page:last-child{page-break-after:auto}.copy-container{position:relative}.template-bg{object-fit:fill;display:block;position:absolute;top:0;left:0;z-index:1}.field-container{box-sizing:border-box;z-index:10;position:absolute;background:transparent}.field-text{white-space:normal;overflow:hidden;line-height:1.2}img{background:transparent;border:none}';
      
      styleEl.textContent = cssText;
      doc.head.appendChild(styleEl);
      doc.getElementById('root').innerHTML = allPagesHtml;
      
      setTimeout(() => {
        printWindow.print();
      }, 1000);
    };
    
    tempImg.src = template.template_image_url;
  }
</script>

<div class="shelf-paper-generator">
  <div class="header">
    <div>
      <h2 class="text-2xl font-bold text-gray-800">Shelf Paper Manager</h2>
      <p class="text-sm text-gray-600 mt-1">Select an active offer to view and plan shelf paper layouts</p>
    </div>
    <button class="template-designer-btn" on:click={openTemplateDesigner} title="Open Template Designer">
      🎨 Template Designer
    </button>
  </div>

  <div class="content">
    <!-- Offers List -->
    <div class="offers-section">
      <h3 class="section-title">Active Offer Templates</h3>
      
      {#if isLoadingOffers}
        <div class="loading">Loading offers...</div>
      {:else if offers.length === 0}
        <div class="empty-state">No active offers found</div>
      {:else}
        <div class="offers-list">
          {#each offers as offer}
            <button
              class="offer-card {selectedOfferId === offer.id ? 'selected' : ''}"
              on:click={() => loadOfferProducts(offer.id)}
            >
              <div class="offer-icon">📋</div>
              <div class="offer-info">
                <div class="offer-name">{offer.name}</div>
                <div class="offer-dates">
                  {formatDate(offer.start_date)} - {formatDate(offer.end_date)}
                </div>
              </div>
              {#if selectedOfferId === offer.id}
                <div class="selected-badge">✓</div>
              {/if}
            </button>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Products List -->
    {#if selectedOfferId}
      <div class="products-section">
        <div class="products-header">
          <h3 class="section-title">Products in Selected Offer: {selectedOffer?.name || ''}</h3>
          
          <!-- Template Selector -->
          <div class="template-selector">
            <label for="template-select" class="template-label">📐 Choose Template:</label>
            <select 
              id="template-select"
              bind:value={selectedTemplateId}
              class="template-select"
              disabled={isLoadingTemplates}
            >
              <option value={null}>-- No Template (Default Layout) --</option>
              {#each savedTemplates as template}
                <option value={template.id}>{template.name}</option>
              {/each}
            </select>
            {#if selectedTemplateId}
              <span class="template-badge">✓ Template Selected</span>
              <div class="size-buttons-group" style="display:inline-flex;gap:8px;margin-left:12px;">
                <button class="size-btn" on:click={() => generateSizePDF('a4')} title="Generate A4 PDFs for all selected products">
                  A4
                </button>
                <button class="size-btn" on:click={() => generateSizePDF('a5')} title="Generate A5 PDFs for all selected products">
                  A5
                </button>
                <button class="size-btn" on:click={() => generateSizePDF('a6')} title="Generate A6 PDFs for all selected products">
                  A6
                </button>
                <button class="size-btn" on:click={() => generateSizePDF('a7')} title="Generate A7 PDFs for all selected products">
                  A7
                </button>
              </div>
            {/if}
          </div>
        </div>
        
        <!-- Search Bar -->
        <div class="search-section">
          <div class="search-controls">
            <input 
              type="text" 
              bind:value={searchQuery}
              placeholder="Search products..."
              class="search-input"
            />
            <div class="search-radio-group">
              <label class="radio-label">
                <input type="radio" bind:group={searchBy} value="barcode" />
                Barcode
              </label>
              <label class="radio-label">
                <input type="radio" bind:group={searchBy} value="name_en" />
                English Name
              </label>
              <label class="radio-label">
                <input type="radio" bind:group={searchBy} value="name_ar" />
                Arabic Name
              </label>
              <label class="radio-label">
                <input type="radio" bind:group={searchBy} value="serial" />
                Serial Number
              </label>
            </div>
            <span class="search-results-count">
              {filteredProducts.length} of {products.length} products
            </span>
          </div>
        </div>
        
        {#if isLoadingProducts}
          <div class="loading">Loading products...</div>
        {:else if products.length === 0}
          <div class="empty-state">No products found in this offer</div>
        {:else}
          <div style="margin-bottom: 1rem;">
            <button class="print-btn" on:click={printShelfPaper} title="Print shelf paper details for supervisor">
              🖨️ Print for Paper Size
            </button>
          </div>
          <div class="products-table-container">
            <table class="products-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Image</th>
                  <th>Page/Order</th>
                  <th>Barcode</th>
                  <th>Product Name (EN)</th>
                  <th>Product Name (AR)</th>
                  <th>Unit</th>
                  <th>Regular Price</th>
                  <th>Offer Price</th>
                  <th>Qty</th>
                  <th>Limit</th>
                  <th>Savings</th>
                  <th>PDF Size & Copies</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {#each filteredProducts as product, index}
                  <tr>
                    <td class="serial-cell">{index + 1}</td>
                    <td class="image-cell">
                      <div class="product-image-small">
                        {#if product.image_url}
                          <img src={product.image_url} alt={product.product_name_en} />
                        {:else}
                          <div class="no-image-small">📦</div>
                        {/if}
                      </div>
                    </td>
                    <td class="page-order-cell">
                      {product.page_number || 1}/{product.page_order || 1}
                    </td>
                    <td class="barcode-cell">{product.barcode}</td>
                    <td class="name-cell">
                      <div class="product-name-wrapper">
                        <span>{product.product_name_en}</span>
                        {#if product.is_variation_group}
                          <span class="variation-group-badge" title="{product.variation_count} variations in group">
                            🔗 Group ({product.variation_count})
                          </span>
                        {/if}
                      </div>
                    </td>
                    <td class="name-ar-cell" dir="rtl">
                      <div class="product-name-wrapper">
                        <span>{product.product_name_ar}</span>
                        {#if product.is_variation_group}
                          <span class="variation-group-badge-ar" title="{product.variation_count} منتجات في المجموعة">
                            مجموعة ({product.variation_count})
                          </span>
                        {/if}
                      </div>
                    </td>
                    <td class="unit-cell">{product.unit_name}</td>
                    <td class="price-cell">
                      <span class="regular-price">{product.total_sales_price.toFixed(2)} SAR</span>
                    </td>
                    <td class="price-cell">
                      <span class="offer-price">{product.total_offer_price.toFixed(2)} SAR</span>
                    </td>
                    <td class="qty-cell">
                      {#if product.offer_qty > 1}
                        <span class="qty-badge">{product.offer_qty}</span>
                      {:else}
                        1
                      {/if}
                    </td>
                    <td class="limit-cell">
                      {#if product.limit_qty}
                        <span class="limit-badge">{product.limit_qty}</span>
                      {:else}
                        <span class="no-limit">No Limit</span>
                      {/if}
                    </td>
                    <td class="savings-cell">
                      <span class="savings-amount">
                        {(product.total_sales_price - product.total_offer_price).toFixed(2)} SAR
                      </span>
                    </td>
                    <td class="pdf-size-cell">
                      <div class="pdf-size-options">
                        <div class="size-row">
                          <label class="pdf-checkbox">
                            <input 
                              type="checkbox" 
                              value="a4"
                              checked={product.pdfSizes.includes('a4')}
                              on:change={(e) => togglePdfSize(product.barcode, 'a4', e.currentTarget.checked)}
                            />
                            <span>A4 (1)</span>
                          </label>
                          <input 
                            type="number" 
                            min="1" 
                            max="10" 
                            bind:value={product.copiesA4}
                            class="copies-input-inline"
                            on:change={() => filterProducts()}
                            title="Copies for A4"
                          />
                        </div>
                        <div class="size-row">
                          <label class="pdf-checkbox">
                            <input 
                              type="checkbox" 
                              value="a5"
                              checked={product.pdfSizes.includes('a5')}
                              on:change={(e) => togglePdfSize(product.barcode, 'a5', e.currentTarget.checked)}
                            />
                            <span>A5 (2)</span>
                          </label>
                          <input 
                            type="number" 
                            min="1" 
                            max="10" 
                            bind:value={product.copiesA5}
                            class="copies-input-inline"
                            on:change={() => filterProducts()}
                            title="Copies for A5"
                          />
                        </div>
                        <div class="size-row">
                          <label class="pdf-checkbox">
                            <input 
                              type="checkbox" 
                              value="a6"
                              checked={product.pdfSizes.includes('a6')}
                              on:change={(e) => togglePdfSize(product.barcode, 'a6', e.currentTarget.checked)}
                            />
                            <span>A6 (4)</span>
                          </label>
                          <input 
                            type="number" 
                            min="1" 
                            max="10" 
                            bind:value={product.copiesA6}
                            class="copies-input-inline"
                            on:change={() => filterProducts()}
                            title="Copies for A6"
                          />
                        </div>
                        <div class="size-row">
                          <label class="pdf-checkbox">
                            <input 
                              type="checkbox" 
                              value="a7"
                              checked={product.pdfSizes.includes('a7')}
                              on:change={(e) => togglePdfSize(product.barcode, 'a7', e.currentTarget.checked)}
                            />
                            <span>A7 (8)</span>
                          </label>
                          <input 
                            type="number" 
                            min="1" 
                            max="10" 
                            bind:value={product.copiesA7}
                            class="copies-input-inline"
                            on:change={() => filterProducts()}
                            title="Copies for A7"
                          />
                        </div>
                      </div>
                    </td>
                    <td class="action-cell">
                      {#if selectedTemplateId}
                        <button class="template-btn" on:click={() => generatePDFWithTemplate(product)} title="Generate using selected template">
                          Use Template
                        </button>
                      {/if}
                      <button class="generate-btn" on:click={() => generatePDF(product)}>
                        Generate
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .shelf-paper-generator {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: #f9fafb;
  }

  .header {
    padding: 1.5rem;
    background: white;
    border-bottom: 2px solid #e5e7eb;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
  }

  .template-designer-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
    color: white;
    padding: 0.625rem 1.25rem;
    border: none;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(139, 92, 246, 0.2);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .template-designer-btn:hover {
    background: linear-gradient(135deg, #7c3aed 0%, #6d28d9 100%);
    box-shadow: 0 4px 8px rgba(139, 92, 246, 0.3);
    transform: translateY(-1px);
  }

  .template-designer-btn:active {
    transform: translateY(0);
  }

  .content {
    flex: 1;
    display: grid;
    grid-template-columns: 350px 1fr;
    gap: 1.5rem;
    padding: 1.5rem;
    overflow: hidden;
  }

  .offers-section,
  .products-section {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    overflow-y: auto;
  }

  .section-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 1rem;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid #e5e7eb;
  }

  .offers-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .offer-card {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem;
    background: #f9fafb;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s;
    text-align: left;
    width: 100%;
  }

  .offer-card:hover {
    background: #f3f4f6;
    border-color: #14b8a6;
    transform: translateX(4px);
  }

  .offer-card.selected {
    background: #f0fdfa;
    border-color: #14b8a6;
    box-shadow: 0 0 0 3px rgba(20, 184, 166, 0.1);
  }

  .offer-icon {
    font-size: 2rem;
    flex-shrink: 0;
  }

  .offer-info {
    flex: 1;
  }

  .offer-name {
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 0.25rem;
  }

  .offer-dates {
    font-size: 0.75rem;
    color: #6b7280;
  }

  .selected-badge {
    width: 28px;
    height: 28px;
    background: #14b8a6;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    flex-shrink: 0;
  }

  .products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1rem;
  }

  .products-table-container {
    overflow-x: auto;
  }

  .products-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.875rem;
  }

  .products-table thead {
    background: #f9fafb;
    position: sticky;
    top: 0;
    z-index: 10;
  }

  .products-table th {
    padding: 0.75rem 1rem;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 2px solid #e5e7eb;
    white-space: nowrap;
  }

  .products-table tbody tr {
    border-bottom: 1px solid #e5e7eb;
    transition: background-color 0.2s;
  }

  .products-table tbody tr:hover {
    background-color: #f9fafb;
  }

  .products-table td {
    padding: 0.75rem 1rem;
    vertical-align: middle;
  }

  .image-cell {
    width: 80px;
  }

  .product-image-small {
    width: 60px;
    height: 60px;
    background: white;
    border-radius: 6px;
    border: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  .product-image-small img {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }

  .no-image-small {
    font-size: 1.5rem;
    opacity: 0.3;
  }

  .barcode-cell {
    font-family: monospace;
    font-weight: 600;
    color: #6b7280;
  }

  .name-cell {
    font-weight: 500;
    color: #1f2937;
  }

  .product-name-wrapper {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .variation-group-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    background: #10b981;
    color: white;
    padding: 0.125rem 0.5rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
    white-space: nowrap;
  }

  .variation-group-badge-ar {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    background: #10b981;
    color: white;
    padding: 0.125rem 0.5rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
    white-space: nowrap;
    direction: rtl;
  }

  .name-ar-cell {
    color: #6b7280;
  }

  .price-cell {
    font-weight: 600;
  }

  .regular-price {
    color: #6b7280;
    text-decoration: line-through;
  }

  .offer-price {
    color: #14b8a6;
    font-size: 1rem;
  }

  .qty-cell {
    text-align: center;
  }

  .qty-badge {
    display: inline-block;
    background: #14b8a6;
    color: white;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .savings-cell {
    font-weight: 700;
  }

  .savings-amount {
    color: #059669;
  }

  .product-card {
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 1rem;
    transition: all 0.2s;
  }

  .product-card:hover {
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    transform: translateY(-2px);
  }

  .product-image {
    width: 100%;
    height: 150px;
    background: white;
    border-radius: 6px;
    margin-bottom: 0.75rem;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  .product-image img {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }

  .no-image {
    font-size: 3rem;
    opacity: 0.3;
  }

  .product-barcode {
    font-family: monospace;
    font-size: 0.875rem;
    font-weight: 600;
    color: #6b7280;
    margin-bottom: 0.5rem;
  }

  .product-name {
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 0.25rem;
    font-size: 0.875rem;
  }

  .product-name-ar {
    color: #6b7280;
    margin-bottom: 0.75rem;
    font-size: 0.875rem;
    direction: rtl;
  }

  .product-prices {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .price-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.875rem;
  }

  .price-label {
    color: #6b7280;
  }

  .regular-price {
    color: #6b7280;
    text-decoration: line-through;
  }

  .offer-price {
    color: #14b8a6;
    font-weight: 700;
    font-size: 1rem;
  }

  .qty-badge {
    display: inline-block;
    background: #14b8a6;
    color: white;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .loading,
  .empty-state {
    padding: 3rem;
    text-align: center;
    color: #6b7280;
  }

  .pdf-size-cell {
    padding: 0.5rem;
  }

  .pdf-size-options {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .size-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .pdf-checkbox {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
    font-size: 0.875rem;
    color: #374151;
    min-width: 80px;
  }

  .pdf-checkbox input[type="checkbox"] {
    cursor: pointer;
    width: 16px;
    height: 16px;
  }

  .pdf-checkbox span {
    user-select: none;
  }

  .copies-input-inline {
    width: 70px;
    padding: 0.5rem;
    border: 2px solid #e5e7eb;
    border-radius: 4px;
    font-size: 1rem;
    font-weight: 600;
    text-align: center;
    transition: all 0.2s;
  }

  .copies-input-inline:focus {
    outline: none;
    border-color: #14b8a6;
    box-shadow: 0 0 0 2px rgba(20, 184, 166, 0.1);
  }

  .copies-input-inline::-webkit-inner-spin-button,
  .copies-input-inline::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  .copies-input-inline[type="number"] {
    -moz-appearance: textfield;
  }

  .copies-input-inline::-webkit-inner-spin-button,
  .copies-input-inline::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  .copies-cell {
    padding: 0.5rem;
    text-align: center;
  }

  .copies-input {
    width: 60px;
    padding: 0.375rem;
    border: 2px solid #e5e7eb;
    border-radius: 4px;
    font-size: 0.875rem;
    text-align: center;
    transition: all 0.2s;
  }

  .copies-input:focus {
    outline: none;
    border-color: #14b8a6;
    box-shadow: 0 0 0 3px rgba(20, 184, 166, 0.1);
  }

  .copies-input::-webkit-inner-spin-button,
  .copies-input::-webkit-outer-spin-button {
    opacity: 1;
  }

  .action-cell {
    padding: 0.5rem;
  }

  .print-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
    color: white;
    padding: 0.625rem 1.25rem;
    border: none;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(245, 158, 11, 0.2);
  }

  .print-btn:hover {
    background: linear-gradient(135deg, #d97706 0%, #b45309 100%);
    box-shadow: 0 4px 8px rgba(245, 158, 11, 0.3);
    transform: translateY(-1px);
  }

  .print-btn:active {
    transform: translateY(0);
  }

  .template-btn {
    background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
    color: white;
    border: none;
    padding: 0.375rem 0.75rem;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
    display: inline-flex;
    align-items: center;
    margin-right: 0.5rem;
  }

  .template-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(139, 92, 246, 0.4);
  }

  .generate-btn {
    background: linear-gradient(135deg, #14b8a6 0%, #0891b2 100%);
    color: white;
    border: none;
    padding: 0.375rem 0.75rem;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
    display: inline-flex;
    align-items: center;
  }

  .generate-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(20, 184, 166, 0.4);
  }

  .generate-btn:active {
    transform: translateY(0);
  }

  .products-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .search-section {
    margin: 1rem 0;
    padding: 1rem;
    background: #f9fafb;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
  }

  .search-controls {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .search-input {
    padding: 0.75rem 1rem;
    border: 2px solid #e5e7eb;
    border-radius: 6px;
    font-size: 0.875rem;
    background: white;
    transition: all 0.2s;
  }

  .search-input:focus {
    outline: none;
    border-color: #14b8a6;
    box-shadow: 0 0 0 3px rgba(20, 184, 166, 0.1);
  }

  .search-radio-group {
    display: flex;
    gap: 1.5rem;
    flex-wrap: wrap;
  }

  .radio-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
    color: #374151;
    cursor: pointer;
  }

  .radio-label input[type="radio"] {
    cursor: pointer;
    accent-color: #14b8a6;
  }

  .search-results-count {
    font-size: 0.875rem;
    color: #6b7280;
    font-weight: 500;
  }

  .template-selector {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .template-label {
    font-size: 0.875rem;
    font-weight: 600;
    color: #374151;
    white-space: nowrap;
  }

  .template-select {
    padding: 0.5rem 1rem;
    border: 2px solid #e5e7eb;
    border-radius: 6px;
    font-size: 0.875rem;
    background: white;
    cursor: pointer;
    transition: all 0.2s;
    min-width: 250px;
  }

  .template-select:hover {
    border-color: #8b5cf6;
  }

  .template-select:focus {
    outline: none;
    border-color: #8b5cf6;
    box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
  }

  .template-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    background: #8b5cf6;
    color: white;
    padding: 0.375rem 0.75rem;
    border-radius: 6px;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .master-generate-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
    color: white;
    padding: 0.625rem 1.25rem;
    border: none;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(139, 92, 246, 0.2);
  }

  .master-generate-btn:hover {
    background: linear-gradient(135deg, #7c3aed 0%, #6d28d9 100%);
    box-shadow: 0 4px 8px rgba(139, 92, 246, 0.3);
    transform: translateY(-1px);
  }

  .master-generate-btn:active {
    transform: translateY(0);
  }

  .size-btn {
    display: inline-flex;
    align-items: center;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    padding: 0.375rem 0.75rem;
    border: none;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
  }

  .size-btn:hover {
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
    transform: translateY(-1px);
  }

  .size-btn:active {
    transform: translateY(0);
  }

  .serial-cell {
    font-weight: 600;
    color: #6b7280;
  }

  @media (max-width: 1024px) {
    .content {
      grid-template-columns: 1fr;
    }
  }
</style>
