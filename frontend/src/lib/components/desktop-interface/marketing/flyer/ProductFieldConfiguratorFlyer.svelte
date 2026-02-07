<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  
  export let field: any;
  export let onSave: (fields: any[]) => void;
  
  const dispatch = createEventDispatcher();
  
  interface FieldSelector {
    id: string;
    label: string;
    x: number;
    y: number;
    width: number;
    height: number;
    fontSize: number;
    fontFamily: string;
    alignment: 'left' | 'center' | 'right';
    color: string;
    iconUrl?: string;
    iconWidth?: number;
    iconHeight?: number;
    iconX?: number;
    iconY?: number;
    symbolUrl?: string;
    symbolWidth?: number;
    symbolHeight?: number;
    symbolX?: number;
    symbolY?: number;
  }
  
  let fieldSelectors: FieldSelector[] = field.fields || [];
  let selectedFieldId: string | null = null;
  let nextFieldId = 1;
  let isDragging = false;
  let dragStartX = 0;
  let dragStartY = 0;
  let isResizing = false;
  let resizeHandle = '';
  let previewContainer: HTMLElement | null = null;
  let iconUploadFieldId: string | null = null;
  
  // Auto-scale: ensure the preview is always big enough to configure
  const MIN_PREVIEW_SIZE = 1000;
  $: previewScale = Math.max(1, Math.min(
    MIN_PREVIEW_SIZE / (field.width || 150),
    MIN_PREVIEW_SIZE / (field.height || 150)
  ));
  $: scaledWidth = field.width * previewScale;
  $: scaledHeight = field.height * previewScale;
  let fileInput: HTMLInputElement;
  
  let isDraggingIcon = false;
  let isResizingIcon = false;
  let iconResizeDirection = '';
  let iconDragStartX = 0;
  let iconDragStartY = 0;
  let iconDragStartIconX = 0;
  let iconDragStartIconY = 0;
  let iconResizeStartX = 0;
  let iconResizeStartY = 0;
  let iconResizeStartWidth = 0;
  let iconResizeStartHeight = 0;
  let selectedIconFieldId: string | null = null;
  
  let isDraggingSymbol = false;
  let isResizingSymbol = false;
  let symbolResizeDirection = '';
  let symbolDragStartX = 0;
  let symbolDragStartY = 0;
  let symbolDragStartSymbolX = 0;
  let symbolDragStartSymbolY = 0;
  let symbolResizeStartX = 0;
  let symbolResizeStartY = 0;
  let symbolResizeStartWidth = 0;
  let symbolResizeStartHeight = 0;
  let selectedSymbolFieldId: string | null = null;
  
  // Custom Fonts
  interface CustomFont {
    id: string;
    name: string;
    font_url: string;
    file_name: string | null;
    file_size: number | null;
    created_at: string;
  }
  
  let customFonts: CustomFont[] = [];
  let isUploadingFont = false;
  let fontFileInput: HTMLInputElement;
  
  onMount(() => {
    loadCustomFonts();
  });
  
  async function loadCustomFonts() {
    try {
      const { data, error } = await supabase
        .from('shelf_paper_fonts')
        .select('*')
        .order('name', { ascending: true });
      
      if (error) throw error;
      customFonts = data || [];
      
      for (const font of customFonts) {
        try {
          const fontFace = new FontFace(font.name, `url(${font.font_url})`);
          await fontFace.load();
          document.fonts.add(fontFace);
        } catch (e) {
          console.warn(`Failed to load font: ${font.name}`, e);
        }
      }
    } catch (error) {
      console.error('Error loading custom fonts:', error);
    }
  }
  
  async function handleFontUpload(event: Event) {
    const target = event.target as HTMLInputElement;
    const files = target.files;
    if (!files || files.length === 0) return;
    
    isUploadingFont = true;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      for (const file of files) {
        const fontName = file.name.replace(/\.(ttf|otf|woff|woff2)$/i, '');
        const fileName = `${Date.now()}-${file.name}`;
        
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('custom-fonts')
          .upload(fileName, file, { contentType: file.type, upsert: false });
        
        if (uploadError) throw uploadError;
        
        const { data: { publicUrl } } = supabase.storage
          .from('custom-fonts')
          .getPublicUrl(uploadData.path);
        
        await supabase.from('shelf_paper_fonts').insert({
          name: fontName,
          font_url: publicUrl,
          file_name: fileName,
          file_size: file.size,
          created_by: user?.id
        });
        
        const fontFace = new FontFace(fontName, `url(${publicUrl})`);
        await fontFace.load();
        document.fonts.add(fontFace);
      }
      
      await loadCustomFonts();
    } catch (error) {
      console.error('Error uploading font:', error);
      alert('❌ Failed to upload font: ' + error.message);
    } finally {
      isUploadingFont = false;
      target.value = '';
    }
  }
  
  const availableFields = [
    { value: 'product_name_en', label: 'Product Name (EN)' },
    { value: 'product_name_ar', label: 'Product Name (AR)' },
    { value: 'unit_name', label: 'Unit Name' },
    { value: 'price', label: 'Price' },
    { value: 'offer_price', label: 'Offer Price' },
    { value: 'offer_qty', label: 'Offer Quantity' },
    { value: 'limit_qty', label: 'Limit Quantity' },
    { value: 'free_qty', label: 'Free Quantity' },
    { value: 'image', label: 'Product Image' },
    { value: 'special_symbol', label: '🎨 Special Symbol (Image)' }
  ];
  
  function addFieldSelector() {
    // Calculate position to avoid overlapping with existing fields
    let newX = 10;
    let newY = 10;
    const fieldWidth = Math.min(200, field.width - 20);
    const fieldHeight = 40;
    
    // Ensure unique ID by checking existing field IDs
    const existingIds = fieldSelectors.map(f => {
      const match = f.id.match(/subfield-(\d+)/);
      return match ? parseInt(match[1]) : 0;
    });
    const maxId = existingIds.length > 0 ? Math.max(...existingIds) : 0;
    const newId = maxId + 1;
    
    // Find the lowest Y position of existing fields and offset the new one
    if (fieldSelectors.length > 0) {
      const lowestField = fieldSelectors.reduce((lowest, f) => 
        (f.y + f.height) > (lowest.y + lowest.height) ? f : lowest
      );
      newY = Math.min(lowestField.y + lowestField.height + 20, field.height - fieldHeight - 10);
      newY = Math.max(newY, 10); // Ensure minimum padding
    }
    
    const newField: FieldSelector = {
      id: `subfield-${newId}`,
      label: 'product_name_en',
      x: newX,
      y: newY,
      width: fieldWidth,
      height: fieldHeight,
      fontSize: 16,
      fontFamily: '',
      alignment: 'left',
      color: '#000000',
      iconUrl: undefined,
      iconWidth: 50,
      iconHeight: 50,
      iconX: 0,
      iconY: 0
    };
    fieldSelectors = [...fieldSelectors, newField];
  }
  
  function handleIconUpload(event: Event, fieldId: string) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];
    
    if (file && file.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const iconUrl = e.target?.result as string;
        const fieldItem = fieldSelectors.find(f => f.id === fieldId);
        updateField(fieldId, { 
          iconUrl,
          iconWidth: fieldItem?.iconWidth || 50,
          iconHeight: fieldItem?.iconHeight || 50,
          iconX: fieldItem?.iconX || 0,
          iconY: fieldItem?.iconY || 0
        });
      };
      reader.readAsDataURL(file);
    }
  }
  
  function removeIcon(fieldId: string) {
    updateField(fieldId, { iconUrl: undefined });
  }
  
  function triggerIconUpload(fieldId: string) {
    iconUploadFieldId = fieldId;
    fileInput.click();
  }
  
  let symbolUploadFieldId: string | null = null;
  let symbolFileInput: HTMLInputElement;
  
  function triggerSymbolUpload(fieldId: string) {
    symbolUploadFieldId = fieldId;
    symbolFileInput.click();
  }
  
  function handleSymbolUpload(event: Event, fieldId: string) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];
    
    if (file && file.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const symbolUrl = e.target?.result as string;
        updateField(fieldId, { 
          symbolUrl,
          symbolWidth: 50,
          symbolHeight: 50,
          symbolX: 0,
          symbolY: 0
        });
      };
      reader.readAsDataURL(file);
    }
  }
  
  function removeSymbol(fieldId: string) {
    updateField(fieldId, { 
      symbolUrl: undefined,
      symbolWidth: undefined,
      symbolHeight: undefined
    });
  }
  
  function selectField(fieldId: string) {
    selectedFieldId = fieldId;
  }
  
  function updateField(fieldId: string, updates: Partial<FieldSelector>) {
    fieldSelectors = fieldSelectors.map(f => 
      f.id === fieldId ? { ...f, ...updates } : f
    );
  }
  
  function deleteField(fieldId: string) {
    fieldSelectors = fieldSelectors.filter(f => f.id !== fieldId);
    if (selectedFieldId === fieldId) {
      selectedFieldId = null;
    }
  }

  function handleMouseDown(event: MouseEvent, fieldId: string, handle?: string) {
    event.preventDefault();
    event.stopPropagation();
    
    selectedFieldId = fieldId;
    dragStartX = event.clientX;
    dragStartY = event.clientY;
    
    if (handle) {
      isResizing = true;
      resizeHandle = handle;
    } else {
      isDragging = true;
    }
    
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
  }
  
  function handleMouseMove(event: MouseEvent) {
    if (!selectedFieldId) return;
    
    const deltaX = (event.clientX - dragStartX) / previewScale;
    const deltaY = (event.clientY - dragStartY) / previewScale;
    
    const fieldItem = fieldSelectors.find(f => f.id === selectedFieldId);
    if (!fieldItem) return;
    
    if (isDragging) {
      // Allow free movement with no snapping
      let newX = fieldItem.x + deltaX;
      let newY = fieldItem.y + deltaY;
      
      // Only enforce boundary constraints, no snapping to other fields
      newX = Math.max(0, Math.min(field.width - fieldItem.width, newX));
      newY = Math.max(0, Math.min(field.height - fieldItem.height, newY));
      
      updateField(selectedFieldId, {
        x: newX,
        y: newY
      });
    } else if (isResizing) {
      if (resizeHandle === 'se') {
        const newWidth = Math.max(50, fieldItem.width + deltaX);
        const newHeight = Math.max(30, fieldItem.height + deltaY);
        const updates: any = {
          width: newWidth,
          height: newHeight
        };
        // If special_symbol, also update symbol size
        if (fieldItem.label === 'special_symbol') {
          updates.symbolWidth = newWidth;
          updates.symbolHeight = newHeight;
        }
        updateField(selectedFieldId, updates);
      } else if (resizeHandle === 'e') {
        const newWidth = Math.max(50, fieldItem.width + deltaX);
        const updates: any = {
          width: newWidth
        };
        // If special_symbol, also update symbol width
        if (fieldItem.label === 'special_symbol') {
          updates.symbolWidth = newWidth;
        }
        updateField(selectedFieldId, updates);
      } else if (resizeHandle === 's') {
        const newHeight = Math.max(30, fieldItem.height + deltaY);
        const updates: any = {
          height: newHeight
        };
        // If special_symbol, also update symbol height
        if (fieldItem.label === 'special_symbol') {
          updates.symbolHeight = newHeight;
        }
        updateField(selectedFieldId, updates);
      }
    }
    
    dragStartX = event.clientX;
    dragStartY = event.clientY;
  }
  
  function handleMouseUp() {
    isDragging = false;
    isResizing = false;
    resizeHandle = '';
    isDraggingIcon = false;
    isResizingIcon = false;
    iconResizeDirection = '';
    isDraggingSymbol = false;
    isResizingSymbol = false;
    symbolResizeDirection = '';
    window.removeEventListener('mousemove', handleMouseMove);
    window.removeEventListener('mouseup', handleMouseUp);
    window.removeEventListener('mousemove', handleIconMouseMove);
    window.removeEventListener('mouseup', handleIconMouseUp);
    window.removeEventListener('mousemove', handleSymbolMouseMove);
    window.removeEventListener('mouseup', handleSymbolMouseUp);
  }

  function handleIconMouseDown(event: MouseEvent, fieldId: string) {
    event.stopPropagation();
    selectedIconFieldId = fieldId;
    selectedFieldId = null;
    isDraggingIcon = true;
    iconDragStartX = event.clientX;
    iconDragStartY = event.clientY;
    
    const fieldItem = fieldSelectors.find(f => f.id === fieldId);
    if (fieldItem) {
      iconDragStartIconX = fieldItem.iconX || 0;
      iconDragStartIconY = fieldItem.iconY || 0;
    }
    
    window.addEventListener('mousemove', handleIconMouseMove);
    window.addEventListener('mouseup', handleIconMouseUp);
  }

  function handleIconResizeMouseDown(event: MouseEvent, fieldId: string, direction: string) {
    event.stopPropagation();
    selectedIconFieldId = fieldId;
    isResizingIcon = true;
    iconResizeDirection = direction;
    iconResizeStartX = event.clientX;
    iconResizeStartY = event.clientY;
    
    const fieldItem = fieldSelectors.find(f => f.id === fieldId);
    if (fieldItem) {
      iconResizeStartWidth = fieldItem.iconWidth || 50;
      iconResizeStartHeight = fieldItem.iconHeight || 50;
    }
    
    window.addEventListener('mousemove', handleIconMouseMove);
    window.addEventListener('mouseup', handleIconMouseUp);
  }

  function handleIconMouseMove(event: MouseEvent) {
    if (!selectedIconFieldId) return;
    
    const fieldItem = fieldSelectors.find(f => f.id === selectedIconFieldId);
    if (!fieldItem) return;
    
    if (isDraggingIcon) {
      const deltaX = (event.clientX - iconDragStartX) / previewScale;
      const deltaY = (event.clientY - iconDragStartY) / previewScale;
      
      const newIconX = iconDragStartIconX + deltaX;
      const newIconY = iconDragStartIconY + deltaY;
      
      updateField(selectedIconFieldId, {
        iconX: newIconX,
        iconY: newIconY
      });
    } else if (isResizingIcon) {
      const deltaX = (event.clientX - iconResizeStartX) / previewScale;
      const deltaY = (event.clientY - iconResizeStartY) / previewScale;
      
      if (iconResizeDirection === 'se') {
        const newWidth = Math.max(20, iconResizeStartWidth + deltaX);
        const newHeight = Math.max(20, iconResizeStartHeight + deltaY);
        updateField(selectedIconFieldId, {
          iconWidth: newWidth,
          iconHeight: newHeight
        });
      } else if (iconResizeDirection === 'e') {
        const newWidth = Math.max(20, iconResizeStartWidth + deltaX);
        updateField(selectedIconFieldId, {
          iconWidth: newWidth
        });
      } else if (iconResizeDirection === 's') {
        const newHeight = Math.max(20, iconResizeStartHeight + deltaY);
        updateField(selectedIconFieldId, {
          iconHeight: newHeight
        });
      }
    }
  }

  function handleIconMouseUp() {
    isDraggingIcon = false;
    isResizingIcon = false;
    iconResizeDirection = '';
    window.removeEventListener('mousemove', handleIconMouseMove);
    window.removeEventListener('mouseup', handleIconMouseUp);
  }

  function handleSymbolMouseDown(event: MouseEvent, fieldId: string) {
    event.stopPropagation();
    selectedSymbolFieldId = fieldId;
    selectedFieldId = null;
    selectedIconFieldId = null;
    isDraggingSymbol = true;
    symbolDragStartX = event.clientX;
    symbolDragStartY = event.clientY;
    
    const fieldItem = fieldSelectors.find(f => f.id === fieldId);
    if (fieldItem) {
      symbolDragStartSymbolX = fieldItem.symbolX || 0;
      symbolDragStartSymbolY = fieldItem.symbolY || 0;
    }
    
    window.addEventListener('mousemove', handleSymbolMouseMove);
    window.addEventListener('mouseup', handleSymbolMouseUp);
  }

  function handleSymbolResizeMouseDown(event: MouseEvent, fieldId: string, direction: string) {
    event.stopPropagation();
    selectedSymbolFieldId = fieldId;
    isResizingSymbol = true;
    symbolResizeDirection = direction;
    symbolResizeStartX = event.clientX;
    symbolResizeStartY = event.clientY;
    
    const fieldItem = fieldSelectors.find(f => f.id === fieldId);
    if (fieldItem) {
      symbolResizeStartWidth = fieldItem.symbolWidth || 50;
      symbolResizeStartHeight = fieldItem.symbolHeight || 50;
    }
    
    window.addEventListener('mousemove', handleSymbolMouseMove);
    window.addEventListener('mouseup', handleSymbolMouseUp);
  }

  function handleSymbolMouseMove(event: MouseEvent) {
    if (!selectedSymbolFieldId) return;
    
    const fieldItem = fieldSelectors.find(f => f.id === selectedSymbolFieldId);
    if (!fieldItem) return;
    
    if (isDraggingSymbol) {
      const deltaX = (event.clientX - symbolDragStartX) / previewScale;
      const deltaY = (event.clientY - symbolDragStartY) / previewScale;
      
      const newSymbolX = symbolDragStartSymbolX + deltaX;
      const newSymbolY = symbolDragStartSymbolY + deltaY;
      
      updateField(selectedSymbolFieldId, {
        symbolX: newSymbolX,
        symbolY: newSymbolY
      });
    } else if (isResizingSymbol) {
      const deltaX = (event.clientX - symbolResizeStartX) / previewScale;
      const deltaY = (event.clientY - symbolResizeStartY) / previewScale;
      
      if (symbolResizeDirection === 'se') {
        const newWidth = Math.max(20, symbolResizeStartWidth + deltaX);
        const newHeight = Math.max(20, symbolResizeStartHeight + deltaY);
        updateField(selectedSymbolFieldId, {
          symbolWidth: newWidth,
          symbolHeight: newHeight
        });
      } else if (symbolResizeDirection === 'e') {
        const newWidth = Math.max(20, symbolResizeStartWidth + deltaX);
        updateField(selectedSymbolFieldId, {
          symbolWidth: newWidth
        });
      } else if (symbolResizeDirection === 's') {
        const newHeight = Math.max(20, symbolResizeStartHeight + deltaY);
        updateField(selectedSymbolFieldId, {
          symbolHeight: newHeight
        });
      }
    }
  }

  function handleSymbolMouseUp() {
    isDraggingSymbol = false;
    isResizingSymbol = false;
    symbolResizeDirection = '';
    window.removeEventListener('mousemove', handleSymbolMouseMove);
    window.removeEventListener('mouseup', handleSymbolMouseUp);
  }

  function handleKeyDown(event: KeyboardEvent) {
    if (!selectedFieldId) return;
    
    const fieldItem = fieldSelectors.find(f => f.id === selectedFieldId);
    if (!fieldItem) return;
    
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(event.key)) {
      event.preventDefault();
    }
    
    const step = event.shiftKey ? 10 : 1;
    
    switch (event.key) {
      case 'ArrowUp':
        updateField(selectedFieldId, { y: Math.max(0, fieldItem.y - step) });
        break;
      case 'ArrowDown':
        updateField(selectedFieldId, { y: fieldItem.y + step });
        break;
      case 'ArrowLeft':
        updateField(selectedFieldId, { x: Math.max(0, fieldItem.x - step) });
        break;
      case 'ArrowRight':
        updateField(selectedFieldId, { x: fieldItem.x + step });
        break;
    }
  }
  
  function handleSave() {
    onSave(fieldSelectors);
    dispatch('close');
  }
  
  function handleCancel() {
    dispatch('close');
  }
</script>

<svelte:window on:keydown={handleKeyDown} />

<input 
  type="file" 
  accept="image/png,image/jpeg,image/jpg" 
  on:change={(e) => iconUploadFieldId && handleIconUpload(e, iconUploadFieldId)}
  bind:this={fileInput}
  style="display: none;"
/>

<input 
  type="file" 
  accept="image/png,image/jpeg,image/jpg" 
  on:change={(e) => symbolUploadFieldId && handleSymbolUpload(e, symbolUploadFieldId)}
  bind:this={symbolFileInput}
  style="display: none;"
/>

<div class="configurator">
  <div class="header">
    <h2 class="title">Configure Product Field #{field.number}</h2>
    <p class="subtitle">Field Container: {field.width}×{field.height}px - Add product data fields inside</p>
  </div>

  <div class="content">
    <!-- Left Panel: Controls -->
    <div class="controls-panel">
      <div class="section">
        <h3 class="section-title">Add Data Fields</h3>
        <button class="add-field-btn" on:click={addFieldSelector}>
          ➕ Add Field
        </button>
        
        <div class="fields-list">
          {#each fieldSelectors as fieldItem (fieldItem.id)}
            <div class="field-item {selectedFieldId === fieldItem.id ? 'selected' : ''}" on:click={() => selectField(fieldItem.id)}>
              <div class="field-header">
                <span class="field-label">{availableFields.find(f => f.value === fieldItem.label)?.label || fieldItem.label}</span>
                <button class="delete-btn" on:click|stopPropagation={() => deleteField(fieldItem.id)}>🗑️</button>
              </div>
              
              {#if selectedFieldId === fieldItem.id}
                <div class="field-config">
                  <label>
                    Field Type:
                    <select value={fieldItem.label} on:change={(e) => updateField(fieldItem.id, { label: e.currentTarget.value })}>
                      {#each availableFields as option}
                        <option value={option.value}>{option.label}</option>
                      {/each}
                    </select>
                  </label>
                  
                  <div class="input-row">
                    <label>
                      X: <input type="number" value={fieldItem.x} on:input={(e) => updateField(fieldItem.id, { x: parseFloat(e.currentTarget.value) })} />
                    </label>
                    <label>
                      Y: <input type="number" value={fieldItem.y} on:input={(e) => updateField(fieldItem.id, { y: parseFloat(e.currentTarget.value) })} />
                    </label>
                  </div>
                  
                  <div class="input-row">
                    <label>
                      Width: <input type="number" value={fieldItem.width} on:input={(e) => updateField(fieldItem.id, { width: parseFloat(e.currentTarget.value) })} />
                    </label>
                    <label>
                      Height: <input type="number" value={fieldItem.height} on:input={(e) => updateField(fieldItem.id, { height: parseFloat(e.currentTarget.value) })} />
                    </label>
                  </div>
                  
                  <label>
                    Font Size: <input type="number" value={fieldItem.fontSize} on:input={(e) => updateField(fieldItem.id, { fontSize: parseFloat(e.currentTarget.value) })} />
                  </label>
                  
                  <label>
                    Font Family:
                    <select value={fieldItem.fontFamily} on:change={(e) => updateField(fieldItem.id, { fontFamily: e.currentTarget.value })}>
                      <option value="">-- Default --</option>
                      {#each customFonts as font}
                        <option value={font.name}>{font.name}</option>
                      {/each}
                    </select>
                  </label>
                  <div class="font-upload-row">
                    <label class="font-upload-btn">
                      <input type="file" accept=".ttf,.otf,.woff,.woff2" multiple on:change={handleFontUpload} bind:this={fontFileInput} hidden />
                      {isUploadingFont ? '⏳ Uploading...' : '📤 Upload Fonts'}
                    </label>
                    {#if customFonts.length > 0}
                      <span class="font-count">{customFonts.length} font(s)</span>
                    {/if}
                  </div>
                  
                  <label>
                    Alignment:
                    <select value={fieldItem.alignment} on:change={(e) => updateField(fieldItem.id, { alignment: e.currentTarget.value as 'left' | 'center' | 'right' })}>
                      <option value="left">Left</option>
                      <option value="center">Center</option>
                      <option value="right">Right</option>
                    </select>
                  </label>
                  
                  <label>
                    Text Color:
                    <div class="color-picker-container">
                      <input 
                        type="color" 
                        value={fieldItem.color} 
                        on:input={(e) => updateField(fieldItem.id, { color: e.currentTarget.value })}
                        class="color-picker"
                      />
                      <input 
                        type="text" 
                        value={fieldItem.color} 
                        on:input={(e) => updateField(fieldItem.id, { color: e.currentTarget.value })}
                        class="color-hex"
                        placeholder="#000000"
                      />
                    </div>
                  </label>
                  
                  <!-- Background Icon Section - hide for special_symbol -->
                  {#if fieldItem.label !== 'special_symbol'}
                    <div class="icon-section">
                      <label class="icon-label">Background Icon:</label>
                      {#if fieldItem.iconUrl}
                        <div class="icon-preview-container">
                          <img src={fieldItem.iconUrl} alt="Icon" class="icon-preview" on:dblclick={() => triggerIconUpload(fieldItem.id)} />
                          <button class="remove-icon-btn" on:click={() => removeIcon(fieldItem.id)}>✕</button>
                        </div>
                        <div class="icon-size-controls">
                        <label>
                          Icon Width:
                          <input 
                            type="number" 
                            value={fieldItem.iconWidth} 
                            on:input={(e) => updateField(fieldItem.id, { iconWidth: parseFloat(e.currentTarget.value) || 50 })}
                            min="10"
                          />
                        </label>
                        <label>
                          Icon Height:
                          <input 
                            type="number" 
                            value={fieldItem.iconHeight} 
                            on:input={(e) => updateField(fieldItem.id, { iconHeight: parseFloat(e.currentTarget.value) || 50 })}
                            min="10"
                          />
                        </label>
                        <label>
                          Icon X:
                          <input 
                            type="number" 
                            value={fieldItem.iconX} 
                            on:input={(e) => updateField(fieldItem.id, { iconX: parseFloat(e.currentTarget.value) || 0 })}
                          />
                        </label>
                        <label>
                          Icon Y:
                          <input 
                            type="number" 
                            value={fieldItem.iconY} 
                            on:input={(e) => updateField(fieldItem.id, { iconY: parseFloat(e.currentTarget.value) || 0 })}
                          />
                        </label>
                      </div>
                      <p class="icon-hint">💡 Double-click icon to change</p>
                    {:else}
                      <button class="upload-icon-btn" on:click={() => triggerIconUpload(fieldItem.id)}>
                        📤 Upload Icon (PNG/JPG)
                      </button>
                    {/if}
                  </div>
                  {/if}
                  
                  <!-- Special Symbol Section -->
                  {#if fieldItem.label === 'special_symbol'}
                    <div class="icon-section">
                      <label class="icon-label">🎨 Special Symbol Image:</label>
                      {#if fieldItem.symbolUrl}
                        <div class="icon-preview-container">
                          <img src={fieldItem.symbolUrl} alt="Symbol" class="icon-preview" on:dblclick={() => triggerSymbolUpload(fieldItem.id)} />
                          <button class="remove-icon-btn" on:click={() => removeSymbol(fieldItem.id)}>✕</button>
                        </div>
                        <div class="icon-size-controls">
                          <label>
                            Symbol Width:
                            <input 
                              type="number" 
                              value={fieldItem.symbolWidth} 
                              on:input={(e) => updateField(fieldItem.id, { symbolWidth: parseFloat(e.currentTarget.value) || 50 })}
                              min="10"
                            />
                          </label>
                          <label>
                            Symbol Height:
                            <input 
                              type="number" 
                              value={fieldItem.symbolHeight} 
                              on:input={(e) => updateField(fieldItem.id, { symbolHeight: parseFloat(e.currentTarget.value) || 50 })}
                              min="10"
                            />
                          </label>
                        </div>
                        <p class="icon-hint">💡 Double-click symbol to change</p>
                      {:else}
                        <button class="upload-icon-btn" on:click={() => triggerSymbolUpload(fieldItem.id)}>
                          📤 Upload Symbol Image
                        </button>
                      {/if}
                    </div>
                  {/if}
                </div>
              {/if}
            </div>
          {/each}
        </div>
      </div>

      <div class="section">
        <p class="info-message">💡 This saves field configuration to local memory. Click "Save Template" in the main designer to persist to database.</p>
        <button class="save-btn" on:click={handleSave}>
          ✅ Apply Configuration
        </button>
        <button class="cancel-btn" on:click={handleCancel}>
          Cancel
        </button>
      </div>
    </div>

    <!-- Right Panel: Preview -->
    <div class="preview-panel" bind:this={previewContainer}>
      <h3 class="section-title">Field Preview <span class="scale-badge">🔍 {Math.round(previewScale * 100)}%</span></h3>
      <div class="preview-container">
        <div class="preview-scale-wrapper" style="width: {scaledWidth}px; height: {scaledHeight}px;">
        <div class="preview-wrapper" style="width: {field.width}px; height: {field.height}px; transform: scale({previewScale}); transform-origin: top left;">
          <div class="preview-background"></div>
          
          {#each fieldSelectors as fieldItem (fieldItem.id)}
            <div 
              class="field-overlay {selectedFieldId === fieldItem.id ? 'selected' : ''}"
              style="left: {fieldItem.x}px; top: {fieldItem.y}px; width: {fieldItem.width}px; height: {fieldItem.height}px; color: {fieldItem.color}; overflow: hidden; font-size: {fieldItem.fontSize}px; text-align: {fieldItem.alignment};"
              on:mousedown={(e) => handleMouseDown(e, fieldItem.id)}
            >
              {#if fieldItem.label === 'special_symbol'}
                <!-- Empty for special symbol - will be rendered separately -->
              {:else}
                <span class="field-overlay-label" style="color: {fieldItem.color}; font-size: {fieldItem.fontSize}px;{fieldItem.fontFamily ? ` font-family: '${fieldItem.fontFamily}', sans-serif;` : ''}">{availableFields.find(f => f.value === fieldItem.label)?.label || fieldItem.label}</span>
              {/if}
              
              {#if selectedFieldId === fieldItem.id}
                <div class="resize-handle resize-se" on:mousedown={(e) => handleMouseDown(e, fieldItem.id, 'se')}></div>
                <div class="resize-handle resize-e" on:mousedown={(e) => handleMouseDown(e, fieldItem.id, 'e')}></div>
                <div class="resize-handle resize-s" on:mousedown={(e) => handleMouseDown(e, fieldItem.id, 's')}></div>
              {/if}
            </div>
          {/each}
          
          <!-- Icons rendered separately, absolute to preview-wrapper -->
          {#each fieldSelectors as fieldItem (fieldItem.id)}
            {#if fieldItem.iconUrl}
              <div 
                class="icon-container {selectedIconFieldId === fieldItem.id ? 'icon-selected' : ''}"
                style="left: {fieldItem.iconX || 0}px; top: {fieldItem.iconY || 0}px; width: {fieldItem.iconWidth || 50}px; height: {fieldItem.iconHeight || 50}px;"
                on:mousedown={(e) => handleIconMouseDown(e, fieldItem.id)}
              >
                <img 
                  src={fieldItem.iconUrl} 
                  alt="Background Icon" 
                  class="field-background-icon"
                />
                {#if selectedIconFieldId === fieldItem.id}
                  <div class="icon-resize-handle icon-resize-se" on:mousedown={(e) => handleIconResizeMouseDown(e, fieldItem.id, 'se')}></div>
                  <div class="icon-resize-handle icon-resize-e" on:mousedown={(e) => handleIconResizeMouseDown(e, fieldItem.id, 'e')}></div>
                  <div class="icon-resize-handle icon-resize-s" on:mousedown={(e) => handleIconResizeMouseDown(e, fieldItem.id, 's')}></div>
                {/if}
              </div>
            {/if}
          {/each}
          
          <!-- Symbols rendered separately, absolute to preview-wrapper -->
          {#each fieldSelectors as fieldItem (fieldItem.id)}
            {#if fieldItem.label === 'special_symbol' && fieldItem.symbolUrl}
              <div 
                class="symbol-container {selectedSymbolFieldId === fieldItem.id ? 'symbol-selected' : ''}"
                style="left: {fieldItem.symbolX || 0}px; top: {fieldItem.symbolY || 0}px; width: {fieldItem.symbolWidth || 50}px; height: {fieldItem.symbolHeight || 50}px;"
                on:mousedown={(e) => handleSymbolMouseDown(e, fieldItem.id)}
              >
                <img 
                  src={fieldItem.symbolUrl} 
                  alt="Special Symbol" 
                  class="field-background-icon"
                />
                {#if selectedSymbolFieldId === fieldItem.id}
                  <div class="icon-resize-handle icon-resize-se" on:mousedown={(e) => handleSymbolResizeMouseDown(e, fieldItem.id, 'se')}></div>
                  <div class="icon-resize-handle icon-resize-e" on:mousedown={(e) => handleSymbolResizeMouseDown(e, fieldItem.id, 'e')}></div>
                  <div class="icon-resize-handle icon-resize-s" on:mousedown={(e) => handleSymbolResizeMouseDown(e, fieldItem.id, 's')}></div>
                {/if}
              </div>
            {/if}
          {/each}
        </div>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .configurator {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: #f9fafb;
    overflow: hidden;
  }

  .header {
    padding: 1.5rem;
    background: white;
    border-bottom: 1px solid #e5e7eb;
  }

  .title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
    margin: 0 0 0.5rem 0;
  }

  .subtitle {
    font-size: 0.875rem;
    color: #6b7280;
    margin: 0;
  }

  .content {
    flex: 1;
    display: grid;
    grid-template-columns: 350px 1fr;
    gap: 1.5rem;
    padding: 1.5rem;
    overflow: hidden;
  }

  .controls-panel {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    overflow-y: auto;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    display: flex;
    flex-direction: column;
  }

  .preview-panel {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    overflow: auto;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    display: flex;
    flex-direction: column;
  }

  .section {
    margin-bottom: 1.5rem;
  }

  .section:last-child {
    margin-bottom: 0;
    margin-top: auto;
  }

  .section-title {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid #e5e7eb;
  }

  .add-field-btn {
    width: 100%;
    padding: 0.75rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    margin-bottom: 1rem;
  }

  .add-field-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
  }

  .fields-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    max-height: 400px;
    overflow-y: auto;
    padding-right: 0.5rem;
  }

  .fields-list::-webkit-scrollbar {
    width: 6px;
  }

  .fields-list::-webkit-scrollbar-track {
    background: #f3f4f6;
    border-radius: 3px;
  }

  .fields-list::-webkit-scrollbar-thumb {
    background: #d1d5db;
    border-radius: 3px;
  }

  .fields-list::-webkit-scrollbar-thumb:hover {
    background: #9ca3af;
  }

  .field-item {
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    padding: 0.75rem;
    cursor: pointer;
    transition: all 0.2s;
    background: white;
  }

  .field-item:hover {
    border-color: #14b8a6;
    background: #fafafa;
  }

  .field-item.selected {
    border-color: #14b8a6;
    background: #f0fdfa;
  }

  .field-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .field-label {
    font-weight: 600;
    color: #1f2937;
  }

  .delete-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 1.125rem;
    padding: 0.25rem;
    opacity: 0.6;
    transition: opacity 0.2s;
  }

  .delete-btn:hover {
    opacity: 1;
  }

  .field-config {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid #e5e7eb;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    max-height: 350px;
    overflow-y: auto;
    padding-right: 0.5rem;
  }

  .field-config::-webkit-scrollbar {
    width: 6px;
  }

  .field-config::-webkit-scrollbar-track {
    background: #f3f4f6;
    border-radius: 3px;
  }

  .field-config::-webkit-scrollbar-thumb {
    background: #d1d5db;
    border-radius: 3px;
  }

  .field-config::-webkit-scrollbar-thumb:hover {
    background: #9ca3af;
  }

  .field-config label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    font-size: 0.875rem;
    color: #374151;
    font-weight: 500;
  }

  .field-config input,
  .field-config select {
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 0.875rem;
  }

  .input-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }

  .info-message {
    background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
    color: #92400e;
    padding: 0.75rem 1rem;
    border-radius: 8px;
    font-size: 0.875rem;
    line-height: 1.4;
    margin-bottom: 1rem;
    border-left: 4px solid #f59e0b;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .save-btn,
  .cancel-btn {
    width: 100%;
    padding: 1rem;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
    transition: all 0.2s;
    margin-bottom: 0.5rem;
  }

  .save-btn {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
  }

  .save-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
  }

  .cancel-btn {
    background: #f3f4f6;
    color: #374151;
  }

  .cancel-btn:hover {
    background: #e5e7eb;
  }

  .preview-container {
    position: relative;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    overflow: auto;
    background: #f9fafb;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding: 2rem;
    flex: 1;
  }
  
  .preview-scale-wrapper {
    position: relative;
    flex-shrink: 0;
  }

  .preview-wrapper {
    position: relative;
    flex-shrink: 0;
    border: 2px dashed #9ca3af;
    background: white;
  }

  .scale-badge {
    font-size: 0.75rem;
    font-weight: 500;
    color: #6b7280;
    background: #f3f4f6;
    padding: 0.125rem 0.5rem;
    border-radius: 4px;
    margin-left: 0.5rem;
  }

  .preview-background {
    width: 100%;
    height: 100%;
    background: linear-gradient(45deg, #f3f4f6 25%, transparent 25%),
                linear-gradient(-45deg, #f3f4f6 25%, transparent 25%),
                linear-gradient(45deg, transparent 75%, #f3f4f6 75%),
                linear-gradient(-45deg, transparent 75%, #f3f4f6 75%);
    background-size: 20px 20px;
    background-position: 0 0, 0 10px, 10px -10px, -10px 0px;
    opacity: 0.5;
    position: absolute;
    top: 0;
    left: 0;
  }

  .field-overlay {
    position: absolute;
    border: 2px solid #14b8a6;
    background: rgba(20, 184, 166, 0.1);
    cursor: move;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    box-sizing: border-box;
    z-index: 20;
  }

  .field-overlay:hover {
    background: rgba(20, 184, 166, 0.2);
  }

  .field-overlay.selected {
    border-color: #0891b2;
    background: rgba(8, 145, 178, 0.2);
    box-shadow: 0 0 0 3px rgba(8, 145, 178, 0.3);
  }

  .field-overlay-label {
    font-weight: 600;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    pointer-events: none;
    position: relative;
    z-index: 25;
    width: 100%;
    text-align: inherit;
    display: block;
  }

  .resize-handle {
    position: absolute;
    background: #0891b2;
    border: 1px solid white;
    z-index: 10;
  }

  .resize-se {
    right: -4px;
    bottom: -4px;
    width: 12px;
    height: 12px;
    cursor: se-resize;
  }

  .resize-e {
    right: -4px;
    top: 50%;
    transform: translateY(-50%);
    width: 8px;
    height: 24px;
    cursor: e-resize;
  }

  .resize-s {
    bottom: -4px;
    left: 50%;
    transform: translateX(-50%);
    width: 24px;
    height: 8px;
    cursor: s-resize;
  }

  .color-picker-container {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .color-picker {
    width: 60px;
    height: 38px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    cursor: pointer;
    padding: 2px;
  }

  .color-hex {
    flex: 1;
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 0.875rem;
    font-family: monospace;
  }

  .icon-section {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 2px solid #e5e7eb;
  }

  .icon-label {
    display: block;
    font-size: 0.875rem;
    font-weight: 600;
    color: #374151;
    margin-bottom: 0.75rem;
  }

  .icon-preview-container {
    position: relative;
    width: 100%;
    padding: 1rem;
    background: #f9fafb;
    border: 2px dashed #d1d5db;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 0.75rem;
  }

  .icon-preview {
    max-width: 100px;
    max-height: 100px;
    object-fit: contain;
    cursor: pointer;
    transition: all 0.2s;
  }

  .icon-preview:hover {
    transform: scale(1.05);
    filter: brightness(1.1);
  }

  .remove-icon-btn {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    background: #ef4444;
    color: white;
    border: none;
    border-radius: 50%;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    font-size: 0.875rem;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  .remove-icon-btn:hover {
    background: #dc2626;
    transform: scale(1.1);
  }

  .icon-size-controls {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-bottom: 0.5rem;
  }

  .icon-size-controls label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    font-size: 0.75rem;
    color: #6b7280;
  }

  .icon-size-controls input {
    padding: 0.375rem 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.75rem;
  }

  .icon-hint {
    font-size: 0.75rem;
    color: #6b7280;
    text-align: center;
    margin: 0;
    font-style: italic;
  }

  .upload-icon-btn {
    width: 100%;
    padding: 0.75rem;
    background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    font-size: 0.875rem;
  }

  .upload-icon-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(139, 92, 246, 0.3);
  }

  .font-upload-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-top: 0.25rem;
  }

  .font-upload-btn {
    padding: 0.375rem 0.75rem;
    background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-weight: 600;
    font-size: 0.75rem;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
  }

  .font-upload-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 2px 6px rgba(99, 102, 241, 0.3);
  }

  .font-count {
    font-size: 0.7rem;
    color: #6b7280;
    font-weight: 500;
  }

  .field-background-icon {
    width: 100%;
    height: 100%;
    object-fit: contain;
    pointer-events: none;
    z-index: 1;
    opacity: 0.8;
  }

  .icon-container {
    position: absolute;
    cursor: move;
    border: 2px dashed transparent;
    transition: border-color 0.2s;
    z-index: 2;
    pointer-events: auto;
  }

  .icon-container:hover,
  .icon-container.icon-selected {
    border-color: #8b5cf6;
  }

  .symbol-container {
    position: absolute;
    cursor: move;
    border: 2px dashed transparent;
    transition: border-color 0.2s;
    z-index: 15;
    pointer-events: auto;
  }

  .symbol-container:hover,
  .symbol-container.symbol-selected {
    border-color: #ef4444;
  }

  .icon-resize-handle {
    position: absolute;
    width: 8px;
    height: 8px;
    background: #8b5cf6;
    border: 1px solid white;
    border-radius: 50%;
    z-index: 10;
  }

  .icon-resize-se {
    bottom: -4px;
    right: -4px;
    cursor: nwse-resize;
  }

  .icon-resize-e {
    top: 50%;
    right: -4px;
    transform: translateY(-50%);
    cursor: ew-resize;
  }

  .icon-resize-s {
    bottom: -4px;
    left: 50%;
    transform: translateX(-50%);
    cursor: ns-resize;
  }

  .special-symbol-preview {
    object-fit: contain;
    pointer-events: none;
    z-index: 20;
  }
</style>
