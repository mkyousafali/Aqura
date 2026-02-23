<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';

	interface Incident {
		id: string;
		incident_type_id: string;
		employee_id: string | null;
		branch_id: string;
		violation_id: string | null;
		what_happened: any;
		witness_details: any;
		report_type: string;
		reports_to_user_ids: string[];
		resolution_status: string;
		user_statuses: any;
		attachments: any[];
		created_at: string;
		created_by: string;
		// Enriched fields
		employeeName?: string;
		branchName?: string;
		incidentTypeName?: string;
		violationName?: string;
		reporterName?: string;
		claimedByName?: string;
	}

	let loading = true;
	let incidents: Incident[] = [];
	let currentUserID: string | null = null;
	let filterStatus = 'all'; // 'all', 'reported', 'claimed', 'resolved'

	onMount(async () => {
		const userData = get(currentUser);
		if (userData?.id) {
			currentUserID = userData.id;
			await loadIncidents();
		} else {
			loading = false;
		}
	});

	async function loadIncidents() {
		loading = true;
		try {
			// Fetch incidents that the user can see (they are in reports_to_user_ids)
			// Only fetch unresolved incidents (not 'resolved')
			const { data, error } = await supabase
				.from('incidents')
				.select(`
					id,
					incident_type_id,
					employee_id,
					branch_id,
					violation_id,
					what_happened,
					witness_details,
					report_type,
					reports_to_user_ids,
					resolution_status,
					user_statuses,
					attachments,
					created_at,
					created_by,
					incident_types(id, incident_type_en, incident_type_ar),
					warning_violation(id, name_en, name_ar)
				`)
				.contains('reports_to_user_ids', [currentUserID])
				.neq('resolution_status', 'resolved')
				.order('created_at', { ascending: false });

			if (error) throw error;

			if (!data || data.length === 0) {
				incidents = [];
				loading = false;
				return;
			}

			// Enrich incidents with names
			const enrichedIncidents = await Promise.all(
				data.map(async (incident: any) => {
					let employeeName = '-';
					let branchName = '-';
					let reporterName = '-';

					// Get employee name
					if (incident.employee_id) {
						const { data: empData } = await supabase
							.from('hr_employee_master')
							.select('name_en, name_ar')
							.eq('id', incident.employee_id)
							.single();
						if (empData) {
							employeeName = $currentLocale === 'ar' ? empData.name_ar : empData.name_en;
						}
					}

					// Get branch name
					if (incident.branch_id) {
						const { data: branchData } = await supabase
							.from('branches')
							.select('name_en, name_ar, location_en, location_ar')
							.eq('id', incident.branch_id)
							.single();
						if (branchData) {
							const name = $currentLocale === 'ar' ? branchData.name_ar : branchData.name_en;
							const loc = $currentLocale === 'ar' ? branchData.location_ar : branchData.location_en;
							branchName = `${name} - ${loc}`;
						}
					}

					// Get reporter name
					if (incident.created_by) {
						const { data: reporterData } = await supabase
							.from('hr_employee_master')
							.select('name_en, name_ar')
							.eq('user_id', incident.created_by)
							.single();
						if (reporterData) {
							reporterName = $currentLocale === 'ar' ? reporterData.name_ar : reporterData.name_en;
						}
					}

					// Get incident type name
					const incidentTypeName = incident.incident_types
						? ($currentLocale === 'ar' ? incident.incident_types.incident_type_ar : incident.incident_types.incident_type_en)
						: '-';

					// Get violation name
					const violationName = incident.warning_violation
						? ($currentLocale === 'ar' ? incident.warning_violation.name_ar : incident.warning_violation.name_en)
						: null;

					// Get claimed-by user name from user_statuses
					let claimedByName = '';
					const userStatuses = typeof incident.user_statuses === 'string'
						? JSON.parse(incident.user_statuses)
						: (incident.user_statuses || {});
					const claimedUserId = Object.keys(userStatuses).find(
						uid => userStatuses[uid]?.claimed_at
					);
					if (claimedUserId) {
						const { data: claimedData } = await supabase
							.from('hr_employee_master')
							.select('name_en, name_ar')
							.eq('user_id', claimedUserId)
							.single();
						if (claimedData) {
							claimedByName = $currentLocale === 'ar' ? (claimedData.name_ar || claimedData.name_en) : claimedData.name_en;
						}
					}

					return {
						...incident,
						employeeName,
						branchName,
						reporterName,
						incidentTypeName,
						violationName,
						claimedByName
					};
				})
			);

			incidents = enrichedIncidents;
		} catch (err) {
			console.error('Error loading incidents:', err);
		} finally {
			loading = false;
		}
	}

	$: filteredIncidents = incidents.filter(inc => {
		if (filterStatus === 'all') return true;
		return inc.resolution_status === filterStatus;
	});

	function getStatusColor(status: string): string {
		switch (status) {
			case 'reported': return 'status-reported';
			case 'claimed': return 'status-claimed';
			case 'resolved': return 'status-resolved';
			default: return 'status-unknown';
		}
	}

	function getStatusLabel(status: string): string {
		const labels: Record<string, { en: string; ar: string }> = {
			reported: { en: 'Reported', ar: 'مُبلَّغ عنها' },
			claimed: { en: 'Claimed', ar: 'مطالب بها' },
			resolved: { en: 'Resolved', ar: 'تم حلها' }
		};
		return $currentLocale === 'ar' ? labels[status]?.ar || status : labels[status]?.en || status;
	}

	function formatDate(dateString: string): string {
		const date = new Date(dateString);
		return date.toLocaleDateString($currentLocale === 'ar' ? 'ar-EG' : 'en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			timeZone: 'Asia/Riyadh'
		});
	}

	function openIncidentDetail(incident: Incident) {
		goto(`/mobile-interface/incident-manager/${incident.id}`);
	}
</script>

<div class="mobile-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<div class="mobile-content">
		{#if loading}
			<div class="loading-spinner">
				<div class="spinner"></div>
				<p>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
			</div>
		{:else}
			<!-- Filter Tabs -->
			<div class="filter-tabs">
				<button class="filter-tab" class:active={filterStatus === 'all'} on:click={() => filterStatus = 'all'}>
					{$currentLocale === 'ar' ? 'الكل' : 'All'} ({incidents.length})
				</button>
				<button class="filter-tab" class:active={filterStatus === 'reported'} on:click={() => filterStatus = 'reported'}>
					{$currentLocale === 'ar' ? 'مُبلَّغ' : 'Reported'} ({incidents.filter(i => i.resolution_status === 'reported').length})
				</button>
				<button class="filter-tab" class:active={filterStatus === 'claimed'} on:click={() => filterStatus = 'claimed'}>
					{$currentLocale === 'ar' ? 'مطالب' : 'Claimed'} ({incidents.filter(i => i.resolution_status === 'claimed').length})
				</button>
			</div>

			<!-- Incidents List -->
			{#if filteredIncidents.length === 0}
				<div class="empty-state">
					<span class="empty-icon">📭</span>
					<p>{$currentLocale === 'ar' ? 'لا توجد حوادث' : 'No incidents found'}</p>
				</div>
			{:else}
				<div class="incidents-list">
					{#each filteredIncidents as incident}
						<button class="incident-card" on:click={() => openIncidentDetail(incident)}>
							<div class="incident-header">
								<span class="incident-id">{incident.id}</span>
								<span class="status-badge {getStatusColor(incident.resolution_status)}">
									{getStatusLabel(incident.resolution_status)}
								</span>
							</div>
							
							<div class="incident-type">
								{incident.incidentTypeName}
							</div>
							
							{#if incident.employeeName && incident.employeeName !== '-'}
								<div class="incident-info">
									<span class="label">👤 {$currentLocale === 'ar' ? 'الموظف:' : 'Employee:'}</span>
									<span class="value">{incident.employeeName}</span>
								</div>
							{/if}
							
							<div class="incident-info">
								<span class="label">📍 {$currentLocale === 'ar' ? 'الفرع:' : 'Branch:'}</span>
								<span class="value">{incident.branchName}</span>
							</div>
							
							{#if incident.violationName}
								<div class="incident-info violation">
									<span class="label">⚠️ {$currentLocale === 'ar' ? 'المخالفة:' : 'Violation:'}</span>
									<span class="value">{incident.violationName}</span>
								</div>
							{/if}
							
							{#if incident.claimedByName}
								<div class="incident-info claimed">
									<span class="label">🔒 {$currentLocale === 'ar' ? 'مطالب من:' : 'Claimed by:'}</span>
									<span class="value">{incident.claimedByName}</span>
								</div>
							{/if}

							<div class="incident-footer">
								<span class="reporter">
									{$currentLocale === 'ar' ? 'بواسطة:' : 'By:'} {incident.reporterName}
								</span>
								<span class="date">{formatDate(incident.created_at)}</span>
							</div>
							
							<div class="view-more">
								{$currentLocale === 'ar' ? 'عرض التفاصيل ←' : 'View Details →'}
							</div>
						</button>
					{/each}
				</div>
			{/if}
		{/if}
	</div>
</div>

<style>
	.mobile-page {
		min-height: 100%;
		background: #F8FAFC;
		padding: 0;
	}
	
	.mobile-content {
		padding: 0.4rem 0.5rem;
		max-width: 100%;
		margin: 0 auto;
	}
	
	.loading-spinner {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 40vh;
		gap: 0.5rem;
		font-size: 0.82rem;
		color: #64748b;
	}
	
	.spinner {
		width: 24px;
		height: 24px;
		border: 2px solid #e2e8f0;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	
	@keyframes spin {
		to { transform: rotate(360deg); }
	}
	
	/* Filter Tabs */
	.filter-tabs {
		display: flex;
		gap: 0.3rem;
		margin-bottom: 0.5rem;
		overflow-x: auto;
		padding-bottom: 0.15rem;
	}
	
	.filter-tab {
		flex-shrink: 0;
		padding: 0.3rem 0.6rem;
		border: none;
		border-radius: 2rem;
		background: white;
		color: #64748b;
		font-size: 0.72rem;
		font-weight: 600;
		cursor: pointer;
		box-shadow: 0 1px 2px rgba(0,0,0,0.08);
		transition: all 0.2s;
	}
	
	.filter-tab.active {
		background: #3b82f6;
		color: white;
	}
	
	/* Empty State */
	.empty-state {
		text-align: center;
		padding: 2rem 0.5rem;
		color: #94a3b8;
		font-size: 0.8rem;
	}
	
	.empty-icon {
		font-size: 2rem;
		display: block;
		margin-bottom: 0.4rem;
	}
	
	/* Incidents List */
	.incidents-list {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}
	
	.incident-card {
		background: white;
		border-radius: 6px;
		padding: 0.5rem 0.6rem;
		box-shadow: 0 1px 3px rgba(0,0,0,0.06);
		cursor: pointer;
		transition: transform 0.2s, box-shadow 0.2s;
		border: none;
		width: 100%;
		text-align: inherit;
	}
	
	.incident-card:hover {
		transform: translateY(-1px);
		box-shadow: 0 2px 6px rgba(0,0,0,0.1);
	}
	
	.incident-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.25rem;
	}
	
	.incident-id {
		font-size: 0.72rem;
		font-weight: 700;
		color: #3b82f6;
	}
	
	.status-badge {
		font-size: 0.6rem;
		font-weight: 600;
		padding: 0.12rem 0.4rem;
		border-radius: 1rem;
		text-transform: uppercase;
	}
	
	.status-reported {
		background: #dbeafe;
		color: #1d4ed8;
	}
	
	.status-claimed {
		background: #fef3c7;
		color: #b45309;
	}
	
	.status-resolved {
		background: #d1fae5;
		color: #059669;
	}
	
	.status-unknown {
		background: #e5e7eb;
		color: #6b7280;
	}
	
	.incident-type {
		font-size: 0.8rem;
		font-weight: 600;
		color: #1e293b;
		margin-bottom: 0.3rem;
	}
	
	.incident-info {
		display: flex;
		gap: 0.3rem;
		font-size: 0.72rem;
		margin-bottom: 0.15rem;
	}
	
	.incident-info .label {
		color: #64748b;
	}
	
	.incident-info .value {
		color: #334155;
		font-weight: 500;
	}
	
	.incident-info.violation .value {
		color: #dc2626;
	}

	.incident-info.claimed .value {
		color: #b45309;
		font-weight: 600;
	}
	
	.incident-footer {
		display: flex;
		justify-content: space-between;
		margin-top: 0.3rem;
		padding-top: 0.3rem;
		border-top: 1px solid #f1f5f9;
		font-size: 0.66rem;
		color: #94a3b8;
	}
	
	.view-more {
		margin-top: 0.3rem;
		font-size: 0.72rem;
		font-weight: 600;
		color: #3b82f6;
		text-align: center;
	}
</style>
