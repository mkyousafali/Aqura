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

// Auto-sign in for development (remove in production)
if (browser) {
	supabase.auth.getSession().then(({ data: { session } }) => {
		if (!session) {
			console.log('No session found, attempting to sign in with demo account...');
			// You can create a demo account in Supabase for testing
			// For now, we'll handle this in the RLS policies
		}
	});
}

// Database types based on our models
export interface Branch {
	id: string;
	branch_id?: string; // Auto-generated BR001, HB001, etc.
	name: string;        // Branch Name (English)
	name_ar?: string;    // Branch Name (Arabic)
	code: string;        // Branch Code
	region: string;      // City (English)
	region_ar?: string;  // City (Arabic)
	branch_type: 'branch' | 'head_branch'; // Branch Type
	status: 'active' | 'inactive' | 'pending';
	created_at: string;
	updated_at: string;
}

export interface Vendor {
	id: string;
	erp_vendor_code?: string; // ERP Vendor Code
	name: string; // Contact Person Name
	company: string; // Company Name
	vat_number?: string;
	category?: string;
	status?: 'active' | 'inactive' | 'pending';
	created_at?: string;
	updated_at?: string;
}

export interface VendorContact {
	id: string;
	vendor_id: string;
	name: string;
	position: string;
	phone: string;
	email: string;
	is_primary: boolean;
	created_at: string;
	updated_at: string;
}

export interface VendorPaymentMethod {
	id: string;
	vendor_id: string;
	branch_id: string;
	payment_terms?: string;
	payment_method?: 'cpod' | 'bpod' | 'credit';
	credit_period?: number;
	cash_later?: boolean;
	bank_later?: boolean;
	bank_name?: string;
	iban?: string;
	notes?: string;
	created_at?: string;
	updated_at?: string;
	// Optional joined data
	vendors?: {
		id: string;
		erp_vendor_code?: string;
		name: string;
		company: string;
	};
	branches?: {
		id: string;
		code: string;
		name: string;
		name_ar?: string;
	};
}

export interface VendorVisit {
	id: string;
	vendor_id: string;
	branch_id: string;
	start_date: string;
	visit_interval_days: number;
	status: 'active' | 'paused' | 'cancelled';
	notes?: string;
	created_at: string;
	updated_at: string;
}

export interface VendorVisitLog {
	id: string;
	vendor_visit_id: string;
	scheduled_date: string;
	actual_date?: string;
	status: 'scheduled' | 'completed' | 'missed' | 'skipped';
	notes?: string;
	created_by?: string;
	created_at: string;
	updated_at: string;
}

export interface VendorContract {
	id: string;
	vendor_id: string;
	title: string;
	contract_type: 'main' | 'special';
	start_date: string;
	end_date?: string;
	value?: number;
	currency?: string;
	status: 'draft' | 'active' | 'expired' | 'terminated';
	terms?: string;
	file_path?: string;
	created_at: string;
	updated_at: string;
}

export interface VendorRemark {
	id: string;
	vendor_id: string;
	branch_id?: string;
	remark_date: string;
	category: 'general' | 'quality' | 'delivery' | 'service' | 'pricing';
	content: string;
	rating?: number; // 1-5 scale
	assigned_employee_id?: string;
	task_description?: string;
	task_status: 'pending' | 'in_progress' | 'completed' | 'cancelled';
	task_due_date?: string;
	created_by?: string;
	created_at: string;
	updated_at: string;
}

export interface VendorDocument {
	id: string;
	vendor_id: string;
	name: string;
	type: string;
	file_path: string;
	file_size: number;
	uploaded_by?: string;
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
				.order('first_name');
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
				.eq('status', 'active')
				.order('first_name');
			return { data, error };
		},

		// Excel upload function for simplified employee data
		async uploadFromExcel(employeeData: {
			employee_id: string;
			first_name: string;
			branch_id: string;
		}[]) {
			try {
				console.log('🔄 Starting employee upload to Supabase:', employeeData.length, 'records');
				console.log('📋 Raw input data sample:', employeeData.slice(0, 3));
				
				// Enhanced data validation and cleaning
				const cleanedData = employeeData.map((emp, index) => {
					const cleaned = {
						branch_id: emp.branch_id?.trim(),
						employee_id: emp.employee_id?.toString().trim(),
						first_name: emp.first_name?.toString().trim(),
						status: 'active' as const,
						original_index: index
					};
					
					// Log problematic records
					if (!cleaned.employee_id || !cleaned.first_name || !cleaned.branch_id) {
						console.warn(`⚠️ Record ${index + 1} has missing data:`, {
							employee_id: cleaned.employee_id || 'MISSING',
							first_name: cleaned.first_name || 'MISSING', 
							branch_id: cleaned.branch_id || 'MISSING'
						});
					}
					
					return cleaned;
				});

				// Filter out invalid records and show what we're removing
				const validData = cleanedData.filter((emp, index) => {
					const isValid = emp.employee_id && emp.first_name && emp.branch_id && 
									emp.employee_id.length > 0 && emp.first_name.length > 0;
					if (!isValid) {
						console.error(`❌ Removing invalid record ${index + 1}:`, emp);
					}
					return isValid;
				});

				console.log(`✅ Data validation: ${validData.length}/${employeeData.length} records are valid`);
				
				// Check for duplicate employee IDs within the batch
				const employeeIds = validData.map(emp => emp.employee_id);
				const duplicates = employeeIds.filter((id, index) => employeeIds.indexOf(id) !== index);
				if (duplicates.length > 0) {
					console.warn('⚠️ Duplicate employee IDs found in batch:', [...new Set(duplicates)]);
				}

				// Prepare data for bulk insert (remove original_index)
				const employeesToInsert = validData.map(emp => ({
					branch_id: emp.branch_id,
					employee_id: emp.employee_id,
					first_name: emp.first_name,
					status: emp.status
				}));

				console.log('📊 Final prepared employee data:', employeesToInsert.slice(0, 3));
				console.log('📊 Sample employee IDs:', employeesToInsert.slice(0, 5).map(e => e.employee_id));

				// Use bulk insert with upsert (ON CONFLICT DO UPDATE)
				console.log('📤 Attempting bulk insert...');
				const { data, error } = await supabase
					.from('employees')
					.upsert(employeesToInsert, { 
						onConflict: 'employee_id,branch_id',
						ignoreDuplicates: false 
					})
					.select('id, employee_id, first_name');
				
				console.log('📝 Supabase bulk response:', { data, error });
				console.log('📊 Bulk result summary:', {
					attempted: employeesToInsert.length,
					returned_data_count: data?.length || 0,
					has_error: !!error
				});
				
				if (error) {
					console.error('❌ Bulk upload error details:', {
						message: error.message,
						details: error.details,
						hint: error.hint,
						code: error.code
					});
					
					// If bulk fails, try individual inserts with better error reporting
					console.log('🔄 Bulk failed, trying individual inserts...');
					const results = [];
					for (let i = 0; i < validData.length; i++) {
						const emp = validData[i];
						try {
							console.log(`🔄 Individual insert ${i + 1}/${validData.length}: ${emp.employee_id} - ${emp.first_name}`);
							const { data: singleData, error: singleError } = await supabase
								.from('employees')
								.upsert({
									branch_id: emp.branch_id,
									employee_id: emp.employee_id,
									first_name: emp.first_name,
									status: 'active' as const
								}, { 
									onConflict: 'employee_id,branch_id',
									ignoreDuplicates: false 
								})
								.select('id, employee_id, first_name')
								.single();
							
							if (singleError) {
								console.error(`❌ Individual insert failed for ${emp.employee_id}:`, {
									message: singleError.message,
									details: singleError.details,
									hint: singleError.hint,
									code: singleError.code,
									employee_data: emp
								});
								results.push({ 
									employee: emp.employee_id, 
									success: false, 
									error: `${singleError.message} (${singleError.code || 'unknown'})`,
									row_number: emp.original_index + 1
								});
							} else {
								console.log(`✅ Individual insert success for ${emp.employee_id}:`, singleData);
								results.push({ 
									employee: emp.employee_id, 
									success: true, 
									id: singleData?.id,
									row_number: emp.original_index + 1
								});
							}
						} catch (err) {
							console.error(`🔥 Individual insert exception for ${emp.employee_id}:`, err);
							results.push({ 
								employee: emp.employee_id, 
								success: false, 
								error: (err as Error).message,
								row_number: emp.original_index + 1
							});
						}
					}
					return { data: results, error: null };
				} else {
					// Bulk insert was successful
					console.log('✅ Bulk insert successful:', data);
					const results = data?.map((insertedEmployee, index) => ({
						employee: insertedEmployee.employee_id, 
						success: true, 
						id: insertedEmployee.id,
						row_number: validData[index]?.original_index + 1 || index + 1
					})) || [];
					
					// Add any records that were filtered out as failed
					const failedRecords = employeeData.length - validData.length;
					if (failedRecords > 0) {
						console.log(`⚠️ ${failedRecords} records were filtered out due to validation errors`);
					}
					
					return { data: results, error: null };
				}
			} catch (error) {
				console.error('🔥 Upload function exception:', error);
				return { data: null, error: error };
			}
		},

		// Bulk insert function for Excel data
		async bulkInsert(employees: Omit<Employee, 'id' | 'created_at' | 'updated_at'>[]) {
			const { data, error } = await supabase
				.from('employees')
				.insert(employees)
				.select();
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
		},

		// Excel upload function
		async uploadFromExcel(vendorData: {
			erp_vendor_code: string;
			vendor_name_english?: string;
			vendor_name_arabic?: string;
			vat_number?: string;
		}[]) {
			try {
				const results = [];
				
				// Prepare data for bulk insert
				const vendorsToInsert = vendorData.map(vendor => ({
					erp_vendor_code: vendor.erp_vendor_code,
					name: vendor.vendor_name_english || vendor.vendor_name_arabic || 'Unknown',
					name_ar: vendor.vendor_name_arabic || null,
					vat_number: vendor.vat_number || null,
					company: vendor.vendor_name_english || vendor.vendor_name_arabic || 'Unknown Company',
					tax_id: vendor.vat_number || null,
					category: 'General',
					status: 'active' as const,
					email: '',
					phone: '',
					payment_terms: 'Net 30',
					registration_number: '',
					address: '',
					total_orders: 0
				}));

				// Use bulk insert with upsert (ON CONFLICT DO UPDATE)
				const { data, error } = await supabase
					.from('vendors')
					.upsert(vendorsToInsert, { 
						onConflict: 'erp_vendor_code',
						ignoreDuplicates: false 
					})
					.select('id, erp_vendor_code');
				
				if (error) {
					console.error('Bulk upload error:', error);
					// If bulk fails, try individual inserts
					for (const vendor of vendorData) {
						try {
							const { data: singleData, error: singleError } = await supabase
								.from('vendors')
								.upsert({
									erp_vendor_code: vendor.erp_vendor_code,
									name: vendor.vendor_name_english || vendor.vendor_name_arabic || 'Unknown',
									name_ar: vendor.vendor_name_arabic || null,
									vat_number: vendor.vat_number || null,
									company: vendor.vendor_name_english || vendor.vendor_name_arabic || 'Unknown Company',
									tax_id: vendor.vat_number || null,
									category: 'General',
									status: 'active' as const,
									email: '',
									phone: '',
									payment_terms: 'Net 30',
									registration_number: '',
									address: '',
									total_orders: 0
								}, { 
									onConflict: 'erp_vendor_code',
									ignoreDuplicates: false 
								})
								.select('id, erp_vendor_code')
								.single();
							
							if (singleError) {
								results.push({ 
									vendor: vendor.erp_vendor_code, 
									success: false, 
									error: singleError.message 
								});
							} else {
								results.push({ 
									vendor: vendor.erp_vendor_code, 
									success: true, 
									id: singleData?.id 
								});
							}
						} catch (err) {
							results.push({ 
								vendor: vendor.erp_vendor_code, 
								success: false, 
								error: (err as Error).message 
							});
						}
					}
				} else {
					// Bulk insert was successful
					data?.forEach((insertedVendor) => {
						results.push({ 
							vendor: insertedVendor.erp_vendor_code, 
							success: true, 
							id: insertedVendor.id 
						});
					});
				}
				
				return { data: results, error: null };
			} catch (error) {
				console.error('Upload function error:', error);
				return { data: null, error: error };
			}
		},

		// Bulk insert function for Excel data
		async bulkInsert(vendors: Omit<Vendor, 'id' | 'created_at' | 'updated_at'>[]) {
			const { data, error } = await supabase
				.from('vendors')
				.insert(vendors)
				.select();
			return { data, error };
		}
	},

	// Vendor contacts operations
	vendorContacts: {
		async getByVendor(vendorId: string) {
			const { data, error } = await supabase
				.from('vendor_contacts')
				.select('*')
				.eq('vendor_id', vendorId)
				.order('is_primary', { ascending: false });
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('vendor_contacts')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(contact: Omit<VendorContact, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('vendor_contacts')
				.insert(contact)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<VendorContact>) {
			const { data, error } = await supabase
				.from('vendor_contacts')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('vendor_contacts')
				.delete()
				.eq('id', id);
			return { error };
		}
	},

	// Vendor payment methods operations
	vendorPaymentMethods: {
		async getAll() {
			const { data, error } = await supabase
				.from('vendor_payment_methods')
				.select(`
					*,
					vendors(id, erp_vendor_code, name, company),
					branches(id, code, name, name_ar)
				`)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async getByVendor(vendorId: string) {
			const { data, error } = await supabase
				.from('vendor_payment_methods')
				.select(`
					*,
					vendors(id, erp_vendor_code, name, company),
					branches(id, code, name, name_ar)
				`)
				.eq('vendor_id', vendorId)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async getByBranch(branchId: string) {
			const { data, error } = await supabase
				.from('vendor_payment_methods')
				.select(`
					*,
					vendors(id, erp_vendor_code, name, company),
					branches(id, code, name, name_ar)
				`)
				.eq('branch_id', branchId)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async getByVendorAndBranch(vendorId: string, branchId: string) {
			const { data, error } = await supabase
				.from('vendor_payment_methods')
				.select(`
					*,
					vendors(id, erp_vendor_code, name, company),
					branches(id, code, name, name_ar)
				`)
				.eq('vendor_id', vendorId)
				.eq('branch_id', branchId)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('vendor_payment_methods')
				.select(`
					*,
					vendors(id, erp_vendor_code, name, company),
					branches(id, code, name, name_ar)
				`)
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(paymentMethod: Omit<VendorPaymentMethod, 'id' | 'created_at' | 'updated_at' | 'vendors' | 'branches'>) {
			const { data, error } = await supabase
				.from('vendor_payment_methods')
				.insert(paymentMethod)
				.select(`
					*,
					vendors(id, erp_vendor_code, name, company),
					branches(id, code, name, name_ar)
				`)
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<Omit<VendorPaymentMethod, 'id' | 'created_at' | 'updated_at' | 'vendors' | 'branches'>>) {
			const { data, error } = await supabase
				.from('vendor_payment_methods')
				.update(updates)
				.eq('id', id)
				.select(`
					*,
					vendors(id, erp_vendor_code, name, company),
					branches(id, code, name, name_ar)
				`)
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('vendor_payment_methods')
				.delete()
				.eq('id', id);
			return { error };
		}
	},

	// Vendor visits operations
	vendorVisits: {
		async getByVendor(vendorId: string) {
			const { data, error } = await supabase
				.from('vendor_visits')
				.select(`
					*,
					branches(name),
					vendors(company)
				`)
				.eq('vendor_id', vendorId)
				.order('start_date', { ascending: false });
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('vendor_visits')
				.select(`
					*,
					branches(name),
					vendors(company)
				`)
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(visit: Omit<VendorVisit, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('vendor_visits')
				.insert(visit)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<VendorVisit>) {
			const { data, error } = await supabase
				.from('vendor_visits')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('vendor_visits')
				.delete()
				.eq('id', id);
			return { error };
		},

		async getByBranch(branchId: string) {
			const { data, error } = await supabase
				.from('vendor_visits')
				.select(`
					*,
					vendors(company, name)
				`)
				.eq('branch_id', branchId)
				.eq('status', 'active')
				.order('start_date');
			return { data, error };
		}
	},

	// Vendor visit logs operations
	vendorVisitLogs: {
		async getByVisit(vendorVisitId: string) {
			const { data, error } = await supabase
				.from('vendor_visit_logs')
				.select('*')
				.eq('vendor_visit_id', vendorVisitId)
				.order('scheduled_date', { ascending: false });
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('vendor_visit_logs')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(log: Omit<VendorVisitLog, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('vendor_visit_logs')
				.insert(log)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<VendorVisitLog>) {
			const { data, error } = await supabase
				.from('vendor_visit_logs')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('vendor_visit_logs')
				.delete()
				.eq('id', id);
			return { error };
		},

		async getUpcoming(limit: number = 10) {
			const today = new Date().toISOString().split('T')[0];
			const { data, error } = await supabase
				.from('vendor_visit_logs')
				.select(`
					*,
					vendor_visits(
						vendors(company, name),
						branches(name)
					)
				`)
				.gte('scheduled_date', today)
				.eq('status', 'scheduled')
				.order('scheduled_date')
				.limit(limit);
			return { data, error };
		}
	},

	// Vendor contracts operations
	vendorContracts: {
		async getByVendor(vendorId: string) {
			const { data, error } = await supabase
				.from('vendor_contracts')
				.select('*')
				.eq('vendor_id', vendorId)
				.order('start_date', { ascending: false });
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('vendor_contracts')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(contract: Omit<VendorContract, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('vendor_contracts')
				.insert(contract)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<VendorContract>) {
			const { data, error } = await supabase
				.from('vendor_contracts')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('vendor_contracts')
				.delete()
				.eq('id', id);
			return { error };
		},

		async getExpiring(days: number = 30) {
			const futureDate = new Date();
			futureDate.setDate(futureDate.getDate() + days);
			
			const { data, error } = await supabase
				.from('vendor_contracts')
				.select(`
					*,
					vendors(company, name)
				`)
				.lte('end_date', futureDate.toISOString().split('T')[0])
				.eq('status', 'active')
				.order('end_date');
			return { data, error };
		}
	},

	// Vendor remarks operations
	vendorRemarks: {
		async getByVendor(vendorId: string) {
			const { data, error } = await supabase
				.from('vendor_remarks')
				.select(`
					*,
					branches(name),
					employees(first_name)
				`)
				.eq('vendor_id', vendorId)
				.order('remark_date', { ascending: false });
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('vendor_remarks')
				.select(`
					*,
					branches(name),
					employees(first_name)
				`)
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(remark: Omit<VendorRemark, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('vendor_remarks')
				.insert(remark)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<VendorRemark>) {
			const { data, error } = await supabase
				.from('vendor_remarks')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('vendor_remarks')
				.delete()
				.eq('id', id);
			return { error };
		},

		async getByBranch(branchId: string) {
			const { data, error } = await supabase
				.from('vendor_remarks')
				.select(`
					*,
					vendors(company, name),
					employees(first_name)
				`)
				.eq('branch_id', branchId)
				.order('remark_date', { ascending: false });
			return { data, error };
		},

		async getTasksByEmployee(employeeId: string) {
			const { data, error } = await supabase
				.from('vendor_remarks')
				.select(`
					*,
					vendors(company, name),
					branches(name)
				`)
				.eq('assigned_employee_id', employeeId)
				.neq('task_status', 'completed')
				.order('task_due_date');
			return { data, error };
		}
	},

	// Vendor documents operations
	vendorDocuments: {
		async getByVendor(vendorId: string) {
			const { data, error } = await supabase
				.from('vendor_documents')
				.select('*')
				.eq('vendor_id', vendorId)
				.order('created_at', { ascending: false });
			return { data, error };
		},

		async getById(id: string) {
			const { data, error } = await supabase
				.from('vendor_documents')
				.select('*')
				.eq('id', id)
				.single();
			return { data, error };
		},

		async create(document: Omit<VendorDocument, 'id' | 'created_at' | 'updated_at'>) {
			const { data, error } = await supabase
				.from('vendor_documents')
				.insert(document)
				.select()
				.single();
			return { data, error };
		},

		async update(id: string, updates: Partial<VendorDocument>) {
			const { data, error } = await supabase
				.from('vendor_documents')
				.update(updates)
				.eq('id', id)
				.select()
				.single();
			return { data, error };
		},

		async delete(id: string) {
			const { error } = await supabase
				.from('vendor_documents')
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
			const [employees, branches, vendors, users, vendorPaymentMethods, vendorRemarks] = await Promise.all([
				db.employees.getAll(),
				db.branches.getAll(),
				db.vendors.getAll(),
				db.users.getAll(),
				db.vendorPaymentMethods.getAll(),
				supabase.from('vendor_remarks').select('*')
			]);

			// Store in local cache (IndexedDB via our offline manager)
			if (employees.data) localStorage.setItem('cache:employees', JSON.stringify(employees.data));
			if (branches.data) localStorage.setItem('cache:branches', JSON.stringify(branches.data));
			if (vendors.data) localStorage.setItem('cache:vendors', JSON.stringify(vendors.data));
			if (users.data) localStorage.setItem('cache:users', JSON.stringify(users.data));
			if (vendorPaymentMethods.data) localStorage.setItem('cache:vendor_payment_methods', JSON.stringify(vendorPaymentMethods.data));
			if (vendorRemarks.data) localStorage.setItem('cache:vendor_remarks', JSON.stringify(vendorRemarks.data));

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
