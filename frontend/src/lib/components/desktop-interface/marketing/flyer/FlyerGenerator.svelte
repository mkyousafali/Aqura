<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  
  interface FlyerOffer {
    id: string;
    template_id: string;
    template_name: string;
    start_date: string;
    end_date: string;
    is_active: boolean;
    created_at: string;
  }
  
  interface FlyerTemplate {
    id: string;
    name: string;
    description: string | null;
    first_page_image_url: string;
    sub_page_image_urls: string[];
    first_page_configuration: any[];
    sub_page_configurations: any[][];
    metadata: any;
    is_active: boolean;
    is_default: boolean;
    category: string | null;
    usage_count: number;
    created_at: string;
  }
  
  interface OfferProduct {
    id: string;
    offer_id: string;
    product_barcode: string;
    cost: number | null;
    sales_price: number | null;
    offer_price: number | null;
    profit_amount: number | null;
    profit_percent: number | null;
    profit_after_offer: number | null;
    decrease_amount: number | null;
    offer_qty: number;
    limit_qty: number | null;
    free_qty: number;
    created_at: string;
    // Variation group fields
    is_variation_group?: boolean;
    variation_count?: number;
    variation_barcodes?: string[];
    parent_product_barcode?: string;
    variation_group_name_en?: string;
    variation_group_name_ar?: string;
    variation_images?: string[]; // URLs of all variation images
  }
  
  let activeOffers: FlyerOffer[] = [];
  let flyerTemplates: FlyerTemplate[] = [];
  let selectedOfferId: string = '';
  let selectedTemplateId: string = '';
  let isLoadingOffers = true;
  let isLoadingTemplates = true;
  let errorMessage = '';
  let successMessage = '';
  let offerProducts: OfferProduct[] = [];
  let isLoadingProducts = false;
  let activeTab: 'first' | 'sub' = 'first';
  let activeSubPageIndex: number = 0;
  let showProductSelector = false;
  let selectedFieldForProduct: any = null;
  let selectedPageType: 'first' | 'sub' = 'first';
  let selectedSubPageIndex: number = 0;
  let fieldProductAssignments: { [key: string]: string } = {}; // fieldId -> product barcode
  let productsData: any[] = []; // Full product data with details
  let selectedFieldId: string | null = null;
  
  // Field drag and resize
  let isDraggingField = false;
  let isResizingField = false;
  let fieldDragStartX = 0;
  let fieldDragStartY = 0;
  let resizeHandle = '';
  
  // Action menu system
  let showActionMenu = false;
  let actionMenuX = 0;
  let actionMenuY = 0;
  let selectedElement: any = null;
  let elementType: 'image' | 'text' | null = null;
  let isDraggingMenu = false;
  let menuDragOffsetX = 0;
  let menuDragOffsetY = 0;
  
  // Adjustment values
  let adjustmentValue = 0;
  let isAdjusting = false;
  
  // Element editing (move, resize, rotate)
  let isDraggingElement = false;
  let isResizingElement = false;
  let elementDragStartX = 0;
  let elementDragStartY = 0;
  let elementResizeHandle = '';
  let elementRotation = 0;
  let isDraggingText = false;
  let textDragStartX = 0;
  let textDragStartY = 0;
  let draggedTextElement: any = null;
  let showTextControls = false;
  let textControlsX = 0;
  let textControlsY = 0;
  let selectedTextElement: any = null;
  
  // Variant image dragging
  let isDraggingVariantImage = false;
  let draggedVariantImageIndex = -1;
  let draggedVariantFieldId = '';
  let variantDragStartX = 0;
  let variantDragStartY = 0;
  let selectedVariantImageIndex = 0; // Which variant image is selected (0, 1, or 2)
  let isVariationGroup = false; // Whether current element is a variation group
  
  // Page selector sidebar and fields popup
  let showFieldsPopup = false;
  let selectedPopupPageType: 'first' | 'sub' = 'first';
  let selectedPopupPageIndex: number = 0;
  let popupFields: any[] = [];
  
  async function loadActiveOffers() {
    isLoadingOffers = true;
    errorMessage = '';
    
    try {
      const { data, error } = await supabase
        .from('flyer_offers')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false });
      
      if (error) throw error;
      
      activeOffers = data || [];
      
      // Auto-select first offer if available
      if (activeOffers.length > 0 && !selectedOfferId) {
        selectedOfferId = activeOffers[0].id;
        await loadOfferProducts(selectedOfferId);
      }
    } catch (error: any) {
      console.error('Error loading offers:', error);
      errorMessage = `Failed to load offers: ${error.message}`;
    } finally {
      isLoadingOffers = false;
    }
  }
  
  async function loadFlyerTemplates() {
    isLoadingTemplates = true;
    errorMessage = '';
    
    try {
      const { data, error } = await supabase
        .from('flyer_templates')
        .select('*')
        .eq('is_active', true)
        .is('deleted_at', null)
        .order('is_default', { ascending: false })
        .order('usage_count', { ascending: false });
      
      if (error) throw error;
      
      flyerTemplates = data || [];
      
      // Auto-select default template or first template
      if (flyerTemplates.length > 0 && !selectedTemplateId) {
        const defaultTemplate = flyerTemplates.find(t => t.is_default);
        selectedTemplateId = defaultTemplate ? defaultTemplate.id : flyerTemplates[0].id;
      }
    } catch (error: any) {
      console.error('Error loading templates:', error);
      errorMessage = `Failed to load templates: ${error.message}`;
    } finally {
      isLoadingTemplates = false;
    }
  }
  
  async function loadOfferProducts(offerId: string) {
    if (!offerId) return;
    
    isLoadingProducts = true;
    try {
      const { data, error } = await supabase
        .from('flyer_offer_products')
        .select('*')
        .eq('offer_id', offerId);
      
      if (error) throw error;
      
      if (!data || data.length === 0) {
        offerProducts = [];
        productsData = [];
        return;
      }
      
      const barcodes = data.map(op => op.product_barcode);
      
      // Get product details from products (including variation fields)
      const { data: productDetails, error: productError } = await supabase
        .from('products')
        .select('barcode, product_name_en, product_name_ar, unit_name, image_url, is_variation, parent_product_barcode, variation_group_name_en, variation_group_name_ar, variation_image_override, variation_order')
        .in('barcode', barcodes);
      
      if (productError) throw productError;
      
      // Combine offer data with product details
      const allProducts = data.map(offerProduct => {
        const productDetail = productDetails?.find(p => p.barcode === offerProduct.product_barcode);
        return {
          ...offerProduct,
          product_name_en: productDetail?.product_name_en || '',
          product_name_ar: productDetail?.product_name_ar || '',
          unit_name: productDetail?.unit_name || '',
          image_url: productDetail?.image_url || productDetail?.variation_image_override,
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
      const consolidatedProducts: OfferProduct[] = [];
      
      // Add standalone products
      consolidatedProducts.push(...standaloneProducts);
      
      // Add consolidated variation groups
      for (const [parentBarcode, groupProducts] of variationGroups.entries()) {
        if (groupProducts.length > 0) {
          const firstProduct = groupProducts[0];
          
          // ONLY use variations that are actually selected in the offer
          const offerVariationBarcodes = groupProducts.map(p => p.product_barcode);
          
          // Fetch variation images
          const { data: variationImgData } = await supabase
            .from('products')
            .select('image_url, variation_order')
            .in('barcode', offerVariationBarcodes)
            .order('variation_order', { ascending: true });
          
          const variationImages = variationImgData
            ?.filter(p => p.image_url)
            .map(p => p.image_url) || [];
          
          // Use group name if available, fallback to first product name
          const groupNameEn = firstProduct.variation_group_name_en || firstProduct.product_name_en;
          const groupNameAr = firstProduct.variation_group_name_ar || firstProduct.product_name_ar;
          
          // Find parent product or use first variation's data
          const parentProduct = groupProducts.find(p => p.product_barcode === parentBarcode) || firstProduct;
          
          consolidatedProducts.push({
            ...parentProduct,
            product_barcode: parentBarcode,
            product_name_en: groupNameEn,
            product_name_ar: groupNameAr,
            is_variation_group: true,
            variation_count: offerVariationBarcodes.length,
            variation_barcodes: offerVariationBarcodes,
            variation_images: variationImages,
            // Use parent's image or first variation's image
            image_url: parentProduct.image_url || firstProduct.image_url
          });
        }
      }
      
      offerProducts = consolidatedProducts;
      
      // Also update productsData for backward compatibility
      productsData = consolidatedProducts.map(op => ({
        barcode: op.product_barcode,
        product_name_en: op.product_name_en,
        product_name_ar: op.product_name_ar,
        unit_name: op.unit_name,
        image_url: op.image_url,
        is_variation_group: op.is_variation_group,
        variation_count: op.variation_count,
        variation_barcodes: op.variation_barcodes,
        variation_group_name_en: op.variation_group_name_en,
        variation_group_name_ar: op.variation_group_name_ar,
        variation_images: op.variation_images
      }));
    } catch (error: any) {
      console.error('Error loading offer products:', error);
      errorMessage = `Failed to load offer products: ${error.message}`;
    } finally {
      isLoadingProducts = false;
    }
  }
  
  function handleFieldDoubleClick(field: any, pageType: 'first' | 'sub', subPageIndex?: number) {
    if (selectedFieldId === field.id) {
      // If already selected, open product selector
      selectedFieldForProduct = field;
      selectedPageType = pageType;
      selectedSubPageIndex = subPageIndex || 0;
      showProductSelector = true;
    } else {
      // Select the field
      selectedFieldId = field.id;
      selectedPageType = pageType;
      selectedSubPageIndex = subPageIndex || 0;
    }
  }
  
  function handleFieldClick(field: any, pageType: 'first' | 'sub', subPageIndex?: number, event?: MouseEvent) {
    if (event) {
      event.stopPropagation();
    }
    selectedFieldId = field.id;
    selectedPageType = pageType;
    selectedSubPageIndex = subPageIndex || 0;
  }
  
  // Show action menu on double-click
  function showElementActionMenu(event: MouseEvent, configField: any, field: any, type: 'image' | 'text') {
    event.preventDefault();
    event.stopPropagation();
    
    selectedElement = { configField, field };
    elementType = type;
    actionMenuX = event.clientX;
    actionMenuY = event.clientY;
    showActionMenu = true;
    
    if (type === 'text') {
      adjustmentValue = configField.fontSize || 14;
    } else {
      adjustmentValue = configField.width || 100;
    }
  }
  
  function closeActionMenu() {
    showActionMenu = false;
    selectedElement = null;
    elementType = null;
    isAdjusting = false;
  }
  
  // Menu drag handlers
  function startMenuDrag(event: MouseEvent) {
    isDraggingMenu = true;
    menuDragOffsetX = event.clientX - actionMenuX;
    menuDragOffsetY = event.clientY - actionMenuY;
    window.addEventListener('mousemove', handleMenuDrag);
    window.addEventListener('mouseup', stopMenuDrag);
  }
  
  function handleMenuDrag(event: MouseEvent) {
    if (!isDraggingMenu) return;
    actionMenuX = event.clientX - menuDragOffsetX;
    actionMenuY = event.clientY - menuDragOffsetY;
  }
  
  function stopMenuDrag() {
    isDraggingMenu = false;
    window.removeEventListener('mousemove', handleMenuDrag);
    window.removeEventListener('mouseup', stopMenuDrag);
  }
  
  // Handle double-click on image/text to show action menu
  function handleElementDoubleClick(event: MouseEvent, configField: any, field: any, type: 'image' | 'text', assignedProduct?: any) {
    event.preventDefault();
    event.stopPropagation();
    
    if (type === 'text') {
      // For text, show inline scale controls
      selectedTextElement = { configField, field };
      
      // Position in bottom-right corner
      textControlsX = window.innerWidth - 250; // 220px width + 30px padding
      textControlsY = window.innerHeight - 400; // Position from bottom
      
      showTextControls = true;
    } else {
      // For images, show action menu
      selectedElement = { configField, field, assignedProduct };
      elementType = type;
      
      // Check if this is a variation group
      isVariationGroup = assignedProduct?.is_variation_group && assignedProduct?.variation_images?.length > 0;
      selectedVariantImageIndex = 0; // Default to first image
      
      // Position menu in bottom-right corner with some padding
      actionMenuX = window.innerWidth - 380;
      actionMenuY = window.innerHeight - 450;
      
      showActionMenu = true;
      elementRotation = configField.rotation || 0;
    }
  }
  
  // Handle single click on text to start dragging
  function handleTextMouseDown(event: MouseEvent, configField: any, field: any) {
    event.preventDefault();
    event.stopPropagation();
    
    isDraggingText = true;
    draggedTextElement = { configField, field };
    textDragStartX = event.clientX;
    textDragStartY = event.clientY;
    
    window.addEventListener('mousemove', handleTextDragMove);
    window.addEventListener('mouseup', handleTextDragEnd);
  }
  
  function handleTextDragMove(event: MouseEvent) {
    if (!isDraggingText || !draggedTextElement) return;
    
    const deltaX = event.clientX - textDragStartX;
    const deltaY = event.clientY - textDragStartY;
    
    draggedTextElement.configField.x = (draggedTextElement.configField.x || 0) + deltaX;
    draggedTextElement.configField.y = (draggedTextElement.configField.y || 0) + deltaY;
    
    textDragStartX = event.clientX;
    textDragStartY = event.clientY;
    
    flyerTemplates = [...flyerTemplates];
  }
  
  function handleTextDragEnd() {
    isDraggingText = false;
    draggedTextElement = null;
    window.removeEventListener('mousemove', handleTextDragMove);
    window.removeEventListener('mouseup', handleTextDragEnd);
  }
  
  // Variant image drag handlers
  function handleVariantImageMouseDown(event: MouseEvent, fieldId: string, imageIndex: number) {
    event.preventDefault();
    event.stopPropagation();
    
    isDraggingVariantImage = true;
    draggedVariantImageIndex = imageIndex;
    draggedVariantFieldId = fieldId;
    variantDragStartX = event.clientX;
    variantDragStartY = event.clientY;
    
    window.addEventListener('mousemove', handleVariantImageMouseMove);
    window.addEventListener('mouseup', handleVariantImageMouseUp);
  }
  
  function handleVariantImageMouseMove(event: MouseEvent) {
    if (!isDraggingVariantImage || !draggedVariantFieldId || draggedVariantImageIndex === -1) return;
    
    const deltaX = event.clientX - variantDragStartX;
    const deltaY = event.clientY - variantDragStartY;
    
    updateVariantImagePosition(draggedVariantFieldId, draggedVariantImageIndex, deltaX, deltaY);
    
    variantDragStartX = event.clientX;
    variantDragStartY = event.clientY;
  }
  
  function handleVariantImageMouseUp() {
    isDraggingVariantImage = false;
    draggedVariantImageIndex = -1;
    draggedVariantFieldId = '';
    window.removeEventListener('mousemove', handleVariantImageMouseMove);
    window.removeEventListener('mouseup', handleVariantImageMouseUp);
  }
  
  function updateVariantImagePosition(fieldId: string, imageIndex: number, deltaX: number, deltaY: number) {
    const selectedTemplate = flyerTemplates.find(t => t.id === selectedTemplateId);
    if (!selectedTemplate) return;
    
    const fields = selectedPageType === 'first' 
      ? selectedTemplate.first_page_configuration 
      : selectedTemplate.sub_page_configurations[selectedSubPageIndex];
    
    if (!fields) return;
    
    const fieldIndex = fields.findIndex((f: any) => f.id === fieldId);
    if (fieldIndex === -1) return;
    
    const field = fields[fieldIndex];
    
    // Initialize variantImagePositions if not exists
    if (!field.variantImagePositions) {
      field.variantImagePositions = [];
    }
    
    // Initialize position for this image if not exists (default stacked positions)
    if (!field.variantImagePositions[imageIndex]) {
      const defaultOffset = imageIndex * 15;
      field.variantImagePositions[imageIndex] = {
        x: defaultOffset,
        y: defaultOffset
      };
    }
    
    // Update position
    field.variantImagePositions[imageIndex].x += deltaX;
    field.variantImagePositions[imageIndex].y += deltaY;
    
    flyerTemplates = [...flyerTemplates];
  }
  
  function applyTextScale(amount: number) {
    if (!selectedTextElement) return;
    
    const currentWidth = selectedTextElement.configField.width || 100;
    const currentHeight = selectedTextElement.configField.height || 20;
    
    selectedTextElement.configField.width = Math.max(20, currentWidth + amount);
    selectedTextElement.configField.height = Math.max(10, currentHeight + (amount * 0.2));
    
    flyerTemplates = [...flyerTemplates];
  }
  
  function applyTextFontSize(amount: number) {
    if (!selectedTextElement) return;
    
    const currentSize = selectedTextElement.configField.fontSize || 14;
    selectedTextElement.configField.fontSize = Math.max(6, currentSize + amount);
    
    flyerTemplates = [...flyerTemplates];
  }
  
  function closeTextControls() {
    showTextControls = false;
    selectedTextElement = null;
  }
  
  function applyTextRotation(degrees: number) {
    if (!selectedTextElement) return;
    
    const currentRotation = selectedTextElement.configField.rotation || 0;
    selectedTextElement.configField.rotation = (currentRotation + degrees) % 360;
    
    // Force reactive update
    flyerTemplates = [...flyerTemplates];
  }
  
  // Start moving element
  function startElementMove() {
    showActionMenu = false;
    isDraggingElement = true;
    window.addEventListener('mousemove', handleElementDragMove);
    window.addEventListener('mouseup', handleElementDragEnd);
  }
  
  function handleElementDragMove(event: MouseEvent) {
    if (!isDraggingElement || !selectedElement) return;
    
    // If it's a variation group, move the selected variant image individually
    if (isVariationGroup) {
      const { configField } = selectedElement;
      
      // Initialize variantImagePositions if not exists
      if (!configField.variantImagePositions) {
        configField.variantImagePositions = [];
      }
      
      // Initialize position for this image if not exists (default stacked positions)
      if (!configField.variantImagePositions[selectedVariantImageIndex]) {
        const defaultOffset = selectedVariantImageIndex * 15;
        configField.variantImagePositions[selectedVariantImageIndex] = {
          x: defaultOffset,
          y: defaultOffset
        };
      }
      
      // Move the selected variant image
      configField.variantImagePositions[selectedVariantImageIndex].x += event.movementX;
      configField.variantImagePositions[selectedVariantImageIndex].y += event.movementY;
    } else {
      // For single images, move the entire element
      selectedElement.configField.x = (selectedElement.configField.x || 0) + event.movementX;
      selectedElement.configField.y = (selectedElement.configField.y || 0) + event.movementY;
    }
    
    flyerTemplates = [...flyerTemplates];
  }
  
  function handleElementDragEnd() {
    isDraggingElement = false;
    window.removeEventListener('mousemove', handleElementDragMove);
    window.removeEventListener('mouseup', handleElementDragEnd);
  }
  
  // Start resizing element
  function startElementResize() {
    showActionMenu = false;
    isResizingElement = true;
    window.addEventListener('mousemove', handleElementResizeMove);
    window.addEventListener('mouseup', handleElementResizeEnd);
  }
  
  function handleElementResizeMove(event: MouseEvent) {
    if (!isResizingElement || !selectedElement) return;
    
    const { configField } = selectedElement;
    const currentWidth = configField.width || 100;
    const currentHeight = configField.height || 100;
    
    // Maintain aspect ratio
    const newWidth = Math.max(20, currentWidth + event.movementX);
    const aspectRatio = currentHeight / currentWidth;
    
    configField.width = newWidth;
    configField.height = Math.max(20, newWidth * aspectRatio);
    
    flyerTemplates = [...flyerTemplates];
  }
  
  function handleElementResizeEnd() {
    isResizingElement = false;
    window.removeEventListener('mousemove', handleElementResizeMove);
    window.removeEventListener('mouseup', handleElementResizeEnd);
  }
  
  // Rotate element
  function rotateElement(degrees: number) {
    if (!selectedElement) return;
    
    elementRotation = (elementRotation + degrees) % 360;
    selectedElement.configField.rotation = elementRotation;
    
    // Force reactive update
    flyerTemplates = [...flyerTemplates];
  }
  
  // Page selector functions
  function openFieldsPopup(pageType: 'first' | 'sub', pageIndex: number = 0) {
    const selectedTemplate = flyerTemplates.find(t => t.id === selectedTemplateId);
    if (!selectedTemplate) return;
    
    selectedPopupPageType = pageType;
    selectedPopupPageIndex = pageIndex;
    
    if (pageType === 'first') {
      popupFields = selectedTemplate.first_page_configuration || [];
    } else {
      popupFields = selectedTemplate.sub_page_configurations?.[pageIndex] || [];
    }
    
    showFieldsPopup = true;
  }
  
  function closeFieldsPopup() {
    showFieldsPopup = false;
    popupFields = [];
  }
  
  function selectFieldFromPopup(field: any) {
    selectedFieldForProduct = field;
    selectedPageType = selectedPopupPageType;
    selectedSubPageIndex = selectedPopupPageIndex;
    showFieldsPopup = false;
    showProductSelector = true;
  }
  
  // Field drag and resize handlers
  function handleFieldMouseDown(event: MouseEvent, fieldId: string, handle?: string) {
    event.preventDefault();
    event.stopPropagation();
    
    selectedFieldId = fieldId;
    
    if (handle) {
      isResizingField = true;
      resizeHandle = handle;
    } else {
      isDraggingField = true;
    }
    
    fieldDragStartX = event.clientX;
    fieldDragStartY = event.clientY;
    
    window.addEventListener('mousemove', handleFieldMouseMove);
    window.addEventListener('mouseup', handleFieldMouseUp);
  }
  
  function handleFieldMouseMove(event: MouseEvent) {
    if (!selectedFieldId) return;
    
    const deltaX = event.clientX - fieldDragStartX;
    const deltaY = event.clientY - fieldDragStartY;
    
    if (isDraggingField) {
      updateFieldPosition(selectedFieldId, deltaX, deltaY);
      fieldDragStartX = event.clientX;
      fieldDragStartY = event.clientY;
    } else if (isResizingField) {
      updateFieldSize(selectedFieldId, deltaX, deltaY, resizeHandle);
      fieldDragStartX = event.clientX;
      fieldDragStartY = event.clientY;
    }
  }
  
  function handleFieldMouseUp() {
    isDraggingField = false;
    isResizingField = false;
    resizeHandle = '';
    window.removeEventListener('mousemove', handleFieldMouseMove);
    window.removeEventListener('mouseup', handleFieldMouseUp);
  }
  
  function updateFieldPosition(fieldId: string, deltaX: number, deltaY: number) {
    const selectedTemplate = flyerTemplates.find(t => t.id === selectedTemplateId);
    if (!selectedTemplate) return;
    
    if (selectedPageType === 'first') {
      const fieldIndex = selectedTemplate.first_page_configuration.findIndex((f: any) => f.id === fieldId);
      if (fieldIndex !== -1) {
        selectedTemplate.first_page_configuration[fieldIndex].x += deltaX;
        selectedTemplate.first_page_configuration[fieldIndex].y += deltaY;
        flyerTemplates = [...flyerTemplates];
      }
    } else if (selectedPageType === 'sub') {
      const fieldIndex = selectedTemplate.sub_page_configurations[selectedSubPageIndex]?.findIndex((f: any) => f.id === fieldId);
      if (fieldIndex !== -1) {
        selectedTemplate.sub_page_configurations[selectedSubPageIndex][fieldIndex].x += deltaX;
        selectedTemplate.sub_page_configurations[selectedSubPageIndex][fieldIndex].y += deltaY;
        flyerTemplates = [...flyerTemplates];
      }
    }
  }
  
  function updateFieldSize(fieldId: string, deltaX: number, deltaY: number, handle: string) {
    const selectedTemplate = flyerTemplates.find(t => t.id === selectedTemplateId);
    if (!selectedTemplate) return;
    
    const fields = selectedPageType === 'first' 
      ? selectedTemplate.first_page_configuration 
      : selectedTemplate.sub_page_configurations[selectedSubPageIndex];
    
    if (!fields) return;
    
    const fieldIndex = fields.findIndex((f: any) => f.id === fieldId);
    if (fieldIndex === -1) return;
    
    const field = fields[fieldIndex];
    
    switch (handle) {
      case 'se':
        field.width = Math.max(50, field.width + deltaX);
        field.height = Math.max(50, field.height + deltaY);
        break;
      case 'e':
        field.width = Math.max(50, field.width + deltaX);
        break;
      case 's':
        field.height = Math.max(50, field.height + deltaY);
        break;
    }
    
    flyerTemplates = [...flyerTemplates];
  }
  
  function startAdjustment(action: 'move' | 'resize' | 'fontSize') {
    isAdjusting = true;
  }
  
  function applyMove(direction: 'up' | 'down' | 'left' | 'right', amount: number = 5) {
    if (!selectedElement) return;
    
    const { configField } = selectedElement;
    switch (direction) {
      case 'up':
        configField.y = (configField.y || 0) - amount;
        break;
      case 'down':
        configField.y = (configField.y || 0) + amount;
        break;
      case 'left':
        configField.x = (configField.x || 0) - amount;
        break;
      case 'right':
        configField.x = (configField.x || 0) + amount;
        break;
    }
    flyerTemplates = [...flyerTemplates];
  }
  
  function applyResize(dimension: 'width' | 'height', change: number) {
    if (!selectedElement) return;
    
    const { configField } = selectedElement;
    if (dimension === 'width') {
      configField.width = Math.max(20, (configField.width || 100) + change);
    } else {
      configField.height = Math.max(20, (configField.height || 100) + change);
    }
    flyerTemplates = [...flyerTemplates];
  }
  
  function applyFontSize(change: number) {
    if (!selectedElement || elementType !== 'text') return;
    
    const { configField } = selectedElement;
    configField.fontSize = Math.max(8, Math.min(72, (configField.fontSize || 14) + change));
    adjustmentValue = configField.fontSize;
    flyerTemplates = [...flyerTemplates];
  }
  
  function assignProductToField(productBarcode: string) {
    if (selectedFieldForProduct) {
      const fieldKey = `${selectedPageType}-${selectedPageType === 'sub' ? selectedSubPageIndex : 0}-${selectedFieldForProduct.id}`;
      fieldProductAssignments[fieldKey] = productBarcode;
      fieldProductAssignments = { ...fieldProductAssignments }; // Trigger reactivity
    }
    showProductSelector = false;
    selectedFieldForProduct = null;
  }
  
  function getAssignedProduct(field: any, pageType: 'first' | 'sub', subPageIndex: number = 0) {
    const fieldKey = `${pageType}-${subPageIndex}-${field.id}`;
    const barcode = fieldProductAssignments[fieldKey];
    if (!barcode) return null;
    
    return productsData.find(p => p.barcode === barcode);
  }
  
  // Convert Western numerals to Arabic (Eastern Arabic) numerals
  function toArabicNumerals(num: number | string): string {
    const arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return String(num).replace(/\d/g, (digit) => arabicNumerals[parseInt(digit)]);
  }
  
  function getFieldValue(product: any, offerProduct: any, fieldType: string): string {
    switch (fieldType) {
      case 'product_name_en':
        // Use variation group name if it's a variation group
        return product.variation_group_name_en || product.product_name_en || '';
      case 'product_name_ar':
        // Use variation group name if it's a variation group
        return product.variation_group_name_ar || product.product_name_ar || '';
      case 'barcode':
        return product.barcode || '';
      case 'price':
        // Regular sales price - return just the number, currency icon will be added separately
        const price = offerProduct?.sales_price || product.sales_price || '0.00';
        return parseFloat(price).toFixed(2);
      case 'offer_price':
        // Offer price - return just the number, currency icon will be added separately
        const offerPrice = offerProduct?.offer_price || product.sales_price || '0.00';
        return parseFloat(offerPrice).toFixed(2);
      case 'offer_qty':
        // Show two lines: "عرض على" on line 1, then "qty unit_name" on line 2
        if (offerProduct?.offer_qty && offerProduct.offer_qty > 0) {
          const unitName = product.unit_name || 'قطعة';
          return `عرض على\n${toArabicNumerals(offerProduct.offer_qty)} ${unitName}`;
        }
        return '';
      case 'limit_qty':
        // Show two lines: "لكل عميل" on line 1, then "qty unit_name" on line 2
        if (offerProduct?.limit_qty && offerProduct.limit_qty > 0) {
          const unitName = product.unit_name || 'قطعة';
          return `لكل عميل\n${toArabicNumerals(offerProduct.limit_qty)} ${unitName}`;
        }
        return '';
      case 'free_qty':
        // Show "Buy X get Y free" format in Arabic
        if (offerProduct?.free_qty && offerProduct.free_qty > 0) {
          const unitName = product.unit_name || 'قطعة';
          const buyQty = offerProduct?.offer_qty || 1;
          return `اشتري ${toArabicNumerals(buyQty)} ${unitName}\nواحصل على ${toArabicNumerals(offerProduct.free_qty)} ${unitName} مجاناً`;
        }
        return '';
      case 'unit_name':
        return product.unit_name || '';
      case 'expire_date':
        return product.expire_date || '';
      case 'serial_number':
        return product.serial_number || '';
      case 'image':
        return product.image_url || '';
      case 'variation_text_en':
        return (product.is_variation_group && product.variation_count) ? 'Multiple varieties available' : '';
      case 'variation_text_ar':
        return (product.is_variation_group && product.variation_count) ? 'أصناف متعددة متوفرة' : '';
      default:
        return '';
    }
  }
  
  async function handleOfferChange() {
    if (selectedOfferId) {
      await loadOfferProducts(selectedOfferId);
    }
  }
  
  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }
  
  onMount(() => {
    loadActiveOffers();
    loadFlyerTemplates();
  });
</script>

<div class="h-full overflow-auto bg-gradient-to-br from-indigo-50 via-blue-50 to-purple-50 p-6">
  <!-- Selection Panel -->
  <div class="bg-white rounded-xl shadow-lg p-6 mb-6">
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <!-- Select Offer -->
      <div>
        <label class="block text-sm font-semibold text-gray-700 mb-2">
          Select Active Offer *
        </label>
        {#if isLoadingOffers}
          <div class="flex items-center justify-center p-4 border-2 border-gray-200 border-dashed rounded-lg">
            <svg class="animate-spin w-6 h-6 text-indigo-600" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span class="ml-2 text-gray-600">Loading offers...</span>
          </div>
        {:else if activeOffers.length === 0}
          <div class="p-4 border-2 border-gray-200 border-dashed rounded-lg text-center">
            <p class="text-gray-500 mb-2">No active offers found</p>
            <p class="text-sm text-gray-400">Create an offer first to generate flyers</p>
          </div>
        {:else}
          <select
            bind:value={selectedOfferId}
            on:change={handleOfferChange}
            class="w-full px-4 py-3 border-2 border-gray-200 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all"
          >
            <option value="">-- Choose an offer --</option>
            {#each activeOffers as offer}
              <option value={offer.id}>
                {offer.template_name} ({formatDate(offer.start_date)} - {formatDate(offer.end_date)})
              </option>
            {/each}
          </select>
        {/if}
      </div>
      
      <!-- Select Template -->
      <div>
        <label class="block text-sm font-semibold text-gray-700 mb-2">
          Select Flyer Template *
        </label>
        {#if isLoadingTemplates}
          <div class="flex items-center justify-center p-4 border-2 border-gray-200 border-dashed rounded-lg">
            <svg class="animate-spin w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span class="ml-2 text-gray-600">Loading templates...</span>
          </div>
        {:else if flyerTemplates.length === 0}
          <div class="p-4 border-2 border-gray-200 border-dashed rounded-lg text-center">
            <p class="text-gray-500 mb-2">No templates found</p>
            <p class="text-sm text-gray-400">Create a template first to generate flyers</p>
          </div>
        {:else}
          <select
            bind:value={selectedTemplateId}
            class="w-full px-4 py-3 border-2 border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
          >
            <option value="">-- Choose a template --</option>
            {#each flyerTemplates as template}
              <option value={template.id}>
                {template.name} {template.is_default ? '(Default)' : ''}
              </option>
            {/each}
          </select>
        {/if}
      </div>
    </div>
  </div>
  
  <!-- Template Preview -->
  {#if selectedTemplateId}
    {@const selectedTemplate = flyerTemplates.find(t => t.id === selectedTemplateId)}
    {#if selectedTemplate}
      <div class="bg-white rounded-xl shadow-lg p-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">
          📄 Template Preview: {selectedTemplate.name}
        </h3>
        
        <!-- Tabs -->
        <div class="tabs-header">
          <button 
            class="tab-btn {activeTab === 'first' ? 'active' : ''}"
            on:click={() => activeTab = 'first'}
          >
            First Page
          </button>
          {#if selectedTemplate.sub_page_image_urls && selectedTemplate.sub_page_image_urls.length > 0}
            <button 
              class="tab-btn {activeTab === 'sub' ? 'active' : ''}"
              on:click={() => { activeTab = 'sub'; activeSubPageIndex = 0; }}
            >
              Sub Pages ({selectedTemplate.sub_page_image_urls.length})
            </button>
          {/if}
        </div>
        
        <!-- Main Content with Sidebar and Preview -->
        <div class="main-content-wrapper">
          <!-- Page Selector Sidebar -->
          <div class="page-selector-sidebar">
            <h4 class="sidebar-title">📑 Pages</h4>
            
            <!-- First Page Button -->
            <button 
              class="page-selector-btn first-page"
              on:click={() => openFieldsPopup('first', 0)}
            >
              <span class="page-icon">📄</span>
              <div class="page-info">
                <span class="page-name">First Page</span>
                <span class="page-fields">{selectedTemplate.first_page_configuration?.length || 0} fields</span>
              </div>
            </button>
            
            <!-- Sub Pages Buttons -->
            {#if selectedTemplate.sub_page_image_urls && selectedTemplate.sub_page_image_urls.length > 0}
              <div class="sub-pages-section">
                <p class="sub-pages-label">Sub Pages</p>
                {#each selectedTemplate.sub_page_image_urls as _, index}
                  <button 
                    class="page-selector-btn sub-page"
                    on:click={() => openFieldsPopup('sub', index)}
                  >
                    <span class="page-icon">📃</span>
                    <div class="page-info">
                      <span class="page-name">Page {index + 1}</span>
                      <span class="page-fields">{selectedTemplate.sub_page_configurations?.[index]?.length || 0} fields</span>
                    </div>
                  </button>
                {/each}
              </div>
            {/if}
          </div>
          
          <!-- Preview Content -->
          <div class="preview-content-main">
        
        <!-- Preview Content -->
        <div class="preview-content">
          {#if activeTab === 'first'}
            <!-- First Page Preview -->
            <div class="preview-section">
              <div class="preview-header">
                <span class="preview-title">First Page</span>
                <span class="preview-badge">
                  {selectedTemplate.first_page_configuration?.length || 0} Fields
                </span>
              </div>
              
              <div class="preview-container">
                <div class="preview-wrapper">
                  <img 
                    src={selectedTemplate.first_page_image_url} 
                    alt="First Page" 
                    class="preview-image"
                    on:error={(e) => {
                      e.currentTarget.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="794" height="1123"%3E%3Crect fill="%23f0f0f0" width="794" height="1123"/%3E%3Ctext x="50%25" y="50%25" text-anchor="middle" fill="%23999" font-size="18"%3EImage Not Available%3C/text%3E%3C/svg%3E';
                    }}
                  />
                  
                  <!-- Show product field boxes -->
                  {#if selectedTemplate.first_page_configuration && selectedTemplate.first_page_configuration.length > 0}
                    {#each selectedTemplate.first_page_configuration as field}
                      {@const assignedProduct = getAssignedProduct(field, 'first', 0)}
                      {@const offerProduct = assignedProduct ? offerProducts.find(op => op.product_barcode === assignedProduct.barcode) : null}
                      <div
                        class="product-field {assignedProduct ? 'has-product' : ''} {selectedFieldId === field.id ? 'selected' : ''}"
                        style="left: {field.x}px; top: {field.y}px; width: {field.width}px; height: {field.height}px;"
                        on:click={(e) => handleFieldClick(field, 'first', 0, e)}
                        on:mousedown={(e) => handleFieldMouseDown(e, field.id)}
                      >
                        {#if assignedProduct && field.fields && field.fields.length > 0}
                          <!-- Render configured fields -->
                          <div class="field-preview-content">
                            {#each field.fields as configField}
                              {@const fieldValue = getFieldValue(assignedProduct, offerProduct, configField.label || configField.type)}
                              
                              {#if configField.label === 'image' && fieldValue}
                                <!-- Product Image (with variation group support) -->
                                <div 
                                  class="resizable-element"
                                  style="
                                    position: absolute;
                                    left: {configField.x || 0}px; 
                                    top: {configField.y || 0}px; 
                                    width: {configField.width || 100}px; 
                                    height: {configField.height || 100}px;
                                    transform: rotate({configField.rotation || 0}deg);
                                    transform-origin: center center;
                                  "
                                >
                                  {#if assignedProduct?.is_variation_group && assignedProduct?.variation_images && assignedProduct.variation_images.length > 0}
                                    <!-- Layered images for variation groups -->
                                    <div 
                                      class="img-stack"
                                      style="
                                        position: relative;
                                        width: 100%;
                                        height: 100%;
                                      "
                                    >
                                      {#each assignedProduct.variation_images.slice(0, 3) as imgUrl, imgIndex}
                                        {@const zIndex = 3 - imgIndex}
                                        {@const defaultOffset = imgIndex * 15}
                                        {@const savedPosition = configField.variantImagePositions?.[imgIndex]}
                                        {@const xPos = savedPosition?.x ?? defaultOffset}
                                        {@const yPos = savedPosition?.y ?? defaultOffset}
                                        <img 
                                          src={imgUrl} 
                                          alt="Variation {imgIndex + 1}" 
                                          on:mousedown={(e) => handleVariantImageMouseDown(e, field.id, imgIndex)}
                                          on:dblclick={(e) => handleElementDoubleClick(e, configField, field, 'image', assignedProduct)}
                                          style="
                                            position: absolute;
                                            width: 75%;
                                            height: 75%;
                                            object-fit: contain;
                                            z-index: {zIndex};
                                            left: {xPos}px;
                                            top: {yPos}px;
                                            opacity: 1;
                                            pointer-events: all;
                                            cursor: move;
                                          "
                                        />
                                      {/each}
                                    </div>
                                  {:else}
                                    <!-- Single product image -->
                                    <img 
                                      src={fieldValue} 
                                      alt="Product" 
                                      class="field-image-preview"
                                      on:dblclick={(e) => handleElementDoubleClick(e, configField, field, 'image', assignedProduct)}
                                      style="
                                        width: 100%;
                                        height: 100%;
                                        object-fit: contain;
                                        pointer-events: all;
                                        cursor: pointer;
                                      "
                                    />
                                  {/if}
                                </div>
                              {:else if configField.label === 'special_symbol' && configField.symbolUrl}
                                <!-- Special Symbol -->
                                <img 
                                  src={configField.symbolUrl} 
                                  alt="Symbol" 
                                  class="field-symbol-preview"
                                  style="
                                    position: absolute;
                                    left: {configField.symbolX || 0}px;
                                    top: {configField.symbolY || 0}px;
                                    width: {configField.symbolWidth || 30}px;
                                    height: {configField.symbolHeight || 30}px;
                                    object-fit: contain;
                                  "
                                />
                              {:else if configField.label !== 'special_symbol'}
                                <!-- Text Field with Icon (Resizable Container) -->
                                <div 
                                  class="resizable-element"
                                  style="
                                    position: absolute;
                                    left: {configField.x || 0}px; 
                                    top: {configField.y || 0}px; 
                                    width: {configField.width || 100}px; 
                                    height: {configField.height || 20}px;
                                    transform: rotate({configField.rotation || 0}deg);
                                    transform-origin: center center;
                                  "
                                >
                                  <div 
                                    class="field-text-preview"
                                    on:mousedown={(e) => handleTextMouseDown(e, configField, field)}
                                    on:dblclick={(e) => handleElementDoubleClick(e, configField, field, 'text')}
                                    style="
                                      width: 100%;
                                      height: 100%;
                                      font-size: {configField.fontSize || 14}px;
                                      color: {configField.color || '#000000'};
                                      text-align: {configField.alignment || 'left'};
                                      text-decoration: {configField.strikethrough ? 'line-through' : 'none'};
                                      font-weight: {configField.bold ? 'bold' : 'normal'};
                                      font-style: {configField.italic ? 'italic' : 'normal'};
                                      display: flex;
                                      align-items: center;
                                      justify-content: {configField.alignment === 'center' ? 'center' : configField.alignment === 'right' ? 'flex-end' : 'flex-start'};
                                      overflow: hidden;
                                      pointer-events: all;
                                      cursor: move;
                                    "
                                  >
                                    {#if configField.iconUrl}
                                      <img 
                                        src={configField.iconUrl} 
                                        alt="Icon" 
                                        class="field-icon-preview"
                                        style="
                                          position: absolute;
                                          left: {configField.iconX || 0}px;
                                          top: {configField.iconY || 0}px;
                                          width: {configField.iconWidth || 20}px;
                                          height: {configField.iconHeight || 20}px;
                                        "
                                      />
                                    {/if}
                                    {#if configField.label === 'price' || configField.label === 'offer_price'}
                                      <img 
                                        src="/icons/saudi-currency.png" 
                                        alt="Currency" 
                                        style="
                                          height: {(configField.fontSize || 14) * 0.65}px;
                                          width: auto;
                                          margin-right: 4px;
                                          vertical-align: baseline;
                                        "
                                      />
                                    {/if}
                                    {#if configField.label === 'offer_price'}
                                      {@const [integerPart, decimalPart] = fieldValue.split('.')}
                                      <span style="font-weight: 700; unicode-bidi: plaintext;">
                                        {integerPart}<span style="font-size: 50%; vertical-align: baseline;">.{decimalPart || '00'}</span>
                                      </span>
                                    {:else if configField.label === 'price'}
                                      <span style="font-weight: 700; text-decoration: line-through; unicode-bidi: plaintext;">
                                        {fieldValue}
                                      </span>
                                    {:else}
                                      <span style="font-weight: 400; unicode-bidi: plaintext;">
                                        {fieldValue}
                                      </span>
                                    {/if}
                                  </div>
                                </div>
                              {/if}
                            {/each}
                          </div>
                        {:else if assignedProduct}
                          <span class="field-product-name">{assignedProduct.product_name_en || assignedProduct.product_name_ar || 'Product'}</span>
                        {:else}
                          <span class="field-number-badge">#{field.number}</span>
                        {/if}
                        
                        {#if selectedFieldId === field.id}
                          <div class="resize-handle resize-se" on:mousedown={(e) => handleFieldMouseDown(e, field.id, 'se')}></div>
                          <div class="resize-handle resize-e" on:mousedown={(e) => handleFieldMouseDown(e, field.id, 'e')}></div>
                          <div class="resize-handle resize-s" on:mousedown={(e) => handleFieldMouseDown(e, field.id, 's')}></div>
                        {/if}
                      </div>
                    {/each}
                  {/if}
                </div>
              </div>
            </div>
          {:else}
            <!-- Sub Pages Preview -->
            <div class="preview-section">
              <div class="preview-header">
                <span class="preview-title">Sub Pages</span>
                <div class="sub-page-tabs">
                  {#each selectedTemplate.sub_page_image_urls as _, index}
                    <button
                      class="sub-page-tab-btn {activeSubPageIndex === index ? 'active' : ''}"
                      on:click={() => activeSubPageIndex = index}
                    >
                      Page {index + 1}
                    </button>
                  {/each}
                </div>
              </div>
              
              <div class="preview-container">
                {#if selectedTemplate.sub_page_image_urls[activeSubPageIndex]}
                  <div class="preview-wrapper">
                    <img 
                      src={selectedTemplate.sub_page_image_urls[activeSubPageIndex]} 
                      alt="Sub Page {activeSubPageIndex + 1}" 
                      class="preview-image"
                      on:error={(e) => {
                        e.currentTarget.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="794" height="1123"%3E%3Crect fill="%23f0f0f0" width="794" height="1123"/%3E%3Ctext x="50%25" y="50%25" text-anchor="middle" fill="%23999" font-size="18"%3EImage Not Available%3C/text%3E%3C/svg%3E';
                      }}
                    />
                    
                    <!-- Show product field boxes -->
                    {#if selectedTemplate.sub_page_configurations && selectedTemplate.sub_page_configurations[activeSubPageIndex]}
                      {#each selectedTemplate.sub_page_configurations[activeSubPageIndex] as field}
                        {@const assignedProduct = getAssignedProduct(field, 'sub', activeSubPageIndex)}
                        {@const offerProduct = assignedProduct ? offerProducts.find(op => op.product_barcode === assignedProduct.barcode) : null}
                        <div
                          class="product-field {assignedProduct ? 'has-product' : ''} {selectedFieldId === field.id ? 'selected' : ''}"
                          style="left: {field.x}px; top: {field.y}px; width: {field.width}px; height: {field.height}px;"
                          on:click={(e) => handleFieldClick(field, 'sub', activeSubPageIndex, e)}
                          on:mousedown={(e) => handleFieldMouseDown(e, field.id)}
                        >
                          {#if assignedProduct && field.fields && field.fields.length > 0}
                            <!-- Render configured fields -->
                            <div class="field-preview-content">
                              {#each field.fields as configField}
                                {@const fieldValue = getFieldValue(assignedProduct, offerProduct, configField.label || configField.type)}
                                
                                {#if configField.label === 'image' && fieldValue}
                                  <!-- Product Image (with variation group support) -->
                                  <div 
                                    class="element-wrapper"
                                    style="
                                      position: absolute;
                                      left: {configField.x || 0}px; 
                                      top: {configField.y || 0}px; 
                                      width: {configField.width || 100}px; 
                                      height: {configField.height || 100}px;
                                      transform: rotate({configField.rotation || 0}deg);
                                      transform-origin: center center;
                                    "
                                  >
                                    {#if assignedProduct?.is_variation_group && assignedProduct?.variation_images && assignedProduct.variation_images.length > 0}
                                      <!-- Layered images for variation groups -->
                                      <div 
                                        class="img-stack"
                                        style="
                                          position: relative;
                                          width: 100%;
                                          height: 100%;
                                        "
                                      >
                                        {#each assignedProduct.variation_images.slice(0, 3) as imgUrl, imgIndex}
                                          {@const zIndex = 3 - imgIndex}
                                          {@const defaultOffset = imgIndex * 15}
                                          {@const savedPosition = configField.variantImagePositions?.[imgIndex]}
                                          {@const xPos = savedPosition?.x ?? defaultOffset}
                                          {@const yPos = savedPosition?.y ?? defaultOffset}
                                          <img 
                                            src={imgUrl} 
                                            alt="Variation {imgIndex + 1}" 
                                            on:mousedown={(e) => handleVariantImageMouseDown(e, field.id, imgIndex)}
                                            on:dblclick={(e) => handleElementDoubleClick(e, configField, field, 'image', assignedProduct)}
                                            style="
                                              position: absolute;
                                              width: 75%;
                                              height: 75%;
                                              object-fit: contain;
                                              z-index: {zIndex};
                                              left: {xPos}px;
                                              top: {yPos}px;
                                              opacity: 1;
                                              pointer-events: all;
                                              cursor: move;
                                            "
                                          />
                                        {/each}
                                      </div>
                                    {:else}
                                      <!-- Single product image -->
                                      <img 
                                        src={fieldValue} 
                                        alt="Product" 
                                        class="field-image-preview"
                                        on:dblclick={(e) => handleElementDoubleClick(e, configField, field, 'image', assignedProduct)}
                                        style="
                                          width: 100%;
                                          height: 100%;
                                          object-fit: contain;
                                          pointer-events: all;
                                          cursor: pointer;
                                        "
                                      />
                                    {/if}
                                  </div>
                                {:else if configField.label === 'special_symbol' && configField.symbolUrl}
                                  <!-- Special Symbol -->
                                  <img 
                                    src={configField.symbolUrl} 
                                    alt="Symbol" 
                                    class="field-symbol-preview"
                                    style="
                                      position: absolute;
                                      left: {configField.symbolX || 0}px;
                                      top: {configField.symbolY || 0}px;
                                      width: {configField.symbolWidth || 30}px;
                                      height: {configField.symbolHeight || 30}px;
                                      object-fit: contain;
                                    "
                                  />
                                {:else if configField.label !== 'special_symbol'}
                                  <!-- Text Field with Icon -->
                                  <div 
                                    class="element-wrapper"
                                    style="
                                      position: absolute;
                                      left: {configField.x || 0}px; 
                                      top: {configField.y || 0}px; 
                                      width: {configField.width || 100}px; 
                                      height: {configField.height || 20}px;
                                      transform: rotate({configField.rotation || 0}deg);
                                      transform-origin: center center;
                                    "
                                  >
                                    <div 
                                      class="field-text-preview"
                                      on:mousedown={(e) => handleTextMouseDown(e, configField, field)}
                                      on:dblclick={(e) => handleElementDoubleClick(e, configField, field, 'text')}
                                      style="
                                        width: 100%;
                                        height: 100%;
                                        pointer-events: all;
                                        cursor: move;
                                        font-size: {configField.fontSize || 14}px;
                                        color: {configField.color || '#000000'};
                                        text-align: {configField.alignment || 'left'};
                                        text-decoration: {configField.strikethrough ? 'line-through' : 'none'};
                                        font-weight: {configField.bold ? 'bold' : 'normal'};
                                        font-style: {configField.italic ? 'italic' : 'normal'};
                                        display: flex;
                                        align-items: center;
                                        justify-content: {configField.alignment === 'center' ? 'center' : configField.alignment === 'right' ? 'flex-end' : 'flex-start'};
                                        overflow: hidden;
                                      "
                                    >
                                      {#if configField.iconUrl}
                                        <img 
                                          src={configField.iconUrl} 
                                          alt="Icon" 
                                          class="field-icon-preview"
                                          style="
                                            position: absolute;
                                            left: {configField.iconX || 0}px;
                                            top: {configField.iconY || 0}px;
                                            width: {configField.iconWidth || 20}px;
                                            height: {configField.iconHeight || 20}px;
                                          "
                                        />
                                      {/if}
                                      {#if configField.label === 'price' || configField.label === 'offer_price'}
                                        <img 
                                          src="/icons/saudi-currency.png" 
                                          alt="Currency" 
                                          style="
                                            height: {(configField.fontSize || 14) * 0.65}px;
                                            width: auto;
                                            margin-right: 4px;
                                            vertical-align: baseline;
                                          "
                                        />
                                      {/if}
                                      {#if configField.label === 'offer_price'}
                                        {@const [integerPart, decimalPart] = fieldValue.split('.')}
                                        <span style="font-weight: 700;">
                                          {integerPart}<span style="font-size: 50%; vertical-align: baseline;">.{decimalPart || '00'}</span>
                                        </span>
                                      {:else if configField.label === 'price'}
                                        <span style="font-weight: 700; text-decoration: line-through;">
                                          {fieldValue}
                                        </span>
                                      {:else}
                                        <span style="font-weight: 400;">
                                          {fieldValue}
                                        </span>
                                      {/if}
                                    </div>
                                  </div>
                                {/if}
                              {/each}
                            </div>
                          {:else if assignedProduct}
                            <span class="field-product-name">{assignedProduct.product_name_en || assignedProduct.product_name_ar || 'Product'}</span>
                          {:else}
                            <span class="field-number-badge">#{field.number}</span>
                          {/if}
                          
                          {#if selectedFieldId === field.id}
                            <div class="resize-handle resize-se" on:mousedown={(e) => handleFieldMouseDown(e, field.id, 'se')}></div>
                            <div class="resize-handle resize-e" on:mousedown={(e) => handleFieldMouseDown(e, field.id, 'e')}></div>
                            <div class="resize-handle resize-s" on:mousedown={(e) => handleFieldMouseDown(e, field.id, 's')}></div>
                          {/if}
                        </div>
                      {/each}
                    {/if}
                  </div>
                {/if}
              </div>
            </div>
          {/if}
        </div>
        </div><!-- end preview-content-main -->
        </div><!-- end main-content-wrapper -->
      </div>
    {/if}
  {/if}
  
  <!-- Fields Popup Modal -->
  {#if showFieldsPopup}
    <div class="modal-overlay" on:click={closeFieldsPopup}>
      <div class="fields-popup-modal" on:click|stopPropagation>
        <div class="modal-header">
          <h3 class="modal-title">
            📋 {selectedPopupPageType === 'first' ? 'First Page' : `Sub Page ${selectedPopupPageIndex + 1}`} - Select Field
          </h3>
          <button class="modal-close" on:click={closeFieldsPopup}>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        
        <div class="fields-grid">
          {#if popupFields.length === 0}
            <div class="no-fields-message">
              <p>No fields available in this page</p>
            </div>
          {:else}
            {#each popupFields as field}
              {@const fieldKey = `${selectedPopupPageType}-${selectedPopupPageIndex}-${field.id}`}
              {@const assignedBarcode = fieldProductAssignments[fieldKey]}
              {@const assignedProduct = assignedBarcode ? productsData.find(p => p.barcode === assignedBarcode) : null}
              
              <button 
                class="field-card {assignedProduct ? 'has-product' : ''}"
                on:dblclick={() => selectFieldFromPopup(field)}
              >
                <div class="field-card-header">
                  <span class="field-number">Field #{field.number}</span>
                  {#if assignedProduct}
                    <span class="field-status assigned">✓ Assigned</span>
                  {:else}
                    <span class="field-status empty">Empty</span>
                  {/if}
                </div>
                
                <div class="field-card-info">
                  <p class="field-dimension">
                    📐 {field.width}×{field.height}px
                  </p>
                  <p class="field-position">
                    📍 ({field.x}, {field.y})
                  </p>
                </div>
                
                {#if assignedProduct}
                  <div class="field-card-product">
                    {#if assignedProduct.image_url}
                      <img src={assignedProduct.image_url} alt={assignedProduct.product_name_en} class="product-mini-thumb" />
                    {/if}
                    <p class="product-mini-name">{assignedProduct.product_name_en || assignedProduct.product_name_ar || 'Product'}</p>
                  </div>
                {/if}
                
                <p class="field-card-hint">Double-click to select product</p>
              </button>
            {/each}
          {/if}
        </div>
      </div>
    </div>
  {/if}
  
  <!-- Product Selector Modal -->
  {#if showProductSelector && selectedFieldForProduct}
    <div class="modal-overlay" on:click={() => showProductSelector = false}>
      <div class="modal-content" on:click|stopPropagation>
        <div class="modal-header">
          <h3 class="modal-title">
            Select Product for Field #{selectedFieldForProduct.number}
          </h3>
          <button class="modal-close" on:click={() => showProductSelector = false}>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        
        <div class="modal-body">
          {#if isLoadingProducts}
            <div class="flex items-center justify-center py-8">
              <svg class="animate-spin w-8 h-8 text-indigo-600" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            </div>
          {:else if productsData.length === 0}
            <div class="text-center py-8 text-gray-500">
              No products available in this offer
            </div>
          {:else}
            <div class="products-table-container">
              <table class="products-table">
                <thead>
                  <tr>
                    <th>Image</th>
                    <th>Barcode</th>
                    <th>Product Name (EN)</th>
                    <th>Product Name (AR)</th>
                    <th>Unit</th>
                    <th>Price</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each productsData as product}
                    {@const offerProduct = offerProducts.find(op => op.product_barcode === product.barcode)}
                    <tr>
                      <td>
                        {#if product.is_variation_group && product.variation_images && product.variation_images.length > 0}
                          <!-- Show stacked images for variation groups -->
                          <div class="product-thumb-stack">
                            {#each product.variation_images.slice(0, 2) as imgUrl, imgIndex}
                              <img 
                                src={imgUrl} 
                                alt="Variation {imgIndex + 1}" 
                                class="product-thumb-layered"
                                style="z-index: {2 - imgIndex}; left: {imgIndex * 3}px; top: {imgIndex * 3}px; opacity: {imgIndex === 0 ? 1 : 0.7};"
                              />
                            {/each}
                          </div>
                        {:else if product.image_url}
                          <img src={product.image_url} alt={product.product_name_en} class="product-thumb" />
                        {:else}
                          <div class="product-thumb-placeholder">📦</div>
                        {/if}
                      </td>
                      <td class="font-mono text-sm">{product.barcode}</td>
                      <td>
                        {product.product_name_en || '-'}
                        {#if product.is_variation_group}
                          <span class="variation-badge" title="{product.variation_count} variations">
                            🔗 Group ({product.variation_count})
                          </span>
                        {/if}
                      </td>
                      <td class="text-right">
                        {product.product_name_ar || '-'}
                        {#if product.is_variation_group}
                          <span class="variation-badge-ar" title="{product.variation_count} منتجات">
                            مجموعة ({product.variation_count})
                          </span>
                        {/if}
                      </td>
                      <td>{product.unit_name || '-'}</td>
                      <td>
                        {#if offerProduct?.offer_price}
                          <div class="price-info">
                            <span class="offer-price">${offerProduct.offer_price}</span>
                            {#if offerProduct.sales_price && offerProduct.sales_price !== offerProduct.offer_price}
                              <span class="original-price">${offerProduct.sales_price}</span>
                            {/if}
                          </div>
                        {:else}
                          ${product.sales_price || '0.00'}
                        {/if}
                      </td>
                      <td>
                        <button
                          class="select-product-btn"
                          on:click={() => assignProductToField(product.barcode)}
                        >
                          Select
                        </button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>
      </div>
    </div>
  {/if}
  
  <!-- Action Menu for Images and Text -->
  {#if showActionMenu}
    <div class="action-menu-overlay" on:click={closeActionMenu}>
      <div 
        class="action-menu" 
        style="left: {actionMenuX}px; top: {actionMenuY}px;"
        on:click|stopPropagation
      >
        <div 
          class="action-menu-header" 
          on:mousedown={startMenuDrag}
        >
          <h4 class="action-menu-title">
            {elementType === 'image' ? '🖼️ Image Actions' : '📝 Text Actions'}
          </h4>
          <span class="drag-indicator">⋮⋮</span>
        </div>
        
        {#if isVariationGroup && elementType === 'image'}
          <div class="action-section variant-selector">
            <p class="action-label">Select Variant Image:</p>
            <div class="variant-buttons-row">
              {#each selectedElement?.assignedProduct?.variation_images?.slice(0, 3) || [] as imgUrl, idx}
                <button 
                  class="variant-img-btn {selectedVariantImageIndex === idx ? 'active' : ''}" 
                  on:click={() => selectedVariantImageIndex = idx}
                >
                  <img src={imgUrl} alt="Variant {idx + 1}" />
                  <span class="variant-label">Image {idx + 1}</span>
                </button>
              {/each}
            </div>
          </div>
        {/if}
        
        <div class="action-section">
          <p class="action-label">Actions:</p>
          <div class="action-buttons-row">
            {#if elementType === 'image'}
              <button class="action-btn-large" on:click={startElementMove}>
                <span class="action-icon">↔️</span>
                Move
              </button>
            {/if}
            <button class="action-btn-large" on:click={startElementResize}>
              <span class="action-icon">↗️</span>
              Resize
            </button>
          </div>
        </div>
        
        <div class="action-section">
          <p class="action-label">Rotate: {elementRotation}°</p>
          <div class="action-buttons-row">
            <button class="action-btn-text" on:click={() => rotateElement(-90)}>↶ -90°</button>
            <button class="action-btn-text" on:click={() => rotateElement(-15)}>↶ -15°</button>
            <button class="action-btn-text" on:click={() => rotateElement(-5)}>↶ -5°</button>
            <button class="action-btn-text" on:click={() => rotateElement(-1)}>↶ -1°</button>
          </div>
          <div class="action-buttons-row" style="margin-top: 0.5rem;">
            <button class="action-btn-text" on:click={() => rotateElement(1)}>↷ +1°</button>
            <button class="action-btn-text" on:click={() => rotateElement(5)}>↷ +5°</button>
            <button class="action-btn-text" on:click={() => rotateElement(15)}>↷ +15°</button>
            <button class="action-btn-text" on:click={() => rotateElement(90)}>↷ +90°</button>
          </div>
          <div style="margin-top: 0.75rem;">
            <input 
              type="range" 
              min="-180" 
              max="180" 
              bind:value={elementRotation}
              on:input={() => {
                if (selectedElement) {
                  selectedElement.configField.rotation = elementRotation;
                  flyerTemplates = [...flyerTemplates];
                }
              }}
              style="width: 100%;"
            />
          </div>
        </div>
        
        {#if elementType === 'text'}
          <div class="action-section">
            <p class="action-label">Font Size:</p>
            <div class="action-buttons-row">
              <button class="action-btn-text" on:click={() => applyFontSize(-2)}>-2</button>
              <button class="action-btn-text" on:click={() => applyFontSize(-1)}>-1</button>
              <button class="action-btn-text" on:click={() => applyFontSize(1)}>+1</button>
              <button class="action-btn-text" on:click={() => applyFontSize(2)}>+2</button>
            </div>
          </div>
        {/if}
        
        <button class="action-close-btn" on:click={closeActionMenu}>Close</button>
      </div>
    </div>
  {/if}

  <!-- Text Scale Controls -->
  {#if showTextControls}
    <div class="text-controls-overlay" on:click={closeTextControls}>
      <div 
        class="text-controls" 
        style="left: {textControlsX}px; top: {textControlsY}px;"
        on:click|stopPropagation
      >
        <div class="text-control-section">
          <p class="text-control-label">Width/Height</p>
          <div class="text-control-buttons">
            <button class="text-control-btn" on:click={() => applyTextScale(-10)}>-10</button>
            <button class="text-control-btn" on:click={() => applyTextScale(-5)}>-5</button>
            <button class="text-control-btn" on:click={() => applyTextScale(5)}>+5</button>
            <button class="text-control-btn" on:click={() => applyTextScale(10)}>+10</button>
          </div>
        </div>
        
        <div class="text-control-section">
          <p class="text-control-label">Font Size</p>
          <div class="text-control-buttons">
            <button class="text-control-btn" on:click={() => applyTextFontSize(-2)}>-2</button>
            <button class="text-control-btn" on:click={() => applyTextFontSize(-1)}>-1</button>
            <button class="text-control-btn" on:click={() => applyTextFontSize(1)}>+1</button>
            <button class="text-control-btn" on:click={() => applyTextFontSize(2)}>+2</button>
          </div>
        </div>
        
        <div class="text-control-section">
          <p class="text-control-label">Rotation: {selectedTextElement?.configField?.rotation || 0}°</p>
          <div class="text-control-buttons">
            <button class="text-control-btn" on:click={() => applyTextRotation(-90)}>↶ -90°</button>
            <button class="text-control-btn" on:click={() => applyTextRotation(-15)}>↶ -15°</button>
            <button class="text-control-btn" on:click={() => applyTextRotation(15)}>↷ +15°</button>
            <button class="text-control-btn" on:click={() => applyTextRotation(90)}>↷ +90°</button>
          </div>
          <div class="text-control-buttons" style="margin-top: 0.25rem;">
            <button class="text-control-btn" on:click={() => applyTextRotation(-5)}>↶ -5°</button>
            <button class="text-control-btn" on:click={() => applyTextRotation(-1)}>↶ -1°</button>
            <button class="text-control-btn" on:click={() => applyTextRotation(1)}>↷ +1°</button>
            <button class="text-control-btn" on:click={() => applyTextRotation(5)}>↷ +5°</button>
          </div>
          <div style="margin-top: 0.5rem;">
            <input 
              type="range" 
              min="-180" 
              max="180" 
              value={selectedTextElement?.configField?.rotation || 0}
              on:input={(e) => {
                if (selectedTextElement) {
                  selectedTextElement.configField.rotation = parseInt(e.target.value);
                  flyerTemplates = [...flyerTemplates];
                }
              }}
              style="width: 100%;"
            />
          </div>
        </div>
        
        <button class="text-control-close" on:click={closeTextControls}>✓</button>
      </div>
    </div>
  {/if}
</div>

<style>
  .tabs-header {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1rem;
    border-bottom: 2px solid #e5e7eb;
  }

  .tab-btn {
    padding: 0.75rem 1.5rem;
    background: none;
    border: none;
    border-bottom: 3px solid transparent;
    font-weight: 600;
    color: #6b7280;
    cursor: pointer;
    transition: all 0.2s;
    margin-bottom: -2px;
  }

  .tab-btn:hover {
    color: #3b82f6;
  }

  .tab-btn.active {
    color: #3b82f6;
    border-bottom-color: #3b82f6;
  }

  .preview-content {
    flex: 1;
    display: flex;
    flex-direction: column;
  }

  .preview-section {
    display: flex;
    flex-direction: column;
  }

  .preview-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid #e5e7eb;
  }

  .preview-title {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
  }

  .preview-badge {
    padding: 0.25rem 0.75rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: 600;
    box-shadow: 0 2px 4px rgba(16, 185, 129, 0.2);
  }

  .sub-page-tabs {
    display: flex;
    gap: 0.25rem;
  }

  .sub-page-tab-btn {
    padding: 0.375rem 0.75rem;
    background: #f3f4f6;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    font-size: 0.75rem;
    font-weight: 600;
    color: #6b7280;
    cursor: pointer;
    transition: all 0.2s;
  }

  .sub-page-tab-btn:hover {
    background: #e5e7eb;
    color: #3b82f6;
  }

  .sub-page-tab-btn.active {
    background: #3b82f6;
    color: white;
    border-color: #3b82f6;
  }

  .preview-container {
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    overflow: auto;
    background: #f9fafb;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding: 1rem;
    min-height: 1200px;
    max-height: none;
  }

  .preview-wrapper {
    position: relative;
    width: 794px;
    height: 1123px;
    flex-shrink: 0;
  }

  .preview-image {
    display: block;
    width: 794px !important;
    height: 1123px !important;
    min-width: 794px;
    min-height: 1123px;
    max-width: 794px;
    max-height: 1123px;
    object-fit: fill;
    border-radius: 4px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    pointer-events: none;
    position: relative;
    z-index: 1;
  }

  .product-field {
    position: absolute;
    border: 3px solid #3b82f6;
    background: rgba(59, 130, 246, 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
    box-sizing: border-box;
    z-index: 10;
    cursor: move;
    transition: all 0.2s;
  }

  .product-field:hover {
    background: rgba(59, 130, 246, 0.2);
    border-color: #2563eb;
  }

  .product-field.selected {
    border-color: #1d4ed8;
    background: rgba(29, 78, 216, 0.2);
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
  }

  .product-field.has-product {
    border-color: #10b981;
    background: rgba(16, 185, 129, 0.1);
  }

  .product-field.has-product:hover {
    background: rgba(16, 185, 129, 0.2);
    border-color: #059669;
  }

  .product-field.has-product.selected {
    border-color: #047857;
    background: rgba(4, 120, 87, 0.2);
    box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.3);
  }

  .resize-handle {
    position: absolute;
    background: #3b82f6;
    border: 2px solid white;
    z-index: 20;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  .resize-se {
    right: -6px;
    bottom: -6px;
    width: 16px;
    height: 16px;
    cursor: se-resize;
    border-radius: 2px;
  }

  .resize-e {
    right: -6px;
    top: 50%;
    transform: translateY(-50%);
    width: 12px;
    height: 32px;
    cursor: e-resize;
    border-radius: 2px;
  }

  .resize-s {
    bottom: -6px;
    left: 50%;
    transform: translateX(-50%);
    width: 32px;
    height: 12px;
    cursor: s-resize;
    border-radius: 2px;
  }

  .field-number-badge {
    font-size: 1.5rem;
    font-weight: 900;
    color: #3b82f6;
    background: white;
    padding: 0.5rem 1rem;
    border-radius: 8px;
    pointer-events: none;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .field-product-name {
    font-size: 0.75rem;
    font-weight: 700;
    color: #10b981;
    background: white;
    padding: 0.5rem;
    border-radius: 6px;
    pointer-events: none;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    text-align: center;
    max-width: 90%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .field-preview-content {
    position: relative;
    width: 100%;
    height: 100%;
    pointer-events: none;
  }

  .field-text-preview {
    position: absolute;
    pointer-events: none;
    line-height: 1.2;
    user-select: none;
    white-space: pre-line;
    text-align: center;
  }

  .field-image-preview {
    position: absolute;
    pointer-events: none;
    user-select: none;
  }

  .element-wrapper {
    position: relative;
    pointer-events: none;
  }

  /* Action Menu */
  .action-menu-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.3);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .action-menu {
    position: fixed;
    background: white;
    border-radius: 12px;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.3);
    min-width: 280px;
    z-index: 1001;
    padding: 0;
  }

  .action-menu-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.25rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    border-radius: 12px 12px 0 0;
    cursor: move;
    user-select: none;
  }

  .action-menu-header:active {
    cursor: grabbing;
  }

  .action-menu-title {
    font-size: 1.125rem;
    font-weight: 700;
    color: white;
    margin: 0;
    border: none;
    padding: 0;
  }

  .drag-indicator {
    color: rgba(255, 255, 255, 0.7);
    font-size: 1.25rem;
    letter-spacing: -2px;
  }

  .action-section {
    margin-bottom: 1rem;
    padding: 0 1.25rem;
  }

  .action-section:first-of-type {
    margin-top: 1.25rem;
  }

  .action-label {
    font-size: 0.875rem;
    font-weight: 600;
    color: #6b7280;
    margin-bottom: 0.5rem;
  }

  .action-buttons-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 0.5rem;
  }

  .action-buttons-row {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .action-btn {
    padding: 0.75rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1.25rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
  }

  .action-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 6px rgba(59, 130, 246, 0.3);
  }

  .action-btn:active {
    transform: translateY(0);
  }

  .action-btn-text {
    padding: 0.5rem 1rem;
    background: #f3f4f6;
    color: #374151;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    flex: 1;
    min-width: 60px;
  }

  .action-btn-text:hover {
    background: #3b82f6;
    color: white;
    border-color: #3b82f6;
  }

  .action-btn-large {
    padding: 0.75rem 1rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
  }

  .action-btn-large:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
  }

  .action-icon {
    font-size: 1.5rem;
  }

  .action-close-btn {
    width: calc(100% - 2.5rem);
    margin: 0 1.25rem 1.25rem 1.25rem;
    padding: 0.75rem;
    background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(220, 38, 38, 0.2);
  }

  .action-close-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(220, 38, 38, 0.3);
  }

  /* Variant Image Selector */
  .variant-selector {
    border-bottom: 2px solid #e5e7eb;
    padding-bottom: 1rem;
  }

  .variant-buttons-row {
    display: flex;
    gap: 0.75rem;
    justify-content: center;
  }

  .variant-img-btn {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem;
    background: #f3f4f6;
    border: 3px solid #e5e7eb;
    border-radius: 12px;
    cursor: pointer;
    transition: all 0.2s;
    flex: 1;
    max-width: 80px;
  }

  .variant-img-btn:hover {
    border-color: #3b82f6;
    background: #eff6ff;
    transform: translateY(-2px);
  }

  .variant-img-btn.active {
    border-color: #3b82f6;
    background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
    box-shadow: 0 4px 6px rgba(59, 130, 246, 0.2);
  }

  .variant-img-btn img {
    width: 50px;
    height: 50px;
    object-fit: contain;
    border-radius: 6px;
  }

  .variant-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: #374151;
  }

  .variant-img-btn.active .variant-label {
    color: #1e40af;
  }

  /* Text Controls Styles */
  .text-controls-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 10000;
  }

  .text-controls {
    position: fixed;
    background: white;
    border-radius: 8px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
    padding: 0.75rem;
    z-index: 10001;
    min-width: 200px;
  }

  .text-control-section {
    margin-bottom: 0.75rem;
  }

  .text-control-section:last-of-type {
    margin-bottom: 0.5rem;
  }

  .text-control-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: #6b7280;
    margin: 0 0 0.5rem 0;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .text-control-buttons {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 0.25rem;
  }

  .text-control-btn {
    padding: 0.5rem;
    background: #f3f4f6;
    color: #374151;
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }

  .text-control-btn:hover {
    background: #3b82f6;
    color: white;
    border-color: #3b82f6;
  }

  .text-control-close {
    width: 100%;
    padding: 0.5rem;
    background: #10b981;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }

  .text-control-close:hover {
    background: #059669;
  }

  /* Main Content Wrapper with Sidebar */
  .main-content-wrapper {
    display: flex;
    gap: 1.5rem;
    margin-top: 1rem;
  }

  /* Page Selector Sidebar */
  .page-selector-sidebar {
    width: 220px;
    flex-shrink: 0;
    background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
    border-radius: 12px;
    padding: 1rem;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    max-height: 800px;
    overflow-y: auto;
  }

  .sidebar-title {
    font-size: 1rem;
    font-weight: 700;
    color: #1f2937;
    margin-bottom: 1rem;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid #cbd5e1;
  }

  .page-selector-btn {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.875rem;
    background: white;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s;
    margin-bottom: 0.75rem;
    text-align: left;
  }

  .page-selector-btn:hover {
    border-color: #3b82f6;
    box-shadow: 0 4px 6px rgba(59, 130, 246, 0.2);
    transform: translateY(-2px);
  }

  .page-selector-btn.first-page {
    background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
    border-color: #3b82f6;
  }

  .page-icon {
    font-size: 1.5rem;
    flex-shrink: 0;
  }

  .page-info {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    flex: 1;
  }

  .page-name {
    font-weight: 600;
    color: #1f2937;
    font-size: 0.875rem;
  }

  .page-fields {
    font-size: 0.75rem;
    color: #6b7280;
  }

  .sub-pages-section {
    margin-top: 1rem;
  }

  .sub-pages-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
    margin-bottom: 0.5rem;
    letter-spacing: 0.5px;
  }

  .preview-content-main {
    flex: 1;
    min-width: 0;
  }

  /* Fields Popup Modal */
  .fields-popup-modal {
    background: white;
    border-radius: 16px;
    padding: 0;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.3);
    max-width: 900px;
    width: 90vw;
    max-height: 85vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .fields-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
    padding: 1.5rem;
    overflow-y: auto;
    max-height: calc(85vh - 80px);
  }

  .no-fields-message {
    grid-column: 1 / -1;
    text-align: center;
    padding: 3rem;
    color: #9ca3af;
    font-size: 1rem;
  }

  .field-card {
    background: linear-gradient(135deg, #ffffff 0%, #f9fafb 100%);
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    padding: 1rem;
    cursor: pointer;
    transition: all 0.3s;
    text-align: left;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .field-card:hover {
    border-color: #3b82f6;
    box-shadow: 0 8px 16px rgba(59, 130, 246, 0.2);
    transform: translateY(-4px);
  }

  .field-card.has-product {
    border-color: #10b981;
    background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
  }

  .field-card.has-product:hover {
    border-color: #059669;
    box-shadow: 0 8px 16px rgba(16, 185, 129, 0.3);
  }

  .field-card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .field-number {
    font-weight: 700;
    color: #1f2937;
    font-size: 0.875rem;
  }

  .field-status {
    font-size: 0.75rem;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-weight: 600;
  }

  .field-status.assigned {
    background: #10b981;
    color: white;
  }

  .field-status.empty {
    background: #e5e7eb;
    color: #6b7280;
  }

  .field-card-info {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .field-dimension,
  .field-position {
    font-size: 0.75rem;
    color: #6b7280;
    margin: 0;
  }

  .field-card-product {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem;
    background: white;
    border-radius: 6px;
    margin-top: 0.25rem;
  }

  .product-mini-thumb {
    width: 40px;
    height: 40px;
    object-fit: contain;
    border-radius: 4px;
  }

  .product-mini-name {
    font-size: 0.75rem;
    color: #374151;
    font-weight: 500;
    margin: 0;
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .field-card-hint {
    font-size: 0.7rem;
    color: #9ca3af;
    text-align: center;
    margin: 0;
    padding-top: 0.5rem;
    border-top: 1px solid #e5e7eb;
  }

  .field-symbol-preview {
    position: absolute;
    pointer-events: none;
  }

  .field-icon-preview {
    position: absolute;
    pointer-events: none;
  }

  /* Modal Styles */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 2rem;
  }

  .modal-content {
    background: white;
    border-radius: 12px;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
    max-width: 1200px;
    width: 100%;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.5rem;
    border-bottom: 2px solid #e5e7eb;
  }

  .modal-title {
    font-size: 1.25rem;
    font-weight: 700;
    color: #1f2937;
  }

  .modal-close {
    background: none;
    border: none;
    color: #6b7280;
    cursor: pointer;
    padding: 0.5rem;
    border-radius: 6px;
    transition: all 0.2s;
  }

  .modal-close:hover {
    background: #f3f4f6;
    color: #1f2937;
  }

  .modal-body {
    padding: 1.5rem;
    overflow-y: auto;
    flex: 1;
  }

  .products-table-container {
    overflow-x: auto;
  }

  .products-table {
    width: 100%;
    border-collapse: collapse;
  }

  .products-table thead {
    background: #f9fafb;
    border-bottom: 2px solid #e5e7eb;
  }

  .products-table th {
    padding: 0.75rem 1rem;
    text-align: left;
    font-size: 0.875rem;
    font-weight: 600;
    color: #374151;
    white-space: nowrap;
  }

  .products-table tbody tr {
    border-bottom: 1px solid #e5e7eb;
    transition: background 0.2s;
  }

  .products-table tbody tr:hover {
    background: #f9fafb;
  }

  .products-table td {
    padding: 0.75rem 1rem;
    font-size: 0.875rem;
    color: #1f2937;
  }

  .product-thumb {
    width: 50px;
    height: 50px;
    object-fit: cover;
    border-radius: 6px;
    border: 1px solid #e5e7eb;
  }

  .product-thumb-placeholder {
    width: 50px;
    height: 50px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f3f4f6;
    border-radius: 6px;
    font-size: 1.5rem;
  }

  /* Variation group thumbnail stack */
  .product-thumb-stack {
    position: relative;
    width: 56px;
    height: 56px;
  }

  .product-thumb-layered {
    position: absolute;
    width: 45px;
    height: 45px;
    object-fit: cover;
    border-radius: 6px;
    border: 2px solid #e5e7eb;
    background: white;
  }

  /* Variation group badges */
  .variation-badge {
    display: inline-block;
    margin-left: 0.5rem;
    padding: 0.125rem 0.5rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border-radius: 12px;
    font-size: 0.65rem;
    font-weight: 600;
    vertical-align: middle;
  }

  .variation-badge-ar {
    display: inline-block;
    margin-right: 0.5rem;
    padding: 0.125rem 0.5rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border-radius: 12px;
    font-size: 0.65rem;
    font-weight: 600;
    vertical-align: middle;
    direction: rtl;
  }

  .price-info {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .offer-price {
    font-weight: 700;
    color: #10b981;
    font-size: 1rem;
  }

  .original-price {
    font-size: 0.75rem;
    color: #9ca3af;
    text-decoration: line-through;
  }

  .select-product-btn {
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
  }

  .select-product-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 6px rgba(59, 130, 246, 0.3);
  }
</style>