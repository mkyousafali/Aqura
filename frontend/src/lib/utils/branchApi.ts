/**
 * Branch API Service
 * Handles backend API calls for branch CRUD operations
 */

// Use environment variable or fallback to localhost
const API_BASE_URL = typeof window !== 'undefined' && window.location.hostname === 'localhost' 
	? 'http://localhost:8080/api/v1' 
	: 'http://localhost:8080/api/v1';
const BRANCHES_ENDPOINT = `${API_BASE_URL}/admin/branches`;

// Branch interface matching the schema
export interface Branch {
	id: string;
	name_en: string;
	name_ar: string;
	location_en: string;
	location_ar: string;
	is_active: boolean;
	is_main_branch: boolean;
	created_at?: string;
	updated_at?: string;
}

// Create branch request interface
export interface CreateBranchRequest {
	name_en: string;
	name_ar: string;
	location_en: string;
	location_ar: string;
	is_active: boolean;
	is_main_branch: boolean;
}

// Update branch request interface
export interface UpdateBranchRequest extends Partial<CreateBranchRequest> {}

// API Response wrapper
export interface ApiResponse<T> {
	data: T | null;
	error: string | null;
	status: number;
}

class BranchApiService {
	private async fetchWithErrorHandling<T>(
		url: string,
		options: RequestInit = {}
	): Promise<ApiResponse<T>> {
		try {
			const response = await fetch(url, {
				...options,
				headers: {
					'Content-Type': 'application/json',
					...options.headers,
				},
			});

			if (!response.ok) {
				const errorText = await response.text();
				throw new Error(`HTTP ${response.status}: ${errorText}`);
			}

			const data = await response.json();
			return {
				data,
				error: null,
				status: response.status,
			};
		} catch (error) {
			console.error('API Error:', error);
			return {
				data: null,
				error: error instanceof Error ? error.message : 'Unknown error occurred',
				status: 0,
			};
		}
	}

	// Get all branches
	async getAllBranches(): Promise<ApiResponse<Branch[]>> {
		return this.fetchWithErrorHandling<Branch[]>(BRANCHES_ENDPOINT, {
			method: 'GET',
		});
	}

	// Get branch by ID
	async getBranchById(id: string): Promise<ApiResponse<Branch>> {
		return this.fetchWithErrorHandling<Branch>(`${BRANCHES_ENDPOINT}/${id}`, {
			method: 'GET',
		});
	}

	// Create new branch
	async createBranch(branchData: CreateBranchRequest): Promise<ApiResponse<Branch>> {
		return this.fetchWithErrorHandling<Branch>(BRANCHES_ENDPOINT, {
			method: 'POST',
			body: JSON.stringify(branchData),
		});
	}

	// Update existing branch
	async updateBranch(id: string, branchData: UpdateBranchRequest): Promise<ApiResponse<Branch>> {
		return this.fetchWithErrorHandling<Branch>(`${BRANCHES_ENDPOINT}/${id}`, {
			method: 'PUT',
			body: JSON.stringify(branchData),
		});
	}

	// Delete branch
	async deleteBranch(id: string): Promise<ApiResponse<void>> {
		return this.fetchWithErrorHandling<void>(`${BRANCHES_ENDPOINT}/${id}`, {
			method: 'DELETE',
		});
	}
}

// Export singleton instance
export const branchApiService = new BranchApiService();