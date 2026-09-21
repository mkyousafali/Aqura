import { supabase } from '$lib/utils/supabase';

export interface SelectableUser {
	id: string;
	username: string;
	name_en: string;
	name_ar: string;
}

// Active users that can be chosen as an ERP Entry Task assignee. Same source and inactive-user
// filtering as the picker in DefaultPositions.svelte: names live on hr_employee_master, whose
// user_id links to users.id, and users with a non-active status are dropped.
export async function loadSelectableUsers(): Promise<SelectableUser[]> {
	const { data, error } = await supabase
		.from('hr_employee_master')
		.select('user_id, name_en, name_ar, id')
		.order('name_en');
	if (error) throw error;

	const { data: inactiveUsers } = await supabase.from('users').select('id').neq('status', 'active');
	const inactiveIds = new Set((inactiveUsers || []).map((u: any) => u.id));

	return (data || [])
		.filter((emp: any) => emp.user_id && !inactiveIds.has(emp.user_id))
		.map((emp: any) => ({
			id: emp.user_id,
			username: emp.id,
			name_en: emp.name_en,
			name_ar: emp.name_ar
		}));
}

export function userDisplayName(user: SelectableUser | null | undefined, isArabic: boolean): string {
	if (!user) return '';
	return (isArabic ? user.name_ar || user.name_en : user.name_en || user.name_ar) || user.username || '';
}
