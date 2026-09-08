<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';

  interface FlyerTemplate {
    id: string;
    name: string;
    description: string | null;
    is_active: boolean;
    created_at: string;
  }

  let templates: FlyerTemplate[] = [];
  let isLoading = true;
  let errorMessage = '';
  let successMessage = '';
  let showEditModal = false;
  let editingTemplate: FlyerTemplate | null = null;
  let editName = '';
  let editDescription = '';
  let isSaving = false;
  let showDeleteModal = false;
  let deletingTemplate: FlyerTemplate | null = null;
  let isDeleting = false;
  let showCopyModal = false;
  let copyingTemplate: FlyerTemplate | null = null;
  let copyName = '';
  let isCopying = false;

  async function loadTemplates() {
    try {
      isLoading = true;
      errorMessage = '';

      const { data, error } = await supabase
        .from('flyer_templates')
        .select('id, name, description, is_active, created_at')
        .order('created_at', { ascending: false });

      if (error) throw error;

      templates = data || [];
    } catch (error: any) {
      console.error('Error loading templates:', error);
      errorMessage = error.message || 'Failed to load templates';
    } finally {
      isLoading = false;
    }
  }

  function openEditModal(template: FlyerTemplate) {
    editingTemplate = template;
    editName = template.name;
    editDescription = template.description || '';
    showEditModal = true;
  }

  function closeEditModal() {
    showEditModal = false;
    editingTemplate = null;
    editName = '';
    editDescription = '';
  }

  function openDeleteModal(template: FlyerTemplate) {
    deletingTemplate = template;
    showDeleteModal = true;
  }

  function closeDeleteModal() {
    showDeleteModal = false;
    deletingTemplate = null;
  }

  function openCopyModal(template: FlyerTemplate) {
    copyingTemplate = template;
    copyName = `${template.name} - Copy`;
    showCopyModal = true;
  }

  function closeCopyModal() {
    showCopyModal = false;
    copyingTemplate = null;
    copyName = '';
  }

  async function copyTemplate() {
    if (!copyingTemplate || !copyName.trim()) {
      errorMessage = 'Template name is required';
      return;
    }

    try {
      isCopying = true;
      errorMessage = '';

      // First, get the full template data including all fields
      const { data: fullTemplate, error: fetchError } = await supabase
        .from('flyer_templates')
        .select('*')
        .eq('id', copyingTemplate.id)
        .single();

      if (fetchError) throw fetchError;

      // Create a copy with all fields - exclude auto-generated fields and override specific ones
      const { id, created_at, updated_at, ...templateData } = fullTemplate;

      // Create the copy with all columns included
      const { data: newTemplate, error: insertError } = await supabase
        .from('flyer_templates')
        .insert({
          // Copy all fields from original template
          name: copyName.trim(), // New name
          description: templateData.description,
          first_page_image_url: templateData.first_page_image_url,
          sub_page_image_urls: templateData.sub_page_image_urls,
          first_page_configuration: templateData.first_page_configuration,
          sub_page_configurations: templateData.sub_page_configurations,
          metadata: templateData.metadata,
          category: templateData.category,
          tags: templateData.tags,
          created_by: templateData.created_by,
          updated_by: templateData.updated_by,
          deleted_at: null, // Ensure copy is not deleted
          last_used_at: null, // Reset last used date
          // Override these fields for the copy
          is_active: false, // Set copies as inactive by default
          is_default: false, // Copies cannot be default
          usage_count: 0 // Reset usage count
        })
        .select()
        .single();

      if (insertError) throw insertError;

      successMessage = 'Template copied successfully!';
      setTimeout(() => successMessage = '', 3000);
      
      closeCopyModal();
      await loadTemplates();
    } catch (error: any) {
      console.error('Error copying template:', error);
      errorMessage = error.message || 'Failed to copy template';
    } finally {
      isCopying = false;
    }
  }

  async function deleteTemplate() {
    if (!deletingTemplate) return;

    try {
      isDeleting = true;
      errorMessage = '';

      const { error } = await supabase
        .from('flyer_templates')
        .delete()
        .eq('id', deletingTemplate.id);

      if (error) throw error;

      successMessage = 'Template deleted successfully!';
      setTimeout(() => successMessage = '', 3000);
      
      closeDeleteModal();
      await loadTemplates();
    } catch (error: any) {
      console.error('Error deleting template:', error);
      errorMessage = error.message || 'Failed to delete template';
    } finally {
      isDeleting = false;
    }
  }

  async function saveTemplate() {
    if (!editingTemplate || !editName.trim()) {
      errorMessage = 'Template name is required';
      return;
    }

    try {
      isSaving = true;
      errorMessage = '';

      const { error } = await supabase
        .from('flyer_templates')
        .update({
          name: editName.trim(),
          description: editDescription.trim() || null
        })
        .eq('id', editingTemplate.id);

      if (error) throw error;

      successMessage = 'Template updated successfully!';
      setTimeout(() => successMessage = '', 3000);
      
      closeEditModal();
      await loadTemplates();
    } catch (error: any) {
      console.error('Error updating template:', error);
      errorMessage = error.message || 'Failed to update template';
    } finally {
      isSaving = false;
    }
  }

  onMount(() => {
    loadTemplates();
  });
</script>

<div class="h-full overflow-auto bg-gradient-to-br from-indigo-50 via-blue-50 to-purple-50 p-6">
  <div class="bg-white rounded-xl shadow-lg p-6">
    <div class="flex items-center justify-between mb-6">
      <div>
        <h2 class="text-2xl font-bold text-gray-800">Flyer Settings</h2>
        <p class="text-gray-600 mt-1">Manage flyer templates</p>
      </div>
      <button
        on:click={loadTemplates}
        class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors flex items-center gap-2"
      >
        <span>🔄</span>
        Refresh
      </button>
    </div>

    {#if errorMessage}
      <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4">
        {errorMessage}
      </div>
    {/if}

    {#if successMessage}
      <div class="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg mb-4">
        {successMessage}
      </div>
    {/if}

    {#if isLoading}
      <div class="flex items-center justify-center py-12">
        <svg class="animate-spin w-8 h-8 text-indigo-600" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span class="ml-3 text-gray-600">Loading templates...</span>
      </div>
    {:else if templates.length === 0}
      <div class="text-center py-12">
        <div class="text-6xl mb-4">📄</div>
        <p class="text-gray-600">No templates found</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="border-b-2 border-gray-200">
              <th class="text-left py-3 px-4 font-semibold text-gray-700">Template Name</th>
              <th class="text-left py-3 px-4 font-semibold text-gray-700">Description</th>
              <th class="text-center py-3 px-4 font-semibold text-gray-700">Status</th>
              <th class="text-center py-3 px-4 font-semibold text-gray-700">Actions</th>
            </tr>
          </thead>
          <tbody>
            {#each templates as template}
              <tr class="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                <td class="py-3 px-4">
                  <span class="font-medium text-gray-800">{template.name}</span>
                </td>
                <td class="py-3 px-4">
                  <span class="text-gray-600">{template.description || '-'}</span>
                </td>
                <td class="py-3 px-4 text-center">
                  {#if template.is_active}
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                      ✓ Active
                    </span>
                  {:else}
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-800">
                      ✗ Inactive
                    </span>
                  {/if}
                </td>
                <td class="py-3 px-4 text-center">
                  <div class="flex items-center justify-center gap-2">
                    <button
                      on:click={() => openEditModal(template)}
                      class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium"
                    >
                      ✏️ Edit
                    </button>
                    <button
                      on:click={() => openCopyModal(template)}
                      class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors text-sm font-medium"
                    >
                      📋 Copy
                    </button>
                    <button
                      on:click={() => openDeleteModal(template)}
                      class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors text-sm font-medium"
                    >
                      🗑️ Delete
                    </button>
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>

<!-- Edit Modal -->
{#if showEditModal && editingTemplate}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" on:click={closeEditModal}>
    <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md" on:click|stopPropagation>
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-xl font-bold text-gray-800">Edit Template</h3>
        <button
          on:click={closeEditModal}
          class="text-gray-400 hover:text-gray-600 text-2xl leading-none"
        >
          ×
        </button>
      </div>

      <div class="space-y-4">
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Template Name *
          </label>
          <input
            type="text"
            bind:value={editName}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            placeholder="Enter template name"
          />
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Description
          </label>
          <textarea
            bind:value={editDescription}
            rows="4"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none resize-none"
            placeholder="Enter description (optional)"
          ></textarea>
        </div>
      </div>

      <div class="flex gap-3 mt-6">
        <button
          on:click={closeEditModal}
          class="flex-1 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors font-medium"
          disabled={isSaving}
        >
          Cancel
        </button>
        <button
          on:click={saveTemplate}
          class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
          disabled={isSaving || !editName.trim()}
        >
          {#if isSaving}
            <span class="flex items-center justify-center gap-2">
              <svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Saving...
            </span>
          {:else}
            Save Changes
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Delete Confirmation Modal -->
{#if showDeleteModal && deletingTemplate}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" on:click={closeDeleteModal}>
    <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md" on:click|stopPropagation>
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-xl font-bold text-gray-800">Delete Template</h3>
        <button
          on:click={closeDeleteModal}
          class="text-gray-400 hover:text-gray-600 text-2xl leading-none"
        >
          ×
        </button>
      </div>

      <div class="mb-6">
        <p class="text-gray-700 mb-2">Are you sure you want to delete this template?</p>
        <div class="bg-gray-50 p-4 rounded-lg">
          <p class="font-semibold text-gray-800">{deletingTemplate.name}</p>
          {#if deletingTemplate.description}
            <p class="text-sm text-gray-600 mt-1">{deletingTemplate.description}</p>
          {/if}
        </div>
        <p class="text-red-600 text-sm mt-4">⚠️ This action cannot be undone.</p>
      </div>

      <div class="flex gap-3">
        <button
          on:click={closeDeleteModal}
          class="flex-1 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors font-medium"
          disabled={isDeleting}
        >
          Cancel
        </button>
        <button
          on:click={deleteTemplate}
          class="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
          disabled={isDeleting}
        >
          {#if isDeleting}
            <span class="flex items-center justify-center gap-2">
              <svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Deleting...
            </span>
          {:else}
            Delete
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Copy Modal -->
{#if showCopyModal && copyingTemplate}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" on:click={closeCopyModal}>
    <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md" on:click|stopPropagation>
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-xl font-bold text-gray-800">Copy Template</h3>
        <button
          on:click={closeCopyModal}
          class="text-gray-400 hover:text-gray-600 text-2xl leading-none"
        >
          ×
        </button>
      </div>

      <div class="mb-6">
        <p class="text-gray-700 mb-4">Creating a copy of:</p>
        <div class="bg-gray-50 p-4 rounded-lg mb-4">
          <p class="font-semibold text-gray-800">{copyingTemplate.name}</p>
          {#if copyingTemplate.description}
            <p class="text-sm text-gray-600 mt-1">{copyingTemplate.description}</p>
          {/if}
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            New Template Name *
          </label>
          <input
            type="text"
            bind:value={copyName}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 outline-none"
            placeholder="Enter name for the copy"
          />
        </div>
      </div>

      <div class="flex gap-3">
        <button
          on:click={closeCopyModal}
          class="flex-1 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors font-medium"
          disabled={isCopying}
        >
          Cancel
        </button>
        <button
          on:click={copyTemplate}
          class="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
          disabled={isCopying || !copyName.trim()}
        >
          {#if isCopying}
            <span class="flex items-center justify-center gap-2">
              <svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Copying...
            </span>
          {:else}
            Create Copy
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  table {
    border-collapse: collapse;
  }

  th {
    background-color: #f9fafb;
  }
</style>