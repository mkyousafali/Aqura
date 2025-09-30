// Debug script to check authentication state
console.log('=== Authentication Debug ===');

// Check if we're in browser
if (typeof window !== 'undefined') {
    console.log('Running in browser environment');
    
    // Check localStorage for auth data
    const token = localStorage.getItem('aqura-auth-token');
    const userStr = localStorage.getItem('aqura-user');
    const sessionStr = localStorage.getItem('aqura-session');
    
    console.log('Auth token exists:', !!token);
    console.log('User data exists:', !!userStr);
    console.log('Session data exists:', !!sessionStr);
    
    if (token) {
        console.log('Token (first 20 chars):', token.substring(0, 20) + '...');
    }
    
    if (userStr) {
        try {
            const user = JSON.parse(userStr);
            console.log('User data:', {
                id: user.id,
                username: user.username,
                role: user.role,
                roleType: user.roleType
            });
        } catch (error) {
            console.error('Error parsing user data:', error);
        }
    }
    
    if (sessionStr) {
        try {
            const session = JSON.parse(sessionStr);
            console.log('Session data:', session);
        } catch (error) {
            console.error('Error parsing session data:', error);
        }
    }
} else {
    console.log('Not running in browser environment');
}