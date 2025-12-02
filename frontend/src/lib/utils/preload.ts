// Preload frequently accessed data in the background
// This runs when the app loads to warm up the cache

import { goAPI } from './goAPI';

let preloadStarted = false;

/**
 * Preload branches data in the background
 * This warms up the cache so data loads instantly when user navigates
 */
export async function preloadBranches() {
  if (preloadStarted) return;
  preloadStarted = true;
  
  try {
    console.log('🔄 Preloading branches data...');
    const startTime = performance.now();
    await goAPI.branches.getAll();
    const loadTime = Math.round(performance.now() - startTime);
    console.log(`✅ Branches preloaded in ${loadTime}ms - ready for instant access`);
  } catch (error) {
    console.error('⚠️ Failed to preload branches:', error);
  }
}

/**
 * Initialize all preloading
 * Call this early in app lifecycle (e.g., in +layout.svelte)
 */
export function initPreload() {
  // Use setTimeout to not block initial render
  setTimeout(() => {
    preloadBranches();
  }, 100);
}
