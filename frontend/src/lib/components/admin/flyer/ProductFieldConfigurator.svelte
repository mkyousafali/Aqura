<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let field: any;
  export let onSave: (fields: any[]) => void;
  
  const dispatch = createEventDispatcher();
  
  interface FieldData {
    type: string;
    fontSize: number;
    alignment: 'left' | 'center' | 'right';
    color: string;
    x: number;
    y: number;
    width: number;
    height: number;
  }
  
  let fieldConfigs: FieldData[] = field.fields || [];
  let selectedFieldIndex: number | null = null;
  
  const availableFieldTypes = [
    { value: 'product_name_en', label: 'Product Name (EN)', defaultHeight: 30 },
    { value: 'product_name_ar', label: 'Product Name (AR)', defaultHeight: 30 },
    { value: 'barcode', label: 'Barcode', defaultHeight: 40 },
    { value: 'serial_number', label: 'Serial Number', defaultHeight: 25 },
    { value: 'unit_name', label: 'Unit Name', defaultHeight: 25 },
    { value: 'price', label: 'Price', defaultHeight: 35 },
    { value: 'offer_price', label: 'Offer Price', defaultHeight: 35 },
    { value: 'offer_qty', label: 'Offer Quantity', defaultHeight: 30 },
    { value: 'expire_date', label: 'Expire Date', defaultHeight: 25 },
    { value: 'image', label: 'Product Image', defaultHeight: 100 }
  ];
  
  function addField() {
    const newField: FieldData = {
      type: 'product_name_en',
      fontSize: 16,
      alignment: 'left',
      color: '#000000',
      x: 10,
      y: fieldConfigs.length * 35 + 10,
      width: field.width - 20,
      height: 30
    };
    fieldConfigs = [...fieldConfigs, newField];
    selectedFieldIndex = fieldConfigs.length - 1;
  }
  
  function deleteField(index: number) {
    fieldConfigs = fieldConfigs.filter((_, i) => i !== index);
    if (selectedFieldIndex === index) {
      selectedFieldIndex = null;
    }
  }
  
  function selectField(index: number) {
    selectedFieldIndex = index;
  }
  
  function updateField(index: number, updates: Partial<FieldData>) {
    fieldConfigs = fieldConfigs.map((f, i) => 
      i === index ? { ...f, ...updates } : f
    );
  }
  
  function handleSave() {
    onSave(fieldConfigs);
    dispatch('close');
  }
  
  function handleCancel() {
    dispatch('close');
  }
  
  function getFieldLabel(type: string): string {
    return availableFieldTypes.find(f => f.value === type)?.label || type;
  }
</script>

<div class="configurator">
  <div class="header">
    <div>
      <h2 class="title">Configure Product Field #{field.number}</h2>
      <p class="subtitle">Field Size: {field.width}×{field.height}px</p>
    </div>
  </div>

  <div class="content">
    <!-- Left Panel: Field List -->
    <div class="fields-panel">
      <div class="panel-header">
        <h3 class="panel-title">Data Fields</h3>
        <button class="add-btn" on:click={addField}>➕ Add Field</button>
      </div>
      
      <div class="fields-list">
        {#if fieldConfigs.length === 0}
          <div class="empty-state">
            <span class="empty-icon">📝</span>
            <p>No data fields configured</p>
            <p class="empty-hint">Click "Add Field" to start</p>
          </div>
        {:else}
          {#each fieldConfigs as fieldConfig, index}
            <div 
              class="field-item {selectedFieldIndex === index ? 'selected' : ''}"
              on:click={() => selectField(index)}
            >
              <div class="field-item-header">
                <span class="field-type">{getFieldLabel(fieldConfig.type)}</span>
                <button class="delete-btn" on:click|stopPropagation={() => deleteField(index)}>🗑️</button>
              </div>
              <div class="field-item-info">
                {fieldConfig.width}×{fieldConfig.height}px at ({fieldConfig.x}, {fieldConfig.y})
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </div>

    <!-- Right Panel: Field Configuration -->
    <div class="config-panel">
      {#if selectedFieldIndex !== null && fieldConfigs[selectedFieldIndex]}
        {@const selectedField = fieldConfigs[selectedFieldIndex]}
        <div class="panel-header">
          <h3 class="panel-title">Field Settings</h3>
        </div>
        
        <div class="config-form">
          <label class="form-group">
            <span class="label">Field Type</span>
            <select 
              bind:value={selectedField.type}
              on:change={() => {
                const fieldType = availableFieldTypes.find(f => f.value === selectedField.type);
                if (fieldType) {
                  updateField(selectedFieldIndex, { 
                    type: selectedField.type,
                    height: fieldType.defaultHeight 
                  });
                }
              }}
              class="input"
            >
              {#each availableFieldTypes as fieldType}
                <option value={fieldType.value}>{fieldType.label}</option>
              {/each}
            </select>
          </label>

          <div class="form-row">
            <label class="form-group">
              <span class="label">X Position</span>
              <input 
                type="number" 
                bind:value={selectedField.x}
                on:input={() => updateField(selectedFieldIndex, { x: selectedField.x })}
                min="0"
                max={field.width}
                class="input"
              />
            </label>
            <label class="form-group">
              <span class="label">Y Position</span>
              <input 
                type="number" 
                bind:value={selectedField.y}
                on:input={() => updateField(selectedFieldIndex, { y: selectedField.y })}
                min="0"
                max={field.height}
                class="input"
              />
            </label>
          </div>

          <div class="form-row">
            <label class="form-group">
              <span class="label">Width</span>
              <input 
                type="number" 
                bind:value={selectedField.width}
                on:input={() => updateField(selectedFieldIndex, { width: selectedField.width })}
                min="10"
                max={field.width}
                class="input"
              />
            </label>
            <label class="form-group">
              <span class="label">Height</span>
              <input 
                type="number" 
                bind:value={selectedField.height}
                on:input={() => updateField(selectedFieldIndex, { height: selectedField.height })}
                min="10"
                max={field.height}
                class="input"
              />
            </label>
          </div>

          {#if selectedField.type !== 'image'}
            <label class="form-group">
              <span class="label">Font Size</span>
              <input 
                type="number" 
                bind:value={selectedField.fontSize}
                on:input={() => updateField(selectedFieldIndex, { fontSize: selectedField.fontSize })}
                min="8"
                max="72"
                class="input"
              />
            </label>

            <label class="form-group">
              <span class="label">Text Alignment</span>
              <select 
                bind:value={selectedField.alignment}
                on:change={() => updateField(selectedFieldIndex, { alignment: selectedField.alignment })}
                class="input"
              >
                <option value="left">Left</option>
                <option value="center">Center</option>
                <option value="right">Right</option>
              </select>
            </label>

            <label class="form-group">
              <span class="label">Text Color</span>
              <div class="color-input-group">
                <input 
                  type="color" 
                  bind:value={selectedField.color}
                  on:input={() => updateField(selectedFieldIndex, { color: selectedField.color })}
                  class="color-picker"
                />
                <input 
                  type="text" 
                  bind:value={selectedField.color}
                  on:input={() => updateField(selectedFieldIndex, { color: selectedField.color })}
                  class="color-hex"
                  placeholder="#000000"
                />
              </div>
            </label>
          {/if}
        </div>
      {:else}
        <div class="empty-state-config">
          <span class="empty-icon">⚙️</span>
          <p>Select a field to configure</p>
        </div>
      {/if}
    </div>
  </div>

  <div class="footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    <button class="btn-save" on:click={handleSave}>💾 Save Configuration</button>
  </div>
</div>

<style>
  .configurator {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: #f9fafb;
  }

  .header {
    padding: 1.5rem;
    background: white;
    border-bottom: 2px solid #e5e7eb;
  }

  .title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
    margin: 0;
  }

  .subtitle {
    font-size: 0.875rem;
    color: #6b7280;
    margin: 0.25rem 0 0 0;
  }

  .content {
    flex: 1;
    display: grid;
    grid-template-columns: 300px 1fr;
    gap: 1.5rem;
    padding: 1.5rem;
    overflow: hidden;
  }

  .fields-panel,
  .config-panel {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    overflow-y: auto;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .panel-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid #e5e7eb;
  }

  .panel-title {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
    margin: 0;
  }

  .add-btn {
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .add-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
  }

  .fields-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .field-item {
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    padding: 0.75rem;
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

  .field-item-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.25rem;
  }

  .field-type {
    font-weight: 600;
    color: #1f2937;
    font-size: 0.875rem;
  }

  .field-item-info {
    font-size: 0.75rem;
    color: #6b7280;
  }

  .delete-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 1rem;
    padding: 0.25rem;
    opacity: 0.6;
    transition: opacity 0.2s;
  }

  .delete-btn:hover {
    opacity: 1;
  }

  .empty-state,
  .empty-state-config {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem 1rem;
    text-align: center;
    color: #9ca3af;
  }

  .empty-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  .empty-state p,
  .empty-state-config p {
    margin: 0.25rem 0;
    color: #6b7280;
    font-weight: 500;
  }

  .empty-hint {
    font-size: 0.875rem;
    color: #9ca3af !important;
  }

  .config-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .label {
    font-size: 0.875rem;
    font-weight: 600;
    color: #374151;
  }

  .input {
    padding: 0.625rem 0.75rem;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 0.875rem;
    transition: all 0.2s;
  }

  .input:hover {
    border-color: #3b82f6;
  }

  .input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }

  .color-input-group {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .color-picker {
    width: 60px;
    height: 40px;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    cursor: pointer;
    padding: 2px;
  }

  .color-hex {
    flex: 1;
    padding: 0.625rem 0.75rem;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 0.875rem;
    font-family: monospace;
  }

  .footer {
    padding: 1.5rem;
    background: white;
    border-top: 2px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
  }

  .btn-cancel,
  .btn-save {
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-cancel {
    background: #f3f4f6;
    color: #374151;
  }

  .btn-cancel:hover {
    background: #e5e7eb;
  }

  .btn-save {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
  }

  .btn-save:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.4);
  }
</style>
