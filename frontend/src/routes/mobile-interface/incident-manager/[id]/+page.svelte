<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { notifications } from '$lib/stores/notifications';

	let loading = true;
	let incident: any = null;
	let currentUserID: string | null = null;
	let currentUserName: string | null = null;
	let claimingIncident = false;
	let showImagePreview = false;
	let previewImageUrl = '';

	// Investigation state
	let showInvestigationForm = false;
	let investigationText = '';
	let savingInvestigation = false;

	// Resolution state
	let showResolutionForm = false;
	let resolutionText = '';
	let savingResolution = false;

	// Translation state
	let translations: Record<string, string> = {};
	let translatingKey = '';
	let showLangPicker = '';
	let langSearch = '';
	const translateLanguages = [
		{ code: 'en', name: 'English', flag: '🇬🇧' },
		{ code: 'ar', name: 'Arabic', flag: '🇸🇦' },
		{ code: 'ur', name: 'Urdu', flag: '🇵🇰' },
		{ code: 'hi', name: 'Hindi', flag: '🇮🇳' },
		{ code: 'bn', name: 'Bengali', flag: '🇧🇩' },
		{ code: 'tl', name: 'Filipino', flag: '🇵🇭' },
		{ code: 'ne', name: 'Nepali', flag: '🇳🇵' },
		{ code: 'id', name: 'Indonesian', flag: '🇮🇩' },
		{ code: 'ta', name: 'Tamil', flag: '🇮🇳' },
		{ code: 'ml', name: 'Malayalam', flag: '🇮🇳' },
		{ code: 'fr', name: 'French', flag: '🇫🇷' },
		{ code: 'am', name: 'Amharic', flag: '🇪🇹' },
	];
	$: filteredLangs = translateLanguages.filter(l => {
		if (!langSearch.trim()) return true;
		return l.name.toLowerCase().includes(langSearch.toLowerCase());
	});

	async function translateText(key: string, text: string, targetLang: string) {
		if (!text?.trim()) return;
		showLangPicker = '';
		langSearch = '';
		translatingKey = key;
		try {
			const resp = await fetch(
				`https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${targetLang}&dt=t&q=${encodeURIComponent(text)}`
			);
			const data = await resp.json();
			const translated = (data[0] as any[])?.map((s: any) => s[0]).join('') || '';
			if (translated) translations = { ...translations, [key]: translated };
		} catch (e) {
			console.error('Translation error:', e);
		} finally {
			translatingKey = '';
		}
	}

	$: incidentId = $page.params.id;

	onMount(async () => {
		const userData = get(currentUser);
		if (userData?.id) {
			currentUserID = userData.id;
			currentUserName = userData.employeeName || userData.username || userData.email;
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
					resolution_report,
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

			// Get claimed-by user name from user_statuses
			let claimedByName = '';
			const userStatuses = typeof data.user_statuses === 'string'
				? JSON.parse(data.user_statuses)
				: (data.user_statuses || {});
			const claimedUserId = Object.keys(userStatuses).find(
				uid => userStatuses[uid]?.status?.toLowerCase() === 'claimed'
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

			// Fetch warning/termination actions
			let warningActions: any[] = [];
			const { data: actionsData } = await supabase
				.from('incident_actions')
				.select('id, action_type, recourse_type, action_report, has_fine, fine_amount, fine_threat_amount, is_paid, created_at, created_by')
				.eq('incident_id', incidentId)
				.order('created_at', { ascending: false });
			if (actionsData) {
				warningActions = actionsData;
			}

			incident = {
				...data,
				employeeName,
				branchName,
				reporterName,
				incidentTypeName,
				violationName,
				claimedByName,
				warningActions
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
			minute: '2-digit',
			timeZone: 'Asia/Riyadh'
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

			// Add current user to reports_to_user_ids if not already there
			let reportsToIds = incident.reports_to_user_ids || [];
			if (typeof reportsToIds === 'string') {
				try {
					reportsToIds = JSON.parse(reportsToIds);
				} catch (e) {
					reportsToIds = [];
				}
			}
			
			if (!Array.isArray(reportsToIds)) {
				reportsToIds = [];
			} else {
				reportsToIds = [...reportsToIds];
			}
			
			if (!reportsToIds.includes(currentUserID)) {
				reportsToIds.push(currentUserID);
			}

			const { error } = await supabase
				.from('incidents')
				.update({
					resolution_status: 'claimed',
					claimed_user_id: currentUserID,
					user_statuses: userStatusesObj,
					reports_to_user_ids: reportsToIds
				})
				.eq('id', incident.id);

			if (error) throw error;

			await loadIncident();
			notifications.add({ type: 'success', message: $currentLocale === 'ar' ? 'تم مطالبة الحادثة بنجاح' : 'Incident claimed successfully' });
		} catch (err) {
			console.error('Error claiming incident:', err);
			notifications.add({ type: 'error', message: $currentLocale === 'ar' ? 'خطأ في مطالبة الحادثة' : 'Error claiming incident' });
		} finally {
			claimingIncident = false;
		}
	}

	function goBack() {
		goto('/mobile-interface/incident-manager');
	}

	// --- Investigation ---
	async function saveInvestigation() {
		if (!investigationText.trim() || !incident || !currentUserID) return;
		savingInvestigation = true;
		try {
			const investigationReport = {
				content: investigationText.trim(),
				investigated_by: currentUserID,
				investigated_by_name: currentUserName || 'Unknown',
				investigated_at: new Date().toISOString(),
				employee_id: incident.employee_id || null,
				employee_name: incident.employeeName || ''
			};

			const { error } = await supabase
				.from('incidents')
				.update({ investigation_report: investigationReport })
				.eq('id', incident.id);

			if (error) throw error;

			showInvestigationForm = false;
			investigationText = '';
			await loadIncident();
			notifications.add({ type: 'success', message: $currentLocale === 'ar' ? 'تم حفظ تقرير التحقيق' : 'Investigation report saved' });
		} catch (err) {
			console.error('Error saving investigation:', err);
			notifications.add({ type: 'error', message: $currentLocale === 'ar' ? 'خطأ في حفظ التحقيق' : 'Error saving investigation' });
		} finally {
			savingInvestigation = false;
		}
	}

	// --- Resolution ---
	async function saveResolution() {
		if (!resolutionText.trim() || !incident || !currentUserID) return;
		savingResolution = true;
		try {
			const resolutionReport = {
				content: resolutionText.trim(),
				resolved_by: currentUserID,
				resolved_by_name: currentUserName || 'Unknown',
				resolved_at: new Date().toISOString()
			};

			const { error } = await supabase
				.from('incidents')
				.update({
					resolution_report: resolutionReport,
					resolution_status: 'resolved',
					updated_by: currentUserID
				})
				.eq('id', incident.id);

			if (error) throw error;

			showResolutionForm = false;
			resolutionText = '';
			await loadIncident();
			notifications.add({ type: 'success', message: $currentLocale === 'ar' ? 'تم حل الحادثة بنجاح' : 'Incident resolved successfully' });
		} catch (err) {
			console.error('Error resolving incident:', err);
			notifications.add({ type: 'error', message: $currentLocale === 'ar' ? 'خطأ في حل الحادثة' : 'Error resolving incident' });
		} finally {
			savingResolution = false;
		}
	}

	function openImagePreview(url: string) {
		previewImageUrl = url;
		showImagePreview = true;
	}
</script>

<div class="mobile-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="page-header-bar">
		<h1>{$currentLocale === 'ar' ? 'تفاصيل الحادثة' : 'Incident Details'}</h1>
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
					<button class="translate-icon-btn" on:click={() => { showLangPicker = showLangPicker === 'what' ? '' : 'what'; langSearch = ''; }} title="Translate">🌐</button>
				</div>
				{#if showLangPicker === 'what'}
					<div class="lang-picker">
						<input class="lang-search" bind:value={langSearch} placeholder="Search..." />
						<div class="lang-list">
							{#each filteredLangs as lang}
								<button class="lang-btn" on:click={() => translateText('what', incident.what_happened?.description || '', lang.code)}>{lang.flag} {lang.name}</button>
							{/each}
						</div>
					</div>
				{/if}
				{#if translatingKey === 'what'}
					<div class="translating-indicator">⏳ {$currentLocale === 'ar' ? 'جاري الترجمة...' : 'Translating...'}</div>
				{/if}
				<p class="description-text">
					{incident.what_happened?.description || '-'}
				</p>
				{#if translations['what']}
					<div class="translated-box">
						<div class="translated-header">
							<span>🌐 {$currentLocale === 'ar' ? 'الترجمة' : 'Translation'}</span>
							<button class="close-translation" on:click={() => { const t = {...translations}; delete t['what']; translations = t; }}>✕</button>
						</div>
						<p>{translations['what']}</p>
					</div>
				{/if}
			</div>

			<!-- Witnesses / Evidence -->
			{#if incident.witness_details?.details}
				<div class="detail-card">
					<div class="section-title">
						<span>👁️</span>
						{$currentLocale === 'ar' ? 'الشهود / الأدلة' : 'Witnesses / Evidence'}
						<button class="translate-icon-btn" on:click={() => { showLangPicker = showLangPicker === 'witness' ? '' : 'witness'; langSearch = ''; }} title="Translate">🌐</button>
					</div>
					{#if showLangPicker === 'witness'}
						<div class="lang-picker">
							<input class="lang-search" bind:value={langSearch} placeholder="Search..." />
							<div class="lang-list">
								{#each filteredLangs as lang}
									<button class="lang-btn" on:click={() => translateText('witness', incident.witness_details.details, lang.code)}>{lang.flag} {lang.name}</button>
								{/each}
							</div>
						</div>
					{/if}
					{#if translatingKey === 'witness'}
						<div class="translating-indicator">⏳ {$currentLocale === 'ar' ? 'جاري الترجمة...' : 'Translating...'}</div>
					{/if}
					<p class="description-text">
						{incident.witness_details.details}
					</p>
					{#if translations['witness']}
						<div class="translated-box">
							<div class="translated-header">
								<span>🌐 {$currentLocale === 'ar' ? 'الترجمة' : 'Translation'}</span>
								<button class="close-translation" on:click={() => { const t = {...translations}; delete t['witness']; translations = t; }}>✕</button>
							</div>
							<p>{translations['witness']}</p>
						</div>
					{/if}
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
				{#if incident.claimedByName}
					<div class="meta-row">
						<span class="meta-label">🔒 {$currentLocale === 'ar' ? 'مطالب من:' : 'Claimed By:'}</span>
						<span class="meta-value" style="color: #b45309; font-weight: 600;">{incident.claimedByName}</span>
					</div>
				{/if}
				<div class="meta-row">
					<span class="meta-label">{$currentLocale === 'ar' ? 'التاريخ:' : 'Date:'}</span>
					<span class="meta-value">{formatDate(incident.created_at)}</span>
				</div>
			</div>

			<!-- Investigation Report -->
			{#if incident.investigation_report}
				<div class="detail-card report-card">
					<div class="section-title">
						<span>🔍</span>
						{$currentLocale === 'ar' ? 'تقرير التحقيق' : 'Investigation Report'}
						<button class="translate-icon-btn" on:click={() => { showLangPicker = showLangPicker === 'investigation' ? '' : 'investigation'; langSearch = ''; }} title="Translate">🌐</button>
					</div>
					{#if showLangPicker === 'investigation'}
						<div class="lang-picker">
							<input class="lang-search" bind:value={langSearch} placeholder="Search..." />
							<div class="lang-list">
								{#each filteredLangs as lang}
									<button class="lang-btn" on:click={() => translateText('investigation', incident.investigation_report.content || '', lang.code)}>{lang.flag} {lang.name}</button>
								{/each}
							</div>
						</div>
					{/if}
					{#if translatingKey === 'investigation'}
						<div class="translating-indicator">⏳ {$currentLocale === 'ar' ? 'جاري الترجمة...' : 'Translating...'}</div>
					{/if}
					<p class="description-text">{incident.investigation_report.content || '-'}</p>
					{#if translations['investigation']}
						<div class="translated-box">
							<div class="translated-header">
								<span>🌐 {$currentLocale === 'ar' ? 'الترجمة' : 'Translation'}</span>
								<button class="close-translation" on:click={() => { const t = {...translations}; delete t['investigation']; translations = t; }}>✕</button>
							</div>
							<p>{translations['investigation']}</p>
						</div>
					{/if}
					<div class="report-meta">
						<span>👤 {incident.investigation_report.investigated_by_name || '-'}</span>
						<span>📅 {incident.investigation_report.investigated_at ? formatDate(incident.investigation_report.investigated_at) : '-'}</span>
					</div>
				</div>
			{:else if isClaimedByCurrentUser() && incident.resolution_status !== 'resolved'}
				{#if showInvestigationForm}
					<div class="detail-card report-card">
						<div class="section-title">
							<span>🔍</span>
							{$currentLocale === 'ar' ? 'كتابة تقرير التحقيق' : 'Write Investigation Report'}
						</div>
						<textarea
							class="report-textarea"
							bind:value={investigationText}
							placeholder={$currentLocale === 'ar' ? 'اكتب تقرير التحقيق هنا...' : 'Write your investigation report here...'}
							rows="5"
						></textarea>
						<div class="report-form-actions">
							<button
								class="action-btn save-btn"
								on:click={saveInvestigation}
								disabled={savingInvestigation || !investigationText.trim()}
							>
								{#if savingInvestigation}
									<span class="btn-spinner"></span>
								{:else}
									💾
								{/if}
								{$currentLocale === 'ar' ? 'حفظ التحقيق' : 'Save Investigation'}
							</button>
							<button class="action-btn cancel-btn" on:click={() => { showInvestigationForm = false; investigationText = ''; }}>
								{$currentLocale === 'ar' ? 'إلغاء' : 'Cancel'}
							</button>
						</div>
					</div>
				{:else}
					<button class="action-btn investigate-btn" on:click={() => showInvestigationForm = true}>
						🔍 {$currentLocale === 'ar' ? 'كتابة تقرير التحقيق' : 'Write Investigation Report'}
					</button>
				{/if}
			{/if}

			<!-- Warning / Termination Actions -->
			{#if incident.warningActions && incident.warningActions.length > 0}
				{#each incident.warningActions as action}
					<div class="detail-card warning-card">
						<div class="section-title">
							<span>{action.action_type === 'termination' ? '🚫' : '⚠️'}</span>
							{action.action_type === 'termination'
								? ($currentLocale === 'ar' ? 'إنهاء الخدمة' : 'Termination')
								: ($currentLocale === 'ar' ? 'تقرير الإنذار' : 'Warning Report')}
						</div>

						{#if action.recourse_type}
							<div class="warning-type-badge">
								{action.recourse_type.replace(/_/g, ' ')}
							</div>
						{/if}

						{#if action.action_report?.report_content}
							<div class="translate-row">
								<button class="translate-icon-btn" on:click={() => { showLangPicker = showLangPicker === `warning-${action.id}` ? '' : `warning-${action.id}`; langSearch = ''; }} title="Translate">🌐</button>
							</div>
							{#if showLangPicker === `warning-${action.id}`}
								<div class="lang-picker">
									<input class="lang-search" bind:value={langSearch} placeholder="Search..." />
									<div class="lang-list">
										{#each filteredLangs as lang}
											<button class="lang-btn" on:click={() => translateText(`warning-${action.id}`, action.action_report.report_content, lang.code)}>{lang.flag} {lang.name}</button>
										{/each}
									</div>
								</div>
							{/if}
							{#if translatingKey === `warning-${action.id}`}
								<div class="translating-indicator">⏳ {$currentLocale === 'ar' ? 'جاري الترجمة...' : 'Translating...'}</div>
							{/if}
							<p class="description-text warning-content">{action.action_report.report_content}</p>
							{#if translations[`warning-${action.id}`]}
								<div class="translated-box">
									<div class="translated-header">
										<span>🌐 {$currentLocale === 'ar' ? 'الترجمة' : 'Translation'}</span>
										<button class="close-translation" on:click={() => { const t = {...translations}; delete t[`warning-${action.id}`]; translations = t; }}>✕</button>
									</div>
									<p>{translations[`warning-${action.id}`]}</p>
								</div>
							{/if}
						{/if}

						{#if action.has_fine}
							<div class="fine-info">
								<span class="fine-label">💰 {$currentLocale === 'ar' ? 'الغرامة:' : 'Fine:'}</span>
								<span class="fine-amount">{action.fine_amount || action.fine_threat_amount || 0} SAR</span>
								{#if action.is_paid}
									<span class="paid-badge">{$currentLocale === 'ar' ? 'مدفوع' : 'Paid'}</span>
								{:else}
									<span class="unpaid-badge">{$currentLocale === 'ar' ? 'غير مدفوع' : 'Unpaid'}</span>
								{/if}
							</div>
						{/if}

						<div class="report-meta">
							<span>📅 {action.created_at ? formatDate(action.created_at) : '-'}</span>
						</div>
					</div>
				{/each}
			{/if}

			<!-- Resolution Report -->
			{#if incident.resolution_report}
				<div class="detail-card report-card">
					<div class="section-title">
						<span>✅</span>
						{$currentLocale === 'ar' ? 'تقرير الحل' : 'Resolution Report'}
						<button class="translate-icon-btn" on:click={() => { showLangPicker = showLangPicker === 'resolution' ? '' : 'resolution'; langSearch = ''; }} title="Translate">🌐</button>
					</div>
					{#if showLangPicker === 'resolution'}
						<div class="lang-picker">
							<input class="lang-search" bind:value={langSearch} placeholder="Search..." />
							<div class="lang-list">
								{#each filteredLangs as lang}
									<button class="lang-btn" on:click={() => translateText('resolution', incident.resolution_report.content || '', lang.code)}>{lang.flag} {lang.name}</button>
								{/each}
							</div>
						</div>
					{/if}
					{#if translatingKey === 'resolution'}
						<div class="translating-indicator">⏳ {$currentLocale === 'ar' ? 'جاري الترجمة...' : 'Translating...'}</div>
					{/if}
					<p class="description-text">{incident.resolution_report.content || '-'}</p>
					{#if translations['resolution']}
						<div class="translated-box">
							<div class="translated-header">
								<span>🌐 {$currentLocale === 'ar' ? 'الترجمة' : 'Translation'}</span>
								<button class="close-translation" on:click={() => { const t = {...translations}; delete t['resolution']; translations = t; }}>✕</button>
							</div>
							<p>{translations['resolution']}</p>
						</div>
					{/if}
					<div class="report-meta">
						<span>👤 {incident.resolution_report.resolved_by_name || '-'}</span>
						<span>📅 {incident.resolution_report.resolved_at ? formatDate(incident.resolution_report.resolved_at) : '-'}</span>
					</div>
				</div>
			{:else if isClaimedByCurrentUser() && incident.resolution_status !== 'resolved'}
				{#if showResolutionForm}
					<div class="detail-card report-card">
						<div class="section-title">
							<span>✅</span>
							{$currentLocale === 'ar' ? 'كتابة تقرير الحل' : 'Write Resolution Report'}
						</div>
						<textarea
							class="report-textarea"
							bind:value={resolutionText}
							placeholder={$currentLocale === 'ar' ? 'اكتب تقرير الحل هنا...' : 'Write your resolution report here...'}
							rows="5"
						></textarea>
						<div class="report-form-actions">
							<button
								class="action-btn save-btn resolve-btn-gradient"
								on:click={saveResolution}
								disabled={savingResolution || !resolutionText.trim()}
							>
								{#if savingResolution}
									<span class="btn-spinner"></span>
								{:else}
									✅
								{/if}
								{$currentLocale === 'ar' ? 'حل الحادثة' : 'Resolve Incident'}
							</button>
							<button class="action-btn cancel-btn" on:click={() => { showResolutionForm = false; resolutionText = ''; }}>
								{$currentLocale === 'ar' ? 'إلغاء' : 'Cancel'}
							</button>
						</div>
					</div>
				{:else}
					<button class="action-btn resolve-btn" on:click={() => showResolutionForm = true}>
						✅ {$currentLocale === 'ar' ? 'حل الحادثة' : 'Resolve Incident'}
					</button>
				{/if}
			{/if}

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
		min-height: 100%;
		background: #F8FAFC;
		padding: 0;
	}

	.page-header-bar {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.4rem 0.6rem;
		background: white;
		border-bottom: 1px solid #e5e7eb;
		position: sticky;
		top: 0;
		z-index: 100;
	}

	.page-header-bar h1 {
		font-size: 0.88rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0;
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

	.back-link {
		margin-top: 0.5rem;
		padding: 0.4rem 0.8rem;
		border: none;
		border-radius: 5px;
		background: #3b82f6;
		color: white;
		font-size: 0.78rem;
		cursor: pointer;
	}

	/* ID and Status Row */
	.id-status-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.4rem;
	}

	.incident-id {
		font-size: 0.82rem;
		font-weight: 700;
		color: #3b82f6;
	}

	.status-badge {
		font-size: 0.6rem;
		font-weight: 600;
		padding: 0.15rem 0.5rem;
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
		border-radius: 6px;
		padding: 0.5rem 0.6rem;
		margin-bottom: 0.4rem;
		box-shadow: 0 1px 3px rgba(0,0,0,0.06);
	}

	.type-card {
		background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
		text-align: center;
		padding: 0.4rem;
	}

	.type-label {
		font-size: 0.82rem;
		font-weight: 700;
		color: white;
	}

	.detail-row {
		display: flex;
		gap: 0.4rem;
		padding: 0.3rem 0;
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
		font-size: 0.88rem;
		flex-shrink: 0;
	}

	.detail-content {
		flex: 1;
	}

	.detail-content label {
		display: block;
		font-size: 0.62rem;
		font-weight: 600;
		color: #94a3b8;
		text-transform: uppercase;
		margin-bottom: 0.05rem;
	}

	.detail-content p {
		margin: 0;
		font-size: 0.78rem;
		color: #1e293b;
		font-weight: 500;
	}

	.violation-row .violation-text {
		color: #dc2626;
		font-weight: 600;
	}

	.section-title {
		font-size: 0.76rem;
		font-weight: 700;
		color: #475569;
		margin-bottom: 0.3rem;
		display: flex;
		align-items: center;
		gap: 0.3rem;
	}

	.description-text {
		margin: 0;
		font-size: 0.78rem;
		color: #334155;
		line-height: 1.5;
		background: #f8fafc;
		padding: 0.4rem 0.5rem;
		border-radius: 5px;
		word-break: break-word;
		overflow-wrap: break-word;
	}

	/* Attachments */
	.attachments-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(60px, 1fr));
		gap: 0.35rem;
	}

	.attachment-thumb {
		aspect-ratio: 1;
		border-radius: 5px;
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
		padding: 0.4rem;
		background: #f1f5f9;
		border-radius: 5px;
		text-decoration: none;
		gap: 0.15rem;
	}

	.file-icon {
		font-size: 1.2rem;
	}

	.file-name {
		font-size: 0.55rem;
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
		font-size: 0.72rem;
		padding: 0.15rem 0;
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
		gap: 0.35rem;
		margin-top: 0.5rem;
	}

	.action-btn {
		width: 100%;
		padding: 0.5rem;
		border: none;
		border-radius: 6px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
		min-height: 36px;
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
		top: 0.5rem;
		right: 0.5rem;
		width: 32px;
		height: 32px;
		border: none;
		border-radius: 50%;
		background: white;
		color: #1e293b;
		font-size: 1.2rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	/* Report Cards */
	.report-card {
		border-left: 3px solid #3b82f6;
	}

	.report-meta {
		display: flex;
		justify-content: space-between;
		font-size: 0.65rem;
		color: #64748b;
		margin-top: 0.35rem;
		padding-top: 0.25rem;
		border-top: 1px solid #f1f5f9;
	}

	.report-textarea {
		width: 100%;
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.78rem;
		font-family: inherit;
		resize: vertical;
		min-height: 80px;
		background: #f8fafc;
		color: #1e293b;
		line-height: 1.5;
		box-sizing: border-box;
	}

	.report-textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.15);
	}

	.report-form-actions {
		display: flex;
		gap: 0.35rem;
		margin-top: 0.4rem;
	}

	.report-form-actions .action-btn {
		flex: 1;
		min-height: 34px;
		font-size: 0.76rem;
	}

	.save-btn {
		background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
		color: white;
	}

	.save-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.resolve-btn-gradient {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%) !important;
		color: white !important;
	}

	.cancel-btn {
		background: white;
		border: 1px solid #d1d5db;
		color: #6b7280;
	}

	.investigate-btn {
		background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
		color: white;
		margin-bottom: 0.3rem;
	}

	.investigate-btn:hover {
		transform: translateY(-1px);
	}

	.resolve-btn {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		margin-bottom: 0.3rem;
	}

	.resolve-btn:hover {
		transform: translateY(-1px);
	}

	/* Warning Card */
	.warning-card {
		border-left: 3px solid #f59e0b;
	}

	.warning-type-badge {
		display: inline-block;
		padding: 0.1rem 0.4rem;
		background: #fef3c7;
		color: #92400e;
		font-size: 0.62rem;
		font-weight: 600;
		border-radius: 3px;
		text-transform: capitalize;
		margin-bottom: 0.3rem;
	}

	.warning-content {
		white-space: pre-wrap;
	}

	.fine-info {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-top: 0.3rem;
		padding: 0.25rem 0.4rem;
		background: #fffbeb;
		border-radius: 4px;
		font-size: 0.72rem;
	}

	.fine-label {
		color: #92400e;
		font-weight: 500;
	}

	.fine-amount {
		color: #b45309;
		font-weight: 700;
	}

	.paid-badge {
		padding: 0.05rem 0.3rem;
		background: #d1fae5;
		color: #059669;
		font-size: 0.6rem;
		font-weight: 600;
		border-radius: 3px;
	}

	.unpaid-badge {
		padding: 0.05rem 0.3rem;
		background: #fee2e2;
		color: #dc2626;
		font-size: 0.6rem;
		font-weight: 600;
		border-radius: 3px;
	}

	/* Translation */
	.translate-icon-btn {
		margin-inline-start: auto;
		background: none;
		border: none;
		font-size: 0.82rem;
		cursor: pointer;
		padding: 0.1rem 0.2rem;
		border-radius: 4px;
		transition: background 0.2s;
	}

	.translate-icon-btn:hover {
		background: #e2e8f0;
	}

	.translate-row {
		display: flex;
		justify-content: flex-end;
		margin-bottom: 0.15rem;
	}

	.lang-picker {
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 6px;
		padding: 0.3rem;
		margin-bottom: 0.3rem;
		box-shadow: 0 2px 8px rgba(0,0,0,0.1);
	}

	.lang-search {
		width: 100%;
		padding: 0.25rem 0.4rem;
		border: 1px solid #e2e8f0;
		border-radius: 4px;
		font-size: 0.72rem;
		margin-bottom: 0.2rem;
		box-sizing: border-box;
	}

	.lang-search:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.lang-list {
		display: flex;
		flex-wrap: wrap;
		gap: 0.2rem;
		max-height: 120px;
		overflow-y: auto;
	}

	.lang-btn {
		padding: 0.2rem 0.4rem;
		border: 1px solid #e2e8f0;
		border-radius: 4px;
		background: #f8fafc;
		font-size: 0.65rem;
		cursor: pointer;
		transition: all 0.15s;
		white-space: nowrap;
	}

	.lang-btn:hover {
		background: #dbeafe;
		border-color: #93c5fd;
	}

	.translating-indicator {
		font-size: 0.7rem;
		color: #3b82f6;
		padding: 0.15rem 0;
		animation: pulse 1s infinite;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	.translated-box {
		margin-top: 0.3rem;
		background: #eff6ff;
		border: 1px solid #bfdbfe;
		border-radius: 5px;
		padding: 0.35rem 0.45rem;
	}

	.translated-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.2rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #2563eb;
	}

	.close-translation {
		background: none;
		border: none;
		color: #93c5fd;
		cursor: pointer;
		font-size: 0.72rem;
		padding: 0 0.15rem;
	}

	.close-translation:hover {
		color: #2563eb;
	}

	.translated-box p {
		margin: 0;
		font-size: 0.76rem;
		color: #1e40af;
		line-height: 1.5;
		white-space: pre-wrap;
		word-break: break-word;
	}
</style>
