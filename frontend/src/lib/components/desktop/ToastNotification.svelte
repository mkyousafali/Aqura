<script lang="ts">
  import { onMount } from 'svelte';
  
  type Toast = {
    id: number;
    message: string;
    type: 'info' | 'warning' | 'error' | 'success';
    duration: number;
  };
  
  let toasts: Toast[] = [];
  let nextId = 1;
  
  onMount(() => {
    // Listen for API blocked events
    window.addEventListener('api-blocked', (event: CustomEvent) => {
      const detail = event.detail;
      showToast(
        `🚫 ${detail.method} blocked: This is a read-only desktop app`,
        'error',
        5000
      );
    });
  });
  
  export function showToast(message: string, type: Toast['type'] = 'info', duration: number = 3000) {
    const id = nextId++;
    const toast: Toast = { id, message, type, duration };
    
    toasts = [...toasts, toast];
    
    // Auto-remove after duration
    setTimeout(() => {
      removeToast(id);
    }, duration);
  }
  
  function removeToast(id: number) {
    toasts = toasts.filter(t => t.id !== id);
  }
  
  // Export showToast for use by other components
  if (typeof window !== 'undefined') {
    (window as any).showToast = showToast;
  }
</script>

<!-- Toast Container -->
<div class="fixed top-4 right-4 z-50 space-y-2 pointer-events-none">
  {#each toasts as toast (toast.id)}
    <div
      class="pointer-events-auto bg-white rounded-lg shadow-lg border-l-4 p-4 min-w-80 max-w-md animate-slide-in"
      class:border-blue-500={toast.type === 'info'}
      class:border-yellow-500={toast.type === 'warning'}
      class:border-red-500={toast.type === 'error'}
      class:border-green-500={toast.type === 'success'}
    >
      <div class="flex items-start justify-between">
        <div class="flex items-start space-x-3">
          <!-- Icon -->
          {#if toast.type === 'info'}
            <svg class="w-6 h-6 text-blue-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
            </svg>
          {:else if toast.type === 'warning'}
            <svg class="w-6 h-6 text-yellow-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
            </svg>
          {:else if toast.type === 'error'}
            <svg class="w-6 h-6 text-red-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
            </svg>
          {:else}
            <svg class="w-6 h-6 text-green-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
          {/if}
          
          <!-- Message -->
          <p class="text-sm text-gray-800 leading-relaxed">
            {toast.message}
          </p>
        </div>
        
        <!-- Close button -->
        <button
          on:click={() => removeToast(toast.id)}
          class="ml-4 text-gray-400 hover:text-gray-600 transition-colors"
        >
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
          </svg>
        </button>
      </div>
    </div>
  {/each}
</div>

<style>
  @keyframes slide-in {
    from {
      transform: translateX(100%);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }
  
  .animate-slide-in {
    animation: slide-in 0.3s ease-out;
  }
</style>
