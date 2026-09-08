import { writable } from 'svelte/store';

export interface BranchBillResult {
	branchId: string;
	branchName: string;
	locationEn: string;
	locationAr: string;
	count: number;
	total: number;
	lastBillDate: string | null;
}

export interface BillDetail {
	date: string;
	amount: number;
	branchId: string;
	branchName: string;
}

export interface ContactBillData {
	branchResults: BranchBillResult[];
	totalCount: number;
	totalAmount: number;
	lastBillDate: string | null;
	billDetails?: BillDetail[];
	broadcastStats?: { sent: number; delivered: number; read: number };
}

export interface CachedContact {
	id: string;
	name: string;
	whatsapp_number: string;
	registration_status: string;
	whatsapp_available: boolean | null;
	last_message_at: string | null;
	last_interaction_at: string | null;
	approved_at: string | null;
	last_login_at: string | null;
	unread_count: number;
	is_inside_24hr: boolean;
	conversation_id: string | null;
	created_at: string;
}

/**
 * In-memory cache for WAContacts data.
 * Persists across component mounts/unmounts within the same browser session.
 * Cleared only when the user closes the app (tab/window).
 */
export const billCountCache = writable<Map<string, ContactBillData>>(new Map());
export const contactsCache = writable<CachedContact[]>([]);
export const contactsTotalCount = writable<number>(0);

/**
 * ERP existence cache — tracks whether a phone number exists in any branch's PrivilegeCards.
 * Key: contact ID, Value: { exists: boolean, branches: string[] }
 */
export interface ErpExistence {
	exists: boolean;
	branches: string[];
}
export const erpExistenceCache = writable<Map<string, ErpExistence>>(new Map());
