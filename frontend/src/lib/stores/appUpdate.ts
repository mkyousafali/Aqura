import { writable } from 'svelte/store';

// Store to track if a PWA update is available
// Set by +layout.svelte when service worker detects new version
// Read by any interface (desktop, mobile, cashier, customer) to show update button
export const updateAvailable = writable(false);

// Store the update function so any component can trigger it
export const triggerUpdate = writable<(() => Promise<void>) | null>(null);
