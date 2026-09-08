import { writable, get } from 'svelte/store';

// User information store
export const userStore = writable({
  name: null,
  phone: null,
  email: null,
  customer_id: null,
  customer_name: null,
  registration_status: null,
  isAuthenticated: false
});

// User actions
export const userActions = {
  // Set user information after login
  setUser(userData) {
    userStore.set({
      name: userData.customer_name || userData.name,
      phone: userData.phone,
      email: userData.email,
      customer_id: userData.customer_id,
      customer_name: userData.customer_name,
      registration_status: userData.registration_status,
      isAuthenticated: true
    });
    
    // Save to localStorage for persistence
    localStorage.setItem('customer_session', JSON.stringify(userData));
  },

  // Update user name
  updateName(name) {
    userStore.update(user => ({
      ...user,
      name: name,
      customer_name: name
    }));
    
    // Update localStorage
    const saved = localStorage.getItem('customer_session');
    if (saved) {
      const data = JSON.parse(saved);
      data.customer_name = name;
      localStorage.setItem('customer_session', JSON.stringify(data));
    }
  },

  // Update user phone
  updatePhone(phone) {
    userStore.update(user => ({
      ...user,
      phone: phone
    }));
    
    // Update localStorage
    const saved = localStorage.getItem('customer_session');
    if (saved) {
      const data = JSON.parse(saved);
      data.phone = phone;
      localStorage.setItem('customer_session', JSON.stringify(data));
    }
  },

  // Load user from localStorage
  loadFromStorage() {
    try {
      const customerSession = localStorage.getItem('customer_session');
      if (customerSession) {
        const userData = JSON.parse(customerSession);
        if (userData.registration_status === 'approved') {
          this.setUser(userData);
          return true;
        }
      }
    } catch (error) {
      console.error('Failed to load user from storage:', error);
      this.logout();
    }
    return false;
  },

  // Logout user
  logout() {
    userStore.set({
      name: null,
      phone: null,
      email: null,
      customer_id: null,
      customer_name: null,
      registration_status: null,
      isAuthenticated: false
    });
    
    localStorage.removeItem('customer_session');
  },

  // Get display name (prioritize customer_name, fallback to name, then phone, then 'Guest')
  getDisplayName() {
    const user = get(userStore);
    return user.customer_name || user.name || user.phone || 'Guest';
  },

  // Get current user
  getCurrentUser() {
    return get(userStore);
  }
};

// Helper function to get current user state
export function getCurrentUser() {
  return get(userStore);
}