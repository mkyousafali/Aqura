import { supabaseAdmin } from "./supabase";

/**
 * Push Subscription Cleanup Service
 * Manages cleanup of old push subscriptions to prevent table bloat
 * Keeps only the 1 most recent mobile and 1 most recent desktop subscription per user
 */
export class PushSubscriptionCleanupService {
  /**
   * Clean up old push subscriptions for a specific user
   * Keeps only the 1 most recent subscription per device type (mobile/desktop)
   */
  static async cleanupUserSubscriptions(userId: string): Promise<{
    success: boolean;
    deleted: number;
    error?: string;
  }> {
    try {
      console.log(
        `🧹 [Cleanup] Starting subscription cleanup for user: ${userId}`,
      );

      // Get all active subscriptions for the user, ordered by last_seen (most recent first)
      const { data: allSubscriptions, error: fetchError } = await supabaseAdmin
        .from("push_subscriptions")
        .select("id, device_type, last_seen, created_at, device_id, endpoint")
        .eq("user_id", userId)
        .eq("is_active", true)
        .order("last_seen", { ascending: false });

      if (fetchError) {
        console.error("❌ [Cleanup] Error fetching subscriptions:", fetchError);
        return { success: false, deleted: 0, error: fetchError.message };
      }

      if (!allSubscriptions || allSubscriptions.length === 0) {
        console.log("✅ [Cleanup] No active subscriptions found for user");
        return { success: true, deleted: 0 };
      }

      console.log(
        `📊 [Cleanup] Found ${allSubscriptions.length} active subscriptions`,
      );

      // Separate mobile and desktop subscriptions
      const mobileSubscriptions = allSubscriptions.filter(
        (sub) => sub.device_type === "mobile",
      );
      const desktopSubscriptions = allSubscriptions.filter(
        (sub) => sub.device_type === "desktop",
      );

      console.log(`📱 Mobile subscriptions: ${mobileSubscriptions.length}`);
      console.log(`💻 Desktop subscriptions: ${desktopSubscriptions.length}`);

      // Identify subscriptions to keep (1 most recent of each type)
      const mobileToKeep = mobileSubscriptions.slice(0, 1);
      const desktopToKeep = desktopSubscriptions.slice(0, 1);
      const subscriptionsToKeep = [...mobileToKeep, ...desktopToKeep];

      // Identify subscriptions to delete (everything else)
      const subscriptionsToDelete = allSubscriptions.filter(
        (sub) => !subscriptionsToKeep.some((keep) => keep.id === sub.id),
      );

      console.log(
        `🗑️ [Cleanup] Subscriptions to delete: ${subscriptionsToDelete.length}`,
      );

      if (subscriptionsToDelete.length === 0) {
        console.log(
          "✅ [Cleanup] No cleanup needed - subscription count within limits",
        );
        return { success: true, deleted: 0 };
      }

      // Log what we're keeping and deleting for transparency
      console.log("📋 [Cleanup] Keeping subscriptions:", {
        mobile: mobileToKeep.map((s) => ({
          id: s.id.substring(0, 8) + "...",
          device_id: s.device_id,
          last_seen: s.last_seen,
        })),
        desktop: desktopToKeep.map((s) => ({
          id: s.id.substring(0, 8) + "...",
          device_id: s.device_id,
          last_seen: s.last_seen,
        })),
      });

      console.log(
        "🗑️ [Cleanup] Deleting subscriptions:",
        subscriptionsToDelete.map((s) => ({
          id: s.id.substring(0, 8) + "...",
          device_type: s.device_type,
          device_id: s.device_id,
          last_seen: s.last_seen,
        })),
      );

      // Delete old subscriptions
      const subscriptionIds = subscriptionsToDelete.map((sub) => sub.id);

      const { error: deleteError } = await supabaseAdmin
        .from("push_subscriptions")
        .delete()
        .in("id", subscriptionIds);

      if (deleteError) {
        console.error(
          "❌ [Cleanup] Error deleting subscriptions:",
          deleteError,
        );
        return { success: false, deleted: 0, error: deleteError.message };
      }

      console.log(
        `✅ [Cleanup] Successfully deleted ${subscriptionsToDelete.length} old subscriptions`,
      );
      console.log(
        `📊 [Cleanup] Remaining subscriptions: ${subscriptionsToKeep.length} (${mobileToKeep.length} mobile, ${desktopToKeep.length} desktop)`,
      );

      return {
        success: true,
        deleted: subscriptionsToDelete.length,
      };
    } catch (error) {
      console.error("❌ [Cleanup] Unexpected error during cleanup:", error);
      return {
        success: false,
        deleted: 0,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }

  /**
   * Clean up old push subscriptions for all users
   * Should be run periodically as a maintenance task
   */
  static async cleanupAllUserSubscriptions(): Promise<{
    success: boolean;
    totalDeleted: number;
    usersProcessed: number;
    errors: string[];
  }> {
    try {
      console.log("🧹 [Global Cleanup] Starting global subscription cleanup");

      // Get all users who have active push subscriptions
      const { data: usersWithSubscriptions, error: usersError } =
        await supabaseAdmin
          .from("push_subscriptions")
          .select("user_id")
          .eq("is_active", true)
          .neq("user_id", null);

      if (usersError) {
        console.error("❌ [Global Cleanup] Error fetching users:", usersError);
        return {
          success: false,
          totalDeleted: 0,
          usersProcessed: 0,
          errors: [usersError.message],
        };
      }

      // Get unique user IDs with proper typing
      const uniqueUserIds = [
        ...new Set(
          usersWithSubscriptions
            ?.map((sub) => sub.user_id)
            .filter((id): id is string => id !== null) || [],
        ),
      ];
      console.log(
        `👥 [Global Cleanup] Found ${uniqueUserIds.length} users with active subscriptions`,
      );

      let totalDeleted = 0;
      let usersProcessed = 0;
      const errors: string[] = [];

      // Process each user
      for (const userId of uniqueUserIds) {
        try {
          const result = await this.cleanupUserSubscriptions(userId as string);
          if (result.success) {
            totalDeleted += result.deleted;
            usersProcessed++;

            if (result.deleted > 0) {
              console.log(
                `✅ [Global Cleanup] User ${userId}: deleted ${result.deleted} subscriptions`,
              );
            }
          } else {
            errors.push(`User ${userId}: ${result.error}`);
            console.error(
              `❌ [Global Cleanup] Failed for user ${userId}:`,
              result.error,
            );
          }
        } catch (error) {
          const errorMsg =
            error instanceof Error ? error.message : "Unknown error";
          errors.push(`User ${userId}: ${errorMsg}`);
          console.error(
            `❌ [Global Cleanup] Unexpected error for user ${userId}:`,
            error,
          );
        }

        // Add small delay to prevent overwhelming the database
        await new Promise((resolve) => setTimeout(resolve, 100));
      }

      console.log(
        `✅ [Global Cleanup] Completed: ${usersProcessed}/${uniqueUserIds.length} users processed, ${totalDeleted} total subscriptions deleted`,
      );

      if (errors.length > 0) {
        console.warn(
          `⚠️ [Global Cleanup] ${errors.length} errors occurred:`,
          errors,
        );
      }

      return {
        success: errors.length === 0,
        totalDeleted,
        usersProcessed,
        errors,
      };
    } catch (error) {
      console.error(
        "❌ [Global Cleanup] Unexpected error during global cleanup:",
        error,
      );
      return {
        success: false,
        totalDeleted: 0,
        usersProcessed: 0,
        errors: [error instanceof Error ? error.message : "Unknown error"],
      };
    }
  }

  /**
   * Clean up inactive subscriptions older than specified days
   */
  static async cleanupInactiveSubscriptions(daysOld: number = 30): Promise<{
    success: boolean;
    deleted: number;
    error?: string;
  }> {
    try {
      console.log(
        `🧹 [Inactive Cleanup] Cleaning up inactive subscriptions older than ${daysOld} days`,
      );

      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysOld);

      // Delete inactive subscriptions older than cutoff date
      const { data, error } = await supabaseAdmin
        .from("push_subscriptions")
        .delete()
        .eq("is_active", false)
        .lt("last_seen", cutoffDate.toISOString())
        .select("id");

      if (error) {
        console.error(
          "❌ [Inactive Cleanup] Error deleting inactive subscriptions:",
          error,
        );
        return { success: false, deleted: 0, error: error.message };
      }

      const deletedCount = data?.length || 0;
      console.log(
        `✅ [Inactive Cleanup] Deleted ${deletedCount} inactive subscriptions older than ${daysOld} days`,
      );

      return { success: true, deleted: deletedCount };
    } catch (error) {
      console.error("❌ [Inactive Cleanup] Unexpected error:", error);
      return {
        success: false,
        deleted: 0,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }

  /**
   * Get subscription statistics for monitoring
   */
  static async getSubscriptionStats(): Promise<{
    total: number;
    active: number;
    inactive: number;
    mobile: number;
    desktop: number;
    usersWithSubscriptions: number;
  }> {
    try {
      // Get total counts
      const [
        totalResult,
        activeResult,
        mobileResult,
        desktopResult,
        usersResult,
      ] = await Promise.all([
        supabaseAdmin
          .from("push_subscriptions")
          .select("id", { count: "exact", head: true }),
        supabaseAdmin
          .from("push_subscriptions")
          .select("id", { count: "exact", head: true })
          .eq("is_active", true),
        supabaseAdmin
          .from("push_subscriptions")
          .select("id", { count: "exact", head: true })
          .eq("device_type", "mobile")
          .eq("is_active", true),
        supabaseAdmin
          .from("push_subscriptions")
          .select("id", { count: "exact", head: true })
          .eq("device_type", "desktop")
          .eq("is_active", true),
        supabaseAdmin
          .from("push_subscriptions")
          .select("user_id")
          .eq("is_active", true),
      ]);

      const total = totalResult.count || 0;
      const active = activeResult.count || 0;
      const mobile = mobileResult.count || 0;
      const desktop = desktopResult.count || 0;
      const uniqueUsers = new Set(usersResult.data?.map((r) => r.user_id) || [])
        .size;

      return {
        total,
        active,
        inactive: total - active,
        mobile,
        desktop,
        usersWithSubscriptions: uniqueUsers,
      };
    } catch (error) {
      console.error("❌ [Stats] Error getting subscription stats:", error);
      return {
        total: 0,
        active: 0,
        inactive: 0,
        mobile: 0,
        desktop: 0,
        usersWithSubscriptions: 0,
      };
    }
  }
}

// Convenience export for common cleanup operation
export const cleanupUserPushSubscriptions =
  PushSubscriptionCleanupService.cleanupUserSubscriptions;
export const cleanupAllPushSubscriptions =
  PushSubscriptionCleanupService.cleanupAllUserSubscriptions;
export const cleanupInactivePushSubscriptions =
  PushSubscriptionCleanupService.cleanupInactiveSubscriptions;
export const getPushSubscriptionStats =
  PushSubscriptionCleanupService.getSubscriptionStats;
