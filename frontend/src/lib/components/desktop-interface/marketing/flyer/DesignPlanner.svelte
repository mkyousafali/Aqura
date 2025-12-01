<script lang="ts">
  import { onMount } from 'svelte';
  import { supabaseAdmin } from '$lib/utils/supabase';
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
  }

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

  onMount(async () => {
    await loadActiveOffers();
    await loadTemplates();
  });

  async function loadTemplates() {
    try {
      isLoadingTemplates = true;
      const { data, error } = await supabaseAdmin
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
      const { data, error } = await supabaseAdmin
        .from('flyer_offers')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false });

      if (error) throw error;
      offers = (data || []).map(offer => ({
        id: offer.id,
        name: offer.name_en || offer.name_ar,
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
      const { data: offerProducts, error: offerError } = await supabaseAdmin
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

      // Get product details from flyer_products (including variation fields)
      const { data: productDetails, error: productError } = await supabaseAdmin
        .from('flyer_products')
        .select('barcode, product_name_en, product_name_ar, unit_name, image_url, is_variation, parent_product_barcode, variation_group_name_en, variation_group_name_ar, variation_image_override')
        .in('barcode', barcodes);

      if (productError) throw productError;

      // Combine offer data with product details
      const allProducts = offerProducts.map(offerProduct => {
        const productDetail = productDetails?.find(p => p.barcode === offerProduct.product_barcode);
        return {
          barcode: offerProduct.product_barcode,
          product_name_en: productDetail?.product_name_en || '',
          product_name_ar: productDetail?.product_name_ar || '',
          unit_name: productDetail?.unit_name || '',
          sales_price: offerProduct.sales_price || 0,
          offer_price: offerProduct.offer_price || 0,
          offer_qty: offerProduct.offer_qty || 1,
          limit_qty: offerProduct.limit_qty,
          image_url: productDetail?.image_url || productDetail?.variation_image_override,
          pdfSizes: [],
          offer_end_date: selectedOffer?.end_date || '',
          copiesA4: 1,
          copiesA5: 1,
          copiesA6: 1,
          copiesA7: 1,
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

      products = consolidatedProducts.sort((a, b) => a.product_name_en.localeCompare(b.product_name_en));

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
      filteredProducts = products;
      return;
    }

    const query = searchQuery.toLowerCase().trim();
    
    filteredProducts = products.filter(product => {
      switch(searchBy) {
        case 'barcode':
          return product.barcode.toLowerCase().includes(query);
        case 'name_en':
          return product.product_name_en.toLowerCase().includes(query);
        case 'name_ar':
          return product.product_name_ar.includes(query);
        case 'serial':
          // Serial number search - find the product's index (serial)
          const serialNum = (products.indexOf(product) + 1).toString();
          return serialNum.includes(query);
        default:
          return true;
      }
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
        const { data: variationProducts, error } = await supabaseAdmin
          .from('flyer_products')
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
          
          // Create layered image container
          imgHtml = '<div class="img-stack">';
          
          // Add up to 3 images in stack (main + 2 behind)
          const imagesToShow = variationImages.slice(0, 3);
          imagesToShow.forEach((imgUrl, imgIndex) => {
            const zIndex = imagesToShow.length - imgIndex;
            const offset = imgIndex * 5; // 5px offset for each layer (reduced from 8px)
            const opacity = imgIndex === 0 ? '1' : '0.6'; // Main image full opacity, others semi-transparent
            console.log('   - Adding image', imgIndex + 1, ':', imgUrl);
            imgHtml += '<img src="' + imgUrl + '" class="pi-stacked" style="z-index:' + zIndex + ';left:' + offset + 'px;top:' + offset + 'px;opacity:' + opacity + '" alt="Variation ' + (imgIndex + 1) + '">';
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
        
        cardsHtml += '<div class="pc sz-' + pdfSize + '">' + imgHtml + '<div class="pne sz-' + pdfSize + '">' + product.product_name_en + '</div><div class="pna sz-' + pdfSize + '">' + product.product_name_ar + '</div>' + varHtml + '<div class="ps"><div class="rp sz-' + pdfSize + '">' + product.sales_price.toFixed(2) + ' SAR</div><div class="op sz-' + pdfSize + '">' + product.offer_price.toFixed(2) + ' SAR</div>' + qtyHtml + limHtml + '<div class="bc sz-' + pdfSize + '">' + product.barcode + '</div><div class="exp-en sz-' + pdfSize + '">' + expireDateEn + '</div><div class="exp-ar sz-' + pdfSize + '">' + expireDateAr + '</div></div></div>';
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
        const { data: variationProducts, error } = await supabaseAdmin
          .from('flyer_products')
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
            value = product.sales_price.toFixed(2);
            break;
          case 'offer_price':
            value = product.offer_price.toFixed(2);
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
            if (product.image_url) {
              const scaledX = Math.round(field.x * scaleX);
              const scaledY = Math.round(field.y * scaleY);
              const scaledWidth = Math.round(field.width * scaleX);
              const scaledHeight = Math.round(field.height * scaleY);
              pageHtml += '<div class="field-container" style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;"><img src="' + product.image_url + '" style="width:100%;height:100%;object-fit:contain;"></div>';
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
          
          pageHtml += '<div class="field-container" style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;"><div class="field-text" style="width:100%;height:100%;font-size:' + scaledFontSize + 'px;text-align:' + field.alignment + ';color:' + field.color + ';display:flex;align-items:center;justify-content:' + justifyContent + ';' + fontWeight + strikethrough + dirAttr + '">' + contentHtml + '</div></div>';
        }
      });
      
      pageHtml += '</div>';

      const styleEl = doc.createElement('style');
      let cssText = '@page{size:A4 portrait;margin:0}@media print{html,body{width:210mm;height:297mm;margin:0;padding:0}}*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;margin:0;padding:0;width:' + a4Width + 'px;height:' + a4Height + 'px}.template-page{position:relative;width:' + a4Width + 'px;height:' + a4Height + 'px;overflow:hidden;page-break-inside:avoid;background:white;display:block}.template-bg{width:' + a4Width + 'px;height:' + a4Height + 'px;object-fit:fill;display:block;position:absolute;top:0;left:0;z-index:1}.field-container{box-sizing:border-box;z-index:10;position:absolute}.field-text{white-space:normal;overflow:hidden;line-height:1.2}';
      
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
            const { data: variationProducts, error } = await supabaseAdmin
              .from('flyer_products')
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
              value = product.sales_price.toFixed(2);
              break;
            case 'offer_price':
              value = product.offer_price.toFixed(2);
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
                // Create layered images container
                productFieldsHtml += '<div class="field-container" style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;">';
                productFieldsHtml += '<div style="position:relative;width:100%;height:100%;overflow:hidden;">';
                
                // Support up to 12 variations - show only first 4 for best visibility
                const maxVisibleImages = Math.min(variationImages.length, 4);
                const imagesToShow = variationImages.slice(0, maxVisibleImages);
                
                if (maxVisibleImages === 2) {
                  // TWO IMAGES: Back image smaller and offset, front image full size but contained
                  
                  // BACK IMAGE - smaller (65% size) and positioned to left/top
                  const backImgUrl = imagesToShow[1];
                  const backWidth = scaledWidth * 0.65;
                  const backHeight = scaledHeight * 0.65;
                  productFieldsHtml += '<img src="' + backImgUrl + '" style="position:absolute;left:0px;top:0px;width:' + backWidth + 'px;height:' + backHeight + 'px;object-fit:contain;z-index:1;opacity:0.85;filter:drop-shadow(2px 2px 4px rgba(0,0,0,0.3));max-width:' + backWidth + 'px;max-height:' + backHeight + 'px;" alt="Back variation">';
                  
                  // FRONT IMAGE - 85% size, offset to right/bottom to reveal back image
                  const frontImgUrl = imagesToShow[0];
                  const frontWidth = scaledWidth * 0.85;
                  const frontHeight = scaledHeight * 0.85;
                  const frontOffset = scaledWidth * 0.12; // 12% offset
                  productFieldsHtml += '<img src="' + frontImgUrl + '" style="position:absolute;left:' + frontOffset + 'px;top:' + frontOffset + 'px;width:' + frontWidth + 'px;height:' + frontHeight + 'px;object-fit:contain;z-index:2;opacity:1;filter:drop-shadow(3px 3px 6px rgba(0,0,0,0.4));max-width:' + frontWidth + 'px;max-height:' + frontHeight + 'px;" alt="Front variation">';
                  
                } else if (maxVisibleImages === 3) {
                  // THREE IMAGES: Optimized stacking for exactly 3 variations
                  // Back image (60%), middle (72%), front (85%)
                  const sizes = [0.60, 0.72, 0.85];
                  const baseWidth = scaledWidth;
                  const baseHeight = scaledHeight;
                  const offsetStep = baseWidth * 0.09; // Tighter spacing to stay in bounds
                  
                  for (let i = 0; i < 3; i++) {
                    const imgUrl = imagesToShow[i];
                    const zIndex = i + 1;
                    const imgWidth = baseWidth * sizes[i];
                    const imgHeight = baseHeight * sizes[i];
                    const offset = i * offsetStep;
                    const opacity = i === 2 ? '1' : '0.88';
                    
                    productFieldsHtml += '<img src="' + imgUrl + '" style="position:absolute;left:' + offset + 'px;top:' + offset + 'px;width:' + imgWidth + 'px;height:' + imgHeight + 'px;object-fit:contain;z-index:' + zIndex + ';opacity:' + opacity + ';filter:drop-shadow(2px 2px 4px rgba(0,0,0,0.3));max-width:' + imgWidth + 'px;max-height:' + imgHeight + 'px;" alt="Variation ' + (i + 1) + '">';
                  }
                  
                } else {
                  // 4+ IMAGES: Stack with decreasing sizes (shows first 4)
                  for (let i = 0; i < maxVisibleImages; i++) {
                    const imgUrl = imagesToShow[i];
                    const zIndex = i + 1;
                    // Size progression: back=55%, next=68%, next=80%, front=90%
                    const sizeMultiplier = 0.55 + (i * (0.35 / (maxVisibleImages - 1)));
                    const imgWidth = scaledWidth * sizeMultiplier;
                    const imgHeight = scaledHeight * sizeMultiplier;
                    const offset = i * (scaledWidth * 0.08); // Reduced from 0.13 to 0.08
                    const opacity = i === maxVisibleImages - 1 ? '1' : '0.85';
                    
                    productFieldsHtml += '<img src="' + imgUrl + '" style="position:absolute;left:' + offset + 'px;top:' + offset + 'px;width:' + imgWidth + 'px;height:' + imgHeight + 'px;object-fit:contain;z-index:' + zIndex + ';opacity:' + opacity + ';filter:drop-shadow(2px 2px 4px rgba(0,0,0,0.3));max-width:' + imgWidth + 'px;max-height:' + imgHeight + 'px;" alt="Variation ' + (i + 1) + '">';
                  }
                  
                  // If more than 4 variations exist, show count badge
                  if (variationImages.length > 4) {
                    const badgeRight = 5; // Position from right edge
                    const badgeTop = 5; // Position from top edge
                    productFieldsHtml += '<div style="position:absolute;right:' + badgeRight + 'px;top:' + badgeTop + 'px;background:#ef4444;color:white;font-size:11px;font-weight:bold;padding:3px 6px;border-radius:10px;z-index:100;box-shadow:0 2px 4px rgba(0,0,0,0.3);">+' + (variationImages.length - 4) + '</div>';
                  }
                }
                
                productFieldsHtml += '</div>';
                productFieldsHtml += '</div>';
              } else if (product.image_url) {
                // Single product image
                productFieldsHtml += '<div class="field-container" style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;"><img src="' + product.image_url + '" style="width:100%;height:100%;object-fit:contain;"></div>';
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
            
            productFieldsHtml += '<div class="field-container" style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;"><div class="field-text" style="width:100%;height:100%;font-size:' + scaledFontSize + 'px;text-align:' + field.alignment + ';color:' + field.color + ';display:flex;align-items:center;justify-content:' + justifyContent + ';' + fontWeight + strikethrough + dirAttr + '">' + contentHtml + '</div></div>';
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
      let cssText = '@page{size:A4 portrait;margin:0}@media print{html,body{width:210mm;height:297mm;margin:0;padding:0}}*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;margin:0;padding:0}.template-page{position:relative;width:794px;height:1123px;overflow:hidden;page-break-after:always;background:white;display:block;margin:0 auto}.template-page:last-child{page-break-after:auto}.copy-container{position:relative}.template-bg{object-fit:fill;display:block;position:absolute;top:0;left:0;z-index:1}.field-container{box-sizing:border-box;z-index:10;position:absolute}.field-text{white-space:normal;overflow:hidden;line-height:1.2}';
      
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
                  {new Date(offer.start_date).toLocaleDateString()} - {new Date(offer.end_date).toLocaleDateString()}
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
          <h3 class="section-title">Products in Selected Offer</h3>
          
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
          <div class="products-table-container">
            <table class="products-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Image</th>
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
                    <td class="serial-cell">{products.indexOf(product) + 1}</td>
                    <td class="image-cell">
                      <div class="product-image-small">
                        {#if product.image_url}
                          <img src={product.image_url} alt={product.product_name_en} />
                        {:else}
                          <div class="no-image-small">📦</div>
                        {/if}
                      </div>
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
                      <span class="regular-price">{product.sales_price.toFixed(2)} SAR</span>
                    </td>
                    <td class="price-cell">
                      <span class="offer-price">{product.offer_price.toFixed(2)} SAR</span>
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
                        {((product.sales_price - product.offer_price) * product.offer_qty).toFixed(2)} SAR
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
    width: 50px;
    padding: 0.25rem;
    border: 2px solid #e5e7eb;
    border-radius: 4px;
    font-size: 0.75rem;
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
    opacity: 1;
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
