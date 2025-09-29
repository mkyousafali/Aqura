import { writable } from 'svelte/store';

// Store for component discovery status
export const componentDiscovery = writable({
	isDiscovering: false,
	lastDiscovery: null,
	discoveredComponents: [],
	registeredFunctions: []
});

// API endpoints
const API_BASE = 'http://localhost:8080/api/v1/admin';

/**
 * Discover components from the filesystem and sync to database
 */
export async function discoverAndSyncComponents() {
	componentDiscovery.update(state => ({ 
		...state, 
		isDiscovering: true 
	}));

	try {
		const response = await fetch(`${API_BASE}/components/discover`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${localStorage.getItem('auth_token')}` // Adjust based on your auth system
			}
		});

		if (!response.ok) {
			throw new Error(`Discovery failed: ${response.statusText}`);
		}

		const data = await response.json();
		
		componentDiscovery.update(state => ({
			...state,
			isDiscovering: false,
			lastDiscovery: new Date().toISOString(),
			discoveredComponents: data.components || [],
			registeredFunctions: data.components?.flatMap(c => c.functions) || []
		}));

		return data;
	} catch (error) {
		componentDiscovery.update(state => ({ 
			...state, 
			isDiscovering: false 
		}));
		throw error;
	}
}

/**
 * Get discovered components without syncing to database
 */
export async function getDiscoveredComponents() {
	try {
		const response = await fetch(`${API_BASE}/components/discover`, {
			method: 'GET',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
			}
		});

		if (!response.ok) {
			throw new Error(`Failed to get components: ${response.statusText}`);
		}

		const data = await response.json();
		return data.components || [];
	} catch (error) {
		console.error('Error getting discovered components:', error);
		throw error;
	}
}

/**
 * Manually register a single component function
 */
export async function registerComponentFunction(functionData) {
	try {
		const response = await fetch(`${API_BASE}/components/register`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
			},
			body: JSON.stringify(functionData)
		});

		if (!response.ok) {
			throw new Error(`Registration failed: ${response.statusText}`);
		}

		const data = await response.json();
		return data;
	} catch (error) {
		console.error('Error registering component function:', error);
		throw error;
	}
}

/**
 * Auto-discover components based on current application structure
 * This function analyzes the actual component structure without backend
 */
export function analyzeLocalComponents() {
	const components = [];
	
	// Analyze main navigation components (from Sidebar.svelte)
	const masterComponents = [
		{
			name: 'Branch Master',
			code: 'BRANCH_MASTER',
			category: 'Master Data',
			description: 'Manage company branches and locations'
		},
		{
			name: 'HR Master', 
			code: 'HR_MASTER',
			category: 'Master Data',
			description: 'Human resources master data management'
		},
		{
			name: 'Task Master',
			code: 'TASK_MASTER', 
			category: 'Master Data',
			description: 'Task and workflow management'
		}
	];

	// Analyze HR sub-components (from HRMaster.svelte dashboardButtons)
	const hrSubComponents = [
		{
			name: 'Upload Employees',
			code: 'UPLOAD_EMPLOYEES',
			category: 'HR',
			description: 'Import employees from Excel files'
		},
		{
			name: 'Create Department',
			code: 'CREATE_DEPARTMENT',
			category: 'HR', 
			description: 'Create and manage departments'
		},
		{
			name: 'Create Level',
			code: 'CREATE_LEVEL',
			category: 'HR',
			description: 'Define organizational hierarchy levels'
		},
		{
			name: 'Create Position',
			code: 'CREATE_POSITION',
			category: 'HR',
			description: 'Set up job positions and roles'
		},
		{
			name: 'Reporting Map',
			code: 'REPORTING_MAP',
			category: 'HR',
			description: 'Define reporting relationships and hierarchy'
		},
		{
			name: 'Assign Positions',
			code: 'ASSIGN_POSITIONS',
			category: 'HR',
			description: 'Assign positions to employees'
		},
		{
			name: 'Upload Fingerprint',
			code: 'UPLOAD_FINGERPRINT',
			category: 'HR',
			description: 'Upload fingerprint transaction data'
		},
		{
			name: 'Contact Management',
			code: 'CONTACT_MANAGEMENT',
			category: 'HR',
			description: 'Manage employee contact information'
		},
		{
			name: 'Document Management',
			code: 'DOCUMENT_MANAGEMENT',
			category: 'HR',
			description: 'Manage employee documents and files'
		},
		{
			name: 'Salary Management',
			code: 'SALARY_MANAGEMENT',
			category: 'HR',
			description: 'Employee salary and allowances management'
		}
	];

	// Analyze User Management sub-components  
	const userMgmtComponents = [
		{
			name: 'Create User',
			code: 'CREATE_USER',
			category: 'Administration',
			description: 'Create new user accounts'
		},
		{
			name: 'Edit User',
			code: 'EDIT_USER',
			category: 'Administration',
			description: 'Modify existing user accounts'
		},
		{
			name: 'Assign Roles',
			code: 'ASSIGN_ROLES',
			category: 'Administration',
			description: 'Assign roles and permissions to users'
		},
		{
			name: 'Create User Roles',
			code: 'CREATE_USER_ROLES',
			category: 'Administration',
			description: 'Create and configure user roles with permissions'
		},
		{
			name: 'Manage Admin Users',
			code: 'MANAGE_ADMIN_USERS',
			category: 'Administration',
			description: 'Manage administrative user accounts'
		},
		{
			name: 'Manage Master Admin',
			code: 'MANAGE_MASTER_ADMIN',
			category: 'Administration',
			description: 'Manage master administrator accounts'
		}
	];

	// Core system functions
	const systemComponents = [
		{
			name: 'Dashboard Access',
			code: 'DASHBOARD',
			category: 'System',
			description: 'Main dashboard and navigation access'
		},
		{
			name: 'User Management',
			code: 'USER_MGMT',
			category: 'Administration',
			description: 'Manage user accounts and permissions'
		},
		{
			name: 'Work Management',
			code: 'WORK_MGMT',
			category: 'Operations',
			description: 'Work processes and task management'
		},
		{
			name: 'Reports',
			code: 'REPORTS',
			category: 'Reporting',
			description: 'Generate and view business reports'
		},
		{
			name: 'System Settings',
			code: 'SETTINGS',
			category: 'Administration',
			description: 'System configuration and preferences'
		}
	];

	return {
		masterData: masterComponents,
		hr: hrSubComponents,
		userManagement: userMgmtComponents,
		system: systemComponents,
		all: [...masterComponents, ...hrSubComponents, ...userMgmtComponents, ...systemComponents]
	};
}

/**
 * Get component structure for display
 */
export function getComponentStructure() {
	const analyzed = analyzeLocalComponents();
	
	return {
		categories: {
			'Master Data': analyzed.masterData,
			'HR': analyzed.hr,
			'Administration': analyzed.userManagement.concat(analyzed.system.filter(s => s.category === 'Administration')),
			'Operations': analyzed.system.filter(s => s.category === 'Operations'),
			'Reporting': analyzed.system.filter(s => s.category === 'Reporting'),
			'System': analyzed.system.filter(s => s.category === 'System')
		},
		totalCount: analyzed.all.length,
		summary: analyzed.all.reduce((acc, comp) => {
			acc[comp.category] = (acc[comp.category] || 0) + 1;
			return acc;
		}, {})
	};
}