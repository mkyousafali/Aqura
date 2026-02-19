<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { localeData } from '$lib/i18n';

	let isLoading = true;
	let errorMessage = '';
	let teamTasks: any[] = [];
	let filteredTeamTasks: any[] = [];
	let teamFilter = 'pending'; // 'pending' | 'completed'
	let selectedMember = 'all'; // 'all' | user_id
	let showMemberPopup = false;
	let isBranchManager = false;
	let userNameCacheEn: Record<string, string> = {};
	let userNameCacheAr: Record<string, string> = {};
	let previewImageUrl = '';
	let showImagePreview = false;

	function openImagePreview(url: string) {
		previewImageUrl = url;
		showImagePreview = true;
	}

	function closeImagePreview() {
		showImagePreview = false;
		previewImageUrl = '';
	}

	$: currentUserData = $currentUser;
	$: isRTL = $localeData.code === 'ar';

	// Tasks filtered by current status filter (for popup counts)
	$: statusFilteredTasks = teamFilter === 'completed'
		? teamTasks.filter(t => t.task_status === 'completed')
		: teamTasks.filter(t => t.task_status !== 'completed');

	// Get unique team members for the dropdown
	$: teamMembers = (() => {
		const memberIds = [...new Set(teamTasks.map(t => t.assigned_user_id))];
		return memberIds.map(id => ({ id, name: isRTL ? (userNameCacheAr[id] || 'غير معروف') : (userNameCacheEn[id] || 'Unknown') }));
	})();

	// Filter team tasks by status + selected member
	$: {
		let tasks = teamTasks;
		if (selectedMember !== 'all') {
			tasks = tasks.filter(t => t.assigned_user_id === selectedMember);
		}
		if (teamFilter === 'completed') {
			filteredTeamTasks = tasks.filter(t => t.task_status === 'completed');
		} else {
			filteredTeamTasks = tasks.filter(t => t.task_status !== 'completed');
		}
	}

	$: memberFilteredTasks = selectedMember === 'all' ? teamTasks : teamTasks.filter(t => t.assigned_user_id === selectedMember);
	$: teamPendingCount = memberFilteredTasks.filter(t => t.task_status !== 'completed').length;
	$: teamCompletedCount = memberFilteredTasks.filter(t => t.task_status === 'completed').length;

	onMount(async () => {
		if (!$isAuthenticated || !currentUserData) {
			goto('/login');
			return;
		}
		await loadTeamTasks();
	});

	async function loadTeamTasks() {
		isLoading = true;
		errorMessage = '';
		try {
			const { data, error } = await supabase.rpc('get_receiving_tasks_for_user', {
				p_user_id: currentUserData.id,
				p_completed_days: 7
			});

			if (error) throw error;

			teamTasks = data.team_tasks || [];
			isBranchManager = data.is_branch_manager || false;

			if (!isBranchManager) {
				errorMessage = isRTL ? 'هذه الصفحة متاحة لمديري الفروع فقط' : 'This page is only available for branch managers';
				teamTasks = [];
			}

			// Build user name cache (bilingual)
			if (data.employee_names && data.employee_names.length > 0) {
				data.employee_names.forEach((u: any) => {
					userNameCacheEn[u.user_id] = u.name_en;
					userNameCacheAr[u.user_id] = u.name_ar;
				});
				userNameCacheEn = { ...userNameCacheEn };
				userNameCacheAr = { ...userNameCacheAr };
			}
		} catch (err) {
			console.error('Error loading team tasks:', err);
			errorMessage = isRTL ? 'فشل تحميل مهام الفريق' : 'Failed to load team tasks';
		} finally {
			isLoading = false;
		}
	}

	function getEmployeeName(userId: string) {
		return isRTL ? (userNameCacheAr[userId] || 'غير معروف') : (userNameCacheEn[userId] || 'Unknown');
	}

	function openTask(task: any) {
		goto(`/mobile-interface/receiving-tasks/${task.id}`);
	}

	function getRoleLabel(role: string) {
		if (isRTL) {
			switch (role) {
				case 'shelf_stocker': return 'مُرتِّب الأرفف';
				case 'night_supervisor': return 'مشرف ليلي';
				case 'branch_manager': return 'مدير الفرع';
				case 'warehouse_handler': return 'أمين المستودع';
				case 'inventory_manager': return 'مدير المخزون';
				case 'purchase_manager': return 'مدير المشتريات';
				case 'accountant': return 'المحاسب';
				default: return role;
			}
		}
		switch (role) {
			case 'shelf_stocker': return 'Shelf Stocker';
			case 'night_supervisor': return 'Night Supervisor';
			case 'branch_manager': return 'Branch Manager';
			case 'warehouse_handler': return 'Warehouse Handler';
			case 'inventory_manager': return 'Inventory Manager';
			case 'purchase_manager': return 'Purchase Manager';
			case 'accountant': return 'Accountant';
			default: return role;
		}
	}

	function getStatusColor(status: string) {
		switch (status) {
			case 'completed': return '#22C55E';
			case 'in_progress': return '#3B82F6';
			default: return '#EAB308';
		}
	}

	function getStatusLabel(status: string) {
		if (isRTL) {
			switch (status) {
				case 'completed': return 'مكتمل';
				case 'pending': return 'قيد الانتظار';
				case 'in_progress': return 'قيد التنفيذ';
				default: return status;
			}
		}
		switch (status) {
			case 'completed': return 'Completed';
			case 'pending': return 'Pending';
			case 'in_progress': return 'In Progress';
			default: return status;
		}
	}

	function getPriorityColor(priority: string) {
		switch (priority) {
			case 'urgent': return '#EF4444';
			case 'high': return '#F97316';
			case 'medium': return '#EAB308';
			case 'low': return '#22C55E';
			default: return '#6B7280';
		}
	}

	function getPriorityLabel(priority: string) {
		if (isRTL) {
			switch (priority) {
				case 'urgent': return 'عاجل';
				case 'high': return 'مرتفع';
				case 'medium': return 'متوسط';
				case 'low': return 'منخفض';
				default: return priority;
			}
		}
		return priority ? priority.charAt(0).toUpperCase() + priority.slice(1) : '';
	}

	function formatDate(dateStr: string) {
		if (!dateStr) return '';
		const date = new Date(dateStr);
		return date.toLocaleDateString(isRTL ? 'ar-SA' : 'en-US', { month: 'short', day: 'numeric', year: 'numeric' });
	}

	/** Extract localized text from bilingual string (EN|||AR format) */
	function localized(text: string): string {
		if (!text) return '';
		if (text.includes('|||')) {
			const parts = text.split('|||');
			return isRTL ? (parts[1] || parts[0]).trim() : parts[0].trim();
		}
		return text;
	}

	/** Localized description - extracts dynamic details from English part for old Arabic descriptions */
	function localizedDesc(text: string): string {
		if (!text) return '';
		if (!text.includes('|||')) return text;

		const parts = text.split('|||');
		if (!isRTL) return parts[0].trim();

		let arabicPart = (parts[1] || parts[0]).trim();
		const englishPart = parts[0];

		// If Arabic part already has details (new template format), return as is
		if (arabicPart.includes('الفرع:') || arabicPart.includes('المورد:')) return arabicPart;

		// Extract details from English part and add Arabic labels
		const detailLines: string[] = [];
		const patterns: [RegExp, string][] = [
			[/Branch:\s*(.+)/,          'الفرع'],
			[/Vendor:\s*(.+)/,          'المورد'],
			[/Bill Amount:\s*(.+)/,     'مبلغ الفاتورة'],
			[/Bill Number:\s*(.+)/,     'رقم الفاتورة'],
			[/Received Date:\s*(.+)/,   'تاريخ الاستلام'],
			[/Received By:\s*(.+)/,     'استلمها'],
			[/Deadline:\s*(.+)/,        'الموعد النهائي']
		];

		for (const [pattern, label] of patterns) {
			const match = englishPart.match(pattern);
			if (match) detailLines.push(`${label}: ${match[1].trim()}`);
		}

		if (detailLines.length > 0) {
			// Insert details after first paragraph break in Arabic text (handle \r\n or \n)
			const breakMatch = arabicPart.match(/(\r?\n){2}/);
			if (breakMatch && breakMatch.index !== undefined) {
				const intro = arabicPart.substring(0, breakMatch.index);
				const rest = arabicPart.substring(breakMatch.index);
				arabicPart = intro + '\n\n' + detailLines.join('\n') + rest;
			} else {
				arabicPart = arabicPart + '\n\n' + detailLines.join('\n');
			}
		}

		return arabicPart;
	}

	function timeAgo(dateStr: string) {
		if (!dateStr) return '';
		const now = new Date();
		const date = new Date(dateStr);
		const diffMs = now.getTime() - date.getTime();
		const diffMin = Math.floor(diffMs / 60000);
		const diffHr = Math.floor(diffMin / 60);
		const diffDay = Math.floor(diffHr / 24);

		if (isRTL) {
			if (diffMin < 1) return 'الآن';
			if (diffMin < 60) return `منذ ${diffMin} دقيقة`;
			if (diffHr < 24) {
				const remainMin = diffMin % 60;
				return remainMin > 0 ? `منذ ${diffHr} ساعة ${remainMin} دقيقة` : `منذ ${diffHr} ساعة`;
			}
			const remainHr = diffHr % 24;
			return remainHr > 0 ? `منذ ${diffDay} يوم ${remainHr} ساعة` : `منذ ${diffDay} يوم`;
		}

		if (diffMin < 1) return 'just now';
		if (diffMin < 60) return `${diffMin} min ago`;
		if (diffHr < 24) {
			const remainMin = diffMin % 60;
			return remainMin > 0 ? `${diffHr} hr ${remainMin} min ago` : `${diffHr} hr ago`;
		}
		const remainHr = diffHr % 24;
		return remainHr > 0 ? `${diffDay} day ${remainHr} hr ago` : `${diffDay} day ago`;
	}

	function isOverdue(task: any) {
		if (task.task_status === 'completed' || !task.due_date) return false;
		return new Date(task.due_date) < new Date();
	}

	function selectMember(memberId: string) {
		selectedMember = memberId;
		showMemberPopup = false;
		memberSearch = '';
	}

	let memberSearch = '';
	$: filteredPopupMembers = memberSearch
		? teamMembers.filter(m => m.name.toLowerCase().includes(memberSearch.toLowerCase()))
		: teamMembers;

	$: selectedMemberName = selectedMember === 'all'
		? (isRTL ? 'جميع الأعضاء' : 'All Members')
		: (isRTL ? (userNameCacheAr[selectedMember] || 'غير معروف') : (userNameCacheEn[selectedMember] || 'Unknown'));
</script>

<svelte:head>
	<title>{isRTL ? 'مهام فريق الاستلام' : 'Team Receiving Tasks'}</title>
</svelte:head>

<div class="mobile-tasks" class:rtl={isRTL}>
	<!-- Filters -->
	<div class="filters-section">
		<div class="filter-chips">
			<button class="filter-chip" class:active={teamFilter === 'pending'} on:click={() => teamFilter = 'pending'}>
				{isRTL ? 'قيد الانتظار' : 'Pending'}
				<span class="chip-count">{teamPendingCount}</span>
			</button>
			<button class="filter-chip" class:active={teamFilter === 'completed'} on:click={() => teamFilter = 'completed'}>
				{isRTL ? 'مكتمل' : 'Completed'}
				<span class="chip-count">{teamCompletedCount}</span>
			</button>
			<button class="refresh-chip" on:click={loadTeamTasks} disabled={isLoading} aria-label="Refresh">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class:spinning={isLoading}>
					<polyline points="23 4 23 10 17 10"/>
					<path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
				</svg>
			</button>
		</div>
		{#if teamMembers.length > 1}
			<button class="member-filter-btn" on:click={() => showMemberPopup = true}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
					<circle cx="12" cy="7" r="4"/>
				</svg>
				<span class="member-filter-label">{selectedMemberName}</span>
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<polyline points="6 9 12 15 18 9"/>
				</svg>
			</button>
		{/if}
		<div class="results-count">
			{filteredTeamTasks.length} {isRTL ? 'مهمة فريق' : (filteredTeamTasks.length !== 1 ? 'team tasks found' : 'team task found')}
			{#if teamFilter === 'completed'}
				<span class="period-info">({isRTL ? 'آخر 7 أيام' : 'Last 7 days'})</span>
			{/if}
		</div>
	</div>

	<!-- Content -->
	<div class="content-section">
		{#if isLoading}
			<div class="loading-skeleton">
				{#each Array(4) as _, i}
					<div class="skeleton-card">
						<div class="skeleton-header">
							<div class="skeleton-title"></div>
							<div class="skeleton-badges">
								<div class="skeleton-badge"></div>
								<div class="skeleton-badge"></div>
							</div>
						</div>
						<div class="skeleton-text"></div>
						<div class="skeleton-text short"></div>
						<div class="skeleton-details">
							<div class="skeleton-detail"></div>
							<div class="skeleton-detail"></div>
						</div>
						<div class="skeleton-actions">
							<div class="skeleton-button"></div>
							<div class="skeleton-button"></div>
						</div>
					</div>
				{/each}
			</div>
		{:else if errorMessage}
			<div class="empty-state">
				<div class="empty-icon">
					<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#EF4444" stroke-width="1.5">
						<circle cx="12" cy="12" r="10"/>
						<line x1="15" y1="9" x2="9" y2="15"/>
						<line x1="9" y1="9" x2="15" y2="15"/>
					</svg>
				</div>
				<h2>{errorMessage}</h2>
				<p>
					<button class="retry-btn" on:click={loadTeamTasks}>{isRTL ? 'إعادة المحاولة' : 'Retry'}</button>
				</p>
			</div>
		{:else if filteredTeamTasks.length === 0}
			<div class="empty-state">
				<div class="empty-icon">
					<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
						<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
						<circle cx="9" cy="7" r="4"/>
						<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
						<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
					</svg>
				</div>
				<h2>{teamFilter === 'completed'
					? (isRTL ? 'لا توجد مهام مكتملة' : 'No Completed Tasks')
					: (isRTL ? 'لا توجد مهام قيد الانتظار' : 'No Pending Tasks')}</h2>
				<p>{isRTL ? 'لا توجد مهام مطابقة للفلتر الحالي' : 'No tasks match the current filter'}</p>
			</div>
		{:else}
			<div class="task-list">
				{#each filteredTeamTasks as task (task.id)}
					<div class="task-card" class:overdue={isOverdue(task)}>
						<div class="task-header">
							<div class="task-title-section">
								<h3>{localized(task.title)}</h3>
								<div class="task-meta">
									<span class="task-type-badge employee-badge">
										<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
											<circle cx="12" cy="7" r="4"/>
										</svg>
										{getEmployeeName(task.assigned_user_id)}
									</span>
									{#if task.role_type}
										<span class="task-type-badge role-badge">{getRoleLabel(task.role_type)}</span>
									{/if}
									<span class="task-priority" style="background-color: {getPriorityColor(task.priority)}15; color: {getPriorityColor(task.priority)}">
										{getPriorityLabel(task.priority)}
									</span>
									<span class="task-status" style="background-color: {getStatusColor(task.task_status)}15; color: {getStatusColor(task.task_status)}">
										{getStatusLabel(task.task_status)}
									</span>
								</div>
							</div>
							{#if isOverdue(task)}
								<div class="overdue-badge">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<line x1="12" y1="8" x2="12" y2="12"/>
										<line x1="12" y1="16" x2="12.01" y2="16"/>
									</svg>
								</div>
							{/if}
						</div>

						<div class="task-content">
							{#if task.description}
								<p class="task-description">{task.clearance_certificate_url ? localizedDesc(task.description).replace(/https?:\/\/\S+/g, '').trim() : localizedDesc(task.description)}</p>
							{/if}

							<div class="task-details">
								{#if task.due_date}
									<div class="task-detail">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
											<line x1="16" y1="2" x2="16" y2="6"/>
											<line x1="8" y1="2" x2="8" y2="6"/>
											<line x1="3" y1="10" x2="21" y2="10"/>
										</svg>
										<span class:deadline-text={isOverdue(task)}>{isRTL ? 'الموعد:' : 'Due:'} {formatDate(task.due_date)}</span>
									</div>
								{/if}

								<div class="task-detail">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
										<circle cx="12" cy="7" r="4"/>
									</svg>
									<span>{isRTL ? 'الموظف:' : 'Assigned to:'} {getEmployeeName(task.assigned_user_id)}</span>
								</div>

								<div class="task-detail">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<polyline points="12 6 12 12 16 14"/>
									</svg>
									<span>{isRTL ? 'أنشئت:' : 'Created:'} {formatDate(task.created_at)}</span>
								</div>

								{#if task.completed_at && task.task_status === 'completed'}
									<div class="task-detail completed-time">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
											<polyline points="22 4 12 14.01 9 11.01"/>
										</svg>
										<span>{isRTL ? 'اكتملت:' : 'Completed:'} {timeAgo(task.completed_at)}</span>
									</div>
								{/if}
							</div>

							{#if task.completion_photo_url && task.task_status === 'completed'}
							<div class="completion-photo-section" role="region" aria-label="Completion photo">
									<span class="completion-photo-label">
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
											<circle cx="8.5" cy="8.5" r="1.5"/>
											<polyline points="21 15 16 10 5 21"/>
										</svg>
										{isRTL ? 'صورة الإنجاز' : 'Completion Photo'}
									</span>
									<button class="completion-photo-thumb" on:click|stopPropagation={() => openImagePreview(task.completion_photo_url)}>
										<img src={task.completion_photo_url} alt="Completion" loading="lazy" />
									</button>
								</div>
							{/if}

							{#if task.clearance_certificate_url}
								<a class="certificate-link" href={task.clearance_certificate_url} target="_blank" rel="noopener" on:click|stopPropagation>
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
										<polyline points="14 2 14 8 20 8"/>
										<line x1="16" y1="13" x2="8" y2="13"/>
										<line x1="16" y1="17" x2="8" y2="17"/>
									</svg>
									{isRTL ? 'شهادة التخليص' : 'Clearance Certificate'}
								</a>
							{/if}
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<!-- Image Preview Overlay -->
{#if showImagePreview}
	<div class="image-preview-overlay" on:click={closeImagePreview} on:keydown={(e) => e.key === 'Escape' && closeImagePreview()} role="dialog" tabindex="-1">
		<button class="image-preview-close" on:click={closeImagePreview} aria-label="Close">
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<line x1="18" y1="6" x2="6" y2="18"/>
				<line x1="6" y1="6" x2="18" y2="18"/>
			</svg>
		</button>
		<!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
		<div class="image-preview-img-wrap" on:click|stopPropagation>
			<img src={previewImageUrl} alt="Completion" class="image-preview-img" />
		</div>
	</div>
{/if}

<!-- Member Popup -->
{#if showMemberPopup}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div class="popup-overlay" on:click={() => showMemberPopup = false} on:keydown={(e) => e.key === 'Escape' && (showMemberPopup = false)} role="dialog" tabindex="-1">
		<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
		<div class="popup-sheet" on:click|stopPropagation>
			<div class="popup-header">
				<h3>{isRTL ? 'اختر عضو الفريق' : 'Select Team Member'}</h3>
				<button class="popup-close" on:click={() => { showMemberPopup = false; memberSearch = ''; }} aria-label="Close">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>
			<div class="popup-search">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="11" cy="11" r="8"/>
					<path d="M21 21l-4.35-4.35"/>
				</svg>
				<input type="text" bind:value={memberSearch} placeholder={isRTL ? 'بحث عضو...' : 'Search member...'} class="popup-search-input" />
			</div>
			<div class="popup-list">
				{#if !memberSearch}
					<button class="popup-item" class:selected={selectedMember === 'all'} on:click={() => selectMember('all')}>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
							<circle cx="9" cy="7" r="4"/>
							<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
							<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
						</svg>
						<span>{isRTL ? 'جميع الأعضاء' : 'All Members'}</span>
						<span class="popup-count">{statusFilteredTasks.length}</span>
					</button>
				{/if}
				{#each filteredPopupMembers as member}
					<button class="popup-item" class:selected={selectedMember === member.id} on:click={() => selectMember(member.id)}>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
							<circle cx="12" cy="7" r="4"/>
						</svg>
						<span>{member.name}</span>
						<span class="popup-count">{statusFilteredTasks.filter(t => t.assigned_user_id === member.id).length}</span>
					</button>
				{/each}
				{#if memberSearch && filteredPopupMembers.length === 0}
					<div class="popup-empty">{isRTL ? 'لا توجد نتائج' : 'No results found'}</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.mobile-tasks {
		min-height: 100vh;
		background: #F8FAFC;
	}

	.mobile-tasks.rtl {
		direction: rtl;
	}

	/* Filters Section */
	.filters-section {
		padding: 0.5rem 0.75rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.filter-chips {
		display: flex;
		gap: 0.4rem;
		align-items: center;
	}

	.filter-chip {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
		padding: 0.4rem 0.5rem;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		background: white;
		font-size: 0.72rem;
		font-weight: 500;
		color: #6B7280;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.filter-chip.active {
		background: #3B82F6;
		color: white;
		border-color: #3B82F6;
	}

	.filter-chip:not(.active):hover {
		background: #F9FAFB;
	}

	.chip-count {
		font-size: 0.62rem;
		font-weight: 600;
		padding: 0.1rem 0.35rem;
		border-radius: 4px;
		background: rgba(0, 0, 0, 0.08);
	}

	.filter-chip.active .chip-count {
		background: rgba(255, 255, 255, 0.25);
	}

	.refresh-chip {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.4rem;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		background: white;
		color: #6B7280;
		cursor: pointer;
		transition: all 0.2s;
		flex-shrink: 0;
	}

	.refresh-chip:hover { background: #F9FAFB; }
	.refresh-chip:disabled { opacity: 0.5; cursor: not-allowed; }

	.spinning {
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	.results-count {
		font-size: 0.65rem;
		color: #9CA3AF;
		margin-top: 0.4rem;
	}

	.period-info {
		color: #6B7280;
		font-style: italic;
	}

	/* Member Filter Button */
	.member-filter-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-top: 0.5rem;
		padding: 0.35rem 0.5rem;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		background: white;
		color: #374151;
		font-size: 0.72rem;
		cursor: pointer;
		transition: all 0.2s;
		width: 100%;
	}

	.member-filter-btn:hover {
		border-color: #3B82F6;
		background: #F9FAFB;
	}

	.member-filter-label {
		flex: 1;
		text-align: start;
	}

	/* Member Popup */
	.popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1000;
		display: flex;
		align-items: flex-end;
		justify-content: center;
		animation: fadeIn 0.2s ease;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.popup-sheet {
		background: white;
		border-radius: 16px 16px 0 0;
		width: 100%;
		max-width: 500px;
		max-height: 70vh;
		overflow: hidden;
		animation: slideUp 0.3s ease;
	}

	@keyframes slideUp {
		from { transform: translateY(100%); }
		to { transform: translateY(0); }
	}

	.popup-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.popup-header h3 {
		font-size: 0.88rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
	}

	.popup-close {
		background: none;
		border: none;
		color: #9CA3AF;
		cursor: pointer;
		padding: 0.25rem;
		border-radius: 6px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.15s;
	}

	.popup-close:hover {
		background: #F3F4F6;
		color: #374151;
	}

	.popup-list {
		overflow-y: auto;
		max-height: calc(70vh - 120px);
		padding: 0.5rem;
	}

	.popup-search {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.5rem 0.75rem;
		border-bottom: 1px solid #F3F4F6;
		color: #9CA3AF;
	}

	.popup-search-input {
		flex: 1;
		border: none;
		outline: none;
		font-size: 0.78rem;
		color: #374151;
		background: transparent;
	}

	.popup-search-input::placeholder {
		color: #9CA3AF;
	}

	.popup-empty {
		text-align: center;
		padding: 1.5rem;
		color: #9CA3AF;
		font-size: 0.75rem;
	}

	.popup-item {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.65rem 0.75rem;
		border: none;
		border-radius: 8px;
		background: transparent;
		color: #374151;
		font-size: 0.78rem;
		cursor: pointer;
		transition: all 0.15s;
		text-align: start;
	}

	.popup-item:hover {
		background: #F9FAFB;
	}

	.popup-item.selected {
		background: #EFF6FF;
		color: #2563EB;
		font-weight: 600;
	}

	.popup-item span:first-of-type {
		flex: 1;
	}

	.popup-count {
		font-size: 0.65rem;
		font-weight: 600;
		padding: 0.1rem 0.4rem;
		border-radius: 10px;
		background: #F3F4F6;
		color: #6B7280;
	}

	.popup-item.selected .popup-count {
		background: #DBEAFE;
		color: #2563EB;
	}

	/* Content Section */
	.content-section {
		padding: 0.75rem;
		padding-bottom: 5rem;
	}

	/* Skeleton Loading */
	.loading-skeleton {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.skeleton-card {
		background: white;
		border-radius: 8px;
		padding: 0.75rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.skeleton-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.5rem;
	}

	.skeleton-title {
		width: 60%;
		height: 14px;
		background: #E5E7EB;
		border-radius: 4px;
		animation: pulse 1.5s ease-in-out infinite;
	}

	.skeleton-badges {
		display: flex;
		gap: 0.25rem;
	}

	.skeleton-badge {
		width: 40px;
		height: 12px;
		background: #E5E7EB;
		border-radius: 4px;
		animation: pulse 1.5s ease-in-out infinite;
	}

	.skeleton-text {
		width: 90%;
		height: 10px;
		background: #F3F4F6;
		border-radius: 4px;
		margin-bottom: 0.3rem;
		animation: pulse 1.5s ease-in-out infinite;
	}

	.skeleton-text.short {
		width: 60%;
	}

	.skeleton-details {
		display: flex;
		gap: 0.5rem;
		margin-top: 0.5rem;
	}

	.skeleton-detail {
		width: 80px;
		height: 10px;
		background: #F3F4F6;
		border-radius: 4px;
		animation: pulse 1.5s ease-in-out infinite;
	}

	.skeleton-actions {
		display: flex;
		gap: 0.4rem;
		margin-top: 0.75rem;
		padding-top: 0.5rem;
		border-top: 1px solid #F3F4F6;
	}

	.skeleton-button {
		flex: 1;
		height: 28px;
		background: #F3F4F6;
		border-radius: 6px;
		animation: pulse 1.5s ease-in-out infinite;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.4; }
	}

	/* Empty State */
	.empty-state {
		text-align: center;
		padding: 3rem 1.5rem;
	}

	.empty-icon {
		color: #9CA3AF;
		margin-bottom: 0.75rem;
	}

	.empty-state h2 {
		font-size: 0.88rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 0.25rem;
	}

	.empty-state p {
		font-size: 0.75rem;
		color: #9CA3AF;
	}

	.retry-btn {
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.4rem 1.2rem;
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.retry-btn:hover {
		background: #2563EB;
	}

	/* Task List */
	.task-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.task-card {
		background: white;
		border-radius: 8px;
		overflow: hidden;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		transition: all 0.3s ease;
		border: 1px solid transparent;
	}

	.task-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.task-card.overdue {
		border-color: #FEE2E2;
		background: linear-gradient(to right, #FEF2F2, white);
	}

	.task-header {
		padding: 0.5rem 0.5rem 0.25rem;
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		cursor: pointer;
		touch-action: manipulation;
	}

	.task-title-section {
		flex: 1;
	}

	.task-header h3 {
		font-size: 0.78rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.3rem 0;
		line-height: 1.4;
	}

	.task-meta {
		display: flex;
		gap: 0.25rem;
		flex-wrap: wrap;
	}

	.task-priority,
	.task-status,
	.task-type-badge {
		font-size: 0.62rem;
		font-weight: 600;
		padding: 0.15rem 0.35rem;
		border-radius: 4px;
		text-transform: uppercase;
	}

	.task-type-badge.employee-badge {
		background-color: #EDE9FE;
		color: #6366F1;
		text-transform: none;
		font-weight: 500;
		display: inline-flex;
		align-items: center;
		gap: 0.2rem;
	}

	.task-type-badge.role-badge {
		background-color: #f0f0ff;
		color: #6366F1;
		text-transform: none;
		font-weight: 500;
	}

	.overdue-badge {
		width: 24px;
		height: 24px;
		background: #FEE2E2;
		color: #DC2626;
		border-radius: 6px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.task-content {
		padding: 0 0.5rem 0.5rem;
		cursor: pointer;
		touch-action: manipulation;
	}

	.task-description {
		font-size: 0.72rem;
		color: #6B7280;
		margin: 0 0 0.5rem 0;
		line-height: 1.4;
		display: -webkit-box;
		-webkit-line-clamp: 3;
		line-clamp: 3;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.task-details {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.task-detail {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		font-size: 0.65rem;
		color: #9CA3AF;
	}

	.task-detail svg {
		flex-shrink: 0;
	}

	.deadline-text {
		color: #EF4444 !important;
		font-weight: 600;
	}

	.completed-time {
		color: #22C55E;
	}

	.completed-time svg {
		stroke: #22C55E;
	}

	/* Certificate Link */
	.certificate-link {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		margin-top: 0.5rem;
		padding: 0.25rem 0.5rem;
		background: #EFF6FF;
		color: #2563EB;
		border-radius: 4px;
		font-size: 0.65rem;
		font-weight: 600;
		text-decoration: none;
		transition: background 0.15s;
	}

	.certificate-link:hover {
		background: #DBEAFE;
	}

	/* Completion Photo */
	.completion-photo-section {
		margin-top: 0.5rem;
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
	}

	.completion-photo-label {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		font-size: 0.65rem;
		color: #6B7280;
		font-weight: 500;
	}

	.completion-photo-thumb {
		border: none;
		background: none;
		padding: 0;
		cursor: pointer;
		border-radius: 0.5rem;
		overflow: hidden;
		width: 80px;
		height: 80px;
	}

	.completion-photo-thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 0.5rem;
		border: 1px solid #E5E7EB;
		transition: transform 0.15s;
	}

	.completion-photo-thumb:hover img {
		transform: scale(1.05);
	}

	/* Image Preview Overlay */
	.image-preview-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.9);
		z-index: 9999;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}

	.image-preview-close {
		position: absolute;
		top: 1rem;
		right: 1rem;
		background: rgba(255, 255, 255, 0.2);
		border: none;
		border-radius: 50%;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		color: white;
		z-index: 10000;
	}

	.image-preview-close:hover {
		background: rgba(255, 255, 255, 0.3);
	}

	.image-preview-img {
		max-width: 100%;
		max-height: 90vh;
		object-fit: contain;
		border-radius: 0.5rem;
	}

	/* Task Actions */
	.task-actions {
		padding: 0.4rem 0.5rem;
		border-top: 1px solid #F3F4F6;
		display: flex;
		gap: 0.4rem;
	}

	.view-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
		padding: 0.4rem 0.5rem;
		border: none;
		border-radius: 6px;
		font-size: 0.72rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		background: #F3F4F6;
		color: #374151;
	}

	.view-btn:hover {
		background: #E5E7EB;
		transform: translateY(-1px);
	}

	.view-btn.full-width {
		flex: unset;
		width: 100%;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.filters-section,
		.content-section {
			padding: 0.5rem;
		}

		.filter-chips {
			flex-wrap: wrap;
		}

		.task-card {
			border-radius: 6px;
		}

		.task-actions {
			flex-direction: column;
		}

		.view-btn {
			width: 100%;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.content-section {
			padding-bottom: max(5rem, env(safe-area-inset-bottom));
		}
	}
</style>
