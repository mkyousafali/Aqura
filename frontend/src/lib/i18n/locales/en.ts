import type { LocaleData } from '../types';

export const englishLocale: LocaleData = {
	code: 'en',
	name: 'English',
	nativeName: 'English',
	direction: 'ltr',
	dateFormat: 'MM/dd/yyyy',
	timeFormat: 'HH:mm',
	currencyFormat: '$#,##0.00',
	numberFormat: {
		style: 'decimal',
		minimumFractionDigits: 0,
		maximumFractionDigits: 2
	},
	pluralRules: [
		{ count: 1, form: 'one' },
		{ count: 'other', form: 'other' }
	],
	translations: {
		// App General
		app: {
			name: 'Aqura Management System',
			shortName: 'Aqura',
			description: 'PWA-first windowed management platform',
			loading: 'Loading Aqura...',
			offline: 'You are currently offline',
			updateAvailable: 'New version available',
			updateReady: 'Update ready to install',
			updateNow: 'Update Now',
			updateLater: 'Later'
		},

		// Navigation & UI
		nav: {
			dashboard: 'Dashboard',
			admin: 'Admin',
			user: 'User Interface',
			settings: 'Settings',
			help: 'Help',
			logout: 'Sign Out'
		},

		// Window Management
		window: {
			minimize: 'Minimize',
			maximize: 'Maximize',
			restore: 'Restore',
			close: 'Close',
			duplicate: 'Duplicate',
			detach: 'Detach',
			newWindow: 'New Window',
			activeWindows: 'Active Windows',
			noWindows: 'No open windows'
		},

		// Authentication
		auth: {
			signIn: 'Sign In',
			signOut: 'Sign Out',
			signUp: 'Sign Up',
			email: 'Email Address',
			password: 'Password',
			confirmPassword: 'Confirm Password',
			forgotPassword: 'Forgot Password?',
			resetPassword: 'Reset Password',
			rememberMe: 'Remember me',
			invalidCredentials: 'Invalid email or password',
			accountLocked: 'Account is locked',
			mfaRequired: 'Multi-factor authentication required',
			mfaCode: 'Verification Code',
			changePassword: 'Change Password',
			newPassword: 'New Password',
			currentPassword: 'Current Password',
			passwordChanged: 'Password changed successfully',
			mustChangePassword: 'You must change your password before continuing'
		},

		// Admin Modules
		admin: {
			title: 'Administration',
			hrMaster: 'HR Master',
			branchesMaster: 'Branches Master',
			vendorsMaster: 'Vendors Master',
			invoiceMaster: 'Invoice Master',
			userRoles: 'User Roles',
			hierarchyMaster: 'Hierarchy Master',
			userManagement: 'User Management',
			importData: 'Import Data',
			auditLog: 'Audit Log',
			hr: {
				title: 'HR Master',
				subtitle: 'Manage employees and staff'
			}
		},

		// Welcome
		welcome: {
			title: 'Welcome to Aqura',
			subtitle: 'PWA-first windowed management platform'
		},

		// HR Master
		hr: {
			employee: 'Employee',
			employees: 'Employees',
			employeeId: 'Employee ID',
			firstName: 'First Name',
			lastName: 'Last Name',
			fullName: 'Full Name',
			email: 'Email',
			phone: 'Phone',
			department: 'Department',
			designation: 'Designation',
			status: 'Status',
			branch: 'Branch',
			manager: 'Manager',
			joinDate: 'Join Date',
			active: 'Active',
			inactive: 'Inactive',
			pending: 'Pending'
		},

		// Branches Master
		branches: {
			branch: 'Branch',
			branches: 'Branches',
			branchId: 'Branch ID',
			branchName: 'Branch Name',
			branchCode: 'Branch Code',
			region: 'Region',
			address: 'Address',
			timezone: 'Timezone',
			contactPerson: 'Contact Person',
			contactEmail: 'Contact Email',
			contactPhone: 'Contact Phone'
		},

		// Vendors Master
		vendors: {
			vendor: 'Vendor',
			vendors: 'Vendors',
			vendorId: 'Vendor ID',
			vendorName: 'Vendor Name',
			taxId: 'Tax ID',
			contactPerson: 'Contact Person',
			email: 'Email',
			phone: 'Phone',
			address: 'Address',
			paymentTerms: 'Payment Terms',
			category: 'Category'
		},

		// Invoice Master
		invoices: {
			invoice: 'Invoice',
			invoices: 'Invoices',
			invoiceNo: 'Invoice Number',
			vendor: 'Vendor',
			branch: 'Branch',
			date: 'Invoice Date',
			dueDate: 'Due Date',
			currency: 'Currency',
			subtotal: 'Subtotal',
			tax: 'Tax',
			total: 'Total',
			status: 'Status',
			draft: 'Draft',
			posted: 'Posted',
			paid: 'Paid',
			attachments: 'Attachments'
		},

		// Import System
		import: {
			title: 'Import Data',
			uploadFile: 'Upload File',
			selectFile: 'Select XLSX File',
			dragDrop: 'Drag and drop your file here',
			processing: 'Processing...',
			mapping: 'Column Mapping',
			preview: 'Preview Data',
			validation: 'Validation Results',
			errors: 'Errors',
			warnings: 'Warnings',
			valid: 'Valid Records',
			invalid: 'Invalid Records',
			commitChanges: 'Commit Changes',
			rollback: 'Rollback',
			importComplete: 'Import completed successfully',
			importFailed: 'Import failed',
			recordsProcessed: 'records processed',
			recordsCommitted: 'records committed',
			recordsFailed: 'records failed'
		},

		// Common Actions
		actions: {
			add: 'Add',
			edit: 'Edit',
			delete: 'Delete',
			save: 'Save',
			cancel: 'Cancel',
			confirm: 'Confirm',
			yes: 'Yes',
			no: 'No',
			ok: 'OK',
			apply: 'Apply',
			reset: 'Reset',
			clear: 'Clear',
			search: 'Search',
			filter: 'Filter',
			sort: 'Sort',
			export: 'Export',
			import: 'Import',
			upload: 'Upload',
			download: 'Download',
			print: 'Print',
			refresh: 'Refresh',
			back: 'Back',
			next: 'Next',
			previous: 'Previous',
			continue: 'Continue',
			finish: 'Finish'
		},

		// Status Messages
		status: {
			success: 'Success',
			error: 'Error',
			warning: 'Warning',
			info: 'Information',
			loading: 'Loading...',
			saving: 'Saving...',
			processing: 'Processing...',
			complete: 'Complete',
			failed: 'Failed',
			cancelled: 'Cancelled',
			pending: 'Pending'
		},

		// Validation Messages
		validation: {
			required: 'This field is required',
			email: 'Please enter a valid email address',
			phone: 'Please enter a valid phone number',
			minLength: 'Minimum {min} characters required',
			maxLength: 'Maximum {max} characters allowed',
			numeric: 'Please enter a valid number',
			date: 'Please enter a valid date',
			passwordMismatch: 'Passwords do not match',
			weakPassword: 'Password is too weak',
			invalidFormat: 'Invalid format',
			duplicateValue: 'This value already exists',
			invalidRange: 'Value must be between {min} and {max}'
		},

		// Empty States
		empty: {
			noData: 'No data available',
			noResults: 'No results found',
			noFiles: 'No files uploaded',
			noWindows: 'No windows open',
			noNotifications: 'No notifications',
			noHistory: 'No history available',
			tryAgain: 'Try again',
			getStarted: 'Get started by adding your first item'
		}
	}
};
