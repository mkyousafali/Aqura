import { writable } from 'svelte/store';

/** True when the order system is blocked (customer_login_mask_enabled = true in delivery_service_settings) */
export const orderMaskEnabled = writable(false);
