/**
 * Offline Data Manager for Aqura PWA
 * Handles local data storage, background sync, and offline operations
 */

// Extend ServiceWorkerRegistration to include sync
declare global {
	interface ServiceWorkerRegistration {
		sync?: {
			register(tag: string): Promise<void>;
		};
	}
}

interface PendingOperation {
	id: string;
	type: 'employees' | 'branches' | 'vendors' | 'users';
	method: 'POST' | 'PUT' | 'DELETE';
	data: any;
	timestamp: number;
}

interface CachedData {
	employees: any[];
	branches: any[];
	vendors: any[];
	users: any[];
	lastSync: number;
}

export class OfflineDataManager {
	private dbName = 'aqura-offline-db';
	private dbVersion = 1;
	private db: IDBDatabase | null = null;

	async init(): Promise<void> {
		return new Promise((resolve, reject) => {
			const request = indexedDB.open(this.dbName, this.dbVersion);

			request.onerror = () => reject(request.error);
			request.onsuccess = () => {
				this.db = request.result;
				resolve();
			};

			request.onupgradeneeded = (event) => {
				const db = (event.target as IDBOpenDBRequest).result;

				// Create object stores
				if (!db.objectStoreNames.contains('cachedData')) {
					db.createObjectStore('cachedData', { keyPath: 'type' });
				}

				if (!db.objectStoreNames.contains('pendingOperations')) {
					const store = db.createObjectStore('pendingOperations', { keyPath: 'id' });
					store.createIndex('type', 'type', { unique: false });
				}

				if (!db.objectStoreNames.contains('settings')) {
					db.createObjectStore('settings', { keyPath: 'key' });
				}
			};
		});
	}

	// Cache data locally
	async cacheData(type: keyof CachedData, data: any[]): Promise<void> {
		if (!this.db) await this.init();

		return new Promise((resolve, reject) => {
			const transaction = this.db!.transaction(['cachedData'], 'readwrite');
			const store = transaction.objectStore('cachedData');

			const request = store.put({
				type,
				data,
				lastUpdated: Date.now()
			});

			request.onsuccess = () => resolve();
			request.onerror = () => reject(request.error);
		});
	}

	// Get cached data
	async getCachedData(type: keyof CachedData): Promise<any[]> {
		if (!this.db) await this.init();

		return new Promise((resolve, reject) => {
			const transaction = this.db!.transaction(['cachedData'], 'readonly');
			const store = transaction.objectStore('cachedData');
			const request = store.get(type);

			request.onsuccess = () => {
				const result = request.result;
				resolve(result ? result.data : []);
			};
			request.onerror = () => reject(request.error);
		});
	}

	// Add pending operation for background sync
	async addPendingOperation(operation: Omit<PendingOperation, 'id' | 'timestamp'>): Promise<void> {
		if (!this.db) await this.init();

		const pendingOp: PendingOperation = {
			...operation,
			id: crypto.randomUUID(),
			timestamp: Date.now()
		};

		return new Promise((resolve, reject) => {
			const transaction = this.db!.transaction(['pendingOperations'], 'readwrite');
			const store = transaction.objectStore('pendingOperations');
			const request = store.add(pendingOp);

			request.onsuccess = () => {
				// Register background sync
				this.registerBackgroundSync(operation.type);
				resolve();
			};
			request.onerror = () => reject(request.error);
		});
	}

	// Get pending operations by type
	async getPendingOperations(type: string): Promise<PendingOperation[]> {
		if (!this.db) await this.init();

		return new Promise((resolve, reject) => {
			const transaction = this.db!.transaction(['pendingOperations'], 'readonly');
			const store = transaction.objectStore('pendingOperations');
			const index = store.index('type');
			const request = index.getAll(type);

			request.onsuccess = () => resolve(request.result);
			request.onerror = () => reject(request.error);
		});
	}

	// Remove pending operation
	async removePendingOperation(id: string): Promise<void> {
		if (!this.db) await this.init();

		return new Promise((resolve, reject) => {
			const transaction = this.db!.transaction(['pendingOperations'], 'readwrite');
			const store = transaction.objectStore('pendingOperations');
			const request = store.delete(id);

			request.onsuccess = () => resolve();
			request.onerror = () => reject(request.error);
		});
	}

	// Register background sync
	private async registerBackgroundSync(type: string): Promise<void> {
		if ('serviceWorker' in navigator && 'sync' in (window as any).ServiceWorkerRegistration.prototype) {
			try {
				const registration = await navigator.serviceWorker.ready;
				if (registration.sync) {
					await registration.sync.register(`background-sync-${type}`);
					console.log(`Background sync registered for ${type}`);
				}
			} catch (error) {
				console.error('Background sync registration failed:', error);
			}
		}
	}

	// Check if online
	isOnline(): boolean {
		return navigator.onLine;
	}

	// Attempt to sync specific data type
	async syncData(type: keyof CachedData): Promise<boolean> {
		if (!this.isOnline()) {
			console.log('Cannot sync - offline');
			return false;
		}

		try {
			const pendingOps = await this.getPendingOperations(type);
			
			for (const operation of pendingOps) {
				try {
					const response = await fetch(`/api/${type}`, {
						method: operation.method,
						headers: { 'Content-Type': 'application/json' },
						body: JSON.stringify(operation.data)
					});

					if (response.ok) {
						await this.removePendingOperation(operation.id);
						console.log(`Synced ${type} operation:`, operation.id);
					} else {
						console.error(`Failed to sync ${type} operation:`, response.statusText);
					}
				} catch (error) {
					console.error(`Error syncing ${type} operation:`, error);
					break; // Stop syncing on network error
				}
			}

			// Refresh cached data if sync was successful
			if (pendingOps.length === 0 || this.isOnline()) {
				await this.refreshCachedData(type);
			}

			return true;
		} catch (error) {
			console.error(`Sync failed for ${type}:`, error);
			return false;
		}
	}

	// Refresh cached data from server
	private async refreshCachedData(type: keyof CachedData): Promise<void> {
		try {
			const response = await fetch(`/api/${type}`);
			if (response.ok) {
				const data = await response.json();
				await this.cacheData(type, data);
			}
		} catch (error) {
			console.error(`Failed to refresh ${type} data:`, error);
		}
	}

	// Full sync all data types
	async syncAllData(): Promise<void> {
		const types: (keyof CachedData)[] = ['employees', 'branches', 'vendors', 'users'];
		
		for (const type of types) {
			await this.syncData(type);
		}
	}

	// Set up offline/online event listeners
	setupNetworkListeners(): void {
		window.addEventListener('online', () => {
			console.log('Connection restored - starting sync');
			this.syncAllData();
		});

		window.addEventListener('offline', () => {
			console.log('Connection lost - switching to offline mode');
		});
	}

	// Check if data needs refresh (older than 5 minutes)
	async needsRefresh(type: keyof CachedData): Promise<boolean> {
		if (!this.db) await this.init();

		return new Promise((resolve, reject) => {
			const transaction = this.db!.transaction(['cachedData'], 'readonly');
			const store = transaction.objectStore('cachedData');
			const request = store.get(type);

			request.onsuccess = () => {
				const result = request.result;
				if (!result) {
					resolve(true);
					return;
				}

				const fiveMinutes = 5 * 60 * 1000;
				const needsRefresh = (Date.now() - result.lastUpdated) > fiveMinutes;
				resolve(needsRefresh);
			};
			request.onerror = () => reject(request.error);
		});
	}

	// Get data with automatic caching and offline support
	async getData(type: keyof CachedData): Promise<any[]> {
		// Try to get fresh data if online
		if (this.isOnline()) {
			try {
				const needsRefresh = await this.needsRefresh(type);
				if (needsRefresh) {
					await this.refreshCachedData(type);
				}
			} catch (error) {
				console.warn(`Failed to refresh ${type}, using cached data:`, error);
			}
		}

		// Return cached data (works offline)
		return this.getCachedData(type);
	}
}

// Global instance
export const offlineDataManager = new OfflineDataManager();
