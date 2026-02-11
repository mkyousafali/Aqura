<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { openWindow } from '$lib/utils/windowManagerUtils';
  import { notifications } from '$lib/stores/notifications';
  import ShelfPaperFontManager from '$lib/components/desktop-interface/marketing/flyer/ShelfPaperFontManager.svelte';
  
  let templateImage: string | null = null;
  let imageFile: File | null = null;
  let isUploading = false;
  let isLoading = false;
  let isLoadingFonts = false;
  let isInitialLoad = true;
  let loadingMessage = 'Loading...';
  let loadingPercent = 0;
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
    fontFamily: string;
  }
  
  interface TemplateMetadata {
    preview_width: number;
    preview_height: number;
  }
  
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
  let fontUploadCurrent = 0;
  let fontUploadTotal = 0;
  let fontFileInput: HTMLInputElement;
  let fieldSelectors: FieldSelector[] = [];
  let selectedFieldId: string | null = null;
  let nextFieldId = 1;
  let isDragging = false;
  let dragStartX = 0;
  let dragStartY = 0;
  let isResizing = false;
  let resizeHandle = '';
  let previewContainer: HTMLElement | null = null;
  
  // New Template Modal State
  let showNewTemplateModal = false;
  let showTemplateSelectionModal = false;
  let showTemplateNameInputModal = false;
  let selectedTemplateToCopy: string | null = null;
  let newTemplateNameInput: string = '';
  
  // Confirm dialog state
  let showConfirmDialog = false;
  let confirmDialogMessage = '';
  let confirmDialogTitle = '';
  let confirmDialogAction: (() => void) | null = null;
  
  function showConfirm(title: string, message: string, onConfirm: () => void) {
    confirmDialogTitle = title;
    confirmDialogMessage = message;
    confirmDialogAction = onConfirm;
    showConfirmDialog = true;
  }
  
  function handleConfirmYes() {
    showConfirmDialog = false;
    if (confirmDialogAction) confirmDialogAction();
    confirmDialogAction = null;
  }
  
  function handleConfirmNo() {
    showConfirmDialog = false;
    confirmDialogAction = null;
  }
  
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
    { value: 'product_expiry_date', label: 'Product Expiry Date' },
    { value: 'expire_date', label: 'Expire Date' },
    { value: 'offer_end_date', label: 'Offer End Date' },
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
      alignment: 'left',
      color: '#000000',
      fontFamily: ''
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
    loadInitialData();
    
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  });
  
  async function loadInitialData() {
    isInitialLoad = true;
    loadingPercent = 0;
    loadingMessage = 'Loading templates...';
    try {
      await loadSavedTemplates();
      loadingPercent = 40;
      loadingMessage = 'Loading fonts...';
      await loadCustomFonts();
      loadingPercent = 100;
    } finally {
      isInitialLoad = false;
    }
  }
  
  async function loadCustomFonts() {
    try {
      const { data, error } = await supabase
        .from('shelf_paper_fonts')
        .select('id, name, font_url, file_name, file_size, created_at')
        .order('name', { ascending: true });
      
      if (error) throw error;
      customFonts = data || [];
      loadingPercent = 60;
      
      // Register all custom fonts in parallel, track progress
      if (customFonts.length > 0) {
        let loaded = 0;
        const total = customFonts.length;
        await Promise.allSettled(
          customFonts.map(async (font) => {
            try {
              const fontFace = new FontFace(font.name, `url(${font.font_url})`);
              await fontFace.load();
              document.fonts.add(fontFace);
            } catch (e) {
              console.warn(`Failed to load font: ${font.name}`, e);
            } finally {
              loaded++;
              loadingPercent = 60 + Math.round((loaded / total) * 40);
              loadingMessage = `Loading fonts... (${loaded}/${total})`;
            }
          })
        );
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
    fontUploadCurrent = 0;
    fontUploadTotal = files.length;
    try {
      const user = await getCurrentUser();
      if (!user) throw new Error('User not authenticated');
      
      for (const file of Array.from(files)) {
        fontUploadCurrent++;
        const fontName = file.name.replace(/\.(ttf|otf|woff|woff2)$/i, '');
        const fileExt = file.name.split('.').pop();
        const fileName = `${user.id}/${Date.now()}_${file.name}`;
        
        // Upload to storage
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('custom-fonts')
          .upload(fileName, file, {
            cacheControl: '31536000',
            upsert: false
          });
        
        if (uploadError) throw uploadError;
        
        const { data: { publicUrl } } = supabase.storage
          .from('custom-fonts')
          .getPublicUrl(uploadData.path);
        
        // Save to database
        const { error: dbError } = await supabase
          .from('shelf_paper_fonts')
          .insert({
            name: fontName,
            font_url: publicUrl,
            file_name: file.name,
            original_file_name: file.name,
            file_size: file.size,
            created_by: user.id
          });
        
        if (dbError) throw dbError;
        
        // Register font in browser immediately
        try {
          const fontFace = new FontFace(fontName, `url(${publicUrl})`);
          await fontFace.load();
          document.fonts.add(fontFace);
        } catch (e) {
          console.warn(`Failed to register font: ${fontName}`, e);
        }
      }
      
      await loadCustomFonts();
      notifications.add({ type: 'success', message: `${files.length} font(s) uploaded successfully!` });
    } catch (error) {
      console.error('Error uploading fonts:', error);
      notifications.add({ type: 'error', message: 'Failed to upload font: ' + (error.message || 'Unknown error') });
    } finally {
      isUploadingFont = false;
      fontUploadCurrent = 0;
      fontUploadTotal = 0;
      // Reset the file input
      if (fontFileInput) fontFileInput.value = '';
    }
  }
  
  async function deleteFont(fontId: string) {
    showConfirm('Delete Font', 'Delete this font? Fields using it will fall back to default.', async () => {
      try {
        const { error } = await supabase
          .from('shelf_paper_fonts')
          .delete()
          .eq('id', fontId);
        if (error) throw error;
        await loadCustomFonts();
        notifications.add({ type: 'success', message: 'Font deleted successfully' });
      } catch (error) {
        console.error('Error deleting font:', error);
        notifications.add({ type: 'error', message: 'Failed to delete font' });
      }
    });
  }
  
  async function loadSavedTemplates() {
    isLoading = true;
    try {
      const { data, error } = await supabase
        .from('shelf_paper_templates')
        .select('id, name, description, created_at')
        .eq('is_active', true)
        .order('created_at', { ascending: false });
      
      if (error) throw error;
      savedTemplates = (data || []) as SavedTemplate[];
    } catch (error) {
      console.error('Error loading templates:', error);
    } finally {
      isLoading = false;
    }
  }
  
  async function selectTemplate(templateId: string) {
    isLoading = true;
    try {
      const { data: template, error } = await supabase
        .from('shelf_paper_templates')
        .select('*')
        .eq('id', templateId)
        .single();
      
      if (error) throw error;
      if (!template) return;
      
      selectedTemplateId = templateId;
      templateName = template.name;
      templateDescription = template.description || '';
      templateImage = template.template_image_url;
      fieldSelectors = template.field_configuration || [];
      
      // Update nextFieldId to avoid conflicts
      const maxId = fieldSelectors.reduce((max: number, field: FieldSelector) => {
        const idNum = parseInt(field.id.replace('field-', ''));
        return idNum > max ? idNum : max;
      }, 0);
      nextFieldId = maxId + 1;
    } catch (error) {
      console.error('Error loading template:', error);
      notifications.add({ type: 'error', message: 'Failed to load template' });
    } finally {
      isLoading = false;
    }
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
      notifications.add({ type: 'warning', message: 'Please upload a template image and add field selectors' });
      return;
    }
    
    if (!templateName.trim()) {
      notifications.add({ type: 'warning', message: 'Please enter a template name' });
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
      
      notifications.add({ type: 'success', message: 'Template saved successfully!' });
      await loadSavedTemplates();
      selectedTemplateId = result.data.id;
      imageFile = null; // Clear file after successful upload
    } catch (error) {
      console.error('Error saving template:', error);
      notifications.add({ type: 'error', message: 'Failed to save template: ' + (error.message || 'Unknown error') });
    } finally {
      isUploading = false;
    }
  }
  
  async function updateTemplateImage() {
    if (!selectedTemplateId) {
      notifications.add({ type: 'warning', message: 'Please select a template first' });
      return;
    }
    
    if (!imageFile) {
      notifications.add({ type: 'warning', message: 'Please select a new image first' });
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
      
      notifications.add({ type: 'success', message: 'Template image updated successfully!' });
      templateImage = newImageUrl;
      imageFile = null;
      await loadSavedTemplates();
    } catch (error) {
      console.error('Error updating template image:', error);
      notifications.add({ type: 'error', message: 'Failed to update template image: ' + (error.message || 'Unknown error') });
    } finally {
      isUploading = false;
    }
  }
  
  function openNewTemplateModal() {
    showNewTemplateModal = true;
  }
  
  function closeNewTemplateModal() {
    showNewTemplateModal = false;
  }
  
  function newTemplateAsBlank() {
    selectedTemplateId = null;
    templateName = '';
    templateDescription = '';
    templateImage = null;
    imageFile = null;
    fieldSelectors = [];
    nextFieldId = 1;
    selectedFieldId = null;
    closeNewTemplateModal();
  }
  
  function openTemplateSelectionModal() {
    showNewTemplateModal = false;
    showTemplateSelectionModal = true;
  }
  
  function closeTemplateSelectionModal() {
    showTemplateSelectionModal = false;
  }
  
  async function selectTemplateForCopy(templateId: string) {
    const template = savedTemplates.find(t => t.id === templateId);
    if (template) {
      selectedTemplateToCopy = templateId;
      newTemplateNameInput = template.name + ' (Copy)';
      showTemplateSelectionModal = false;
      showTemplateNameInputModal = true;
    }
  }
  
  function closeTemplateNameInputModal() {
    showTemplateNameInputModal = false;
    selectedTemplateToCopy = null;
    newTemplateNameInput = '';
  }
  
  async function confirmCopyTemplate() {
    if (!selectedTemplateToCopy || !newTemplateNameInput.trim()) {
      notifications.add({ type: 'warning', message: 'Please enter a template name' });
      return;
    }
    await copyFromTemplate(selectedTemplateToCopy, newTemplateNameInput.trim());
  }
  
  async function copyFromTemplate(templateId: string, customName?: string) {
    isLoading = true;
    try {
      const { data: template, error } = await supabase
        .from('shelf_paper_templates')
        .select('*')
        .eq('id', templateId)
        .single();
      
      if (error) throw error;
      if (!template) return;
      
      // Copy all configurations but clear the ID so it saves as new
      selectedTemplateId = null;
      templateName = customName || (template.name + ' (Copy)');
      templateDescription = template.description || '';
      templateImage = template.template_image_url;
      imageFile = null;
      
      // Deep copy field configurations
      if (template.field_configuration && Array.isArray(template.field_configuration)) {
        fieldSelectors = template.field_configuration.map((field: FieldSelector) => ({
          ...field,
          id: `field-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
        }));
      } else {
        fieldSelectors = [];
      }
      
      // Update nextFieldId
      const maxId = fieldSelectors.reduce((max: number, field: FieldSelector) => {
        const idNum = parseInt(field.id.replace('field-', '')) || 0;
        return idNum > max ? idNum : max;
      }, 0);
      nextFieldId = maxId + 1;
      selectedFieldId = null;
      
      closeTemplateNameInputModal();
    } catch (error) {
      console.error('Error copying template:', error);
      notifications.add({ type: 'error', message: 'Failed to copy template' });
    } finally {
      isLoading = false;
    }
  }
  function openFontManager() {
    const windowId = `font-manager-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    openWindow({
      id: windowId,
      title: 'Shelf Paper Font Manager',
      component: ShelfPaperFontManager,
      icon: '🔤',
      size: { width: 900, height: 600 },
      position: {
        x: 100 + (Math.random() * 100),
        y: 100 + (Math.random() * 100)
      },
      resizable: true,
      minimizable: true,
      maximizable: true,
      closable: true
    });
  }
</script>

<div class="template-designer">
  {#if isInitialLoad}
    <div class="loading-overlay">
      <div class="loading-spinner"></div>
      <p class="loading-text">{loadingMessage}</p>
      <div class="loading-progress-bar">
        <div class="loading-progress-fill" style="width: {loadingPercent}%"></div>
      </div>
      <p class="loading-percent">{loadingPercent}%</p>
    </div>
  {/if}
  
  {#if isLoading && !isInitialLoad}
    <div class="loading-bar"></div>
  {/if}
  
  <div class="header">
    <div class="header-row">
      <div>
        <h2 class="text-2xl font-bold text-gray-800">Shelf Paper Template Designer</h2>
        <p class="text-sm text-gray-600 mt-1">Upload template image and define field positions</p>
      </div>
      <div class="header-actions">
        <label class="font-upload-btn" class:uploading={isUploadingFont}>
          <input 
            type="file" 
            accept=".ttf,.otf,.woff,.woff2" 
            multiple 
            on:change={handleFontUpload} 
            bind:this={fontFileInput}
            hidden 
          />
          {isUploadingFont ? `⏳ Uploading ${fontUploadCurrent}/${fontUploadTotal}...` : '📤 Upload Fonts'}
        </label>
        <button class="view-fonts-btn" on:click={openFontManager} title="View all fonts">
          🔤 View Fonts
        </button>
        {#if customFonts.length > 0}
          <span class="font-count">{customFonts.length} font{customFonts.length !== 1 ? 's' : ''}</span>
        {/if}
      </div>
    </div>
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
          <button class="new-template-btn" on:click={openNewTemplateModal} title="Create new template">
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
                    Font Family:
                    <select bind:value={field.fontFamily} on:change={() => updateField(field.id, { fontFamily: field.fontFamily })}>
                      <option value="">-- Default --</option>
                      {#each customFonts as font}
                        <option value={font.name}>{font.name}</option>
                      {/each}
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
                <span class="field-overlay-label" style="color: {field.color}; font-size: {field.fontSize}px; text-align: {field.alignment}; width: 100%; display: block;{field.fontFamily ? ` font-family: '${field.fontFamily}', sans-serif;` : ''}">{availableFields.find(f => f.value === field.label)?.label || field.label}</span>
                
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

<!-- New Template Modal -->
{#if showNewTemplateModal}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="modal-overlay" on:click={closeNewTemplateModal}>
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
    <div class="modal-content" on:click|stopPropagation>
      <div class="modal-header">
        <h3>➕ New Template</h3>
        <button class="modal-close-btn" on:click={closeNewTemplateModal}>✕</button>
      </div>
      <div class="modal-body">
        <p class="modal-description">How would you like to create the new template?</p>
        <div class="option-buttons">
          <button class="option-btn copy-option" on:click={openTemplateSelectionModal} disabled={savedTemplates.length === 0}>
            <span class="option-icon">📋</span>
            <span class="option-title">Copy from Existing</span>
            <span class="option-desc">Copy all configurations from a saved template</span>
          </button>
          <button class="option-btn new-option" on:click={newTemplateAsBlank}>
            <span class="option-icon">🆕</span>
            <span class="option-title">Create Blank</span>
            <span class="option-desc">Start with a blank template</span>
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- Template Selection Modal -->
{#if showTemplateSelectionModal}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="modal-overlay" on:click={closeTemplateSelectionModal}>
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
    <div class="modal-content page-selection-modal" on:click|stopPropagation>
      <div class="modal-header">
        <h3>📄 Select Template to Copy</h3>
        <button class="modal-close-btn" on:click={closeTemplateSelectionModal}>✕</button>
      </div>
      <div class="modal-body">
        <p class="modal-description">Select a template to copy all its configurations:</p>
        <div class="page-list">
          {#each savedTemplates as template}
            <button class="page-option" on:click={() => selectTemplateForCopy(template.id)}>
              <div class="page-thumbnail template-icon">
                <span>📋</span>
              </div>
              <div class="page-info">
                <span class="page-name">{template.name}</span>
                <span class="page-fields">{template.description || 'No description'}</span>
              </div>
            </button>
          {/each}
        </div>
      </div>
      <div class="modal-footer">
        <button class="cancel-btn" on:click={closeTemplateSelectionModal}>Cancel</button>
      </div>
    </div>
  </div>
{/if}

<!-- Template Name Input Modal -->
{#if showTemplateNameInputModal}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="modal-overlay" on:click={closeTemplateNameInputModal}>
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
    <div class="modal-content" on:click|stopPropagation>
      <div class="modal-header">
        <h3>✏️ Enter Template Name</h3>
        <button class="modal-close-btn" on:click={closeTemplateNameInputModal}>✕</button>
      </div>
      <div class="modal-body">
        <p class="modal-description">Enter a name for the new template:</p>
        <div class="name-input-container">
          <input 
            type="text" 
            bind:value={newTemplateNameInput}
            placeholder="Enter template name"
            class="template-name-input"
            on:keydown={(e) => e.key === 'Enter' && confirmCopyTemplate()}
          />
        </div>
      </div>
      <div class="modal-footer">
        <button class="cancel-btn" on:click={closeTemplateNameInputModal}>Cancel</button>
        <button class="confirm-btn" on:click={confirmCopyTemplate} disabled={!newTemplateNameInput.trim()}>
          ✅ Create Template
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Confirm Dialog -->
{#if showConfirmDialog}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="modal-overlay" on:click={handleConfirmNo}>
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
    <div class="modal-content confirm-dialog" on:click|stopPropagation>
      <div class="modal-header confirm-header">
        <h3>⚠️ {confirmDialogTitle}</h3>
      </div>
      <div class="modal-body">
        <p class="confirm-message">{confirmDialogMessage}</p>
      </div>
      <div class="modal-footer">
        <button class="cancel-btn" on:click={handleConfirmNo}>Cancel</button>
        <button class="confirm-delete-btn" on:click={handleConfirmYes}>Confirm</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .template-designer {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: #f9fafb;
    overflow: hidden;
    position: relative;
  }

  .loading-overlay {
    position: absolute;
    inset: 0;
    background: rgba(255, 255, 255, 0.92);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    z-index: 100;
    gap: 1rem;
  }

  .loading-spinner {
    width: 48px;
    height: 48px;
    border: 4px solid #e5e7eb;
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .loading-text {
    font-size: 1rem;
    color: #6b7280;
    font-weight: 500;
  }

  .loading-progress-bar {
    width: 220px;
    height: 8px;
    background: #e5e7eb;
    border-radius: 9999px;
    overflow: hidden;
  }

  .loading-progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #3b82f6, #10b981);
    border-radius: 9999px;
    transition: width 0.3s ease;
  }

  .loading-percent {
    font-size: 0.875rem;
    color: #9ca3af;
    font-weight: 600;
    margin: 0;
  }

  .loading-bar {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(90deg, #3b82f6 0%, #10b981 50%, #3b82f6 100%);
    background-size: 200% 100%;
    animation: shimmer 1.5s ease-in-out infinite;
    z-index: 50;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  @keyframes shimmer {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }

  .header {
    padding: 1.5rem;
    background: white;
    border-bottom: 1px solid #e5e7eb;
  }

  .header-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-shrink: 0;
  }

  .font-upload-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.625rem 1.25rem;
    background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
    user-select: none;
  }

  .font-upload-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(139, 92, 246, 0.4);
  }

  .font-upload-btn.uploading {
    opacity: 0.7;
    cursor: wait;
  }

  .view-fonts-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.625rem 1.25rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
  }

  .view-fonts-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
  }

  .font-count {
    font-size: 0.75rem;
    color: #6b7280;
    background: #f3f4f6;
    padding: 0.375rem 0.75rem;
    border-radius: 9999px;
    font-weight: 500;
  }

  .font-list-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 0.75rem;
    padding-top: 0.75rem;
    border-top: 1px solid #f3f4f6;
  }

  .font-tag {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.25rem 0.625rem;
    background: #f5f3ff;
    border: 1px solid #ddd6fe;
    border-radius: 6px;
    font-size: 0.8rem;
    color: #5b21b6;
  }

  .font-tag-delete {
    background: none;
    border: none;
    color: #a78bfa;
    cursor: pointer;
    font-size: 0.7rem;
    padding: 0;
    line-height: 1;
    transition: color 0.2s;
  }

  .font-tag-delete:hover {
    color: #dc2626;
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
    background: transparent;
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
    z-index: 9999;
    backdrop-filter: blur(2px);
  }

  .modal-content {
    background: white;
    border-radius: 12px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    max-width: 500px;
    width: 90%;
    max-height: 80vh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .page-selection-modal {
    max-width: 600px;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    background: #f9fafb;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 1.125rem;
    color: #1f2937;
  }

  .modal-close-btn {
    background: none;
    border: none;
    font-size: 1.25rem;
    cursor: pointer;
    color: #6b7280;
    padding: 0.25rem;
    border-radius: 4px;
    transition: all 0.2s ease;
  }

  .modal-close-btn:hover {
    background: #e5e7eb;
    color: #1f2937;
  }

  .modal-body {
    padding: 1.5rem;
    overflow-y: auto;
  }

  .modal-description {
    margin: 0 0 1.25rem 0;
    color: #6b7280;
    font-size: 0.9375rem;
  }

  .option-buttons {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .option-btn {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 1.5rem;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    background: white;
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: center;
  }

  .option-btn:hover:not(:disabled) {
    border-color: #3b82f6;
    background: #eff6ff;
  }

  .option-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .copy-option:hover:not(:disabled) {
    border-color: #10b981;
    background: #ecfdf5;
  }

  .new-option:hover:not(:disabled) {
    border-color: #8b5cf6;
    background: #f5f3ff;
  }

  .option-icon {
    font-size: 2rem;
    margin-bottom: 0.5rem;
  }

  .option-title {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 0.25rem;
  }

  .option-desc {
    font-size: 0.8125rem;
    color: #6b7280;
  }

  .page-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    max-height: 400px;
    overflow-y: auto;
  }

  .page-option {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.75rem;
    border: 2px solid #e5e7eb;
    border-radius: 10px;
    background: white;
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: left;
  }

  .page-option:hover {
    border-color: #3b82f6;
    background: #eff6ff;
  }

  .page-thumbnail {
    width: 60px;
    height: 80px;
    border-radius: 6px;
    overflow: hidden;
    background: #f3f4f6;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    border: 1px solid #e5e7eb;
  }

  .page-thumbnail.template-icon {
    font-size: 2rem;
    background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
  }

  .page-info {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .page-name {
    font-weight: 600;
    color: #1f2937;
    font-size: 0.9375rem;
  }

  .page-fields {
    font-size: 0.8125rem;
    color: #6b7280;
  }

  .modal-footer {
    padding: 1rem 1.5rem;
    border-top: 1px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
  }

  .cancel-btn {
    padding: 0.5rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    background: white;
    color: #374151;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .cancel-btn:hover {
    background: #f3f4f6;
    border-color: #9ca3af;
  }

  .name-input-container {
    margin-top: 0.5rem;
  }

  .template-name-input {
    width: 100%;
    padding: 0.75rem 1rem;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 1rem;
    transition: all 0.2s ease;
  }

  .template-name-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .confirm-btn {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 6px;
    background: #10b981;
    color: white;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .confirm-btn:hover:not(:disabled) {
    background: #059669;
  }

  .confirm-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .confirm-dialog {
    max-width: 420px;
  }

  .confirm-header {
    background: #fef3c7;
    border-bottom-color: #fde68a;
  }

  .confirm-message {
    font-size: 0.9375rem;
    color: #374151;
    line-height: 1.5;
    margin: 0;
  }

  .confirm-delete-btn {
    padding: 0.5rem 1.25rem;
    border: none;
    border-radius: 6px;
    background: #ef4444;
    color: white;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .confirm-delete-btn:hover {
    background: #dc2626;
  }
</style>
