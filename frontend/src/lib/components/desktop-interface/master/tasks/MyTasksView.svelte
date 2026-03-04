<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { cashierUser, isCashierAuthenticated } from '$lib/stores/cashierAuth';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { locale } from '$lib/i18n';
	import TaskCompletionModal from './TaskCompletionModal.svelte';
	import TaskDetailsModal from './TaskDetailsModal.svelte';
	import QuickTaskDetailsModal from './QuickTaskDetailsModal.svelte';
	import QuickTaskCompletionDialog from './QuickTaskCompletionDialog.svelte';
	import ReceivingTaskDetailsModal from './ReceivingTaskDetailsModal.svelte';
	import ReceivingTaskCompletionDialog from '$lib/components/desktop-interface/master/operations/receiving/ReceivingTaskCompletionDialog.svelte';

	let allTasks: any[] = [];
	let filteredTasks: any[] = [];
	let visibleTasks: any[] = [];
	let isLoading = true;
	let searchQuery = '';
	let selectedType = '';
	let selectedStatus = '';
	let selectedPriority = '';
	let showCompleted = false;
	const VISIBLE_BATCH = 100;
	let visibleCount = VISIBLE_BATCH;

	let branches: string[] = [];
	let selectedBranch = '';
	let selectedTask: any = null;
	let showDetailPopup = false;
	let showDeleteConfirm = false;
	let deletingTaskId: string | null = null;
	let deletingTaskType: string | null = null;
	let isDeleting = false;

	// Copy notification
	let copyNotification: string | null = null;
	let copyNotificationTimeout: any = null;

	// Countdown timer
	let countdownInterval: any = null;

	$: isRTL = $locale === 'ar';
	$: activeUser = $cashierUser || $currentUser;
	$: authenticated = $isCashierAuthenticated || $isAuthenticated;
	$: isMasterAdmin = $currentUser?.isMasterAdmin || false;

	onMount(async () => {
		await loadTasks();
		startCountdownTimer();
	});

	onDestroy(() => {
		stopCountdownTimer();
		if (copyNotificationTimeout) clearTimeout(copyNotificationTimeout);
	});

	async function loadTasks() {
		if (!authenticated || !activeUser?.id) return;
		try {
			isLoading = true;
			allTasks = [];
			visibleCount = VISIBLE_BATCH;

			const { data, error } = await supabase.rpc('get_my_tasks', {
				p_user_id: activeUser.id,
				p_include_completed: showCompleted,
				p_limit: 500
			});
			if (error) throw error;

			allTasks = data?.tasks || [];
			await enrichTasksWithPriceInfo(allTasks);
			extractBranches();
			applyFilters();
			isLoading = false;
		} catch (err) {
			console.error('❌ Error loading tasks:', err);
			isLoading = false;
		}
	}

	// Enrich quick tasks with parent price/product info
	async function enrichTasksWithPriceInfo(taskList: any[]) {
		const quickTasks = taskList.filter(t => t.task_type === 'quick_task');
		if (quickTasks.length === 0) return;

		const parentTaskIds: string[] = [];
		const taskToParentMap = new Map();
		quickTasks.forEach(t => {
			const desc = t.description || '';
			const parentMatch = desc.match(/linked_parent_task:([a-f0-9-]{36})/i);
			if (parentMatch) {
				parentTaskIds.push(parentMatch[1]);
				taskToParentMap.set(t.id || t.assignment_id, parentMatch[1]);
			}
			// Also extract prices directly from title/description
			const titleDesc = (t.title || '') + ' ' + desc;
			const oldP = titleDesc.match(/Old Price:\s*([\d.]+)/i) || titleDesc.match(/السعر القديم:\s*([\d.]+)/);
			const newP = titleDesc.match(/New Price:\s*([\d.]+)/i) || titleDesc.match(/السعر الجديد:\s*([\d.]+)/);
			const arrowP = titleDesc.match(/([\d.]+)\s*→\s*([\d.]+)/);
			if (oldP || newP || arrowP) {
				t.parent_old_price = oldP ? oldP[1] : (arrowP ? arrowP[1] : null);
				t.parent_new_price = newP ? newP[1] : (arrowP ? arrowP[2] : null);
			}
		});

		if (parentTaskIds.length === 0) return;

		try {
			const { data: parentTasks } = await supabase
				.from('quick_tasks')
				.select('id, title, description, price_tag')
				.in('id', [...new Set(parentTaskIds)]);

			if (!parentTasks) return;

			const parentMap = new Map();
			const barcodesToLookup = new Set<string>();
			parentTasks.forEach(pt => {
				parentMap.set(pt.id, pt);
				const barcodeMatch = (pt.description || '').match(/Barcode:\s*(\S+)/i) || (pt.description || '').match(/باركود:\s*(\S+)/);
				const titleBarcodeMatch = (pt.title || '').match(/:\s*(\d{4,})/);
				const barcode = barcodeMatch ? barcodeMatch[1] : (titleBarcodeMatch ? titleBarcodeMatch[1] : null);
				if (barcode) {
					(pt as any)._barcode = barcode;
					barcodesToLookup.add(barcode);
				}
			});

			let productNameMap = new Map();
			if (barcodesToLookup.size > 0) {
				const barcodeArr = [...barcodesToLookup];
				const [byBarcode, byAutoBarcode] = await Promise.all([
					supabase.from('erp_synced_products').select('barcode, auto_barcode, product_name_en, product_name_ar').in('barcode', barcodeArr),
					supabase.from('erp_synced_products').select('barcode, auto_barcode, product_name_en, product_name_ar').in('auto_barcode', barcodeArr)
				]);
				if (byBarcode.data) byBarcode.data.forEach(p => productNameMap.set(p.barcode, p));
				if (byAutoBarcode.data) byAutoBarcode.data.forEach(p => productNameMap.set(p.auto_barcode, p));
			}

			quickTasks.forEach(t => {
				const key = t.id || t.assignment_id;
				const parentId = taskToParentMap.get(key);
				if (parentId && parentMap.has(parentId)) {
					const parent = parentMap.get(parentId);
					const parentDesc = parent.description || '';
					const oldP = parentDesc.match(/Old Price:\s*([\d.]+)/i) || parentDesc.match(/السعر القديم:\s*([\d.]+)/);
					const newP = parentDesc.match(/New Price:\s*([\d.]+)/i) || parentDesc.match(/السعر الجديد:\s*([\d.]+)/);
					const arrowP = parentDesc.match(/([\d.]+)\s*→\s*([\d.]+)/);
					t.parent_old_price = oldP ? oldP[1] : (arrowP ? arrowP[1] : t.parent_old_price);
					t.parent_new_price = newP ? newP[1] : (arrowP ? arrowP[2] : t.parent_new_price);
					t.parent_title = parent.title;
					if ((parent as any)._barcode && productNameMap.has((parent as any)._barcode)) {
						const prod = productNameMap.get((parent as any)._barcode);
						t.product_name = prod.product_name_en || prod.product_name_ar || '';
						t.product_name_ar = prod.product_name_ar || '';
						t.product_barcode = (parent as any)._barcode;
						if (prod.auto_barcode === (parent as any)._barcode && prod.barcode !== (parent as any)._barcode) {
							t.product_real_barcode = prod.barcode;
						}
					}
				}
			});
		} catch (err) {
			console.error('Error enriching tasks with price info:', err);
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
			if (!showCompleted && (task.assignment_status === 'completed' || task.assignment_status === 'cancelled')) return false;
			const q = searchQuery.toLowerCase();
			const matchesSearch = !q ||
				task.title?.toLowerCase().includes(q) ||
				task.description?.toLowerCase().includes(q) ||
				task.assigned_by_name?.toLowerCase().includes(q);
			const bName = isRTL ? (task.branch_name_ar || task.branch_name) : task.branch_name;
			const matchesBranch = !selectedBranch || bName === selectedBranch;
			const matchesType = !selectedType || task.task_type === selectedType;
			const matchesPriority = !selectedPriority || task.priority === selectedPriority;
			const matchesStatus = !selectedStatus || task.assignment_status === selectedStatus;
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

	$: if (showCompleted !== undefined) loadTasks();

	// ─── Formatting ───
	function formatDate(date: any): string {
		if (!date) return '—';
		try {
			const d = new Date(date);
			return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
		} catch { return '—'; }
	}

	function getTypeInfo(type: string): { label: string; icon: string; color: string; bg: string } {
		if (type === 'quick_task') return { label: isRTL ? 'سريع' : 'Quick', icon: '⚡', color: 'text-blue-700', bg: 'bg-blue-50 border-blue-200' };
		if (type === 'receiving') return { label: isRTL ? 'استلام' : 'Receiving', icon: '📦', color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200' };
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
		if (s === 'pending') return { label: isRTL ? 'معلق' : 'Pending', color: 'text-orange-700', bg: 'bg-orange-50 border-orange-200' };
		return { label: isRTL ? 'معين' : 'Assigned', color: 'text-blue-700', bg: 'bg-blue-50 border-blue-200' };
	}

	function getBranch(task: any): string {
		if (isRTL) return task.branch_name_ar || task.branch_name || 'بدون فرع';
		return task.branch_name || 'No Branch';
	}

	function isOverdue(task: any): boolean {
		if (task.assignment_status === 'completed' || task.assignment_status === 'cancelled' || !task.deadline_datetime) return false;
		try { return new Date(task.deadline_datetime) < new Date(); } catch { return false; }
	}

	function getCountdown(task: any): { text: string; urgent: boolean } {
		if (!task.deadline_datetime) return { text: isRTL ? 'بدون موعد' : 'No deadline', urgent: false };
		const now = new Date();
		const deadline = new Date(task.deadline_datetime);
		if (task.assignment_status === 'completed' || task.assignment_status === 'cancelled') {
			return { text: formatDate(task.deadline_datetime), urgent: false };
		}
		if (deadline < now) return { text: isRTL ? 'متأخر!' : 'Overdue!', urgent: true };
		const diffMs = deadline.getTime() - now.getTime();
		const days = Math.floor(diffMs / 86400000);
		const hours = Math.floor((diffMs % 86400000) / 3600000);
		const mins = Math.floor((diffMs % 3600000) / 60000);
		let s = '';
		if (days > 0) s += `${days}d `;
		if (hours > 0) s += `${hours}h `;
		s += `${mins}m`;
		return { text: s, urgent: days === 0 };
	}

	// ─── Barcode & Price copy ───
	function extractBarcode(title: string): string | null {
		if (!title) return null;
		const parts = title.split('|');
		if (parts.length >= 2) { const b = parts[1].trim(); if (/^\d+$/.test(b)) return b; }
		const cm = title.match(/:\s*(\d+)/); if (cm?.[1]) return cm[1];
		const nm = title.match(/\b(\d{5,})\b/); if (nm?.[1]) return nm[1];
		return null;
	}

	function extractPrice(desc: string): string | null {
		if (!desc) return null;
		const m = desc.match(/New Price:\s*([\d.]+)/i);
		return m?.[1] || null;
	}

	async function copyToClipboard(text: string) {
		try {
			await navigator.clipboard.writeText(text);
			copyNotification = text;
			if (copyNotificationTimeout) clearTimeout(copyNotificationTimeout);
			copyNotificationTimeout = setTimeout(() => { copyNotification = null; }, 2000);
		} catch (err) { console.error('Copy failed:', err); }
	}

	// ─── Countdown timer ───
	function startCountdownTimer() {
		if (countdownInterval) clearInterval(countdownInterval);
		countdownInterval = setInterval(() => { allTasks = [...allTasks]; }, 60000);
	}
	function stopCountdownTimer() {
		if (countdownInterval) { clearInterval(countdownInterval); countdownInterval = null; }
	}

	// ─── Task actions (open windows) ───
	function removeCompletedTask(taskId: string) {
		allTasks = allTasks.filter(t => t.id !== taskId);
		applyFilters();
	}

	function openTaskCompletion(task: any) {
		if (task.task_type === 'quick_task') {
			const wId = `quick-task-completion-${task.assignment_id}`;
			openWindow({ id: wId, title: `Complete Quick Task: ${task.title}`, component: QuickTaskCompletionDialog,
				props: { task, assignmentId: task.assignment_id, onComplete: () => { windowManager.closeWindow(wId); removeCompletedTask(task.id); } },
				icon: '⚡', size: { width: 600, height: 700 }, position: { x: window.innerWidth/2-300, y: window.innerHeight/2-350 },
				resizable: true, minimizable: true, maximizable: true, closable: true });
		} else if (task.task_type === 'receiving') {
			const wId = `receiving-task-completion-${task.id}`;
			openWindow({ id: wId, title: 'Complete Receiving Task', component: ReceivingTaskCompletionDialog,
				props: { taskId: task.id, receivingRecordId: task.receiving_record_id, onComplete: () => { windowManager.closeWindow(wId); removeCompletedTask(task.id); } },
				icon: '✅', size: { width: 500, height: 300 }, position: { x: window.innerWidth/2-250, y: window.innerHeight/2-150 },
				resizable: true, minimizable: true, maximizable: true, closable: true });
		} else {
			const wId = `task-completion-${task.id}`;
			openWindow({ id: wId, title: `Complete Task: ${task.title}`, component: TaskCompletionModal,
				props: { task, assignmentId: task.assignment_id,
					requireTaskFinished: task.require_task_finished ?? false,
					requirePhotoUpload: task.require_photo_upload ?? false,
					requireErpReference: task.require_erp_reference ?? false,
					onTaskCompleted: () => { removeCompletedTask(task.id); windowManager.closeWindow(wId); } },
				icon: '✅', size: { width: 600, height: 700 }, position: { x: 100+Math.random()*200, y: 50+Math.random()*100 },
				resizable: true, minimizable: true, maximizable: true, closable: true });
		}
	}

	function openTaskDetails(task: any) {
		if (task.task_type === 'quick_task') {
			const wId = `quick-task-details-${task.id}`;
			openWindow({ id: wId, title: `⚡ Quick Task: ${task.title}`, component: QuickTaskDetailsModal,
				props: { task, windowId: wId, onTaskCompleted: () => removeCompletedTask(task.id) },
				icon: '⚡', size: { width: 800, height: 600 }, position: { x: 150+Math.random()*100, y: 100+Math.random()*50 },
				resizable: true, minimizable: true, maximizable: true, closable: true });
		} else if (task.task_type === 'receiving') {
			const wId = `receiving-task-details-${task.id}`;
			openWindow({ id: wId, title: `📦 Receiving: ${task.title}`, component: ReceivingTaskDetailsModal,
				props: { task, windowId: wId, onTaskCompleted: () => removeCompletedTask(task.id) },
				icon: '📦', size: { width: 800, height: 600 }, position: { x: 100+Math.random()*100, y: 50+Math.random()*50 },
				resizable: true, minimizable: true, maximizable: true, closable: true });
		} else {
			const wId = `task-details-${task.id}`;
			openWindow({ id: wId, title: `Task: ${task.title}`, component: TaskDetailsModal,
				props: { task, windowId: wId, onTaskCompleted: () => removeCompletedTask(task.id) },
				icon: '📋', size: { width: 800, height: 600 }, position: { x: 150+Math.random()*100, y: 100+Math.random()*50 },
				resizable: true, minimizable: true, maximizable: true, closable: true });
		}
	}

	// ─── Delete (master admin only) ───
	function confirmDelete(task: any) {
		deletingTaskId = task.assignment_id;
		deletingTaskType = task.task_type;
		selectedTask = task;
		showDeleteConfirm = true;
	}

	function cancelDelete() {
		showDeleteConfirm = false;
		deletingTaskId = null;
		deletingTaskType = null;
	}

	async function deleteAssignment() {
		if (!deletingTaskId || !deletingTaskType) return;
		try {
			isDeleting = true;
			let table = 'task_assignments';
			if (deletingTaskType === 'quick_task') table = 'quick_task_assignments';
			else if (deletingTaskType === 'receiving') table = 'receiving_tasks';

			const { error } = await supabase.from(table).delete().eq('id', deletingTaskId);
			if (error) throw error;

			allTasks = allTasks.filter(t => t.assignment_id !== deletingTaskId);
			applyFilters();
			showDeleteConfirm = false;
			showDetailPopup = false;
			deletingTaskId = null;
			deletingTaskType = null;
			selectedTask = null;
		} catch (err) {
			console.error('❌ Error deleting:', err);
		} finally {
			isDeleting = false;
		}
	}

	function openDetail(task: any) { selectedTask = task; showDetailPopup = true; }
	function closeDetail() { showDetailPopup = false; selectedTask = null; }
	function hideImage(e: any) { e.target.style.display = 'none'; }

	// Stats
	$: totalCount = filteredTasks.length;
	$: activeCount = filteredTasks.filter(t => t.assignment_status !== 'completed' && t.assignment_status !== 'cancelled').length;
	$: completedCount = allTasks.filter(t => t.assignment_status === 'completed').length;
	$: overdueCount = filteredTasks.filter(t => isOverdue(t)).length;
	$: regularCount = filteredTasks.filter(t => t.task_type === 'regular').length;
	$: quickCount = filteredTasks.filter(t => t.task_type === 'quick_task').length;
	$: receivingCount = filteredTasks.filter(t => t.task_type === 'receiving').length;
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Copy Notification Toast -->
	{#if copyNotification}
		<div class="fixed top-4 {isRTL ? 'left-4' : 'right-4'} z-50" style="animation: fadeIn 0.2s ease-out;">
			<div class="bg-emerald-500 text-white px-4 py-3 rounded-xl shadow-lg flex items-center gap-2 text-sm font-bold">
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
				<span>{copyNotification} {isRTL ? 'تم النسخ' : 'copied'}</span>
			</div>
		</div>
	{/if}

	<!-- Header Bar -->
	<div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">📝</span>
			<div>
				<h2 class="text-sm font-black text-slate-800 uppercase tracking-wide">{isRTL ? 'مهامي' : 'My Tasks'}</h2>
				<p class="text-[10px] text-slate-400 font-semibold">
					{isRTL ? `${allTasks.length} مهمة مسندة إليك` : `${allTasks.length} tasks assigned to you`}
				</p>
			</div>
		</div>
		<div class="flex items-center gap-2">
			<label class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-[10px] font-bold cursor-pointer transition-all {showCompleted ? 'bg-teal-100 text-teal-700' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}">
				<input type="checkbox" bind:checked={showCompleted} class="w-3 h-3 rounded" />
				{isRTL ? 'المكتملة' : 'Completed'}
			</label>
			<button
				class="flex items-center gap-2 px-4 py-2 bg-teal-500 text-white rounded-xl text-xs font-bold hover:bg-teal-600 transition-all shadow-sm hover:shadow-md"
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
		<div class="absolute top-0 right-0 w-[400px] h-[400px] bg-teal-100/20 rounded-full blur-[120px] -mr-48 -mt-48 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-cyan-100/15 rounded-full blur-[120px] -ml-48 -mb-48 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if isLoading}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-teal-200 border-t-teal-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">{isRTL ? 'جاري تحميل المهام...' : 'Loading tasks...'}</p>
					</div>
				</div>
			{:else if allTasks.length === 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-5xl mb-4">📭</div>
					<p class="text-slate-600 font-semibold text-lg">{isRTL ? 'لا توجد مهام' : 'No tasks assigned to you'}</p>
				</div>
			{:else}
				<!-- KPI Cards -->
				<div class="grid grid-cols-5 gap-3 mb-4">
					<div class="bg-white/60 backdrop-blur-sm rounded-2xl border border-white/80 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-slate-800">{totalCount}</p>
						<p class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{isRTL ? 'المعروض' : 'Showing'}</p>
					</div>
					<div class="bg-teal-50/60 backdrop-blur-sm rounded-2xl border border-teal-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-teal-600">{activeCount}</p>
						<p class="text-[10px] font-bold text-teal-500 uppercase tracking-wide">{isRTL ? 'نشط' : 'Active'}</p>
					</div>
					<div class="bg-red-50/60 backdrop-blur-sm rounded-2xl border border-red-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-red-600">{overdueCount}</p>
						<p class="text-[10px] font-bold text-red-500 uppercase tracking-wide">{isRTL ? 'متأخر' : 'Overdue'}</p>
					</div>
					<div class="bg-blue-50/60 backdrop-blur-sm rounded-2xl border border-blue-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-blue-600">{quickCount}</p>
						<p class="text-[10px] font-bold text-blue-500 uppercase tracking-wide">{isRTL ? 'سريع' : 'Quick'}</p>
					</div>
					<div class="bg-purple-50/60 backdrop-blur-sm rounded-2xl border border-purple-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-purple-600">{receivingCount}</p>
						<p class="text-[10px] font-bold text-purple-500 uppercase tracking-wide">{isRTL ? 'استلام' : 'Receiving'}</p>
					</div>
				</div>

				<!-- Filters -->
				<div class="mb-4 flex gap-3">
					<div class="flex-[2]">
						<span class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'بحث' : 'Search'}</span>
						<input type="text" placeholder={isRTL ? 'بحث بالعنوان...' : 'Search by title...'} bind:value={searchQuery} on:input={applyFilters}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent transition-all" />
					</div>
					<div class="flex-1">
						<span class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'النوع' : 'Type'}</span>
						<select bind:value={selectedType} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'الكل' : 'All Types'}</option>
							<option value="regular">{isRTL ? 'عادي' : 'Regular'}</option>
							<option value="quick_task">{isRTL ? 'سريع' : 'Quick'}</option>
							<option value="receiving">{isRTL ? 'استلام' : 'Receiving'}</option>
						</select>
					</div>
					<div class="flex-1">
						<span class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'الحالة' : 'Status'}</span>
						<select bind:value={selectedStatus} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'الكل' : 'All'}</option>
							<option value="pending">{isRTL ? 'معلق' : 'Pending'}</option>
							<option value="assigned">{isRTL ? 'معين' : 'Assigned'}</option>
							<option value="in_progress">{isRTL ? 'قيد التنفيذ' : 'In Progress'}</option>
							{#if showCompleted}<option value="completed">{isRTL ? 'مكتمل' : 'Completed'}</option>{/if}
						</select>
					</div>
					<div class="flex-1">
						<span class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'الأولوية' : 'Priority'}</span>
						<select bind:value={selectedPriority} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'الكل' : 'All'}</option>
							<option value="high">{isRTL ? 'عاجل' : 'High'}</option>
							<option value="medium">{isRTL ? 'متوسط' : 'Medium'}</option>
							<option value="low">{isRTL ? 'منخفض' : 'Low'}</option>
						</select>
					</div>
					<div class="flex-1">
						<span class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'الفرع' : 'Branch'}</span>
						<select bind:value={selectedBranch} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'كل الفروع' : 'All Branches'}</option>
							{#each branches as b}<option value={b}>{b}</option>{/each}
						</select>
					</div>
				</div>

				<!-- Table -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
					<div class="overflow-x-auto flex-1 overflow-y-auto">
						<table class="w-full border-collapse [&_th]:border-x [&_th]:border-teal-500/30 [&_td]:border-x [&_td]:border-slate-200">
							<thead class="sticky top-0 bg-teal-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">#</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">{isRTL ? 'المهمة' : 'Task'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">{isRTL ? 'النوع' : 'Type'}</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">{isRTL ? 'الفرع' : 'Branch'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">{isRTL ? 'الحالة' : 'Status'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">{isRTL ? 'الأولوية' : 'Priority'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">{isRTL ? 'الموعد / المتبقي' : 'Deadline'}</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">{isRTL ? 'من' : 'From'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-teal-400">{isRTL ? 'إجراء' : 'Action'}</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each visibleTasks as task, index (task.assignment_id)}
									{@const typeInfo = getTypeInfo(task.task_type)}
									{@const prioInfo = getPriorityInfo(task.priority)}
									{@const statusInfo = getStatusInfo(task.assignment_status)}
									{@const overdue = isOverdue(task)}
									{@const countdown = getCountdown(task)}
									{@const barcode = extractBarcode(task.title)}
									<tr class="hover:bg-teal-50/30 transition-colors duration-200 {overdue ? 'bg-red-50/40' : index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
										<td class="px-4 py-2.5 text-xs text-slate-400 font-mono">{index + 1}</td>
										<td class="px-4 py-2.5">
<div class="text-sm font-semibold text-slate-800 truncate max-w-[280px] {barcode ? 'cursor-pointer hover:text-teal-600' : ''}"
											role={barcode ? 'button' : undefined} tabindex={barcode ? 0 : undefined}
												on:dblclick={() => barcode && copyToClipboard(barcode)}
												title={barcode ? (isRTL ? 'نقر مزدوج لنسخ الباركود' : 'Double-click to copy barcode') : ''}
											>{task.title}</div>
											{#if task.parent_old_price || task.parent_new_price}
												<div class="inline-flex items-center gap-1 mt-1 px-2 py-0.5 rounded-md text-[10px] font-bold" style="background:#fef3c7;border:1px solid #f59e0b;">
													<span style="color:#dc2626;text-decoration:line-through;">{task.parent_old_price || '?'}</span>
													<span style="color:#6b7280;">→</span>
													<span style="color:#16a34a;font-weight:700;">{task.parent_new_price || '?'}</span>
												</div>
											{/if}
											{#if task.product_name}
												<div class="inline-flex items-center gap-1 mt-0.5 px-2 py-0.5 rounded-md text-[10px]" style="background:#eff6ff;border:1px solid #93c5fd;">
													<span>📦</span>
													<span style="color:#1e40af;font-weight:500;max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{task.product_name}</span>
													{#if task.product_real_barcode}
														<span style="color:#6b7280;font-family:monospace;font-size:9px;">{task.product_real_barcode}</span>
													{:else if task.product_barcode}
														<span style="color:#6b7280;font-family:monospace;font-size:9px;">{task.product_barcode}</span>
													{/if}
												</div>
											{/if}
											{#if task.description && !task.parent_old_price && !task.parent_new_price}
												{@const price = extractPrice(task.description)}
												<div class="text-[10px] text-slate-400 truncate max-w-[280px]">
													{#if price}
														<span>{task.description.split(/New Price:/i)[0]}</span>
														<span class="font-bold text-blue-600 cursor-pointer hover:text-blue-800" role="button" tabindex="0" on:dblclick={() => copyToClipboard(price)} title={isRTL ? 'نقر مزدوج لنسخ السعر' : 'Double-click to copy price'}>
															{price}
														</span>
													{:else}
														{task.description.split('linked_parent_task:')[0].substring(0, 80)}
													{/if}
												</div>
											{/if}
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg border text-[10px] font-bold {typeInfo.bg} {typeInfo.color}">
												<span>{typeInfo.icon}</span> {typeInfo.label}
											</span>
										</td>
										<td class="px-4 py-2.5 text-sm text-slate-700">{getBranch(task)}</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg border text-[10px] font-bold {statusInfo.bg} {statusInfo.color}">
												{statusInfo.label}
											</span>
											{#if overdue}
												<span class="block text-[9px] font-bold text-red-600 mt-0.5">⚠ {isRTL ? 'متأخر' : 'OVERDUE'}</span>
											{/if}
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-flex items-center gap-1.5 {prioInfo.color} text-xs font-bold">
												<span class="w-2 h-2 rounded-full {prioInfo.dot}"></span>
												{prioInfo.label}
											</span>
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="text-xs font-bold {countdown.urgent ? 'text-red-600' : 'text-slate-600'}">
												{countdown.text}
											</span>
										</td>
										<td class="px-4 py-2.5 text-sm text-slate-600">{task.assigned_by_name}</td>
										<td class="px-4 py-2.5 text-center">
											<div class="flex items-center justify-center gap-1">
												{#if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled'}
													<button
														class="px-2.5 py-1.5 bg-emerald-500 text-white rounded-lg text-[10px] font-bold hover:bg-emerald-600 transition-all shadow-sm active:scale-95"
														on:click={() => openTaskCompletion(task)}
														title={isRTL ? 'إكمال' : 'Complete'}
													>
														✅
													</button>
												{/if}
												<button
													class="px-2.5 py-1.5 bg-teal-500 text-white rounded-lg text-[10px] font-bold hover:bg-teal-600 transition-all shadow-sm active:scale-95"
													on:click={() => openDetail(task)}
												>
													{isRTL ? 'تفاصيل' : 'Details'}
												</button>
												{#if isMasterAdmin}
													<button
														class="px-2 py-1.5 bg-red-500 text-white rounded-lg text-[10px] font-bold hover:bg-red-600 transition-all shadow-sm active:scale-95"
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
								<button class="px-6 py-2.5 bg-teal-500 text-white rounded-xl text-xs font-bold hover:bg-teal-600 transition-all shadow-sm hover:shadow-md" on:click={showMore}>
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
	{@const statusInfo = getStatusInfo(t.assignment_status)}
	{@const countdown = getCountdown(t)}
	<div
		class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[200] flex items-center justify-center"
		style="animation: fadeIn 0.15s ease-out;"
		on:click|self={closeDetail}
		on:keydown={(e) => e.key === 'Escape' && closeDetail()}
		role="dialog"
		tabindex="-1"
		aria-modal="true"
	>
		<div class="bg-white rounded-3xl shadow-2xl border border-slate-200 w-[560px] max-h-[80vh] overflow-hidden" style="animation: scaleIn 0.2s ease-out;" dir={isRTL ? 'rtl' : 'ltr'}>
			<div class="bg-gradient-to-r from-teal-500 to-cyan-500 px-6 py-4 flex items-center justify-between">
				<div class="flex items-center gap-3">
					<span class="text-2xl">{typeInfo.icon}</span>
					<div>
						<h3 class="text-sm font-black text-white uppercase tracking-wide">{isRTL ? 'تفاصيل المهمة' : 'Task Details'}</h3>
						<p class="text-[10px] text-teal-100 font-semibold">{typeInfo.label} • ID: {t.assignment_id?.substring(0, 8)}...</p>
					</div>
				</div>
				<button class="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 transition-all flex items-center justify-center" on:click={closeDetail} aria-label="Close">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
				</button>
			</div>
			<div class="p-6 overflow-y-auto max-h-[60vh]">
				<div class="mb-5">
					<h4 class="text-lg font-bold text-slate-800 mb-1">{t.title}</h4>
					{#if t.description}
						{@const urlPart = t.description.split('Photo URL:')[1]}
						{@const photoUrl = urlPart ? urlPart.trim().split(/[\s\n]/)[0] : null}
						<p class="text-sm text-slate-500 leading-relaxed whitespace-pre-wrap">{photoUrl ? t.description.split('Photo URL:')[0] : t.description}</p>
						{#if photoUrl && (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))}
							<div class="mt-4 rounded-lg overflow-hidden bg-slate-100 p-2">
								<img 
									src={photoUrl} 
									alt="Barcode product photo" 
									class="max-w-full max-h-[300px] object-contain rounded"
									loading="lazy"
									on:error={hideImage}
								/>
							</div>
						{/if}
					{/if}
				</div>
				<div class="grid grid-cols-2 gap-3 mb-5">
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'النوع' : 'Type'}</p>
						<span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-bold {typeInfo.bg} {typeInfo.color}">{typeInfo.icon} {typeInfo.label}</span>
					</div>
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الحالة' : 'Status'}</p>
						<span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-bold {statusInfo.bg} {statusInfo.color}">{statusInfo.label}</span>
					</div>
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الأولوية' : 'Priority'}</p>
						<span class="inline-flex items-center gap-1.5 {prioInfo.color} text-sm font-bold">
							<span class="w-2.5 h-2.5 rounded-full {prioInfo.dot}"></span> {prioInfo.label}
						</span>
					</div>
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'تاريخ الإسناد' : 'Assigned Date'}</p>
						<span class="text-sm font-semibold text-slate-700">{formatDate(t.assigned_at)}</span>
					</div>
				</div>
				{#if t.deadline_datetime}
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100 mb-5 {isOverdue(t) ? 'bg-red-50 border-red-200' : ''}">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الموعد النهائي' : 'Deadline'}</p>
						<div class="flex items-center gap-3">
							<span class="text-sm font-semibold {isOverdue(t) ? 'text-red-600' : 'text-slate-700'}">{formatDate(t.deadline_datetime)}</span>
							<span class="inline-block px-2 py-0.5 rounded-lg text-[10px] font-bold {countdown.urgent ? 'bg-red-100 text-red-700' : 'bg-teal-100 text-teal-700'}">{countdown.text}</span>
						</div>
					</div>
				{/if}
				{#if t.completed_at}
					<div class="bg-emerald-50 rounded-xl p-3 border border-emerald-100 mb-5">
						<p class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide mb-1">{isRTL ? 'تاريخ الإكمال' : 'Completed'}</p>
						<span class="text-sm font-semibold text-emerald-700">{formatDate(t.completed_at)}</span>
					</div>
				{/if}
				<div class="grid grid-cols-2 gap-3 mb-5">
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'من' : 'Assigned By'}</p>
						<p class="text-sm font-semibold text-slate-700">{t.assigned_by_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الفرع' : 'Branch'}</p>
						<p class="text-sm font-semibold text-slate-700">{getBranch(t)}</p>
					</div>
				</div>
				{#if t.task_type === 'quick_task' && (t.issue_type || t.price_tag)}
					<div class="bg-blue-50 rounded-xl p-3 border border-blue-100 mb-5">
						<p class="text-[10px] font-bold text-blue-500 uppercase tracking-wide mb-2">{isRTL ? 'تفاصيل المهمة السريعة' : 'Quick Task Details'}</p>
						<div class="grid grid-cols-2 gap-3">
							{#if t.issue_type}<div><p class="text-[10px] text-blue-400 font-bold">{isRTL ? 'نوع المشكلة' : 'Issue Type'}</p><p class="text-sm font-semibold text-blue-700 capitalize">{t.issue_type}</p></div>{/if}
							{#if t.price_tag}<div><p class="text-[10px] text-blue-400 font-bold">{isRTL ? 'السعر' : 'Price Tag'}</p><p class="text-sm font-semibold text-blue-700 capitalize">{t.price_tag}</p></div>{/if}
						</div>
					</div>
				{/if}
				{#if t.parent_old_price || t.parent_new_price}
					<div class="rounded-xl p-3 border mb-5" style="background:#fefce8;border-color:#f59e0b;">
						<p class="text-[10px] font-bold uppercase tracking-wide mb-2" style="color:#b45309;">{isRTL ? 'تغيير السعر' : 'Price Change'}</p>
						<div class="flex items-center gap-3">
							<span class="text-base font-bold" style="color:#dc2626;text-decoration:line-through;">{t.parent_old_price || '?'} SAR</span>
							<span style="color:#6b7280;font-size:18px;">→</span>
							<span class="text-base font-black" style="color:#16a34a;">{t.parent_new_price || '?'} SAR</span>
						</div>
					</div>
				{/if}
				{#if t.product_name}
					<div class="rounded-xl p-3 border mb-5" style="background:#eff6ff;border-color:#93c5fd;">
						<p class="text-[10px] font-bold uppercase tracking-wide mb-2" style="color:#1e40af;">{isRTL ? 'المنتج' : 'Product'}</p>
						<p class="text-sm font-semibold" style="color:#1e3a5f;">📦 {t.product_name}</p>
						{#if t.product_real_barcode}
							<p class="text-xs mt-1" style="color:#6b7280;font-family:monospace;">{isRTL ? 'الباركود:' : 'Barcode:'} {t.product_real_barcode}</p>
						{:else if t.product_barcode}
							<p class="text-xs mt-1" style="color:#6b7280;font-family:monospace;">{isRTL ? 'الباركود:' : 'Barcode:'} {t.product_barcode}</p>
						{/if}
					</div>
				{/if}
				{#if t.parent_title}
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100 mb-5">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'المهمة الأصلية' : 'Parent Task'}</p>
						<p class="text-sm font-semibold text-slate-700">{t.parent_title}</p>
					</div>
				{/if}
				{#if t.task_type === 'receiving' && (t.role_type || t.clearance_certificate_url)}
					<div class="bg-purple-50 rounded-xl p-3 border border-purple-100 mb-5">
						<p class="text-[10px] font-bold text-purple-500 uppercase tracking-wide mb-2">{isRTL ? 'تفاصيل الاستلام' : 'Receiving Details'}</p>
						{#if t.role_type}<p class="text-sm text-purple-700"><span class="font-bold">{isRTL ? 'الدور:' : 'Role:'}</span> {t.role_type}</p>{/if}
					</div>
				{/if}
			</div>
			<div class="px-6 py-3 bg-slate-50 border-t border-slate-200 flex items-center justify-between">
				<div class="flex items-center gap-2">
					{#if t.assignment_status !== 'completed' && t.assignment_status !== 'cancelled'}
						<button class="px-4 py-2 bg-emerald-500 text-white rounded-xl text-xs font-bold hover:bg-emerald-600 transition-all flex items-center gap-2"
						on:click={() => { const task = t; closeDetail(); openTaskCompletion(task); }}>
							✅ {isRTL ? 'إكمال' : 'Complete'}
						</button>
					{/if}
					<button class="px-4 py-2 bg-teal-500 text-white rounded-xl text-xs font-bold hover:bg-teal-600 transition-all flex items-center gap-2"
						on:click={() => { const task = t; closeDetail(); openTaskDetails(task); }}>
						{isRTL ? 'عرض كامل' : 'Full View'}
					</button>
					{#if isMasterAdmin}
						<button class="px-4 py-2 bg-red-500 text-white rounded-xl text-xs font-bold hover:bg-red-600 transition-all flex items-center gap-2"
							on:click={() => confirmDelete(t)}>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2m3 0v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6h14"/></svg>
							{isRTL ? 'حذف' : 'Delete'}
						</button>
					{/if}
				</div>
				<button class="px-5 py-2 bg-slate-200 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-300 transition-all" on:click={closeDetail}>
					{isRTL ? 'إغلاق' : 'Close'}
				</button>
			</div>
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
				<p class="text-sm text-slate-500 mb-1">{isRTL ? 'هل أنت متأكد من حذف هذه المهمة؟' : 'Are you sure you want to delete this task?'}</p>
				{#if selectedTask}
					<p class="text-sm font-semibold text-slate-700 bg-slate-50 rounded-lg px-3 py-2 mt-3">{selectedTask.title}</p>
				{/if}
				<p class="text-[10px] text-red-500 font-bold mt-3">⚠️ {isRTL ? 'لا يمكن التراجع عن هذا الإجراء' : 'This action cannot be undone'}</p>
			</div>
			<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex items-center justify-center gap-3">
				<button class="px-5 py-2.5 bg-slate-200 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-300 transition-all" on:click={cancelDelete} disabled={isDeleting}>
					{isRTL ? 'إلغاء' : 'Cancel'}
				</button>
				<button class="px-5 py-2.5 bg-red-500 text-white rounded-xl text-xs font-bold hover:bg-red-600 transition-all flex items-center gap-2 disabled:opacity-50" on:click={deleteAssignment} disabled={isDeleting}>
					{#if isDeleting}<div class="w-3 h-3 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>{/if}
					{isRTL ? 'حذف نهائي' : 'Delete Permanently'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
	@keyframes scaleIn { from { opacity: 0; transform: scale(0.95); } to { opacity: 1; transform: scale(1); } }
	:global([dir="rtl"] select) {
		background-position: left 0.75rem center !important;
		padding-left: 2.5rem !important;
		padding-right: 1rem !important;
	}
</style>