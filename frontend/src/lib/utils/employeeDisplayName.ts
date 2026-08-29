import { supabase } from './supabase';

/**
 * Resolves the locale-appropriate display name for a verified user from hr_employee_master
 * (name_ar/name_en) rather than the users.username the various `verify_quick_access_code` call
 * sites were previously showing — usernames are login handles, not the employee's actual name in
 * either language. Falls back through the other language's name, then the given username, in case
 * a user has no linked hr_employee_master row (or it's missing one of the two name columns).
 *
 * Mirrors the inline pattern already used in CashierLogin.svelte's login flow.
 */
export async function getEmployeeDisplayName(userId: string, locale: string, fallbackUsername: string): Promise<string> {
	try {
		const { data, error } = await supabase
			.from('hr_employee_master')
			.select('name_en, name_ar')
			.eq('user_id', userId)
			.maybeSingle();

		if (error) {
			console.warn('getEmployeeDisplayName: query error for user_id', userId, error);
			return fallbackUsername;
		}
		if (!data) {
			console.warn('getEmployeeDisplayName: no hr_employee_master row for user_id', userId, '— falling back to', fallbackUsername);
			return fallbackUsername;
		}
		if (!data.name_en && !data.name_ar) {
			console.warn('getEmployeeDisplayName: hr_employee_master row for user_id', userId, 'has no name_en/name_ar set — falling back to', fallbackUsername);
		}

		if (locale === 'ar') {
			return data.name_ar || data.name_en || fallbackUsername;
		}
		return data.name_en || data.name_ar || fallbackUsername;
	} catch (err) {
		console.error('Error resolving employee display name:', err);
		return fallbackUsername;
	}
}
