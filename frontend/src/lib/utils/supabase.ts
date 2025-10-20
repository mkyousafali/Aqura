import { createClient } from '@supabase/supabase-js';
import { browser } from '$app/environment';

// Supabase configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Singleton instances to prevent multiple client creation
let _supabase: any = null;
let _supabaseAdmin: any = null;

// Create Supabase client with singleton pattern
export const supabase = (() => {
	if (_supabase) {
		return _supabase;
	}
	
	_supabase = createClient(supabaseUrl, supabaseAnonKey, {
		auth: {
			persistSession: true,
			autoRefreshToken: true,
			detectSessionInUrl: true,
			storageKey: 'aqura-auth-v2' // Use unique storage key
		},
		global: {
			headers: {
				'X-Client-Info': 'aqura-pwa-v2'
			}
		},
		realtime: {
			params: {
				eventsPerSecond: 10
			}
		}
	});
	
	// Mark as singleton to avoid recreation
	_supabase._isSingleton = true;
	return _supabase;
})();

// Service role client for administrative operations (bypasses RLS)
export const supabaseAdmin = (() => {
	if (_supabaseAdmin) {
		return _supabaseAdmin;
	}
	
	_supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
		auth: {
			persistSession: false,
			autoRefreshToken: false,
			storageKey: 'aqura-admin-auth-v2' // Use unique storage key
		},
		global: {
			headers: {
				'X-Client-Info': 'aqura-pwa-admin-v2'
			}
		}
	});
	
	// Mark as singleton to avoid recreation
	_supabaseAdmin._isSingleton = true;
	return _supabaseAdmin;
})();

// Database types based on our models
export interface Employee {
	id: string;
	name: string;
	email: string;
	phone: string;
	position: string;
	department: string;
	salary: number;
	hire_date: string;
	status: 'active' | 'inactive' | 'on_leave';
	avatar_url?: string;
	branch_id?: string;
	created_at: string;
	updated_at: string;
}

export interface Branch {
	id: string;
	name_en: string;
	name_ar: string;
	location_en: string;
	location_ar: string;
	is_active: boolean;
	is_main_branch: boolean;
	created_at: string;
	updated_at: string;
}

export interface Vendor {
	erp_vendor_id: number;
	vendor_name: string;
	salesman_name?: string;
	salesman_contact?: string;
	supervisor_name?: string;
	supervisor_contact?: string;
	vendor_contact_number?: string;
	payment_method?: string;
	credit_period?: number;
	bank_name?: string;
	iban?: string;
	status: string;
	last_visit?: string;
	categories?: string[];
	delivery_modes?: string[];
	place?: string;
	location_link?: string;
	return_expired_products?: string;
	return_expired_products_note?: string;
	return_near_expiry_products?: string;
	return_near_expiry_products_note?: string;
	return_over_stock?: string;
	return_over_stock_note?: string;
	return_damage_products?: string;
	return_damage_products_note?: string;
	no_return?: boolean;
	no_return_note?: string;
	vat_applicable?: string;
	vat_number?: string;
	no_vat_note?: string;
	created_at?: string;
	updated_at?: string;
}

export interface User {
	id: string;
	email: string;
	full_name: string;
	role: 'admin' | 'manager' | 'employee';
	avatar_url?: string;
	branch_id?: string;
	is_active: boolean;
	last_login?: string;
	created_at: string;
	updated_at: string;
}

export interface Task {
	id: string;
	title: string;
	description?: string;
	require_task_finished: boolean;
	require_photo_upload: boolean;
	require_erp_reference: boolean;
	can_escalate: boolean;
	can_reassign: boolean;
	created_by: string;
	created_by_name?: string;
	created_by_role?: string;
	status: 'draft' | 'active' | 'paused' | 'completed' | 'cancelled';
	priority: 'low' | 'medium' | 'high';
	created_at: string;
	updated_at: string;
	deleted_at?: string;
	due_date?: string;
	due_time?: string;
	due_datetime?: string;
}

export interface TaskImage {
	id: string;
	task_id: string;
	file_name: string;
	file_size: number;
	file_type: string;
	file_url: string;
	image_type: 'task_creation' | 'task_completion';
	uploaded_by: string;
	uploaded_by_name?: string;
	created_at: string;
	image_width?: number;
	image_height?: number;
}

export interface TaskAssignment {
	id: string;
	task_id: string;
	assignment_type: 'user' | 'branch' | 'all';
	assigned_to_user_id?: string;
	assigned_to_branch_id?: string;
	assigned_by: string;
	assigned_by_name?: string;
	assigned_at: string;
	status: 'assigned' | 'in_progress' | 'completed' | 'escalated' | 'reassigned';
	started_at?: string;
	completed_at?: string;
	// New enhanced fields
	schedule_date?: string;
	schedule_time?: string;
	deadline_date?: string;
	deadline_time?: string;
	deadline_datetime?: string;
	is_reassignable?: boolean;
	is_recurring?: boolean;
	recurring_pattern?: any;
	notes?: string;
	priority_override?: string;
	require_task_finished?: boolean;
	require_photo_upload?: boolean;
	require_erp_reference?: boolean;
	reassigned_from?: string;
	reassignment_reason?: string;
	reassigned_at?: string;
}

export interface RecurringAssignmentSchedule {
	id: string;
	assignment_id: string;
	repeat_type: 'daily' | 'weekly' | 'monthly' | 'yearly' | 'custom';
	repeat_interval: number;
	repeat_on_days?: number[];
	repeat_on_date?: number;
	repeat_on_month?: number;
	execute_time: string;
	timezone: string;
	start_date: string;
	end_date?: string;
	max_occurrences?: number;
	is_active: boolean;
	last_executed_at?: string;
	next_execution_at: string;
	executions_count: number;
	created_at: string;
	updated_at: string;
	created_by: string;
}

export interface TaskCompletion {
	id: string;
	task_id: string;
	assignment_id: string;
	completed_by: string;
	completed_by_name?: string;
	completed_by_branch_id?: string;
	task_finished_completed: boolean;
	photo_uploaded_completed: boolean;
	erp_reference_completed: boolean;
	erp_reference_number?: string;
	completion_notes?: string;
	verified_by?: string;
	verified_at?: string;
	verification_notes?: string;
	completed_at: string;
	created_at: string;
}

export interface NotificationAttachment {
	id: string;
	notification_id: string;
	file_name: string;
	file_path: string;
	file_size: number;
	file_type: string;
	uploaded_by: string;
	created_at: string;
}

export interface TaskAttachment {
	id: string;
	task_id: string;
	file_name: string;
	file_path: string;
	file_size: number;
	file_type: string;
	attachment_type: 'task_creation' | 'task_completion';
	uploaded_by: string;
	uploaded_by_name?: string;
	created_at: string;
}

// Auth helpers
export const auth = {
	// Sign in with email and password
	async signIn(email: string, password: string) {
		const { data, error } = await supabase.auth.signInWithPassword({
			email,
			password
		});
		return { data, error };
	},

	// Sign up new user
	async signUp(email: string, password: string, metadata?: any) {
		const { data, error } = await supabase.auth.signUp({
			email,
			password,
			options: {
				data: metadata
			}
		});
		return { data, error };
	},

	// Sign out
	async signOut() {
		const { error } = await supabase.auth.signOut();
		return { error };
	},

	// Get current user
	async getCurrentUser() {
		const { data: { user }, error } = await supabase.auth.getUser();
		return { user, error };
	},

	// Get session
	async getSession() {
		const { data: { session }, error } = await supabase.auth.getSession();
		return { session, error };
	},

	// Listen to auth changes
	onAuthStateChange(callback: (event: string, session: any) => void) {
		return supabase.auth.onAuthStateChange(callback);
	}
};

// Data access layer
export const db = {
	// Employee operations
	employees: {
		async getAll() {
			const { data, error } = await supabase
				.from('hr_employees')
				.select(`
					id,
					employee_id,
					name,
					branch_id,
					hire_date,
					status,
					created_at
				`)
				.order('name');
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('hr_employees')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(employee: any) {
			const { data, error } = await supabase
				.from('hr_employees')
				.insert(employee)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: any) {
			const { data, error } = await supabase
				.from('hr_employees')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('hr_employees')
				.delete()
				.eq('id', id);
			return { error };
		},

		async getByBranch(branchId: string) {
			const { data, error } = await supabase
				.from('hr_employees')
				.select('*')
				.eq('branch_id', branchId)
				.order('name');
			return { data, error };
		},

		async getAllWithContacts() {
			const { data, error } = await supabase
				.from('hr_employees')
				.select(`
					id,
					employee_id,
					name,
					branch_id,
					hire_date,
					status,
					created_at,
					hr_employee_contacts (
						id,
						email,
						contact_number,
						whatsapp_number,
						is_active
					)
				`)
				.eq('status', 'active')
				.eq('hr_employee_contacts.is_active', true)
				.order('name');
			return { data, error };
		}
	},

	// Employee contacts operations
	employeeContacts: {
		async getAll() {
			const { data, error } = await supabase
				.from('hr_employee_contacts')
				.select('*')
				.eq('is_active', true)
				.order('created_at');
			return { data, error };
		},

		async getByEmployeeId(employeeId: string) {
			const { data, error } = await supabase
				.from('hr_employee_contacts')
				.select('*')
				.eq('employee_id', employeeId)
				.eq('is_active', true);
			return { data, error };
		},

		async create(contact: any) {
			const { data, error } = await supabase
				.from('hr_employee_contacts')
				.insert(contact)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: any) {
			const { data, error } = await supabase
				.from('hr_employee_contacts')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('hr_employee_contacts')
				.delete()
				.eq('id', id);
			return { error };
		}
	},

	// Branch operations
	branches: {
		async getAll() {
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.order('name_en');
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(branch: Omit<Branch, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('branches')
				.insert(branch)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<Branch>) {
			const { data, error } = await supabase
				.from('branches')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('branches')
				.delete()
				.eq('id', id);
			return { error };
		}
	},

	// Vendor operations
	vendors: {
		async getAll() {
			const { data, error } = await supabase
				.from('vendors')
				.select('*')
				.order('vendor_name')
				.limit(10000); // Increase limit to show all vendors
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('vendors')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(vendor: Omit<Vendor, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('vendors')
				.insert(vendor)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<Vendor>) {
			const { data, error } = await supabase
				.from('vendors')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('vendors')
				.delete()
				.eq('id', id);
			return { error };
		}
	},

	// User operations (system users table)
	users: {
		async getAll() {
			const { data, error } = await supabase
				.from('users')
				.select(`
					id,
					username,
					user_type,
					role_type,
					status,
					branch_id,
					avatar,
					avatar_small_url,
					avatar_medium_url,
					avatar_large_url,
					created_at,
					updated_at
				`)
				.order('username');
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('users')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(user: any) {
			const { data, error } = await supabase
				.from('users')
				.insert(user)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: any) {
			const { data, error } = await supabase
				.from('users')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('users')
				.delete()
				.eq('id', id);
			return { error };
		},

		async getAllWithEmployeeDetails() {
			const { data, error } = await supabase
				.from('users')
				.select(`
					id,
					username,
					user_type,
					role_type,
					status,
					branch_id,
					employee_id,
					avatar,
					avatar_small_url,
					avatar_medium_url,
					avatar_large_url,
					created_at,
					updated_at,
					hr_employees!employee_id (
						id,
						name,
						employee_id,
						hire_date,
						status,
						hr_employee_contacts (
							id,
							email,
							contact_number,
							whatsapp_number,
							is_active
						),
						hr_position_assignments!hr_position_assignments_employee_id_fkey (
							id,
							is_current,
							effective_date,
							hr_positions (
								id,
								position_title_en,
								position_title_ar
							)
						)
					)
				`)
				.eq('status', 'active')
				.order('username');
			return { data, error };
		},

		async getAllWithEmployeeDetailsFlat() {
			// Use the database function to get flat user-employee data structure
			const { data, error } = await supabase.rpc('get_users_with_employee_details');
			return { data, error };
		}
	},

	// Task operations
	tasks: {
		async getAll(limit: number = 50, offset: number = 0, status?: string, created_by?: string) {
			let query = supabase
				.from('tasks')
				.select('*')
				.is('deleted_at', null)
				.order('created_at', { ascending: false })
				.range(offset, offset + limit - 1);

			if (status) {
				query = query.eq('status', status);
			}
			if (created_by) {
				query = query.eq('created_by', created_by);
			}

			const { data, error, count } = await query;
			return { data, error, count };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('tasks')
				.select('*')
				.eq('id', id)
				.is('deleted_at', null)
				.single();
			return { data, error };
		},

		async create(task: Omit<Task, 'id' | 'created_at' | 'updated_at'>) {
			console.log('🗄️ [DB] tasks.create called with:', task);
			console.log('🗄️ [DB] task data types:', {
				title: typeof task.title,
				description: typeof task.description,
				created_by: typeof task.created_by,
				require_task_finished: typeof task.require_task_finished,
				require_photo_upload: typeof task.require_photo_upload,
				require_erp_reference: typeof task.require_erp_reference,
				can_escalate: typeof task.can_escalate,
				can_reassign: typeof task.can_reassign,
				status: typeof task.status,
				priority: typeof task.priority,
				due_date: typeof task.due_date,
				due_time: typeof task.due_time,
				due_datetime: typeof task.due_datetime
			});
			
			const { data, error } = await supabase
				.from('tasks')
				.insert(task)
				.select()
				.single();
				
			console.log('🗄️ [DB] tasks.create result:', { data, error });
			
			if (error) {
				console.error('❌ [DB] Database insert error details:', {
					message: error.message,
					details: error.details,
					hint: error.hint,
					code: error.code
				});
			}
			
			return { data, error };
		},

		async update(id: string, updates: Partial<Task>) {
			const { data, error } = await supabase
				.from('tasks')
				.update({ ...updates, updated_at: new Date().toISOString() })
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string, user_id: string) {
			// Soft delete by setting deleted_at
			const { data, error } = await supabase
				.from('tasks')
				.update({ 
					deleted_at: new Date().toISOString(),
					updated_at: new Date().toISOString()
				})
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async search(query: string, user_id?: string, limit: number = 50, offset: number = 0) {
			const { data, error } = await supabase.rpc('search_tasks', {
				search_query: query,
				user_id_param: user_id,
				limit_param: limit,
				offset_param: offset
			});
			return { data, error };
		},

		async getStatistics(user_id?: string) {
			const { data, error } = await supabase.rpc('get_task_statistics', {
				user_id_param: user_id
			});
			return { data: data?.[0] || null, error };
		},

		// Task status operations
		async activate(id: string, user_id: string) {
			return this.update(id, { status: 'active' });
		},

		async pause(id: string, user_id: string) {
			return this.update(id, { status: 'paused' });
		},

		async resume(id: string, user_id: string) {
			return this.update(id, { status: 'active' });
		},

		async complete(id: string, user_id: string) {
			return this.update(id, { status: 'completed' });
		}
	},

	// Task assignments operations
	taskAssignments: {
		async getById(id: string) {
			const { data, error } = await supabase
				.from('task_assignments')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async getByTaskId(task_id: string) {
			const { data, error } = await supabase
				.from('task_assignments')
				.select('*')
				.eq('task_id', task_id);
			return { data, error };
		},

		async create(assignment: Omit<TaskAssignment, 'id' | 'assigned_at'>) {
			const { data, error } = await supabase
				.from('task_assignments')
				.insert(assignment)
				.select()
				.single();
			return { data, error };
		},

		async assignTasks(task_ids: string[], assignment_type: 'user' | 'branch' | 'all', assigned_by: string, assigned_by_name?: string, assigned_to_user_id?: string, assigned_to_branch_id?: string, scheduleSettings?: {
			deadline_date?: string;
			deadline_time?: string;
			notes?: string;
			priority_override?: string;
			require_task_finished?: boolean;
			require_photo_upload?: boolean;
			require_erp_reference?: boolean;
		}) {
			const assignments = task_ids.map(task_id => {
				// Build the assignment object step by step for better debugging
				const baseAssignment = {
					task_id,
					assignment_type,
					assigned_to_user_id,
					assigned_to_branch_id,
					assigned_by,
					assigned_by_name
				};

				// Add optional fields
				const optionalFields: any = {};
				if (scheduleSettings?.deadline_date) {
					optionalFields.deadline_date = scheduleSettings.deadline_date;
				}
				if (scheduleSettings?.deadline_time) {
					optionalFields.deadline_time = scheduleSettings.deadline_time;
				}
				if (scheduleSettings?.deadline_date && scheduleSettings?.deadline_time) {
					optionalFields.deadline_datetime = `${scheduleSettings.deadline_date}T${scheduleSettings.deadline_time}:00`;
				}
				if (scheduleSettings?.notes) {
					optionalFields.notes = scheduleSettings.notes;
				}
				if (scheduleSettings?.priority_override) {
					optionalFields.priority_override = scheduleSettings.priority_override;
				}

				// Add completion criteria explicitly
				const completionCriteria = {
					require_task_finished: scheduleSettings?.require_task_finished ?? true,
					require_photo_upload: scheduleSettings?.require_photo_upload ?? false,
					require_erp_reference: scheduleSettings?.require_erp_reference ?? false
				};

				const finalAssignment = {
					...baseAssignment,
					...optionalFields,
					...completionCriteria
				};

				return finalAssignment;
			});

			try {
				const { data, error } = await supabase
					.from('task_assignments')
					.insert(assignments)
					.select();
				
				return { data, error };
			} catch (insertError) {
				console.error('❌ [DB] Insert exception:', insertError);
				return { data: null, error: insertError };
			}
		},

		async createScheduledAssignment(
			task_id: string,
			assignment_type: 'user' | 'branch' | 'all',
			assigned_by: string,
			assigned_to_user_id?: string,
			assigned_to_branch_id?: string,
			assigned_by_name?: string,
			schedule_date: string | null = null,
			schedule_time: string | null = null,
			deadline_date: string | null = null,
			deadline_time: string | null = null
		) {
			const { data, error } = await supabase.rpc('create_scheduled_assignment', {
				p_task_id: task_id,
				p_assignment_type: assignment_type,
				p_assigned_by: assigned_by,
				p_assigned_to_user_id: assigned_to_user_id,
				p_assigned_to_branch_id: assigned_to_branch_id,
				p_assigned_by_name: assigned_by_name,
				p_schedule_date: schedule_date,
				p_schedule_time: schedule_time,
				p_deadline_date: deadline_date,
				p_deadline_time: deadline_time
			});
			return { data, error };
		},

		async createRecurringAssignment(
			task_id: string,
			assignment_type: 'user' | 'branch' | 'all',
			assigned_by: string,
			assigned_by_name: string,
			repeat_pattern: 'daily' | 'weekly' | 'monthly' | 'yearly',
			repeat_interval: number = 1,
			start_date: string,
			end_date?: string,
			assigned_to_user_id?: string,
			assigned_to_branch_id?: string
		) {
			const { data, error } = await supabase.rpc('create_recurring_assignment', {
				p_task_id: task_id,
				p_assignment_type: assignment_type,
				p_assigned_by: assigned_by,
				p_assigned_by_name: assigned_by_name,
				p_repeat_pattern: repeat_pattern,
				p_repeat_interval: repeat_interval,
				p_start_date: start_date,
				p_end_date: end_date,
				p_assigned_to_user_id: assigned_to_user_id,
				p_assigned_to_branch_id: assigned_to_branch_id
			});
			return { data, error };
		},

		async reassignTask(
			assignment_id: string,
			new_assigned_to_user_id: string | null,
			new_assigned_to_branch_id: string | null,
			new_assignment_type: 'user' | 'branch' | 'all',
			reassigned_by: string,
			reassigned_by_name: string,
			reason?: string
		) {
			const { data, error } = await supabase.rpc('reassign_task', {
				p_assignment_id: assignment_id,
				p_new_assigned_to_user_id: new_assigned_to_user_id,
				p_new_assigned_to_branch_id: new_assigned_to_branch_id,
				p_new_assignment_type: new_assignment_type,
				p_reassigned_by: reassigned_by,
				p_reassigned_by_name: reassigned_by_name,
				p_reason: reason
			});
			return { data, error };
		},

		async getAssignmentsWithDeadlines(user_id?: string, branch_id?: string) {
			const { data, error } = await supabase.rpc('get_assignments_with_deadlines', {
				p_user_id: user_id,
				p_branch_id: branch_id
			});
			return { data, error };
		}
	},

	// Quick task assignments operations
	quickTaskAssignments: {
		async getById(id: string) {
			const { data, error } = await supabase
				.from('quick_task_assignments')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async getByTaskId(quick_task_id: string) {
			const { data, error } = await supabase
				.from('quick_task_assignments')
				.select('*')
				.eq('quick_task_id', quick_task_id);
			return { data, error };
		},

		async getByUserId(user_id: string) {
			const { data, error } = await supabase
				.from('quick_task_assignments')
				.select('*')
				.eq('assigned_to_user_id', user_id)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async create(assignment: {
			quick_task_id: string;
			assigned_to_user_id: string;
			require_task_finished?: boolean;
			require_photo_upload?: boolean;
			require_erp_reference?: boolean;
		}) {
			const { data, error } = await supabase
				.from('quick_task_assignments')
				.insert({
					require_task_finished: true,
					require_photo_upload: false,
					require_erp_reference: false,
					...assignment
				})
				.select()
				.single();
			return { data, error };
		},

		async createMultiple(assignments: Array<{
			quick_task_id: string;
			assigned_to_user_id: string;
			require_task_finished?: boolean;
			require_photo_upload?: boolean;
			require_erp_reference?: boolean;
		}>) {
			const formattedAssignments = assignments.map(assignment => ({
				require_task_finished: true,
				require_photo_upload: false,
				require_erp_reference: false,
				...assignment
			}));

			const { data, error } = await supabase
				.from('quick_task_assignments')
				.insert(formattedAssignments)
				.select();
			return { data, error };
		},

		async updateStatus(id: string, status: string) {
			const updates: any = {
				status,
				updated_at: new Date().toISOString()
			};

			if (status === 'accepted') {
				updates.accepted_at = new Date().toISOString();
			} else if (status === 'in_progress') {
				updates.started_at = new Date().toISOString();
			} else if (status === 'completed') {
				updates.completed_at = new Date().toISOString();
			}

			const { data, error } = await supabase
				.from('quick_task_assignments')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async submitCompletion(
			assignment_id: string,
			completion_notes?: string,
			photo_path?: string,
			erp_reference?: string
		) {
			const { data, error } = await supabase.rpc('submit_quick_task_completion', {
				assignment_id_param: assignment_id,
				completion_notes_param: completion_notes,
				photo_path_param: photo_path,
				erp_reference_param: erp_reference
			});
			return { data, error };
		}
	},

	// Task images operations
	taskImages: {
		async getByTaskId(task_id: string) {
			const { data, error } = await supabase
				.from('task_images')
				.select('*')
				.eq('task_id', task_id)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async create(image: Omit<TaskImage, 'id' | 'created_at'>) {
			const { data, error } = await supabase
				.from('task_images')
				.insert(image)
				.select()
				.single();
			return { data, error };
		}
	},

	// Task completions operations
	taskCompletions: {
		async getByTaskId(task_id: string) {
			const { data, error } = await supabase
				.from('task_completions')
				.select('*')
				.eq('task_id', task_id)
				.order('completed_at', { ascending: false });
			return { data, error };
		},

		async create(completion: Omit<TaskCompletion, 'id' | 'created_at' | 'completed_at'>) {
			const { data, error } = await supabase
				.from('task_completions')
				.insert({
					...completion,
					completed_at: new Date().toISOString()
				})
				.select()
				.single();
			return { data, error };
		}
	},

	// Notification attachments operations
	notificationAttachments: {
		async getByNotificationId(notification_id: string) {
			const { data, error } = await supabase
				.from('notification_attachments')
				.select('*')
				.eq('notification_id', notification_id)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async getBatchByNotificationIds(notification_ids: string[]) {
			if (notification_ids.length === 0) {
				return { data: [], error: null };
			}
			
			const { data, error } = await supabase
				.from('notification_attachments')
				.select('*')
				.in('notification_id', notification_ids)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async create(attachment: Omit<NotificationAttachment, 'id' | 'created_at'>) {
			const { data, error } = await supabase
				.from('notification_attachments')
				.insert(attachment)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('notification_attachments')
				.delete()
				.eq('id', id);
			return { error };
		}
	},

	// Task attachments operations
	taskAttachments: {
		async getByTaskId(task_id: string) {
			const { data, error } = await supabase
				.from('task_attachments')
				.select('*')
				.eq('task_id', task_id)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async create(attachment: Omit<TaskAttachment, 'id' | 'created_at'>) {
			// Map TaskAttachment fields to task_images table structure
			const taskImageData = {
				task_id: attachment.task_id,
				file_name: attachment.file_name,
				file_size: attachment.file_size,
				file_type: attachment.file_type,
				file_url: attachment.file_path, // map file_path to file_url for task_images table
				image_type: attachment.attachment_type || 'task_creation',
				uploaded_by: attachment.uploaded_by,
				uploaded_by_name: attachment.uploaded_by_name,
				// Add required fields for task_images table
				image_width: null,
				image_height: null
			};

			const { data, error } = await supabase
				.from('task_images')
				.insert(taskImageData)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('task_images')
				.delete()
				.eq('id', id);
			return { error };
		}
	}
};

// Real-time subscriptions
export const realtime = {
	// Subscribe to table changes
	subscribeToTable(table: string, callback: (payload: any) => void) {
		return supabase
			.channel(`public:${table}`)
			.on('postgres_changes', 
				{ event: '*', schema: 'public', table }, 
				callback
			)
			.subscribe();
	},

	// Subscribe to specific record changes
	subscribeToRecord(table: string, id: string, callback: (payload: any) => void) {
		return supabase
			.channel(`public:${table}:id=eq.${id}`)
			.on('postgres_changes', 
				{ event: '*', schema: 'public', table, filter: `id=eq.${id}` }, 
				callback
			)
			.subscribe();
	}
};

// Offline support with Supabase
export const offline = {
	// Cache strategy for offline support
	async syncOfflineData() {
		if (!browser || !navigator.onLine) return;

		try {
			// Sync all tables
			const [employees, branches, vendors, users] = await Promise.all([
				db.employees.getAll(),
				db.branches.getAll(),
				db.vendors.getAll(),
				db.users.getAll()
			]);

			// Store in local cache (IndexedDB via our offline manager)
			if (employees.data) localStorage.setItem('cache:employees', JSON.stringify(employees.data));
			if (branches.data) localStorage.setItem('cache:branches', JSON.stringify(branches.data));
			if (vendors.data) localStorage.setItem('cache:vendors', JSON.stringify(vendors.data));
			if (users.data) localStorage.setItem('cache:users', JSON.stringify(users.data));

			localStorage.setItem('cache:last_sync', new Date().toISOString());
		} catch (error) {
			console.error('Offline sync failed:', error);
		}
	},

	// Get cached data when offline
	getCachedData(table: string) {
		if (!browser) return [];
		const cached = localStorage.getItem(`cache:${table}`);
		return cached ? JSON.parse(cached) : [];
	},

	// Check if data is stale (older than 5 minutes)
	isDataStale() {
		if (!browser) return true;
		const lastSync = localStorage.getItem('cache:last_sync');
		if (!lastSync) return true;
		
		const fiveMinutes = 5 * 60 * 1000;
		return (Date.now() - new Date(lastSync).getTime()) > fiveMinutes;
	}
};

// File storage utilities
export const storage = {
	// Get current authenticated user from session
	getCurrentAuthUser() {
		if (typeof window === 'undefined') return null;
		
		const sessionData = localStorage.getItem('aqura-device-session');
		if (!sessionData) return null;
		
		try {
			const session = JSON.parse(sessionData);
			if (session.currentUserId && session.users) {
				const currentUser = session.users.find(u => u.id === session.currentUserId);
				if (currentUser && currentUser.isActive) {
					return {
						id: currentUser.id,
						username: currentUser.username,
						employeeName: currentUser.employeeName,
						role: currentUser.role
					};
				}
			}
		} catch (error) {
			console.error('Error parsing session data:', error);
		}
		
		return null;
	},

	// Upload file to Supabase storage
	async uploadFile(file: File, bucket: string, path?: string) {
		const fileName = path || `${Date.now()}-${file.name}`;
		
		// Check if user is authenticated using our custom auth system
		let isAuthenticated = false;
		let userId = null;
		let userName = null;
		
		// Check localStorage for device session (our custom auth system)
		if (typeof window !== 'undefined') {
			const sessionData = localStorage.getItem('aqura-device-session');
			
			if (sessionData) {
				try {
					const session = JSON.parse(sessionData);
					// Check if there's a current user in the session
					if (session.currentUserId && session.users) {
						const currentUser = session.users.find(u => u.id === session.currentUserId);
						if (currentUser && currentUser.isActive) {
							isAuthenticated = true;
							userId = currentUser.id;
							userName = currentUser.username;
							console.log('Upload auth check - user:', `${currentUser.id} (${currentUser.username})`);
						}
					}
				} catch (error) {
					console.error('Error parsing session data:', error);
				}
			}
		}
		
		if (!isAuthenticated) {
			console.log('Upload auth check - user: not authenticated');
			return { 
				data: null, 
				error: { 
					message: 'User must be authenticated to upload files. Please log in first.'
				} 
			};
		}
		
		console.log(`Uploading file ${file.name} to bucket ${bucket} as ${fileName}`);
		
		try {
			const { data, error } = await supabaseAdmin.storage
				.from(bucket)
				.upload(fileName, file, {
					cacheControl: '3600',
					upsert: false
				});
			
			console.log('Supabase storage response:', { data, error });
			
			if (error) {
				console.error('Storage upload error:', error);
				
				// Provide more helpful error messages
				if (error.message.includes('not found') || error.message.includes('bucket')) {
					return { 
						data: null, 
						error: { 
							...error, 
							message: `Storage bucket '${bucket}' does not exist. Please create it in the Supabase dashboard first.` 
						} 
					};
				}
				
				if (error.message.includes('Unauthorized') || error.message.includes('permission')) {
					return { 
						data: null, 
						error: { 
							...error, 
							message: `No permission to upload to bucket '${bucket}'. Please check storage policies.` 
						} 
					};
				}
				
				if (error.message.includes('mime type') || error.message.includes('not supported')) {
					return { 
						data: null, 
						error: { 
							...error, 
							message: `File type '${file.type}' is not allowed in bucket '${bucket}'.` 
						} 
					};
				}
				
				return { data: null, error };
			}
			
			// Get public URL using admin client as well
			const { data: publicUrlData } = supabaseAdmin.storage
				.from(bucket)
				.getPublicUrl(fileName);
			
			return { 
				data: { 
					...data, 
					publicUrl: publicUrlData.publicUrl,
					fileName: fileName
				}, 
				error: null 
			};
		} catch (uploadError) {
			console.error('Upload exception:', uploadError);
			return { 
				data: null, 
				error: { 
					message: `Upload failed: ${uploadError.message || 'Unknown error'}` 
				} 
			};
		}
	},
	
	// Delete file from storage
	async deleteFile(bucket: string, fileName: string) {
		const { error } = await supabase.storage
			.from(bucket)
			.remove([fileName]);
		
		return { error };
	},
	
	// Get file URL
	getFileUrl(bucket: string, fileName: string) {
		const { data } = supabase.storage
			.from(bucket)
			.getPublicUrl(fileName);
		
		return data.publicUrl;
	}
};

// Export the uploadToSupabase function for backward compatibility
export const uploadToSupabase = storage.uploadFile;

// Initialize offline sync
if (browser) {
	// Sync on app load
	offline.syncOfflineData();
	
	// Sync when coming back online
	window.addEventListener('online', offline.syncOfflineData);
	
	// Expose supabase client globally for debugging (development only)
	if (typeof window !== 'undefined') {
		(window as any).supabase = supabase;
	}
}
