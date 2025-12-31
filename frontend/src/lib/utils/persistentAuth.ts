import { writable } from "svelte/store";
import { browser } from "$app/environment";
import { supabase } from "./supabase";
import type { User, UserPermissions } from "$lib/types/auth";

// Database types matching our deployed schema
interface DatabaseUser {
  id: string;
  username: string;
  password_hash: string;
  salt: string;
  quick_access_code: string;
  quick_access_salt: string;
  user_type: "global" | "branch_specific";
  employee_id?: string;
  branch_id?: number;
  is_master_admin: boolean;
  is_admin: boolean;
  position_id?: string;
  avatar?: string;
  status: "active" | "inactive" | "locked";
  is_first_login: boolean;
  failed_login_attempts: number;
  last_login_at?: string;
  created_at: string;
  updated_at: string;
}

interface DatabaseUserView {
  id: string;
  username: string;
  employee_name: string;
  branch_name: string;
  is_master_admin: boolean;
  is_admin: boolean;
  status: "active" | "inactive" | "locked";
  avatar?: string;
  last_login?: string;
  is_first_login: boolean;
  failed_login_attempts: number;
  user_type: "global" | "branch_specific";
  employee_id?: string;
  branch_id?: number;
  position_id?: string;
  created_at: string;
  updated_at: string;
}

interface DatabaseUserPermissions {
  user_id: string;
  username: string;
  role_name: string;
  function_name: string;
  function_code: string;
  can_view: boolean;
  can_add: boolean;
  can_edit: boolean;
  can_delete: boolean;
  can_export: boolean;
}

// Types
export interface UserSession {
  id: string;
  username: string;
  email?: string;
  isMasterAdmin?: boolean;
  isAdmin?: boolean;
  userType?: string;
  avatar?: string;
  employeeName?: string;
  branchName?: string;
  employee_id?: string;
  branch_id?: string;
  customerId?: string; // For customer users
  loginTime: string;
  deviceId: string;
  loginMethod: "password" | "quickAccess" | "customerAccess";
  isActive: boolean;
  token?: string;
  permissions?: UserPermissions;
  customer?: any; // Customer details for customer users
}

export interface DeviceSession {
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
  // 🔄 CHANGED: Removed SESSION_DURATION - users stay logged in indefinitely
  // Only logout on explicit logout, cache clear, or admin block (status change)
  // private readonly SESSION_DURATION = 24 * 60 * 60 * 1000; // 24 hours
  private readonly ACTIVITY_UPDATE_INTERVAL = 5 * 60 * 1000; // 5 minutes
  private readonly STATUS_CHECK_INTERVAL = 5 * 60 * 1000; // Check user status every 5 minutes

  constructor() {
    // Don't auto-initialize in constructor to avoid race conditions
    // Let the layout call initializeAuth() explicitly
  }

  /**
   * Initialize authentication system
   */
  async initializeAuth(): Promise<void> {
    try {
      console.log("🔐 Starting persistent auth initialization...");

      // Load device sessions from localStorage
      await this.loadDeviceSessions();

      // Check if there's an active session
      const activeUser = await this.getActiveUser();
      if (activeUser) {
        console.log("🔐 Found active user session:", activeUser.username);
        await this.setCurrentUser(activeUser);
      } else {
        console.log("🔐 No active user session found");
        // Ensure auth state is properly set to false
        currentUser.set(null);
        isAuthenticated.set(false);
      }

      // Start session monitoring
      this.startSessionMonitoring();

      // Initialize push notifications for authenticated user (non-blocking)
      if (activeUser) {
        console.log(
          "� [PersistentAuth] Active user found, will initialize push notifications after login",
        );
      }

      console.log("🔐 Persistent auth initialization complete");
    } catch (error) {
      console.error("🔐 Error initializing auth:", error);
      // Ensure auth state is properly set to false on error
      currentUser.set(null);
      isAuthenticated.set(false);
    }
  }

  /**
   * Validate quick access code and get user permissions (without full login)
   */
  async validateQuickAccessCode(
    quickAccessCode: string
  ): Promise<{ 
    success: boolean; 
    error?: string; 
    userId?: string;
    userType?: string;
    permissions?: UserPermissions;
    interfacePermissions?: {
      desktop?: boolean;
      mobile?: boolean;
      cashier?: boolean;
    };
  }> {
    try {
      console.log("🔐 [PersistentAuth] Validating quick access code");

      // Validate code format
      if (!/^[0-9]{6}$/.test(quickAccessCode)) {
        console.error("❌ [PersistentAuth] Invalid access code format:", quickAccessCode);
        return { success: false, error: "Invalid access code format" };
      }

      // Get user by quick access code
      const { data: users, error: userError } = await supabase
        .from("users")
        .select(
          `
          id,
          username,
          user_type,
          status,
          is_master_admin,
          is_admin,
          employee_id,
          branch_id
        `,
        )
        .eq("status", "active")
        .eq("quick_access_code", quickAccessCode)
        .limit(1);

      if (userError) {
        console.error("❌ [PersistentAuth] Database error:", userError);
        return { success: false, error: "Database connection error. Please try again." };
      }

      if (!users || users.length === 0) {
        console.error("❌ [PersistentAuth] No user found with quick access code");
        return { success: false, error: "Invalid access code" };
      }

      const dbUser = users[0];
      console.log("✅ [PersistentAuth] Quick access code validated for user:", dbUser.username);

      // Get user permissions
      const permissions = await this.getUserPermissions(dbUser.id);

      // Check interface permissions
      const interfacePermissions = {
        desktop: dbUser.is_master_admin || dbUser.is_admin || false,
        mobile: dbUser.is_master_admin || dbUser.is_admin || false,
        cashier: dbUser.is_master_admin || dbUser.is_admin || false
      };

      console.log("✅ [PersistentAuth] Interface permissions determined:", interfacePermissions);

      return {
        success: true,
        userId: dbUser.id,
        userType: dbUser.user_type,
        permissions,
        interfacePermissions
      };
    } catch (error) {
      console.error("❌ [PersistentAuth] Error validating quick access code:", error);
      return { success: false, error: "Validation failed. Please try again." };
    }
  }

  /**
   * Login user with quick access code
   */
  async loginWithQuickAccess(
    quickAccessCode: string,
    interfaceType: 'desktop' | 'mobile' | 'customer' = 'desktop'
  ): Promise<{ success: boolean; error?: string; user?: UserSession }> {
    try {
      console.log("🔐 [PersistentAuth] Starting quick access login process");

      // Step 1: Validate code format
      if (!/^[0-9]{6}$/.test(quickAccessCode)) {
        console.error("❌ [PersistentAuth] Invalid access code format:", quickAccessCode);
        throw new Error("Invalid access code format");
      }

      console.log("🔍 [PersistentAuth] Querying database for user with quick access code");

      // Step 2: Get user by quick access code directly from database
      const { data: users, error: userError } = await supabase
        .from("users")
        .select(
          `
					id,
					username,
					quick_access_code,
					quick_access_salt,
					status,
					user_type,
					employee_id,
					branch_id,
					is_master_admin,
					is_admin,
					position_id,
					avatar
				`,
        )
        .eq("status", "active")
        .eq("quick_access_code", quickAccessCode)
        .limit(1);

      if (userError) {
        console.error("❌ [PersistentAuth] Database error:", userError);
        throw new Error("Database connection error. Please try again.");
      }

      if (!users || users.length === 0) {
        console.error("❌ [PersistentAuth] No user found with quick access code");
        throw new Error("Invalid access code");
      }

      const dbUser = users[0];
      console.log("✅ [PersistentAuth] Found user:", dbUser.username);

      // Step 3: Get user details from view
      console.log("🔍 [PersistentAuth] Getting user details from view");
      const { data: userDetails, error: userDetailsError } = await supabase
        .from("user_management_view")
        .select("*")
        .eq("id", dbUser.id)
        .single();

      if (userDetailsError || !userDetails) {
        console.error("❌ [PersistentAuth] User details error:", userDetailsError);
        throw new Error("User account configuration error. Please contact support.");
      }

      console.log("✅ [PersistentAuth] User details retrieved successfully");

      // Step 4: Get user permissions
      console.log("🔍 [PersistentAuth] Getting user permissions");
      const permissions = await this.getUserPermissions(dbUser.id);
      console.log("✅ [PersistentAuth] User permissions retrieved");

      // Step 4.1: Check interface access permission based on interface type
      console.log(`🔍 [PersistentAuth] Checking ${interfaceType} interface access permission`);
      const { data: interfacePermissions, error: permissionError } = await supabase
        .from("interface_permissions")
        .select("desktop_enabled, mobile_enabled, customer_enabled")
        .eq("user_id", dbUser.id)
        .single();

      if (permissionError) {
        console.log("⚠️ [PersistentAuth] No interface permissions found, defaulting to enabled");
      } else if (interfacePermissions) {
        const isEnabled = interfacePermissions[`${interfaceType}_enabled`];
        if (!isEnabled) {
          console.error(`❌ [PersistentAuth] ${interfaceType} interface access denied for user:`, dbUser.username);
          throw new Error(`${interfaceType.charAt(0).toUpperCase() + interfaceType.slice(1)} interface access is disabled for your account. Please contact your administrator${interfaceType !== 'desktop' ? ' or use the desktop interface' : ''}.`);
        }
      }

      console.log(`✅ [PersistentAuth] ${interfaceType} interface access confirmed`);

      // Step 5: Update last login
      console.log("🔍 [PersistentAuth] Updating last login timestamp");
      await this.updateLastLogin(dbUser.id);

      // Step 6: Create session token
      console.log("🔍 [PersistentAuth] Creating session token");
      const token = this.generateSessionToken();

      // Step 6.5: Set user context in Postgres for RLS policies
      console.log("🔐 [PersistentAuth] Setting user context for RLS policies...");
      try {
        await supabase.rpc('set_user_context', {
          user_id: dbUser.id,
          is_master_admin: dbUser.is_master_admin || false,
          is_admin: dbUser.is_admin || false
        });
        console.log("✅ [PersistentAuth] User context set successfully for RLS");
      } catch (contextError) {
        console.warn("⚠️ [PersistentAuth] Failed to set user context:", contextError);
        // Don't fail login if context setting fails, just log warning
      }

      // Step 7: Store session in database
      console.log("🔍 [PersistentAuth] Storing session in database");
      await this.createUserSession(dbUser.id, token, "quick_access");

      // Convert to UserSession
      const userSession: UserSession = {
        id: userDetails.id,
        username: userDetails.username,
        isMasterAdmin: userDetails.is_master_admin,
        isAdmin: userDetails.is_admin,
        userType: userDetails.user_type,
        avatar: userDetails.avatar,
        employeeName: userDetails.employee_name,
        branchName: userDetails.branch_name,
        employee_id: userDetails.employee_id,
        branch_id: userDetails.branch_id?.toString(),
        loginTime: new Date().toISOString(),
        deviceId: this.getDeviceId(),
        loginMethod: "quickAccess",
        isActive: true,
        token,
        permissions,
      };
      console.log("✅ [PersistentAuth] User session object created");

      // Save session to device
      console.log("🔐 [PersistentAuth] Saving user session to device...");
      await this.saveUserSession(userSession);
      console.log("✅ [PersistentAuth] User session saved to device");

      // Set as current user
      console.log("🔐 [PersistentAuth] Setting current user...");
      await this.setCurrentUser(userSession);
      console.log("✅ [PersistentAuth] Current user set successfully");

      // Push notification initialization removed
      console.log(
        "✅ [PersistentAuth] Push notification initialization skipped (removed)",
      );

      // Log login activity (with timeout protection)
      console.log("🔐 [PersistentAuth] Logging user activity...");
      try {
        const activityPromise = this.logUserActivity(
          "quick_access_login",
          userSession.id,
        );
        const activityTimeout = new Promise((_, reject) => {
          setTimeout(() => reject(new Error("Activity logging timeout")), 3000);
        });

        await Promise.race([activityPromise, activityTimeout]);
        console.log("✅ [PersistentAuth] User activity logged");
      } catch (activityError) {
        console.warn(
          "⚠️ [PersistentAuth] Activity logging failed, continuing:",
          activityError,
        );
      }

      console.log(
        "🎉 [PersistentAuth] Quick access login completed successfully",
      );
      return { success: true, user: userSession };
    } catch (error) {
      console.error("❌ [PersistentAuth] Quick access login error:", error);

      // Rethrow with more specific error messages
      if (error instanceof Error) {
        if (error.message.includes("fetch")) {
          return {
            success: false,
            error: "Network connection error. Please check your internet connection.",
          };
        } else if (error.message.includes("Database")) {
          return {
            success: false,
            error: "Database connection error. Please try again.",
          };
        } else {
          return {
            success: false,
            error: error.message,
          };
        }
      } else {
        return {
          success: false,
          error: "Authentication service error. Please try again.",
        };
      }
    }
  }

  /**
   * Login customer with username and access code
   */
  async loginWithCustomerCredentials(
    username: string,
    accessCode: string,
  ): Promise<{ success: boolean; error?: string; user?: UserSession }> {
    try {
      console.log("🔐 [PersistentAuth] Starting customer login process");

      // Step 1: Validate inputs
      if (!username?.trim() || !accessCode?.trim()) {
        throw new Error("Username and access code are required");
      }

      if (!/^[0-9]{6}$/.test(accessCode)) {
        throw new Error("Access code must be 6 digits");
      }

      console.log("🔍 [PersistentAuth] Calling customer authentication function");

      // Step 2: Authenticate using database function
      const { data: authResult, error: authError } = await supabase.rpc(
        "authenticate_customer_access_code",
        {
          p_username: username.trim(),
          p_access_code: accessCode.trim(),
        },
      );

      if (authError) {
        console.error("❌ [PersistentAuth] Database authentication error:", authError);
        throw new Error("Authentication service error. Please try again.");
      }

      if (!authResult || !authResult.success) {
        const errorMsg = authResult?.error || "Invalid credentials";
        console.error("❌ [PersistentAuth] Authentication failed:", errorMsg);
        
        if (errorMsg.includes("not found")) {
          throw new Error("Invalid username or access code");
        } else if (errorMsg.includes("not approved")) {
          throw new Error("Your account is pending approval");
        } else if (errorMsg.includes("suspended")) {
          throw new Error("Your account has been suspended");
        } else {
          throw new Error("Authentication failed. Please try again.");
        }
      }

      console.log("✅ [PersistentAuth] Customer authenticated successfully");

      // Step 3: Get user and customer details
      const userId = authResult.user_id;
      const customerId = authResult.customer_id;

      // Get user details from view
      const { data: userDetails, error: userDetailsError } = await supabase
        .from("user_management_view")
        .select("*")
        .eq("id", userId)
        .single();

      if (userDetailsError || !userDetails) {
        console.error("❌ [PersistentAuth] User details error:", userDetailsError);
        throw new Error("User account configuration error. Please contact support.");
      }

      // Get customer details
      const { data: customerDetails, error: customerError } = await supabase
        .from("customers")
        .select("*")
        .eq("id", customerId)
        .single();

      if (customerError || !customerDetails) {
        console.error("❌ [PersistentAuth] Customer details error:", customerError);
        throw new Error("Customer account error. Please contact support.");
      }

      // Step 4: Get user permissions (customers have limited permissions)
      const permissions = await this.getUserPermissions(userId);

      // Step 4.1: Check customer interface access permission
      console.log("🔍 [PersistentAuth] Checking customer interface access permission");
      const { data: interfacePermissions, error: permissionError } = await supabase
        .from("interface_permissions")
        .select("customer_enabled")
        .eq("user_id", userId)
        .single();

      if (permissionError) {
        console.log("⚠️ [PersistentAuth] No interface permissions found, defaulting to enabled");
      } else if (interfacePermissions && !interfacePermissions.customer_enabled) {
        console.error("❌ [PersistentAuth] Customer interface access denied for user:", userDetails.username);
        throw new Error("Customer interface access is disabled for your account. Please contact your administrator.");
      }

      console.log("✅ [PersistentAuth] Customer interface access confirmed");

      // Step 5: Update last login for customer
      await supabase
        .from("customers")
        .update({ last_login_at: new Date().toISOString() })
        .eq("id", customerId);

      // Step 6: Create session token
      const token = this.generateSessionToken();

      // Step 7: Store session in database
      await this.createUserSession(userId, token, "customer_access");

      // Create UserSession
      const userSession: UserSession = {
        id: userDetails.id,
        username: userDetails.username,
        isMasterAdmin: userDetails.is_master_admin,
        isAdmin: userDetails.is_admin,
        userType: "customer",
        avatar: userDetails.avatar,
        employeeName: userDetails.employee_name,
        branchName: userDetails.branch_name,
        employee_id: userDetails.employee_id,
        branch_id: userDetails.branch_id?.toString(),
        customerId: customerId,
        loginTime: new Date().toISOString(),
        deviceId: this.getDeviceId(),
        loginMethod: "customerAccess" as const,
        isActive: true,
        token,
        permissions,
        customer: customerDetails,
      };

      // Save session to device
      console.log("🔐 [PersistentAuth] Saving customer session to device...");
      await this.saveUserSession(userSession);
      console.log("✅ [PersistentAuth] Customer session saved to device");

      // Set as current user
      console.log("🔐 [PersistentAuth] Setting current customer user...");
      await this.setCurrentUser(userSession);
      console.log("✅ [PersistentAuth] Current customer user set successfully");

      console.log("✅ [PersistentAuth] Customer login completed successfully");
      return { success: true, user: userSession };
    } catch (error) {
      console.error("❌ [PersistentAuth] Customer login failed:", error);

      // Rethrow with more specific error messages
      if (error instanceof Error) {
        if (error.message.includes("fetch")) {
          return {
            success: false,
            error: "Network connection error. Please check your internet connection.",
          };
        } else if (error.message.includes("Database")) {
          return {
            success: false,
            error: "Database connection error. Please try again.",
          };
        } else {
          return {
            success: false,
            error: error.message,
          };
        }
      } else {
        return {
          success: false,
          error: "Customer authentication error. Please try again.",
        };
      }
    }
  }

  /**
   * Login user and create persistent session
   */
  async login(
    username: string,
    password: string,
  ): Promise<{ success: boolean; error?: string; user?: UserSession }> {
    try {
      // Authenticate with Supabase
      const { data: authData, error: authError } =
        await supabase.auth.signInWithPassword({
          email: username.includes("@") ? username : `${username}@aqura.local`,
          password,
        });

      if (authError || !authData.user) {
        return {
          success: false,
          error: authError?.message || "Authentication failed",
        };
      }

      // Get user details from users table
      const { data: userData, error: userError } = await supabase
        .from("users")
        .select(
          `
					id,
					username,
					is_master_admin,
					is_admin,
					user_type,
					hr_employees (
						id,
						employee_id,
						branch_id
					)
				`,
        )
        .eq("id", authData.user.id)
        .single();

      if (userError || !userData) {
        return { success: false, error: "User data not found" };
      }

      // Set user context in Postgres for RLS policies
      console.log("🔐 [PersistentAuth] Setting user context for RLS policies...");
      try {
        await supabase.rpc('set_user_context', {
          user_id: userData.id,
          is_master_admin: userData.is_master_admin || false,
          is_admin: userData.is_admin || false
        });
        console.log("✅ [PersistentAuth] User context set successfully for RLS");
      } catch (contextError) {
        console.warn("⚠️ [PersistentAuth] Failed to set user context:", contextError);
        // Don't fail login if context setting fails, just log warning
      }

      // Check desktop interface access permission
      const { data: interfacePermissions, error: permissionError } = await supabase
        .from("interface_permissions")
        .select("desktop_enabled")
        .eq("user_id", userData.id)
        .single();

      if (permissionError) {
        console.log("⚠️ [PersistentAuth] No interface permissions found, defaulting to enabled");
      } else if (interfacePermissions && !interfacePermissions.desktop_enabled) {
        console.error("❌ [PersistentAuth] Desktop interface access denied for user:", userData.username);
        return { 
          success: false, 
          error: "Desktop interface access is disabled for your account. Please contact your administrator or use the mobile interface." 
        };
      }

      // Get user permissions
      console.log("🔍 [PersistentAuth] Getting user permissions");
      const permissions = await this.getUserPermissions(userData.id);
      console.log("✅ [PersistentAuth] User permissions retrieved");

      // Create user session
      const userSession: UserSession = {
        id: userData.id,
        username: userData.username,
        isMasterAdmin: userData.is_master_admin,
        isAdmin: userData.is_admin,
        userType: userData.user_type,
        employee_id: userData.hr_employees?.[0]?.employee_id,
        branch_id: userData.hr_employees?.[0]?.branch_id,
        loginTime: new Date().toISOString(),
        deviceId: this.getDeviceId(),
        loginMethod: "password",
        isActive: true,
        permissions,
      };

      // Save session to device
      await this.saveUserSession(userSession);

      // Set as current user
      await this.setCurrentUser(userSession);

      // Log login activity
      await this.logUserActivity("login", userSession.id);

      return { success: true, user: userSession };
    } catch (error) {
      console.error("Login error:", error);
      return { success: false, error: "Login failed. Please try again." };
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
        this.logUserActivity("logout", current.id).catch((err) =>
          console.warn("Failed to log logout activity:", err),
        );

        // Push notification unregister removed

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
      console.error("Logout error:", error);
    }
  }

  /**
   * Switch to another user on the same device
   */
  async switchUser(
    userId: string,
  ): Promise<{ success: boolean; error?: string; user?: UserSession }> {
    try {
      const deviceSession = await this.getDeviceSession();
      if (!deviceSession) {
        return { success: false, error: "No device session found" };
      }

      const targetUser = deviceSession.users.find((u) => u.id === userId);
      if (!targetUser) {
        return { success: false, error: "User not found on this device" };
      }

      // Check if session is still valid (only checks user status, not time)
      const isValid = await this.isSessionValid(userId);
      if (!isValid) {
        // Session expired or user blocked/locked
        await this.logout();
        return {
          success: false,
          error: "Your account has been locked or deactivated. Please contact your administrator.",
        };
      }

      // Switch to target user
      await this.setCurrentUser(targetUser);

      // Update device session
      deviceSession.currentUserId = userId;
      deviceSession.lastActivity = new Date().toISOString();
      await this.saveDeviceSession(deviceSession);

      // Log switch activity
      await this.logUserActivity("switch", userId);

      return { success: true, user: targetUser };
    } catch (error) {
      console.error("Switch user error:", error);
      return { success: false, error: "Failed to switch user" };
    }
  }

  /**
   * Get all users logged in on this device
   */
  async getDeviceUsers(): Promise<UserSession[]> {
    const deviceSession = await this.getDeviceSession();
    return deviceSession?.users.filter((u) => u.isActive) || [];
  }

  /**
   * Check if user session is valid
   * 🔄 CHANGED: Only checks if user status is active, not time-based expiration
   * Users stay logged in until explicit logout, cache clear, or admin blocks them
   */
  async isSessionValid(userId: string): Promise<boolean> {
    const deviceSession = await this.getDeviceSession();
    if (!deviceSession) return false;

    const user = deviceSession.users.find((u) => u.id === userId);
    if (!user) return false;

    // Check if user status is still active in database
    try {
      const { data: dbUser, error } = await supabase
        .from("users")
        .select("status")
        .eq("id", userId)
        .single();

      if (error || !dbUser) {
        console.warn("⚠️ [PersistentAuth] Could not verify user status, keeping session valid");
        return true;
      }

      // Logout if user is locked or inactive
      if (dbUser.status === "locked" || dbUser.status === "inactive") {
        console.log(`⚠️ [PersistentAuth] User account is ${dbUser.status}, session invalid`);
        return false;
      }

      // User is active, session remains valid (no time-based expiration)
      return true;
    } catch (error) {
      console.warn("⚠️ [PersistentAuth] Error checking session validity:", error);
      // Keep session valid if we can't check (network issue)
      return true;
    }
  }

  /**
   * Private methods
   */
  private async loadDeviceSessions(): Promise<void> {
    if (!browser) return;

    try {
      const sessionData = localStorage.getItem("aqura-device-session");
      if (sessionData) {
        const session = JSON.parse(sessionData);
        deviceSessions.set(session);
      }
    } catch (error) {
      console.error("Error loading device sessions:", error);
    }
  }

  private async saveDeviceSession(session: DeviceSession): Promise<void> {
    if (!browser) return;

    try {
      localStorage.setItem("aqura-device-session", JSON.stringify(session));
      deviceSessions.set(session);
    } catch (error) {
      console.error("Error saving device session:", error);
    }
  }

  private async getDeviceSession(): Promise<DeviceSession | null> {
    if (!browser) return null;

    try {
      const sessionData = localStorage.getItem("aqura-device-session");
      return sessionData ? JSON.parse(sessionData) : null;
    } catch (error) {
      console.error("Error getting device session:", error);
      return null;
    }
  }

  private async saveUserSession(user: UserSession): Promise<void> {
    let deviceSession = await this.getDeviceSession();

    if (!deviceSession) {
      deviceSession = {
        deviceId: this.getDeviceId(),
        users: [],
        lastActivity: new Date().toISOString(),
      };
    }

    // Remove existing session for this user
    deviceSession.users = deviceSession.users.filter((u) => u.id !== user.id);

    // Add new session
    deviceSession.users.push(user);
    deviceSession.currentUserId = user.id;
    deviceSession.lastActivity = new Date().toISOString();

    await this.saveDeviceSession(deviceSession);
  }

  private async removeUserSession(userId: string): Promise<void> {
    const deviceSession = await this.getDeviceSession();
    if (!deviceSession) return;

    deviceSession.users = deviceSession.users.filter((u) => u.id !== userId);

    if (deviceSession.currentUserId === userId) {
      deviceSession.currentUserId = undefined;
    }

    deviceSession.lastActivity = new Date().toISOString();
    await this.saveDeviceSession(deviceSession);
  }

  private async getActiveUser(): Promise<UserSession | null> {
    const deviceSession = await this.getDeviceSession();
    if (!deviceSession || !deviceSession.currentUserId) return null;

    const user = deviceSession.users.find(
      (u) => u.id === deviceSession.currentUserId,
    );
    if (!user) return null;

    // Check if session is valid
    const isValid = await this.isSessionValid(user.id);
    if (!isValid) {
      await this.removeUserSession(user.id);
      return null;
    }

    // Refresh admin flags from database to ensure they're current
    try {
      const { data: freshUserData, error } = await supabase
        .from('users')
        .select('is_admin, is_master_admin')
        .eq('id', user.id)
        .single();

      if (!error && freshUserData) {
        // Update the user session with fresh admin flags
        user.isAdmin = freshUserData.is_admin;
        user.isMasterAdmin = freshUserData.is_master_admin;
        
        // Update the session in storage
        if (deviceSession) {
          const userIndex = deviceSession.users.findIndex(u => u.id === user.id);
          if (userIndex !== -1) {
            deviceSession.users[userIndex] = user;
            await this.saveDeviceSession(deviceSession);
          }
        }
        
        console.log('🔄 [PersistentAuth] Refreshed admin flags for user:', user.username, {
          isAdmin: user.isAdmin,
          isMasterAdmin: user.isMasterAdmin
        });
      }
    } catch (refreshError) {
      console.warn('⚠️ [PersistentAuth] Failed to refresh admin flags:', refreshError);
      // Continue with cached data if refresh fails
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

    // 🔴 DISABLED: updateLastActivity disabled
    // await this.updateLastActivity();
  }

  private async updateLastActivity(): Promise<void> {
    // 🔴 DISABLED: updateLastActivity causing updateLastSeen warnings
    return;
  }

  private startSessionMonitoring(): void {
    // 🔄 CHANGED: Check user status instead of session age
    // Every 5 minutes, verify user is still active (not locked/inactive by admin)
    this.sessionCheckInterval = setInterval(async () => {
      const current = await this.getCurrentUser();
      if (current) {
        const isValid = await this.isSessionValid(current.id);
        if (!isValid) {
          console.log("🔐 [PersistentAuth] User account no longer active, logging out");
          await this.logout();
        } else {
          console.log("✅ [PersistentAuth] Session valid - user still active");
        }
      }
    }, this.STATUS_CHECK_INTERVAL);

    // Update activity every 5 minutes
    // 🔴 DISABLED: updateLastActivity disabled
    // this.activityTrackingInterval = setInterval(async () => {
    //   const current = await this.getCurrentUser();
    //   if (current) {
    //     await this.updateLastActivity();
    //   }
    // }, this.ACTIVITY_UPDATE_INTERVAL);
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
    let deviceId = localStorage.getItem("aqura-device-id");
    if (!deviceId) {
      deviceId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      localStorage.setItem("aqura-device-id", deviceId);
    }
    return deviceId;
  }

  private async logUserActivity(
    activity: string,
    userId: string,
  ): Promise<void> {
    try {
      console.log("🔍 [PersistentAuth] Logging user activity:", {
        activity,
        userId,
      });

      const result = await supabase.from("user_audit_logs").insert({
        user_id: userId,
        action: activity,
        ip_address: null, // We could get this from a service if needed
        user_agent: navigator.userAgent,
      });

      if (result.error) {
        console.error(
          "🔍 [PersistentAuth] Audit log insert error:",
          result.error,
        );
      } else {
        console.log("🔍 [PersistentAuth] Audit log inserted successfully");
      }
    } catch (error) {
      console.error("🔍 [PersistentAuth] Error logging user activity:", error);
    }
  }

  // Authentication helper methods (merged from userAuth.ts)

  private async getUserPermissions(userId: string): Promise<UserPermissions> {
    const { data: permissions, error } = await supabase
      .from("user_permissions_view")
      .select("*")
      .eq("user_id", userId);

    if (error) {
      console.error("Error fetching permissions:", error);
      return {};
    }

    const permissionMap: UserPermissions = {};

    if (permissions) {
      permissions.forEach((perm: DatabaseUserPermissions) => {
        permissionMap[perm.function_code] = {
          can_view: perm.can_view,
          can_add: perm.can_add,
          can_edit: perm.can_edit,
          can_delete: perm.can_delete,
          can_export: perm.can_export,
        };
      });
    }

    return permissionMap;
  }

  private async updateLastLogin(userId: string): Promise<void> {
    await supabase
      .from("users")
      .update({
        last_login_at: new Date().toISOString(),
        failed_login_attempts: 0,
      })
      .eq("id", userId);
  }

  private async createUserSession(
    userId: string,
    token: string,
    loginMethod: string,
  ): Promise<void> {
    const expiresAt = new Date();
    expiresAt.setHours(
      expiresAt.getHours() + (loginMethod === "quick_access" ? 8 : 24),
    );

    await supabase.from("user_sessions").insert({
      user_id: userId,
      session_token: token,
      login_method: loginMethod,
      expires_at: expiresAt.toISOString(),
      is_active: true,
    });
  }

  private generateSessionToken(): string {
    const timestamp = Date.now().toString();
    const random = Math.random().toString(36).substring(2);
    return `aqura_${timestamp}_${random}`;
  }

  private async getPasswordHash(userId: string): Promise<string> {
    const { data, error } = await supabase
      .from("users")
      .select("password_hash")
      .eq("id", userId)
      .single();

    if (error || !data) {
      throw new Error("User not found");
    }

    return data.password_hash;
  }

  private async incrementFailedLoginAttempts(userId: string): Promise<void> {
    // First get current count
    const { data: user } = await supabase
      .from("users")
      .select("failed_login_attempts")
      .eq("id", userId)
      .single();

    const currentAttempts = user?.failed_login_attempts || 0;

    await supabase
      .from("users")
      .update({
        failed_login_attempts: currentAttempts + 1,
      })
      .eq("id", userId);
  }
}

// Singleton instance
export const persistentAuthService = new PersistentAuthService();
