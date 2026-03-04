<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { locale } from '$lib/i18n';

	export let windowId: string = '';

	let allTasks: any[] = [];
	let filteredTasks: any[] = [];
	let visibleTasks: any[] = [];
	let isLoading = true;
	let searchQuery = '';
	let selectedBranch = '';
	let selectedType = '';
	let selectedPriority = '';
	let selectedStatus = '';
	let showCompleted = false;
	const VISIBLE_BATCH = 100;
	let visibleCount = VISIBLE_BATCH;

	let branches: string[] = [];
	let selectedTask: any = null;
	let showDetailPopup = false;
	let showDeleteConfirm = false;
	let deletingTaskId: string | null = null;
	let isDeleting = false;
	let taskImages: any[] = [];
	let selectedImageUrl: string = '';
	let showImageModal = false;

	$: isRTL = $locale === 'ar';
	$: isMasterAdmin = $currentUser?.isMasterAdmin || false;

	onMount(async () => {
		await loadTasks();
	});

	async function loadTasks() {
		if (!$currentUser) return;
		try {
			isLoading = true;
			allTasks = [];
			visibleCount = VISIBLE_BATCH;

			const { data, error } = await supabase.rpc('get_my_assignments', { p_user_id: $currentUser.id, p_limit: 500 });
			if (error) throw error;

			allTasks = data?.tasks || [];
			// Auto-enable showCompleted if all tasks are completed (otherwise table looks empty)
			const hasIncomplete = allTasks.some((t: any) => t.status !== 'completed');
			if (!hasIncomplete && allTasks.length > 0) showCompleted = true;
			extractBranches();
			applyFilters();
			isLoading = false;
		} catch (err) {
			console.error('❌ Error loading assignments:', err);
			isLoading = false;
		}
	}

	function extractBranches() {
		const branchSet = new Set<string>();
		allTasks.forEach((t: any) => {
			const bName = isRTL ? (t.branch_name_ar || t.branch_name) : t.branch_name;
			if (bName && bName !== 'No Branch') branchSet.add(bName);
		});
		branches = Array.from(branchSet).sort();
	}

	function applyFilters() {
		const filtered = allTasks.filter(task => {
			// Hide completed unless toggled
			if (!showCompleted && task.status === 'completed') return false;
			const q = searchQuery.toLowerCase();
			const matchesSearch = !q ||
				task.task_title?.toLowerCase().includes(q) ||
				task.task_description?.toLowerCase().includes(q) ||
				task.assigned_to_name?.toLowerCase().includes(q) ||
				task.assigned_by_name?.toLowerCase().includes(q);
			const bName = isRTL ? (task.branch_name_ar || task.branch_name) : task.branch_name;
			const matchesBranch = !selectedBranch || bName === selectedBranch;
			const matchesType = !selectedType || task.task_type === selectedType;
			const matchesPriority = !selectedPriority || task.priority === selectedPriority;
			const matchesStatus = !selectedStatus || task.status === selectedStatus;
			return matchesSearch && matchesBranch && matchesType && matchesPriority && matchesStatus;
		});
		filteredTasks = filtered;
		visibleCount = VISIBLE_BATCH;
		updateVisibleTasks();
	}

	function updateVisibleTasks() {
		visibleTasks = filteredTasks.slice(0, visibleCount);
	}

	function showMore() {
		visibleCount += VISIBLE_BATCH;
		updateVisibleTasks();
	}

	function formatDate(date: any): string {
		if (!date) return '—';
		try {
			const d = new Date(date);
			return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
		} catch { return '—'; }
	}

	function formatCompletionTime(hours: any): string {
		if (hours == null) return '—';
		const h = parseFloat(hours);
		if (h < 1) return isRTL ? 'أقل من ساعة' : '< 1h';
		if (h < 24) return isRTL ? `${Math.round(h)} ساعة` : `${Math.round(h)}h`;
		const days = Math.round(h / 24);
		return isRTL ? `${days} يوم` : `${days}d`;
	}

	function getTypeInfo(type: string): { label: string; icon: string; color: string; bg: string } {
		if (type === 'quick') return { label: isRTL ? 'سريع' : 'Quick', icon: '⚡', color: 'text-blue-700', bg: 'bg-blue-50 border-blue-200' };
		return { label: isRTL ? 'عادي' : 'Regular', icon: '📋', color: 'text-indigo-700', bg: 'bg-indigo-50 border-indigo-200' };
	}

	function getPriorityInfo(p: string): { label: string; color: string; dot: string } {
		if (p === 'high' || p === 'urgent') return { label: isRTL ? 'عاجل' : 'High', color: 'text-red-600', dot: 'bg-red-500' };
		if (p === 'low') return { label: isRTL ? 'منخفض' : 'Low', color: 'text-slate-500', dot: 'bg-slate-400' };
		return { label: isRTL ? 'متوسط' : 'Medium', color: 'text-amber-600', dot: 'bg-amber-500' };
	}

	function getStatusInfo(s: string): { label: string; color: string; bg: string } {
		if (s === 'completed') return { label: isRTL ? 'مكتمل' : 'Completed', color: 'text-emerald-700', bg: 'bg-emerald-50 border-emerald-200' };
		if (s === 'in_progress') return { label: isRTL ? 'قيد التنفيذ' : 'In Progress', color: 'text-amber-700', bg: 'bg-amber-50 border-amber-200' };
		if (s === 'cancelled') return { label: isRTL ? 'ملغي' : 'Cancelled', color: 'text-red-700', bg: 'bg-red-50 border-red-200' };
		if (s === 'escalated') return { label: isRTL ? 'مرفوع' : 'Escalated', color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200' };
		return { label: isRTL ? 'معين' : 'Assigned', color: 'text-blue-700', bg: 'bg-blue-50 border-blue-200' };
	}

	function getEmpName(task: any): string {
		if (isRTL) return task.assigned_to_name_ar || task.assigned_to_name_en || task.assigned_to_name || 'غير محدد';
		return task.assigned_to_name_en || task.assigned_to_name || 'Unassigned';
	}

	function getBranch(task: any): string {
		if (isRTL) return task.branch_name_ar || task.branch_name || 'بدون فرع';
		return task.branch_name || 'No Branch';
	}

	function isOverdue(task: any): boolean {
		if (task.status === 'completed' || !task.deadline) return false;
		try { return new Date(task.deadline) < new Date(); } catch { return false; }
	}

	async function openDetail(task: any) {
		selectedTask = task;
		await loadTaskImages(task);
		showDetailPopup = true;
	}

	async function loadTaskImages(task: any) {
		try {
			taskImages = [];
			const allImages: any[] = [];
			
			console.log('🔍 Loading images for task:', {
				id: task.id,
				task_id: task.task_id,
				task_type: task.task_type,
				task_title: task.task_title
			});
			
			if (task.task_type === 'quick') {
				// For quick tasks - Get completion attachments
				const { data: completions, error: compError } = await supabase
					.from('quick_task_completions')
					.select('*')
					.eq('assignment_id', task.id);
				
				console.log('📸 Quick task completions:', { completions, error: compError });
				
				if (completions && completions.length > 0) {
					completions.forEach((completion: any) => {
						console.log('📋 Completion object full details:', JSON.stringify(completion, null, 2));
						console.log('📋 Completion keys:', Object.keys(completion));
						console.log('📋 Completion.photo_path:', completion.photo_path);
						
						// For quick_task_completions, use photo_path field
						if (completion.photo_path) {
										const photoUrl = `https://supabase.urbanaqura.com/storage/v1/object/public/quick-task-files/${completion.photo_path}`;
							console.log('✅ Quick task completion photo found:', photoUrl);
							allImages.push({
								file_url: photoUrl,
								file_name: 'Completion Photo',
								type: 'completion'
							});
						} else {
							console.log('⚠️ No photo_path found in completion object');
						}
					});
				}
			} else {
				// For regular tasks - Load from task_images table
				const taskId = task.task_id || task.id;
				console.log('🔎 Searching for task_images with task_id:', taskId);
				
				const { data: images, error: imgError } = await supabase
					.from('task_images')
					.select('*')
					.eq('task_id', taskId);
				
				console.log('📋 Regular task images:', { images, error: imgError });
				
				if (images && images.length > 0) {
					images.forEach((img: any) => {
						console.log('✅ Regular task image found:', img);
						allImages.push({
							file_url: img.file_url || img.url,
							file_name: img.file_name || 'Image',
							type: 'assigned'
						});
					});
				}

				// Also get completion images from task_completions
				const { data: completions, error: compError } = await supabase
					.from('task_completions')
					.select('*')
					.eq('assignment_id', task.id);
				
				console.log('📸 Regular task completions:', { completions, error: compError });
				
				if (completions && completions.length > 0) {
					completions.forEach((completion: any) => {
						console.log('📋 Regular completion object full details:', JSON.stringify(completion, null, 2));
						console.log('📋 Regular completion keys:', Object.keys(completion));
						
						// Try photo_path first (newer structure)
						if (completion.photo_path) {
									const photoUrl = `https://supabase.urbanaqura.com/storage/v1/object/public/completion-photos/${completion.photo_path}`;
							console.log('✅ Regular task completion photo found:', photoUrl);
							allImages.push({
								file_url: photoUrl,
								file_name: 'Completion Photo',
								type: 'completion'
							});
						}
						
						// Also try attachments field (older structure)
						if (completion.attachments && Array.isArray(completion.attachments)) {
							completion.attachments.forEach((att: any) => {
								console.log('✅ Regular task completion image found:', att);
								allImages.push({
									file_url: att.file_url || att.url || att,
									file_name: att.file_name || att.name || 'Completion Image',
									type: 'completion'
								});
							});
						}
					});
				}
			}
			
			console.log('🖼️ Final images array after database queries:', allImages);
			
			// Always extract image URLs from description (to show assigned images alongside completion photos)
			if (task.task_description) {
				console.log('🔗 Attempting to extract URLs from description...');
				const urlRegex = /https?:\/\/[^\s]+\.(jpg|jpeg|png|gif|webp)/gi;
				const matches = task.task_description.match(urlRegex);
				if (matches) {
					console.log('🔗 Found URLs in description:', matches);
					matches.forEach((url: string) => {
						// Only add if not already in array (avoid duplicates)
						if (!allImages.some(img => img.file_url === url)) {
							allImages.push({
								file_url: url,
								file_name: 'Image from description',
								type: 'assigned'
							});
						}
					});
				}
			}
			
			console.log('📦 Loading images complete. Total:', allImages.length);
			taskImages = allImages;
		} catch (err) {
			console.error('❌ Error loading task images:', err);
			taskImages = [];
		}
	}

	function closeDetail() {
		showDetailPopup = false;
		selectedTask = null;
		taskImages = [];
		selectedImageUrl = '';
	}

	function openImageModal(imageUrl: string) {
		selectedImageUrl = imageUrl;
		showImageModal = true;
	}

	function closeImageModal() {
		showImageModal = false;
		selectedImageUrl = '';
	}

	function confirmDelete(task: any) {
		deletingTaskId = task.id;
		selectedTask = task;
		showDeleteConfirm = true;
	}

	function cancelDelete() {
		showDeleteConfirm = false;
		deletingTaskId = null;
	}

	async function deleteAssignment() {
		if (!deletingTaskId || !selectedTask) return;
		try {
			isDeleting = true;
			const table = selectedTask.task_type === 'quick' ? 'quick_task_assignments' : 'task_assignments';
			const { error } = await supabase.from(table).delete().eq('id', deletingTaskId);
			if (error) throw error;

			// Remove from local list
			allTasks = allTasks.filter(t => t.id !== deletingTaskId);
			applyFilters();
			showDeleteConfirm = false;
			showDetailPopup = false;
			deletingTaskId = null;
			selectedTask = null;
		} catch (err) {
			console.error('❌ Error deleting assignment:', err);
		} finally {
			isDeleting = false;
		}
	}

	$: if (showCompleted !== undefined) applyFilters();

	// Stats
	$: totalCount = allTasks.length;
	$: completedCount = allTasks.filter(t => t.status === 'completed').length;
	$: inProgressCount = allTasks.filter(t => t.status === 'in_progress').length;
	$: assignedCount = allTasks.filter(t => t.status === 'assigned' || t.status === 'pending').length;
	$: overdueCount = allTasks.filter(t => isOverdue(t)).length;
	$: regularCount = filteredTasks.filter(t => t.task_type === 'regular').length;
	$: quickCount = filteredTasks.filter(t => t.task_type === 'quick').length;
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Header Bar -->
	<div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">📋</span>
			<div>
				<h2 class="text-sm font-black text-slate-800 uppercase tracking-wide">{isRTL ? 'مهامي المسندة' : 'My Assignments'}</h2>
				<p class="text-[10px] text-slate-400 font-semibold">
					{isRTL ? `${allTasks.length} مهمة أسندتها` : `${allTasks.length} tasks you assigned`}
				</p>
			</div>
		</div>
		<div class="flex items-center gap-2">
			<!-- Show Completed Toggle -->
			<label class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-[10px] font-bold cursor-pointer transition-all {showCompleted ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}">
				<input type="checkbox" bind:checked={showCompleted} class="w-3 h-3 rounded" />
				{isRTL ? 'المكتملة' : 'Completed'}
			</label>
			<button
				class="flex items-center gap-2 px-4 py-2 bg-indigo-500 text-white rounded-xl text-xs font-bold hover:bg-indigo-600 transition-all shadow-sm hover:shadow-md"
				on:click={loadTasks}
				disabled={isLoading}
			>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class:animate-spin={isLoading}>
					<polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
				</svg>
				{isRTL ? 'تحديث' : 'Refresh'}
			</button>
		</div>
	</div>

	<!-- Content -->
	<div class="flex-1 p-6 overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative blurs -->
		<div class="absolute top-0 right-0 w-[400px] h-[400px] bg-indigo-100/20 rounded-full blur-[120px] -mr-48 -mt-48 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-violet-100/15 rounded-full blur-[120px] -ml-48 -mb-48 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if isLoading}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-indigo-200 border-t-indigo-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">{isRTL ? 'جاري تحميل المهام...' : 'Loading assignments...'}</p>
					</div>
				</div>
			{:else if allTasks.length === 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-5xl mb-4">📭</div>
					<p class="text-slate-600 font-semibold text-lg">{isRTL ? 'لا توجد مهام مسندة' : 'No assignments found'}</p>
					<p class="text-slate-400 text-sm mt-1">{isRTL ? 'لم تسند أي مهام بعد' : 'You haven\'t assigned any tasks yet'}</p>
				</div>
			{:else}
				<!-- KPI Cards -->
				<div class="grid grid-cols-5 gap-3 mb-4">
					<div class="bg-white/60 backdrop-blur-sm rounded-2xl border border-white/80 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-slate-800">{totalCount}</p>
						<p class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{isRTL ? 'إجمالي' : 'Total'}</p>
					</div>
					<div class="bg-emerald-50/60 backdrop-blur-sm rounded-2xl border border-emerald-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-emerald-600">{completedCount}</p>
						<p class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide">{isRTL ? 'مكتمل' : 'Completed'}</p>
					</div>
					<div class="bg-amber-50/60 backdrop-blur-sm rounded-2xl border border-amber-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-amber-600">{inProgressCount}</p>
						<p class="text-[10px] font-bold text-amber-500 uppercase tracking-wide">{isRTL ? 'قيد التنفيذ' : 'In Progress'}</p>
					</div>
					<div class="bg-blue-50/60 backdrop-blur-sm rounded-2xl border border-blue-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-blue-600">{assignedCount}</p>
						<p class="text-[10px] font-bold text-blue-500 uppercase tracking-wide">{isRTL ? 'معلق' : 'Pending'}</p>
					</div>
					<div class="bg-red-50/60 backdrop-blur-sm rounded-2xl border border-red-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-red-600">{overdueCount}</p>
						<p class="text-[10px] font-bold text-red-500 uppercase tracking-wide">{isRTL ? 'متأخر' : 'Overdue'}</p>
					</div>
				</div>

				<!-- Filters -->
				<div class="mb-4 flex gap-3">
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'بحث' : 'Search'}</label>
						<input
							type="text"
							placeholder={isRTL ? 'بحث بالعنوان، الموظف...' : 'Search by title, employee...'}
							bind:value={searchQuery}
							on:input={applyFilters}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
						/>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'الفرع' : 'Branch'}</label>
						<select bind:value={selectedBranch} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'كل الفروع' : 'All Branches'}</option>
							{#each branches as b}
								<option value={b}>{b}</option>
							{/each}
						</select>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'النوع' : 'Type'}</label>
						<select bind:value={selectedType} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'الكل' : 'All Types'}</option>
							<option value="regular">{isRTL ? 'عادي' : 'Regular'}</option>
							<option value="quick">{isRTL ? 'سريع' : 'Quick'}</option>
						</select>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'الحالة' : 'Status'}</label>
						<select bind:value={selectedStatus} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'الكل' : 'All'}</option>
							<option value="assigned">{isRTL ? 'معين' : 'Assigned'}</option>
							<option value="in_progress">{isRTL ? 'قيد التنفيذ' : 'In Progress'}</option>
							<option value="completed">{isRTL ? 'مكتمل' : 'Completed'}</option>
							<option value="cancelled">{isRTL ? 'ملغي' : 'Cancelled'}</option>
						</select>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'الأولوية' : 'Priority'}</label>
						<select bind:value={selectedPriority} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'الكل' : 'All'}</option>
							<option value="high">{isRTL ? 'عاجل' : 'High'}</option>
							<option value="medium">{isRTL ? 'متوسط' : 'Medium'}</option>
							<option value="low">{isRTL ? 'منخفض' : 'Low'}</option>
						</select>
					</div>
				</div>

				<!-- Table -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
					<div class="overflow-x-auto flex-1 overflow-y-auto">
						<table class="w-full border-collapse [&_th]:border-x [&_th]:border-indigo-500/30 [&_td]:border-x [&_td]:border-slate-200">
							<thead class="sticky top-0 bg-indigo-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">#</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'المهمة' : 'Task'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'النوع' : 'Type'}</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'الفرع' : 'Branch'}</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'مسند إلى' : 'Assigned To'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'الحالة' : 'Status'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'الأولوية' : 'Priority'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'الموعد' : 'Deadline'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'تاريخ الإسناد' : 'Assigned'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">{isRTL ? 'إجراء' : 'Action'}</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each visibleTasks as task, index (task.id + ':' + task.task_type)}
									{@const typeInfo = getTypeInfo(task.task_type)}
									{@const prioInfo = getPriorityInfo(task.priority)}
									{@const statusInfo = getStatusInfo(task.status)}
									{@const overdue = isOverdue(task)}
									<tr class="hover:bg-indigo-50/30 transition-colors duration-200 {overdue ? 'bg-red-50/40' : index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
										<td class="px-4 py-2.5 text-xs text-slate-400 font-mono">{index + 1}</td>
										<td class="px-4 py-2.5">
											<div class="text-sm font-semibold text-slate-800 truncate max-w-[280px]">{task.task_title}</div>
											{#if task.task_description}
												<div class="text-[10px] text-slate-400 truncate max-w-[280px]">{task.task_description.substring(0, 80)}</div>
											{/if}
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg border text-[10px] font-bold {typeInfo.bg} {typeInfo.color}">
												<span>{typeInfo.icon}</span> {typeInfo.label}
											</span>
										</td>
										<td class="px-4 py-2.5 text-sm text-slate-700">{getBranch(task)}</td>
										<td class="px-4 py-2.5">
											<div class="text-sm text-slate-700 font-medium">{getEmpName(task)}</div>
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg border text-[10px] font-bold {statusInfo.bg} {statusInfo.color}">
												{statusInfo.label}
											</span>
											{#if overdue}
												<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-bold bg-red-100 text-red-700 border border-red-200 mt-0.5">
													{isRTL ? 'متأخر' : 'OVERDUE'}
												</span>
											{/if}
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-flex items-center gap-1.5 {prioInfo.color} text-xs font-bold">
												<span class="w-2 h-2 rounded-full {prioInfo.dot}"></span>
												{prioInfo.label}
											</span>
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="text-xs text-slate-700 font-medium {overdue ? 'text-red-600 font-bold' : ''}">{task.deadline ? formatDate(task.deadline) : (isRTL ? 'بدون' : 'None')}</span>
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="text-xs text-slate-700 font-medium">{formatDate(task.assigned_date)}</span>
										</td>
										<td class="px-4 py-2.5 text-center">
											<div class="flex items-center justify-center gap-1">
												<button
													class="px-3 py-1.5 bg-indigo-500 text-white rounded-lg text-[10px] font-bold hover:bg-indigo-600 transition-all shadow-sm hover:shadow-md active:scale-95"
													on:click={async () => await openDetail(task)}
												>
													{isRTL ? 'تفاصيل' : 'Details'}
												</button>
												{#if isMasterAdmin}
													<button
														class="px-2 py-1.5 bg-red-500 text-white rounded-lg text-[10px] font-bold hover:bg-red-600 transition-all shadow-sm hover:shadow-md active:scale-95"
														on:click={() => confirmDelete(task)}
														title={isRTL ? 'حذف' : 'Delete'}
													>
														<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2m3 0v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6h14"/></svg>
													</button>
												{/if}
											</div>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
						{#if filteredTasks.length === 0 && allTasks.length > 0}
							<div class="flex items-center justify-center py-12">
								<div class="text-center">
									<div class="text-4xl mb-3">🔍</div>
									<p class="text-slate-500 font-semibold">{isRTL ? 'لا نتائج مطابقة' : 'No matching results'}</p>
									<p class="text-slate-400 text-xs mt-1">{isRTL ? 'حاول تغيير الفلاتر' : 'Try changing filters'}</p>
								</div>
							</div>
						{/if}
						{#if visibleCount < filteredTasks.length}
							<div class="flex items-center justify-center py-4 border-t border-slate-200">
								<button
									class="px-6 py-2.5 bg-indigo-500 text-white rounded-xl text-xs font-bold hover:bg-indigo-600 transition-all shadow-sm hover:shadow-md"
									on:click={showMore}
								>
									{isRTL ? `عرض المزيد (${filteredTasks.length - visibleCount} متبقي)` : `Show More (${filteredTasks.length - visibleCount} remaining)`}
								</button>
							</div>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- Task Detail Popup -->
{#if showDetailPopup && selectedTask}
	{@const t = selectedTask}
	{@const typeInfo = getTypeInfo(t.task_type)}
	{@const prioInfo = getPriorityInfo(t.priority)}
	{@const statusInfo = getStatusInfo(t.status)}
	<div
		class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[200] flex items-center justify-center"
		style="animation: fadeIn 0.15s ease-out;"
		on:click|self={closeDetail}
		on:keydown={(e) => e.key === 'Escape' && closeDetail()}
		role="dialog"
		tabindex="-1"
		aria-modal="true"
	>
		<div class="bg-white rounded-3xl shadow-2xl border border-slate-200 w-[900px] max-h-[85vh] overflow-hidden flex" style="animation: scaleIn 0.2s ease-out;" dir={isRTL ? 'rtl' : 'ltr'}>
			
			<!-- Main Content -->
			<div class="flex-1 flex flex-col {isRTL ? 'border-r' : 'border-l'} border-slate-200">
				<!-- Popup Header -->
				<div class="bg-gradient-to-r from-indigo-500 to-violet-500 px-6 py-4 flex items-center justify-between">
					<div class="flex items-center gap-3">
						<span class="text-2xl">{typeInfo.icon}</span>
						<div>
							<h3 class="text-sm font-black text-white uppercase tracking-wide">{isRTL ? 'تفاصيل المهمة' : 'Assignment Details'}</h3>
							<p class="text-[10px] text-indigo-100 font-semibold">{typeInfo.label} • ID: {t.id.substring(0, 8)}...</p>
						</div>
					</div>
					<button class="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 transition-all flex items-center justify-center" on:click={closeDetail} aria-label="Close">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
					</button>
				</div>

				<!-- Popup Body -->
				<div class="flex-1 p-6 overflow-y-auto">
					<!-- Title & Description -->
					<div class="mb-5">
						<h4 class="text-lg font-bold text-slate-800 mb-1">{t.task_title}</h4>
						{#if t.task_description}
							<p class="text-sm text-slate-500 leading-relaxed whitespace-pre-wrap">{t.task_description}</p>
						{/if}
					</div>

					<!-- Info Grid -->
					<div class="grid grid-cols-2 gap-3 mb-5">
						<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
							<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'النوع' : 'Type'}</p>
							<span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-bold {typeInfo.bg} {typeInfo.color}">
								{typeInfo.icon} {typeInfo.label}
							</span>
						</div>
						<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
							<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الحالة' : 'Status'}</p>
							<span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-bold {statusInfo.bg} {statusInfo.color}">
								{statusInfo.label}
							</span>
						</div>
						<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
							<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الأولوية' : 'Priority'}</p>
							<span class="inline-flex items-center gap-1.5 {prioInfo.color} text-sm font-bold">
								<span class="w-2.5 h-2.5 rounded-full {prioInfo.dot}"></span>
								{prioInfo.label}
							</span>
						</div>
						<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
							<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'تاريخ الإسناد' : 'Assigned Date'}</p>
							<span class="text-sm font-semibold text-slate-700">{formatDate(t.assigned_date)}</span>
						</div>
					</div>

					<!-- Deadline -->
					{#if t.deadline}
						<div class="bg-slate-50 rounded-xl p-3 border border-slate-100 mb-5 {isOverdue(t) ? 'bg-red-50 border-red-200' : ''}">
							<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الموعد النهائي' : 'Deadline'}</p>
							<p class="text-sm font-semibold {isOverdue(t) ? 'text-red-600' : 'text-slate-700'}">
								{formatDate(t.deadline)}
								{#if isOverdue(t)}
									<span class="text-[10px] text-red-500 font-bold {isRTL ? 'mr-2' : 'ml-2'}">⚠️ {isRTL ? 'متأخر' : 'OVERDUE'}</span>
								{/if}
							</p>
						</div>
					{/if}

					<!-- Completed Date -->
					{#if t.completed_date}
						<div class="bg-emerald-50 rounded-xl p-3 border border-emerald-100 mb-5">
							<p class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide mb-1">{isRTL ? 'تاريخ الإكمال' : 'Completed Date'}</p>
							<div class="flex items-center gap-3">
								<span class="text-sm font-semibold text-emerald-700">{formatDate(t.completed_date)}</span>
								{#if t.completion_hours != null}
									<span class="inline-block px-2 py-0.5 rounded-lg text-[10px] font-bold bg-emerald-100 text-emerald-700">
										{formatCompletionTime(t.completion_hours)}
									</span>
								{/if}
							</div>
						</div>
					{/if}

					<!-- People & Branch -->
					<div class="grid grid-cols-2 gap-3 mb-5">
						<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
							<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'مسند إلى' : 'Assigned To'}</p>
							<p class="text-sm font-semibold text-slate-700">{getEmpName(t)}</p>
						</div>
						<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
							<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الفرع' : 'Branch'}</p>
							<p class="text-sm font-semibold text-slate-700">{getBranch(t)}</p>
						</div>
					</div>

					<!-- Quick Task extras -->
					{#if t.task_type === 'quick' && (t.price_tag || t.issue_type)}
						<div class="bg-blue-50 rounded-xl p-3 border border-blue-100 mb-5">
							<p class="text-[10px] font-bold text-blue-500 uppercase tracking-wide mb-2">{isRTL ? 'تفاصيل المهمة السريعة' : 'Quick Task Details'}</p>
							<div class="grid grid-cols-2 gap-3">
								{#if t.price_tag}
									<div>
										<p class="text-[10px] text-blue-400 font-bold">{isRTL ? 'السعر' : 'Price Tag'}</p>
										<p class="text-sm font-semibold text-blue-700 capitalize">{t.price_tag}</p>
									</div>
								{/if}
								{#if t.issue_type}
									<div>
										<p class="text-[10px] text-blue-400 font-bold">{isRTL ? 'نوع المشكلة' : 'Issue Type'}</p>
										<p class="text-sm font-semibold text-blue-700 capitalize">{t.issue_type}</p>
									</div>
								{/if}
							</div>
						</div>
					{/if}

					<!-- Notes -->
					{#if t.notes}
						<div class="bg-indigo-50 rounded-xl p-4 border border-indigo-100">
							<p class="text-[10px] font-bold text-indigo-500 uppercase tracking-wide mb-1">{isRTL ? 'ملاحظات' : 'Notes'}</p>
							<p class="text-sm text-slate-700 whitespace-pre-wrap">{t.notes}</p>
						</div>
					{/if}
				</div>

				<!-- Popup Footer -->
				<div class="px-6 py-3 bg-slate-50 border-t border-slate-200 flex items-center {isRTL ? 'flex-row-reverse' : ''} justify-between">
					{#if isMasterAdmin}
						<button
							class="px-4 py-2 bg-red-500 text-white rounded-xl text-xs font-bold hover:bg-red-600 transition-all flex items-center gap-2"
							on:click={() => confirmDelete(t)}
						>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2m3 0v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6h14"/></svg>
							{isRTL ? 'حذف' : 'Delete'}
						</button>
					{:else}
						<div></div>
					{/if}
					<button
						class="px-5 py-2 bg-slate-200 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-300 transition-all"
						on:click={closeDetail}
					>
						{isRTL ? 'إغلاق' : 'Close'}
					</button>
				</div>
			</div>

			<!-- Aside Panel - Images -->
			<div class="w-64 bg-slate-50 border-l border-slate-200 flex flex-col">
				<!-- Aside Header -->
				<div class="px-4 py-4 bg-slate-100 border-b border-slate-200">
					<h4 class="text-sm font-bold text-slate-700">{isRTL ? 'الصور' : 'Images'} ({taskImages?.length || 0})</h4>
				</div>

				<!-- Images Grid -->
				<div class="flex-1 overflow-y-auto p-3">
					{#if taskImages && taskImages.length > 0}
						<div class="grid grid-cols-2 gap-2">
							{#each taskImages as image (image.file_url)}
								<div 
									class="relative group cursor-pointer rounded-lg overflow-hidden border-2 border-slate-300 hover:border-indigo-500 transition-all"
									on:click={() => openImageModal(image.file_url)}
									on:keydown={(e) => e.key === 'Enter' && openImageModal(image.file_url)}
									role="button"
									tabindex="0"
								>
									<img 
										src={image.file_url} 
										alt="Task"
										class="w-full h-24 object-cover group-hover:scale-110 transition-transform duration-200 bg-slate-200"
										on:error={(e) => {
											const target = e.target as HTMLImageElement;
											target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"%3E%3Cpath stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4v2m0 0v2m0-6v-2m0 0V9m0 0h2m0 0h2m0 0h-2m0 0h-2m0 6h2m0 0h2m0 0h-2m0 0h-2"/%3E%3C/svg%3E';
											target.classList.add('bg-red-100');
										}}
										loading="lazy"
									/>
									<!-- Type Badge -->
									<div class="absolute top-1 {image.type === 'completion' ? 'right-1' : 'left-1'} z-10">
										{#if image.type === 'completion'}
											<span class="inline-flex items-center gap-1 px-2 py-1 bg-emerald-500/90 text-white text-[9px] font-bold rounded-md backdrop-blur-sm">
												<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>
												{isRTL ? 'مكتمل' : 'Completed'}
											</span>
										{:else}
											<span class="inline-flex items-center gap-1 px-2 py-1 bg-blue-500/90 text-white text-[9px] font-bold rounded-md backdrop-blur-sm">
												<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M4 4a2 2 0 00-2 2v4a1 1 0 001 1h12a1 1 0 001-1V6a2 2 0 00-2-2H4zm12 12H4a2 2 0 01-2-2v-4a1 1 0 10-2 0v4a4 4 0 004 4h12a4 4 0 004-4v-4a1 1 0 10-2 0v4a2 2 0 01-2 2z" clip-rule="evenodd"/></svg>
												{isRTL ? 'مسند' : 'Assigned'}
											</span>
										{/if}
									</div>
									<div class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors"></div>
									<div class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
										<svg class="w-6 h-6 text-white drop-shadow-lg" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
										</svg>
									</div>
								</div>
							{/each}
						</div>
					{:else}
						<div class="h-full flex items-center justify-center text-center">
							<div>
								<svg class="w-8 h-8 text-slate-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
								</svg>
								<p class="text-xs text-slate-400 font-medium">{isRTL ? 'لا توجد صور' : 'No Images'}</p>

							</div>
						</div>
					{/if}
				</div>
			</div>
		</div>
	</div>
{/if}

<!-- Image Modal -->
{#if showImageModal && selectedImageUrl}
	<div 
		class="fixed inset-0 bg-black/75 z-[400] flex items-center justify-center p-4"
		on:click={closeImageModal}
		on:keydown={(e) => e.key === 'Escape' && closeImageModal()}
		role="dialog"
		tabindex="-1"
		aria-modal="true"
	>
		<div 
			class="relative max-w-4xl max-h-[90vh] bg-white rounded-2xl overflow-hidden shadow-2xl"
			role="document"
			on:click|stopPropagation
		>
			<button
				class="absolute top-4 right-4 z-10 bg-black/50 hover:bg-black/75 text-white rounded-full p-3 transition-all"
				on:click={closeImageModal}
				aria-label="Close"
			>
				<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
				</svg>
			</button>
			<img 
				src={selectedImageUrl} 
				alt="Full size preview"
				class="w-full h-auto max-h-[85vh] object-contain"
			/>
		</div>
	</div>
{/if}

<!-- Delete Confirmation Modal -->
{#if showDeleteConfirm}
	<div
		class="fixed inset-0 bg-black/50 backdrop-blur-sm z-[300] flex items-center justify-center"
		style="animation: fadeIn 0.15s ease-out;"
		on:click|self={cancelDelete}
		on:keydown={(e) => e.key === 'Escape' && cancelDelete()}
		role="dialog"
		tabindex="-1"
		aria-modal="true"
	>
		<div class="bg-white rounded-2xl shadow-2xl border border-slate-200 w-[400px] overflow-hidden" style="animation: scaleIn 0.2s ease-out;" dir={isRTL ? 'rtl' : 'ltr'}>
			<div class="p-6 text-center">
				<div class="w-16 h-16 mx-auto mb-4 bg-red-100 rounded-full flex items-center justify-center">
					<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2"><path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2m3 0v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6h14"/></svg>
				</div>
				<h3 class="text-lg font-bold text-slate-800 mb-2">{isRTL ? 'تأكيد الحذف' : 'Confirm Delete'}</h3>
				<p class="text-sm text-slate-500 mb-1">
					{isRTL ? 'هل أنت متأكد من حذف هذا التعيين؟' : 'Are you sure you want to delete this assignment?'}
				</p>
				{#if selectedTask}
					<p class="text-sm font-semibold text-slate-700 bg-slate-50 rounded-lg px-3 py-2 mt-3">
						{selectedTask.task_title}
					</p>
				{/if}
				<p class="text-[10px] text-red-500 font-bold mt-3">
					{isRTL ? '⚠️ لا يمكن التراجع عن هذا الإجراء' : '⚠️ This action cannot be undone'}
				</p>
			</div>
			<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex items-center justify-center gap-3">
				<button
					class="px-5 py-2.5 bg-slate-200 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-300 transition-all"
					on:click={cancelDelete}
					disabled={isDeleting}
				>
					{isRTL ? 'إلغاء' : 'Cancel'}
				</button>
				<button
					class="px-5 py-2.5 bg-red-500 text-white rounded-xl text-xs font-bold hover:bg-red-600 transition-all flex items-center gap-2 disabled:opacity-50"
					on:click={deleteAssignment}
					disabled={isDeleting}
				>
					{#if isDeleting}
						<div class="w-3 h-3 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
					{/if}
					{isRTL ? 'حذف نهائي' : 'Delete Permanently'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}
	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.95); }
		to { opacity: 1; transform: scale(1); }
	}
	:global([dir="rtl"] select) {
		background-position: left 0.75rem center !important;
		padding-left: 2.5rem !important;
		padding-right: 1rem !important;
	}
</style>