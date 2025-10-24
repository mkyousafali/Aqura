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
		// Load from task_assignments with branches relation
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

		// Load from quick_task_assignments with quick_tasks.branches relation
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

		if (taskAssignments) {
			tasks = [...tasks, ...taskAssignments.map(ta => ({
				...ta,
				task_title: ta.tasks?.title || 'N/A',
				task_description: ta.tasks?.description || '',
				task_type: 'regular',
				branch_name: ta.assignee?.user_branch?.name_en || ta.branches?.name_en || 'N/A',
				branch_id: ta.assignee?.user_branch?.id || ta.assigned_to_branch_id,
				assigned_date: ta.assigned_at,
				deadline: ta.deadline_datetime || ta.deadline_date,
				assigned_by_name: ta.assigner?.username || ta.assigner?.username,
				assigned_to_name: ta.assignee?.username || ta.assignee?.username
			}))];
		}

		if (quickAssignments) {
			tasks = [...tasks, ...quickAssignments.map(qa => ({
				...qa,
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
		// Load all tasks (like loadTotalTasks) but filter out completed ones
		// First, get all completed task IDs for filtering

		// Get completed task_assignment IDs
		const { data: completedTaskIds, error: ctError } = await supabase
			.from('task_completions')
			.select('assignment_id');

		// Get completed quick_task_assignment IDs  
		const { data: completedQuickIds, error: cqError } = await supabase
			.from('quick_task_completions')
			.select('assignment_id');

		if (ctError) console.error('Error loading completed task IDs:', ctError);
		if (cqError) console.error('Error loading completed quick task IDs:', cqError);

		const completedTaskAssignmentIds = completedTaskIds?.map(c => c.assignment_id) || [];
		const completedQuickAssignmentIds = completedQuickIds?.map(c => c.assignment_id) || [];

		// Load from task_assignments with branches relation
		let taskAssignmentsQuery = supabase
			.from('task_assignments')
			.select(`
				*,
				tasks(*),
				branches:assigned_to_branch_id(id, name_en),
				assigner:assigned_by(id, username),
				assignee:assigned_to_user_id(id, username, user_branch:branch_id(id, name_en))
			`);

		// Only apply filter if there are completed tasks to exclude
		if (completedTaskAssignmentIds.length > 0) {
			taskAssignmentsQuery = taskAssignmentsQuery.not('id', 'in', `(${completedTaskAssignmentIds.join(',')})`);
		}

		const { data: taskAssignments, error: taError } = await taskAssignmentsQuery;

		if (taError) console.error('Error loading incomplete task_assignments:', taError);

		// Load from quick_task_assignments with quick_tasks.branches relation
		let quickAssignmentsQuery = supabase
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

		// Only apply filter if there are completed quick tasks to exclude
		if (completedQuickAssignmentIds.length > 0) {
			quickAssignmentsQuery = quickAssignmentsQuery.not('id', 'in', `(${completedQuickAssignmentIds.join(',')})`);
		}

		const { data: quickAssignments, error: qaError } = await quickAssignmentsQuery;

		if (qaError) console.error('Error loading incomplete quick_task_assignments:', qaError);

		if (taskAssignments) {
			tasks = [...tasks, ...taskAssignments.map(ta => ({
				...ta,
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
			tasks = [...tasks, ...quickAssignments.map(qa => ({
				...qa,
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

	function viewTaskDetails(task: any) {
		selectedTask = task;
		showTaskDetail = true;
	}

	function closeTaskDetail() {
		showTaskDetail = false;
		selectedTask = null;
	}
</script>

<div class="task-details-view">
	<div class="header">
		<h2 class="title">{cardTitles[cardType] || 'Task Details'}</h2>
		<button class="close-btn" on:click={onClose} aria-label="Close window">
			<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
			</svg>
		</button>
	</div>

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
				{#each users as user}
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
						<th>Task Title</th>
						<th>Type</th>
						<th>Branch</th>
						<th>Assigned By</th>
						<th>Assigned To</th>
						<th>Assigned Date</th>
						<th>Deadline</th>
						<th>Status</th>
						{#if cardType === 'completed_tasks' || cardType === 'my_completed_tasks' || cardType === 'my_assignments_completed'}
							<th>Completed Date</th>
						{/if}
					</tr>
				</thead>
				<tbody>
					{#each filteredTasks as task}
						<tr class="clickable-row" on:click={() => viewTaskDetails(task)}>
							<td>
								<div class="task-title-cell">
									<strong>{task.task_title}</strong>
									{#if task.task_description}
										<span class="task-desc">{task.task_description.substring(0, 80)}{task.task_description.length > 80 ? '...' : ''}</span>
									{/if}
								</div>
							</td>
							<td>
								<span class="badge {task.task_type === 'quick' ? 'badge-quick' : 'badge-regular'}">
									{task.task_type === 'quick' ? 'Quick' : 'Regular'}
								</span>
							</td>
							<td>{task.branch_name}</td>
							<td>{task.assigned_by_name || task.assigned_by || 'N/A'}</td>
							<td>{task.assigned_to_name || task.assigned_to || 'N/A'}</td>
							<td>{formatDate(task.assigned_date)}</td>
							<td>{formatDate(task.deadline)}</td>
							<td>
								<span class="badge badge-{task.status || 'pending'}">
									{task.status || 'N/A'}
								</span>
							</td>
							{#if cardType === 'completed_tasks' || cardType === 'my_completed_tasks' || cardType === 'my_assignments_completed'}
								<td>{formatDate(task.completed_date)}</td>
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
						<span class="badge {selectedTask.task_type === 'quick' ? 'badge-quick' : 'badge-regular'}">
							{selectedTask.task_type === 'quick' ? 'Quick Task' : 'Regular Task'}
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
		padding: 24px;
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
		border-collapse: collapse;
		background: white;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		border-radius: 8px;
		overflow: hidden;
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
</style>


