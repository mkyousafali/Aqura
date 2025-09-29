import { writable } from 'svelte/store';
import { userAuth } from '../utils/userAuth';

// Check if we're in browser environment
const isBrowser = typeof window !== 'undefined';

// Types for authentication
export interface User {
	id: string;
	username: string;
	role: string;
	roleType: 'Master Admin' | 'Admin' | 'Position-based';
	userType: 'global' | 'branch_specific';
	avatar?: string;
	employeeName?: string;
	branchName?: string;
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

// Authentication store
function createAuthStore() {
	const { subscribe, set, update } = writable<AuthSession | null>(null);

	return {
		subscribe,
		// Initialize auth state from localStorage
		init: async () => {
			if (!isBrowser) return;
			
			try {
				const token = localStorage.getItem('aqura-auth-token');
				const userStr = localStorage.getItem('aqura-user');
				const sessionStr = localStorage.getItem('aqura-session');
				
				if (token && userStr && sessionStr) {
					const user = JSON.parse(userStr);
					const session = JSON.parse(sessionStr);
					
					// Check if session is still valid (client-side check)
					if (new Date(session.expiresAt) > new Date()) {
						// Also validate with database
						const validUser = await userAuth.validateSession(token);
						
						if (validUser) {
							set({
								token,
								user: validUser, // Use the validated user data
								...session
							});
						} else {
							// Session invalid, clear storage
							localStorage.removeItem('aqura-auth-token');
							localStorage.removeItem('aqura-user');
							localStorage.removeItem('aqura-session');
						}
					} else {
						// Session expired, clear storage
						localStorage.removeItem('aqura-auth-token');
						localStorage.removeItem('aqura-user');
						localStorage.removeItem('aqura-session');
					}
				}
			} catch (error) {
				console.error('Error initializing auth:', error);
				// Clear potentially corrupted data
				if (isBrowser) {
					localStorage.removeItem('aqura-auth-token');
					localStorage.removeItem('aqura-user');
					localStorage.removeItem('aqura-session');
				}
			}
		},
		
		// Login with username/password
		loginWithCredentials: async (username: string, password: string, rememberMe: boolean = false) => {
			try {
				// Use real authentication service
				const { user, token } = await userAuth.loginWithCredentials(username, password);
				
				const expiresAt = new Date();
				expiresAt.setHours(expiresAt.getHours() + (rememberMe ? 720 : 24)); // 30 days or 24 hours
				
				const session: AuthSession = {
					token,
					user,
					loginMethod: 'username',
					loginTime: new Date().toISOString(),
					expiresAt: expiresAt.toISOString()
				};
				
				// Store in localStorage
				if (isBrowser) {
					localStorage.setItem('aqura-auth-token', session.token);
					localStorage.setItem('aqura-user', JSON.stringify(session.user));
					localStorage.setItem('aqura-session', JSON.stringify({
						loginMethod: session.loginMethod,
						loginTime: session.loginTime,
						expiresAt: session.expiresAt
					}));
				}
				
				set(session);
				return { success: true, user };
			} catch (error) {
				console.error('Login error:', error);
				throw new Error(error.message || 'Login failed');
			}
		},
		
		// Login with quick access code
		loginWithQuickAccess: async (quickAccessCode: string) => {
			try {
				// Use real authentication service
				const { user, token } = await userAuth.loginWithQuickAccess(quickAccessCode);
				
				const expiresAt = new Date();
				expiresAt.setHours(expiresAt.getHours() + 8); // 8 hours for quick access
				
				const session: AuthSession = {
					token,
					user,
					loginMethod: 'quickAccess',
					loginTime: new Date().toISOString(),
					expiresAt: expiresAt.toISOString()
				};
				
				// Store in localStorage
				if (isBrowser) {
					localStorage.setItem('aqura-auth-token', session.token);
					localStorage.setItem('aqura-user', JSON.stringify(session.user));
					localStorage.setItem('aqura-session', JSON.stringify({
						loginMethod: session.loginMethod,
						loginTime: session.loginTime,
						expiresAt: session.expiresAt
					}));
				}
				
				set(session);
				return { success: true, user };
			} catch (error) {
				console.error('Quick access error:', error);
				throw new Error(error.message || 'Quick access failed');
			}
		},
		
		// Logout
		logout: async () => {
			console.log('Auth store logout called');
			
			let currentSession: AuthSession | null = null;
			update(session => {
				currentSession = session;
				return session;
			});

			// End session in database
			if (currentSession?.token) {
				try {
					await userAuth.logout(currentSession.token);
				} catch (error) {
					console.error('Error ending session in database:', error);
				}
			}

			if (isBrowser) {
				console.log('Clearing localStorage items...');
				localStorage.removeItem('aqura-auth-token');
				localStorage.removeItem('aqura-user');
				localStorage.removeItem('aqura-session');
				console.log('localStorage cleared');
			}
			console.log('Setting auth state to null');
			set(null);
			console.log('Logout completed');
		},
		
		// Update user data
		updateUser: (userData: Partial<User>) => {
			update(session => {
				if (session) {
					session.user = { ...session.user, ...userData };
					if (isBrowser) {
						localStorage.setItem('aqura-user', JSON.stringify(session.user));
					}
				}
				return session;
			});
		},
		
		// Check if user has permission for a specific function
		hasPermission: (functionCode: string, action: 'view' | 'add' | 'edit' | 'delete' | 'export'): boolean => {
			let hasPermission = false;
			update(session => {
				if (session?.user?.permissions?.[functionCode]) {
					const permission = session.user.permissions[functionCode];
					hasPermission = permission[`can_${action}`] || false;
				} else if (session?.user?.roleType === 'Master Admin') {
					// Master Admin has all permissions
					hasPermission = true;
				}
				return session;
			});
			return hasPermission;
		},
		
		// Refresh session
		refreshSession: async () => {
			if (!isBrowser) return;

			const token = localStorage.getItem('aqura-auth-token');
			if (!token) return;

			try {
				// Validate session with database
				const user = await userAuth.validateSession(token);
				
				if (user) {
					// Session is valid, update user data
					update(session => {
						if (session) {
							session.user = user;
							localStorage.setItem('aqura-user', JSON.stringify(user));
						}
						return session;
					});
				} else {
					// Session is invalid, clear auth state
					localStorage.removeItem('aqura-auth-token');
					localStorage.removeItem('aqura-user');
					localStorage.removeItem('aqura-session');
					set(null);
				}
			} catch (error) {
				console.error('Session refresh error:', error);
				// Clear invalid session
				localStorage.removeItem('aqura-auth-token');
				localStorage.removeItem('aqura-user');
				localStorage.removeItem('aqura-session');
				set(null);
			}
		}
	};
}

export const auth = createAuthStore();