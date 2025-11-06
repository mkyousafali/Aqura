import { writable } from "svelte/store";
import {
  db,
  type Task,
  type TaskImage,
  type TaskAssignment,
  type TaskCompletion,
} from "$lib/utils/supabase";

interface TaskStore {
  tasks: Task[];
  loading: boolean;
  error: string | null;
  currentTask: Task | null;
  completions: TaskCompletion[];
  totalTasks: number;
  completedTasks: number;
  pendingTasks: number;
  inProgressTasks: number;
}

const initialState: TaskStore = {
  tasks: [],
  loading: false,
  error: null,
  currentTask: null,
  completions: [],
  totalTasks: 0,
  completedTasks: 0,
  pendingTasks: 0,
  inProgressTasks: 0,
};

function createTaskStore() {
  const { subscribe, set, update } = writable<TaskStore>(initialState);

  const updateTaskCounts = (tasks: Task[]) => {
    return {
      totalTasks: tasks.length,
      completedTasks: tasks.filter((task) => task.status === "completed")
        .length,
      pendingTasks: tasks.filter((task) => task.status === "draft").length, // draft is pending
      inProgressTasks: tasks.filter((task) => task.status === "active").length,
    };
  };

  return {
    subscribe,
    set,
    update,

    // Load all tasks
    async loadTasks(limit: number = 50, offset: number = 0, status?: string) {
      update((state) => ({ ...state, loading: true, error: null }));

      try {
        const {
          data: tasks,
          error,
          count,
        } = await db.tasks.getAll(limit, offset, status);

        if (error) {
          throw new Error(error.message);
        }

        const taskCounts = updateTaskCounts(tasks || []);

        update((state) => ({
          ...state,
          tasks: tasks || [],
          ...taskCounts,
          loading: false,
          error: null,
        }));

        return { success: true, data: tasks, total: count };
      } catch (error) {
        console.error("Failed to load tasks:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to load tasks";
        update((state) => ({
          ...state,
          loading: false,
          error: errorMessage,
        }));
        return { success: false, error: errorMessage };
      }
    },

    // Create new task
    async createTask(taskData: Omit<Task, "id" | "created_at" | "updated_at">) {
      console.log("🎯 [TaskStore] createTask called with data:", taskData);
      update((state) => ({ ...state, loading: true, error: null }));

      try {
        console.log("📤 [TaskStore] Calling db.tasks.create...");
        const { data: newTask, error } = await db.tasks.create(taskData);
        console.log("📥 [TaskStore] db.tasks.create result:", {
          data: newTask,
          error,
        });

        if (error) {
          console.error("❌ [TaskStore] Database error:", error);
          throw new Error(error.message);
        }

        console.log("✅ [TaskStore] Task created successfully:", newTask);
        update((state) => {
          const updatedTasks = [newTask!, ...state.tasks];
          const taskCounts = updateTaskCounts(updatedTasks);

          return {
            ...state,
            tasks: updatedTasks,
            ...taskCounts,
            loading: false,
            error: null,
          };
        });

        return { success: true, data: newTask };
      } catch (error) {
        console.error("❌ [TaskStore] Failed to create task:", error);
        console.error("❌ [TaskStore] Error details:", {
          message: error?.message,
          stack: error?.stack,
          name: error?.name,
          taskData: taskData,
        });
        const errorMessage =
          error instanceof Error ? error.message : "Failed to create task";
        update((state) => ({
          ...state,
          loading: false,
          error: errorMessage,
        }));
        return { success: false, error: errorMessage };
      }
    },

    // Update existing task
    async updateTask(taskId: string, taskData: Partial<Task>) {
      update((state) => ({ ...state, loading: true, error: null }));

      try {
        const { data: updatedTask, error } = await db.tasks.update(
          taskId,
          taskData,
        );

        if (error) {
          throw new Error(error.message);
        }

        update((state) => {
          const updatedTasks = state.tasks.map((task) =>
            task.id === taskId ? { ...task, ...updatedTask } : task,
          );
          const taskCounts = updateTaskCounts(updatedTasks);

          return {
            ...state,
            tasks: updatedTasks,
            ...taskCounts,
            loading: false,
            error: null,
          };
        });

        return { success: true, data: updatedTask };
      } catch (error) {
        console.error("Failed to update task:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to update task";
        update((state) => ({
          ...state,
          loading: false,
          error: errorMessage,
        }));
        return { success: false, error: errorMessage };
      }
    },

    // Delete an existing task (soft delete)
    async deleteTask(id: string, userId: string) {
      try {
        const { error } = await db.tasks.delete(id, userId);

        if (error) {
          throw new Error(error.message);
        }

        // Remove the deleted task from the store
        update((state) => {
          const updatedTasks = state.tasks.filter((task) => task.id !== id);
          const taskCounts = updateTaskCounts(updatedTasks);

          return {
            ...state,
            tasks: updatedTasks,
            ...taskCounts,
            currentTask:
              state.currentTask?.id === id ? null : state.currentTask,
            error: null,
          };
        });

        return { success: true, data: { id } };
      } catch (error) {
        console.error("Failed to delete task:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to delete task";
        update((state) => ({
          ...state,
          error: errorMessage,
        }));
        return { success: false, error: errorMessage };
      }
    },

    // Search tasks
    async searchTasks(
      query: string,
      userId?: string,
      limit: number = 50,
      offset: number = 0,
    ) {
      update((state) => ({ ...state, loading: true, error: null }));

      try {
        const { data: tasks, error } = await db.tasks.search(
          query,
          userId,
          limit,
          offset,
        );

        if (error) {
          throw new Error(error.message);
        }

        const taskCounts = updateTaskCounts(tasks || []);

        update((state) => ({
          ...state,
          tasks: tasks || [],
          ...taskCounts,
          loading: false,
          error: null,
        }));

        return { success: true, data: tasks };
      } catch (error) {
        console.error("Failed to search tasks:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to search tasks";
        update((state) => ({
          ...state,
          loading: false,
          error: errorMessage,
        }));
        return { success: false, error: errorMessage };
      }
    },

    // Get task statistics
    async getStatistics(userId?: string) {
      try {
        const { data: stats, error } = await db.tasks.getStatistics(userId);

        if (error) {
          throw new Error(error.message);
        }

        return { success: true, data: stats };
      } catch (error) {
        console.error("Failed to get task statistics:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to get statistics";
        return { success: false, error: errorMessage };
      }
    },

    // Task status operations
    async activateTask(taskId: string, userId: string) {
      return this.updateTask(taskId, { status: "active" });
    },

    async pauseTask(taskId: string, userId: string) {
      return this.updateTask(taskId, { status: "paused" });
    },

    async resumeTask(taskId: string, userId: string) {
      return this.updateTask(taskId, { status: "active" });
    },

    async completeTask(taskId: string, userId: string) {
      return this.updateTask(taskId, { status: "completed" });
    },

    // Assign tasks
    async assignTasks(
      taskIds: string[],
      assignmentType: "user" | "branch" | "all",
      assignedBy: string,
      assignedByName?: string,
      assignedToUserId?: string,
      assignedToBranchId?: string,
      scheduleSettings?: {
        schedule_date?: string;
        schedule_time?: string;
        deadline_date?: string;
        deadline_time?: string;
        notes?: string;
        priority_override?: string;
        is_recurring?: boolean;
        repeat_type?: string;
        repeat_interval?: number;
        repeat_days?: string[];
        repeat_end_type?: string;
        repeat_end_count?: number;
        repeat_end_date?: string;
      },
    ) {
      try {
        // If scheduling is enabled, use the scheduled assignment function
        if (
          scheduleSettings &&
          (scheduleSettings.schedule_date || scheduleSettings.deadline_date)
        ) {
          for (const taskId of taskIds) {
            const { error } =
              await db.taskAssignments.createScheduledAssignment(
                taskId,
                assignmentType,
                assignedBy,
                assignedToUserId,
                assignedToBranchId,
                assignedByName || "Unknown User",
                scheduleSettings.schedule_date,
                scheduleSettings.schedule_time,
                scheduleSettings.deadline_date,
                scheduleSettings.deadline_time,
              );

            if (error) {
              throw new Error(error.message);
            }
          }
        } else {
          // Use basic assignment for immediate assignments
          const { error } = await db.taskAssignments.assignTasks(
            taskIds,
            assignmentType,
            assignedBy,
            assignedByName,
            assignedToUserId,
            assignedToBranchId,
          );

          if (error) {
            throw new Error(error.message);
          }
        }

        return { success: true };
      } catch (error) {
        console.error("Failed to assign tasks:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to assign tasks";
        return { success: false, error: errorMessage };
      }
    },

    // Get task assignments
    async getTaskAssignments(taskId: string) {
      try {
        const { data: assignments, error } =
          await db.taskAssignments.getByTaskId(taskId);

        if (error) {
          throw new Error(error.message);
        }

        return { success: true, data: assignments };
      } catch (error) {
        console.error("Failed to get task assignments:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to get assignments";
        return { success: false, error: errorMessage };
      }
    },

    // Get task images
    async getTaskImages(taskId: string) {
      try {
        const { data: images, error } = await db.taskImages.getByTaskId(taskId);

        if (error) {
          throw new Error(error.message);
        }

        return { success: true, data: images };
      } catch (error) {
        console.error("Failed to get task images:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to get images";
        return { success: false, error: errorMessage };
      }
    },

    // Add task image
    async addTaskImage(
      taskId: string,
      image: Omit<TaskImage, "id" | "created_at" | "task_id">,
    ) {
      try {
        const { data: newImage, error } = await db.taskImages.create({
          ...image,
          task_id: taskId,
        });

        if (error) {
          throw new Error(error.message);
        }

        return { success: true, data: newImage };
      } catch (error) {
        console.error("Failed to add task image:", error);
        const errorMessage =
          error instanceof Error ? error.message : "Failed to add image";
        return { success: false, error: errorMessage };
      }
    },

    // Clear error
    clearError() {
      update((state) => ({ ...state, error: null }));
    },

    // Clear all tasks
    clearTasks() {
      set(initialState);
    },

    // Set current task
    setCurrentTask(task: Task | null) {
      update((state) => ({ ...state, currentTask: task }));
    },
  };
}

export const taskStore = createTaskStore();

// Export individual methods for convenience
export const loadTasks = taskStore.loadTasks.bind(taskStore);
export const createTask = taskStore.createTask.bind(taskStore);
export const updateTask = taskStore.updateTask.bind(taskStore);
export const deleteTask = taskStore.deleteTask.bind(taskStore);
export const searchTasks = taskStore.searchTasks.bind(taskStore);
export const getStatistics = taskStore.getStatistics.bind(taskStore);
export const activateTask = taskStore.activateTask.bind(taskStore);
export const pauseTask = taskStore.pauseTask.bind(taskStore);
export const resumeTask = taskStore.resumeTask.bind(taskStore);
export const completeTask = taskStore.completeTask.bind(taskStore);
export const assignTasks = taskStore.assignTasks.bind(taskStore);
export const getTaskAssignments = taskStore.getTaskAssignments.bind(taskStore);
export const getTaskImages = taskStore.getTaskImages.bind(taskStore);
export const addTaskImage = taskStore.addTaskImage.bind(taskStore);
export const clearError = taskStore.clearError.bind(taskStore);
export const clearTasks = taskStore.clearTasks.bind(taskStore);
export const setCurrentTask = taskStore.setCurrentTask.bind(taskStore);
