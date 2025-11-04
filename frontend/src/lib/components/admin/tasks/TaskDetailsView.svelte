<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let cardType: string = 'total_tasks';
	export let onClose: () => void;

	let tasks: any[] = [];
	let filteredTasks: any[] = [];
	let isLoading = true;
	let searchQuery = '';
	let selectedUser = '';
	let selectedBranch = '';
	let dateFilter = 'all';
	let customDateFrom = '';
	let customDateTo = '';
	let selectedTask: any = null;
	let showTaskDetail = false;

	let users: any[] = [];
	let branches: any[] = [];
	
	// Computed property: users who have tasks assigned
	$: usersWithTasks = (() => {
		if (!tasks.length || !users.length) return [];
		
		// Get unique user IDs from tasks
		const userIdsWithTasks = new Set();
		tasks.forEach(task => {
			if (task.assigned_to_user_id) {
				userIdsWithTasks.add(task.assigned_to_user_id);
			}
			// Also check other user ID fields that might be used
			if (task.assigned_to) {
				userIdsWithTasks.add(task.assigned_to);
			}
		});
		
		// Filter users to only include those with tasks
		return users.filter(user => userIdsWithTasks.has(user.id));
	})();
	// Reminder functionality
	let selectedTaskIds: Set<string> = new Set();
	let selectedTaskIdsArray: string[] = [];
	let isSendingReminders = false;
	let reminderStats = { sent: 0, failed: 0 };
	let showReminderStats = false;
	let autoReminderCount = 0;
	let autoReminderStats = {
		totalReminders: 0,
		totalTriggers: 0,
		lastTrigger: null as string | null,
		avgPerTrigger: 0
	};

	// Card type titles
	const cardTitles = {
		total_tasks: 'Total Tasks',
		active_tasks: 'Active Tasks',
		completed_tasks: 'Total Completed Tasks',
		incomplete_tasks: 'Total Incomplete Tasks',
		my_assigned_tasks: 'My Assigned Tasks',
		my_completed_tasks: 'My Completed Tasks',
		my_assignments: 'My Assignments',
		my_assignments_completed: 'My Assignments Completed'
	};

	onMount(async () => {
		await loadFilters();
		await loadTasks();
		await loadAutoReminderCount();
	});

	async function loadFilters() {
		try {
			// Load users
			const { data: userData } = await supabase
				.from('users')
				.select('id, username, username')
				.order('username');
			
			if (userData) users = userData;

			// Load branches
			const { data: branchData } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.order('name_en');
			
			if (branchData) branches = branchData;

		} catch (error) {
			console.error('Error loading filters:', error);
		}
	}

	async function loadTasks() {
		try {
			isLoading = true;
			tasks = [];

			const user = $currentUser;
			if (!user) return;

			if (cardType === 'total_tasks') {
				await loadTotalTasks();
			} else if (cardType === 'active_tasks') {
				await loadActiveTasks();
			} else if (cardType === 'completed_tasks') {
				await loadCompletedTasks();
			} else if (cardType === 'incomplete_tasks') {
				await loadIncompleteTasks();
			} else if (cardType === 'my_assigned_tasks') {
				await loadMyAssignedTasks(user);
			} else if (cardType === 'my_completed_tasks') {
				await loadMyCompletedTasks(user);
			} else if (cardType === 'my_assignments') {
				await loadMyAssignments(user);
			} else if (cardType === 'my_assignments_completed') {
				await loadMyAssignmentsCompleted(user);
			}

			filteredTasks = [...tasks];
			applyFilters();
		} catch (error) {
			console.error('Error loading tasks:', error);
		} finally {
			isLoading = false;
		}
	}

	async function loadTotalTasks() {
		console.log('🔍 Loading total tasks...');
		
		try {
			// Load ALL task_assignments using pagination with joins for branch and user data
			let allTaskAssignments = [];
			let page = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const start = page * pageSize;
				const end = start + pageSize - 1;
				
				const { data: batch, error: batchError } = await supabase
					.from('task_assignments')
					.select(`
						*,
						assigned_to_branch:assigned_to_branch_id(id, name_en),
						assigned_by_user:assigned_by(id, username),
						assigned_to_user:assigned_to_user_id(id, username),
						task:task_id(id, title, description)
					`)
					.range(start, end);

				if (batchError) {
					console.error(`❌ Error loading task_assignments batch ${page}:`, batchError);
					break;
				}

				if (batch && batch.length > 0) {
					allTaskAssignments = [...allTaskAssignments, ...batch];
					console.log(`📋 Loaded batch ${page}: ${batch.length} records (total: ${allTaskAssignments.length})`);
					
					// If we got less than pageSize, we're done
					if (batch.length < pageSize) {
						hasMore = false;
					} else {
						page++;
					}
				} else {
					hasMore = false;
				}
			}

			console.log('📋 Total task_assignments loaded:', allTaskAssignments.length);

			// Load from quick_task_assignments simplified
			const { data: quickAssignments, error: qaError } = await supabase
				.from('quick_task_assignments')
				.select('*')
				.limit(1000);

			if (qaError) {
				console.error('❌ Error loading quick_task_assignments:', qaError);
			} else {
				console.log('⚡ Loaded quick_task_assignments:', quickAssignments?.length || 0);
			}

			// Load receiving_tasks with receiving record information
			const { data: receivingTasks, error: rtError } = await supabase
				.from('receiving_tasks')
				.select(`
					*,
					receiving_record:receiving_record_id(
						id,
						user_id,
						branch:branch_id(id, name_en)
					)
				`)
				.limit(1000);

			if (rtError) {
				console.error('❌ Error loading receiving_tasks:', rtError);
			} else {
				console.log('📦 Loaded receiving_tasks:', receivingTasks?.length || 0);
				if (receivingTasks && receivingTasks.length > 0) {
					console.log('📦 Sample receiving task:', receivingTasks[0]);
				}
			}

			// Process all the data
			tasks = [];

			if (allTaskAssignments) {
				console.log('📝 Processing task_assignments:', allTaskAssignments.length);
				const processedTasks = allTaskAssignments.map(ta => ({
					...ta,
					task_title: ta.task?.title || `📋 Task Assignment #${ta.id.slice(-8)}`,
					task_description: ta.task?.description || ta.task_description || ta.description || 'Regular task assignment',
					task_type: 'regular',
					branch_name: ta.assigned_to_branch?.name_en || 'No Branch',
					branch_id: ta.assigned_to_branch_id,
					assigned_date: ta.assigned_at,
					deadline: ta.deadline_datetime || ta.deadline_date,
					assigned_by_name: ta.assigned_by_user?.username || 'System',
					assigned_to_name: ta.assigned_to_user?.username || 'Unassigned',
					assigned_to_user_id: ta.assigned_to_user_id
				}));
				tasks = [...tasks, ...processedTasks];
			}

			if (quickAssignments) {
				console.log('⚡ Processing quick_task_assignments:', quickAssignments.length);
				const processedQuickTasks = quickAssignments.map(qa => ({
					...qa,
					task_title: `⚡ Quick Task #${qa.id}`,
					task_description: qa.description || 'Quick task assignment',
					task_type: 'quick',
					branch_name: 'No Branch',
					branch_id: null,
					assigned_date: qa.created_at,
					deadline: null,
					assigned_by_name: 'System',
					assigned_to_name: 'TBD',
					assigned_to_user_id: qa.assigned_to_user_id
				}));
				tasks = [...tasks, ...processedQuickTasks];
			}

			if (receivingTasks) {
				// Get unique user IDs (both creators and assigned users)
				const creatorUserIds = [...new Set(receivingTasks.map(rt => rt.receiving_record?.user_id).filter(Boolean))];
				const assignedUserIds = [...new Set(receivingTasks.map(rt => rt.assigned_user_id).filter(Boolean))];
				const allUserIds = [...new Set([...creatorUserIds, ...assignedUserIds])];
				
				// Fetch user information for all users with IDs
				let userMap = new Map();
				if (allUserIds.length > 0) {
					const { data: users, error: usersError } = await supabase
						.from('users')
						.select('id, username')
						.in('id', allUserIds);
					
					if (usersError) {
						console.error('❌ Error fetching users:', usersError);
					}
					
					if (users) {
						users.forEach(user => userMap.set(user.id, user.username));
					}
				}
				
				// For tasks with null assigned_user_id, find users by role and branch
				const tasksWithNullAssignment = receivingTasks.filter(rt => !rt.assigned_user_id && rt.role_type && rt.receiving_record?.branch?.id);
				let roleUserMap = new Map(); // Map of "role|branchId" -> username
				
				if (tasksWithNullAssignment.length > 0) {
					// Get unique role+branch combinations using a better delimiter
					const rolesByBranch = [...new Set(tasksWithNullAssignment.map(rt => 
						`${rt.role_type}|${rt.receiving_record.branch.id}`
					))];
					
					console.log('🔍 Role+Branch combinations found:', rolesByBranch);
					
					// Since all users have user_type='branch_specific', we can't match by role
					// Let's just skip the user lookup and use role names directly
					console.log('ℹ️ All users have user_type="branch_specific", skipping role-based user lookup');
					console.log('ℹ️ Will use role types directly as assignee names for receiving tasks');
				}
				
				const receivingTasksFormatted = receivingTasks.map(rt => {
					const branchId = rt.receiving_record?.branch?.id;
					let assignedToUsername;
					
					if (rt.assigned_user_id) {
						// Use direct user ID mapping
						assignedToUsername = userMap.get(rt.assigned_user_id);
					} else if (rt.role_type && branchId) {
						// Since users don't have specific role types, format the role name nicely
						assignedToUsername = rt.role_type
							.split('_')
							.map(word => word.charAt(0).toUpperCase() + word.slice(1))
							.join(' ');
					}
					
					// Fallback to role_type if no username found
					assignedToUsername = assignedToUsername || rt.role_type || 'Unassigned';
					
					return {
						...rt,
						task_title: `📦 ${rt.title || `Receiving Task #${rt.id}`}`,
						task_description: rt.description || 'Receiving task for inventory management',
						task_type: 'receiving',
						branch_name: rt.receiving_record?.branch?.name_en || 'No Branch',
						branch_id: branchId || null,
						assigned_date: rt.created_at,
						deadline: rt.due_date,
						assigned_by_name: userMap.get(rt.receiving_record?.user_id) || 'System',
						assigned_to_name: assignedToUsername,
						assigned_to_user_id: rt.assigned_user_id,
						role_type: rt.role_type,
						task_status: rt.task_status,
						priority: rt.priority
					};
				});

				tasks = [...tasks, ...receivingTasksFormatted];
				console.log('📦 Added receiving tasks to main list. Total receiving tasks:', receivingTasksFormatted.length);
			}

			console.log('🎯 Total tasks loaded:', tasks.length);
			console.log('📊 Task types breakdown:', {
				regular: tasks.filter(t => t.task_type === 'regular').length,
				quick: tasks.filter(t => t.task_type === 'quick').length,
				receiving: tasks.filter(t => t.task_type === 'receiving').length
			});

		} catch (error) {
			console.error('💥 Fatal error in loadTotalTasks:', error);
		}
	}

	async function loadActiveTasks() {
		const { data } = await supabase
			.from('tasks')
			.select(`
				*,
				task_assignments(
					*,
					branches(id, name_en),
					assigner:assigned_by(id, username, username),
					assignee:assigned_to_user_id(id, username, username, user_branch:branch_id(id, name_en))
				)
			`)
			.eq('status', 'active');

		if (data) {
			tasks = data.map(t => ({
				...t,
				task_title: t.title,
				task_description: t.description,
				task_type: 'regular',
				branch_name: t.task_assignments?.[0]?.assignee?.user_branch?.name_en || t.task_assignments?.[0]?.branches?.name_en || 'N/A',
				assigned_date: t.created_at,
				deadline: t.due_datetime,
				assigned_by_name: t.task_assignments?.[0]?.assigner?.username || t.task_assignments?.[0]?.assigner?.username,
				assigned_to_name: t.task_assignments?.[0]?.assignee?.username || t.task_assignments?.[0]?.assignee?.username
			}));
		}
	}

	async function loadCompletedTasks() {
		// Load from task_completions with branches
		const { data: taskCompletions, error: tcError } = await supabase
			.from('task_completions')
			.select(`
				*,
				task_assignments!inner(
					*,
					tasks(*),
					branches:assigned_to_branch_id(id, name_en),
					assigner:assigned_by(id, username, username),
					assignee:assigned_to_user_id(id, username, username, user_branch:branch_id(id, name_en))
				)
			`);

		if (tcError) console.error('Error loading task completions:', tcError);

		// Load from quick_task_completions with quick_tasks.branches
		const { data: quickCompletions, error: qcError } = await supabase
			.from('quick_task_completions')
			.select(`
				*,
				quick_task_assignments!inner(
					*,
					quick_tasks!inner(
						*, 
						branches:assigned_to_branch_id(id, name_en),
						assigner:assigned_by(id, username)
					),
					assignee:assigned_to_user_id(id, username, user_branch:branch_id(id, name_en))
				)
			`);

		if (qcError) console.error('Error loading quick completions:', qcError);

		if (taskCompletions) {
			tasks = [...tasks, ...taskCompletions.map(tc => ({
				...tc,
				task_title: tc.task_assignments?.tasks?.title || 'N/A',
				task_description: tc.task_assignments?.tasks?.description || '',
				task_type: 'regular',
				branch_name: tc.task_assignments?.assignee?.user_branch?.name_en || tc.task_assignments?.branches?.name_en || 'N/A',
				branch_id: tc.task_assignments?.assignee?.user_branch?.id || tc.task_assignments?.assigned_to_branch_id,
				assigned_date: tc.task_assignments?.assigned_at,
				deadline: tc.task_assignments?.deadline_datetime || tc.task_assignments?.deadline_date,
				status: tc.task_assignments?.status || 'completed',
				completed_date: tc.completed_at,
				completed_by: tc.completed_by,
				assigned_by_name: tc.task_assignments?.assigner?.username || tc.task_assignments?.assigner?.username,
				assigned_to_name: tc.task_assignments?.assignee?.username || tc.task_assignments?.assignee?.username
			}))];
		}

		if (quickCompletions) {
			tasks = [...tasks, ...quickCompletions.map(qc => ({
				...qc,
				task_title: qc.quick_task_assignments?.quick_tasks?.title || 'N/A',
				task_description: qc.quick_task_assignments?.quick_tasks?.description || '',
				task_type: 'quick',
				branch_name: qc.quick_task_assignments?.assignee?.user_branch?.name_en || qc.quick_task_assignments?.quick_tasks?.branches?.name_en || 'N/A',
				branch_id: qc.quick_task_assignments?.assignee?.user_branch?.id || qc.quick_task_assignments?.quick_tasks?.assigned_to_branch_id,
				assigned_date: qc.quick_task_assignments?.quick_tasks?.created_at,
				deadline: qc.quick_task_assignments?.quick_tasks?.deadline_datetime,
				status: qc.quick_task_assignments?.status || 'completed',
				completed_date: qc.created_at,
				completed_by: qc.completed_by_user_id,
				assigned_by_name: qc.quick_task_assignments?.quick_tasks?.assigner?.username,
				assigned_to_name: qc.quick_task_assignments?.assignee?.username,
				price_tag: qc.quick_task_assignments?.quick_tasks?.price_tag,
				issue_type: qc.quick_task_assignments?.quick_tasks?.issue_type
			}))];
		}
	}

	async function loadIncompleteTasks() {
		// Load tasks that DON'T have completion records at all
		// This matches the count calculation: total_tasks - completed_tasks
		// where completed_tasks = count of task_completions + quick_task_completions
		
		// Get ALL completion assignment IDs (tasks that have ANY completion record)
		let allTaskCompletionIds: any[] = [];
		let from = 0;
		const chunkSize = 1000;
		
		while (true) {
			const { data: completions, error } = await supabase
				.from('task_completions')
				.select('assignment_id')
				.range(from, from + chunkSize - 1);
			
			if (error) {
				console.error('Error loading task completions:', error);
				break;
			}
			
			if (!completions || completions.length === 0) break;
			allTaskCompletionIds = allTaskCompletionIds.concat(completions.map(c => c.assignment_id));
			if (completions.length < chunkSize) break;
			from += chunkSize;
		}
		
		// Get ALL quick_task_completion assignment IDs
		let allQuickCompletionIds: any[] = [];
		from = 0;
		
		while (true) {
			const { data: completions, error } = await supabase
				.from('quick_task_completions')
				.select('assignment_id')
				.range(from, from + chunkSize - 1);
			
			if (error) {
				console.error('Error loading quick task completions:', error);
				break;
			}
			
			if (!completions || completions.length === 0) break;
			allQuickCompletionIds = allQuickCompletionIds.concat(completions.map(c => c.assignment_id));
			if (completions.length < chunkSize) break;
			from += chunkSize;
		}

		// Create sets for fast lookup
		const hasCompletionRecord = new Set(allTaskCompletionIds);
		const hasQuickCompletionRecord = new Set(allQuickCompletionIds);

		// Load ALL task_assignments
		const { data: taskAssignments, error: taError } = await supabase
			.from('task_assignments')
			.select(`
				*,
				tasks(*),
				branches:assigned_to_branch_id(id, name_en),
				assigner:assigned_by(id, username),
				assignee:assigned_to_user_id(id, username, user_branch:branch_id(id, name_en))
			`);

		if (taError) console.error('Error loading task_assignments:', taError);

		// Load ALL quick_task_assignments
		const { data: quickAssignments, error: qaError } = await supabase
			.from('quick_task_assignments')
			.select(`
				*,
				quick_tasks!inner(
					*,
					branches:assigned_to_branch_id(id, name_en),
					assigner:assigned_by(id, username)
				),
				assignee:assigned_to_user_id(id, username, user_branch:branch_id(id, name_en))
			`);

		if (qaError) console.error('Error loading quick_task_assignments:', qaError);

		// Filter: assignments that DON'T have any completion record
		if (taskAssignments) {
			const incompleteTasks = taskAssignments.filter(ta => 
				!hasCompletionRecord.has(ta.id) && ta.status !== 'completed'
			);
			
			tasks = [...tasks, ...incompleteTasks.map(ta => ({
				...ta,
				assignment_id: ta.id,  // Preserve the assignment ID
				task_title: ta.tasks?.title || 'N/A',
				task_description: ta.tasks?.description || '',
				task_type: 'regular',
				branch_name: ta.assignee?.user_branch?.name_en || ta.branches?.name_en || 'N/A',
				branch_id: ta.assignee?.user_branch?.id || ta.assigned_to_branch_id,
				assigned_date: ta.assigned_at,
				deadline: ta.deadline_datetime || ta.deadline_date,
				assigned_by_name: ta.assigner?.username,
				assigned_to_name: ta.assignee?.username
			}))];
		}

		if (quickAssignments) {
			const incompleteQuick = quickAssignments.filter(qa => 
				!hasQuickCompletionRecord.has(qa.id) && qa.status !== 'completed'
			);
			
			tasks = [...tasks, ...incompleteQuick.map(qa => ({
				...qa,
				quick_assignment_id: qa.id,  // Preserve the quick assignment ID
				task_title: qa.quick_tasks?.title || 'N/A',
				task_description: qa.quick_tasks?.description || '',
				task_type: 'quick',
				branch_name: qa.assignee?.user_branch?.name_en || qa.quick_tasks?.branches?.name_en || 'N/A',
				branch_id: qa.assignee?.user_branch?.id || qa.quick_tasks?.assigned_to_branch_id,
				assigned_date: qa.quick_tasks?.created_at,
				deadline: qa.quick_tasks?.deadline_datetime,
				assigned_by_name: qa.quick_tasks?.assigner?.username,
				assigned_to_name: qa.assignee?.username,
				price_tag: qa.quick_tasks?.price_tag,
				issue_type: qa.quick_tasks?.issue_type
			}))];
		}

		// Load incomplete receiving tasks (not completed)
		const { data: receivingTasks, error: rtError } = await supabase
			.from('receiving_tasks')
			.select(`
				*,
				receiving_record:receiving_record_id(
					id,
					user_id,
					branch:branch_id(id, name_en)
				)
			`)
			.neq('task_status', 'completed')
			.eq('task_completed', false);

		if (rtError) {
			console.error('Error loading incomplete receiving_tasks:', rtError);
		} else {
			if (receivingTasks && receivingTasks.length > 0) {
				// Get unique user IDs (both creators and assigned users)
				const creatorUserIds = [...new Set(receivingTasks.map(rt => rt.receiving_record?.user_id).filter(Boolean))];
				const assignedUserIds = [...new Set(receivingTasks.map(rt => rt.assigned_user_id).filter(Boolean))];
				const allUserIds = [...new Set([...creatorUserIds, ...assignedUserIds])];
				
				// Fetch user information for all users with IDs
				let userMap = new Map();
				if (allUserIds.length > 0) {
					const { data: users, error: usersError } = await supabase
						.from('users')
						.select('id, username')
						.in('id', allUserIds);
					
					if (usersError) {
						console.error('❌ Error fetching users:', usersError);
					}
					
					if (users) {
						users.forEach(user => userMap.set(user.id, user.username));
					}
				}
				
				// For tasks with null assigned_user_id, skip user lookup since all users are 'branch_specific'
				console.log('ℹ️ Skipping user lookup for receiving tasks - using role names directly');
				
				const incompleteReceivingTasks = receivingTasks.map(rt => {
					const branchId = rt.receiving_record?.branch?.id;
					let assignedToUsername;
					
					if (rt.assigned_user_id) {
						// Use direct user ID mapping
						assignedToUsername = userMap.get(rt.assigned_user_id);
					} else if (rt.role_type && branchId) {
						// Since users don't have specific role types, format the role name nicely
						assignedToUsername = rt.role_type
							.split('_')
							.map(word => word.charAt(0).toUpperCase() + word.slice(1))
							.join(' ');
					}
					
					// Fallback to role_type if no username found
					assignedToUsername = assignedToUsername || rt.role_type || 'Unassigned';
					
					return {
						...rt,
						receiving_task_id: rt.id,  // Preserve the receiving task ID
						task_title: `📦 ${rt.title || `Receiving Task #${rt.id.slice(-8)}`}`,
						task_description: rt.description || 'Receiving task for inventory management',
						task_type: 'receiving',
						branch_name: rt.receiving_record?.branch?.name_en || 'No Branch',
						branch_id: branchId || null,
						assigned_date: rt.created_at,
						deadline: rt.due_date,
						assigned_by_name: userMap.get(rt.receiving_record?.user_id) || 'System',
						assigned_to_name: assignedToUsername,
						role_type: rt.role_type,
						task_status: rt.task_status,
						priority: rt.priority
					};
				});
				
				tasks = [...tasks, ...incompleteReceivingTasks];
			}
		}
	}

	async function loadMyAssignedTasks(user: any) {
		// Load from task_assignments with branches
		const { data: myTaskAssignments, error: taError } = await supabase
			.from('task_assignments')
			.select(`
				*,
				tasks(*),
				branches:assigned_to_branch_id(id, name_en),
				assigner:assigned_by(id, username, username),
				assignee:assigned_to_user_id(id, username, username, user_branch:branch_id(id, name_en))
			`)
			.eq('assigned_to_user_id', user.id)
			.in('status', ['assigned', 'in_progress', 'pending']);

		if (taError) console.error('Error loading my task_assignments:', taError);

		// Load from quick_task_assignments with quick_tasks.branches
		const { data: myQuickAssignments, error: qaError } = await supabase
			.from('quick_task_assignments')
			.select(`
				*,
				quick_tasks!inner(
					*, 
					branches:assigned_to_branch_id(id, name_en),
					assigner:assigned_by(id, username)
				),
				assignee:assigned_to_user_id(id, username)
			`)
			.eq('assigned_to_user_id', user.id)
			.eq('status', 'pending');

		if (qaError) console.error('Error loading my quick_task_assignments:', qaError);

		if (myTaskAssignments) {
			tasks = [...tasks, ...myTaskAssignments.map(ta => ({
				...ta,
				task_title: ta.tasks?.title || 'N/A',
				task_description: ta.tasks?.description || '',
				task_type: 'regular',
				branch_name: ta.assignee?.user_branch?.name_en || ta.branches?.name_en || 'N/A',
				branch_id: ta.assignee?.user_branch?.id || ta.assigned_to_branch_id,
				assigned_date: ta.assigned_at,
				deadline: ta.deadline_datetime || ta.deadline_date,
				status: ta.status,
				assigned_by_name: ta.assigner?.username || ta.assigner?.username,
				assigned_to_name: ta.assignee?.username || ta.assignee?.username
			}))];
		}

		if (myQuickAssignments) {
			tasks = [...tasks, ...myQuickAssignments.map(qa => ({
				...qa,
				task_title: qa.quick_tasks?.title || 'N/A',
				task_description: qa.quick_tasks?.description || '',
				task_type: 'quick',
				branch_name: qa.assignee?.user_branch?.name_en || qa.quick_tasks?.branches?.name_en || 'N/A',
				branch_id: qa.assignee?.user_branch?.id || qa.quick_tasks?.assigned_to_branch_id,
				assigned_date: qa.quick_tasks?.created_at,
				deadline: qa.quick_tasks?.deadline_datetime,
				status: qa.status,
				assigned_by_name: qa.quick_tasks?.assigner?.username,
				assigned_to_name: qa.assignee?.username || qa.assignee?.username,
				price_tag: qa.quick_tasks?.price_tag,
				issue_type: qa.quick_tasks?.issue_type
			}))];
		}
	}

	async function loadMyCompletedTasks(user: any) {
		// Load from task_completions with branches
		const { data: myTaskCompletions, error: tcError } = await supabase
			.from('task_completions')
			.select(`
				*,
				task_assignments!inner(
					*,
					tasks(*),
					branches:assigned_to_branch_id(id, name_en),
					assigner:assigned_by(id, username, username),
					assignee:assigned_to_user_id(id, username, username, user_branch:branch_id(id, name_en))
				)
			`)
			.eq('completed_by', user.id);

		if (tcError) console.error('Error loading my task completions:', tcError);

		// Load from quick_task_completions with quick_tasks.branches
		const { data: myQuickCompletions, error: qcError } = await supabase
			.from('quick_task_completions')
			.select(`
				*,
				quick_task_assignments!inner(
					*,
					quick_tasks!inner(
						*, 
						branches:assigned_to_branch_id(id, name_en),
						assigner:assigned_by(id, username)
					),
					assignee:assigned_to_user_id(id, username, user_branch:branch_id(id, name_en))
				)
			`)
			.eq('completed_by_user_id', user.id);

		if (qcError) console.error('Error loading my quick completions:', qcError);

		if (myTaskCompletions) {
			tasks = [...tasks, ...myTaskCompletions.map(tc => ({
				...tc,
				task_title: tc.task_assignments?.tasks?.title || 'N/A',
				task_description: tc.task_assignments?.tasks?.description || '',
				task_type: 'regular',
				branch_name: tc.task_assignments?.assignee?.user_branch?.name_en || tc.task_assignments?.branches?.name_en || 'N/A',
				branch_id: tc.task_assignments?.assignee?.user_branch?.id || tc.task_assignments?.assigned_to_branch_id,
				assigned_date: tc.task_assignments?.assigned_at,
				deadline: tc.task_assignments?.deadline_datetime || tc.task_assignments?.deadline_date,
				status: tc.task_assignments?.status || 'completed',
				completed_date: tc.completed_at,
				assigned_by_name: tc.task_assignments?.assigner?.username || tc.task_assignments?.assigner?.username,
				assigned_to_name: tc.task_assignments?.assignee?.username || tc.task_assignments?.assignee?.username
			}))];
		}

		if (myQuickCompletions) {
			tasks = [...tasks, ...myQuickCompletions.map(qc => ({
				...qc,
				task_title: qc.quick_task_assignments?.quick_tasks?.title || 'N/A',
				task_description: qc.quick_task_assignments?.quick_tasks?.description || '',
				task_type: 'quick',
				branch_name: qc.quick_task_assignments?.assignee?.user_branch?.name_en || qc.quick_task_assignments?.quick_tasks?.branches?.name_en || 'N/A',
				branch_id: qc.quick_task_assignments?.assignee?.user_branch?.id || qc.quick_task_assignments?.quick_tasks?.assigned_to_branch_id,
				assigned_date: qc.quick_task_assignments?.quick_tasks?.created_at,
				deadline: qc.quick_task_assignments?.quick_tasks?.deadline_datetime,
				status: qc.quick_task_assignments?.status || 'completed',
				completed_date: qc.created_at,
				assigned_by_name: qc.quick_task_assignments?.quick_tasks?.assigner?.username,
				assigned_to_name: qc.quick_task_assignments?.assignee?.username,
				price_tag: qc.quick_task_assignments?.quick_tasks?.price_tag,
				issue_type: qc.quick_task_assignments?.quick_tasks?.issue_type
			}))];
		}
	}

	async function loadMyAssignments(user: any) {
		// Load from task_assignments with branches
		const { data: myTaskAssignments, error: taError } = await supabase
			.from('task_assignments')
			.select(`
				*,
				tasks(*),
				branches:assigned_to_branch_id(id, name_en),
				assigner:assigned_by(id, username, username),
				assignee:assigned_to_user_id(id, username, username, user_branch:branch_id(id, name_en))
			`)
			.eq('assigned_by', user.id);

		if (taError) console.error('Error loading my task assignments:', taError);

		// Load from quick_task_assignments with quick_tasks.branches
		const { data: myQuickAssignments, error: qaError } = await supabase
			.from('quick_task_assignments')
			.select(`
				*,
				quick_tasks!inner(
					*, 
					branches:assigned_to_branch_id(id, name_en),
					assigner:assigned_by(id, username)
				),
				assignee:assigned_to_user_id(id, username, user_branch:branch_id(id, name_en))
			`)
			.eq('quick_tasks.assigned_by', user.id);

		if (qaError) console.error('Error loading my quick assignments:', qaError);

		if (myTaskAssignments) {
			tasks = [...tasks, ...myTaskAssignments.map(ta => ({
				...ta,
				task_title: ta.tasks?.title || 'N/A',
				task_description: ta.tasks?.description || '',
				task_type: 'regular',
				branch_name: ta.assignee?.user_branch?.name_en || ta.branches?.name_en || 'N/A',
				branch_id: ta.assignee?.user_branch?.id || ta.assigned_to_branch_id,
				assigned_date: ta.assigned_at,
				deadline: ta.deadline_datetime || ta.deadline_date,
				assigned_to: ta.assigned_to_user_id,
				assigned_by_name: ta.assigner?.username || ta.assigner?.username,
				assigned_to_name: ta.assignee?.username || ta.assignee?.username
			}))];
		}

		if (myQuickAssignments) {
			tasks = [...tasks, ...myQuickAssignments.map(qa => ({
				...qa,
				task_title: qa.quick_tasks?.title || 'N/A',
				task_description: qa.quick_tasks?.description || '',
				task_type: 'quick',
				branch_name: qa.assignee?.user_branch?.name_en || qa.quick_tasks?.branches?.name_en || 'N/A',
				branch_id: qa.assignee?.user_branch?.id || qa.quick_tasks?.assigned_to_branch_id,
				assigned_date: qa.quick_tasks?.created_at,
				deadline: qa.quick_tasks?.deadline_datetime,
				assigned_to: qa.assigned_to_user_id,
				assigned_by_name: qa.quick_tasks?.assigner?.username,
				assigned_to_name: qa.assignee?.username,
				price_tag: qa.quick_tasks?.price_tag,
				issue_type: qa.quick_tasks?.issue_type
			}))];
		}
	}

	async function loadMyAssignmentsCompleted(user: any) {
		// Load from task_completions with branches
		const { data: myTaskAssignmentsCompleted, error: tcError } = await supabase
			.from('task_completions')
			.select(`
				*,
				task_assignments!inner(
					*,
					tasks(*),
					branches:assigned_to_branch_id(id, name_en),
					assigner:assigned_by(id, username, username),
					assignee:assigned_to_user_id(id, username, username, user_branch:branch_id(id, name_en))
				)
			`)
			.eq('task_assignments.assigned_by', user.id);

		if (tcError) console.error('Error loading my task completions:', tcError);

		// Load from quick_task_completions with quick_tasks.branches
		const { data: myQuickAssignmentsCompleted, error: qcError } = await supabase
			.from('quick_task_completions')
			.select(`
				*,
				quick_task_assignments!inner(
					*,
					quick_tasks!inner(
						*, 
						branches:assigned_to_branch_id(id, name_en),
						assigner:assigned_by(id, username)
					),
					assignee:assigned_to_user_id(id, username)
				)
			`)
			.eq('quick_task_assignments.quick_tasks.assigned_by', user.id);

		if (qcError) console.error('Error loading my quick completions:', qcError);

		if (myTaskAssignmentsCompleted) {
			tasks = [...tasks, ...myTaskAssignmentsCompleted.map(tc => ({
				...tc,
				task_title: tc.task_assignments?.tasks?.title || 'N/A',
				task_description: tc.task_assignments?.tasks?.description || '',
				task_type: 'regular',
				branch_name: tc.task_assignments?.branches?.name_en || 'N/A',
				branch_id: tc.task_assignments?.assigned_to_branch_id,
				assigned_date: tc.task_assignments?.assigned_at,
				deadline: tc.task_assignments?.deadline_datetime || tc.task_assignments?.deadline_date,
				status: tc.task_assignments?.status || 'completed',
				completed_date: tc.completed_at,
				completed_by: tc.completed_by,
				assigned_by_name: tc.task_assignments?.assigner?.username || tc.task_assignments?.assigner?.username,
				assigned_to_name: tc.task_assignments?.assignee?.username || tc.task_assignments?.assignee?.username
			}))];
		}

		if (myQuickAssignmentsCompleted) {
			tasks = [...tasks, ...myQuickAssignmentsCompleted.map(qc => ({
				...qc,
				task_title: qc.quick_task_assignments?.quick_tasks?.title || 'N/A',
				task_description: qc.quick_task_assignments?.quick_tasks?.description || '',
				task_type: 'quick',
				branch_name: qc.quick_task_assignments?.quick_tasks?.branches?.name_en || 'N/A',
				branch_id: qc.quick_task_assignments?.quick_tasks?.assigned_to_branch_id,
				assigned_date: qc.quick_task_assignments?.quick_tasks?.created_at,
				deadline: qc.quick_task_assignments?.quick_tasks?.deadline_datetime,
				status: qc.quick_task_assignments?.status || 'completed',
				completed_date: qc.created_at,
				completed_by: qc.completed_by_user_id,
				assigned_by_name: qc.quick_task_assignments?.quick_tasks?.assigner?.username,
				assigned_to_name: qc.quick_task_assignments?.assignee?.username,
				price_tag: qc.quick_task_assignments?.quick_tasks?.price_tag,
				issue_type: qc.quick_task_assignments?.quick_tasks?.issue_type
			}))];
		}
	}

	function applyFilters() {
		console.log('🔍 Applying filters to', tasks.length, 'tasks');
		console.log('🔍 Filters:', { searchQuery, selectedBranch, selectedUser, dateFilter });
		
		filteredTasks = tasks.filter(task => {
			// Search filter
			if (searchQuery) {
				const search = searchQuery.toLowerCase();
				const matchesSearch = 
					task.task_title?.toLowerCase().includes(search) ||
					task.task_description?.toLowerCase().includes(search) ||
					task.branch_name?.toLowerCase().includes(search);
				if (!matchesSearch) return false;
			}

			// Branch filter
			if (selectedBranch && task.branch_id !== selectedBranch) {
				return false;
			}

			// User filter
			if (selectedUser) {
				const matchesUser = 
					task.assigned_to_user_id === selectedUser ||
					task.assigned_to === selectedUser ||
					task.completed_by === selectedUser ||
					task.completed_by_user_id === selectedUser;
				if (!matchesUser) return false;
			}

			// Date filter
			if (dateFilter !== 'all') {
				const taskDate = new Date(task.assigned_date || task.completed_date);
				const today = new Date();
				today.setHours(0, 0, 0, 0);

				if (dateFilter === 'today') {
					const taskDateOnly = new Date(taskDate);
					taskDateOnly.setHours(0, 0, 0, 0);
					if (taskDateOnly.getTime() !== today.getTime()) return false;
				} else if (dateFilter === 'yesterday') {
					const yesterday = new Date(today);
					yesterday.setDate(yesterday.getDate() - 1);
					const taskDateOnly = new Date(taskDate);
					taskDateOnly.setHours(0, 0, 0, 0);
					if (taskDateOnly.getTime() !== yesterday.getTime()) return false;
				} else if (dateFilter === 'custom') {
					if (customDateFrom) {
						const fromDate = new Date(customDateFrom);
						if (taskDate < fromDate) return false;
					}
					if (customDateTo) {
						const toDate = new Date(customDateTo);
						toDate.setHours(23, 59, 59, 999);
						if (taskDate > toDate) return false;
					}
				}
			}

			return true;
		});

		console.log('✅ Filtered tasks result:', filteredTasks.length, 'out of', tasks.length);

		// Sort by completion status first, then by deadline for overdue prioritization
		filteredTasks.sort((a, b) => {
			// Determine completion status for each task
			const isCompletedViewA = cardType === 'completed_tasks' || cardType === 'my_completed_tasks' || cardType === 'my_assignments_completed';
			const isReceivingTaskCompletedA = a.task_type === 'receiving' && a.task_completed === true;
			const taskStatusA = isCompletedViewA || isReceivingTaskCompletedA ? 'completed' : 'incomplete';
			
			const isCompletedViewB = cardType === 'completed_tasks' || cardType === 'my_completed_tasks' || cardType === 'my_assignments_completed';
			const isReceivingTaskCompletedB = b.task_type === 'receiving' && b.task_completed === true;
			const taskStatusB = isCompletedViewB || isReceivingTaskCompletedB ? 'completed' : 'incomplete';
			
			// First priority: completed tasks go to bottom
			if (taskStatusA !== taskStatusB) {
				return taskStatusA === 'completed' ? 1 : -1; // incomplete first, completed last
			}
			
			// Second priority: for incomplete tasks, sort by deadline (most overdue first)
			if (taskStatusA === 'incomplete') {
				const deadlineA = a.deadline ? new Date(a.deadline).getTime() : Number.MAX_SAFE_INTEGER;
				const deadlineB = b.deadline ? new Date(b.deadline).getTime() : Number.MAX_SAFE_INTEGER;
				return deadlineA - deadlineB; // Ascending order - earliest (most overdue) first
			}
			
			// For completed tasks, maintain original order or sort by completion date if available
			return 0;
		});
	}

	function handleSearch() {
		applyFilters();
	}

	function handleFilterChange() {
		applyFilters();
	}

	function formatDate(dateString: string) {
		if (!dateString) return 'N/A';
		const date = new Date(dateString);
		return date.toLocaleString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getDueStatus(deadline: string) {
		if (!deadline) return { text: 'No Deadline', days: null, class: 'status-no-deadline' };
		
		const now = new Date();
		const dueDate = new Date(deadline);
		
		// Calculate difference in milliseconds
		const diffTime = dueDate.getTime() - now.getTime();
		const diffHours = diffTime / (1000 * 60 * 60);
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		
		// If already past deadline (negative time difference)
		if (diffTime < 0) {
			const overdueDays = Math.abs(diffDays);
			const overdueHours = Math.abs(Math.floor(diffHours));
			
			if (overdueDays === 0 || overdueHours < 24) {
				if (overdueHours < 1) {
					return { 
						text: `&lt;1h overdue`, 
						days: diffDays, 
						class: 'status-overdue' 
					};
				} else {
					return { 
						text: `${overdueHours}h overdue`, 
						days: diffDays, 
						class: 'status-overdue' 
					};
				}
			} else {
				const remainingHours = overdueHours % 24;
				return { 
					text: remainingHours > 0 ? `${overdueDays}d ${remainingHours}h overdue` : `${overdueDays}d overdue`, 
					days: diffDays, 
					class: 'status-overdue' 
				};
			}
		} 
		// Due within next 24 hours
		else if (diffHours <= 24) {
			const hoursRemaining = Math.floor(diffHours);
			if (hoursRemaining < 1) {
				const minutesRemaining = Math.floor((diffTime / (1000 * 60)));
				return { text: `${minutesRemaining} min remaining`, days: 0, class: 'status-safe' };
			} else {
				return { text: `${hoursRemaining} ${hoursRemaining === 1 ? 'hour' : 'hours'} remaining`, days: 0, class: 'status-safe' };
			}
		} 
		// Due tomorrow (24-48 hours)
		else if (diffDays === 1) {
			return { text: 'Due Tomorrow', days: diffDays, class: 'status-safe' };
		} 
		// All other remaining time - green
		else {
			return { text: `${diffDays} days remaining`, days: diffDays, class: 'status-safe' };
		}
	}

	function viewTaskDetails(task: any) {
		selectedTask = task;
		showTaskDetail = true;
	}

	function closeTaskDetail() {
		showTaskDetail = false;
		selectedTask = null;
	}

	// Reminder Functions
	async function loadAutoReminderCount() {
		try {
			// Get total reminders count (both automatic and manual)
			const { count } = await supabase
				.from('notifications')
				.select('*', { count: 'exact', head: true })
				.eq('type', 'task_overdue');
			
			autoReminderCount = count || 0;
			autoReminderStats.totalReminders = count || 0;

			// Get trigger statistics from task_reminder_logs
			const { data: triggerData } = await supabase
				.from('task_reminder_logs')
				.select('created_at')
				.order('created_at', { ascending: false });

			if (triggerData && triggerData.length > 0) {
				// Group by hour to count distinct triggers
				const triggerHours = new Set<string>();
				triggerData.forEach(log => {
					const date = new Date(log.created_at);
					const hourKey = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}-${date.getHours()}`;
					triggerHours.add(hourKey);
				});

				autoReminderStats.totalTriggers = triggerHours.size;
				autoReminderStats.lastTrigger = triggerData[0].created_at;
				autoReminderStats.avgPerTrigger = autoReminderStats.totalTriggers > 0 
					? Math.round(autoReminderStats.totalReminders / autoReminderStats.totalTriggers) 
					: 0;
			}
		} catch (error) {
			console.error('Error loading auto reminder count:', error);
		}
	}

	function toggleTaskSelection(taskId: string) {
		if (selectedTaskIds.has(taskId)) {
			selectedTaskIds.delete(taskId);
		} else {
			selectedTaskIds.add(taskId);
		}
		selectedTaskIds = selectedTaskIds; // Trigger reactivity
		selectedTaskIdsArray = Array.from(selectedTaskIds); // Update array for reactivity
	}

	function selectAllTasks() {
		filteredTasks.forEach(task => {
			const taskId = task.assignment_id || task.quick_assignment_id;
			if (taskId) selectedTaskIds.add(taskId);
		});
		selectedTaskIds = selectedTaskIds;
		selectedTaskIdsArray = Array.from(selectedTaskIds);
	}

	function deselectAllTasks() {
		selectedTaskIds.clear();
		selectedTaskIds = selectedTaskIds;
		selectedTaskIdsArray = [];
	}

	async function sendRemindersToSelected() {
		if (selectedTaskIds.size === 0) {
			alert('Please select at least one task');
			return;
		}

		if (!confirm(`Send reminder for ${selectedTaskIds.size} selected task(s)?`)) {
			return;
		}

		await sendReminders(Array.from(selectedTaskIds));
	}

	async function sendRemindersToAll() {
		if (!confirm('Send automatic reminders for all overdue tasks?')) {
			return;
		}

		isSendingReminders = true;
		reminderStats = { sent: 0, failed: 0 };
		showReminderStats = true;

		try {
			// Call the Edge Function
			const response = await fetch(
				'https://vmypotfsyrvuublyddyt.supabase.co/functions/v1/check-overdue-reminders',
				{
					method: 'POST',
					headers: {
						'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
						'Content-Type': 'application/json'
					}
				}
			);

			if (!response.ok) {
				throw new Error(`Failed to send reminders: ${response.statusText}`);
			}

			const result = await response.json();
			
			if (result.success) {
				reminderStats.sent = result.reminders_sent || 0;
				alert(`✅ ${result.message || `Successfully sent ${result.reminders_sent} reminders`}`);
			} else {
				throw new Error(result.error || 'Failed to send reminders');
			}

			// Refresh reminder count
			await loadAutoReminderCount();

			// Reload tasks to update the reminder status
			await loadTasks();

		} catch (error) {
			console.error('Error sending reminders:', error);
			reminderStats.failed = 1;
			alert(`❌ Error sending reminders: ${error.message}`);
		} finally {
			isSendingReminders = false;
		}
	}

	async function sendReminders(taskIds: string[]) {
		isSendingReminders = true;
		reminderStats = { sent: 0, failed: 0 };
		showReminderStats = true;

		try {
			for (const taskId of taskIds) {
				try {
					const task = tasks.find(t => 
						(t.assignment_id === taskId || t.quick_assignment_id === taskId)
					);

					if (!task) continue;

					// Create notification
					const { error } = await supabase
						.from('notifications')
						.insert({
							title: '⚠️ Task Reminder',
							message: `Reminder: "${task.task_title}" is overdue. Please complete it as soon as possible.`,
							type: 'task_overdue',
							target_users: [task.assigned_to_user_id],
							target_type: 'specific_users',
							status: 'published',
							sent_at: new Date().toISOString(),
							created_by: currentUser?.id || 'system',
							created_by_name: currentUser?.username || 'System',
							created_by_role: currentUser?.role || 'system',
							task_id: task.task_id,
							priority: 'medium',
							read_count: 0,
							total_recipients: 1,
							metadata: {
								task_id: task.task_id,
								assignment_id: taskId,
								task_type: task.task_type,
								deadline: task.deadline,
								reminder_type: 'manual'
							}
						});

					if (error) {
						console.error('Error sending reminder:', error);
						reminderStats.failed++;
					} else {
						reminderStats.sent++;
					}
				} catch (error) {
					console.error('Error processing task:', error);
					reminderStats.failed++;
				}
			}

			// Refresh reminder count
			await loadAutoReminderCount();

			// Clear selection
			selectedTaskIds.clear();
			selectedTaskIds = selectedTaskIds;

		} catch (error) {
			console.error('Error sending reminders:', error);
		} finally {
			isSendingReminders = false;
		}
	}

	function closeReminderStats() {
		showReminderStats = false;
		reminderStats = { sent: 0, failed: 0 };
	}

</script>

<div class="task-details-view">
	{#if cardType === 'incomplete_tasks'}
		<div class="auto-reminder-stats">
			<div class="stats-grid">
				<div class="stat-card">
					<div class="stat-icon">
						<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
							<path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z"/>
						</svg>
					</div>
					<div class="stat-content">
						<div class="stat-value">{autoReminderStats.totalReminders}</div>
						<div class="stat-label">Total Reminders</div>
					</div>
				</div>

				<div class="stat-card">
					<div class="stat-icon">
						<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
							<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"/>
						</svg>
					</div>
					<div class="stat-content">
						<div class="stat-value">{autoReminderStats.totalTriggers}</div>
						<div class="stat-label">Auto Triggers</div>
					</div>
				</div>

				<div class="stat-card">
					<div class="stat-icon">
						<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
							<path fill-rule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clip-rule="evenodd"/>
						</svg>
					</div>
					<div class="stat-content">
						<div class="stat-value">
							{#if autoReminderStats.lastTrigger}
								{new Date(autoReminderStats.lastTrigger).toLocaleString()}
							{:else}
								-
							{/if}
						</div>
						<div class="stat-label">Last Trigger</div>
					</div>
				</div>

				<div class="stat-card">
					<div class="stat-icon">
						<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
							<path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5zM8 7a1 1 0 011-1h2a1 1 0 011 1v9a1 1 0 01-1 1H9a1 1 0 01-1-1V7zM14 4a1 1 0 011-1h2a1 1 0 011 1v12a1 1 0 01-1 1h-2a1 1 0 01-1-1V4z"/>
						</svg>
					</div>
					<div class="stat-content">
						<div class="stat-value">{autoReminderStats.avgPerTrigger}</div>
						<div class="stat-label">Avg per Trigger</div>
					</div>
				</div>
			</div>
		</div>
	{/if}

	{#if cardType === 'incomplete_tasks'}
		<div class="reminder-controls">
			<div class="selection-controls">
				<button class="btn-select" on:click={selectAllTasks} disabled={isSendingReminders}>
					<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
					</svg>
					Select All
				</button>
				<button class="btn-deselect" on:click={deselectAllTasks} disabled={isSendingReminders || selectedTaskIds.size === 0}>
					<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/>
					</svg>
					Deselect All
				</button>
				{#if selectedTaskIds.size > 0}
					<span class="selected-count">{selectedTaskIds.size} selected</span>
				{/if}
			</div>
			
			<div class="reminder-buttons">
				<button 
					class="btn-remind-selected" 
					on:click={sendRemindersToSelected}
					disabled={isSendingReminders || selectedTaskIds.size === 0}
				>
					{#if isSendingReminders}
						<svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Sending...
					{:else}
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
						</svg>
						Send to Selected ({selectedTaskIds.size})
					{/if}
				</button>

				<button 
					class="btn-remind-all" 
					on:click={sendRemindersToAll}
					disabled={isSendingReminders}
				>
					<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
					</svg>
					Send to All Overdue
				</button>
			</div>
		</div>
	{/if}

	<div class="filters-section">
		<div class="search-box">
			<svg class="search-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
			</svg>
			<input
				type="text"
				class="search-input"
				placeholder="Search tasks..."
				bind:value={searchQuery}
				on:input={handleSearch}
			/>
		</div>

		<div class="filters-grid">
			<select class="filter-select" bind:value={selectedBranch} on:change={handleFilterChange}>
				<option value="">All Branches</option>
				{#each branches as branch}
					<option value={branch.id}>{branch.name_en}</option>
				{/each}
			</select>

			<select class="filter-select" bind:value={selectedUser} on:change={handleFilterChange}>
				<option value="">All Users</option>
				{#each usersWithTasks as user}
					<option value={user.id}>{user.username} - {user.username || ''}</option>
				{/each}
			</select>

			<select class="filter-select" bind:value={dateFilter} on:change={handleFilterChange}>
				<option value="all">All Dates</option>
				<option value="today">Today</option>
				<option value="yesterday">Yesterday</option>
				<option value="custom">Custom Range</option>
			</select>

			{#if dateFilter === 'custom'}
				<input
					type="date"
					class="date-input"
					bind:value={customDateFrom}
					on:change={handleFilterChange}
					placeholder="From"
				/>
				<input
					type="date"
					class="date-input"
					bind:value={customDateTo}
					on:change={handleFilterChange}
					placeholder="To"
				/>
			{/if}
		</div>
	</div>

	<div class="results-info">
		<p>Showing {filteredTasks.length} of {tasks.length} tasks</p>
	</div>

	<div class="table-container">
		{#if isLoading}
			<div class="loading">Loading tasks...</div>
		{:else if filteredTasks.length === 0}
			<div class="no-data">No tasks found</div>
		{:else}
			<table class="tasks-table">
				<thead>
					<tr>
						{#if cardType === 'incomplete_tasks'}
							<th class="checkbox-col">Select</th>
						{/if}
						<th>Task Title</th>
						<th>Type</th>
						<th>Branch</th>
						<th>Assigned By</th>
						<th>Assigned To</th>
						<th>Assigned Date</th>
						<th>Deadline</th>
						<th>Due Status</th>
						<th>Status</th>
						{#if cardType === 'completed_tasks' || cardType === 'my_completed_tasks' || cardType === 'my_assignments_completed'}
							<th>Completed Date</th>
						{/if}
					</tr>
				</thead>
				<tbody>
					{#each filteredTasks as task, index (`${task.assignment_id || task.quick_assignment_id || index}-${task.task_type}-${index}`)}
						{@const taskId = task.assignment_id || task.quick_assignment_id}
						{@const isCompletedView = cardType === 'completed_tasks' || cardType === 'my_completed_tasks' || cardType === 'my_assignments_completed'}
						{@const isReceivingTaskCompleted = task.task_type === 'receiving' && task.task_completed === true}
						{@const taskStatus = isCompletedView || isReceivingTaskCompleted ? 'completed' : (task.status || 'pending')}
						<tr class="clickable-row">
							{#if cardType === 'incomplete_tasks'}
								<td class="checkbox-col" on:click|stopPropagation>
									<input 
										type="checkbox" 
										class="task-checkbox"
										id="checkbox-{taskId}"
										value={taskId}
										checked={selectedTaskIdsArray.includes(taskId)}
										on:click|stopPropagation
										on:change={() => toggleTaskSelection(taskId)}
									/>
								</td>
							{/if}
							<td on:click={() => viewTaskDetails(task)}>
								<div class="task-title-cell">
									<strong>{task.task_title}</strong>
									{#if task.task_description}
										<span class="task-desc">{task.task_description.substring(0, 80)}{task.task_description.length > 80 ? '...' : ''}</span>
									{/if}
								</div>
							</td>
							<td on:click={() => viewTaskDetails(task)}>
								<span class="badge {task.task_type === 'quick' ? 'badge-quick' : task.task_type === 'receiving' ? 'badge-receiving' : 'badge-regular'}">
									{task.task_type === 'quick' ? 'Quick' : task.task_type === 'receiving' ? 'Receiving' : 'Regular'}
								</span>
							</td>
							<td on:click={() => viewTaskDetails(task)}>{task.branch_name}</td>
							<td on:click={() => viewTaskDetails(task)}>{task.assigned_by_name || task.assigned_by || 'N/A'}</td>
							<td on:click={() => viewTaskDetails(task)}>{task.assigned_to_name || task.assigned_to || 'N/A'}</td>
							<td on:click={() => viewTaskDetails(task)}>{formatDate(task.assigned_date)}</td>
							<td on:click={() => viewTaskDetails(task)}>{formatDate(task.deadline)}</td>
							<td on:click={() => viewTaskDetails(task)}>
								{#if taskStatus === 'completed'}
									<span class="due-status-badge status-completed">Completed</span>
								{:else if task.deadline}
									{@const dueStatus = getDueStatus(task.deadline)}
									<span class="due-status-badge {dueStatus.class}">
										{dueStatus.text}
									</span>
								{:else}
									<span class="due-status-badge status-no-deadline">No Deadline</span>
								{/if}
							</td>
							<td on:click={() => viewTaskDetails(task)}>
								<span class="badge badge-{taskStatus}">
									{taskStatus.charAt(0).toUpperCase() + taskStatus.slice(1)}
								</span>
							</td>
							{#if cardType === 'completed_tasks' || cardType === 'my_completed_tasks' || cardType === 'my_assignments_completed'}
								<td on:click={() => viewTaskDetails(task)}>{formatDate(task.completed_date)}</td>
							{/if}
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
</div>

{#if showTaskDetail && selectedTask}
	<div class="task-detail-modal" on:click={closeTaskDetail}>
		<div class="task-detail-content" on:click|stopPropagation>
			<div class="detail-header">
				<h3>{selectedTask.task_title}</h3>
				<button class="close-btn" on:click={closeTaskDetail}>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
					</svg>
				</button>
			</div>
			<div class="detail-body">
				<div class="detail-section">
					<label>Description:</label>
					<p>{selectedTask.task_description || 'No description provided'}</p>
				</div>
				
				<div class="detail-grid">
					<div class="detail-item">
						<label>Type:</label>
						<span class="badge {selectedTask.task_type === 'quick' ? 'badge-quick' : selectedTask.task_type === 'receiving' ? 'badge-receiving' : 'badge-regular'}">
							{selectedTask.task_type === 'quick' ? 'Quick Task' : selectedTask.task_type === 'receiving' ? 'Receiving Task' : 'Regular Task'}
						</span>
					</div>
					
					<div class="detail-item">
						<label>Status:</label>
						<span class="badge badge-{selectedTask.status || 'pending'}">
							{selectedTask.status || 'Pending'}
						</span>
					</div>
					
					<div class="detail-item">
						<label>Branch:</label>
						<p>{selectedTask.branch_name || 'N/A'}</p>
					</div>
					
					<div class="detail-item">
						<label>Assigned By:</label>
						<p>{selectedTask.assigned_by_name || selectedTask.assigned_by || 'N/A'}</p>
					</div>
					
					<div class="detail-item">
						<label>Assigned To:</label>
						<p>{selectedTask.assigned_to_name || selectedTask.assigned_to || 'N/A'}</p>
					</div>
					
					<div class="detail-item">
						<label>Assigned Date:</label>
						<p>{formatDate(selectedTask.assigned_date)}</p>
					</div>
					
					<div class="detail-item">
						<label>Deadline:</label>
						<p>{formatDate(selectedTask.deadline)}</p>
					</div>
					
					{#if selectedTask.completed_date}
						<div class="detail-item">
							<label>Completed Date:</label>
							<p>{formatDate(selectedTask.completed_date)}</p>
						</div>
					{/if}

					{#if selectedTask.task_type === 'quick' && selectedTask.price_tag}
						<div class="detail-item">
							<label>Price Tag:</label>
							<span class="badge badge-info">{selectedTask.price_tag}</span>
						</div>
					{/if}

					{#if selectedTask.task_type === 'quick' && selectedTask.issue_type}
						<div class="detail-item">
							<label>Issue Type:</label>
							<span class="badge badge-warning">{selectedTask.issue_type}</span>
						</div>
					{/if}
				</div>
			</div>
		</div>
	</div>
{/if}

{#if showReminderStats}
	<div class="reminder-stats-modal" on:click={closeReminderStats}>
		<div class="reminder-stats-content" on:click|stopPropagation>
			<div class="stats-header">
				<h3>Reminder Results</h3>
				<button class="close-btn" on:click={closeReminderStats}>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
					</svg>
				</button>
			</div>
			<div class="stats-body">
				<div class="stat-card success">
					<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
					</svg>
					<h4>{reminderStats.sent}</h4>
					<p>Reminders Sent</p>
				</div>
				{#if reminderStats.failed > 0}
					<div class="stat-card error">
						<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/>
						</svg>
						<h4>{reminderStats.failed}</h4>
						<p>Failed</p>
					</div>
				{/if}
			</div>
			<button class="btn-close-stats" on:click={closeReminderStats}>Close</button>
		</div>
	</div>
{/if}

<style>
	.task-details-view {
		background: white;
		border-radius: 12px;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		height: 100%;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 2px solid #e5e7eb;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
	}

	.title {
		font-size: 24px;
		font-weight: 700;
		margin: 0;
		color: white;
	}

	.close-btn {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		width: 36px;
		height: 36px;
		border-radius: 8px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s ease;
		color: white;
	}

	.close-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		transform: scale(1.05);
	}

	.filters-section {
		padding: 20px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.search-box {
		position: relative;
		margin-bottom: 16px;
	}

	.search-icon {
		position: absolute;
		left: 12px;
		top: 50%;
		transform: translateY(-50%);
		width: 20px;
		height: 20px;
		color: #9ca3af;
	}

	.search-input {
		width: 100%;
		padding: 12px 12px 12px 44px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
		transition: all 0.2s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.filters-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.filter-select,
	.date-input {
		padding: 10px 12px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
		background: white;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.filter-select:focus,
	.date-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.results-info {
		padding: 12px 24px;
		background: #f3f4f6;
		font-size: 14px;
		color: #6b7280;
		font-weight: 500;
	}

	.table-container {
		flex: 1;
		overflow-y: auto;
		padding: 0 24px 24px 24px; /* Remove top padding */
	}

	.loading,
	.no-data {
		text-align: center;
		padding: 60px 20px;
		color: #9ca3af;
		font-size: 16px;
	}

	.tasks-table {
		width: 100%;
		border-collapse: separate;
		border-spacing: 0;
		background: white;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		border-radius: 8px;
	}

	.tasks-table thead {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.tasks-table th {
		padding: 14px 16px;
		text-align: left;
		font-weight: 600;
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		position: sticky;
		top: 0;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		z-index: 10;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
	}

	.tasks-table th:first-child {
		border-top-left-radius: 8px;
	}

	.tasks-table th:last-child {
		border-top-right-radius: 8px;
	}

	.tasks-table tbody tr {
		border-bottom: 1px solid #e5e7eb;
		transition: background 0.2s ease;
	}

	.tasks-table tbody tr:hover {
		background: #f9fafb;
	}

	.clickable-row {
		cursor: pointer;
	}

	.clickable-row:hover {
		background: #f3f4f6 !important;
	}

	.tasks-table td {
		padding: 14px 16px;
		font-size: 14px;
		color: #374151;
	}

	.task-title-cell {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.task-desc {
		font-size: 12px;
		color: #6b7280;
	}

	.badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		text-transform: capitalize;
	}

	.badge-quick {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge-receiving {
		background: #dcfce7;
		color: #166534;
	}

	.badge-regular {
		background: #f3e8ff;
		color: #6b21a8;
	}

	.badge-assigned,
	.badge-pending {
		background: #fef3c7;
		color: #92400e;
	}

	.badge-in_progress {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge-completed {
		background: #d1fae5;
		color: #065f46;
	}

	.badge-info {
		background: #e0e7ff;
		color: #3730a3;
	}

	.badge-warning {
		background: #fed7aa;
		color: #92400e;
	}

	/* Due Status Badges */
	.due-status-badge {
		display: inline-block;
		padding: 6px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		white-space: nowrap;
	}

	.status-overdue {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fca5a5;
		animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
	}

	.status-due-today {
		background: #fef3c7;
		color: #92400e;
		border: 1px solid #fcd34d;
		font-weight: 700;
	}

	.status-due-tomorrow {
		background: #fed7aa;
		color: #c2410c;
		border: 1px solid #fb923c;
	}

	.status-urgent {
		background: #fecaca;
		color: #b91c1c;
		border: 1px solid #f87171;
	}

	.status-warning {
		background: #fef3c7;
		color: #a16207;
		border: 1px solid #fbbf24;
	}

	.status-safe {
		background: #d1fae5;
		color: #065f46;
		border: 1px solid #6ee7b7;
	}

	.status-completed {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #4ade80;
		font-weight: 600;
	}

	.status-no-deadline {
		background: #e5e7eb;
		color: #4b5563;
		border: 1px solid #d1d5db;
	}

	/* Task Detail Modal */
	.task-detail-modal {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 20px;
		backdrop-filter: blur(4px);
	}

	.task-detail-content {
		background: white;
		border-radius: 16px;
		max-width: 800px;
		width: 100%;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.detail-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 24px;
		border-bottom: 2px solid #e5e7eb;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border-radius: 16px 16px 0 0;
	}

	.detail-header h3 {
		margin: 0;
		font-size: 22px;
		font-weight: 700;
	}

	.detail-body {
		padding: 24px;
	}

	.detail-section {
		margin-bottom: 24px;
	}

	.detail-section label {
		display: block;
		font-weight: 600;
		color: #374151;
		margin-bottom: 8px;
		font-size: 14px;
	}

	.detail-section p {
		margin: 0;
		color: #6b7280;
		line-height: 1.6;
		font-size: 15px;
	}

	.detail-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 20px;
	}

	.detail-item label {
		display: block;
		font-weight: 600;
		color: #374151;
		margin-bottom: 6px;
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.detail-item p {
		margin: 0;
		color: #1f2937;
		font-size: 15px;
	}

	/* Header with Counter */
	.header-left {
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.reminder-counter {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		background: rgba(255, 255, 255, 0.2);
		padding: 6px 12px;
		border-radius: 20px;
		font-size: 13px;
		font-weight: 600;
		color: white;
	}

	/* Auto Reminder Statistics Dashboard */
	.auto-reminder-stats {
		padding: 16px 24px;
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border-bottom: 1px solid #bae6fd;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
		gap: 16px;
	}

	.stat-card {
		display: flex;
		align-items: center;
		gap: 12px;
		background: white;
		padding: 16px;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
		transition: all 0.3s ease;
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
	}

	.stat-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 48px;
		height: 48px;
		border-radius: 10px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		flex-shrink: 0;
	}

	.stat-content {
		flex: 1;
		min-width: 0;
	}

	.stat-value {
		font-size: 20px;
		font-weight: 700;
		color: #1f2937;
		margin-bottom: 4px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.stat-label {
		font-size: 12px;
		font-weight: 500;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	/* Reminder Controls */
	.reminder-controls {
		padding: 16px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: 12px;
	}

	.selection-controls {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.reminder-buttons {
		display: flex;
		gap: 12px;
	}

	.btn-select,
	.btn-deselect {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 8px 16px;
		border: 1px solid #d1d5db;
		background: white;
		color: #374151;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-select:hover:not(:disabled),
	.btn-deselect:hover:not(:disabled) {
		background: #f3f4f6;
		border-color: #9ca3af;
	}

	.btn-select:disabled,
	.btn-deselect:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.selected-count {
		padding: 4px 12px;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 12px;
		font-size: 13px;
		font-weight: 600;
	}

	.btn-remind-selected,
	.btn-remind-all {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 10px 20px;
		border: none;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-remind-selected {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.btn-remind-selected:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
	}

	.btn-remind-all {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		color: white;
	}

	.btn-remind-all:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
	}

	.btn-remind-selected:disabled,
	.btn-remind-all:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.animate-spin {
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	/* Checkbox Column */
	.checkbox-col {
		width: 60px;
		text-align: center;
	}

	.task-checkbox {
		width: 18px;
		height: 18px;
		cursor: pointer;
		accent-color: #667eea;
	}

	/* Reminder Stats Modal */
	.reminder-stats-modal {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1100;
		padding: 20px;
		backdrop-filter: blur(4px);
	}

	.reminder-stats-content {
		background: white;
		border-radius: 16px;
		max-width: 500px;
		width: 100%;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.stats-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 24px;
		border-bottom: 2px solid #e5e7eb;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border-radius: 16px 16px 0 0;
	}

	.stats-header h3 {
		margin: 0;
		font-size: 20px;
		font-weight: 700;
	}

	.stats-body {
		padding: 32px;
		display: flex;
		gap: 20px;
		justify-content: center;
	}

	.stat-card {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 24px;
		border-radius: 12px;
		text-align: center;
	}

	.stat-card.success {
		background: #d1fae5;
		color: #065f46;
	}

	.stat-card.error {
		background: #fee2e2;
		color: #991b1b;
	}

	.stat-card h4 {
		margin: 12px 0 4px;
		font-size: 32px;
		font-weight: 700;
	}

	.stat-card p {
		margin: 0;
		font-size: 14px;
		font-weight: 600;
		opacity: 0.8;
	}

	.btn-close-stats {
		margin: 0 24px 24px;
		width: calc(100% - 48px);
		padding: 12px;
		background: #667eea;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 15px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-close-stats:hover {
		background: #5568d3;
		transform: translateY(-1px);
	}
</style>


