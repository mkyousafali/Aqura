// Go Backend API Client
// This file provides functions to interact with the Go backend API

import { supabase } from './supabase';

// Get Go API URL from environment variables
const GO_API_URL = import.meta.env.VITE_GO_API_URL || 'http://localhost:8080';

// Toggle to use Go backend or Supabase
export const USE_GO_BACKEND = import.meta.env.VITE_USE_GO_BACKEND === 'true' || false;

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
     * Get all branches
     */
    async getAll() {
      try {
        const data = await goFetch('/api/branches');
        return { data, error: null };
      } catch (error: any) {
        return { data: null, error: { message: error.message } };
      }
    },

    /**
     * Get single branch by ID
     */
    async getById(id: string | number) {
      try {
        const data = await goFetch(`/api/branches/${id}`);
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
