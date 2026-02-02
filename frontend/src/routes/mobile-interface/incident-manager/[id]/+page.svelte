<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';

	let loading = true;
	let incident: any = null;
	let currentUserID: string | null = null;
	let claimingIncident = false;
	let showImagePreview = false;
	let previewImageUrl = '';

	$: incidentId = $page.params.id;

	onMount(async () => {
		const userData = get(currentUser);
		if (userData?.id) {
			currentUserID = userData.id;
			await loadIncident();
		} else {
			loading = false;
		}
	});

	async function loadIncident() {
		loading = true;
		try {
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
					related_party,
					report_type,
					reports_to_user_ids,
					resolution_status,
					user_statuses,
					attachments,
					investigation_report,
					created_at,
					created_by,
					incident_types(id, incident_type_en, incident_type_ar),
					warning_violation(id, name_en, name_ar)
				`)
				.eq('id', incidentId)
				.single();

			if (error) throw error;

			if (!data) {
				incident = null;
				loading = false;
				return;
			}

			// Enrich with names
			let employeeName = '-';
			let branchName = '-';
			let reporterName = '-';

			// Get employee name
			if (data.employee_id) {
				const { data: empData } = await supabase
					.from('hr_employee_master')
					.select('name_en, name_ar')
					.eq('id', data.employee_id)
					.single();
				if (empData) {
					employeeName = $currentLocale === 'ar' ? empData.name_ar : empData.name_en;
				}
			}

			// Get branch name
			if (data.branch_id) {
				const { data: branchData } = await supabase
					.from('branches')
					.select('name_en, name_ar, location_en, location_ar')
					.eq('id', data.branch_id)
					.single();
				if (branchData) {
					const name = $currentLocale === 'ar' ? branchData.name_ar : branchData.name_en;
					const loc = $currentLocale === 'ar' ? branchData.location_ar : branchData.location_en;
					branchName = `${name} - ${loc}`;
				}
			}

			// Get reporter name
			if (data.created_by) {
				const { data: reporterData } = await supabase
					.from('hr_employee_master')
					.select('name_en, name_ar')
					.eq('user_id', data.created_by)
					.single();
				if (reporterData) {
					reporterName = $currentLocale === 'ar' ? reporterData.name_ar : reporterData.name_en;
				}
			}

			// Get incident type name
			const incidentTypeName = data.incident_types
				? ($currentLocale === 'ar' ? data.incident_types.incident_type_ar : data.incident_types.incident_type_en)
				: '-';

			// Get violation name
			const violationName = data.warning_violation
				? ($currentLocale === 'ar' ? data.warning_violation.name_ar : data.warning_violation.name_en)
				: null;

			incident = {
				...data,
				employeeName,
				branchName,
				reporterName,
				incidentTypeName,
				violationName
			};
		} catch (err) {
			console.error('Error loading incident:', err);
		} finally {
			loading = false;
		}
	}

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
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function isClaimedByCurrentUser(): boolean {
		if (!incident?.user_statuses || !currentUserID) return false;
		const userStatuses = typeof incident.user_statuses === 'string'
			? JSON.parse(incident.user_statuses)
			: incident.user_statuses;
		return userStatuses[currentUserID]?.status?.toLowerCase() === 'claimed';
	}

	function canClaim(): boolean {
		if (!incident) return false;
		return incident.resolution_status === 'reported' && !isClaimedByCurrentUser();
	}

	async function claimIncident() {
		if (!currentUserID || !incident) return;
		
		claimingIncident = true;
		try {
			const userStatusesObj = typeof incident.user_statuses === 'string'
				? JSON.parse(incident.user_statuses)
				: (incident.user_statuses || {});

			userStatusesObj[currentUserID] = {
				...userStatusesObj[currentUserID],
				status: 'claimed',
				claimed_at: new Date().toISOString()
			};

			const { error } = await supabase
				.from('incidents')
				.update({
					resolution_status: 'claimed',
					user_statuses: userStatusesObj
				})
				.eq('id', incident.id);

			if (error) throw error;

			await loadIncident();
			alert($currentLocale === 'ar' ? '✅ تم مطالبة الحادثة بنجاح' : '✅ Incident claimed successfully');
		} catch (err) {
			console.error('Error claiming incident:', err);
			alert($currentLocale === 'ar' ? '❌ خطأ في مطالبة الحادثة' : '❌ Error claiming incident');
		} finally {
			claimingIncident = false;
		}
	}

	function goBack() {
		goto('/mobile-interface/incident-manager');
	}

	function openImagePreview(url: string) {
		previewImageUrl = url;
		showImagePreview = true;
	}
</script>

<div class="mobile-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="page-header-bar">
		<button class="back-btn" on:click={goBack}>
			{$currentLocale === 'ar' ? '→' : '←'}
		</button>
		<h1>{$currentLocale === 'ar' ? 'تفاصيل الحادثة' : 'Incident Details'}</h1>
		<div class="spacer"></div>
	</div>

	<div class="mobile-content">
		{#if loading}
			<div class="loading-spinner">
				<div class="spinner"></div>
				<p>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
			</div>
		{:else if !incident}
			<div class="empty-state">
				<span class="empty-icon">❌</span>
				<p>{$currentLocale === 'ar' ? 'لم يتم العثور على الحادثة' : 'Incident not found'}</p>
				<button class="back-link" on:click={goBack}>
					{$currentLocale === 'ar' ? '← العودة' : '← Go Back'}
				</button>
			</div>
		{:else}
			<!-- Incident ID and Status -->
			<div class="id-status-row">
				<span class="incident-id">{incident.id}</span>
				<span class="status-badge {getStatusColor(incident.resolution_status)}">
					{getStatusLabel(incident.resolution_status)}
				</span>
			</div>

			<!-- Incident Type Card -->
			<div class="detail-card type-card">
				<span class="type-label">{incident.incidentTypeName}</span>
			</div>

			<!-- Main Details -->
			<div class="detail-card">
				{#if incident.employeeName && incident.employeeName !== '-'}
					<div class="detail-row">
						<span class="detail-icon">👤</span>
						<div class="detail-content">
							<label>{$currentLocale === 'ar' ? 'الموظف' : 'Employee'}</label>
							<p>{incident.employeeName}</p>
						</div>
					</div>
				{/if}

				<div class="detail-row">
					<span class="detail-icon">📍</span>
					<div class="detail-content">
						<label>{$currentLocale === 'ar' ? 'الفرع' : 'Branch'}</label>
						<p>{incident.branchName}</p>
					</div>
				</div>

				{#if incident.violationName}
					<div class="detail-row violation-row">
						<span class="detail-icon">⚠️</span>
						<div class="detail-content">
							<label>{$currentLocale === 'ar' ? 'المخالفة' : 'Violation'}</label>
							<p class="violation-text">{incident.violationName}</p>
						</div>
					</div>
				{/if}

				{#if incident.related_party}
					<div class="detail-row">
						<span class="detail-icon">🧑‍🤝‍🧑</span>
						<div class="detail-content">
							<label>{$currentLocale === 'ar' ? 'الطرف المعني' : 'Related Party'}</label>
							<p>
								{#if incident.related_party.name}
									{incident.related_party.name}
									{#if incident.related_party.contact_number}
										<br/><small>📞 {incident.related_party.contact_number}</small>
									{/if}
								{:else if incident.related_party.details}
									{incident.related_party.details}
								{/if}
							</p>
						</div>
					</div>
				{/if}
			</div>

			<!-- What Happened -->
			<div class="detail-card">
				<div class="section-title">
					<span>📝</span>
					{$currentLocale === 'ar' ? 'ماذا حدث؟' : 'What Happened?'}
				</div>
				<p class="description-text">
					{incident.what_happened?.description || '-'}
				</p>
			</div>

			<!-- Witnesses / Evidence -->
			{#if incident.witness_details?.details}
				<div class="detail-card">
					<div class="section-title">
						<span>👁️</span>
						{$currentLocale === 'ar' ? 'الشهود / الأدلة' : 'Witnesses / Evidence'}
					</div>
					<p class="description-text">
						{incident.witness_details.details}
					</p>
				</div>
			{/if}

			<!-- Attachments -->
			{#if incident.attachments && incident.attachments.length > 0}
				<div class="detail-card">
					<div class="section-title">
						<span>📎</span>
						{$currentLocale === 'ar' ? 'المرفقات' : 'Attachments'} ({incident.attachments.length})
					</div>
					<div class="attachments-grid">
						{#each incident.attachments as att}
							{#if att.type === 'image'}
								<div class="attachment-thumb" on:click={() => openImagePreview(att.url)}>
									<img src={att.url} alt={att.name} />
								</div>
							{:else}
								<a href={att.url} target="_blank" class="attachment-file">
									<span class="file-icon">📄</span>
									<span class="file-name">{att.name}</span>
								</a>
							{/if}
						{/each}
					</div>
				</div>
			{/if}

			<!-- Reporter Info -->
			<div class="detail-card meta-card">
				<div class="meta-row">
					<span class="meta-label">{$currentLocale === 'ar' ? 'المُبلِّغ:' : 'Reported By:'}</span>
					<span class="meta-value">{incident.reporterName}</span>
				</div>
				<div class="meta-row">
					<span class="meta-label">{$currentLocale === 'ar' ? 'التاريخ:' : 'Date:'}</span>
					<span class="meta-value">{formatDate(incident.created_at)}</span>
				</div>
			</div>

			<!-- Action Buttons -->
			<div class="action-buttons">
				{#if canClaim()}
					<button 
						class="action-btn claim-btn"
						on:click={claimIncident}
						disabled={claimingIncident}
					>
						{#if claimingIncident}
							<span class="btn-spinner"></span>
						{:else}
							✋
						{/if}
						{$currentLocale === 'ar' ? 'مطالبة بالحادثة' : 'Claim Incident'}
					</button>
				{/if}
				
				<button class="action-btn back-btn-full" on:click={goBack}>
					{$currentLocale === 'ar' ? 'العودة للقائمة' : 'Back to List'}
				</button>
			</div>
		{/if}
	</div>
</div>

<!-- Image Preview Modal -->
{#if showImagePreview}
	<div class="image-preview-overlay" on:click={() => showImagePreview = false}>
		<img src={previewImageUrl} alt="Preview" />
		<button class="close-preview" on:click={() => showImagePreview = false}>×</button>
	</div>
{/if}

<style>
	.mobile-page {
		min-height: 100vh;
		background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
		padding-bottom: 100px;
	}

	.page-header-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		background: white;
		border-bottom: 1px solid #e5e7eb;
		position: sticky;
		top: 0;
		z-index: 100;
	}

	.page-header-bar h1 {
		font-size: 1.125rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0;
	}

	.back-btn {
		width: 36px;
		height: 36px;
		border: none;
		border-radius: 50%;
		background: #f1f5f9;
		color: #475569;
		font-size: 1.25rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.spacer {
		width: 36px;
	}

	.mobile-content {
		padding: 1rem;
		max-width: 600px;
		margin: 0 auto;
	}

	.loading-spinner {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 1rem;
		color: #64748b;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 3px solid #e2e8f0;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.empty-state {
		text-align: center;
		padding: 3rem 1rem;
		color: #94a3b8;
	}

	.empty-icon {
		font-size: 4rem;
		display: block;
		margin-bottom: 1rem;
	}

	.back-link {
		margin-top: 1rem;
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 0.5rem;
		background: #3b82f6;
		color: white;
		font-size: 0.9rem;
		cursor: pointer;
	}

	/* ID and Status Row */
	.id-status-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.incident-id {
		font-size: 1.25rem;
		font-weight: 700;
		color: #3b82f6;
	}

	.status-badge {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.375rem 1rem;
		border-radius: 2rem;
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

	/* Detail Cards */
	.detail-card {
		background: white;
		border-radius: 1rem;
		padding: 1rem;
		margin-bottom: 1rem;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
	}

	.type-card {
		background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
		text-align: center;
	}

	.type-label {
		font-size: 1.125rem;
		font-weight: 700;
		color: white;
	}

	.detail-row {
		display: flex;
		gap: 0.75rem;
		padding: 0.75rem 0;
		border-bottom: 1px solid #f1f5f9;
	}

	.detail-row:last-child {
		border-bottom: none;
		padding-bottom: 0;
	}

	.detail-row:first-child {
		padding-top: 0;
	}

	.detail-icon {
		font-size: 1.25rem;
		flex-shrink: 0;
	}

	.detail-content {
		flex: 1;
	}

	.detail-content label {
		display: block;
		font-size: 0.7rem;
		font-weight: 600;
		color: #94a3b8;
		text-transform: uppercase;
		margin-bottom: 0.125rem;
	}

	.detail-content p {
		margin: 0;
		font-size: 0.9rem;
		color: #1e293b;
		font-weight: 500;
	}

	.violation-row .violation-text {
		color: #dc2626;
		font-weight: 600;
	}

	.section-title {
		font-size: 0.875rem;
		font-weight: 700;
		color: #475569;
		margin-bottom: 0.75rem;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.description-text {
		margin: 0;
		font-size: 0.9rem;
		color: #334155;
		line-height: 1.6;
		background: #f8fafc;
		padding: 0.75rem;
		border-radius: 0.5rem;
	}

	/* Attachments */
	.attachments-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(80px, 1fr));
		gap: 0.5rem;
	}

	.attachment-thumb {
		aspect-ratio: 1;
		border-radius: 0.5rem;
		overflow: hidden;
		cursor: pointer;
		border: 1px solid #e5e7eb;
	}

	.attachment-thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.attachment-file {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 0.75rem;
		background: #f1f5f9;
		border-radius: 0.5rem;
		text-decoration: none;
		gap: 0.25rem;
	}

	.file-icon {
		font-size: 1.5rem;
	}

	.file-name {
		font-size: 0.6rem;
		color: #475569;
		text-align: center;
		word-break: break-all;
	}

	/* Meta Card */
	.meta-card {
		background: #f8fafc;
	}

	.meta-row {
		display: flex;
		justify-content: space-between;
		font-size: 0.8rem;
		padding: 0.25rem 0;
	}

	.meta-label {
		color: #64748b;
	}

	.meta-value {
		color: #1e293b;
		font-weight: 500;
	}

	/* Action Buttons */
	.action-buttons {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		margin-top: 1.5rem;
	}

	.action-btn {
		width: 100%;
		padding: 1rem;
		border: none;
		border-radius: 0.75rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		transition: transform 0.2s;
	}

	.claim-btn {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		color: white;
	}

	.claim-btn:hover:not(:disabled) {
		transform: translateY(-2px);
	}

	.claim-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}

	.back-btn-full {
		background: white;
		border: 1px solid #d1d5db;
		color: #374151;
	}

	.btn-spinner {
		width: 1.25rem;
		height: 1.25rem;
		border: 2px solid white;
		border-top-color: transparent;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	/* Image Preview */
	.image-preview-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.9);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 2000;
		padding: 1rem;
	}

	.image-preview-overlay img {
		max-width: 100%;
		max-height: 90vh;
		object-fit: contain;
		border-radius: 0.5rem;
	}

	.close-preview {
		position: absolute;
		top: 1rem;
		right: 1rem;
		width: 44px;
		height: 44px;
		border: none;
		border-radius: 50%;
		background: white;
		color: #1e293b;
		font-size: 1.5rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}
</style>
