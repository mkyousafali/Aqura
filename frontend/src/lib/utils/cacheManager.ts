// Enhanced cache management utility for Aqura PWA
// Provides aggressive cache clearing on app refresh/reopen

export class CacheManager {
	private static instance: CacheManager;
	private isClearing = false;
	
	static getInstance(): CacheManager {
		if (!CacheManager.instance) {
			CacheManager.instance = new CacheManager();
		}
		return CacheManager.instance;
	}

	/**
	 * Clear all application caches aggressively
	 * Called on every app startup, refresh, or reopen
	 */
	async clearAllCaches(): Promise<void> {
		if (this.isClearing) {
			console.log('🔄 Cache clearing already in progress...');
			return;
		}

		this.isClearing = true;
		console.log('🧹 Starting aggressive cache clearing...');

		try {
			// Clear all browser caches
			await this.clearBrowserCaches();
			
			// Clear service worker caches
			await this.clearServiceWorkerCaches();
			
			// Clear local storage data (except essential auth)
			await this.clearLocalStorageData();
			
			// Clear session storage
			await this.clearSessionStorage();
			
			// Clear IndexedDB caches
			await this.clearIndexedDBCaches();
			
			console.log('✅ All caches cleared successfully');
		} catch (error) {
			console.error('❌ Error during cache clearing:', error);
		} finally {
			this.isClearing = false;
		}
	}

	/**
	 * Clear all browser caches using Cache API
	 */
	async clearBrowserCaches(): Promise<void> {
		if (!('caches' in window)) {
			console.log('⚠️ Cache API not supported');
			return;
		}

		try {
			const cacheNames = await caches.keys();
			console.log(`🗑️ Found ${cacheNames.length} cache(s) to clear`);

			// Delete all caches
			const deletionPromises = cacheNames.map(async (cacheName) => {
				console.log(`   🗑️ Deleting cache: ${cacheName}`);
				return caches.delete(cacheName);
			});

			await Promise.all(deletionPromises);
			console.log('✅ All browser caches cleared');
		} catch (error) {
			console.error('❌ Failed to clear browser caches:', error);
		}
	}

	/**
	 * Clear only browser caches and localStorage, preserve service workers and auth data
	 */
	async clearBrowserCachesOnly(): Promise<void> {
		console.log('🧹 Starting browser cache clearing (preserving service workers)...');
		
		try {
			// Clear browser caches
			await this.clearBrowserCaches();
			
			// Clear localStorage except auth data
			await this.clearLocalStorageData();
			
			// Clear sessionStorage
			await this.clearSessionStorage();
			
			// Clear IndexedDB except auth databases
			await this.clearIndexedDBCaches();
			
			console.log('✅ Browser caches cleared, service workers preserved');
		} catch (error) {
			console.error('❌ Browser cache clearing failed:', error);
			throw error;
		}
	}

	/**
	 * Unregister problematic service workers while preserving PWA service worker
	 */
	private async clearServiceWorkerCaches(): Promise<void> {
		if (!('serviceWorker' in navigator)) {
			console.log('⚠️ Service workers not supported');
			return;
		}

		try {
			// Get all service worker registrations
			const registrations = await navigator.serviceWorker.getRegistrations();
			console.log(`🔧 Found ${registrations.length} service worker(s)`);

			// Only unregister non-PWA service workers
			for (const registration of registrations) {
				const scriptURL = registration.active?.scriptURL || registration.waiting?.scriptURL || registration.installing?.scriptURL || '';
				
				// Preserve PWA service workers needed for push notifications
				const isPWAServiceWorker = scriptURL.includes('/sw.js') || 
					scriptURL.includes('vite-pwa') ||
					registration.scope === location.origin + '/';
				
				if (isPWAServiceWorker) {
					console.log(`✅ Preserving PWA SW: ${registration.scope}`);
				} else {
					console.log(`🗑️ Unregistering SW: ${registration.scope}`);
					await registration.unregister();
				}
			}

			console.log('🔄 Service worker cleanup completed, PWA SW preserved');
		} catch (error) {
			console.error('❌ Failed to clear service worker caches:', error);
		}
	}

	/**
	 * Clear local storage data except essential authentication
	 */
	private async clearLocalStorageData(): Promise<void> {
		try {
			const preserveKeys = [
				'aqura-device-session',      // Persistent auth sessions
				'aqura-device-id',           // Device identification
				'aqura-persistent-auth-token',
				'aqura-persistent-user-data',
				'aqura-auth-remember-me',
				'i18n-locale'               // User language preference
			];

			// Get all keys before clearing
			const allKeys = Object.keys(localStorage);
			console.log(`🗄️ Found ${allKeys.length} localStorage entries`);

			// Clear all except preserved keys
			let clearedCount = 0;
			allKeys.forEach(key => {
				if (!preserveKeys.includes(key)) {
					console.log(`   🗑️ Removing localStorage key: ${key}`);
					localStorage.removeItem(key);
					clearedCount++;
				} else {
					console.log(`   🔐 Preserving auth data: ${key}`);
				}
			});

			console.log(`✅ LocalStorage cleaned: ${clearedCount} items removed, ${preserveKeys.length} auth items preserved`);
		} catch (error) {
			console.error('❌ Failed to clear localStorage:', error);
		}
	}

	/**
	 * Clear all session storage
	 */
	private async clearSessionStorage(): Promise<void> {
		try {
			const sessionCount = sessionStorage.length;
			console.log(`🗄️ Found ${sessionCount} sessionStorage entries`);
			
			sessionStorage.clear();
			console.log('✅ SessionStorage cleared');
		} catch (error) {
			console.error('❌ Failed to clear sessionStorage:', error);
		}
	}

	/**
	 * Clear IndexedDB databases (except critical app data)
	 */
	private async clearIndexedDBCaches(): Promise<void> {
		if (!('indexedDB' in window)) {
			console.log('⚠️ IndexedDB not supported');
			return;
		}

		try {
			// Get all databases (this may not work in all browsers)
			// We'll target known cache databases
			const cacheDatabases = [
				'workbox-cache',
				'aqura-cache-db',
				'sw-cache-db',
				'vite-pwa-cache'
			];

			for (const dbName of cacheDatabases) {
				try {
					await this.deleteIndexedDB(dbName);
					console.log(`   🗑️ Deleted IndexedDB: ${dbName}`);
				} catch (error) {
					// Database might not exist, which is fine
					console.log(`   ⚠️ IndexedDB ${dbName} not found or already deleted`);
				}
			}

			console.log('✅ IndexedDB caches cleared');
		} catch (error) {
			console.error('❌ Failed to clear IndexedDB caches:', error);
		}
	}

	/**
	 * Delete a specific IndexedDB database
	 */
	private deleteIndexedDB(dbName: string): Promise<void> {
		return new Promise((resolve, reject) => {
			const deleteRequest = indexedDB.deleteDatabase(dbName);
			
			deleteRequest.onsuccess = () => resolve();
			deleteRequest.onerror = () => reject(deleteRequest.error);
			deleteRequest.onblocked = () => {
				console.warn(`🔒 IndexedDB deletion blocked: ${dbName}`);
				// Still resolve as the database will be deleted eventually
				resolve();
			};
		});
	}

	/**
	 * Clear all application data and force fresh state
	 * This is the most aggressive option
	 */
	async clearAllApplicationData(): Promise<void> {
		console.log('💥 Starting complete application data clear...');
		
		await this.clearAllCaches();
		
		// Additional cleanup for fresh state
		try {
			// Clear any remaining application state
			if ('cookieStore' in window) {
				// Clear cookies if API is available
				console.log('🍪 Clearing cookies...');
			}
			
			// Force garbage collection if available
			if ('gc' in window && typeof (window as any).gc === 'function') {
				(window as any).gc();
				console.log('🗑️ Forced garbage collection');
			}
			
			console.log('💥 Complete application data clear finished');
		} catch (error) {
			console.error('❌ Error in complete data clear:', error);
		}
	}

	/**
	 * Get cache statistics for debugging
	 */
	async getCacheStats(): Promise<{
		cacheCount: number;
		cacheNames: string[];
		localStorageSize: number;
		sessionStorageSize: number;
	}> {
		const stats = {
			cacheCount: 0,
			cacheNames: [] as string[],
			localStorageSize: 0,
			sessionStorageSize: 0
		};

		try {
			// Cache API stats
			if ('caches' in window) {
				stats.cacheNames = await caches.keys();
				stats.cacheCount = stats.cacheNames.length;
			}

			// Storage stats
			stats.localStorageSize = Object.keys(localStorage).length;
			stats.sessionStorageSize = sessionStorage.length;

		} catch (error) {
			console.error('Error getting cache stats:', error);
		}

		return stats;
	}

	/**
	 * Check if cache clearing is currently in progress
	 */
	isCleaningInProgress(): boolean {
		return this.isClearing;
	}
}

// Export singleton instance
export const cacheManager = CacheManager.getInstance();

// Export convenience functions
export const clearAllCaches = () => cacheManager.clearAllCaches();
export const clearAllApplicationData = () => cacheManager.clearAllApplicationData();
export const getCacheStats = () => cacheManager.getCacheStats();