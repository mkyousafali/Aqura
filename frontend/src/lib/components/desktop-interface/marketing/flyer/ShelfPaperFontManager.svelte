<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { notifications } from '$lib/stores/notifications';

  interface CustomFont {
    id: string;
    name: string;
    font_url: string;
    file_name: string | null;
    file_size: number | null;
    created_at: string;
  }

  let fonts: CustomFont[] = [];
  let isLoading = false;
  let searchQuery = '';
  let sortColumn: 'name' | 'file_name' | 'file_size' | 'created_at' = 'name';
  let sortDirection: 'asc' | 'desc' = 'asc';
  let deletingFontId: string | null = null;
  
  // Confirm dialog state
  let showConfirmDialog = false;
  let confirmFontToDelete: CustomFont | null = null;
  
  function requestDeleteFont(font: CustomFont) {
    confirmFontToDelete = font;
    showConfirmDialog = true;
  }
  
  function cancelDelete() {
    showConfirmDialog = false;
    confirmFontToDelete = null;
  }
  
  async function confirmDelete() {
    if (!confirmFontToDelete) return;
    showConfirmDialog = false;
    await doDeleteFont(confirmFontToDelete);
    confirmFontToDelete = null;
  }

  $: filteredFonts = fonts.filter(font => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      font.name.toLowerCase().includes(q) ||
      (font.file_name && font.file_name.toLowerCase().includes(q))
    );
  }).sort((a, b) => {
    let valA: any;
    let valB: any;
    
    switch (sortColumn) {
      case 'name':
        valA = a.name.toLowerCase();
        valB = b.name.toLowerCase();
        break;
      case 'file_name':
        valA = (a.file_name || '').toLowerCase();
        valB = (b.file_name || '').toLowerCase();
        break;
      case 'file_size':
        valA = a.file_size || 0;
        valB = b.file_size || 0;
        break;
      case 'created_at':
        valA = a.created_at;
        valB = b.created_at;
        break;
      default:
        return 0;
    }
    
    if (valA < valB) return sortDirection === 'asc' ? -1 : 1;
    if (valA > valB) return sortDirection === 'asc' ? 1 : -1;
    return 0;
  });

  onMount(() => {
    loadFonts();
  });

  async function loadFonts() {
    isLoading = true;
    try {
      const { data, error } = await supabase
        .from('shelf_paper_fonts')
        .select('*')
        .order('name', { ascending: true });

      if (error) throw error;
      fonts = data || [];
    } catch (error) {
      console.error('Error loading fonts:', error);
    } finally {
      isLoading = false;
    }
  }

  function toggleSort(column: typeof sortColumn) {
    if (sortColumn === column) {
      sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      sortColumn = column;
      sortDirection = 'asc';
    }
  }

  function formatFileSize(bytes: number | null): string {
    if (!bytes) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  }

  function formatDate(dateStr: string): string {
    try {
      const date = new Date(dateStr);
      return date.toLocaleDateString('en-GB', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch {
      return dateStr;
    }
  }

  async function doDeleteFont(font: CustomFont) {
    deletingFontId = font.id;
    try {
      const { error } = await supabase
        .from('shelf_paper_fonts')
        .delete()
        .eq('id', font.id);

      if (error) throw error;
      fonts = fonts.filter(f => f.id !== font.id);
      notifications.add({ type: 'success', message: `Font "${font.name}" deleted` });
    } catch (error) {
      console.error('Error deleting font:', error);
      notifications.add({ type: 'error', message: 'Failed to delete font' });
    } finally {
      deletingFontId = null;
    }
  }

  function getSortIcon(column: typeof sortColumn): string {
    if (sortColumn !== column) return '↕';
    return sortDirection === 'asc' ? '↑' : '↓';
  }

  function openFontUrl(url: string) {
    window.open(url, '_blank');
  }
</script>

<div class="font-manager">
  <div class="toolbar">
    <div class="search-box">
      <span class="search-icon">🔍</span>
      <input
        type="text"
        bind:value={searchQuery}
        placeholder="Search fonts..."
        class="search-input"
      />
      {#if searchQuery}
        <button class="clear-search" on:click={() => searchQuery = ''}>✕</button>
      {/if}
    </div>
    <div class="toolbar-info">
      <span class="font-total">{filteredFonts.length} of {fonts.length} fonts</span>
      <button class="refresh-btn" on:click={loadFonts} disabled={isLoading} title="Refresh">
        🔄
      </button>
    </div>
  </div>

  {#if isLoading}
    <div class="loading-state">
      <div class="spinner"></div>
      <p>Loading fonts...</p>
    </div>
  {:else if fonts.length === 0}
    <div class="empty-state">
      <span class="empty-icon">🔤</span>
      <p>No fonts uploaded yet</p>
      <p class="empty-hint">Upload fonts from the Template Designer</p>
    </div>
  {:else}
    <div class="table-container">
      <table class="fonts-table">
        <thead>
          <tr>
            <th class="col-num">#</th>
            <th class="col-name sortable" on:click={() => toggleSort('name')}>
              Font Name <span class="sort-icon">{getSortIcon('name')}</span>
            </th>
            <th class="col-preview">Preview</th>
            <th class="col-file sortable" on:click={() => toggleSort('file_name')}>
              File Name <span class="sort-icon">{getSortIcon('file_name')}</span>
            </th>
            <th class="col-size sortable" on:click={() => toggleSort('file_size')}>
              Size <span class="sort-icon">{getSortIcon('file_size')}</span>
            </th>
            <th class="col-date sortable" on:click={() => toggleSort('created_at')}>
              Uploaded <span class="sort-icon">{getSortIcon('created_at')}</span>
            </th>
            <th class="col-actions">Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredFonts as font, index}
            <tr class:deleting={deletingFontId === font.id}>
              <td class="col-num">{index + 1}</td>
              <td class="col-name">
                <span class="font-name-text">{font.name}</span>
              </td>
              <td class="col-preview">
                <span class="font-preview" style="font-family: '{font.name}', sans-serif;">
                  AaBbCc 123
                </span>
              </td>
              <td class="col-file">
                <span class="file-name-text">{font.file_name || '—'}</span>
              </td>
              <td class="col-size">{formatFileSize(font.file_size)}</td>
              <td class="col-date">{formatDate(font.created_at)}</td>
              <td class="col-actions">
                <button
                  class="action-btn download-btn"
                  on:click={() => openFontUrl(font.font_url)}
                  title="Download font"
                >
                  ⬇️
                </button>
                <button
                  class="action-btn delete-btn"
                  on:click={() => requestDeleteFont(font)}
                  disabled={deletingFontId === font.id}
                  title="Delete font"
                >
                  {deletingFontId === font.id ? '⏳' : '🗑️'}
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if filteredFonts.length === 0 && searchQuery}
      <div class="no-results">
        <p>No fonts matching "{searchQuery}"</p>
      </div>
    {/if}
  {/if}
</div>

<!-- Confirm Delete Dialog -->
{#if showConfirmDialog && confirmFontToDelete}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="confirm-overlay" on:click={cancelDelete}>
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
    <div class="confirm-dialog" on:click|stopPropagation>
      <div class="confirm-header">
        <h3>⚠️ Delete Font</h3>
      </div>
      <div class="confirm-body">
        <p>Delete font <strong>"{confirmFontToDelete.name}"</strong>?</p>
        <p class="confirm-hint">Fields using it will fall back to default font.</p>
      </div>
      <div class="confirm-footer">
        <button class="confirm-cancel-btn" on:click={cancelDelete}>Cancel</button>
        <button class="confirm-delete-btn" on:click={confirmDelete}>Delete</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .font-manager {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: #f9fafb;
    overflow: hidden;
  }

  .toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    padding: 1rem 1.5rem;
    background: white;
    border-bottom: 1px solid #e5e7eb;
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex: 1;
    max-width: 400px;
    padding: 0.5rem 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    background: #f9fafb;
    transition: all 0.2s;
  }

  .search-box:focus-within {
    border-color: #3b82f6;
    background: white;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .search-icon {
    font-size: 0.875rem;
    flex-shrink: 0;
  }

  .search-input {
    flex: 1;
    border: none;
    outline: none;
    font-size: 0.875rem;
    background: transparent;
    color: #1f2937;
  }

  .clear-search {
    background: none;
    border: none;
    cursor: pointer;
    color: #9ca3af;
    font-size: 0.875rem;
    padding: 0;
    line-height: 1;
    transition: color 0.2s;
  }

  .clear-search:hover {
    color: #374151;
  }

  .toolbar-info {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-shrink: 0;
  }

  .font-total {
    font-size: 0.8125rem;
    color: #6b7280;
    font-weight: 500;
  }

  .refresh-btn {
    background: none;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    padding: 0.375rem 0.5rem;
    cursor: pointer;
    font-size: 0.875rem;
    transition: all 0.2s;
  }

  .refresh-btn:hover:not(:disabled) {
    background: #f3f4f6;
    border-color: #9ca3af;
  }

  .refresh-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem 2rem;
    gap: 1rem;
    color: #6b7280;
  }

  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid #e5e7eb;
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem 2rem;
    gap: 0.5rem;
    color: #6b7280;
  }

  .empty-icon {
    font-size: 3rem;
    margin-bottom: 0.5rem;
  }

  .empty-hint {
    font-size: 0.8125rem;
    color: #9ca3af;
  }

  .table-container {
    flex: 1;
    overflow: auto;
    padding: 0;
  }

  .fonts-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.875rem;
  }

  .fonts-table thead {
    position: sticky;
    top: 0;
    z-index: 10;
    background: white;
  }

  .fonts-table th {
    padding: 0.75rem 1rem;
    text-align: left;
    font-weight: 600;
    color: #374151;
    background: #f9fafb;
    border-bottom: 2px solid #e5e7eb;
    white-space: nowrap;
    user-select: none;
  }

  .fonts-table th.sortable {
    cursor: pointer;
    transition: background 0.2s;
  }

  .fonts-table th.sortable:hover {
    background: #f3f4f6;
  }

  .sort-icon {
    font-size: 0.75rem;
    color: #9ca3af;
    margin-left: 0.25rem;
  }

  .fonts-table td {
    padding: 0.75rem 1rem;
    border-bottom: 1px solid #f3f4f6;
    color: #374151;
    vertical-align: middle;
  }

  .fonts-table tbody tr {
    transition: background 0.15s;
  }

  .fonts-table tbody tr:hover {
    background: #f0fdf4;
  }

  .fonts-table tbody tr.deleting {
    opacity: 0.5;
    pointer-events: none;
  }

  .col-num {
    width: 50px;
    text-align: center;
    color: #9ca3af;
    font-weight: 500;
  }

  .col-name {
    min-width: 180px;
  }

  .font-name-text {
    font-weight: 600;
    color: #1f2937;
  }

  .col-preview {
    min-width: 160px;
  }

  .font-preview {
    font-size: 1rem;
    color: #6b7280;
    display: inline-block;
    padding: 0.25rem 0.5rem;
    background: #f3f4f6;
    border-radius: 4px;
  }

  .col-file {
    min-width: 150px;
  }

  .file-name-text {
    color: #6b7280;
    font-size: 0.8125rem;
    word-break: break-all;
  }

  .col-size {
    width: 100px;
    white-space: nowrap;
  }

  .col-date {
    width: 160px;
    white-space: nowrap;
    font-size: 0.8125rem;
    color: #6b7280;
  }

  .col-actions {
    width: 100px;
    text-align: center;
  }

  .action-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 1rem;
    padding: 0.25rem 0.375rem;
    border-radius: 4px;
    transition: all 0.2s;
    opacity: 0.7;
  }

  .action-btn:hover:not(:disabled) {
    opacity: 1;
    background: #f3f4f6;
  }

  .action-btn:disabled {
    cursor: not-allowed;
    opacity: 0.4;
  }

  .delete-btn:hover:not(:disabled) {
    background: #fef2f2;
  }

  .no-results {
    padding: 2rem;
    text-align: center;
    color: #9ca3af;
    font-size: 0.9375rem;
  }

  .confirm-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 9999;
    backdrop-filter: blur(2px);
  }

  .confirm-dialog {
    background: white;
    border-radius: 12px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    max-width: 420px;
    width: 90%;
    overflow: hidden;
  }

  .confirm-header {
    padding: 1rem 1.5rem;
    background: #fef3c7;
    border-bottom: 1px solid #fde68a;
  }

  .confirm-header h3 {
    margin: 0;
    font-size: 1.125rem;
    color: #92400e;
  }

  .confirm-body {
    padding: 1.5rem;
  }

  .confirm-body p {
    margin: 0;
    color: #374151;
    font-size: 0.9375rem;
    line-height: 1.5;
  }

  .confirm-hint {
    margin-top: 0.5rem !important;
    font-size: 0.8125rem !important;
    color: #6b7280 !important;
  }

  .confirm-footer {
    padding: 1rem 1.5rem;
    border-top: 1px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
  }

  .confirm-cancel-btn {
    padding: 0.5rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    background: white;
    color: #374151;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .confirm-cancel-btn:hover {
    background: #f3f4f6;
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
    transition: all 0.2s;
  }

  .confirm-delete-btn:hover {
    background: #dc2626;
  }
</style>
