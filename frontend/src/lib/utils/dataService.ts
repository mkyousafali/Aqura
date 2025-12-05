/**
 * Data Service - Handles switching between mock and Supabase data
 * Provides unified interface for data operations with offline support
 */

import {
  db,
  offline,
  supabase,
  type Employee,
  type Branch,
  type Vendor,
  type User,
} from "./supabase";
// offlineDataManager removed - using localStorage caching instead

// Configuration
const USE_SUPABASE = true; // Set to true when Supabase is configured
const MOCK_DATA_DELAY = 300; // Simulate network delay for mock data

// Mock data (same as before but exported for reuse)
const mockEmployees: Employee[] = [
  {
    id: "1",
    name: "أحمد محمد الأحمد",
    email: "ahmed.mohamed@aqura.sa",
    phone: "+966-50-123-4567",
    position: "Senior Developer",
    department: "IT",
    salary: 12000,
    hire_date: "2022-01-15",
    status: "active",
    avatar_url:
      "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face",
    branch_id: "1",
    created_at: "2022-01-15T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
  {
    id: "2",
    name: "فاطمة علي السالم",
    email: "fatima.ali@aqura.sa",
    phone: "+966-50-234-5678",
    position: "Marketing Manager",
    department: "Marketing",
    salary: 9500,
    hire_date: "2021-06-20",
    status: "active",
    avatar_url:
      "https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face",
    branch_id: "1",
    created_at: "2021-06-20T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
  {
    id: "3",
    name: "خالد عبدالله النصر",
    email: "khalid.abdullah@aqura.sa",
    phone: "+966-50-345-6789",
    position: "Sales Representative",
    department: "Sales",
    salary: 7000,
    hire_date: "2023-03-10",
    status: "on_leave",
    avatar_url:
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face",
    branch_id: "2",
    created_at: "2023-03-10T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
];

const mockBranches: Branch[] = [
  {
    id: "1",
    name_en: "Central Riyadh",
    name_ar: "الرياض المركزي",
    location_en: "King Fahd Road, Riyadh 12345",
    location_ar: "شارع الملك فهد، الرياض 12345",
    is_active: true,
    is_main_branch: true,
    created_at: "2020-01-15T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
  {
    id: "2",
    name_en: "West Jeddah",
    name_ar: "جدة الغربي",
    location_en: "Prince Abdulaziz Road, Jeddah 21589",
    location_ar: "طريق الأمير عبدالعزيز، جدة 21589",
    is_active: true,
    is_main_branch: false,
    created_at: "2020-03-20T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
  {
    id: "3",
    name_en: "East Dammam",
    name_ar: "الدمام الشرقي",
    location_en: "King Saud Road, Dammam 34217",
    location_ar: "شارع الملك سعود، الدمام 34217",
    is_active: true,
    is_main_branch: false,
    created_at: "2020-06-10T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
];

const mockVendors: Vendor[] = [
  {
    id: "1",
    name: "محمد أحمد التجاري",
    company: "شركة التقنية المتقدمة",
    email: "mohammed@techadvanced.sa",
    phone: "+966-50-111-2222",
    category: "Technology",
    status: "active",
    payment_terms: "30 days",
    tax_id: "1234567890",
    registration_number: "CR-12345678",
    address: "الرياض، المملكة العربية السعودية",
    total_orders: 45,
    created_at: "2021-01-10T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
  {
    id: "2",
    name: "سارة علي المكتبي",
    company: "مؤسسة اللوازم المكتبية",
    email: "sara@officesupplies.sa",
    phone: "+966-50-222-3333",
    category: "Office Supplies",
    status: "active",
    payment_terms: "15 days",
    tax_id: "2345678901",
    registration_number: "CR-23456789",
    address: "جدة، المملكة العربية السعودية",
    total_orders: 28,
    created_at: "2021-03-15T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
  {
    id: "3",
    name: "عبدالرحمن صالح الصناعي",
    company: "الشركة الصناعية الحديثة",
    email: "abdulrahman@modernindustrial.sa",
    phone: "+966-50-333-4444",
    category: "Manufacturing",
    status: "pending",
    payment_terms: "45 days",
    tax_id: "3456789012",
    registration_number: "CR-34567890",
    address: "الدمام، المملكة العربية السعودية",
    total_orders: 12,
    created_at: "2023-11-20T00:00:00Z",
    updated_at: "2024-01-15T00:00:00Z",
  },
];

// Utility function to simulate network delay
const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// Unified data service interface
export const dataService = {
  // Employee operations
  employees: {
    async getAll(): Promise<{ data: Employee[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          // Try to get fresh data from Supabase
          const result = await db.employees.getAll();

          // Cache the data for offline use
          if (result.data) {
            localStorage.setItem("cache:employees", JSON.stringify(result.data));
          }

          return result;
        } catch (error) {
          // Fallback to cached data if offline
          console.warn("Supabase failed, using cached data:", error);
          const cachedStr = localStorage.getItem("cache:employees");
          const cachedData = cachedStr ? JSON.parse(cachedStr) : [];
          return {
            data: cachedData.length > 0 ? cachedData : mockEmployees,
            error: null,
          };
        }
      } else {
        // Use mock data with simulated delay
        await delay(MOCK_DATA_DELAY);
        return { data: mockEmployees, error: null };
      }
    },

    async getById(id: string): Promise<{ data: Employee | null; error: any }> {
      if (USE_SUPABASE) {
        return await db.employees.getById(id);
      } else {
        await delay(MOCK_DATA_DELAY);
        const employee = mockEmployees.find((e) => e.id === id);
        return {
          data: employee || null,
          error: employee ? null : "Employee not found",
        };
      }
    },

    async create(
      employee: Omit<Employee, "id" | "created_at" | "updated_at">,
    ): Promise<{ data: Employee | null; error: any }> {
      if (USE_SUPABASE) {
        const result = await db.employees.create(employee);

        // If offline, queue the operation (note: offlineDataManager removed, pending ops not supported)
        if (!navigator.onLine && !result.data) {
          console.warn("Offline: Employee creation queued but not persisted (offlineDataManager removed)");
        }

        return result;
      } else {
        await delay(MOCK_DATA_DELAY);
        const newEmployee: Employee = {
          ...employee,
          id: Date.now().toString(),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        mockEmployees.unshift(newEmployee);
        return { data: newEmployee, error: null };
      }
    },

    async update(
      id: string,
      updates: Partial<Employee>,
    ): Promise<{ data: Employee | null; error: any }> {
      if (USE_SUPABASE) {
        const result = await db.employees.update(id, updates);

        // If offline, queue the operation (note: offlineDataManager removed)
        if (!navigator.onLine && !result.data) {
          console.warn("Offline: Employee update queued but not persisted (offlineDataManager removed)");
        }

        return result;
      } else {
        await delay(MOCK_DATA_DELAY);
        const index = mockEmployees.findIndex((e) => e.id === id);
        if (index !== -1) {
          mockEmployees[index] = {
            ...mockEmployees[index],
            ...updates,
            updated_at: new Date().toISOString(),
          };
          return { data: mockEmployees[index], error: null };
        }
        return { data: null, error: "Employee not found" };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        const result = await db.employees.delete(id);

        // If offline, queue the operation (note: offlineDataManager removed)
        if (!navigator.onLine && result.error) {
          console.warn("Offline: Employee deletion queued but not persisted (offlineDataManager removed)");
        }

        return result;
      } else {
        await delay(MOCK_DATA_DELAY);
        const index = mockEmployees.findIndex((e) => e.id === id);
        if (index !== -1) {
          mockEmployees.splice(index, 1);
          return { error: null };
        }
        return { error: "Employee not found" };
      }
    },
  },

  // HR Master operations
  hrDepartments: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_departments")
            .select("*")
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR departments:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(department: {
      department_name_en: string;
      department_name_ar: string;
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_departments")
            .insert([department])
            .select()
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR department:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: {
            id: Date.now(),
            ...department,
            created_at: new Date().toISOString(),
          },
          error: null,
        };
      }
    },

    async update(
      id: string,
      updates: Partial<{
        department_name_en: string;
        department_name_ar: string;
      }>,
    ): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_departments")
            .update(updates)
            .eq("id", id)
            .select()
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to update HR department:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: { id, ...updates, updated_at: new Date().toISOString() },
          error: null,
        };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        try {
          const { error } = await supabase
            .from("hr_departments")
            .delete()
            .eq("id", id);

          return { error };
        } catch (error) {
          console.error("Failed to delete HR department:", error);
          return { error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { error: null };
      }
    },
  },

  // HR Levels operations
  hrLevels: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_levels")
            .select("*")
            .order("level_order", { ascending: true });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR levels:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(level: {
      level_name_en: string;
      level_name_ar: string;
      level_order: number;
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_levels")
            .insert([level])
            .select()
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR level:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: {
            id: Date.now(),
            ...level,
            created_at: new Date().toISOString(),
          },
          error: null,
        };
      }
    },

    async update(
      id: string,
      updates: Partial<{
        level_name_en: string;
        level_name_ar: string;
        level_order: number;
      }>,
    ): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_levels")
            .update(updates)
            .eq("id", id)
            .select()
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to update HR level:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: { id, ...updates, updated_at: new Date().toISOString() },
          error: null,
        };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        try {
          const { error } = await supabase
            .from("hr_levels")
            .delete()
            .eq("id", id);

          return { error };
        } catch (error) {
          console.error("Failed to delete HR level:", error);
          return { error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { error: null };
      }
    },
  },

  // HR Positions operations
  hrPositions: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_positions")
            .select(
              `
							*,
							hr_departments:department_id (
								id,
								department_name_en,
								department_name_ar
							),
							hr_levels:level_id (
								id,
								level_name_en,
								level_name_ar,
								level_order
							)
						`,
            )
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR positions:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(position: {
      position_title_en: string;
      position_title_ar: string;
      department_id: string;
      level_id: string;
      description?: string;
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_positions")
            .insert([position])
            .select(
              `
							*,
							hr_departments:department_id (
								id,
								department_name_en,
								department_name_ar
							),
							hr_levels:level_id (
								id,
								level_name_en,
								level_name_ar,
								level_order
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR position:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: {
            id: Date.now(),
            ...position,
            created_at: new Date().toISOString(),
          },
          error: null,
        };
      }
    },

    async update(
      id: string,
      updates: Partial<{
        position_title_en: string;
        position_title_ar: string;
        department_id: string;
        level_id: string;
        description: string;
      }>,
    ): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_positions")
            .update(updates)
            .eq("id", id)
            .select(
              `
							*,
							hr_departments:department_id (
								id,
								department_name_en,
								department_name_ar
							),
							hr_levels:level_id (
								id,
								level_name_en,
								level_name_ar,
								level_order
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to update HR position:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: { id, ...updates, updated_at: new Date().toISOString() },
          error: null,
        };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        try {
          const { error } = await supabase
            .from("hr_positions")
            .delete()
            .eq("id", id);

          return { error };
        } catch (error) {
          console.error("Failed to delete HR position:", error);
          return { error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { error: null };
      }
    },
  },

  // HR Employees operations (complete view)
  hrEmployees: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employees")
            .select(
              `
							*,
							branch:branch_id (
								id,
								name_en,
								name_ar,
								location_en,
								location_ar
							)
						`,
            )
            .order("employee_id", { ascending: true });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR employees:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getByBranch(
      branchId: string,
    ): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          // First, get employees with their basic info
          const { data: employees, error: employeeError } = await supabase
            .from("hr_employees")
            .select(
              `
							*,
							branch:branch_id (
								id,
								name_en,
								name_ar,
								location_en,
								location_ar
							)
						`,
            )
            .eq("branch_id", branchId)
            .order("employee_id", { ascending: true });

          if (employeeError) {
            console.error("Employee query error:", employeeError);
            throw employeeError;
          }

          if (!employees || employees.length === 0) {
            return { data: [], error: null };
          }

          // Get position assignments and related data
          const employeeIds = employees.map((emp) => emp.id);
          console.log("Looking for assignments for employee IDs:", employeeIds);

          const { data: assignments, error: assignmentError } = await supabase
            .from("hr_position_assignments")
            .select("*")
            .in("employee_id", employeeIds)
            .eq("is_current", true);

          console.log("Assignment query result:", {
            assignments,
            assignmentError,
          });

          if (assignmentError) {
            console.error("Assignment query error:", assignmentError);
          }

          // Get positions for the found assignments
          let positions = [];
          let departments = [];

          if (assignments && assignments.length > 0) {
            const positionIds = [
              ...new Set(assignments.map((a) => a.position_id)),
            ];
            const departmentIds = [
              ...new Set(assignments.map((a) => a.department_id)),
            ];

            console.log("Position IDs:", positionIds);
            console.log("Department IDs:", departmentIds);

            // Get positions
            const { data: positionsData, error: positionsError } =
              await supabase
                .from("hr_positions")
                .select("*")
                .in("id", positionIds);

            console.log("Positions query result:", {
              positionsData,
              positionsError,
            });
            positions = positionsData || [];

            // Get departments
            const { data: departmentsData, error: departmentsError } =
              await supabase
                .from("hr_departments")
                .select("*")
                .in("id", departmentIds);

            console.log("Departments query result:", {
              departmentsData,
              departmentsError,
            });
            departments = departmentsData || [];
          }

          // Merge all data together
          const enrichedEmployees = employees.map((employee) => {
            const assignment = assignments?.find(
              (a) => a.employee_id === employee.id,
            );
            const position = assignment
              ? positions.find((p) => p.id === assignment.position_id)
              : null;
            const department = assignment
              ? departments.find((d) => d.id === assignment.department_id)
              : null;

            console.log(`Employee ${employee.name}:`, {
              assignment,
              position,
              department,
            });

            return {
              ...employee,
              department:
                department?.department_name_en ||
                department?.department_name_ar ||
                null,
              position:
                position?.position_title_en ||
                position?.position_title_ar ||
                null,
              department_code: department?.department_code || null,
              position_code: position?.position_code || null,
              assignment_data: assignment, // For debugging
            };
          });

          return { data: enrichedEmployees, error: null };
        } catch (error) {
          console.error("Failed to fetch HR employees by branch:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(employee: {
      employee_id: string;
      name: string;
      branch_id: string;
      hire_date?: string;
      status?: string;
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employees")
            .insert([
              {
                employee_id: employee.employee_id,
                name: employee.name,
                branch_id: employee.branch_id,
                hire_date: employee.hire_date,
                status: employee.status || "active",
                created_at: new Date().toISOString(),
              },
            ])
            .select()
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR employee:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: {
            id: Date.now(),
            ...employee,
            created_at: new Date().toISOString(),
          },
          error: null,
        };
      }
    },

    async syncEmployee(
      employeeId: string,
      hrCode: string,
      name: string,
      branchId?: string,
      positionTitle?: string,
    ): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase.rpc("sync_employee_with_hr", {
            p_employee_id: employeeId,
            p_employee_code: hrCode,
            p_employee_name: name,
            p_branch_id: branchId || null,
            p_position_title: positionTitle || null,
          });

          return { data, error };
        } catch (error) {
          console.error("Failed to sync employee with HR:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: { success: true }, error: null };
      }
    },
  },

  // Organizational chart
  organizationalChart: {
    async getChart(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("v_organizational_chart_real")
            .select("*")
            .order("level_order", { ascending: true });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch organizational chart:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },
  },

  // Branch operations
  branches: {
    async getAll(): Promise<{ data: Branch[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("branches")
            .select("*")
            .eq("is_active", true)
            .order("name_en", { ascending: true });

          if (error) {
            console.error("Failed to fetch branches:", error);
            return { data: null, error: error.message };
          }

          if (data) {
            localStorage.setItem("cache:branches", JSON.stringify(data));
          }
          return { data, error: null };
        } catch (error) {
          console.error("Error fetching branches:", error);
          const cachedStr = localStorage.getItem("cache:branches");
          const cachedData = cachedStr ? JSON.parse(cachedStr) : [];
          return {
            data: cachedData.length > 0 ? cachedData : mockBranches,
            error: null,
          };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: mockBranches, error: null };
      }
    },

    async create(
      branch: Omit<Branch, "id" | "created_at" | "updated_at">,
    ): Promise<{ data: Branch | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("branches")
            .insert([
              {
                name_en: branch.name_en,
                name_ar: branch.name_ar,
                location_en: branch.location_en,
                location_ar: branch.location_ar,
                is_active:
                  branch.is_active !== undefined ? branch.is_active : true,
                is_main_branch: branch.is_main_branch || false,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
              },
            ])
            .select()
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create branch:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        const newBranch: Branch = {
          ...branch,
          id: Date.now().toString(),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        mockBranches.unshift(newBranch);
        return { data: newBranch, error: null };
      }
    },

    async update(
      id: string,
      updates: Partial<Branch>,
    ): Promise<{ data: Branch | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("branches")
            .update({
              ...updates,
              updated_at: new Date().toISOString(),
            })
            .eq("id", id)
            .select()
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to update branch:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        const index = mockBranches.findIndex((b) => b.id === id);
        if (index !== -1) {
          mockBranches[index] = {
            ...mockBranches[index],
            ...updates,
            updated_at: new Date().toISOString(),
          };
          return { data: mockBranches[index], error: null };
        }
        return { data: null, error: "Branch not found" };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        try {
          const { error } = await supabase
            .from("branches")
            .update({ is_active: false })
            .eq("id", id);

          return { error };
        } catch (error) {
          console.error("Failed to delete branch:", error);
          return { error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        const index = mockBranches.findIndex((b) => b.id === id);
        if (index !== -1) {
          mockBranches.splice(index, 1);
          return { error: null };
        }
        return { error: "Branch not found" };
      }
    },
  },

  // Vendor operations
  vendors: {
    async getAll(): Promise<{ data: Vendor[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const result = await db.vendors.getAll();
          if (result.data) {
            localStorage.setItem("cache:vendors", JSON.stringify(result.data));
          }
          return result;
        } catch (error) {
          const cachedStr = localStorage.getItem("cache:vendors");
          const cachedData = cachedStr ? JSON.parse(cachedStr) : [];
          return {
            data: cachedData.length > 0 ? cachedData : mockVendors,
            error: null,
          };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: mockVendors, error: null };
      }
    },

    async create(
      vendor: Omit<Vendor, "id" | "created_at" | "updated_at">,
    ): Promise<{ data: Vendor | null; error: any }> {
      if (USE_SUPABASE) {
        return await db.vendors.create(vendor);
      } else {
        await delay(MOCK_DATA_DELAY);
        const newVendor: Vendor = {
          ...vendor,
          id: Date.now().toString(),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        mockVendors.unshift(newVendor);
        return { data: newVendor, error: null };
      }
    },

    async update(
      id: string,
      updates: Partial<Vendor>,
    ): Promise<{ data: Vendor | null; error: any }> {
      if (USE_SUPABASE) {
        return await db.vendors.update(id, updates);
      } else {
        await delay(MOCK_DATA_DELAY);
        const index = mockVendors.findIndex((v) => v.id === id);
        if (index !== -1) {
          mockVendors[index] = {
            ...mockVendors[index],
            ...updates,
            updated_at: new Date().toISOString(),
          };
          return { data: mockVendors[index], error: null };
        }
        return { data: null, error: "Vendor not found" };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        return await db.vendors.delete(id);
      } else {
        await delay(MOCK_DATA_DELAY);
        const index = mockVendors.findIndex((v) => v.id === id);
        if (index !== -1) {
          mockVendors.splice(index, 1);
          return { error: null };
        }
        return { error: "Vendor not found" };
      }
    },
  },

  // HR Reporting operations
  hrReporting: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_position_reporting_template")
            .select(
              `
							*,
							subordinate_position:subordinate_position_id (
								id,
								position_title_en,
								position_title_ar,
								hr_departments:department_id (
									id,
									department_name_en,
									department_name_ar
								),
								hr_levels:level_id (
									id,
									level_name_en,
									level_name_ar,
									level_order
								)
							),
							manager_1:manager_position_1 (
								id,
								position_title_en,
								position_title_ar
							),
							manager_2:manager_position_2 (
								id,
								position_title_en,
								position_title_ar
							),
							manager_3:manager_position_3 (
								id,
								position_title_en,
								position_title_ar
							),
							manager_4:manager_position_4 (
								id,
								position_title_en,
								position_title_ar
							),
							manager_5:manager_position_5 (
								id,
								position_title_en,
								position_title_ar
							)
						`,
            )
            .eq("is_active", true)
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR reporting maps:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(reportingMap: {
      subordinate_position_id: string;
      manager_positions: string[];
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const insertData: any = {
            subordinate_position_id: reportingMap.subordinate_position_id,
            is_active: true,
            created_at: new Date().toISOString(),
          };

          // Set manager positions (up to 5 slots)
          if (reportingMap.manager_positions[0])
            insertData.manager_position_1 = reportingMap.manager_positions[0];
          if (reportingMap.manager_positions[1])
            insertData.manager_position_2 = reportingMap.manager_positions[1];
          if (reportingMap.manager_positions[2])
            insertData.manager_position_3 = reportingMap.manager_positions[2];
          if (reportingMap.manager_positions[3])
            insertData.manager_position_4 = reportingMap.manager_positions[3];
          if (reportingMap.manager_positions[4])
            insertData.manager_position_5 = reportingMap.manager_positions[4];

          const { data, error } = await supabase
            .from("hr_position_reporting_template")
            .insert([insertData])
            .select(
              `
							*,
							subordinate_position:subordinate_position_id (
								id,
								position_title_en,
								position_title_ar
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR reporting map:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: {
            id: Date.now(),
            ...reportingMap,
            created_at: new Date().toISOString(),
          },
          error: null,
        };
      }
    },

    async update(
      id: string,
      updates: { manager_positions: string[] },
    ): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const updateData: any = {};

          // Clear all manager positions first
          updateData.manager_position_1 = null;
          updateData.manager_position_2 = null;
          updateData.manager_position_3 = null;
          updateData.manager_position_4 = null;
          updateData.manager_position_5 = null;

          // Set new manager positions (up to 5 slots)
          if (updates.manager_positions[0])
            updateData.manager_position_1 = updates.manager_positions[0];
          if (updates.manager_positions[1])
            updateData.manager_position_2 = updates.manager_positions[1];
          if (updates.manager_positions[2])
            updateData.manager_position_3 = updates.manager_positions[2];
          if (updates.manager_positions[3])
            updateData.manager_position_4 = updates.manager_positions[3];
          if (updates.manager_positions[4])
            updateData.manager_position_5 = updates.manager_positions[4];

          const { data, error } = await supabase
            .from("hr_position_reporting_template")
            .update(updateData)
            .eq("id", id)
            .select(
              `
							*,
							subordinate_position:subordinate_position_id (
								id,
								position_title_en,
								position_title_ar
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to update HR reporting map:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: { id, ...updates }, error: null };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        try {
          const { error } = await supabase
            .from("hr_position_reporting_template")
            .delete()
            .eq("id", id);

          return { error };
        } catch (error) {
          console.error("Failed to delete HR reporting map:", error);
          return { error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { error: null };
      }
    },
  },

  // HR Position Assignments operations
  hrAssignments: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_position_assignments")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							),
							position:position_id (
								id,
								position_title_en,
								position_title_ar
							),
							department:department_id (
								id,
								department_name_en,
								department_name_ar
							),
							level:level_id (
								id,
								level_name_en,
								level_name_ar,
								level_order
							),
							branch:branch_id (
								id,
								name_en,
								name_ar,
								location_en,
								location_ar
							)
						`,
            )
            .eq("is_current", true)
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR assignments:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getByBranch(
      branchId: string,
    ): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_position_assignments")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							),
							position:position_id (
								id,
								position_title_en,
								position_title_ar
							),
							department:department_id (
								id,
								department_name_en,
								department_name_ar
							),
							level:level_id (
								id,
								level_name_en,
								level_name_ar,
								level_order
							),
							branch:branch_id (
								id,
								name_en,
								name_ar,
								location_en,
								location_ar
							)
						`,
            )
            .eq("branch_id", branchId)
            .eq("is_current", true)
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR assignments by branch:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(assignment: {
      employee_id: string;
      position_id: string;
      department_id: string;
      level_id: string;
      branch_id: string;
      effective_date?: string;
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          // First, mark any existing current assignment for this employee as not current
          await supabase
            .from("hr_position_assignments")
            .update({ is_current: false })
            .eq("employee_id", assignment.employee_id)
            .eq("is_current", true);

          // Create the new assignment
          const { data, error } = await supabase
            .from("hr_position_assignments")
            .insert([
              {
                employee_id: assignment.employee_id,
                position_id: assignment.position_id,
                department_id: assignment.department_id,
                level_id: assignment.level_id,
                branch_id: assignment.branch_id,
                effective_date:
                  assignment.effective_date ||
                  new Date().toISOString().split("T")[0],
                is_current: true,
                created_at: new Date().toISOString(),
              },
            ])
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							),
							position:position_id (
								id,
								position_title_en,
								position_title_ar
							),
							department:department_id (
								id,
								department_name_en,
								department_name_ar
							),
							level:level_id (
								id,
								level_name_en,
								level_name_ar,
								level_order
							),
							branch:branch_id (
								id,
								name_en,
								name_ar,
								location_en,
								location_ar
							)
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR assignment:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: {
            id: Date.now(),
            ...assignment,
            created_at: new Date().toISOString(),
          },
          error: null,
        };
      }
    },

    async update(
      id: string,
      updates: Partial<{
        position_id: string;
        department_id: string;
        level_id: string;
        effective_date: string;
      }>,
    ): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_position_assignments")
            .update(updates)
            .eq("id", id)
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							),
							position:position_id (
								id,
								position_title_en,
								position_title_ar
							),
							department:department_id (
								id,
								department_name_en,
								department_name_ar
							),
							level:level_id (
								id,
								level_name_en,
								level_name_ar,
								level_order
							),
							branch:branch_id (
								id,
								name_en,
								name_ar,
								location_en,
								location_ar
							)
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to update HR assignment:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: { id, ...updates, updated_at: new Date().toISOString() },
          error: null,
        };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        try {
          // Instead of deleting, mark as not current
          const { error } = await supabase
            .from("hr_position_assignments")
            .update({ is_current: false })
            .eq("id", id);

          return { error };
        } catch (error) {
          console.error("Failed to delete HR assignment:", error);
          return { error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { error: null };
      }
    },
  },

  // HR Fingerprint Transactions operations
  hrFingerprint: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const allData: any[] = [];
          let page = 0;
          const pageSize = 1000;
          let hasMore = true;

          while (hasMore) {
            const from = page * pageSize;
            const to = from + pageSize - 1;

            const { data, error, count } = await supabase
              .from("hr_fingerprint_transactions")
              .select("*", { count: "exact" })
              .order("date", { ascending: false })
              .order("time", { ascending: false })
              .range(from, to);

            if (error) {
              console.error("Failed to fetch HR fingerprint transactions:", error);
              return { data: null, error: error.message };
            }

            if (data && data.length > 0) {
              allData.push(...data);
            }

            hasMore = data && data.length === pageSize;
            page++;
          }

          return { data: allData, error: null };
        } catch (error) {
          console.error("Failed to fetch HR fingerprint transactions:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getByDate(date: string): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_fingerprint_transactions")
            .select("*")
            .eq("date", date)
            .order("time", { ascending: false });

          if (error) {
            console.error("Failed to fetch HR fingerprint transactions by date:", error);
            return { data: null, error: error.message };
          }

          return { data, error: null };
        } catch (error) {
          console.error("Failed to fetch HR fingerprint transactions by date:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getByDateRange(startDate: string, endDate: string): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_fingerprint_transactions")
            .select("*")
            .gte("date", startDate)
            .lte("date", endDate)
            .order("date", { ascending: false })
            .order("time", { ascending: false });

          if (error) {
            console.error("Failed to fetch HR fingerprint transactions by date range:", error);
            return { data: null, error: error.message };
          }

          return { data, error: null };
        } catch (error) {
          console.error("Failed to fetch HR fingerprint transactions by date range:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getByBranch(
      branchId: string,
    ): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const allData: any[] = [];
          let page = 0;
          const pageSize = 1000;
          let hasMore = true;

          while (hasMore) {
            const from = page * pageSize;
            const to = from + pageSize - 1;

            const { data, error } = await supabase
              .from("hr_fingerprint_transactions")
              .select("*")
              .eq("branch_id", branchId)
              .order("date", { ascending: false })
              .order("time", { ascending: false })
              .range(from, to);

            if (error) {
              console.error(
                "Failed to fetch HR fingerprint transactions by branch:",
                error,
              );
              return { data: null, error: error.message };
            }

            if (data && data.length > 0) {
              allData.push(...data);
            }

            hasMore = data && data.length === pageSize;
            page++;
          }

          return { data: allData, error: null };
        } catch (error) {
          console.error(
            "Failed to fetch HR fingerprint transactions by branch:",
            error,
          );
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(transaction: {
      employee_id: string;
      name?: string;
      branch_id: number;
      transaction_date: string;
      transaction_time: string;
      punch_state: string;
      device_id?: string;
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_fingerprint_transactions")
            .insert([
              {
                employee_id: transaction.employee_id,
                name: transaction.name,
                branch_id: String(transaction.branch_id), // Convert to string to handle potential type mismatch
                transaction_date: transaction.transaction_date,
                transaction_time: transaction.transaction_time,
                punch_state: transaction.punch_state,
                device_id: transaction.device_id,
                created_at: new Date().toISOString(),
              },
            ])
            .select()
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR fingerprint transaction:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: {
            id: Date.now(),
            ...transaction,
            created_at: new Date().toISOString(),
          },
          error: null,
        };
      }
    },

    async createMany(transactions: any[]): Promise<{
      data: any[] | null;
      error: any;
      successCount: number;
      errorCount: number;
      errors: string[];
    }> {
      if (USE_SUPABASE) {
        let successCount = 0;
        let errorCount = 0;
        const errors = [];
        const successfulData = [];

        for (const [index, transaction] of transactions.entries()) {
          try {
            const { data, error } = await this.create(transaction);
            if (error) {
              errors.push(`Row ${index + 1}: ${error.message}`);
              errorCount++;
            } else {
              successfulData.push(data);
              successCount++;
            }
          } catch (error) {
            errors.push(`Row ${index + 1}: ${error.message}`);
            errorCount++;
          }
        }

        return {
          data: successfulData,
          error: errorCount > 0 ? `${errorCount} transactions failed` : null,
          successCount,
          errorCount,
          errors,
        };
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: transactions,
          error: null,
          successCount: transactions.length,
          errorCount: 0,
          errors: [],
        };
      }
    },
  },

  hrContacts: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employee_contacts")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .eq("is_active", true)
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR employee contacts:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getByBranch(
      branchId: string,
    ): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          // Get employees for this branch first, then their contacts
          const { data: employees, error: empError } = await supabase
            .from("hr_employees")
            .select("id")
            .eq("branch_id", branchId);

          if (empError) {
            return { data: null, error: empError };
          }

          const employeeIds = employees.map((emp) => emp.id);

          if (employeeIds.length === 0) {
            return { data: [], error: null };
          }

          const { data, error } = await supabase
            .from("hr_employee_contacts")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .in("employee_id", employeeIds)
            .eq("is_active", true)
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error(
            "Failed to fetch HR employee contacts by branch:",
            error,
          );
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(contact: {
      employee_id: string;
      whatsapp_number?: string;
      contact_number?: string;
      email?: string;
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employee_contacts")
            .insert([
              {
                employee_id: contact.employee_id,
                whatsapp_number: contact.whatsapp_number,
                contact_number: contact.contact_number,
                email: contact.email,
                is_active: true,
                created_at: new Date().toISOString(),
              },
            ])
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR employee contact:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: {
            id: Date.now(),
            ...contact,
            created_at: new Date().toISOString(),
          },
          error: null,
        };
      }
    },

    async update(
      id: string,
      updates: {
        whatsapp_number?: string;
        contact_number?: string;
        email?: string;
      },
    ): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employee_contacts")
            .update({
              ...updates,
              updated_at: new Date().toISOString(),
            })
            .eq("id", id)
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to update HR employee contact:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: { id, ...updates, updated_at: new Date().toISOString() },
          error: null,
        };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        try {
          const { error } = await supabase
            .from("hr_employee_contacts")
            .update({ is_active: false })
            .eq("id", id);

          return { error };
        } catch (error) {
          console.error("Failed to delete HR employee contact:", error);
          return { error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { error: null };
      }
    },
  },

  hrDocuments: {
    async getAll(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employee_documents")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .eq("is_active", true)
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch HR documents:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getByEmployeeId(
      employeeId: string,
    ): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employee_documents")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .eq("employee_id", employeeId)
            .eq("is_active", true)
            .order("created_at", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch employee documents:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getByBranch(
      branchId: number,
    ): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          // Get documents for employees in the specified branch
          const { data, error } = await supabase
            .from("hr_employee_documents")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name,
								branch_id
							)
						`,
            )
            .eq("is_active", true)
            .order("created_at", { ascending: false });

          // Filter by branch in application layer
          const branchDocuments =
            data?.filter((doc) => doc.employee?.branch_id === branchId) || [];

          return { data: branchDocuments, error };
        } catch (error) {
          console.error("Failed to fetch branch documents:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async create(documentData: {
      employee_id: string;
      document_type: string;
      document_name: string;
      document_number?: string;
      document_description?: string;
      file_path: string;
      file_type?: string;
      expiry_date?: string;
      document_category?: string;
      category_start_date?: string;
      category_end_date?: string;
      category_days?: number;
      category_last_working_day?: string;
      category_reason?: string;
      category_details?: string;
      category_content?: string;
    }): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employee_documents")
            .insert([
              {
                ...documentData,
                upload_date: new Date().toISOString().split("T")[0],
                created_at: new Date().toISOString(),
              },
            ])
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to create HR document:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        const newDocument = {
          id: `doc_${Date.now()}`,
          ...documentData,
          upload_date: new Date().toISOString().split("T")[0],
          created_at: new Date().toISOString(),
          is_active: true,
        };
        return { data: newDocument, error: null };
      }
    },

    async update(
      id: string,
      updates: {
        document_name?: string;
        document_number?: string;
        file_path?: string;
        file_size?: number;
        file_type?: string;
        expiry_date?: string;
      },
    ): Promise<{ data: any | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const { data, error } = await supabase
            .from("hr_employee_documents")
            .update({
              ...updates,
              updated_at: new Date().toISOString(),
            })
            .eq("id", id)
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .single();

          return { data, error };
        } catch (error) {
          console.error("Failed to update HR document:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return {
          data: { id, ...updates, updated_at: new Date().toISOString() },
          error: null,
        };
      }
    },

    async delete(id: string): Promise<{ error: any }> {
      if (USE_SUPABASE) {
        try {
          const { error } = await supabase
            .from("hr_employee_documents")
            .update({
              is_active: false,
              updated_at: new Date().toISOString(),
            })
            .eq("id", id);

          return { error };
        } catch (error) {
          console.error("Failed to delete HR document:", error);
          return { error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { error: null };
      }
    },

    async getExpiringSoon(
      days: number = 30,
    ): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const expiryDate = new Date();
          expiryDate.setDate(expiryDate.getDate() + days);

          const { data, error } = await supabase
            .from("hr_employee_documents")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .eq("is_active", true)
            .not("expiry_date", "is", null)
            .lte("expiry_date", expiryDate.toISOString().split("T")[0])
            .gte("expiry_date", new Date().toISOString().split("T")[0])
            .order("expiry_date", { ascending: true });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch expiring documents:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },

    async getExpired(): Promise<{ data: any[] | null; error: any }> {
      if (USE_SUPABASE) {
        try {
          const today = new Date().toISOString().split("T")[0];

          const { data, error } = await supabase
            .from("hr_employee_documents")
            .select(
              `
							*,
							employee:employee_id (
								id,
								employee_id,
								name
							)
						`,
            )
            .eq("is_active", true)
            .not("expiry_date", "is", null)
            .lt("expiry_date", today)
            .order("expiry_date", { ascending: false });

          return { data, error };
        } catch (error) {
          console.error("Failed to fetch expired documents:", error);
          return { data: null, error: error.message };
        }
      } else {
        await delay(MOCK_DATA_DELAY);
        return { data: [], error: null };
      }
    },
  },
};

// offlineDataManager removed - using localStorage caching instead
// Initialize offline support using localStorage
if (typeof window !== "undefined") {
  // Periodically sync data to localStorage cache
  setInterval(() => {
    if (navigator.onLine) {
      offline.syncOfflineData();
    }
  }, 60000); // Sync every minute
}
