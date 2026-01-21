import { supabase } from "./supabase";

// Types for user management
interface CreateUserRequest {
  username: string;
  password: string;
  isMasterAdmin?: boolean;
  isAdmin?: boolean;
  userType: "global" | "branch_specific";
  branchId?: number;
  employeeId?: string;
  positionId?: string;
  quickAccessCode?: string; // Optional - will generate if not provided
}

interface UpdateUserRequest {
  username?: string;
  p_is_master_admin?: boolean;
  p_is_admin?: boolean;
  user_type?: "global" | "branch_specific";
  branch_id?: number | null;
  employee_id?: string | null;
  position_id?: string | null;
  status?: "active" | "inactive" | "locked";
  avatar?: string;
}

interface UserListItem {
  id: string;
  username: string;
  employee_name: string;
  branch_name: string;
  position_title: string;
  is_master_admin: boolean;
  is_admin: boolean;
  status: "active" | "inactive" | "locked";
  avatar?: string;
  last_login?: string;
  is_first_login: boolean;
  failed_login_attempts: number;
  user_type: "global" | "branch_specific";
  created_at: string;
  updated_at: string;
}

export class UserManagementService {
  /**
   * Get all users with their details
   */
  async getAllUsers(): Promise<UserListItem[]> {
    // Get all user details from view
    const { data: viewData, error: viewError } = await supabase
      .from("user_management_view")
      .select("*")
      .order("created_at", { ascending: false });

    if (viewError) {
      console.error("Error fetching users from view:", viewError);
      throw new Error("Failed to fetch users");
    }

    if (!viewData || viewData.length === 0) {
      return [];
    }

    // Map the data to include position_title from the view
    const mappedData = viewData.map((user) => ({
      ...user,
      position_title: user.position_title_en || "Not Assigned",
    }));

    // Return users directly from the view
    // Approval permissions are now managed in the approval_permissions table
    // and accessed through the ApprovalPermissionsManager component
    return mappedData;
  }

  /**
   * Get user by ID
   */
  async getUserById(id: string): Promise<UserListItem | null> {
    const { data, error } = await supabase
      .from("user_management_view")
      .select("*")
      .eq("id", id)
      .single();

    if (error) {
      if (error.code === "PGRST116") {
        // Not found
        return null;
      }
      console.error("Error fetching user:", error);
      throw new Error("Failed to fetch user");
    }

    return data;
  }

  /**
   * Create a new user
   */
  async createUser(
    userData: CreateUserRequest,
  ): Promise<{ success: boolean; user?: any; quickAccessCode?: string }> {
    try {
      // Call the database function to create user
      const { data, error } = await supabase.rpc("create_user", {
        p_username: userData.username,
        p_password: userData.password,
        p_is_master_admin: userData.isMasterAdmin || false,
        p_is_admin: userData.isAdmin || false,
        p_user_type: userData.userType,
        p_branch_id: userData.branchId || null,
        p_employee_id: userData.employeeId || null,
        p_position_id: userData.positionId || null,
        p_quick_access_code: userData.quickAccessCode || null,
      });

      if (error) {
        console.error("Error creating user:", error);
        throw new Error(error.message || "Failed to create user");
      }

      console.log("Create user response:", data);
      
      if (data && data.success) {
        return {
          success: true,
          user: data,
          quickAccessCode: data.quick_access_code,
        };
      } else {
        const errorMessage = data?.message || "User creation failed";
        throw new Error(errorMessage);
      }
    } catch (error) {
      console.error("Create user error:", error);
      throw error;
    }
  }

  /**
   * Update user details
   */
  async updateUser(
    userId: string,
    updates: UpdateUserRequest,
  ): Promise<boolean> {
    try {
      // Use RPC function with SECURITY DEFINER that bypasses RLS
      const { data, error } = await supabase.rpc('update_user', {
        p_user_id: userId,
        p_username: updates.username ?? null,
        p_is_master_admin: updates.p_is_master_admin ?? null,
        p_is_admin: updates.p_is_admin ?? null,
        p_user_type: updates.user_type ?? null,
        p_branch_id: updates.branch_id ?? null,
        p_employee_id: updates.employee_id && updates.employee_id.trim() !== '' ? updates.employee_id : null,
        p_position_id: updates.position_id && updates.position_id.trim() !== '' ? updates.position_id : null,
        p_status: updates.status ?? null,
        p_avatar: updates.avatar ?? null
      });

      if (error) {
        console.error("Error updating user via RPC:", error);
        throw new Error("Failed to update user: " + error.message);
      }

      // Check response from function
      if (data && !data.success) {
        console.error("RPC returned error:", data.message);
        throw new Error(data.message || "Failed to update user");
      }

      console.log("User updated successfully via RPC:", data);
      return true;
    } catch (error) {
      console.error("Update user error:", error);
      throw error;
    }
  }

  /**
   * Delete/deactivate user
   */
  async deleteUser(userId: string): Promise<boolean> {
    try {
      // Instead of deleting, we'll deactivate the user
      const { error } = await supabase
        .from("users")
        .update({ status: "inactive" })
        .eq("id", userId);

      if (error) {
        console.error("Error deactivating user:", error);
        throw new Error("Failed to deactivate user");
      }

      return true;
    } catch (error) {
      console.error("Delete user error:", error);
      throw error;
    }
  }

  /**
   * Reset user password
   */
  async resetUserPassword(
    userId: string,
    newPassword: string,
  ): Promise<boolean> {
    try {
      // Generate salt and hash password
      const { data: saltData, error: saltError } =
        await supabase.rpc("generate_salt");

      if (saltError) {
        throw new Error("Failed to generate password salt");
      }

      const { data: hashedPassword, error: hashError } = await supabase.rpc(
        "hash_password",
        {
          password: newPassword,
          salt: saltData,
        },
      );

      if (hashError) {
        throw new Error("Failed to hash password");
      }

      // Update user password
      const { error } = await supabase
        .from("users")
        .update({
          password_hash: hashedPassword,
          salt: saltData,
          is_first_login: true,
          failed_login_attempts: 0,
          last_password_change: new Date().toISOString(),
        })
        .eq("id", userId);

      if (error) {
        console.error("Error resetting password:", error);
        throw new Error("Failed to reset password");
      }

      return true;
    } catch (error) {
      console.error("Reset password error:", error);
      throw error;
    }
  }

  /**
   * Generate new quick access code for user
   */
  async generateQuickAccessCode(userId: string): Promise<string> {
    try {
      // Generate new unique quick access code
      const { data: newCode, error: codeError } = await supabase.rpc(
        "generate_unique_quick_access_code",
      );

      if (codeError) {
        throw new Error("Failed to generate quick access code");
      }

      // Generate salt and hash the code
      const { data: saltData, error: saltError } =
        await supabase.rpc("generate_salt");

      if (saltError) {
        throw new Error("Failed to generate code salt");
      }

      const { data: hashedCode, error: hashError } = await supabase.rpc(
        "hash_password",
        {
          password: newCode,
          salt: saltData,
        },
      );

      if (hashError) {
        throw new Error("Failed to hash quick access code");
      }

      // Update user with new quick access code
      const { error } = await supabase
        .from("users")
        .update({
          quick_access_code: newCode,
          quick_access_salt: hashedCode,
        })
        .eq("id", userId);

      if (error) {
        console.error("Error updating quick access code:", error);
        throw new Error("Failed to update quick access code");
      }

      return newCode;
    } catch (error) {
      console.error("Generate quick access code error:", error);
      throw error;
    }
  }

  /**
   * Check if username is available
   */
  async isUsernameAvailable(
    username: string,
    excludeUserId?: string,
  ): Promise<boolean> {
    try {
      let query = supabase.from("users").select("id").eq("username", username);

      if (excludeUserId) {
        query = query.neq("id", excludeUserId);
      }

      const { data, error } = await query.limit(1);

      if (error) {
        console.error("Error checking username availability:", error);
        return false;
      }

      return !data || data.length === 0;
    } catch (error) {
      console.error("Username availability check error:", error);
      return false;
    }
  }

  /**
   * Check if quick access code is available
   */
  async isQuickAccessCodeAvailable(code: string): Promise<boolean> {
    try {
      const { data, error } = await supabase.rpc(
        "is_quick_access_code_available",
        {
          p_quick_access_code: code,
        },
      );

      if (error) {
        console.error("Error checking quick access code availability:", error);
        return false;
      }

      return data;
    } catch (error) {
      console.error("Quick access code availability check error:", error);
      return false;
    }
  }

  /**
   * Get user roles for dropdown
   * NOTE: This function is deprecated - user_roles table removed in favor of button permissions system
   */
  async getUserRoles(): Promise<Array<any>> {
    console.warn("getUserRoles is deprecated - user_roles table no longer exists");
    return [];
  }

  /**
   * Get branches for dropdown
   */
  async getBranches(): Promise<
    Array<{ id: number; name_en: string; name_ar: string; location_en: string }>
  > {
    console.log("🔍 [UserManagement] Fetching branches...");

    const { data, error } = await supabase
      .from("branches")
      .select("id, name_en, name_ar, location_en")
      .eq("is_active", true)
      .order("name_en");

    if (error) {
      console.error("❌ [UserManagement] Error fetching branches:", error);
      return [];
    }

    console.log(
      "✅ [UserManagement] Loaded branches:",
      data?.length || 0,
      data,
    );
    return data || [];
  }

  /**
   * Get HR employees for dropdown
   */
  async getEmployees(): Promise<
    Array<{
      id: string;
      employee_id?: string;
      name: string;
      branch_id?: number;
      position_title_en?: string;
    }>
  > {
    console.log("🔍 [UserManagement] Fetching employees...");

    try {
      // First try with position information using left join
      const { data, error } = await supabase
        .from("hr_employees")
        .select(
          `
					id, 
					employee_id,
					name,
					branch_id,
					hr_position_assignments(
						hr_positions(position_title_en)
					)
				`,
        )
        .order("name");

      if (error) {
        console.error("Error fetching employees with positions:", error);
        // Fall back to simple query without position information
        console.log(
          "🔄 [UserManagement] Falling back to simple employee query...",
        );

        const { data: simpleData, error: simpleError } = await supabase
          .from("hr_employees")
          .select(
            `
						id, 
						employee_id,
						name,
						branch_id
					`,
          )
          .order("name");

        if (simpleError) {
          console.error(
            "Error fetching employees (simple query):",
            simpleError,
          );
          return [];
        }

        console.log(
          "✅ [UserManagement] Loaded employees (simple):",
          simpleData?.length || 0,
        );
        return (
          simpleData?.map((emp: any) => ({
            id: emp.id,
            employee_id: emp.employee_id,
            name: emp.name,
            branch_id: emp.branch_id,
            position_title_en: null,
          })) || []
        );
      }

      console.log(
        "✅ [UserManagement] Loaded employees with positions:",
        data?.length || 0,
      );
      return (
        data?.map((emp: any) => ({
          id: emp.id,
          employee_id: emp.employee_id,
          name: emp.name,
          branch_id: emp.branch_id,
          position_title_en:
            emp.hr_position_assignments?.[0]?.hr_positions?.position_title_en ||
            null,
        })) || []
      );
    } catch (error) {
      console.error("Unexpected error fetching employees:", error);
      return [];
    }
  }

  /**
   * Get HR positions for dropdown
   */
  async getPositions(): Promise<
    Array<{ id: string; position_title_en: string; position_title_ar: string }>
  > {
    const { data, error } = await supabase
      .from("hr_positions")
      .select("id, position_title_en, position_title_ar")
      .order("position_title_en");

    if (error) {
      console.error("Error fetching positions:", error);
      return [];
    }

    return data || [];
  }

  /**
   * Get quick access code usage statistics
   */
  async getQuickAccessStats(): Promise<any> {
    try {
      const { data, error } = await supabase.rpc("get_quick_access_stats");

      if (error) {
        console.error("Error fetching quick access stats:", error);
        return null;
      }

      return data;
    } catch (error) {
      console.error("Quick access stats error:", error);
      return null;
    }
  }
}

// Export singleton instance
export const userManagement = new UserManagementService();
