import { writable } from 'svelte/store';
import { browser } from '$app/environment';
import { supabase } from './supabase';
import { pushNotificationService } from './pushNotifications';
import { userAuth } from './userAuth';
import type { User } from '$lib/types/auth';

// Types
interface UserSession {
	id: string;
	username: string;
	role?: string;
	roleType?: string;
	userType?: string;
	avatar?: string;
	employeeName?: string;
	branchName?: string;
	employee_id?: string;
	branch_id?: string;
	loginTime: string;
	deviceId: string;
	loginMethod: 'password' | 'quickAccess';
	isActive: boolean;
}

interface DeviceSession {
	deviceId: string;
	users: UserSession[];
	currentUserId?: string;
	lastActivity: string;
}

// Stores
export const currentUser = writable<UserSession | null>(null);
export const isAuthenticated = writable<boolean>(false);
export const deviceSessions = writable<DeviceSession | null>(null);

export class PersistentAuthService {
	private sessionCheckInterval: NodeJS.Timeout | null = null;
	private activityTrackingInterval: NodeJS.Timeout | null = null;
	private readonly SESSION_DURATION = 24 * 60 * 60 * 1000; // 24 hours
	private readonly ACTIVITY_UPDATE_INTERVAL = 5 * 60 * 1000; // 5 minutes

	constructor() {
		// Don't auto-initialize in constructor to avoid race conditions
		// Let the layout call initializeAuth() explicitly
	}

	/**
	 * Initialize authentication system
	 */
	async initializeAuth(): Promise<void> {
		try {
			console.log('🔐 Starting persistent auth initialization...');
			
			// Load device sessions from localStorage
			await this.loadDeviceSessions();

			// Check if there's an active session
			const activeUser = await this.getActiveUser();
			if (activeUser) {
				console.log('🔐 Found active user session:', activeUser.username);
				await this.setCurrentUser(activeUser);
			} else {
				console.log('🔐 No active user session found');
				// Ensure auth state is properly set to false
				currentUser.set(null);
				isAuthenticated.set(false);
			}

			// Start session monitoring
			this.startSessionMonitoring();

			// Initialize push notifications for authenticated user (non-blocking)
			if (activeUser) {
				// Wait for Service Worker cleanup to complete before initializing push notifications
				console.log('🔔 Scheduling push notification initialization after cleanup...');
				setTimeout(async () => {
					try {
						console.log('🔔 Starting delayed push notification initialization...');
						await pushNotificationService.initialize();
						console.log('✅ Push notification initialization completed successfully');
					} catch (error) {
						console.warn('🔔 Push notification initialization failed:', error);
					}
				}, 3000); // Wait 3 seconds for all cleanup to complete
			}
			
			console.log('🔐 Persistent auth initialization complete');
		} catch (error) {
			console.error('🔐 Error initializing auth:', error);
			// Ensure auth state is properly set to false on error
			currentUser.set(null);
			isAuthenticated.set(false);
		}
	}

	/**
	 * Login user with quick access code
	 */
	async loginWithQuickAccess(quickAccessCode: string): Promise<{ success: boolean; error?: string; user?: UserSession }> {
		try {
			console.log('🔐 [PersistentAuth] Starting quick access login process');
			
			// Use the userAuth service to authenticate
			const { user, token } = await userAuth.loginWithQuickAccess(quickAccessCode);
			console.log('✅ [PersistentAuth] UserAuth completed successfully');

			// Convert User to UserSession
			const userSession: UserSession = {
				id: user.id,
				username: user.username,
				role: user.role,
				roleType: user.roleType,
				userType: user.userType,
				avatar: user.avatar,
				employeeName: user.employeeName,
				branchName: user.branchName,
				loginTime: new Date().toISOString(),
				deviceId: this.getDeviceId(),
				loginMethod: 'quickAccess',
				isActive: true
			};
			console.log('✅ [PersistentAuth] User session object created');

			// Save session to device
			console.log('🔐 [PersistentAuth] Saving user session to device...');
			await this.saveUserSession(userSession);
			console.log('✅ [PersistentAuth] User session saved to device');

			// Set as current user
			console.log('🔐 [PersistentAuth] Setting current user...');
			await this.setCurrentUser(userSession);
			console.log('✅ [PersistentAuth] Current user set successfully');

			// Initialize push notifications (with timeout protection)
			console.log('🔐 [PersistentAuth] Initializing push notifications...');
			try {
				const pushInitPromise = pushNotificationService.initialize();
				const pushTimeout = new Promise((_, reject) => {
					setTimeout(() => reject(new Error('Push notification timeout')), 15000); // Increased to 15 seconds
				});
				
				await Promise.race([pushInitPromise, pushTimeout]);
				console.log('✅ [PersistentAuth] Push notifications initialized');
			} catch (pushError) {
				console.warn('⚠️ [PersistentAuth] Push notification initialization failed, continuing:', pushError);
			}

			// Log login activity (with timeout protection)
			console.log('🔐 [PersistentAuth] Logging user activity...');
			try {
				const activityPromise = this.logUserActivity('quick_access_login', userSession.id);
				const activityTimeout = new Promise((_, reject) => {
					setTimeout(() => reject(new Error('Activity logging timeout')), 3000);
				});
				
				await Promise.race([activityPromise, activityTimeout]);
				console.log('✅ [PersistentAuth] User activity logged');
			} catch (activityError) {
				console.warn('⚠️ [PersistentAuth] Activity logging failed, continuing:', activityError);
			}

			console.log('🎉 [PersistentAuth] Quick access login completed successfully');
			return { success: true, user: userSession };
		} catch (error) {
			console.error('❌ [PersistentAuth] Quick access login error:', error);
			return { success: false, error: error instanceof Error ? error.message : 'Quick access login failed. Please try again.' };
		}
	}

	/**
	 * Login user and create persistent session
	 */
	async login(username: string, password: string): Promise<{ success: boolean; error?: string; user?: UserSession }> {
		try {
			// Authenticate with Supabase
			const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
				email: username.includes('@') ? username : `${username}@aqura.local`,
				password
			});

			if (authError || !authData.user) {
				return { success: false, error: authError?.message || 'Authentication failed' };
			}

			// Get user details from users table
			const { data: userData, error: userError } = await supabase
				.from('users')
				.select(`
					id,
					username,
					email,
					role,
					hr_employees (
						id,
						employee_id,
						branch_id
					)
				`)
				.eq('id', authData.user.id)
				.single();

			if (userError || !userData) {
				return { success: false, error: 'User data not found' };
			}

			// Create user session
			const userSession: UserSession = {
				id: userData.id,
				username: userData.username,
				role: userData.role,
				employee_id: userData.hr_employees?.[0]?.employee_id,
				branch_id: userData.hr_employees?.[0]?.branch_id,
				loginTime: new Date().toISOString(),
				deviceId: this.getDeviceId(),
				loginMethod: 'password',
				isActive: true
			};

			// Save session to device
			await this.saveUserSession(userSession);

			// Set as current user
			await this.setCurrentUser(userSession);

			// Initialize push notifications
			await pushNotificationService.initialize();

			// Log login activity
			await this.logUserActivity('login', userSession.id);

			return { success: true, user: userSession };
		} catch (error) {
			console.error('Login error:', error);
			return { success: false, error: 'Login failed. Please try again.' };
		}
	}

	/**
	 * Logout current user
	 */
	async logout(): Promise<void> {
		try {
			const current = await this.getCurrentUser();
			if (current) {
				// Log logout activity (but don't let it block logout)
				this.logUserActivity('logout', current.id).catch(err => 
					console.warn('Failed to log logout activity:', err)
				);

				// Unregister device from push notifications
				await pushNotificationService.unregisterDevice();

				// Remove user from device sessions
				await this.removeUserSession(current.id);

				// Clear Supabase session
				await supabase.auth.signOut();
			}

			// Clear current user
			currentUser.set(null);
			isAuthenticated.set(false);

			// Stop session monitoring
			this.stopSessionMonitoring();

		} catch (error) {
			console.error('Logout error:', error);
		}
	}

	/**
	 * Switch to another user on the same device
	 */
	async switchUser(userId: string): Promise<{ success: boolean; error?: string; user?: UserSession }> {
		try {
			const deviceSession = await this.getDeviceSession();
			if (!deviceSession) {
				return { success: false, error: 'No device session found' };
			}

			const targetUser = deviceSession.users.find(u => u.id === userId);
			if (!targetUser) {
				return { success: false, error: 'User not found on this device' };
			}

			// Check if session is still valid
			const sessionAge = Date.now() - new Date(targetUser.loginTime).getTime();
			if (sessionAge > this.SESSION_DURATION) {
				// Session expired, remove it
				await this.removeUserSession(userId);
				return { success: false, error: 'Session expired. Please login again.' };
			}

			// Switch to target user
			await this.setCurrentUser(targetUser);

			// Update device session
			deviceSession.currentUserId = userId;
			deviceSession.lastActivity = new Date().toISOString();
			await this.saveDeviceSession(deviceSession);

			// Re-initialize push notifications for new user
			await pushNotificationService.unregisterDevice();
			await pushNotificationService.initialize();

			// Log switch activity
			await this.logUserActivity('switch', userId);

			return { success: true, user: targetUser };
		} catch (error) {
			console.error('Switch user error:', error);
			return { success: false, error: 'Failed to switch user' };
		}
	}

	/**
	 * Get all users logged in on this device
	 */
	async getDeviceUsers(): Promise<UserSession[]> {
		const deviceSession = await this.getDeviceSession();
		return deviceSession?.users.filter(u => u.isActive) || [];
	}

	/**
	 * Check if user session is valid
	 */
	async isSessionValid(userId: string): Promise<boolean> {
		const deviceSession = await this.getDeviceSession();
		if (!deviceSession) return false;

		const user = deviceSession.users.find(u => u.id === userId);
		if (!user) return false;

		const sessionAge = Date.now() - new Date(user.loginTime).getTime();
		return sessionAge <= this.SESSION_DURATION;
	}

	/**
	 * Private methods
	 */
	private async loadDeviceSessions(): Promise<void> {
		if (!browser) return;

		try {
			const sessionData = localStorage.getItem('aqura-device-session');
			if (sessionData) {
				const session = JSON.parse(sessionData);
				deviceSessions.set(session);
			}
		} catch (error) {
			console.error('Error loading device sessions:', error);
		}
	}

	private async saveDeviceSession(session: DeviceSession): Promise<void> {
		if (!browser) return;

		try {
			localStorage.setItem('aqura-device-session', JSON.stringify(session));
			deviceSessions.set(session);
		} catch (error) {
			console.error('Error saving device session:', error);
		}
	}

	private async getDeviceSession(): Promise<DeviceSession | null> {
		if (!browser) return null;

		try {
			const sessionData = localStorage.getItem('aqura-device-session');
			return sessionData ? JSON.parse(sessionData) : null;
		} catch (error) {
			console.error('Error getting device session:', error);
			return null;
		}
	}

	private async saveUserSession(user: UserSession): Promise<void> {
		let deviceSession = await this.getDeviceSession();

		if (!deviceSession) {
			deviceSession = {
				deviceId: this.getDeviceId(),
				users: [],
				lastActivity: new Date().toISOString()
			};
		}

		// Remove existing session for this user
		deviceSession.users = deviceSession.users.filter(u => u.id !== user.id);

		// Add new session
		deviceSession.users.push(user);
		deviceSession.currentUserId = user.id;
		deviceSession.lastActivity = new Date().toISOString();

		await this.saveDeviceSession(deviceSession);
	}

	private async removeUserSession(userId: string): Promise<void> {
		const deviceSession = await this.getDeviceSession();
		if (!deviceSession) return;

		deviceSession.users = deviceSession.users.filter(u => u.id !== userId);

		if (deviceSession.currentUserId === userId) {
			deviceSession.currentUserId = undefined;
		}

		deviceSession.lastActivity = new Date().toISOString();
		await this.saveDeviceSession(deviceSession);
	}

	private async getActiveUser(): Promise<UserSession | null> {
		const deviceSession = await this.getDeviceSession();
		if (!deviceSession || !deviceSession.currentUserId) return null;

		const user = deviceSession.users.find(u => u.id === deviceSession.currentUserId);
		if (!user) return null;

		// Check if session is valid
		const isValid = await this.isSessionValid(user.id);
		if (!isValid) {
			await this.removeUserSession(user.id);
			return null;
		}

		return user;
	}

	private async getCurrentUser(): Promise<UserSession | null> {
		return new Promise((resolve) => {
			let unsubscribe: (() => void) | undefined;
			
			// Set a timeout to prevent hanging
			const timeout = setTimeout(() => {
				if (unsubscribe) unsubscribe();
				resolve(null);
			}, 1000);
			
			unsubscribe = currentUser.subscribe((user) => {
				clearTimeout(timeout);
				if (unsubscribe) unsubscribe();
				resolve(user);
			});
		});
	}

	private async setCurrentUser(user: UserSession): Promise<void> {
		currentUser.set(user);
		isAuthenticated.set(true);

		// Defer last activity update to avoid race conditions during initialization
		setTimeout(async () => {
			try {
				await this.updateLastActivity();
			} catch (error) {
				console.warn('Failed to update last activity:', error);
			}
		}, 100);
	}

	private async updateLastActivity(): Promise<void> {
		const deviceSession = await this.getDeviceSession();
		if (deviceSession) {
			deviceSession.lastActivity = new Date().toISOString();
			await this.saveDeviceSession(deviceSession);
		}

		// Update push notification service
		await pushNotificationService.updateLastSeen();
	}

	private startSessionMonitoring(): void {
		// Check session validity every minute
		this.sessionCheckInterval = setInterval(async () => {
			const current = await this.getCurrentUser();
			if (current) {
				const isValid = await this.isSessionValid(current.id);
				if (!isValid) {
					await this.logout();
				}
			}
		}, 60 * 1000);

		// Update activity every 5 minutes
		this.activityTrackingInterval = setInterval(async () => {
			const current = await this.getCurrentUser();
			if (current) {
				await this.updateLastActivity();
			}
		}, this.ACTIVITY_UPDATE_INTERVAL);
	}

	private stopSessionMonitoring(): void {
		if (this.sessionCheckInterval) {
			clearInterval(this.sessionCheckInterval);
			this.sessionCheckInterval = null;
		}

		if (this.activityTrackingInterval) {
			clearInterval(this.activityTrackingInterval);
			this.activityTrackingInterval = null;
		}
	}

	private getDeviceId(): string {
		let deviceId = localStorage.getItem('aqura-device-id');
		if (!deviceId) {
			deviceId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
			localStorage.setItem('aqura-device-id', deviceId);
		}
		return deviceId;
	}

	private async logUserActivity(activity: string, userId: string): Promise<void> {
		try {
			console.log('🔍 [PersistentAuth] Logging user activity:', { activity, userId });
			
			const result = await supabase.from('user_audit_logs').insert({
				user_id: userId,
				action: activity,
				ip_address: null, // We could get this from a service if needed
				user_agent: navigator.userAgent
			});
			
			if (result.error) {
				console.error('🔍 [PersistentAuth] Audit log insert error:', result.error);
			} else {
				console.log('🔍 [PersistentAuth] Audit log inserted successfully');
			}
		} catch (error) {
			console.error('🔍 [PersistentAuth] Error logging user activity:', error);
		}
	}
}

// Singleton instance
export const persistentAuthService = new PersistentAuthService();

// Listen for user activity to update last seen
if (browser) {
	['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart', 'click'].forEach(event => {
		document.addEventListener(event, () => {
			persistentAuthService['updateLastActivity']();
		}, { passive: true });
	});
}