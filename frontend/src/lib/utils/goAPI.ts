// Go Backend API Client
// This file provides functions to interact with the Go backend API

import { supabase } from './supabase';

// Get Go API URL from environment variables
const GO_API_URL = import.meta.env.VITE_GO_API_URL || 'http://localhost:8080';

// Toggle to use Go backend or Supabase
export const USE_GO_BACKEND = import.meta.env.VITE_USE_GO_BACKEND === 'true' || false;

// Client-side cache for faster subsequent loads
interface CacheEntry<T> {
  data: T;
  timestamp: number;
}

const cache = new Map<string, CacheEntry<any>>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes to match backend

function getCached<T>(key: string): T | null {
  const entry = cache.get(key);
  if (!entry) return null;
  
  // Check if expired
  if (Date.now() - entry.timestamp > CACHE_TTL) {
    cache.delete(key);
    return null;
  }
  
  return entry.data;
}

function setCache<T>(key: string, data: T): void {
  cache.set(key, { data, timestamp: Date.now() });
}

function invalidateCache(pattern: string): void {
  if (pattern === '*') {
    cache.clear();
  } else {
    // Remove all keys that start with pattern
    for (const key of cache.keys()) {
      if (key.startsWith(pattern)) {
        cache.delete(key);
      }
    }
  }
}

/**
 * Get authorization token from Supabase session
 */
async function getAuthToken(): Promise<string | null> {
  const { data: { session } } = await supabase.auth.getSession();
  return session?.access_token || null;
}

/**
 * Make authenticated API request to Go backend
 */
async function goFetch(endpoint: string, options: RequestInit = {}) {
  const token = await getAuthToken();
  
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  // Add auth token if available and method requires it
  if (token && ['POST', 'PUT', 'DELETE'].includes(options.method || 'GET')) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(`${GO_API_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: response.statusText }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }

  return response.json();
}

/**
 * Branch API operations using Go backend
 */
export const goAPI = {
  branches: {
    /**
     * Get all branches with client-side caching
     */
    async getAll(useCache = true) {
      const cacheKey = 'branches:all';
      
      // Try cache first
      if (useCache) {
        const cached = getCached(cacheKey);
        if (cached) {
          console.log('✅ Loaded branches from client cache');
          return { data: cached, error: null };
        }
      }
      
      try {
        const data = await goFetch('/api/branches');
        setCache(cacheKey, data);
        return { data, error: null };
      } catch (error: any) {
        return { data: null, error: { message: error.message } };
      }
    },

    /**
     * Get single branch by ID
     */
    async getById(id: string | number) {
      const cacheKey = `branches:${id}`;
      const cached = getCached(cacheKey);
      if (cached) return { data: cached, error: null };
      
      try {
        const data = await goFetch(`/api/branches/${id}`);
        setCache(cacheKey, data);
        return { data, error: null };
      } catch (error: any) {
        return { data: null, error: { message: error.message } };
      }
    },

    /**
     * Create new branch
     */
    async create(branch: any) {
      try {
        const data = await goFetch('/api/branches', {
          method: 'POST',
          body: JSON.stringify(branch),
        });
        // Invalidate cache after creation
        invalidateCache('branches');
        return { data, error: null };
      } catch (error: any) {
        return { data: null, error: { message: error.message } };
      }
    },

    /**
     * Update existing branch
     */
    async update(id: string | number, updates: any) {
      try {
        const data = await goFetch(`/api/branches/${id}`, {
          method: 'PUT',
          body: JSON.stringify(updates),
        });
        // Invalidate cache after update
        invalidateCache('branches');
        return { data, error: null };
      } catch (error: any) {
        return { data: null, error: { message: error.message } };
      }
    },

    /**
     * Delete branch (soft delete)
     */
    async delete(id: string | number) {
      try {
        const data = await goFetch(`/api/branches/${id}`, {
          method: 'DELETE',
        });
        // Invalidate cache after deletion
        invalidateCache('branches');
        return { data, error: null };
      } catch (error: any) {
        return { data: null, error: { message: error.message } };
      }
    },
  },

  /**
   * Health check endpoint
   */
  async healthCheck() {
    try {
      const data = await goFetch('/health');
      return { data, error: null };
    } catch (error: any) {
      return { data: null, error: { message: error.message } };
    }
  },
};
