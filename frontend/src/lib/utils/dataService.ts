/**
 * Data Service - Handles switching between mock and Supabase data
 * Provides unified interface for data operations with offline support
 */

import { db, offline, type Employee, type Branch, type Vendor, type User } from './supabase';
import { offlineDataManager } from './offlineDataManager';

// Configuration
const USE_SUPABASE = false; // Set to true when Supabase is configured
const MOCK_DATA_DELAY = 300; // Simulate network delay for mock data

// Mock data (same as before but exported for reuse)
const mockEmployees: Employee[] = [
	{
		id: '1',
		name: 'أحمد محمد الأحمد',
		email: 'ahmed.mohamed@aqura.sa',
		phone: '+966-50-123-4567',
		position: 'Senior Developer',
		department: 'IT',
		salary: 12000,
		hire_date: '2022-01-15',
		status: 'active',
		avatar_url: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
		branch_id: '1',
		created_at: '2022-01-15T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	},
	{
		id: '2',
		name: 'فاطمة علي السالم',
		email: 'fatima.ali@aqura.sa',
		phone: '+966-50-234-5678',
		position: 'Marketing Manager',
		department: 'Marketing',
		salary: 9500,
		hire_date: '2021-06-20',
		status: 'active',
		avatar_url: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face',
		branch_id: '1',
		created_at: '2021-06-20T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	},
	{
		id: '3',
		name: 'خالد عبدالله النصر',
		email: 'khalid.abdullah@aqura.sa',
		phone: '+966-50-345-6789',
		position: 'Sales Representative',
		department: 'Sales',
		salary: 7000,
		hire_date: '2023-03-10',
		status: 'on_leave',
		avatar_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
		branch_id: '2',
		created_at: '2023-03-10T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	}
];

const mockBranches: Branch[] = [
	{
		id: '1',
		name: 'الرياض المركزي',
		code: 'RYD-001',
		region: 'Central',
		address: 'شارع الملك فهد، الرياض 12345',
		phone: '+966-11-234-5678',
		email: 'riyadh@aqura.sa',
		manager_id: '1',
		employee_count: 25,
		status: 'active',
		established_date: '2020-01-15',
		created_at: '2020-01-15T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	},
	{
		id: '2',
		name: 'جدة الغربي',
		code: 'JED-001',
		region: 'Western',
		address: 'شارع التحلية، جدة 21452',
		phone: '+966-12-345-6789',
		email: 'jeddah@aqura.sa',
		employee_count: 18,
		status: 'active',
		established_date: '2020-03-20',
		created_at: '2020-03-20T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	},
	{
		id: '3',
		name: 'الدمام الشرقي',
		code: 'DMM-001',
		region: 'Eastern',
		address: 'شارع الملك سعود، الدمام 34217',
		phone: '+966-13-456-7890',
		email: 'dammam@aqura.sa',
		employee_count: 15,
		status: 'active',
		established_date: '2020-06-10',
		created_at: '2020-06-10T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	}
];

const mockVendors: Vendor[] = [
	{
		id: '1',
		name: 'محمد أحمد التجاري',
		company: 'شركة التقنية المتقدمة',
		email: 'mohammed@techadvanced.sa',
		phone: '+966-50-111-2222',
		category: 'Technology',
		status: 'active',
		payment_terms: '30 days',
		tax_id: '1234567890',
		registration_number: 'CR-12345678',
		address: 'الرياض، المملكة العربية السعودية',
		total_orders: 45,
		created_at: '2021-01-10T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	},
	{
		id: '2',
		name: 'سارة علي المكتبي',
		company: 'مؤسسة اللوازم المكتبية',
		email: 'sara@officesupplies.sa',
		phone: '+966-50-222-3333',
		category: 'Office Supplies',
		status: 'active',
		payment_terms: '15 days',
		tax_id: '2345678901',
		registration_number: 'CR-23456789',
		address: 'جدة، المملكة العربية السعودية',
		total_orders: 28,
		created_at: '2021-03-15T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	},
	{
		id: '3',
		name: 'عبدالرحمن صالح الصناعي',
		company: 'الشركة الصناعية الحديثة',
		email: 'abdulrahman@modernindustrial.sa',
		phone: '+966-50-333-4444',
		category: 'Manufacturing',
		status: 'pending',
		payment_terms: '45 days',
		tax_id: '3456789012',
		registration_number: 'CR-34567890',
		address: 'الدمام، المملكة العربية السعودية',
		total_orders: 12,
		created_at: '2023-11-20T00:00:00Z',
		updated_at: '2024-01-15T00:00:00Z'
	}
];

// Utility function to simulate network delay
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

// Unified data service interface
export const dataService = {
	// Employee operations
	employees: {
		async getAll(): Promise<{ data: Employee[] | null; error: any }> {
			if (USE_SUPABASE) {
				try {
					// Try to get fresh data from Supabase
					const result = await db.employees.getAll();
					
					// Cache the data for offline use
					if (result.data) {
						await offlineDataManager.cacheData('employees', result.data);
					}
					
					return result;
				} catch (error) {
					// Fallback to cached data if offline
					console.warn('Supabase failed, using cached data:', error);
					const cachedData = await offlineDataManager.getCachedData('employees');
					return { data: cachedData.length > 0 ? cachedData : mockEmployees, error: null };
				}
			} else {
				// Use mock data with simulated delay
				await delay(MOCK_DATA_DELAY);
				return { data: mockEmployees, error: null };
			}
		},

		async getById(id: string): Promise<{ data: Employee | null; error: any }> {
			if (USE_SUPABASE) {
				return await db.employees.getById(id);
			} else {
				await delay(MOCK_DATA_DELAY);
				const employee = mockEmployees.find(e => e.id === id);
				return { data: employee || null, error: employee ? null : 'Employee not found' };
			}
		},

		async create(employee: Omit<Employee, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: Employee | null; error: any }> {
			if (USE_SUPABASE) {
				const result = await db.employees.create(employee);
				
				// If offline, queue the operation
				if (!navigator.onLine && !result.data) {
					await offlineDataManager.addPendingOperation({
						type: 'employees',
						method: 'POST',
						data: employee
					});
				}
				
				return result;
			} else {
				await delay(MOCK_DATA_DELAY);
				const newEmployee: Employee = {
					...employee,
					id: Date.now().toString(),
					created_at: new Date().toISOString(),
					updated_at: new Date().toISOString()
				};
				mockEmployees.unshift(newEmployee);
				return { data: newEmployee, error: null };
			}
		},

		async update(id: string, updates: Partial<Employee>): Promise<{ data: Employee | null; error: any }> {
			if (USE_SUPABASE) {
				const result = await db.employees.update(id, updates);
				
				// If offline, queue the operation
				if (!navigator.onLine && !result.data) {
					await offlineDataManager.addPendingOperation({
						type: 'employees',
						method: 'PUT',
						data: { id, ...updates }
					});
				}
				
				return result;
			} else {
				await delay(MOCK_DATA_DELAY);
				const index = mockEmployees.findIndex(e => e.id === id);
				if (index !== -1) {
					mockEmployees[index] = { ...mockEmployees[index], ...updates, updated_at: new Date().toISOString() };
					return { data: mockEmployees[index], error: null };
				}
				return { data: null, error: 'Employee not found' };
			}
		},

		async delete(id: string): Promise<{ error: any }> {
			if (USE_SUPABASE) {
				const result = await db.employees.delete(id);
				
				// If offline, queue the operation
				if (!navigator.onLine && result.error) {
					await offlineDataManager.addPendingOperation({
						type: 'employees',
						method: 'DELETE',
						data: { id }
					});
				}
				
				return result;
			} else {
				await delay(MOCK_DATA_DELAY);
				const index = mockEmployees.findIndex(e => e.id === id);
				if (index !== -1) {
					mockEmployees.splice(index, 1);
					return { error: null };
				}
				return { error: 'Employee not found' };
			}
		}
	},

	// Branch operations
	branches: {
		async getAll(): Promise<{ data: Branch[] | null; error: any }> {
			if (USE_SUPABASE) {
				try {
					const result = await db.branches.getAll();
					if (result.data) {
						await offlineDataManager.cacheData('branches', result.data);
					}
					return result;
				} catch (error) {
					const cachedData = await offlineDataManager.getCachedData('branches');
					return { data: cachedData.length > 0 ? cachedData : mockBranches, error: null };
				}
			} else {
				await delay(MOCK_DATA_DELAY);
				return { data: mockBranches, error: null };
			}
		},

		async create(branch: Omit<Branch, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: Branch | null; error: any }> {
			if (USE_SUPABASE) {
				return await db.branches.create(branch);
			} else {
				await delay(MOCK_DATA_DELAY);
				const newBranch: Branch = {
					...branch,
					id: Date.now().toString(),
					created_at: new Date().toISOString(),
					updated_at: new Date().toISOString()
				};
				mockBranches.unshift(newBranch);
				return { data: newBranch, error: null };
			}
		},

		async update(id: string, updates: Partial<Branch>): Promise<{ data: Branch | null; error: any }> {
			if (USE_SUPABASE) {
				return await db.branches.update(id, updates);
			} else {
				await delay(MOCK_DATA_DELAY);
				const index = mockBranches.findIndex(b => b.id === id);
				if (index !== -1) {
					mockBranches[index] = { ...mockBranches[index], ...updates, updated_at: new Date().toISOString() };
					return { data: mockBranches[index], error: null };
				}
				return { data: null, error: 'Branch not found' };
			}
		},

		async delete(id: string): Promise<{ error: any }> {
			if (USE_SUPABASE) {
				return await db.branches.delete(id);
			} else {
				await delay(MOCK_DATA_DELAY);
				const index = mockBranches.findIndex(b => b.id === id);
				if (index !== -1) {
					mockBranches.splice(index, 1);
					return { error: null };
				}
				return { error: 'Branch not found' };
			}
		}
	},

	// Vendor operations  
	vendors: {
		async getAll(): Promise<{ data: Vendor[] | null; error: any }> {
			if (USE_SUPABASE) {
				try {
					const result = await db.vendors.getAll();
					if (result.data) {
						await offlineDataManager.cacheData('vendors', result.data);
					}
					return result;
				} catch (error) {
					const cachedData = await offlineDataManager.getCachedData('vendors');
					return { data: cachedData.length > 0 ? cachedData : mockVendors, error: null };
				}
			} else {
				await delay(MOCK_DATA_DELAY);
				return { data: mockVendors, error: null };
			}
		},

		async create(vendor: Omit<Vendor, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: Vendor | null; error: any }> {
			if (USE_SUPABASE) {
				return await db.vendors.create(vendor);
			} else {
				await delay(MOCK_DATA_DELAY);
				const newVendor: Vendor = {
					...vendor,
					id: Date.now().toString(),
					created_at: new Date().toISOString(),
					updated_at: new Date().toISOString()
				};
				mockVendors.unshift(newVendor);
				return { data: newVendor, error: null };
			}
		},

		async update(id: string, updates: Partial<Vendor>): Promise<{ data: Vendor | null; error: any }> {
			if (USE_SUPABASE) {
				return await db.vendors.update(id, updates);
			} else {
				await delay(MOCK_DATA_DELAY);
				const index = mockVendors.findIndex(v => v.id === id);
				if (index !== -1) {
					mockVendors[index] = { ...mockVendors[index], ...updates, updated_at: new Date().toISOString() };
					return { data: mockVendors[index], error: null };
				}
				return { data: null, error: 'Vendor not found' };
			}
		},

		async delete(id: string): Promise<{ error: any }> {
			if (USE_SUPABASE) {
				return await db.vendors.delete(id);
			} else {
				await delay(MOCK_DATA_DELAY);
				const index = mockVendors.findIndex(v => v.id === id);
				if (index !== -1) {
					mockVendors.splice(index, 1);
					return { error: null };
				}
				return { error: 'Vendor not found' };
			}
		}
	}
};

// Initialize offline data manager
if (typeof window !== 'undefined') {
	offlineDataManager.init().then(() => {
		offlineDataManager.setupNetworkListeners();
	});
}
