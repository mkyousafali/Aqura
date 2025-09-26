import { createClient } from '@supabase/supabase-js';
import { browser } from '$app/environment';

// Supabase configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs';

// Create Supabase client
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
	auth: {
		persistSession: true,
		autoRefreshToken: true,
		detectSessionInUrl: true
	},
	global: {
		headers: {
			'X-Client-Info': 'aqura-pwa'
		}
	}
});

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
	id: string;
	name: string;
	company: string;
	email: string;
	phone: string;
	category: string;
	status: 'active' | 'inactive' | 'pending';
	payment_terms: string;
	tax_id: string;
	registration_number: string;
	address: string;
	total_orders: number;
	created_at: string;
	updated_at: string;
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
				.from('employees')
				.select('*')
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('employees')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(employee: Omit<Employee, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('employees')
				.insert(employee)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<Employee>) {
			const { data, error } = await supabase
				.from('employees')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('employees')
				.delete()
				.eq('id', id);
			return { error };
		},

		async getByBranch(branchId: string) {
			const { data, error } = await supabase
				.from('employees')
				.select('*')
				.eq('branch_id', branchId)
				.order('name');
			return { data, error };
		}
	},

	// Branch operations
	branches: {
		async getAll() {
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.order('name');
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
				.order('company');
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

	// User operations
	users: {
		async getAll() {
			const { data, error } = await supabase
				.from('users')
				.select('*')
				.order('full_name');
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

		async create(user: Omit<User, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('users')
				.insert(user)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<User>) {
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

// Initialize offline sync
if (browser) {
	// Sync on app load
	offline.syncOfflineData();
	
	// Sync when coming back online
	window.addEventListener('online', offline.syncOfflineData);
}
