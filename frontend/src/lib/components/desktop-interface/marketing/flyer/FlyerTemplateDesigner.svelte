<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { openWindow } from '$lib/utils/windowManagerUtils';
  import ProductFieldConfiguratorFlyer from '$lib/components/desktop-interface/marketing/flyer/ProductFieldConfiguratorFlyer.svelte';
  
  let firstPageImage: string | null = null;
  let subPageImages: string[] = [];
  let firstPageFile: File | null = null;
  let subPageFiles: File[] = [];
  let isUploading = false;
  let isLoading = false;
  let templateName: string = '';
  let templateDescription: string = '';
  
  interface SavedTemplate {
    id: string;
    name: string;
    description: string | null;
    first_page_image_url: string;
    sub_page_image_urls: string[];
    first_page_configuration: ProductField[];
    sub_page_configurations: ProductField[][];
    metadata: TemplateMetadata | null;
    created_at: string;
  }
  
  let savedTemplates: SavedTemplate[] = [];
  let selectedTemplateId: string | null = null;
  
  interface TemplateMetadata {
    first_page_width: number;
    first_page_height: number;
    sub_page_width: number;
    sub_page_height: number;
  }
  
  interface ProductField {
    id: string;
    number: number;
    x: number;
    y: number;
    width: number;
    height: number;
    fields: FieldData[];
    pageNumber: number;
    pageOrder: number;
  }
  
  interface FieldData {
    id?: string;
    label?: string; // Field type label from configurator
    type?: 'product_name_en' | 'product_name_ar' | 'barcode' | 'price' | 'offer_price' | 'offer_qty' | 'limit_qty' | 'free_qty' | 'unit_name' | 'image' | 'expire_date' | 'serial_number' | 'special_symbol';
    fontSize?: number;
    alignment?: 'left' | 'center' | 'right';
    color?: string;
    x?: number;
    y?: number;
    width?: number;
    height?: number;
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
  
  let firstPageFields: ProductField[] = [];
  let subPageFieldsArray: ProductField[][] = [];
  let nextFieldNumber = 1;
  let selectedFieldId: string | null = null;
  let activeTab: 'first' | 'sub' = 'first';
  let activeSubPageIndex: number = 0;
  let isDragging = false;
  let isResizing = false;
  let dragStartX = 0;
  let dragStartY = 0;
  let resizeHandle = '';
  
  function handleFirstPageUpload(event: Event) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];
    
    if (file && file.type.startsWith('image/')) {
      firstPageFile = file;
      const reader = new FileReader();
      reader.onload = (e) => {
        firstPageImage = e.target?.result as string;
      };
      reader.readAsDataURL(file);
    }
  }
  
  function handleSubPageUpload(event: Event, pageIndex: number) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];
    
    if (file && file.type.startsWith('image/')) {
      subPageFiles[pageIndex] = file;
      const reader = new FileReader();
      reader.onload = (e) => {
        subPageImages[pageIndex] = e.target?.result as string;
        subPageImages = [...subPageImages];
      };
      reader.readAsDataURL(file);
    }
  }
  
  function addSubPage() {
    subPageImages = [...subPageImages, null];
    subPageFiles = [...subPageFiles, null];
    subPageFieldsArray = [...subPageFieldsArray, []];
    activeTab = 'sub';
    activeSubPageIndex = subPageImages.length - 1;
  }
  
  function removeSubPage(index: number) {
    subPageImages = subPageImages.filter((_, i) => i !== index);
    subPageFiles = subPageFiles.filter((_, i) => i !== index);
    subPageFieldsArray = subPageFieldsArray.filter((_, i) => i !== index);
    if (activeSubPageIndex >= subPageImages.length) {
      activeSubPageIndex = Math.max(0, subPageImages.length - 1);
    }
    if (subPageImages.length === 0) {
      activeTab = 'first';
    }
  }
  
  async function loadSavedTemplates() {
    isLoading = true;
    try {
      const { data, error } = await supabase
        .from('flyer_templates')
        .select('id, name, description, created_at')
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

  async function saveTemplate() {
    if (!templateName || !firstPageImage || subPageImages.length === 0) {
      alert('Please fill in template name and upload all required images');
      return;
    }

    isUploading = true;
    try {
      // Upload first page image
      let firstPageUrl = firstPageImage;
      if (firstPageFile) {
        const firstPageFileName = `first-page-${Date.now()}-${firstPageFile.name}`;
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('flyer-templates')
          .upload(firstPageFileName, firstPageFile, {
            contentType: firstPageFile.type,
            upsert: false
          });

        if (uploadError) throw uploadError;

        const { data: { publicUrl } } = supabase.storage
          .from('flyer-templates')
          .getPublicUrl(uploadData.path);
        
        firstPageUrl = publicUrl;
      }

      // Upload sub-page images
      const subPageUrls: string[] = [];
      for (let i = 0; i < subPageImages.length; i++) {
        if (subPageFiles[i]) {
          const subPageFileName = `sub-page-${i + 1}-${Date.now()}-${subPageFiles[i].name}`;
          const { data: uploadData, error: uploadError } = await supabase.storage
            .from('flyer-templates')
            .upload(subPageFileName, subPageFiles[i], {
              contentType: subPageFiles[i].type,
              upsert: false
            });

          if (uploadError) throw uploadError;

          const { data: { publicUrl } } = supabase.storage
            .from('flyer-templates')
            .getPublicUrl(uploadData.path);
          
          subPageUrls.push(publicUrl);
        } else {
          subPageUrls.push(subPageImages[i]);
        }
      }

      // Get current user ID
      const { data: { user } } = await supabase.auth.getUser();

      // Save template to database
      const templateData = {
        name: templateName,
        description: templateDescription || null,
        first_page_image_url: firstPageUrl,
        sub_page_image_urls: subPageUrls,
        first_page_configuration: firstPageFields,
        sub_page_configurations: subPageFieldsArray,
        metadata: {
          first_page_width: 794,
          first_page_height: 1123,
          sub_page_width: 794,
          sub_page_height: 1123
        },
        is_active: true,
        is_default: false,
        created_by: user?.id,
        updated_by: user?.id
      };

      let result;
      if (selectedTemplateId) {
        // Update existing template
        result = await supabase
          .from('flyer_templates')
          .update({
            ...templateData,
            updated_by: user?.id
          })
          .eq('id', selectedTemplateId)
          .select()
          .single();
      } else {
        // Insert new template
        result = await supabase
          .from('flyer_templates')
          .insert(templateData)
          .select()
          .single();
      }

      if (result.error) throw result.error;

      alert('✅ Template saved successfully!');
      await loadSavedTemplates();
      selectedTemplateId = result.data.id;
    } catch (error) {
      console.error('Error saving template:', error);
      alert('❌ Failed to save template: ' + error.message);
    } finally {
      isUploading = false;
    }
  }
  
  async function selectTemplate(templateId: string) {
    isLoading = true;
    try {
      const { data: template, error } = await supabase
        .from('flyer_templates')
        .select('*')
        .eq('id', templateId)
        .single();
      
      if (error) throw error;
      if (!template) return;
    
      selectedTemplateId = templateId;
      templateName = template.name;
      templateDescription = template.description || '';
      firstPageImage = template.first_page_image_url;
    
    // Load sub-page arrays
    if (template.sub_page_image_urls && Array.isArray(template.sub_page_image_urls)) {
      subPageImages = template.sub_page_image_urls;
    } else if (template.sub_page_image_url) {
      // Backward compatibility: convert single sub-page to array
      subPageImages = [template.sub_page_image_url];
    }
    
    if (template.sub_page_configurations && Array.isArray(template.sub_page_configurations)) {
      subPageFieldsArray = template.sub_page_configurations;
    } else if (template.sub_page_configuration) {
      // Backward compatibility: convert single sub-page to array
      subPageFieldsArray = [template.sub_page_configuration];
    }
    
    firstPageFields = template.first_page_configuration || [];
    
    // Update nextFieldNumber
    const allFields = [...firstPageFields, ...subPageFieldsArray.flat()];
    const maxNumber = allFields.reduce((max, field) => Math.max(max, field.number), 0);
    nextFieldNumber = maxNumber + 1;
    } catch (error) {
      console.error('Error loading template:', error);
    } finally {
      isLoading = false;
    }
  }
  
  function newTemplate() {
    selectedTemplateId = null;
    templateName = '';
    templateDescription = '';
    firstPageImage = null;
    subPageImages = [];
    firstPageFile = null;
    subPageFiles = [];
    firstPageFields = [];
    subPageFieldsArray = [];
    activeSubPageIndex = 0;
    nextFieldNumber = 1;
    selectedFieldId = null;
  }
  
  function addProductField() {
    const currentFields = activeTab === 'first' ? firstPageFields : (subPageFieldsArray[activeSubPageIndex] || []);
    const maxOrder = currentFields.reduce((max, f) => Math.max(max, f.pageOrder || 0), 0);
    const currentPage = activeTab === 'first' ? 1 : activeSubPageIndex + 2;
    
    const newField: ProductField = {
      id: `field-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      number: nextFieldNumber++,
      x: 50,
      y: 50,
      width: 150,
      height: 150,
      fields: [],
      pageNumber: currentPage,
      pageOrder: maxOrder + 1
    };
    
    if (activeTab === 'first') {
      firstPageFields = [...firstPageFields, newField];
    } else {
      if (!subPageFieldsArray[activeSubPageIndex]) {
        subPageFieldsArray[activeSubPageIndex] = [];
      }
      subPageFieldsArray[activeSubPageIndex] = [...subPageFieldsArray[activeSubPageIndex], newField];
      subPageFieldsArray = [...subPageFieldsArray];
    }
    
    selectedFieldId = newField.id;
  }
  
  function addSpecialSymbol() {
    const currentPage = activeTab === 'first' ? 1 : activeSubPageIndex + 2;
    
    const newField: ProductField = {
      id: `symbol-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      number: nextFieldNumber++,
      x: 100,
      y: 100,
      width: 100,
      height: 100,
      fields: [{
        type: 'special_symbol',
        fontSize: 16,
        alignment: 'center'
      }],
      pageNumber: currentPage,
      pageOrder: 0
    };
    
    if (activeTab === 'first') {
      firstPageFields = [...firstPageFields, newField];
    } else {
      if (!subPageFieldsArray[activeSubPageIndex]) {
        subPageFieldsArray[activeSubPageIndex] = [];
      }
      subPageFieldsArray[activeSubPageIndex] = [...subPageFieldsArray[activeSubPageIndex], newField];
      subPageFieldsArray = [...subPageFieldsArray];
    }
    
    selectedFieldId = newField.id;
  }
  
  function selectField(fieldId: string) {
    selectedFieldId = fieldId;
  }
  
  function deleteField(fieldId: string) {
    if (activeTab === 'first') {
      firstPageFields = firstPageFields.filter(f => f.id !== fieldId);
    } else {
      if (subPageFieldsArray[activeSubPageIndex]) {
        subPageFieldsArray[activeSubPageIndex] = subPageFieldsArray[activeSubPageIndex].filter(f => f.id !== fieldId);
        subPageFieldsArray = [...subPageFieldsArray];
      }
    }
    
    if (selectedFieldId === fieldId) {
      selectedFieldId = null;
    }
  }
  
  function duplicateField(fieldId: string) {
    const fields = activeTab === 'first' ? firstPageFields : (subPageFieldsArray[activeSubPageIndex] || []);
    const fieldToCopy = fields.find(f => f.id === fieldId);
    if (!fieldToCopy) return;
    
    // Create a copy with new ID and number, offset position slightly
    const maxOrder = fields.reduce((max, f) => Math.max(max, f.pageOrder || 0), 0);
    
    const newField: ProductField = {
      id: `field-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      number: nextFieldNumber++,
      x: Math.min(fieldToCopy.x + 20, 794 - fieldToCopy.width),
      y: Math.min(fieldToCopy.y + 20, 1123 - fieldToCopy.height),
      width: fieldToCopy.width,
      height: fieldToCopy.height,
      fields: JSON.parse(JSON.stringify(fieldToCopy.fields)), // Deep copy of field configurations
      pageNumber: fieldToCopy.pageNumber || 1,
      pageOrder: maxOrder + 1
    };
    
    if (activeTab === 'first') {
      firstPageFields = [...firstPageFields, newField];
    } else {
      if (!subPageFieldsArray[activeSubPageIndex]) {
        subPageFieldsArray[activeSubPageIndex] = [];
      }
      subPageFieldsArray[activeSubPageIndex] = [...subPageFieldsArray[activeSubPageIndex], newField];
      subPageFieldsArray = [...subPageFieldsArray];
    }
    
    selectedFieldId = newField.id;
  }
  
  function updateField(fieldId: string, updates: Partial<ProductField>) {
    if (activeTab === 'first') {
      firstPageFields = firstPageFields.map(f => 
        f.id === fieldId ? { ...f, ...updates } : f
      );
    } else {
      if (!subPageFieldsArray[activeSubPageIndex]) {
        subPageFieldsArray[activeSubPageIndex] = [];
      }
      subPageFieldsArray[activeSubPageIndex] = subPageFieldsArray[activeSubPageIndex].map(f => 
        f.id === fieldId ? { ...f, ...updates } : f
      );
      subPageFieldsArray = [...subPageFieldsArray];
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
    
    const fields = activeTab === 'first' ? firstPageFields : (subPageFieldsArray[activeSubPageIndex] || []);
    const field = fields.find(f => f.id === selectedFieldId);
    if (!field) return;
    
    const maxWidth = 794;
    const maxHeight = 1123;
    
    if (isDragging) {
      const newX = Math.max(0, Math.min(maxWidth - field.width, field.x + deltaX));
      const newY = Math.max(0, Math.min(maxHeight - field.height, field.y + deltaY));
      updateField(selectedFieldId, { x: newX, y: newY });
    } else if (isResizing) {
      if (resizeHandle === 'se') {
        const newWidth = Math.max(50, Math.min(maxWidth - field.x, field.width + deltaX));
        const newHeight = Math.max(50, Math.min(maxHeight - field.y, field.height + deltaY));
        updateField(selectedFieldId, { width: newWidth, height: newHeight });
      } else if (resizeHandle === 'e') {
        const newWidth = Math.max(50, Math.min(maxWidth - field.x, field.width + deltaX));
        updateField(selectedFieldId, { width: newWidth });
      } else if (resizeHandle === 's') {
        const newHeight = Math.max(50, Math.min(maxHeight - field.y, field.height + deltaY));
        updateField(selectedFieldId, { height: newHeight });
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
  
  function handleFieldDoubleClick(field: ProductField) {
    // Open field configuration window
    openWindow({
      id: `flyer-field-config-${field.id}`,
      title: `Configure Product Field #${field.number}`,
      component: ProductFieldConfiguratorFlyer,
      props: {
        field: field,
        onSave: (updatedFields: FieldData[]) => {
          updateField(field.id, { fields: updatedFields });
        }
      },
      icon: '⚙️',
      size: { width: 1000, height: 700 },
      position: { x: 100, y: 100 },
      resizable: true,
      minimizable: true,
      maximizable: true,
      closable: true
    });
  }
  
  function handleKeyDown(event: KeyboardEvent) {
    if (!selectedFieldId) return;
    
    const fields = activeTab === 'first' ? firstPageFields : (subPageFieldsArray[activeSubPageIndex] || []);
    const field = fields.find(f => f.id === selectedFieldId);
    if (!field) return;
    
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(event.key)) {
      event.preventDefault();
    }
    
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
      case 'Delete':
        deleteField(selectedFieldId);
        break;
    }
  }
  
  onMount(() => {
    window.addEventListener('keydown', handleKeyDown);
    loadSavedTemplates();
    
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      handleMouseUp();
    };
  });
</script>

<div class="flyer-designer">
  <div class="header">
    <h2 class="text-2xl font-bold text-gray-800">Flyer Template Designer</h2>
    <p class="text-sm text-gray-600 mt-1">Create and manage flyer templates with first page and sub-page layouts</p>
  </div>

  <div class="content">
    <!-- Left Panel: Controls -->
    <div class="controls-panel">
      <!-- Load Template Section -->
      <div class="section">
        <h3 class="section-title">📂 Load Template</h3>
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
      
      <!-- Template Details Section -->
      <div class="section">
        <h3 class="section-title">📝 Template Details</h3>
        <label class="input-label">
          Template Name *
          <input 
            type="text" 
            bind:value={templateName} 
            placeholder="Enter template name (e.g., Weekly Specials)"
            class="text-input"
          />
        </label>
        <label class="input-label">
          Description
          <textarea 
            bind:value={templateDescription} 
            placeholder="Optional description for this template"
            class="text-input"
            rows="3"
          ></textarea>
        </label>
      </div>

      <!-- Template Image - First Page -->
      <div class="section">
        <h3 class="section-title">🖼️ Template Image - First Page</h3>
        <div class="upload-area">
          {#if !firstPageImage}
            <label class="upload-label">
              <input type="file" accept="image/*" on:change={handleFirstPageUpload} hidden />
              <div class="upload-placeholder">
                <span class="upload-icon">📤</span>
                <span class="upload-text">Click to upload first page template</span>
                <span class="upload-hint">Recommended: A4 size (794×1123px)</span>
              </div>
            </label>
          {:else}
            <div class="uploaded-preview">
              <img src={firstPageImage} alt="First Page Template" />
              <button class="change-btn" on:click={() => { firstPageImage = null; firstPageFile = null; }}>
                🔄 Change Image
              </button>
            </div>
          {/if}
        </div>
      </div>

      <!-- Template Image - Sub Pages -->
      <div class="section">
        <div class="section-header-with-button">
          <h3 class="section-title">🖼️ Template Images - Sub Pages ({subPageImages.length})</h3>
          <button class="add-page-btn" on:click={addSubPage}>
            ➕ Add Sub Page
          </button>
        </div>
        
        {#if subPageImages.length === 0}
          <p class="no-pages-text">No sub pages yet. Click "Add Sub Page" to create one.</p>
        {:else}
          {#each subPageImages as subPageImage, index}
            <div class="sub-page-item">
              <div class="sub-page-header">
                <span class="sub-page-title">Sub Page {index + 1}</span>
                <button class="remove-page-btn" on:click={() => removeSubPage(index)} title="Remove this page">
                  🗑️
                </button>
              </div>
              <div class="upload-area">
                {#if !subPageImage}
                  <label class="upload-label">
                    <input type="file" accept="image/*" on:change={(e) => handleSubPageUpload(e, index)} hidden />
                    <div class="upload-placeholder-small">
                      <span class="upload-icon-small">📤</span>
                      <span class="upload-text-small">Upload sub page {index + 1}</span>
                    </div>
                  </label>
                {:else}
                  <div class="uploaded-preview-small">
                    <img src={subPageImage} alt="Sub Page {index + 1}" />
                    <button class="change-btn-small" on:click={() => { subPageImages[index] = null; subPageFiles[index] = null; subPageImages = [...subPageImages]; }}>
                      🔄
                    </button>
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        {/if}
      </div>

      <!-- Action Buttons -->
      <div class="section">
        <button 
          class="add-field-btn" 
          on:click={addProductField} 
          disabled={activeTab === 'first' ? !firstPageImage : !subPageImages[activeSubPageIndex]}
        >
          ➕ Add Product Field
        </button>
        
        <button 
          class="add-symbol-btn" 
          on:click={addSpecialSymbol} 
          disabled={activeTab === 'first' ? !firstPageImage : !subPageImages[activeSubPageIndex]}
        >
          🎨 Add Special Symbol
        </button>
        
        <div class="fields-list">
          <h4 class="fields-list-title">
            {activeTab === 'first' ? 'First Page' : `Sub Page ${activeSubPageIndex + 1}`} Fields ({activeTab === 'first' ? firstPageFields.length : (subPageFieldsArray[activeSubPageIndex] || []).length})
          </h4>
          {#each (activeTab === 'first' ? firstPageFields : (subPageFieldsArray[activeSubPageIndex] || [])) as field}
            <div 
              class="field-item {selectedFieldId === field.id ? 'selected' : ''}"
              on:click={() => selectField(field.id)}
            >
              <div class="field-header">
                <span class="field-number">{field.pageNumber || 1}:{field.pageOrder || 1}</span>
                <span class="field-info">{field.width}×{field.height}px</span>
                <div class="field-actions">
                  <button 
                    class="action-btn duplicate-btn" 
                    on:click|stopPropagation={() => duplicateField(field.id)}
                    title="Duplicate field"
                  >
                    📋
                  </button>
                  <button 
                    class="action-btn delete-btn" 
                    on:click|stopPropagation={() => deleteField(field.id)}
                    title="Delete field"
                  >
                    🗑️
                  </button>
                </div>
              </div>
              
              <!-- Page & Order inputs -->
              <div class="field-page-order-inputs" on:click|stopPropagation>
                <label class="page-order-label">
                  📄 Page
                  <input 
                    type="number" 
                    min="1" 
                    value={field.pageNumber || 1}
                    on:change={(e) => updateField(field.id, { pageNumber: parseInt(e.target.value) || 1 })}
                    class="page-order-input"
                  />
                </label>
                <label class="page-order-label">
                  🔢 Order
                  <input 
                    type="number" 
                    min="1" 
                    value={field.pageOrder || 1}
                    on:change={(e) => updateField(field.id, { pageOrder: parseInt(e.target.value) || 1 })}
                    class="page-order-input"
                  />
                </label>
              </div>
              
              {#if field.fields.length > 0}
                <div class="field-tags">
                  {#each field.fields.slice(0, 3) as subField}
                    <span class="field-tag">{subField.type}</span>
                  {/each}
                  {#if field.fields.length > 3}
                    <span class="field-tag more">+{field.fields.length - 3}</span>
                  {/if}
                </div>
              {:else}
                <div class="field-empty">No fields configured</div>
              {/if}
            </div>
          {/each}
        </div>
        
        <button class="save-btn" on:click={saveTemplate} disabled={!templateName || !firstPageImage || isUploading}>
          {isUploading ? '⏳ Saving...' : '💾 Save Template'}
        </button>
      </div>
    </div>

    <!-- Right Panel: Preview -->
    <div class="preview-panel">
      <h3 class="section-title">👁️ Template Preview</h3>
      
      <div class="preview-tabs">
        <div class="tabs-header">
          <button 
            class="tab-btn {activeTab === 'first' ? 'active' : ''}"
            on:click={() => activeTab = 'first'}
          >
            📄 First Page
          </button>
          {#if subPageImages.length > 0}
            {#each subPageImages as _, index}
              <button 
                class="tab-btn {activeTab === 'sub' && activeSubPageIndex === index ? 'active' : ''}"
                on:click={() => { activeTab = 'sub'; activeSubPageIndex = index; }}
              >
                📑 Sub Page {index + 1}
              </button>
            {/each}
          {/if}
        </div>
        
        <div class="preview-content">
          {#if activeTab === 'first'}
            <div class="preview-container">
              {#if firstPageImage}
                <div class="preview-wrapper">
                  <img src={firstPageImage} alt="First Page Preview" class="preview-image" />
                  
                  {#each firstPageFields as field}
                    <div
                      class="product-field {selectedFieldId === field.id ? 'selected' : ''}"
                      style="left: {field.x}px; top: {field.y}px; width: {field.width}px; height: {field.height}px;"
                      on:mousedown={(e) => handleMouseDown(e, field.id)}
                      on:dblclick={() => handleFieldDoubleClick(field)}
                    >
                      {#if !field.fields || field.fields.length === 0}
                        <span class="field-number-badge">{field.pageNumber || 1}:{field.pageOrder || 1}</span>
                      {/if}
                      
                      <!-- Preview configured fields inside container -->
                      {#if field.fields && field.fields.length > 0}
                        <!-- Check if this is a special symbol field (should fill container) -->
                        {#if field.fields.length === 1 && field.fields[0].label === 'special_symbol' && field.fields[0].symbolUrl}
                          <!-- Special Symbol fills entire container -->
                          <img 
                            src={field.fields[0].symbolUrl} 
                            alt="Special Symbol" 
                            class="field-symbol-full-preview"
                            style="
                              width: 100%;
                              height: 100%;
                              object-fit: contain;
                            "
                          />
                        {:else}
                          <!-- Normal fields with positioning -->
                          <div class="field-preview-content">
                            {#each field.fields as configField}
                              <div 
                                class="preview-field-item"
                                style="
                                  left: {configField.x || 0}px; 
                                  top: {configField.y || 0}px; 
                                  width: {configField.width || 100}px; 
                                  height: {configField.height || 20}px;
                                  font-size: {configField.fontSize || 14}px;
                                  color: {configField.color || '#000000'};
                                  text-align: {configField.alignment || 'left'};
                                "
                              >
                                <!-- Background Icon (behind text) -->
                                {#if configField.iconUrl}
                                  <img 
                                    src={configField.iconUrl} 
                                    alt="Icon" 
                                    class="field-icon-preview"
                                    style="
                                      left: {configField.iconX || 0}px;
                                      top: {configField.iconY || 0}px;
                                      width: {configField.iconWidth || 30}px;
                                      height: {configField.iconHeight || 30}px;
                                    "
                                  />
                                {/if}
                                
                                <!-- Text Label (for non-symbol fields) -->
                                {#if configField.label !== 'special_symbol'}
                                  <span class="field-label-preview">
                                    {#if configField.label === 'product_name_en'}Product Name (EN)
                                    {:else if configField.label === 'product_name_ar'}اسم المنتج
                                    {:else if configField.label === 'price'}$99.99
                                    {:else if configField.label === 'offer_price'}$79.99
                                    {:else if configField.label === 'offer_qty'}2 for 1
                                    {:else if configField.label === 'unit_name'}Box
                                    {:else if configField.label === 'image'}🖼️
                                    {:else}{configField.label}
                                    {/if}
                                  </span>
                                {/if}
                              </div>
                            {/each}
                          </div>
                        {/if}
                      {/if}
                      
                      {#if selectedFieldId === field.id}
                        <!-- Position indicators -->
                        <div class="position-indicator top-indicator" style="top: -25px; left: 0;">
                          X: {field.x}px
                        </div>
                        <div class="position-indicator left-indicator" style="left: -80px; top: 0;">
                          Y: {field.y}px
                        </div>
                        
                        <!-- Size indicators -->
                        <div class="size-indicator width-indicator" style="bottom: -25px; left: 50%; transform: translateX(-50%);">
                          W: {field.width}px
                        </div>
                        <div class="size-indicator height-indicator" style="right: -80px; top: 50%; transform: translateY(-50%);">
                          H: {field.height}px
                        </div>
                        
                        <!-- Distance lines to other fields -->
                        {#each firstPageFields as otherField}
                          {#if otherField.id !== field.id}
                            <!-- Horizontal distance (X-axis) -->
                            {#if Math.abs((otherField.x + otherField.width/2) - (field.x + field.width/2)) > 5}
                              <div 
                                class="distance-line horizontal-line"
                                style="
                                  left: {Math.min(field.x + field.width/2, otherField.x + otherField.width/2) - field.x}px;
                                  top: {field.height + 5}px;
                                  width: {Math.abs((otherField.x + otherField.width/2) - (field.x + field.width/2))}px;
                                "
                              >
                                <span class="distance-label">
                                  {Math.round(Math.abs((otherField.x + otherField.width/2) - (field.x + field.width/2)))}px
                                </span>
                              </div>
                            {/if}
                            
                            <!-- Vertical distance (Y-axis) -->
                            {#if Math.abs((otherField.y + otherField.height/2) - (field.y + field.height/2)) > 5}
                              <div 
                                class="distance-line vertical-line"
                                style="
                                  left: {field.width + 5}px;
                                  top: {Math.min(field.y + field.height/2, otherField.y + otherField.height/2) - field.y}px;
                                  height: {Math.abs((otherField.y + otherField.height/2) - (field.y + field.height/2))}px;
                                "
                              >
                                <span class="distance-label">
                                  {Math.round(Math.abs((otherField.y + otherField.height/2) - (field.y + field.height/2)))}px
                                </span>
                              </div>
                            {/if}
                          {/if}
                        {/each}
                        
                        <div class="resize-handle resize-se" on:mousedown={(e) => handleMouseDown(e, field.id, 'se')}></div>
                        <div class="resize-handle resize-e" on:mousedown={(e) => handleMouseDown(e, field.id, 'e')}></div>
                        <div class="resize-handle resize-s" on:mousedown={(e) => handleMouseDown(e, field.id, 's')}></div>
                      {/if}
                    </div>
                  {/each}
                </div>
              {:else}
                <div class="preview-placeholder">
                  <div class="placeholder-content">
                    <span class="placeholder-icon">📄</span>
                    <p class="placeholder-text">First Page Preview</p>
                    <p class="placeholder-hint">Upload an image to see preview</p>
                  </div>
                </div>
              {/if}
            </div>
          {:else}
            <div class="preview-container">
              {#if subPageImages[activeSubPageIndex]}
                <div class="preview-wrapper">
                  <img src={subPageImages[activeSubPageIndex]} alt="Sub Page {activeSubPageIndex + 1} Preview" class="preview-image" />
                  
                  {#each (subPageFieldsArray[activeSubPageIndex] || []) as field}
                    <div
                      class="product-field {selectedFieldId === field.id ? 'selected' : ''}"
                      style="left: {field.x}px; top: {field.y}px; width: {field.width}px; height: {field.height}px;"
                      on:mousedown={(e) => handleMouseDown(e, field.id)}
                      on:dblclick={() => handleFieldDoubleClick(field)}
                    >
                      {#if !field.fields || field.fields.length === 0}
                        <span class="field-number-badge">{field.pageNumber || 1}:{field.pageOrder || 1}</span>
                      {/if}
                      
                      <!-- Preview configured fields inside container -->
                      {#if field.fields && field.fields.length > 0}
                        <!-- Check if this is a special symbol field (should fill container) -->
                        {#if field.fields.length === 1 && field.fields[0].label === 'special_symbol' && field.fields[0].symbolUrl}
                          <!-- Special Symbol fills entire container -->
                          <img 
                            src={field.fields[0].symbolUrl} 
                            alt="Special Symbol" 
                            class="field-symbol-full-preview"
                            style="
                              width: 100%;
                              height: 100%;
                              object-fit: contain;
                            "
                          />
                        {:else}
                          <!-- Normal fields with positioning -->
                          <div class="field-preview-content">
                            {#each field.fields as configField}
                              <div 
                                class="preview-field-item"
                                style="
                                  left: {configField.x || 0}px; 
                                  top: {configField.y || 0}px; 
                                  width: {configField.width || 100}px; 
                                  height: {configField.height || 20}px;
                                  font-size: {configField.fontSize || 14}px;
                                  color: {configField.color || '#000000'};
                                  text-align: {configField.alignment || 'left'};
                                "
                              >
                                <!-- Background Icon (behind text) -->
                                {#if configField.iconUrl}
                                  <img 
                                    src={configField.iconUrl} 
                                    alt="Icon" 
                                    class="field-icon-preview"
                                    style="
                                      left: {configField.iconX || 0}px;
                                      top: {configField.iconY || 0}px;
                                      width: {configField.iconWidth || 30}px;
                                      height: {configField.iconHeight || 30}px;
                                    "
                                  />
                                {/if}
                                
                                <!-- Text Label (for non-symbol fields) -->
                                {#if configField.label !== 'special_symbol'}
                                  <span class="field-label-preview">
                                    {#if configField.label === 'product_name_en'}Product Name (EN)
                                    {:else if configField.label === 'product_name_ar'}اسم المنتج
                                    {:else if configField.label === 'price'}$99.99
                                    {:else if configField.label === 'offer_price'}$79.99
                                    {:else if configField.label === 'offer_qty'}2 for 1
                                    {:else if configField.label === 'unit_name'}Box
                                    {:else if configField.label === 'image'}🖼️
                                    {:else}{configField.label}
                                    {/if}
                                  </span>
                                {/if}
                              </div>
                            {/each}
                          </div>
                        {/if}
                      {/if}
                      
                      {#if selectedFieldId === field.id}
                        <!-- Position indicators -->
                        <div class="position-indicator top-indicator" style="top: -25px; left: 0;">
                          X: {field.x}px
                        </div>
                        <div class="position-indicator left-indicator" style="left: -80px; top: 0;">
                          Y: {field.y}px
                        </div>
                        
                        <!-- Size indicators -->
                        <div class="size-indicator width-indicator" style="bottom: -25px; left: 50%; transform: translateX(-50%);">
                          W: {field.width}px
                        </div>
                        <div class="size-indicator height-indicator" style="right: -80px; top: 50%; transform: translateY(-50%);">
                          H: {field.height}px
                        </div>
                        
                        <!-- Distance lines to other fields -->
                        {#each (subPageFieldsArray[activeSubPageIndex] || []) as otherField}
                          {#if otherField.id !== field.id}
                            <!-- Horizontal distance (X-axis) -->
                            {#if Math.abs((otherField.x + otherField.width/2) - (field.x + field.width/2)) > 5}
                              <div 
                                class="distance-line horizontal-line"
                                style="
                                  left: {Math.min(field.x + field.width/2, otherField.x + otherField.width/2) - field.x}px;
                                  top: {field.height + 5}px;
                                  width: {Math.abs((otherField.x + otherField.width/2) - (field.x + field.width/2))}px;
                                "
                              >
                                <span class="distance-label">
                                  {Math.round(Math.abs((otherField.x + otherField.width/2) - (field.x + field.width/2)))}px
                                </span>
                              </div>
                            {/if}
                            
                            <!-- Vertical distance (Y-axis) -->
                            {#if Math.abs((otherField.y + otherField.height/2) - (field.y + field.height/2)) > 5}
                              <div 
                                class="distance-line vertical-line"
                                style="
                                  left: {field.width + 5}px;
                                  top: {Math.min(field.y + field.height/2, otherField.y + otherField.height/2) - field.y}px;
                                  height: {Math.abs((otherField.y + otherField.height/2) - (field.y + field.height/2))}px;
                                "
                              >
                                <span class="distance-label">
                                  {Math.round(Math.abs((otherField.y + otherField.height/2) - (field.y + field.height/2)))}px
                                </span>
                              </div>
                            {/if}
                          {/if}
                        {/each}
                        
                        <div class="resize-handle resize-se" on:mousedown={(e) => handleMouseDown(e, field.id, 'se')}></div>
                        <div class="resize-handle resize-e" on:mousedown={(e) => handleMouseDown(e, field.id, 'e')}></div>
                        <div class="resize-handle resize-s" on:mousedown={(e) => handleMouseDown(e, field.id, 's')}></div>
                      {/if}
                    </div>
                  {/each}
                </div>
              {:else}
                <div class="preview-placeholder">
                  <div class="placeholder-content">
                    <span class="placeholder-icon">📑</span>
                    <p class="placeholder-text">Sub Page {activeSubPageIndex + 1} Preview</p>
                    <p class="placeholder-hint">Upload an image to see preview</p>
                  </div>
                </div>
              {/if}
            </div>
          {/if}
          
          <div class="preview-hint">
            💡 Tip: Click to select field, drag to move, use corners to resize. Double-click to configure product data fields.
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .flyer-designer {
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
    grid-template-columns: 380px 1fr;
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
    padding-bottom: 1.5rem;
    border-bottom: 1px solid #f3f4f6;
  }

  .section:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .section-title {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .template-selector-row {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .template-select {
    flex: 1;
    padding: 0.625rem 0.75rem;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 0.875rem;
    background: white;
    cursor: pointer;
    transition: all 0.2s;
  }

  .template-select:hover:not(:disabled) {
    border-color: #3b82f6;
  }

  .template-select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .template-select:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .new-template-btn {
    padding: 0.625rem 1rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(16, 185, 129, 0.2);
  }

  .new-template-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
  }

  .template-info {
    margin-top: 0.75rem;
    padding: 0.75rem;
    background: #f0f9ff;
    border: 1px solid #bfdbfe;
    border-radius: 8px;
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

  .input-label:last-child {
    margin-bottom: 0;
  }

  .text-input {
    padding: 0.625rem 0.75rem;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 0.875rem;
    resize: vertical;
    transition: all 0.2s;
  }

  .text-input:hover {
    border-color: #3b82f6;
  }

  .text-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .upload-area {
    border: 2px dashed #d1d5db;
    border-radius: 8px;
    overflow: hidden;
    transition: all 0.2s;
  }

  .upload-area:hover {
    border-color: #3b82f6;
    background: #f9fafb;
  }

  .upload-label {
    display: block;
    cursor: pointer;
  }

  .upload-placeholder {
    padding: 2.5rem 1rem;
    text-align: center;
    color: #6b7280;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    transition: all 0.2s;
  }

  .upload-label:hover .upload-placeholder {
    color: #3b82f6;
  }

  .upload-icon {
    font-size: 3rem;
  }

  .upload-text {
    font-weight: 500;
    color: #374151;
  }

  .upload-hint {
    font-size: 0.75rem;
    color: #9ca3af;
  }

  .uploaded-preview {
    position: relative;
    max-height: 180px;
    overflow: hidden;
    background: #f9fafb;
  }

  .uploaded-preview img {
    width: 100%;
    height: 100%;
    display: block;
    object-fit: contain;
    max-height: 180px;
  }

  .change-btn {
    position: absolute;
    top: 0.75rem;
    right: 0.75rem;
    background: white;
    border: 2px solid #e5e7eb;
    padding: 0.5rem 1rem;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .change-btn:hover {
    background: #f3f4f6;
    border-color: #3b82f6;
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
  }

  .action-buttons {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
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
    box-shadow: 0 2px 4px rgba(16, 185, 129, 0.2);
    margin-bottom: 0.5rem;
  }

  .add-field-btn:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
  }

  .add-field-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .add-symbol-btn {
    width: 100%;
    padding: 0.75rem;
    background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(139, 92, 246, 0.2);
    margin-bottom: 1rem;
  }

  .add-symbol-btn:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(139, 92, 246, 0.3);
  }

  .add-symbol-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .fields-list {
    margin-bottom: 1rem;
  }

  .fields-list-title {
    font-size: 0.875rem;
    font-weight: 600;
    color: #6b7280;
    margin-bottom: 0.75rem;
  }

  .field-item {
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    padding: 0.75rem;
    margin-bottom: 0.5rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .field-item:hover {
    border-color: #3b82f6;
    background: #f9fafb;
  }

  .field-item.selected {
    border-color: #3b82f6;
    background: #eff6ff;
  }

  .field-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.5rem;
  }

  .field-number {
    font-weight: 700;
    color: #3b82f6;
    font-size: 1rem;
  }

  .field-info {
    flex: 1;
    font-size: 0.75rem;
    color: #6b7280;
  }

  .field-actions {
    display: flex;
    gap: 0.25rem;
  }

  .action-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 1rem;
    padding: 0.25rem;
    opacity: 0.6;
    transition: all 0.2s;
    border-radius: 4px;
  }

  .action-btn:hover {
    opacity: 1;
    background: rgba(0, 0, 0, 0.05);
  }

  .duplicate-btn:hover {
    background: rgba(59, 130, 246, 0.1);
  }

  .delete-btn:hover {
    background: rgba(239, 68, 68, 0.1);
  }

  .field-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
  }

  .field-tag {
    background: #dbeafe;
    color: #1e40af;
    padding: 0.125rem 0.5rem;
    border-radius: 4px;
    font-size: 0.625rem;
    font-weight: 600;
  }

  .field-tag.more {
    background: #f3f4f6;
    color: #6b7280;
  }

  .field-empty {
    font-size: 0.75rem;
    color: #9ca3af;
    font-style: italic;
  }

  .field-page-order-inputs {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 0.5rem;
    padding: 0.375rem;
    background: #f9fafb;
    border-radius: 6px;
    border: 1px solid #e5e7eb;
  }

  .page-order-label {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.7rem;
    font-weight: 600;
    color: #6b7280;
    flex: 1;
  }

  .page-order-input {
    width: 50px;
    padding: 0.25rem 0.375rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.75rem;
    text-align: center;
    background: white;
    transition: all 0.2s;
  }

  .page-order-input:focus {
    outline: none;
    border-color: #7c3aed;
    box-shadow: 0 0 0 2px rgba(124, 58, 237, 0.15);
  }

  .page-order-input:hover {
    border-color: #7c3aed;
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
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
  }

  .save-btn:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 6px 12px rgba(59, 130, 246, 0.4);
  }

  .save-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none;
  }

  .preview-tabs {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

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
    overflow: hidden;
  }

  .preview-tab-container {
    flex: 1;
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    overflow: hidden;
  }

  .preview-section {
    display: flex;
    flex-direction: column;
    overflow: hidden;
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

  .preview-badge.empty {
    background: linear-gradient(135deg, #9ca3af 0%, #6b7280 100%);
  }

  .preview-container {
    flex: 1;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    overflow: auto;
    background: #f9fafb;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding: 1rem;
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
    cursor: move;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    box-sizing: border-box;
    z-index: 10;
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

  .preview-hint {
    margin-top: 1rem;
    padding: 0.75rem 1rem;
    background: #eff6ff;
    border: 1px solid #bfdbfe;
    border-radius: 8px;
    font-size: 0.875rem;
    color: #1e40af;
    text-align: center;
  }

  .position-indicator,
  .size-indicator {
    position: absolute;
    background: #1e40af;
    color: white;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
    white-space: nowrap;
    pointer-events: none;
    z-index: 30;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  .position-indicator {
    background: #059669;
  }

  .size-indicator {
    background: #7c3aed;
  }

  .distance-line {
    position: absolute;
    pointer-events: none;
    z-index: 25;
  }

  .horizontal-line {
    border-top: 2px dashed #f59e0b;
    height: 0;
  }

  .vertical-line {
    border-left: 2px dashed #f59e0b;
    width: 0;
  }

  .distance-label {
    position: absolute;
    background: #f59e0b;
    color: white;
    padding: 0.125rem 0.5rem;
    border-radius: 3px;
    font-size: 0.625rem;
    font-weight: 700;
    white-space: nowrap;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
  }

  .horizontal-line .distance-label {
    top: -12px;
    left: 50%;
    transform: translateX(-50%);
  }

  .vertical-line .distance-label {
    left: -30px;
    top: 50%;
    transform: translateY(-50%);
  }

  .field-preview-content {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: 5;
    overflow: visible;
  }

  .preview-field-item {
    position: absolute;
    display: flex;
    align-items: center;
    justify-content: flex-start;
    overflow: visible;
    pointer-events: none;
  }

  .field-label-preview {
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    background: rgba(255, 255, 255, 0.95);
    padding: 4px 8px;
    border-radius: 4px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.15);
    position: relative;
    z-index: 10;
    display: inline-block;
  }

  .field-icon-preview,
  .field-symbol-preview {
    position: absolute;
    object-fit: contain;
    z-index: 1;
    pointer-events: none;
  }

  .field-icon-preview {
    opacity: 0.8;
    filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.2));
  }

  .field-symbol-preview {
    opacity: 1;
    filter: drop-shadow(0 2px 6px rgba(0, 0, 0, 0.3));
  }

  .field-symbol-full-preview {
    width: 100%;
    height: 100%;
    object-fit: contain;
    pointer-events: none;
    position: absolute;
    top: 0;
    left: 0;
    z-index: 5;
  }

  .preview-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 400px;
  }

  .placeholder-content {
    text-align: center;
    color: #9ca3af;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.75rem;
  }

  .placeholder-icon {
    font-size: 4rem;
    opacity: 0.5;
  }

  .placeholder-text {
    font-weight: 600;
    font-size: 1.125rem;
    color: #6b7280;
    margin: 0;
  }

  .placeholder-hint {
    font-size: 0.875rem;
    color: #9ca3af;
    margin: 0;
  }

  /* Responsive adjustments */
  @media (max-width: 1400px) {
    .content {
      grid-template-columns: 350px 1fr;
    }
  }

  @media (max-width: 1200px) {
    .preview-tab-container {
      grid-template-columns: 1fr;
    }
  }

  /* Sub-page management styles */
  .section-header-with-button {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 0.75rem;
  }

  .add-page-btn {
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
  }

  .add-page-btn:hover {
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.4);
    transform: translateY(-1px);
  }

  .add-page-btn:active {
    transform: translateY(0);
  }

  .no-pages-text {
    text-align: center;
    color: #9ca3af;
    font-size: 0.875rem;
    padding: 2rem;
    background: #f9fafb;
    border-radius: 8px;
    border: 2px dashed #e5e7eb;
  }

  .sub-page-item {
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 0.75rem;
    margin-bottom: 0.75rem;
    transition: all 0.2s ease;
  }

  .sub-page-item:hover {
    border-color: #3b82f6;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.1);
  }

  .sub-page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.5rem;
  }

  .sub-page-title {
    font-weight: 600;
    color: #374151;
    font-size: 0.875rem;
  }

  .remove-page-btn {
    padding: 0.25rem 0.5rem;
    background: #ef4444;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 0.75rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .remove-page-btn:hover {
    background: #dc2626;
    transform: scale(1.05);
  }

  .upload-placeholder-small {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
    background: white;
    border: 2px dashed #d1d5db;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .upload-placeholder-small:hover {
    border-color: #3b82f6;
    background: #f0f9ff;
  }

  .upload-icon-small {
    font-size: 1.5rem;
    margin-bottom: 0.5rem;
  }

  .upload-text-small {
    font-size: 0.75rem;
    color: #6b7280;
    font-weight: 500;
  }

  .uploaded-preview-small {
    position: relative;
    border-radius: 6px;
    overflow: hidden;
    max-height: 120px;
  }

  .uploaded-preview-small img {
    width: 100%;
    height: auto;
    display: block;
  }

  .change-btn-small {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    padding: 0.375rem 0.75rem;
    background: rgba(0, 0, 0, 0.7);
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 0.75rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .change-btn-small:hover {
    background: rgba(0, 0, 0, 0.9);
  }
</style>
