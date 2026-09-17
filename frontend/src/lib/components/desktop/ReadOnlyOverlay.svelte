<script lang="ts">
  export let show = true;
  let showHint = true;
  
  // Auto-hide hint after 10 seconds
  setTimeout(() => {
    showHint = false;
  }, 10000);
</script>

{#if show}
  <div class="fixed inset-0 pointer-events-none z-50">
    <!-- Subtle border around screen -->
    <div class="absolute inset-0 border-4 border-yellow-400 opacity-50"></div>
    
    <!-- Floating hint message (dismissible) -->
    {#if showHint}
      <div class="absolute bottom-8 left-1/2 transform -translate-x-1/2 pointer-events-auto">
        <div class="bg-yellow-50 border-2 border-yellow-400 rounded-lg shadow-xl px-6 py-4 max-w-2xl flex items-center space-x-4">
          <svg class="w-8 h-8 text-yellow-600 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
          </svg>
          <div class="flex-1">
            <p class="text-sm font-semibold text-yellow-900">Read-Only Desktop Mode</p>
            <p class="text-xs text-yellow-800 mt-1">
              This is a local copy for viewing data offline. Changes cannot be saved to the cloud.
              Use the web version to make edits.
            </p>
          </div>
          <button
            on:click={() => showHint = false}
            class="text-yellow-600 hover:text-yellow-800 transition-colors"
          >
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
            </svg>
          </button>
        </div>
      </div>
    {/if}
  </div>
{/if}

<style>
  /* Disable all forms and buttons globally when in read-only mode */
  :global(input:not([type="search"])),
  :global(textarea),
  :global(select),
  :global(button[type="submit"]),
  :global(button.btn-primary),
  :global(button.btn-danger),
  :global(a.btn:not(.btn-secondary)) {
    pointer-events: none !important;
    opacity: 0.6 !important;
    cursor: not-allowed !important;
  }
  
  /* Allow navigation and read-only actions */
  :global(button.btn-secondary),
  :global(a.link),
  :global(input[type="search"]),
  :global(.read-only-allowed) {
    pointer-events: auto !important;
    opacity: 1 !important;
    cursor: pointer !important;
  }
</style>
