// Go Backend API Client
// This file provides functions to interact with the Go backend API

import { supabase } from './supabase';

// Get Go API URL from environment variables
const GO_API_URL = import.meta.env.VITE_GO_API_URL || 'http://localhost:8080';

// Toggle to use Go backend or Supabase
export const USE_GO_BACKEND = import.meta.env.VITE_USE_GO_BACKEND === 'true' || false;

// Backend health tracking
let backendHealthy = true;
let lastHealthCheck = 0;
const HEALTH_CHECK_INTERVAL = 30 * 1000; // 30 seconds

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
 * Check backend health and update status
 */
async function checkBackendHealth(): Promise<boolean> {
  const now = Date.now();
  
  // Only check every 30 seconds to avoid spam
  if (now - lastHealthCheck < HEALTH_CHECK_INTERVAL) {
    return backendHealthy;
  }
  
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000); // 5s timeout
    
    const response = await fetch(`${GO_API_URL}/health`, {
      signal: controller.signal,
    });
    
    clearTimeout(timeoutId);
    backendHealthy = response.ok;
    lastHealthCheck = now;
    
    if (!backendHealthy) {
      console.warn('⚠️ Go backend health check failed, using Supabase fallback');
    }
    
    return backendHealthy;
  } catch (error) {
    backendHealthy = false;
    lastHealthCheck = now;
    console.warn('⚠️ Go backend unreachable, using Supabase fallback');
    return false;
  }
}

/**
 * Fallback to Supabase for branches
 */
async function fetchBranchesFromSupabase() {
  const { data, error } = await supabase
    .from('branches')
    .select('*')
    .eq('is_active', true)
    .order('id', { ascending: true });
  
  if (error) throw error;
  return data;
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
 * Branch API operations using Go backend with Supabase fallback
 */
export const goAPI = {
  branches: {
    /**
     * Get all branches with client-side caching and fallback
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
      
      // Check backend health first
      const isHealthy = await checkBackendHealth();
      
      try {
        if (isHealthy && USE_GO_BACKEND) {
          // Try Go backend first
          const data = await goFetch('/api/branches');
          setCache(cacheKey, data);
          console.log('✅ Loaded branches from Go backend');
          return { data, error: null };
        } else {
          // Use Supabase fallback
          const data = await fetchBranchesFromSupabase();
          setCache(cacheKey, data);
          console.log('✅ Loaded branches from Supabase (fallback)');
          return { data, error: null };
        }
      } catch (error: any) {
        // If Go backend fails, try Supabase fallback
        console.warn('⚠️ Go backend failed, trying Supabase fallback:', error.message);
        try {
          const data = await fetchBranchesFromSupabase();
          setCache(cacheKey, data);
          backendHealthy = false; // Mark backend as unhealthy
          console.log('✅ Loaded branches from Supabase (fallback after error)');
          return { data, error: null };
        } catch (fallbackError: any) {
          console.error('❌ Both Go backend and Supabase failed:', fallbackError);
          return { data: null, error: { message: fallbackError.message } };
        }
      }
    },

    /**
     * Get single branch by ID with fallback
     */
    async getById(id: string | number) {
      const cacheKey = `branches:${id}`;
      const cached = getCached(cacheKey);
      if (cached) return { data: cached, error: null };
      
      const isHealthy = await checkBackendHealth();
      
      try {
        if (isHealthy && USE_GO_BACKEND) {
          const data = await goFetch(`/api/branches/${id}`);
          setCache(cacheKey, data);
          return { data, error: null };
        } else {
          // Supabase fallback
          const { data, error } = await supabase
            .from('branches')
            .select('*')
            .eq('id', id)
            .single();
          if (error) throw error;
          setCache(cacheKey, data);
          return { data, error: null };
        }
      } catch (error: any) {
        // Try Supabase fallback
        try {
          const { data, error: fbError } = await supabase
            .from('branches')
            .select('*')
            .eq('id', id)
            .single();
          if (fbError) throw fbError;
          setCache(cacheKey, data);
          backendHealthy = false;
          return { data, error: null };
        } catch (fallbackError: any) {
          return { data: null, error: { message: fallbackError.message } };
        }
      }
    },

    /**
     * Create new branch with fallback
     */
    async create(branch: any) {
      const isHealthy = await checkBackendHealth();
      
      try {
        if (isHealthy && USE_GO_BACKEND) {
          const data = await goFetch('/api/branches', {
            method: 'POST',
            body: JSON.stringify(branch),
          });
          invalidateCache('branches');
          return { data, error: null };
        } else {
          // Supabase fallback
          const { data, error } = await supabase
            .from('branches')
            .insert([branch])
            .select()
            .single();
          if (error) throw error;
          invalidateCache('branches');
          return { data, error: null };
        }
      } catch (error: any) {
        // Try Supabase fallback
        try {
          const { data, error: fbError } = await supabase
            .from('branches')
            .insert([branch])
            .select()
            .single();
          if (fbError) throw fbError;
          invalidateCache('branches');
          backendHealthy = false;
          return { data, error: null };
        } catch (fallbackError: any) {
          return { data: null, error: { message: fallbackError.message } };
        }
      }
    },

    /**
     * Update existing branch with fallback
     */
    async update(id: string | number, updates: any) {
      const isHealthy = await checkBackendHealth();
      
      try {
        if (isHealthy && USE_GO_BACKEND) {
          const data = await goFetch(`/api/branches/${id}`, {
            method: 'PUT',
            body: JSON.stringify(updates),
          });
          invalidateCache('branches');
          return { data, error: null };
        } else {
          // Supabase fallback
          const { data, error } = await supabase
            .from('branches')
            .update(updates)
            .eq('id', id)
            .select()
            .single();
          if (error) throw error;
          invalidateCache('branches');
          return { data, error: null };
        }
      } catch (error: any) {
        // Try Supabase fallback
        try {
          const { data, error: fbError } = await supabase
            .from('branches')
            .update(updates)
            .eq('id', id)
            .select()
            .single();
          if (fbError) throw fbError;
          invalidateCache('branches');
          backendHealthy = false;
          return { data, error: null };
        } catch (fallbackError: any) {
          return { data: null, error: { message: fallbackError.message } };
        }
      }
    },

    /**
     * Delete branch (soft delete) with fallback
     */
    async delete(id: string | number) {
      const isHealthy = await checkBackendHealth();
      
      try {
        if (isHealthy && USE_GO_BACKEND) {
          const data = await goFetch(`/api/branches/${id}`, {
            method: 'DELETE',
          });
          invalidateCache('branches');
          return { data, error: null };
        } else {
          // Supabase fallback (soft delete)
          const { data, error } = await supabase
            .from('branches')
            .update({ is_active: false })
            .eq('id', id)
            .select()
            .single();
          if (error) throw error;
          invalidateCache('branches');
          return { data, error: null };
        }
      } catch (error: any) {
        // Try Supabase fallback
        try {
          const { data, error: fbError } = await supabase
            .from('branches')
            .update({ is_active: false })
            .eq('id', id)
            .select()
            .single();
          if (fbError) throw fbError;
          invalidateCache('branches');
          backendHealthy = false;
          return { data, error: null };
        } catch (fallbackError: any) {
          return { data: null, error: { message: fallbackError.message } };
        }
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
