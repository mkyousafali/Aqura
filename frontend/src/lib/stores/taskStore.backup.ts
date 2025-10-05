import { writable } from 'svelte/store';

interface Task {
	id: string;
	title: string;
	description: string;
	priority: 'low' | 'medium' | 'high';
	status: 'pending' | 'in_progress' | 'completed' | 'cancelled';
	due_date: string;
	due_time: string;
	created_at: string;
	updated_at: string;
	created_by: string;
	assigned_to?: string;
	image_url?: string;
	require_task_finished: boolean;
	require_photo_upload: boolean;
	require_erp_reference: boolean;
	can_escalate: boolean;
	can_reassign: boolean;
}

interface TaskCompletion {
	id: string;
	task_id: string;
	completion_type: 'task_finished' | 'photo_upload' | 'erp_reference';
	completed_at: string;
	completed_by: string;
}

interface TaskStore {
	tasks: Task[];
	loading: boolean;
	error: string | null;
	currentTask: Task | null;
	completions: TaskCompletion[];
	totalTasks: number;
	completedTasks: number;
	pendingTasks: number;
	inProgressTasks: number;
}

const initialState: TaskStore = {
	tasks: [],
	loading: false,
	error: null,
	currentTask: null,
	completions: [],
	totalTasks: 0,
	completedTasks: 0,
	pendingTasks: 0,
	inProgressTasks: 0
};

function createTaskStore() {
	const { subscribe, set, update } = writable<TaskStore>(initialState);

	return {
		subscribe,
		set,
		update,

		// Load all tasks
		async loadTasks() {
			update(state => ({ ...state, loading: true, error: null }));
			
			try {
				const response = await fetch('http://localhost:8080/api/v1/admin/tasks', {
					headers: {
						'X-User-ID': 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',
						'X-User-Name': 'Admin User',
						'X-User-Role': 'Master Admin'
					},
				});
				
				if (!response.ok) {
					throw new Error(`Failed to load tasks: ${response.statusText}`);
				}
				
				const data = await response.json();
				const tasks = data.data || [];
				
				const totalTasks = tasks.length;
				const completedTasks = tasks.filter((task: Task) => task.status === 'completed').length;
				const pendingTasks = tasks.filter((task: Task) => task.status === 'pending').length;
				const inProgressTasks = tasks.filter((task: Task) => task.status === 'in_progress').length;
				
				update(state => ({
					...state,
					tasks,
					totalTasks,
					completedTasks,
					pendingTasks,
					inProgressTasks,
					loading: false,
					error: null
				}));
				
			} catch (error) {
				console.error('Failed to load tasks:', error);
				update(state => ({
					...state,
					loading: false,
					error: error instanceof Error ? error.message : 'Failed to load tasks'
				}));
			}
		},

		// Create new task
		async createTask(taskData: Omit<Task, 'id' | 'created_at' | 'updated_at'>) {
			update(state => ({ ...state, loading: true, error: null }));
			
			try {
				const response = await fetch('http://localhost:8080/api/v1/admin/tasks', {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json',
						'X-User-ID': 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',
						'X-User-Name': 'Admin User',
						'X-User-Role': 'Master Admin'
					},
					body: JSON.stringify(taskData)
				});
				
				if (!response.ok) {
					const errorText = await response.text();
					update(state => ({
						...state,
						loading: false,
						error: `Failed to create task: ${response.statusText}`
					}));
					return { success: false, error: `Failed to create task: ${response.statusText}` };
				}
				
				const result = await response.json();
				const newTask = result.data || result;
				
				update(state => {
					const updatedTasks = [...state.tasks, newTask];
					const totalTasks = updatedTasks.length;
					const completedTasks = updatedTasks.filter((task: Task) => task.status === 'completed').length;
					const pendingTasks = updatedTasks.filter((task: Task) => task.status === 'pending').length;
					const inProgressTasks = updatedTasks.filter((task: Task) => task.status === 'in_progress').length;
					
					return {
						...state,
						tasks: updatedTasks,
						totalTasks,
						completedTasks,
						pendingTasks,
						inProgressTasks,
						loading: false,
						error: null
					};
				});
				
				return { success: true, data: newTask };
			} catch (error) {
				console.error('Failed to create task:', error);
				const errorMessage = error instanceof Error ? error.message : 'Failed to create task';
				update(state => ({
					...state,
					loading: false,
					error: errorMessage
				}));
				return { success: false, error: errorMessage };
			}
		},

		// Update existing task
		async updateTask(taskId: string, taskData: Partial<Omit<Task, 'id' | 'created_at' | 'updated_at'>>) {
			update(state => ({ ...state, loading: true, error: null }));
			
			try {
				const response = await fetch(`http://localhost:8080/api/v1/admin/tasks/${taskId}`, {
					method: 'PUT',
					headers: {
						'Content-Type': 'application/json',
						'X-User-ID': 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',
						'X-User-Name': 'Admin User',
						'X-User-Role': 'Master Admin'
					},
					body: JSON.stringify(taskData)
				});
				
				if (!response.ok) {
					const errorText = await response.text();
					update(state => ({
						...state,
						loading: false,
						error: `Failed to update task: ${response.statusText}`
					}));
					return { success: false, error: `Failed to update task: ${response.statusText}` };
				}
				
				const result = await response.json();
				const updatedTask = result.data || result;
				
				update(state => {
					const updatedTasks = state.tasks.map(task => 
						task.id === taskId ? { ...task, ...updatedTask } : task
					);
					const totalTasks = updatedTasks.length;
					const completedTasks = updatedTasks.filter((task: Task) => task.status === 'completed').length;
					const pendingTasks = updatedTasks.filter((task: Task) => task.status === 'pending').length;
					const inProgressTasks = updatedTasks.filter((task: Task) => task.status === 'in_progress').length;
					
					return {
						...state,
						tasks: updatedTasks,
						totalTasks,
						completedTasks,
						pendingTasks,
						inProgressTasks,
						loading: false,
						error: null
					};
				});
				
				return { success: true, data: updatedTask };
			} catch (error) {
				console.error('Failed to update task:', error);
				const errorMessage = error instanceof Error ? error.message : 'Failed to update task';
				update(state => ({
					...state,
					loading: false,
					error: errorMessage
				}));
				return { success: false, error: errorMessage };
			}
		},

		// Delete an existing task
		async deleteTask(id: string) {
			try {
				const response = await fetch(`http://localhost:8080/api/v1/admin/tasks/${id}`, {
					method: 'DELETE',
					headers: {
						'Content-Type': 'application/json',
						'X-User-ID': 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',
						'X-User-Name': 'Admin User',
						'X-User-Role': 'Master Admin'
					},
				});

				if (!response.ok) {
					const errorText = await response.text();
					update(state => ({
						...state,
						error: `Failed to delete task: ${response.statusText}`
					}));
					return { success: false, error: `Failed to delete task: ${response.statusText}` };
				}

				// Remove the deleted task from the store
				update(state => {
					const updatedTasks = state.tasks.filter(task => task.id !== id);
					const totalTasks = updatedTasks.length;
					const completedTasks = updatedTasks.filter((task: Task) => task.status === 'completed').length;
					const pendingTasks = updatedTasks.filter((task: Task) => task.status === 'pending').length;
					const inProgressTasks = updatedTasks.filter((task: Task) => task.status === 'in_progress').length;

					return {
						...state,
						tasks: updatedTasks,
						totalTasks,
						completedTasks,
						pendingTasks,
						inProgressTasks,
						currentTask: state.currentTask?.id === id ? null : state.currentTask,
						error: null
					};
				});

				return { success: true, data: { id } };
			} catch (error) {
				console.error('Failed to delete task:', error);
				const errorMessage = error instanceof Error ? error.message : 'Failed to delete task';
				update(state => ({
					...state,
					error: errorMessage
				}));
				return { success: false, error: errorMessage };
			}
		},

		// Clear error
		clearError() {
			update(state => ({ ...state, error: null }));
		},

		// Clear all tasks
		clearTasks() {
			set(initialState);
		},

		// Set current task
		setCurrentTask(task: Task | null) {
			update(state => ({ ...state, currentTask: task }));
		}
	};
}

export const taskStore = createTaskStore();

// Export individual methods for convenience
export const loadTasks = taskStore.loadTasks.bind(taskStore);
export const createTask = taskStore.createTask.bind(taskStore);
export const updateTask = taskStore.updateTask.bind(taskStore);
export const deleteTask = taskStore.deleteTask.bind(taskStore);
export const clearError = taskStore.clearError.bind(taskStore);
export const clearTasks = taskStore.clearTasks.bind(taskStore);
export const setCurrentTask = taskStore.setCurrentTask.bind(taskStore);