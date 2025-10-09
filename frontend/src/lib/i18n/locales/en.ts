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
			description: 'AI-powered management system',
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
			master: 'Master',
			admin: 'Admin',
			user: 'User Interface',
			work: 'Work',
			reports: 'Reports',
			settings: 'Settings',
			finance: 'Finance',
			help: 'Help',
			logout: 'Sign Out',
			language: 'Language',
			languageToggle: 'Switch Language',
			english: 'English',
			arabic: 'العربية',
			goBack: 'Go back',
			goToDashboard: 'Go to dashboard',
			viewNotifications: 'View notifications',
			refreshNotifications: 'Refresh notifications'
		},

		// Mobile page titles
		mobile: {
			dashboard: 'Dashboard',
			tasks: 'Tasks',
			notifications: 'Notifications',
			assignments: 'Assignments',
			quickTask: 'Quick Task',
			assignTasks: 'Assign Tasks',
			createTask: 'Create Task',
			completeTask: 'Complete Task',
			taskDetails: 'Task Details',
			notification: 'Notification',
			assignmentDetails: 'Assignment Details',
			// Bottom navigation
			bottomNav: {
				tasks: 'Tasks',
				create: 'Assign',
				assignments: 'Assignments'
			},
			// Error messages
			error: {
				accessRequired: 'Access Required',
				loginRequired: 'Please log in to access the mobile interface.',
				goToLogin: 'Go to Mobile Login'
			},
			// Dashboard content
			dashboardContent: {
				stats: {
					pendingTasks: 'Pending Tasks',
					completed: 'Completed',
					notifications: 'Notifications',
					totalTasks: 'Total Tasks'
				},
				recentNotifications: {
					title: 'Recent Notifications',
					allInSystem: 'All notifications in system',
					yourRecent: 'Your recent notifications',
					noNotifications: 'No recent notifications'
				},
				actions: {
					createNotification: 'Create Notification',
					download: 'Download',
					source: 'Source'
				},
				labels: {
					sentBy: 'Sent by:',
					sentTo: 'Sent to:',
					attachments: 'Attachments',
					system: 'System',
					from: 'From:'
				}
			},
			// Tasks page content
			tasksContent: {
				title: 'My Tasks - Aqura Mobile',
				createTask: 'Create Task',
				searchPlaceholder: 'Search tasks...',
				filters: {
					allStatus: 'All Status',
					pending: 'Pending',
					inProgress: 'In Progress',
					completed: 'Completed',
					cancelled: 'Cancelled',
					allPriority: 'All Priority',
					high: 'High',
					medium: 'Medium',
					low: 'Low'
				},
				results: {
					tasksFound: 'tasks found',
					taskFound: 'task found'
				},
				loading: 'Loading tasks...',
				emptyState: {
					title: 'No tasks found',
					description: 'No tasks match your current filters, or you don\'t have any assigned tasks yet.'
				},
				taskCard: {
					quickTask: 'Quick Task',
					by: 'By',
					assigned: 'Assigned',
					unknown: 'Unknown',
					attachment: 'attachment',
					attachments: 'attachments',
					download: 'Download',
					downloadAll: 'Download All',
					markComplete: 'Mark Complete',
					viewDetails: 'View Details'
				}
			},
			// Task assignment page content
			assignContent: {
				title: 'Assign Tasks - Aqura Mobile',
				loading: 'Loading data...',
				steps: {
					users: 'Users',
					tasks: 'Tasks',
					settings: 'Settings',
					criteria: 'Criteria'
				},
				step1: {
					title: 'Select Users',
					description: 'Choose users to assign tasks to',
					searchPlaceholder: 'Search by name, username, email...',
					allBranches: 'All Branches'
				},
				step2: {
					title: 'Select Tasks',
					description: 'Choose tasks to assign',
					searchPlaceholder: 'Search tasks...',
					noDescription: 'No description'
				},
				step3: {
					title: 'Assignment Settings',
					description: 'Configure assignment options',
					notificationSettings: 'Notification Settings',
					sendNotifications: 'Send notifications to assignees',
					assignmentType: 'Assignment Type',
					oneTimeAssignment: 'One-time Assignment',
					recurringAssignment: 'Recurring Assignment',
					deadlineSettings: 'Deadline Settings',
					setDeadline: 'Set deadline for assignment',
					deadlineDate: 'Deadline Date',
					deadlineTime: 'Deadline Time',
					allowReassign: 'Allow users to reassign tasks',
					notifyAssignees: 'Notify assignees',
					additionalNotes: 'Additional Notes',
					specialInstructions: 'Add any special instructions...',
					// Repeat Settings
					repeatSettings: 'Repeat Settings',
					repeatType: 'Repeat Type',
					selectDays: 'Select Days',
					repeatEvery: 'Repeat every',
					daily: 'Daily',
					weekly: 'Weekly',
					weeklySpecific: 'Weekly (specific days)',
					monthly: 'Monthly',
					monthlySpecific: 'Monthly (specific date)',
					everyNDays: 'Every N Days',
					everyNWeeks: 'Every N Weeks',
					// Days of the week
					monday: 'Monday',
					tuesday: 'Tuesday',
					wednesday: 'Wednesday',
					thursday: 'Thursday',
					friday: 'Friday',
					saturday: 'Saturday',
					sunday: 'Sunday',
					// Day abbreviations
					mon: 'Mon',
					tue: 'Tue',
					wed: 'Wed',
					thu: 'Thu',
					fri: 'Fri',
					sat: 'Sat',
					sun: 'Sun',
					priorityOverride: 'Priority Override',
					defaultPriority: 'Use task default priority',
					high: 'High',
					medium: 'Medium',
					low: 'Low',
					additionalOptions: 'Additional Options',
					enableReassigning: 'Enable reassigning if user is unavailable',
					addNote: 'Add note for assignees'
				},
				step4: {
					title: 'Assignment Criteria',
					description: 'Set completion requirements',
					completionRequirements: 'Completion Requirements',
					requireTaskFinished: 'Task must be marked as finished',
					requirePhotoUpload: 'Photo upload required for completion',
					requireErpReference: 'ERP reference required',
					assignmentSummary: 'Assignment Summary',
					usersLabel: 'Users:',
					tasksLabel: 'Tasks:',
					typeLabel: 'Type:',
					deadlineLabel: 'Deadline:',
					oneTimeType: 'One-time',
					recurringType: 'Recurring',
					selectedUsers: 'selected',
					selectedTasks: 'selected'
				},
				actions: {
					cancel: 'Cancel',
					previous: 'Previous',
					nextStep: 'Next Step',
					assignTasks: 'Assign Tasks',
					assigning: 'Assigning...'
				},
				// Priority and Status translations
				priorities: {
					high: 'High',
					medium: 'Medium',
					low: 'Low'
				},
				statuses: {
					draft: 'Draft',
					active: 'Active',
					paused: 'Paused',
					completed: 'Completed',
					cancelled: 'Cancelled'
				}
			},

			// Create Task Content
			createContent: {
				title: 'Create Task - Aqura Mobile',
				taskTitle: 'Task Title',
				taskTitleRequired: 'Task title is required',
				taskTitlePlaceholder: 'Enter task title',
				description: 'Description',
				descriptionRequired: 'Description is required',
				descriptionPlaceholder: 'Describe the task',
				attachments: 'Attachments',
				camera: 'Camera',
				uploadFile: 'Upload file (optional)',
				chooseFiles: 'Choose files or drag and drop here',
				supportedFormats: 'Supported: images/pdf, doc, docx, xls, xlsx, txt, ppt • Max: 10MB',
				actions: {
					cancel: 'Cancel',
					createTask: 'Create Task',
					creating: 'Creating...'
				},
				errors: {
					titleRequired: 'Task title is required',
					descriptionRequired: 'Description is required',
					createFailed: 'Failed to create task',
					fillRequired: 'Please fill all required fields',
					fixFormErrors: 'Please fix the form errors before submitting.',
					createFailedTryAgain: 'Failed to create task. Please try again.'
				},
				success: {
					taskCreated: 'Task created successfully!'
				}
			},

			// Quick Task Content
			quickTaskContent: {
				title: 'Quick Task - Aqura Mobile',
				loading: 'Loading...',
				// Steps
				step1: {
					title: '1. Select Branch',
					branchLabel: 'Branch:',
					selectBranch: '-- Select Branch --',
					defaultBadge: 'Default',
					change: 'Change',
					confirm: '✓ Confirm',
					setAsDefault: 'Set as default branch'
				},
				step2: {
					title: '2. Select Users',
					usersLabel: 'Users:',
					selected: 'selected',
					change: 'Change',
					searchPlaceholder: 'Search users...',
					more: 'more',
					setAsDefault: 'Save these users as default',
					confirmUsers: '✓ Confirm Users'
				},
				step3: {
					title: '3. Task Details',
					issueType: 'Issue Type:',
					selectIssueType: '-- Select Issue Type --',
					customIssueType: 'Custom Issue Type:',
					customIssuePlaceholder: 'Enter custom issue type',
					priority: 'Priority:',
					description: 'Description (Optional):',
					descriptionPlaceholder: 'Enter task description...',
					saveAsDefault: 'Save these settings as default'
				},
				step4: {
					title: '4. Attachments (Optional)',
					chooseFiles: 'Choose Files',
					camera: 'Camera',
					removeFile: 'Remove File'
				},
				step5: {
					title: '5. Completion Requirements',
					requirePhoto: 'Require photo upload on completion',
					requireErp: 'Require ERP reference on completion',
					requireFile: 'Require file upload on completion'
				},
				// Issue Types
				issueTypes: {
					priceTag: 'Price Tag Issue',
					cleaning: 'Cleaning Issue',
					display: 'Display Issue',
					filling: 'Filling Issue',
					maintenance: 'Maintenance Issue',
					other: 'Other Issue'
				},
				// Priority Options
				priorities: {
					low: 'Low',
					medium: 'Medium',
					high: 'High',
					urgent: 'Urgent'
				},
				// Price Tag Options
				priceTags: {
					low: 'Low',
					medium: 'Medium',
					high: 'High',
					critical: 'Critical'
				},
				// Actions
				actions: {
					assignTask: 'Assign Task',
					creatingTask: 'Creating Task...'
				},
				// Success Messages
				success: {
					taskCreated: 'Task created successfully!'
				}
			},

			// Assignments Content
			assignmentsContent: {
				title: 'My Assignments - Aqura Mobile',
				loading: 'Loading assignments...',
				// Statistics
				stats: {
					total: 'Total',
					completed: 'Completed',
					inProgress: 'In Progress',
					pending: 'Pending',
					overdue: 'Overdue'
				},
				// Search and Filters
				search: {
					placeholder: 'Search tasks or users...',
					allStatuses: 'All Statuses',
					allPriorities: 'All Priorities',
					clearFilters: 'Clear Filters'
				},
				// Statuses
				statuses: {
					assigned: 'Assigned',
					inProgress: 'In Progress',
					completed: 'Completed',
					cancelled: 'Cancelled',
					escalated: 'Escalated',
					reassigned: 'Reassigned',
					unknown: 'Unknown'
				},
				// Priorities
				priorities: {
					high: 'High',
					medium: 'Medium',
					low: 'Low',
					urgent: 'Urgent'
				},
				// Task Details
				taskDetails: {
					unknownTask: 'Unknown Task',
					quickTask: '⚡ Quick Task',
					quickBadge: '⚡ QUICK',
					overdue: '⚠️ OVERDUE',
					description: 'Description:',
					notes: 'Notes:',
					attachments: '📎 Attachments',
					deadline: 'Deadline:',
					noDeadline: 'No deadline',
					assignedTo: 'Assigned to:',
					createdBy: 'Created by:',
					branch: 'Branch:',
					priceTag: 'Price Tag:',
					issueType: 'Issue Type:',
					status: 'Status:'
				},
				// Actions
				actions: {
					download: 'Download',
					viewDetails: 'View Details',
					markComplete: 'Mark Complete',
					updateStatus: 'Update Status'
				},
				// Empty States
				emptyStates: {
					noAssignments: 'No assignments found',
					noAssignmentsYet: 'You haven\'t assigned any tasks yet.',
					noMatchingFilters: 'No assignments match your current filters.'
				},
				// Footer
				footer: {
					showing: 'Showing',
					of: 'of',
					completionRate: 'Completion Rate:'
				}
			}
		},

		// Commands
		commands: {
			// Window management
			window: 'Window',
			minimizeAll: 'Minimize All Windows',
			minimizeAllDesc: 'Minimize all open windows',
			closeAll: 'Close All Windows',
			closeAllDesc: 'Close all open windows',
			showDesktop: 'Show Desktop',
			showDesktopDesc: 'Show desktop by minimizing all windows',
			// Admin functions
			manageBranches: 'Manage company branches',
			manageVendors: 'Manage vendors and suppliers',
			manageInvoices: 'Manage invoices and billing',
			manageUsers: 'Manage system users and roles',
			importData: 'Import data from Excel files',
			// Tools and help
			tools: 'Tools',
			help: 'Help & Documentation',
			helpDesc: 'View system documentation',
			helpCategory: 'Help',
			about: 'About Aqura',
			aboutDesc: 'System information and version',
			// UI
			searchPlaceholder: 'Type a command or search...',
			clearSearch: 'Clear search',
			noResults: 'No commands found',
			execute: 'Execute',
			close: 'Close'
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
			taskMaster: 'Task Master',
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
			subtitle: 'PWA-first windowed management platform',
			features: {
				multiWindow: 'Multi-window interface for enhanced productivity',
				offline: 'Offline capabilities for seamless work',
				responsive: 'Responsive design that adapts to any device',
				bilingual: 'Full bilingual support for English and Arabic'
			},
			instructions: 'Get started by exploring the features above or dive into the management modules'
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
			contactPhone: 'Contact Phone',
			// New fields for multilingual support
			createBranch: 'Create Branch',
			nameEnglish: 'Name (English)',
			nameArabic: 'Name (Arabic)',
			locationEnglish: 'Location (English)',
			locationArabic: 'Location (Arabic)',
			save: 'Save',
			cancel: 'Cancel',
			edit: 'Edit',
			update: 'Update',
			delete: 'Delete',
			active: 'Active',
			inactive: 'Inactive',
			mainBranch: 'Main Branch',
			createdAt: 'Created At',
			updatedAt: 'Updated At',
			actions: 'Actions'
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

		// Common Messages
		common: {
			confirmDelete: 'Are you sure you want to delete this item?',
			noData: 'No data available',
			status: 'Status',
			loading: 'Loading...',
			error: 'An error occurred'
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
