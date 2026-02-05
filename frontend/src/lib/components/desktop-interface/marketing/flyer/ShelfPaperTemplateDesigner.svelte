<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  
  let templateImage: string | null = null;
  let imageFile: File | null = null;
  let isUploading = false;
  let isLoading = false;
  let templateName: string = '';
  let templateDescription: string = '';
  
  interface SavedTemplate {
    id: string;
    name: string;
    description: string | null;
    template_image_url: string;
    field_configuration: FieldSelector[];
    metadata: TemplateMetadata | null;
    created_at: string;
  }
  
  let savedTemplates: SavedTemplate[] = [];
  let selectedTemplateId: string | null = null;
  
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
  
  interface TemplateMetadata {
    preview_width: number;
    preview_height: number;
  }
  
  let fieldSelectors: FieldSelector[] = [];
  let selectedFieldId: string | null = null;
  let nextFieldId = 1;
  let isDragging = false;
  let dragStartX = 0;
  let dragStartY = 0;
  let isResizing = false;
  let resizeHandle = '';
  let previewContainer: HTMLElement | null = null;
  
  const availableFields = [
    { value: 'product_name_en', label: 'Product Name (EN)' },
    { value: 'product_name_ar', label: 'Product Name (AR)' },
    { value: 'barcode', label: 'Barcode' },
    { value: 'serial_number', label: 'Serial Number' },
    { value: 'unit_name', label: 'Unit Name' },
    { value: 'price', label: 'Price' },
    { value: 'offer_price', label: 'Offer Price' },
    { value: 'offer_qty', label: 'Offer Quantity' },
    { value: 'limit_qty', label: 'Limit Quantity' },
    { value: 'expire_date', label: 'Expire Date' },
    { value: 'image', label: 'Product Image' }
  ];
  
  function handleFileUpload(event: Event) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];
    
    if (file && file.type.startsWith('image/')) {
      imageFile = file;
      const reader = new FileReader();
      reader.onload = (e) => {
        templateImage = e.target?.result as string;
      };
      reader.readAsDataURL(file);
    }
  }
  
  function addFieldSelector() {
    const newField: FieldSelector = {
      id: `field-${nextFieldId++}`,
      label: 'product_name_en',
      x: 50,
      y: 50,
      width: 200,
      height: 40,
      fontSize: 16,
      alignment: 'left'
    };
    fieldSelectors = [...fieldSelectors, newField];
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
    
    const field = fieldSelectors.find(f => f.id === selectedFieldId);
    if (!field) return;
    
    // A4 dimensions at 96 DPI
    const maxWidth = 794;
    const maxHeight = 1123;
    
    if (isDragging) {
      const newX = Math.max(0, Math.min(maxWidth - field.width, field.x + deltaX));
      const newY = Math.max(0, Math.min(maxHeight - field.height, field.y + deltaY));
      updateField(selectedFieldId, {
        x: newX,
        y: newY
      });
    } else if (isResizing) {
      if (resizeHandle === 'se') {
        const newWidth = Math.max(50, Math.min(maxWidth - field.x, field.width + deltaX));
        const newHeight = Math.max(30, Math.min(maxHeight - field.y, field.height + deltaY));
        updateField(selectedFieldId, {
          width: newWidth,
          height: newHeight
        });
      } else if (resizeHandle === 'e') {
        const newWidth = Math.max(50, Math.min(maxWidth - field.x, field.width + deltaX));
        updateField(selectedFieldId, {
          width: newWidth
        });
      } else if (resizeHandle === 's') {
        const newHeight = Math.max(30, Math.min(maxHeight - field.y, field.height + deltaY));
        updateField(selectedFieldId, {
          height: newHeight
        });
      }
    }
    
    dragStartX = event.clientX;
    dragStartY = event.clientY;
  }
  
  function handleMouseUp() {
    isDragging = false;
    isResizing = false;
    resizeHandle = '';
    window.removeEventListener('mousemove', handleMouseMove);
    window.removeEventListener('mouseup', handleMouseUp);
  }

  function handleKeyDown(event: KeyboardEvent) {
    if (!selectedFieldId) return;
    
    const field = fieldSelectors.find(f => f.id === selectedFieldId);
    if (!field) return;
    
    // Prevent default scrolling behavior
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(event.key)) {
      event.preventDefault();
    }
    
    // Determine step size (hold Shift for larger steps)
    const step = event.shiftKey ? 10 : 1;
    
    switch (event.key) {
      case 'ArrowUp':
        updateField(selectedFieldId, { y: Math.max(0, field.y - step) });
        break;
      case 'ArrowDown':
        updateField(selectedFieldId, { y: field.y + step });
        break;
      case 'ArrowLeft':
        updateField(selectedFieldId, { x: Math.max(0, field.x - step) });
        break;
      case 'ArrowRight':
        updateField(selectedFieldId, { x: field.x + step });
        break;
    }
  }

  onMount(() => {
    window.addEventListener('keydown', handleKeyDown);
    loadSavedTemplates();
    
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  });
  
  async function loadSavedTemplates() {
    isLoading = true;
    try {
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
      isLoading = false;
    }
  }
  
  async function selectTemplate(templateId: string) {
    const template = savedTemplates.find(t => t.id === templateId);
    if (!template) return;
    
    selectedTemplateId = templateId;
    templateName = template.name;
    templateDescription = template.description || '';
    templateImage = template.template_image_url;
    fieldSelectors = template.field_configuration || [];
    
    // Update nextFieldId to avoid conflicts
    const maxId = fieldSelectors.reduce((max, field) => {
      const idNum = parseInt(field.id.replace('field-', ''));
      return idNum > max ? idNum : max;
    }, 0);
    nextFieldId = maxId + 1;
  }
  
  async function getCurrentUser() {
    // Try to get user from regular supabase client first (with session)
    const { data: { user } } = await supabase.auth.getUser();
    if (user) return user;
    
    // Fallback to custom session storage
    if (typeof window === 'undefined') return null;
    
    const sessionData = localStorage.getItem('aqura-device-session');
    if (!sessionData) return null;
    
    try {
      const session = JSON.parse(sessionData);
      if (session.currentUserId && session.users) {
        const currentUser = session.users.find(u => u.id === session.currentUserId);
        if (currentUser && currentUser.isActive) {
          return { id: currentUser.id };
        }
      }
    } catch (error) {
      console.error('Error parsing session data:', error);
    }
    
    return null;
  }
  
  async function uploadTemplateImage(): Promise<string | null> {
    if (!imageFile) return templateImage;
    
    try {
      const user = await getCurrentUser();
      if (!user) throw new Error('User not authenticated');
      
      const fileExt = imageFile.name.split('.').pop();
      const fileName = `${user.id}/${Date.now()}.${fileExt}`;
      
      const { data, error } = await supabase.storage
        .from('shelf-paper-templates')
        .upload(fileName, imageFile, {
          cacheControl: '3600',
          upsert: false
        });
      
      if (error) throw error;
      
      const { data: { publicUrl } } = supabase.storage
        .from('shelf-paper-templates')
        .getPublicUrl(data.path);
      
      return publicUrl;
    } catch (error) {
      console.error('Error uploading image:', error);
      throw error;
    }
  }
  
  async function saveTemplate() {
    if (!templateImage || fieldSelectors.length === 0) {
      alert('Please upload a template image and add field selectors');
      return;
    }
    
    if (!templateName.trim()) {
      alert('Please enter a template name');
      return;
    }
    
    isUploading = true;
    try {
      // Get current user
      const user = await getCurrentUser();
      if (!user) {
        throw new Error('User not authenticated');
      }
      
      // Upload image to storage if a new file was selected
      let imageUrl = templateImage;
      if (imageFile) {
        imageUrl = await uploadTemplateImage();
        if (!imageUrl) throw new Error('Failed to upload image');
      }
      
      // Get the actual displayed size of the preview image (A4 at 96 DPI)
      const previewImg = previewContainer?.querySelector('.preview-image') as HTMLImageElement;
      const metadata: TemplateMetadata = {
        preview_width: 794,  // A4 width in pixels
        preview_height: 1123 // A4 height in pixels
      };
      
      const templateData = {
        name: templateName.trim(),
        description: templateDescription.trim() || null,
        template_image_url: imageUrl,
        field_configuration: fieldSelectors,
        metadata: metadata,
        created_by: user.id,
        is_active: true
      };
      
      let result;
      if (selectedTemplateId) {
        // Update existing template (don't update created_by)
        const { created_by, ...updateData } = templateData;
        result = await supabase
          .from('shelf_paper_templates')
          .update(updateData)
          .eq('id', selectedTemplateId)
          .select()
          .single();
      } else {
        // Create new template
        result = await supabase
          .from('shelf_paper_templates')
          .insert([templateData])
          .select()
          .single();
      }
      
      if (result.error) throw result.error;
      
      alert('Template saved successfully!');
      await loadSavedTemplates();
      selectedTemplateId = result.data.id;
      imageFile = null; // Clear file after successful upload
    } catch (error) {
      console.error('Error saving template:', error);
      alert('Failed to save template: ' + (error.message || 'Unknown error'));
    } finally {
      isUploading = false;
    }
  }
  
  async function updateTemplateImage() {
    if (!selectedTemplateId) {
      alert('Please select a template first');
      return;
    }
    
    if (!imageFile) {
      alert('Please select a new image first');
      return;
    }
    
    isUploading = true;
    try {
      // Upload the new image
      const newImageUrl = await uploadTemplateImage();
      if (!newImageUrl) throw new Error('Failed to upload image');
      
      // Update only the template_image_url field
      const { error } = await supabase
        .from('shelf_paper_templates')
        .update({ template_image_url: newImageUrl })
        .eq('id', selectedTemplateId);
      
      if (error) throw error;
      
      alert('Template image updated successfully!');
      templateImage = newImageUrl;
      imageFile = null;
      await loadSavedTemplates();
    } catch (error) {
      console.error('Error updating template image:', error);
      alert('Failed to update template image: ' + (error.message || 'Unknown error'));
    } finally {
      isUploading = false;
    }
  }
  
  function newTemplate() {
    selectedTemplateId = null;
    templateName = '';
    templateDescription = '';
    templateImage = null;
    fieldSelectors = [];
    nextFieldId = 1;
  }
</script>

<div class="template-designer">
  <div class="header">
    <h2 class="text-2xl font-bold text-gray-800">Shelf Paper Template Designer</h2>
    <p class="text-sm text-gray-600 mt-1">Upload template image and define field positions</p>
  </div>

  <div class="content">
    <!-- Left Panel: Controls -->
    <div class="controls-panel">
      <div class="section">
        <h3 class="section-title">Load Template</h3>
        <div class="template-selector-row">
          <select 
            bind:value={selectedTemplateId} 
            on:change={(e) => e.target.value && selectTemplate(e.target.value)}
            class="template-select"
            disabled={isLoading}
          >
            <option value="">-- Select a saved template --</option>
            {#each savedTemplates as template}
              <option value={template.id}>{template.name}</option>
            {/each}
          </select>
          <button class="new-template-btn" on:click={newTemplate} title="Create new template">
            ➕ New
          </button>
        </div>
        {#if selectedTemplateId}
          <div class="template-info">
            <p class="text-xs text-gray-600 mt-2">
              {savedTemplates.find(t => t.id === selectedTemplateId)?.description || 'No description'}
            </p>
          </div>
        {/if}
      </div>
      
      <div class="section">
        <h3 class="section-title">Template Details</h3>
        <label class="input-label">
          Template Name *
          <input 
            type="text" 
            bind:value={templateName} 
            placeholder="Enter template name"
            class="text-input"
          />
        </label>
        <label class="input-label">
          Description
          <textarea 
            bind:value={templateDescription} 
            placeholder="Optional description"
            class="text-input"
            rows="2"
          ></textarea>
        </label>
      </div>

      <div class="section">
        <h3 class="section-title">Template Image</h3>
        <div class="upload-area">
          {#if !templateImage}
            <label class="upload-label">
              <input type="file" accept="image/*" on:change={handleFileUpload} hidden />
              <div class="upload-placeholder">
                <span class="upload-icon">📤</span>
                <span>Click to upload template</span>
              </div>
            </label>
          {:else}
            <div class="uploaded-preview">
              <img src={templateImage} alt="Template" />
              <div class="image-actions">
                <label class="change-image-btn">
                  <input type="file" accept="image/*" on:change={handleFileUpload} hidden />
                  🔄 Change Image
                </label>
                {#if imageFile && selectedTemplateId}
                  <button class="save-image-btn" on:click={updateTemplateImage} disabled={isUploading}>
                    {isUploading ? 'Saving...' : '💾 Save Image'}
                  </button>
                {/if}
              </div>
            </div>
          {/if}
        </div>
      </div>

      <div class="section">
        <h3 class="section-title">Field Selectors</h3>
        <button class="add-field-btn" on:click={addFieldSelector} disabled={!templateImage}>
          ➕ Add Field
        </button>
        
        <div class="fields-list">
          {#each fieldSelectors as field}
            <div class="field-item {selectedFieldId === field.id ? 'selected' : ''}" on:click={() => selectField(field.id)}>
              <div class="field-header">
                <span class="field-label">{availableFields.find(f => f.value === field.label)?.label || field.label}</span>
                <button class="delete-btn" on:click|stopPropagation={() => deleteField(field.id)}>🗑️</button>
              </div>
              
              {#if selectedFieldId === field.id}
                <div class="field-config">
                  <label>
                    Field Type:
                    <select bind:value={field.label} on:change={() => updateField(field.id, { label: field.label })}>
                      {#each availableFields as option}
                        <option value={option.value}>{option.label}</option>
                      {/each}
                    </select>
                  </label>
                  
                  <div class="input-row">
                    <label>
                      X: <input type="number" bind:value={field.x} on:input={() => updateField(field.id, { x: field.x })} />
                    </label>
                    <label>
                      Y: <input type="number" bind:value={field.y} on:input={() => updateField(field.id, { y: field.y })} />
                    </label>
                  </div>
                  
                  <div class="input-row">
                    <label>
                      Width: <input type="number" bind:value={field.width} on:input={() => updateField(field.id, { width: field.width })} />
                    </label>
                    <label>
                      Height: <input type="number" bind:value={field.height} on:input={() => updateField(field.id, { height: field.height })} />
                    </label>
                  </div>
                  
                  <label>
                    Font Size: <input type="number" bind:value={field.fontSize} on:input={() => updateField(field.id, { fontSize: field.fontSize })} />
                  </label>
                  
                  <label>
                    Alignment:
                    <select bind:value={field.alignment} on:change={() => updateField(field.id, { alignment: field.alignment })}>
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
                        bind:value={field.color} 
                        on:input={() => updateField(field.id, { color: field.color })}
                        class="color-picker"
                      />
                      <input 
                        type="text" 
                        bind:value={field.color} 
                        on:input={() => updateField(field.id, { color: field.color })}
                        class="color-hex"
                        placeholder="#000000"
                      />
                    </div>
                  </label>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      </div>

      <div class="section">
        <button class="save-btn" on:click={saveTemplate} disabled={isUploading || !templateImage || fieldSelectors.length === 0}>
          {isUploading ? 'Saving...' : '💾 Save Template'}
        </button>
      </div>
    </div>

    <!-- Right Panel: Preview -->
    <div class="preview-panel" bind:this={previewContainer}>
      <h3 class="section-title">Template Preview</h3>
      {#if templateImage}
        <div class="preview-container">
          <div class="preview-wrapper">
            <img src={templateImage} alt="Template Preview" class="preview-image" />
            
            {#each fieldSelectors as field}
              <div 
                class="field-overlay {selectedFieldId === field.id ? 'selected' : ''}"
                style="left: {field.x}px; top: {field.y}px; width: {field.width}px; height: {field.height}px; color: {field.color};"
                on:mousedown={(e) => handleMouseDown(e, field.id)}
              >
                <span class="field-overlay-label" style="color: {field.color}; font-size: {field.fontSize}px; text-align: {field.alignment}; width: 100%; display: block;">{availableFields.find(f => f.value === field.label)?.label || field.label}</span>
                
                {#if selectedFieldId === field.id}
                  <!-- Resize handles -->
                  <div 
                    class="resize-handle resize-se"
                    on:mousedown={(e) => handleMouseDown(e, field.id, 'se')}
                  ></div>
                  <div 
                    class="resize-handle resize-e"
                    on:mousedown={(e) => handleMouseDown(e, field.id, 'e')}
                  ></div>
                  <div 
                    class="resize-handle resize-s"
                    on:mousedown={(e) => handleMouseDown(e, field.id, 's')}
                  ></div>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {:else}
        <div class="preview-placeholder">
          <p>Upload a template image to start designing</p>
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .template-designer {
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

  .section-title {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid #e5e7eb;
  }

  .upload-area {
    border: 2px dashed #d1d5db;
    border-radius: 8px;
    overflow: hidden;
  }

  .upload-label {
    display: block;
    cursor: pointer;
  }

  .upload-placeholder {
    padding: 3rem 1rem;
    text-align: center;
    color: #6b7280;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
  }

  .upload-icon {
    font-size: 3rem;
  }

  .uploaded-preview {
    position: relative;
    background: #f9fafb;
    padding: 1rem;
  }

  .uploaded-preview img {
    width: 100%;
    height: auto;
    display: block;
    object-fit: contain;
    max-height: 150px;
    border-radius: 6px;
  }

  .change-btn {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    background: white;
    border: 1px solid #d1d5db;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .change-btn:hover {
    background: #f3f4f6;
  }

  .image-actions {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.75rem;
    flex-wrap: wrap;
  }

  .change-image-btn {
    flex: 1;
    display: inline-block;
    padding: 0.75rem 1rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    text-align: center;
    user-select: none;
  }

  .change-image-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
  }

  .save-image-btn {
    flex: 1;
    padding: 0.75rem 1rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .save-image-btn:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
  }

  .save-image-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
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

  .add-field-btn:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
  }

  .add-field-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .fields-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .field-item {
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    padding: 0.75rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .field-item:hover {
    border-color: #14b8a6;
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

  .save-btn {
    width: 100%;
    padding: 1rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .save-btn:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
  }

  .save-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .preview-container {
    position: relative;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    overflow: auto;
    max-height: calc(100vh - 250px);
    background: #f9fafb;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding: 1rem;
    transform: scale(1);
    transform-origin: top center;
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
    position: relative;
    z-index: 1;
    pointer-events: none;
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
    z-index: 10;
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
    background: white;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    pointer-events: none;
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

  .preview-placeholder {
    padding: 4rem 2rem;
    text-align: center;
    color: #9ca3af;
    border: 2px dashed #d1d5db;
    border-radius: 8px;
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

  .template-selector-row {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .template-select {
    flex: 1;
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 0.875rem;
    background: white;
    cursor: pointer;
  }

  .new-template-btn {
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.2s;
  }

  .new-template-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
  }

  .template-info {
    margin-top: 0.5rem;
    padding: 0.5rem;
    background: #f9fafb;
    border-radius: 6px;
  }

  .input-label {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    font-size: 0.875rem;
    color: #374151;
    font-weight: 500;
    margin-bottom: 0.75rem;
  }

  .text-input {
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 0.875rem;
    resize: vertical;
  }
</style>
