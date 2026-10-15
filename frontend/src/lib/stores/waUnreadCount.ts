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

export const internalWaUnreadCounts = writable<WAUnreadCounts>({
	total: 0,
	loading: true
});

let refreshInterval: ReturnType<typeof setInterval> | null = null;
let conversationsChannel: any = null;

async function getUnreadTotal(accountId: string): Promise<number> {
	const { data, error } = await supabase
		.from('wa_conversations')
		.select('unread_count')
		.eq('wa_account_id', accountId)
		.eq('status', 'active')
		.gt('unread_count', 0);
	if (error) throw error;
	return (data || []).reduce((sum, conversation) => sum + (conversation.unread_count || 0), 0);
}

export async function fetchWAUnreadCount() {
	try {
		const { data: account } = await supabase
			.from('wa_accounts')
			.select('id')
			.eq('is_active', true)
			.eq('is_default', true)
			.maybeSingle();
		
		if (!account) {
			waUnreadCounts.set({ total: 0, loading: false });
			return;
		}

		const total = await getUnreadTotal(account.id);
		waUnreadCounts.set({ total, loading: false });
	} catch (e) {
		console.error('Error fetching WA unread counts:', e);
		waUnreadCounts.set({ total: 0, loading: false });
	}
}

export async function fetchInternalWAUnreadCount() {
	try {
		const { data } = await supabase.rpc('get_internal_whatsapp_account');
		const account = Array.isArray(data) ? data[0] : data;
		if (!account?.id) {
			internalWaUnreadCounts.set({ total: 0, loading: false });
			return;
		}
		const total = await getUnreadTotal(account.id);
		internalWaUnreadCounts.set({ total, loading: false });
	} catch (error) {
		console.error('Error fetching internal WA unread counts:', error);
		internalWaUnreadCounts.set({ total: 0, loading: false });
	}
}

async function refreshAllWAUnreadCounts() {
	await Promise.all([fetchWAUnreadCount(), fetchInternalWAUnreadCount()]);
}

export function initWAUnreadMonitoring() {
	refreshAllWAUnreadCounts();

	if (refreshInterval) clearInterval(refreshInterval);
	refreshInterval = setInterval(refreshAllWAUnreadCounts, 30000);

	if (conversationsChannel) supabase.removeChannel(conversationsChannel);
	conversationsChannel = supabase
		.channel('taskbar-wa-unread-counts')
		.on('postgres_changes', { event: '*', schema: 'public', table: 'wa_conversations' }, refreshAllWAUnreadCounts)
		.subscribe();
}

export function stopWAUnreadMonitoring() {
	if (refreshInterval) {
		clearInterval(refreshInterval);
		refreshInterval = null;
	}
	if (conversationsChannel) {
		supabase.removeChannel(conversationsChannel);
		conversationsChannel = null;
	}
}
