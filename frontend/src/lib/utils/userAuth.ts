import { supabase } from "./supabase";
import type { User, UserPermissions, AuthSession } from "$lib/types/auth";

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
  role_type: "Master Admin" | "Admin" | "Position-based";
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
  role_type: "Master Admin" | "Admin" | "Position-based";
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

// User authentication service using real database
export class UserAuthService {
  /**
   * Authenticate user with username and password
   */
  async loginWithCredentials(
    username: string,
    password: string,
  ): Promise<{ user: User; token: string }> {
    try {
      // Step 1: Get user from database
      const { data: users, error: userError } = await supabase
        .from("user_management_view")
        .select("*")
        .eq("username", username)
        .eq("status", "active")
        .limit(1);

      if (userError) {
        throw new Error("Database error: " + userError.message);
      }

      if (!users || users.length === 0) {
        throw new Error("Invalid username or password");
      }

      const dbUser = users[0] as DatabaseUserView;

      // Step 2: Verify password using database function
      const { data: passwordCheck, error: passwordError } = await supabase.rpc(
        "verify_password",
        {
          password: password,
          hash: await this.getPasswordHash(dbUser.id),
        },
      );

      if (passwordError) {
        console.error("Password verification error:", passwordError);
        throw new Error("Authentication failed");
      }

      if (!passwordCheck) {
        // Increment failed login attempts
        await this.incrementFailedLoginAttempts(dbUser.id);
        throw new Error("Invalid username or password");
      }

      // Step 3: Get user permissions
      const permissions = await this.getUserPermissions(dbUser.id);

      // Step 4: Update last login and reset failed attempts
      await this.updateLastLogin(dbUser.id);

      // Step 5: Create session token and return user data
      const token = this.generateSessionToken();
      const user = this.mapDatabaseUserToUser(dbUser, permissions);

      // Step 6: Store session in database
      await this.createUserSession(dbUser.id, token, "username_password");

      return { user, token };
    } catch (error) {
      console.error("Login error:", error);
      throw error;
    }
  }

  /**
   * Authenticate user with quick access code
   */
  async loginWithQuickAccess(
    quickAccessCode: string,
    interfaceType: 'desktop' | 'mobile' | 'customer' = 'desktop'
  ): Promise<{ user: User; token: string }> {
    try {
      console.log("🔍 [UserAuth] Starting quick access login");

      // Step 1: Validate code format
      if (!/^[0-9]{6}$/.test(quickAccessCode)) {
        console.error(
          "❌ [UserAuth] Invalid access code format:",
          quickAccessCode,
        );
        throw new Error("Invalid access code format");
      }

      console.log(
        "🔍 [UserAuth] Querying database for user with quick access code",
      );

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
					role_type,
					position_id,
					avatar
				`,
        )
        .eq("status", "active")
        .eq("quick_access_code", quickAccessCode)
        .limit(1);

      if (userError) {
        console.error("❌ [UserAuth] Database error:", userError);
        throw new Error("Database connection error. Please try again.");
      }

      if (!users || users.length === 0) {
        console.error("❌ [UserAuth] No user found with quick access code");
        throw new Error("Invalid access code");
      }

      const dbUser = users[0];
      console.log("✅ [UserAuth] Found user:", dbUser.username);

      // Step 3: Get user details from view
      console.log("🔍 [UserAuth] Getting user details from view");
      const { data: userDetails, error: userDetailsError } = await supabase
        .from("user_management_view")
        .select("*")
        .eq("id", dbUser.id)
        .single();

      if (userDetailsError || !userDetails) {
        console.error("❌ [UserAuth] User details error:", userDetailsError);
        throw new Error(
          "User account configuration error. Please contact support.",
        );
      }

      console.log("✅ [UserAuth] User details retrieved successfully");

      // Step 4: Get user permissions
      console.log("🔍 [UserAuth] Getting user permissions");
      const permissions = await this.getUserPermissions(dbUser.id);
      console.log("✅ [UserAuth] User permissions retrieved");

      // Step 4.1: Check interface access permission based on interface type
      console.log(`🔍 [UserAuth] Checking ${interfaceType} interface access permission`);
      const { data: interfacePermissions, error: permissionError } = await supabase
        .from("interface_permissions")
        .select("desktop_enabled, mobile_enabled, customer_enabled")
        .eq("user_id", dbUser.id)
        .single();

      if (permissionError) {
        console.log("⚠️ [UserAuth] No interface permissions found, defaulting to enabled");
      } else if (interfacePermissions) {
        const isEnabled = interfacePermissions[`${interfaceType}_enabled`];
        if (!isEnabled) {
          console.error(`❌ [UserAuth] ${interfaceType} interface access denied for user:`, dbUser.username);
          throw new Error(`${interfaceType.charAt(0).toUpperCase() + interfaceType.slice(1)} interface access is disabled for your account. Please contact your administrator${interfaceType !== 'desktop' ? ' or use the desktop interface' : ''}.`);
        }
      }

      console.log(`✅ [UserAuth] ${interfaceType} interface access confirmed`);

      // Step 5: Update last login
      console.log("🔍 [UserAuth] Updating last login timestamp");
      await this.updateLastLogin(dbUser.id);

      // Step 6: Create session token and return user data
      console.log("🔍 [UserAuth] Creating session token");
      const token = this.generateSessionToken();
      const user = this.mapDatabaseUserToUser(
        userDetails as DatabaseUserView,
        permissions,
      );

      // Step 7: Store session in database
      console.log("🔍 [UserAuth] Storing session in database");
      await this.createUserSession(dbUser.id, token, "quick_access");

      console.log("✅ [UserAuth] Quick access login completed successfully");
      return { user, token };
    } catch (error) {
      console.error("❌ [UserAuth] Quick access login error:", error);

      // Rethrow with more specific error messages
      if (error instanceof Error) {
        if (error.message.includes("fetch")) {
          throw new Error(
            "Network connection error. Please check your internet connection.",
          );
        } else if (error.message.includes("Database")) {
          throw new Error("Database connection error. Please try again.");
        } else {
          throw error;
        }
      } else {
        throw new Error("Authentication service error. Please try again.");
      }
    }
  }

  /**
   * Authenticate customer with username and access code
   */
  async loginWithCustomerCredentials(
    username: string,
    accessCode: string,
  ): Promise<{ user: User; token: string; customer: any }> {
    try {
      console.log("🔍 [UserAuth] Starting customer authentication");

      // Step 1: Validate inputs
      if (!username?.trim() || !accessCode?.trim()) {
        throw new Error("Username and access code are required");
      }

      if (!/^[0-9]{6}$/.test(accessCode)) {
        throw new Error("Access code must be 6 digits");
      }

      console.log("🔍 [UserAuth] Calling customer authentication function");

      // Step 2: Authenticate using database function
      const { data: authResult, error: authError } = await supabase.rpc(
        "authenticate_customer_access_code",
        {
          p_username: username.trim(),
          p_access_code: accessCode.trim(),
        },
      );

      if (authError) {
        console.error("❌ [UserAuth] Database authentication error:", authError);
        throw new Error("Authentication service error. Please try again.");
      }

      if (!authResult || !authResult.success) {
        const errorMsg = authResult?.error || "Invalid credentials";
        console.error("❌ [UserAuth] Authentication failed:", errorMsg);
        
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

      console.log("✅ [UserAuth] Customer authenticated successfully");

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
        console.error("❌ [UserAuth] User details error:", userDetailsError);
        throw new Error("User account configuration error. Please contact support.");
      }

      // Get customer details
      const { data: customerDetails, error: customerError } = await supabase
        .from("customers")
        .select("*")
        .eq("id", customerId)
        .single();

      if (customerError || !customerDetails) {
        console.error("❌ [UserAuth] Customer details error:", customerError);
        throw new Error("Customer account error. Please contact support.");
      }

      // Step 4: Get user permissions (customers have limited permissions)
      const permissions = await this.getUserPermissions(userId);

      // Step 4.1: Check customer interface access permission
      console.log("🔍 [UserAuth] Checking customer interface access permission");
      const { data: interfacePermissions, error: permissionError } = await supabase
        .from("interface_permissions")
        .select("customer_enabled")
        .eq("user_id", userId)
        .single();

      if (permissionError) {
        console.log("⚠️ [UserAuth] No interface permissions found, defaulting to enabled");
      } else if (interfacePermissions && !interfacePermissions.customer_enabled) {
        console.error("❌ [UserAuth] Customer interface access denied for user:", userDetails.username);
        throw new Error("Customer interface access is disabled for your account. Please contact your administrator.");
      }

      console.log("✅ [UserAuth] Customer interface access confirmed");

      // Step 5: Update last login for customer
      await supabase
        .from("customers")
        .update({ last_login_at: new Date().toISOString() })
        .eq("id", customerId);

      // Step 6: Create session token
      const token = this.generateSessionToken();
      const user = this.mapDatabaseUserToUser(
        userDetails as DatabaseUserView,
        permissions,
      );

      // Add customer-specific properties
      user.userType = "customer";
      user.customerId = customerId;

      // Step 7: Store session in database
      await this.createUserSession(userId, token, "customer_access");

      console.log("✅ [UserAuth] Customer login completed successfully");
      return { user, token, customer: customerDetails };
    } catch (error) {
      console.error("❌ [UserAuth] Customer login error:", error);

      // Rethrow with more specific error messages
      if (error instanceof Error) {
        if (error.message.includes("fetch")) {
          throw new Error(
            "Network connection error. Please check your internet connection.",
          );
        } else if (error.message.includes("Database")) {
          throw new Error("Database connection error. Please try again.");
        } else {
          throw error;
        }
      } else {
        throw new Error("Customer authentication error. Please try again.");
      }
    }
  }

  /**
   * Validate existing session token
   */
  async validateSession(token: string): Promise<User | null> {
    try {
      // Check if session exists and is active
      const { data: sessions, error: sessionError } = await supabase
        .from("user_sessions")
        .select(
          `
					*,
					users!inner(*)
				`,
        )
        .eq("session_token", token)
        .eq("is_active", true)
        .gt("expires_at", new Date().toISOString())
        .limit(1);

      if (sessionError || !sessions || sessions.length === 0) {
        return null;
      }

      const session = sessions[0];

      // Get user details from view
      const { data: userDetails, error: userError } = await supabase
        .from("user_management_view")
        .select("*")
        .eq("id", session.user_id)
        .eq("status", "active")
        .single();

      if (userError || !userDetails) {
        return null;
      }

      // Get user permissions
      const permissions = await this.getUserPermissions(session.user_id);

      return this.mapDatabaseUserToUser(
        userDetails as DatabaseUserView,
        permissions,
      );
    } catch (error) {
      console.error("Session validation error:", error);
      return null;
    }
  }

  /**
   * Logout user and invalidate session
   */
  async logout(token: string): Promise<void> {
    try {
      // End the session in database
      await supabase
        .from("user_sessions")
        .update({
          is_active: false,
          ended_at: new Date().toISOString(),
        })
        .eq("session_token", token);
    } catch (error) {
      console.error("Logout error:", error);
    }
  }

  // Private helper methods

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

  private mapDatabaseUserToUser(
    dbUser: DatabaseUserView,
    permissions: UserPermissions,
  ): User {
    return {
      id: dbUser.id,
      username: dbUser.username,
      role: dbUser.role_type,
      roleType: dbUser.role_type,
      userType: dbUser.user_type,
      avatar: dbUser.avatar,
      employeeName: dbUser.employee_name,
      branchName: dbUser.branch_name,
      employee_id: dbUser.employee_id,
      branch_id: dbUser.branch_id?.toString(),
      lastLogin: dbUser.last_login,
      permissions,
    };
  }
}

// Export singleton instance
export const userAuth = new UserAuthService();
