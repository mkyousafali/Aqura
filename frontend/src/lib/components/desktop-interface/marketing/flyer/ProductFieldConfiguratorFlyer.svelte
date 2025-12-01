<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
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
    const newField: FieldSelector = {
      id: `subfield-${nextFieldId++}`,
      label: 'product_name_en',
      x: 10,
      y: 10,
      width: Math.min(200, field.width - 20),
      height: 40,
      fontSize: 16,
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
    
    const deltaX = event.clientX - dragStartX;
    const deltaY = event.clientY - dragStartY;
    
    const fieldItem = fieldSelectors.find(f => f.id === selectedFieldId);
    if (!fieldItem) return;
    
    if (isDragging) {
      const newX = Math.max(0, Math.min(field.width - fieldItem.width, fieldItem.x + deltaX));
      const newY = Math.max(0, Math.min(field.height - fieldItem.height, fieldItem.y + deltaY));
      updateField(selectedFieldId, {
        x: newX,
        y: newY
      });
    } else if (isResizing) {
      if (resizeHandle === 'se') {
        const newWidth = Math.max(50, Math.min(field.width - fieldItem.x, fieldItem.width + deltaX));
        const newHeight = Math.max(30, Math.min(field.height - fieldItem.y, fieldItem.height + deltaY));
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
        const newWidth = Math.max(50, Math.min(field.width - fieldItem.x, fieldItem.width + deltaX));
        const updates: any = {
          width: newWidth
        };
        // If special_symbol, also update symbol width
        if (fieldItem.label === 'special_symbol') {
          updates.symbolWidth = newWidth;
        }
        updateField(selectedFieldId, updates);
      } else if (resizeHandle === 's') {
        const newHeight = Math.max(30, Math.min(field.height - fieldItem.y, fieldItem.height + deltaY));
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
      const deltaX = event.clientX - iconDragStartX;
      const deltaY = event.clientY - iconDragStartY;
      
      const newIconX = iconDragStartIconX + deltaX;
      const newIconY = iconDragStartIconY + deltaY;
      
      updateField(selectedIconFieldId, {
        iconX: newIconX,
        iconY: newIconY
      });
    } else if (isResizingIcon) {
      const deltaX = event.clientX - iconResizeStartX;
      const deltaY = event.clientY - iconResizeStartY;
      
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
      const deltaX = event.clientX - symbolDragStartX;
      const deltaY = event.clientY - symbolDragStartY;
      
      const newSymbolX = symbolDragStartSymbolX + deltaX;
      const newSymbolY = symbolDragStartSymbolY + deltaY;
      
      updateField(selectedSymbolFieldId, {
        symbolX: newSymbolX,
        symbolY: newSymbolY
      });
    } else if (isResizingSymbol) {
      const deltaX = event.clientX - symbolResizeStartX;
      const deltaY = event.clientY - symbolResizeStartY;
      
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
          {#each fieldSelectors as fieldItem}
            <div class="field-item {selectedFieldId === fieldItem.id ? 'selected' : ''}" on:click={() => selectField(fieldItem.id)}>
              <div class="field-header">
                <span class="field-label">{availableFields.find(f => f.value === fieldItem.label)?.label || fieldItem.label}</span>
                <button class="delete-btn" on:click|stopPropagation={() => deleteField(fieldItem.id)}>🗑️</button>
              </div>
              
              {#if selectedFieldId === fieldItem.id}
                <div class="field-config">
                  <label>
                    Field Type:
                    <select bind:value={fieldItem.label} on:change={() => updateField(fieldItem.id, { label: fieldItem.label })}>
                      {#each availableFields as option}
                        <option value={option.value}>{option.label}</option>
                      {/each}
                    </select>
                  </label>
                  
                  <div class="input-row">
                    <label>
                      X: <input type="number" bind:value={fieldItem.x} on:input={() => updateField(fieldItem.id, { x: fieldItem.x })} />
                    </label>
                    <label>
                      Y: <input type="number" bind:value={fieldItem.y} on:input={() => updateField(fieldItem.id, { y: fieldItem.y })} />
                    </label>
                  </div>
                  
                  <div class="input-row">
                    <label>
                      Width: <input type="number" bind:value={fieldItem.width} on:input={() => updateField(fieldItem.id, { width: fieldItem.width })} />
                    </label>
                    <label>
                      Height: <input type="number" bind:value={fieldItem.height} on:input={() => updateField(fieldItem.id, { height: fieldItem.height })} />
                    </label>
                  </div>
                  
                  <label>
                    Font Size: <input type="number" bind:value={fieldItem.fontSize} on:input={() => updateField(fieldItem.id, { fontSize: fieldItem.fontSize })} />
                  </label>
                  
                  <label>
                    Alignment:
                    <select bind:value={fieldItem.alignment} on:change={() => updateField(fieldItem.id, { alignment: fieldItem.alignment })}>
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
                        bind:value={fieldItem.color} 
                        on:input={() => updateField(fieldItem.id, { color: fieldItem.color })}
                        class="color-picker"
                      />
                      <input 
                        type="text" 
                        bind:value={fieldItem.color} 
                        on:input={() => updateField(fieldItem.id, { color: fieldItem.color })}
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
                            bind:value={fieldItem.iconWidth} 
                            on:input={() => updateField(fieldItem.id, { iconWidth: fieldItem.iconWidth || 50 })}
                            min="10"
                          />
                        </label>
                        <label>
                          Icon Height:
                          <input 
                            type="number" 
                            bind:value={fieldItem.iconHeight} 
                            on:input={() => updateField(fieldItem.id, { iconHeight: fieldItem.iconHeight || 50 })}
                            min="10"
                          />
                        </label>
                        <label>
                          Icon X:
                          <input 
                            type="number" 
                            bind:value={fieldItem.iconX} 
                            on:input={() => updateField(fieldItem.id, { iconX: fieldItem.iconX || 0 })}
                          />
                        </label>
                        <label>
                          Icon Y:
                          <input 
                            type="number" 
                            bind:value={fieldItem.iconY} 
                            on:input={() => updateField(fieldItem.id, { iconY: fieldItem.iconY || 0 })}
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
                              bind:value={fieldItem.symbolWidth} 
                              on:input={() => updateField(fieldItem.id, { symbolWidth: fieldItem.symbolWidth || 50 })}
                              min="10"
                            />
                          </label>
                          <label>
                            Symbol Height:
                            <input 
                              type="number" 
                              bind:value={fieldItem.symbolHeight} 
                              on:input={() => updateField(fieldItem.id, { symbolHeight: fieldItem.symbolHeight || 50 })}
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
      <h3 class="section-title">Field Preview</h3>
      <div class="preview-container">
        <div class="preview-wrapper" style="width: {field.width}px; height: {field.height}px;">
          <div class="preview-background"></div>
          
          {#each fieldSelectors as fieldItem}
            <div 
              class="field-overlay {selectedFieldId === fieldItem.id ? 'selected' : ''}"
              style="left: {fieldItem.x}px; top: {fieldItem.y}px; width: {fieldItem.width}px; height: {fieldItem.height}px; color: {fieldItem.color}; overflow: hidden;"
              on:mousedown={(e) => handleMouseDown(e, fieldItem.id)}
            >
              {#if fieldItem.label === 'special_symbol'}
                <!-- Empty for special symbol - will be rendered separately -->
              {:else}
                <span class="field-overlay-label" style="color: {fieldItem.color};">{availableFields.find(f => f.value === fieldItem.label)?.label || fieldItem.label}</span>
              {/if}
              
              {#if selectedFieldId === fieldItem.id}
                <div class="resize-handle resize-se" on:mousedown={(e) => handleMouseDown(e, fieldItem.id, 'se')}></div>
                <div class="resize-handle resize-e" on:mousedown={(e) => handleMouseDown(e, fieldItem.id, 'e')}></div>
                <div class="resize-handle resize-s" on:mousedown={(e) => handleMouseDown(e, fieldItem.id, 's')}></div>
              {/if}
            </div>
          {/each}
          
          <!-- Icons rendered separately, absolute to preview-wrapper -->
          {#each fieldSelectors as fieldItem}
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
          {#each fieldSelectors as fieldItem}
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
  
  .preview-wrapper {
    position: relative;
    flex-shrink: 0;
    border: 2px dashed #9ca3af;
    background: white;
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
    font-size: 0.75rem;
    font-weight: 600;
    color: #0f766e;
    background: rgba(255, 255, 255, 0.95);
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    pointer-events: none;
    position: relative;
    z-index: 25;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
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
