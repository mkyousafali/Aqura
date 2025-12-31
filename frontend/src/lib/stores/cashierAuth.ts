/**
 * Cashier Authentication Store
 * 
 * Separate authentication system for cashier interface to avoid conflicts
 * with the main desktop authentication system.
 */

import { writable } from 'svelte/store';

export interface CashierUser {
	id: string;
	username: string;
	employee_id?: string;
	branch_id?: string;
	full_name: string;
	employeeName: string;
	name: string;
	role: string;
}

export interface CashierBranch {
	id: string;
	name_ar: string;
	name_en: string;
}

// Cashier-specific authentication stores (separate from main auth)
export const cashierUser = writable<CashierUser | null>(null);
export const cashierBranch = writable<CashierBranch | null>(null);
export const isCashierAuthenticated = writable<boolean>(false);

// Session storage keys
const CASHIER_USER_KEY = 'cashier_user';
const CASHIER_BRANCH_KEY = 'cashier_branch';

/**
 * Initialize cashier session from sessionStorage
 */
export function initCashierSession() {
	if (typeof window === 'undefined') return;

	try {
		const savedUser = sessionStorage.getItem(CASHIER_USER_KEY);
		const savedBranch = sessionStorage.getItem(CASHIER_BRANCH_KEY);

		if (savedUser && savedBranch) {
			const user = JSON.parse(savedUser) as CashierUser;
			const branch = JSON.parse(savedBranch) as CashierBranch;

			cashierUser.set(user);
			cashierBranch.set(branch);
			isCashierAuthenticated.set(true);

			return { user, branch };
		}
	} catch (error) {
		console.error('Failed to restore cashier session:', error);
		clearCashierSession();
	}

	return null;
}

/**
 * Set cashier authentication
 */
export function setCashierAuth(user: CashierUser, branch: CashierBranch) {
	if (typeof window === 'undefined') return;

	try {
		// Save to stores
		cashierUser.set(user);
		cashierBranch.set(branch);
		isCashierAuthenticated.set(true);

		// Save to sessionStorage
		sessionStorage.setItem(CASHIER_USER_KEY, JSON.stringify(user));
		sessionStorage.setItem(CASHIER_BRANCH_KEY, JSON.stringify(branch));
	} catch (error) {
		console.error('Failed to set cashier authentication:', error);
	}
}

/**
 * Clear cashier authentication
 */
export function clearCashierSession() {
	if (typeof window === 'undefined') return;

	// Clear stores
	cashierUser.set(null);
	cashierBranch.set(null);
	isCashierAuthenticated.set(false);

	// Clear sessionStorage
	try {
		sessionStorage.removeItem(CASHIER_USER_KEY);
		sessionStorage.removeItem(CASHIER_BRANCH_KEY);
	} catch (error) {
		console.error('Failed to clear cashier session:', error);
	}
}
