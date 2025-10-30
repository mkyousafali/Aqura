// Shared authentication types
export interface User {
	id: string;
	username: string;
	role: string;
	roleType: 'Master Admin' | 'Admin' | 'Position-based';
	userType: 'global' | 'branch_specific';
	avatar?: string;
	employeeName?: string;
	branchName?: string;
	employee_id?: string;
	branch_id?: string;
	lastLogin?: string;
	permissions?: UserPermissions;
}

export interface UserPermissions {
	[functionCode: string]: {
		can_view: boolean;
		can_add: boolean;
		can_edit: boolean;
		can_delete: boolean;
		can_export: boolean;
	};
}

export interface AuthSession {
	token: string;
	user: User;
	loginMethod: 'username' | 'quickAccess';
	loginTime: string;
	expiresAt: string;
}