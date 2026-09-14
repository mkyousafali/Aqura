<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import EmployeeAnalysisWindow from '$lib/components/desktop-interface/master/hr/EmployeeAnalysisWindow.svelte';

	let employee: any = null;
	let loading = true;
	let errorMessage = '';

	// Match the desktop employee-analysis default: the 25th of the previous
	// month through yesterday, with no user-editable date controls.
	const yesterday = getYesterday();
	const rangeStartDate = getPreviousMonth25th();

	function formatLocalDate(date: Date): string {
		const year = date.getFullYear();
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const day = String(date.getDate()).padStart(2, '0');
		return `${year}-${month}-${day}`;
	}

	function getPreviousMonth25th(): string {
		const today = new Date();
		return formatLocalDate(new Date(today.getFullYear(), today.getMonth() - 1, 25));
	}

	function getYesterday(): string {
		const date = new Date();
		date.setDate(date.getDate() - 1);
		return formatLocalDate(date);
	}

	onMount(async () => {
		try {
			const loggedInUserId = $currentUser?.id;
			if (!loggedInUserId) {
				errorMessage = 'No logged-in user was found.';
				return;
			}

			// Resolve the employee exclusively from the authenticated application session.
			// No route parameter or user-controlled employee ID is accepted.
			const { data: employeeLink, error: linkError } = await supabase
				.from('hr_employee_master')
				.select('id')
				.eq('user_id', loggedInUserId)
				.single();

			if (linkError || !employeeLink) {
				throw linkError || new Error('No employee record is linked to this user.');
			}

			const { data: employeeRecord, error: employeeError } = await supabase
				.from('hr_employee_master_with_status')
				.select(`
					id,
					name_en,
					name_ar,
					current_branch_id,
					nationality_id,
					employment_status,
					employment_status_effective_date,
					sponsorship_status
				`)
				.eq('id', employeeLink.id)
				.single();

			if (employeeError || !employeeRecord) {
				throw employeeError || new Error('Employee details could not be loaded.');
			}

			const [{ data: branch }, { data: nationality }] = await Promise.all([
				employeeRecord.current_branch_id
					? supabase.from('branches').select('name_en, name_ar').eq('id', employeeRecord.current_branch_id).maybeSingle()
					: Promise.resolve({ data: null }),
				employeeRecord.nationality_id
					? supabase.from('nationalities').select('name_en, name_ar').eq('id', employeeRecord.nationality_id).maybeSingle()
					: Promise.resolve({ data: null })
			]);

			employee = {
				...employeeRecord,
				branch_name_en: branch?.name_en,
				branch_name_ar: branch?.name_ar,
				nationality_name_en: nationality?.name_en,
				nationality_name_ar: nationality?.name_ar
			};
		} catch (error) {
			console.error('Mobile fingerprint analysis failed to initialize:', error);
			errorMessage = error instanceof Error ? error.message : 'Fingerprint analysis could not be loaded.';
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Fingerprint Analysis</title>
</svelte:head>

<div class="mobile-analysis-page">
	{#if loading}
		<div class="state-card" role="status">Loading fingerprint analysis…</div>
	{:else if errorMessage}
		<div class="state-card error" role="alert">{errorMessage}</div>
	{:else if employee}
		<EmployeeAnalysisWindow
			{employee}
			windowId="mobile-employee-analysis"
			initialStartDate={rangeStartDate}
			initialEndDate={yesterday}
			mobileMode={true}
		/>
	{/if}
</div>

<!-- Prevent scrolling cards from showing through/around the fixed bottom bar. -->
<div class="bottom-navigation-mask" aria-hidden="true"></div>

<style>
	.mobile-analysis-page {
		background: #f8fafc;
		box-sizing: border-box;
		max-width: 100%;
		min-height: 100%;
		overflow-x: clip;
		width: 100%;
	}

	.state-card {
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 0.75rem;
		color: #475569;
		margin: 1rem;
		padding: 1rem;
		text-align: center;
	}

	.state-card.error {
		background: #fef2f2;
		border-color: #fecaca;
		color: #b91c1c;
	}

	.bottom-navigation-mask {
		background: #f8fafc;
		bottom: 0;
		height: calc(3.9rem + env(safe-area-inset-bottom, 0px));
		left: 0;
		pointer-events: none;
		position: fixed;
		right: 0;
		z-index: 899;
	}
</style>
