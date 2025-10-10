import { PushSubscriptionCleanupService } from './pushSubscriptionCleanup';

/**
 * Admin utilities for manual database cleanup
 * These functions can be called from the browser console when needed
 */

/**
 * Run cleanup for all users - can be called from browser console
 * Usage: window.runGlobalCleanup()
 */
export async function runGlobalCleanup(): Promise<void> {
	console.log('🧹 Starting global push subscription cleanup...');
	
	try {
		const result = await PushSubscriptionCleanupService.cleanupAllUserSubscriptions();
		
		if (result.success) {
			console.log(`✅ Global cleanup completed successfully!`);
			console.log(`📊 Users processed: ${result.usersProcessed}`);
			console.log(`🗑️ Total subscriptions deleted: ${result.totalDeleted}`);
			
			if (result.errors && result.errors.length > 0) {
				console.warn('⚠️ Some errors occurred during cleanup:');
				result.errors.forEach(error => console.warn(`   ${error}`));
			}
		} else {
			console.error(`❌ Global cleanup failed`);
			if (result.errors && result.errors.length > 0) {
				result.errors.forEach(error => console.error(`   ${error}`));
			}
		}
	} catch (error) {
		console.error('❌ Global cleanup error:', error);
	}
}

/**
 * Run cleanup for inactive subscriptions - can be called from browser console
 * Usage: window.cleanupInactive(30) // 30 days
 */
export async function cleanupInactive(daysInactive: number = 30): Promise<void> {
	console.log(`🧹 Starting cleanup of subscriptions inactive for ${daysInactive} days...`);
	
	try {
		const result = await PushSubscriptionCleanupService.cleanupInactiveSubscriptions(daysInactive);
		
		if (result.success) {
			console.log(`✅ Inactive cleanup completed successfully!`);
			console.log(`🗑️ Deleted ${result.deleted} inactive subscriptions`);
		} else {
			console.error(`❌ Inactive cleanup failed: ${result.error}`);
		}
	} catch (error) {
		console.error('❌ Inactive cleanup error:', error);
	}
}

/**
 * Get subscription statistics - can be called from browser console
 * Usage: window.getCleanupStats()
 */
export async function getCleanupStats(): Promise<void> {
	console.log('📊 Fetching push subscription statistics...');
	
	try {
		const stats = await PushSubscriptionCleanupService.getSubscriptionStats();
		
		console.log('📋 Push Subscription Statistics:');
		console.log(`   Total subscriptions: ${stats.total}`);
		console.log(`   Active subscriptions: ${stats.active}`);
		console.log(`   Inactive subscriptions: ${stats.inactive}`);
		console.log(`   Active mobile subscriptions: ${stats.mobile}`);
		console.log(`   Active desktop subscriptions: ${stats.desktop}`);
		console.log(`   Users with subscriptions: ${stats.usersWithSubscriptions}`);
		
		if (stats.usersWithSubscriptions > 0) {
			const avgPerUser = stats.active / stats.usersWithSubscriptions;
			console.log(`   Average active subscriptions per user: ${avgPerUser.toFixed(2)}`);
		}
		
	} catch (error) {
		console.error('❌ Error fetching stats:', error);
	}
}

/**
 * Initialize admin functions on window object for console access
 * Call this in development to add admin utilities to window
 */
export function initAdminCleanupConsole(): void {
	if (typeof window !== 'undefined') {
		// Make functions available globally for console access
		(window as any).runGlobalCleanup = runGlobalCleanup;
		(window as any).cleanupInactive = cleanupInactive;
		(window as any).getCleanupStats = getCleanupStats;
		
		console.log('🔧 Admin cleanup utilities loaded:');
		console.log('   - window.runGlobalCleanup() - Clean up all users');
		console.log('   - window.cleanupInactive(days) - Clean up inactive subscriptions');
		console.log('   - window.getCleanupStats() - Show subscription statistics');
	}
}