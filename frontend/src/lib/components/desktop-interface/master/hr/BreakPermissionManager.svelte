<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { locale } from '$lib/i18n';

	$: isRtl = $locale === 'ar';

	interface PermRow {
		user_id: string;
		username: string;
		employee_name_en: string | null;
		employee_name_ar: string | null;
		can_see_own_breaks: boolean;
		can_see_branch_breaks: boolean;
		can_see_all_breaks: boolean;
		saving?: boolean;
	}

	let rows: PermRow[] = [];
	let loading = true;
	let searchQuery = '';
	let savingAll = false;

	$: filtered = rows.filter(r => {
		if (!searchQuery.trim()) return true;
		const s = searchQuery.toLowerCase();
		return (r.username || '').toLowerCase().includes(s)
			|| (r.employee_name_en || '').toLowerCase().includes(s)
			|| (r.employee_name_ar || '').includes(s);
	});

	onMount(async () => {
		await loadPermissions();
	});

	async function loadPermissions() {
		loading = true;
		try {
			// Load active users
			const { data: users, error: usersErr } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.eq('status', 'active')
				.order('username');

			if (usersErr) throw usersErr;

			// Load existing permissions
			const { data: perms } = await supabase
				.from('break_register_permissions')
				.select('*');

			const permMap = new Map((perms || []).map((p: any) => [p.user_id, p]));

			// Load employee names
			const empIds = (users || []).map((u: any) => u.employee_id).filter(Boolean);
			let empMap = new Map<string, any>();
			if (empIds.length > 0) {
				const { data: emps } = await supabase
					.from('hr_employee_master')
					.select('id, name_en, name_ar')
					.in('id', empIds);
				empMap = new Map((emps || []).map((e: any) => [String(e.id), e]));
			}

			rows = (users || []).map((u: any) => {
				const perm = permMap.get(u.id);
				const emp = u.employee_id ? empMap.get(String(u.employee_id)) : null;
				return {
					user_id: u.id,
					username: u.username,
					employee_name_en: emp?.name_en || null,
					employee_name_ar: emp?.name_ar || null,
					can_see_own_breaks: perm?.can_see_own_breaks ?? true,
					can_see_branch_breaks: perm?.can_see_branch_breaks ?? false,
					can_see_all_breaks: perm?.can_see_all_breaks ?? false,
					saving: false
				};
			});
		} catch (err) {
			console.error('Error loading permissions:', err);
		} finally {
			loading = false;
		}
	}

	async function saveRow(row: PermRow) {
		row.saving = true;
		rows = rows; // trigger reactivity
		try {
			const { error } = await supabase
				.from('break_register_permissions')
				.upsert({
					user_id: row.user_id,
					can_see_own_breaks: row.can_see_own_breaks,
					can_see_branch_breaks: row.can_see_branch_breaks,
					can_see_all_breaks: row.can_see_all_breaks,
					updated_at: new Date().toISOString()
				}, { onConflict: 'user_id' });
			if (error) throw error;
		} catch (err) {
			console.error('Error saving permission:', err);
		} finally {
			row.saving = false;
			rows = rows;
		}
	}

	function toggle(row: PermRow, field: 'can_see_own_breaks' | 'can_see_branch_breaks' | 'can_see_all_breaks') {
		// can_see_own_breaks can never be turned off
		if (field === 'can_see_own_breaks' && row.can_see_own_breaks) return;
		(row as any)[field] = !(row as any)[field];
		rows = rows;
		saveRow(row);
	}

	function getDisplayName(row: PermRow): string {
		if (isRtl && row.employee_name_ar) return row.employee_name_ar;
		if (row.employee_name_en) return row.employee_name_en;
		return row.username;
	}
</script>

<div class="h-full flex flex-col bg-white" dir={isRtl ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="px-6 py-4 border-b border-slate-200 flex items-center justify-between gap-4 bg-slate-50">
		<div>
			<h2 class="text-lg font-black text-slate-900">{isRtl ? 'إدارة صلاحيات سجل الاستراحات' : 'Break Register Permission Manager'}</h2>
			<p class="text-xs text-slate-500 mt-0.5">{isRtl ? 'تحكم في صلاحيات عرض سجلات الاستراحات لكل مستخدم' : 'Control what break data each user can see'}</p>
		</div>
		<input
			type="text"
			bind:value={searchQuery}
			placeholder={isRtl ? 'بحث...' : 'Search...'}
			class="px-4 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 w-56"
		/>
	</div>

	<!-- Table -->
	<div class="flex-1 overflow-auto">
		{#if loading}
			<div class="flex items-center justify-center h-40 text-slate-400">{isRtl ? 'جاري التحميل...' : 'Loading...'}</div>
		{:else}
			<table class="w-full text-sm border-collapse">
				<thead class="sticky top-0 z-10 bg-slate-100">
					<tr>
						<th class="px-4 py-3 text-{isRtl ? 'right' : 'left'} font-black text-slate-700 border-b border-slate-200 w-[40%]">
							{isRtl ? 'المستخدم' : 'User'}
						</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">
							{isRtl ? 'استراحاته فقط' : 'Own Breaks'}
						</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">
							{isRtl ? 'استراحات الفرع' : 'Branch Breaks'}
						</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">
							{isRtl ? 'جميع الاستراحات' : 'All Breaks'}
						</th>
					</tr>
				</thead>
				<tbody>
					{#each filtered as row (row.user_id)}
						<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors {row.saving ? 'opacity-60' : ''}">
							<td class="px-4 py-3">
								<div class="font-semibold text-slate-900">{getDisplayName(row)}</div>
							{#if row.username.toLowerCase() !== getDisplayName(row).toLowerCase()}
								<div class="text-xs text-slate-400">@{row.username}</div>
							{/if}
							</td>
							<!-- Own Breaks (always on, locked) -->
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none cursor-not-allowed
										{row.can_see_own_breaks ? 'bg-emerald-500' : 'bg-slate-300'}"
									title={isRtl ? 'لا يمكن إيقاف هذا' : 'Cannot be disabled'}
									disabled
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.can_see_own_breaks ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>
							<!-- Branch Breaks -->
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.can_see_branch_breaks ? 'bg-blue-500' : 'bg-slate-300'}"
									on:click={() => toggle(row, 'can_see_branch_breaks')}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.can_see_branch_breaks ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>
							<!-- All Breaks -->
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.can_see_all_breaks ? 'bg-purple-500' : 'bg-slate-300'}"
									on:click={() => toggle(row, 'can_see_all_breaks')}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.can_see_all_breaks ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
			{#if filtered.length === 0}
				<div class="text-center py-12 text-slate-400">{isRtl ? 'لا توجد نتائج' : 'No results found'}</div>
			{/if}
		{/if}
	</div>

	<!-- Legend -->
	<div class="px-6 py-3 border-t border-slate-100 bg-slate-50 flex gap-6 text-xs text-slate-500 flex-wrap">
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-emerald-500 inline-block"></span>{isRtl ? 'استراحاته فقط' : 'Own Breaks'}: {isRtl ? 'ثابت للجميع' : 'Always on'}</span>
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-blue-500 inline-block"></span>{isRtl ? 'استراحات الفرع' : 'Branch Breaks'}: {isRtl ? 'يرى استراحات فرعه' : 'Sees own branch breaks'}</span>
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-purple-500 inline-block"></span>{isRtl ? 'جميع الاستراحات' : 'All Breaks'}: {isRtl ? 'يرى جميع الاستراحات' : 'Sees all branches'}</span>
	</div>
</div>
