import { writable } from 'svelte/store';
import { supabase } from '$lib/utils/supabase';

export interface WAUnreadCounts {
	total: number;
	loading: boolean;
}

export const waUnreadCounts = writable<WAUnreadCounts>({
	total: 0,
	loading: true
});

let refreshInterval: ReturnType<typeof setInterval> | null = null;

export async function fetchWAUnreadCount() {
	try {
		// Get the first active WA account
		const { data: accounts } = await supabase
			.from('wa_accounts')
			.select('id')
			.eq('is_active', true)
			.limit(1);
		
		if (!accounts || accounts.length === 0) {
			waUnreadCounts.set({ total: 0, loading: false });
			return;
		}

		const accountId = accounts[0].id;

		const { data, error } = await supabase
			.from('wa_conversations')
			.select('unread_count')
			.eq('wa_account_id', accountId)
			.eq('status', 'active')
			.gt('unread_count', 0);

		if (error) throw error;

		const total = (data || []).reduce((sum, c) => sum + (c.unread_count || 0), 0);
		waUnreadCounts.set({ total, loading: false });
	} catch (e) {
		console.error('Error fetching WA unread counts:', e);
		waUnreadCounts.set({ total: 0, loading: false });
	}
}

export function initWAUnreadMonitoring() {
	// Initial fetch
	fetchWAUnreadCount();

	// Refresh every 30 seconds
	if (refreshInterval) clearInterval(refreshInterval);
	refreshInterval = setInterval(fetchWAUnreadCount, 30000);
}

export function stopWAUnreadMonitoring() {
	if (refreshInterval) {
		clearInterval(refreshInterval);
		refreshInterval = null;
	}
}
