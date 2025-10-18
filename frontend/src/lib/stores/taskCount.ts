import { writable } from 'svelte/store';
import { supabase } from '$lib/utils/supabase';
import { currentUser } from '$lib/utils/persistentAuth';
import { get } from 'svelte/store';
import { browser } from '$app/environment';

export interface TaskCounts {
	total: number;
	pending: number;
	inProgress: number;
	overdue: number;
	quickTasks: number;
	regularTasks: number;
	loading: boolean;
	lastUpdated: Date;
}

// Create task counts store
export const taskCounts = writable<TaskCounts>({
	total: 0,
	pending: 0,
	inProgress: 0,
	overdue: 0,
	quickTasks: 0,
	regularTasks: 0,
	loading: true,
	lastUpdated: new Date()
});

// Track previous counts to detect changes
let previousTotalCount = 0;
let isInitialLoad = true;

// Task count management functions
export const taskCountService = {
	// Fetch task counts for current user
	async fetchTaskCounts(silent = false): Promise<void> {
		const user = get(currentUser);
		if (!user || !browser) {
			return;
		}

		if (!silent) {
			taskCounts.update(state => ({ ...state, loading: true }));
		}

		try {
			const now = new Date().toISOString();
			
			// Fetch regular task assignments (simplified query like mobile layout)
			const { data: regularTasks, error: regularError } = await supabase
				.from('task_assignments')
				.select('id, status, deadline_date, deadline_time, assigned_at')
				.eq('assigned_to_user_id', user.id)
				.in('status', ['assigned', 'in_progress', 'pending']);

			// Fetch quick task assignments (simplified query like mobile layout)
			const { data: quickTasks, error: quickError } = await supabase
				.from('quick_task_assignments')
				.select(`
					id,
					status,
					created_at,
					quick_task:quick_tasks!inner(
						deadline_datetime
					)
				`)
				.eq('assigned_to_user_id', user.id)
				.in('status', ['assigned', 'in_progress', 'pending']);

			if (regularError) {
				console.error('Error fetching regular task counts:', regularError);
			}

			if (quickError) {
				console.error('Error fetching quick task counts:', quickError);
			}

			// Process the data
			const regularTasksCount = regularTasks?.length || 0;
			const quickTasksCount = quickTasks?.length || 0;
			const totalCount = regularTasksCount + quickTasksCount;

			// Count pending and in-progress tasks
			const pendingRegular = regularTasks?.filter(t => t.status === 'pending' || t.status === 'assigned').length || 0;
			const inProgressRegular = regularTasks?.filter(t => t.status === 'in_progress').length || 0;
			const pendingQuick = quickTasks?.filter(t => t.status === 'pending' || t.status === 'assigned').length || 0;
			const inProgressQuick = quickTasks?.filter(t => t.status === 'in_progress').length || 0;

			// Count overdue tasks
			const overdueRegular = regularTasks?.filter(t => {
				if (!t.deadline_date) return false;
				const deadlineStr = t.deadline_time ? 
					`${t.deadline_date}T${t.deadline_time}` : 
					`${t.deadline_date}T23:59:59`;
				return new Date(deadlineStr) < new Date(now) && 
					   t.status !== 'completed' && 
					   t.status !== 'cancelled';
			}).length || 0;

			const overdueQuick = quickTasks?.filter(t => {
				const deadlineDateTime = t.quick_task?.deadline_datetime;
				if (!deadlineDateTime) return false;
				return new Date(deadlineDateTime) < new Date(now) && 
					   t.status !== 'completed' && 
					   t.status !== 'cancelled';
			}).length || 0;

			const counts: TaskCounts = {
				total: totalCount,
				pending: pendingRegular + pendingQuick,
				inProgress: inProgressRegular + inProgressQuick,
				overdue: overdueRegular + overdueQuick,
				quickTasks: quickTasksCount,
				regularTasks: regularTasksCount,
				loading: false,
				lastUpdated: new Date()
			};

			// Update the store
			taskCounts.set(counts);

			// Update PWA badge if supported and count changed
			if (browser && totalCount !== previousTotalCount) {
				try {
					// Try direct API first
					if ('setAppBadge' in navigator) {
						if (totalCount > 0) {
							await (navigator as any).setAppBadge(totalCount);
						} else {
							await (navigator as any).clearAppBadge();
						}
					} else {
						// Fallback to service worker
						if ('serviceWorker' in navigator && (navigator as any).serviceWorker.controller) {
							(navigator as any).serviceWorker.controller.postMessage({
								type: 'UPDATE_TASK_BADGE',
								taskCount: totalCount
							});
						}
					}
				} catch (error) {
					console.warn('Failed to update app badge:', error);
				}
			}

			// Play notification sound if count increased (new tasks)
			if (!isInitialLoad && totalCount > previousTotalCount && browser) {
				try {
					const { notificationSoundManager } = await import('$lib/utils/inAppNotificationSounds');
					if (notificationSoundManager) {
						const newTaskNotification = {
							id: 'new-task-' + Date.now(),
							title: 'New Task Assignment',
							message: `You have ${totalCount - previousTotalCount} new task${totalCount - previousTotalCount !== 1 ? 's' : ''} assigned`,
							type: 'info' as const,
							priority: 'medium' as const,
							timestamp: new Date(),
							read: false,
							soundEnabled: true
						};
						await notificationSoundManager.playNotificationSound(newTaskNotification);
					}
				} catch (error) {
					console.warn('Failed to play new task notification sound:', error);
				}
			}

			previousTotalCount = totalCount;
			isInitialLoad = false;

			console.log('📊 Task counts updated:', counts);

		} catch (error) {
			console.error('Error fetching task counts:', error);
			taskCounts.update(state => ({ ...state, loading: false }));
		}
	},

	// Refresh task counts (wrapper for fetchTaskCounts)
	async refreshTaskCounts(): Promise<void> {
		return this.fetchTaskCounts();
	},

	// Subscribe to real-time task updates
	subscribeToTaskUpdates() {
		const user = get(currentUser);
		if (!user || !browser) return null;

		// Subscribe to regular task assignments
		const regularTaskChannel = supabase
			.channel('task-assignments-updates')
			.on('postgres_changes', 
				{ 
					event: '*', 
					schema: 'public', 
					table: 'task_assignments',
					filter: `assigned_to_user_id=eq.${user.id}`
				}, 
				() => {
					console.log('📋 Regular task assignment changed, refreshing counts...');
					this.fetchTaskCounts(true); // Silent refresh
				}
			)
			.subscribe();

		// Subscribe to quick task assignments
		const quickTaskChannel = supabase
			.channel('quick-task-assignments-updates')
			.on('postgres_changes', 
				{ 
					event: '*', 
					schema: 'public', 
					table: 'quick_task_assignments',
					filter: `assigned_to_user_id=eq.${user.id}`
				}, 
				() => {
					console.log('⚡ Quick task assignment changed, refreshing counts...');
					this.fetchTaskCounts(true); // Silent refresh
				}
			)
			.subscribe();

		return () => {
			supabase.removeChannel(regularTaskChannel);
			supabase.removeChannel(quickTaskChannel);
		};
	},

	// Initialize task count monitoring
	async initTaskCountMonitoring() {
		if (!browser) return;

		// Initial fetch
		await this.fetchTaskCounts();

		// Subscribe to real-time updates
		const unsubscribe = this.subscribeToTaskUpdates();

		// Periodic refresh every 5 minutes
		const refreshInterval = setInterval(() => {
			this.fetchTaskCounts(true);
		}, 5 * 60 * 1000);

		// Return cleanup function
		return () => {
			if (unsubscribe) unsubscribe();
			clearInterval(refreshInterval);
		};
	}
};

// Start monitoring when the store is imported (browser only)
if (browser) {
	// Wait for current user to be available
	currentUser.subscribe(user => {
		if (user) {
			taskCountService.initTaskCountMonitoring();
		}
	});
}