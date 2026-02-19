<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { locale } from '$lib/i18n';

	import TaskCreateForm from '$lib/components/desktop-interface/master/tasks/TaskCreateForm.svelte';
	import TaskViewTable from '$lib/components/desktop-interface/master/tasks/TaskViewTable.svelte';
	import TaskAssignmentView from '$lib/components/desktop-interface/master/tasks/TaskAssignmentView.svelte';
	import MyTasksView from '$lib/components/desktop-interface/master/tasks/MyTasksView.svelte';
	import TaskStatusView from '$lib/components/desktop-interface/master/tasks/TaskStatusView.svelte';
	import MyAssignmentsView from '$lib/components/desktop-interface/master/tasks/MyAssignmentsView.svelte';
	import QuickTaskWindow from '$lib/components/desktop-interface/master/tasks/QuickTaskWindow.svelte';
	import TotalTasksView from '$lib/components/desktop-interface/master/tasks/TotalTasksView.svelte';
	import CompletedTasksView from '$lib/components/desktop-interface/master/tasks/CompletedTasksView.svelte';
	import IncompleteTasksView from '$lib/components/desktop-interface/master/tasks/IncompleteTasksView.svelte';

	let taskStats = {
		total_tasks: 0,
		completed_tasks: 0,
		incomplete_tasks: 0,
		my_assigned_tasks: 0,
		my_completed_tasks: 0,
		my_assignments: 0
	};

	let isLoading = true;
	let refreshInterval: any = null;

	$: isRTL = $locale === 'ar';

	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	async function fetchTaskStatistics() {
		if (!$currentUser?.id) return;
		try {
			isLoading = true;
			const { data, error } = await supabase.rpc('get_task_master_stats', { p_user_id: $currentUser.id });
			if (error) throw error;
			taskStats = {
				total_tasks: data?.total_tasks || 0,
				completed_tasks: data?.completed_tasks || 0,
				incomplete_tasks: data?.incomplete_tasks || 0,
				my_assigned_tasks: data?.my_assigned_tasks || 0,
				my_completed_tasks: data?.my_completed_tasks || 0,
				my_assignments: data?.my_assignments || 0
			};
		} catch (err) {
			console.error('❌ Error fetching task statistics:', err);
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		fetchTaskStatistics();
		refreshInterval = setInterval(fetchTaskStatistics, 60000);
	});

	onDestroy(() => {
		if (refreshInterval) clearInterval(refreshInterval);
	});

	// ─── Window openers ───
	function openCreateTask() {
		openWindow({
			id: generateWindowId('create-task'), title: isRTL ? 'إنشاء قالب مهمة' : 'Create Task Template',
			component: TaskCreateForm, icon: '📝',
			size: { width: 600, height: 500 }, position: { x: 100 + Math.random() * 100, y: 100 + Math.random() * 100 },
			resizable: true, minimizable: true, maximizable: true, closable: true
		});
	}

	function openViewTasks() {
		openWindow({
			id: generateWindowId('view-tasks'), title: isRTL ? 'قوالب المهام' : 'Task Templates',
			component: TaskViewTable, icon: '📋',
			size: { width: 1000, height: 700 }, position: { x: 50 + Math.random() * 50, y: 50 + Math.random() * 50 },
			resizable: true, minimizable: true, maximizable: true, closable: true
		});
	}

	function openAssignTasks() {
		openWindow({
			id: generateWindowId('assign-tasks'), title: isRTL ? 'تعيين المهام' : 'Assign Tasks',
			component: TaskAssignmentView, icon: '👥',
			size: { width: 900, height: 600 }, position: { x: 100 + Math.random() * 100, y: 100 + Math.random() * 100 },
			resizable: true, minimizable: true, maximizable: true, closable: true
		});
	}

	function openTaskStatus() {
		openWindow({
			id: generateWindowId('task-status'), title: isRTL ? 'حالة المهام' : 'Task Status',
			component: TaskStatusView, icon: '📊',
			size: { width: 1200, height: 800 }, position: { x: 50 + Math.random() * 100, y: 50 + Math.random() * 100 },
			resizable: true, minimizable: true, maximizable: true, closable: true
		});
	}

	function openMyTasks() {
		openWindow({
			id: generateWindowId('my-tasks'), title: isRTL ? 'مهامي' : 'My Tasks',
			component: MyTasksView, icon: '📝',
			size: { width: 1000, height: 700 }, position: { x: 50 + Math.random() * 100, y: 50 + Math.random() * 100 },
			resizable: true, minimizable: true, maximizable: true, closable: true
		});
	}

	function openMyAssignments() {
		openWindow({
			id: generateWindowId('my-assignments'), title: isRTL ? 'تعييناتي' : 'My Assignments',
			component: MyAssignmentsView, icon: '👨‍💼',
			size: { width: 1200, height: 800 }, position: { x: 75 + Math.random() * 100, y: 75 + Math.random() * 100 },
			resizable: true, minimizable: true, maximizable: true, closable: true
		});
	}

	function openQuickTaskWindow() {
		openWindow({
			id: generateWindowId('quick-task'), title: isRTL ? 'مهمة سريعة' : 'Quick Task',
			component: QuickTaskWindow, icon: '⚡',
			size: { width: 600, height: 500 }, position: { x: 150 + Math.random() * 100, y: 100 + Math.random() * 100 },
			resizable: true, minimizable: true, maximizable: true, closable: true
		});
	}

	function openTaskDetails(cardType: string) {
		const componentMap: Record<string, any> = {
			total_tasks: TotalTasksView,
			completed_tasks: CompletedTasksView,
			incomplete_tasks: IncompleteTasksView,
			my_assigned_tasks: MyTasksView,
			my_completed_tasks: MyTasksView,
			my_assignments: MyAssignmentsView
		};
		const titleMap: Record<string, string> = {
			total_tasks: isRTL ? '📋 إجمالي المهام' : '📋 Total Tasks',
			completed_tasks: isRTL ? '✅ المهام المكتملة' : '✅ Completed Tasks',
			incomplete_tasks: isRTL ? '⏳ المهام غير المكتملة' : '⏳ Incomplete Tasks',
			my_assigned_tasks: isRTL ? '👤 مهامي' : '👤 My Tasks',
			my_completed_tasks: isRTL ? '✅ مهامي المكتملة' : '✅ My Completed',
			my_assignments: isRTL ? '📌 تعييناتي' : '📌 My Assignments'
		};
		const iconMap: Record<string, string> = {
			total_tasks: '📋', completed_tasks: '✅', incomplete_tasks: '⏳',
			my_assigned_tasks: '👤', my_completed_tasks: '✅', my_assignments: '📌'
		};
		openWindow({
			id: generateWindowId('task-details'), title: titleMap[cardType] || 'Task Details',
			component: componentMap[cardType] || TotalTasksView, icon: iconMap[cardType] || '📋',
			size: { width: 1200, height: 700 }, position: { x: 50 + Math.random() * 100, y: 50 + Math.random() * 100 },
			resizable: true, minimizable: true, maximizable: true, closable: true
		});
	}

	// Stats card definitions
	const statCards = [
		{ key: 'total_tasks', icon: '📋', labelAr: 'إجمالي المهام', labelEn: 'Total Tasks', bg: 'bg-blue-50/70', border: 'border-blue-200', text: 'text-blue-700' },
		{ key: 'completed_tasks', icon: '✅', labelAr: 'المكتملة', labelEn: 'Completed', bg: 'bg-emerald-50/70', border: 'border-emerald-200', text: 'text-emerald-700' },
		{ key: 'incomplete_tasks', icon: '⏳', labelAr: 'غير المكتملة', labelEn: 'Incomplete', bg: 'bg-amber-50/70', border: 'border-amber-200', text: 'text-amber-700' },
		{ key: 'my_assigned_tasks', icon: '📝', labelAr: 'مهامي', labelEn: 'My Tasks', bg: 'bg-teal-50/70', border: 'border-teal-200', text: 'text-teal-700' },
		{ key: 'my_completed_tasks', icon: '🏆', labelAr: 'مكتملاتي', labelEn: 'My Completed', bg: 'bg-violet-50/70', border: 'border-violet-200', text: 'text-violet-700' },
		{ key: 'my_assignments', icon: '📌', labelAr: 'تعييناتي', labelEn: 'Assigned By Me', bg: 'bg-indigo-50/70', border: 'border-indigo-200', text: 'text-indigo-700' }
	];

	// Action card definitions
	const actionCards = [
		{ fn: 'createTask', icon: '✨', labelAr: 'إنشاء قالب مهمة', labelEn: 'Create Template', descAr: 'إنشاء قوالب مهام جديدة', descEn: 'Add new task templates', color: 'from-emerald-500 to-green-600', hover: 'hover:shadow-emerald-200/50' },
		{ fn: 'viewTasks', icon: '📋', labelAr: 'قوالب المهام', labelEn: 'Templates', descAr: 'عرض وإدارة القوالب', descEn: 'Browse & manage templates', color: 'from-blue-500 to-blue-600', hover: 'hover:shadow-blue-200/50' },
		{ fn: 'myTasks', icon: '📝', labelAr: 'مهامي', labelEn: 'My Tasks', descAr: 'عرض وإكمال مهامك', descEn: 'View & complete your tasks', color: 'from-teal-500 to-cyan-600', hover: 'hover:shadow-teal-200/50' },
		{ fn: 'myAssignments', icon: '👨‍💼', labelAr: 'تعييناتي', labelEn: 'My Assignments', descAr: 'تتبع المهام المعينة للآخرين', descEn: 'Track tasks assigned to others', color: 'from-indigo-500 to-violet-600', hover: 'hover:shadow-indigo-200/50' },
		{ fn: 'assignTasks', icon: '👥', labelAr: 'تعيين المهام', labelEn: 'Assign Tasks', descAr: 'تعيين المهام للمستخدمين', descEn: 'Assign tasks to users', color: 'from-purple-500 to-fuchsia-600', hover: 'hover:shadow-purple-200/50' },
		{ fn: 'taskStatus', icon: '📊', labelAr: 'حالة المهام', labelEn: 'Task Status', descAr: 'مراقبة التقدم والتذكيرات', descEn: 'Monitor progress & reminders', color: 'from-rose-500 to-pink-600', hover: 'hover:shadow-rose-200/50' }
	];

	function handleAction(fn: string) {
		const map: Record<string, () => void> = {
			createTask: openCreateTask,
			viewTasks: openViewTasks,
			myTasks: openMyTasks,
			myAssignments: openMyAssignments,
			assignTasks: openAssignTasks,
			taskStatus: openTaskStatus
		};
		map[fn]?.();
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">📋</span>
			<div>
				<h2 class="text-sm font-black text-slate-800 uppercase tracking-wide">{isRTL ? 'لوحة إدارة المهام' : 'Task Master'}</h2>
				<p class="text-[10px] text-slate-400 font-semibold">{isRTL ? 'نظام إدارة المهام الشامل' : 'Comprehensive Task Management'}</p>
			</div>
		</div>
		<div class="flex items-center gap-2">
			<button
				class="flex items-center gap-2 px-4 py-2 bg-blue-500 text-white rounded-xl text-xs font-bold hover:bg-blue-600 transition-all shadow-sm hover:shadow-md active:scale-95"
				on:click={openQuickTaskWindow}
			>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 5v14m-7-7h14"/></svg>
				{isRTL ? 'مهمة سريعة' : 'Quick Task'}
			</button>
			<button
				class="flex items-center gap-2 px-4 py-2 bg-slate-100 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-200 transition-all shadow-sm active:scale-95"
				on:click={fetchTaskStatistics}
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
	<div class="flex-1 p-6 overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50 relative">
		<div class="absolute top-0 right-0 w-[400px] h-[400px] bg-blue-100/20 rounded-full blur-[120px] -mr-48 -mt-48 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-violet-100/15 rounded-full blur-[120px] -ml-48 -mb-48 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative max-w-5xl mx-auto space-y-6">

			<!-- Stats Cards -->
			<div class="grid grid-cols-6 gap-3">
				{#if isLoading}
					{#each Array(6) as _}
						<div class="bg-white/60 backdrop-blur-sm rounded-2xl border border-white/80 shadow-sm p-4 text-center animate-pulse">
							<div class="h-6 w-10 bg-slate-200 rounded mx-auto mb-2"></div>
							<div class="h-3 w-16 bg-slate-200 rounded mx-auto"></div>
						</div>
					{/each}
				{:else}
					{#each statCards as card}
						<button
							class="{card.bg} backdrop-blur-sm rounded-2xl border {card.border} shadow-sm p-4 text-center transition-all duration-300 hover:shadow-lg hover:-translate-y-1 cursor-pointer group active:scale-95"
							on:click={() => openTaskDetails(card.key)}
						>
							<div class="text-xl mb-1 group-hover:scale-110 transition-transform">{card.icon}</div>
							<p class="text-2xl font-black {card.text}">{taskStats[card.key as keyof typeof taskStats]}</p>
							<p class="text-[9px] font-bold text-slate-500 uppercase tracking-wider mt-1">{isRTL ? card.labelAr : card.labelEn}</p>
						</button>
					{/each}
				{/if}
			</div>

			<!-- Action Cards -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
				<h3 class="text-xs font-black text-slate-500 uppercase tracking-wider mb-4 {isRTL ? 'text-right' : 'text-left'}">{isRTL ? 'الإجراءات السريعة' : 'Quick Actions'}</h3>
				<div class="grid grid-cols-3 gap-4">
					{#each actionCards as card}
						<button
							class="group relative overflow-hidden bg-white/70 backdrop-blur rounded-2xl border border-slate-200 p-5 text-{isRTL ? 'right' : 'left'} transition-all duration-300 hover:shadow-xl {card.hover} hover:-translate-y-1 active:scale-[0.98]"
							on:click={() => handleAction(card.fn)}
						>
							<div class="absolute top-0 {isRTL ? 'right-0' : 'left-0'} w-1 h-full bg-gradient-to-b {card.color} rounded-full opacity-0 group-hover:opacity-100 transition-opacity"></div>
							<div class="flex items-start gap-3">
								<div class="w-10 h-10 rounded-xl bg-gradient-to-br {card.color} flex items-center justify-center text-white text-lg shadow-md group-hover:scale-110 transition-transform flex-shrink-0">
									{card.icon}
								</div>
								<div class="flex-1 min-w-0">
									<h4 class="text-sm font-bold text-slate-800 mb-0.5">{isRTL ? card.labelAr : card.labelEn}</h4>
									<p class="text-[10px] text-slate-400 font-semibold leading-relaxed">{isRTL ? card.descAr : card.descEn}</p>
								</div>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="text-slate-300 group-hover:text-slate-500 transition-all group-hover:{isRTL ? '-translate-x-1' : 'translate-x-1'} flex-shrink-0 mt-1 {isRTL ? 'rotate-180' : ''}">
									<path d="M9 18l6-6-6-6"/>
								</svg>
							</div>
						</button>
					{/each}
				</div>
			</div>

		</div>
	</div>
</div>

<style>
	@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
</style>