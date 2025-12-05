<!-- Settings Component -->
<script lang="ts">
    import NotificationSoundControls from '$lib/components/common/NotificationSoundControls.svelte';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { currentLocale, t } from '$lib/i18n';
    // import { cacheManager } from '$lib/utils/cacheManager'; // Removed - cacheManager deleted
    
    // Get current user for context
    $: user = $currentUser;
    
    // Settings categories
    let activeCategory = 'notifications';
    
    const categories = [
        { id: 'notifications', label: 'Notifications', icon: '🔔' },
        { id: 'appearance', label: 'Appearance', icon: '🎨' },
        { id: 'privacy', label: 'Privacy', icon: '🔒' },
        { id: 'system', label: 'System', icon: '⚙️' }
    ];
    
    function selectCategory(categoryId: string) {
        activeCategory = categoryId;
    }
    
    // Cache management
    let isClearing = false;
    let clearMessage = '';
    
    async function clearAllCaches() {
        if (isClearing) return;
        
        isClearing = true;
        clearMessage = 'Clearing caches...';
        
        try {
            // TODO: Replace with localStorage.clear() or IndexedDB clearing
            // await cacheManager.clearAllCaches();
            localStorage.clear();
            clearMessage = '✅ Caches cleared successfully! App performance may improve.';
            
            // Clear the message after 3 seconds
            setTimeout(() => {
                clearMessage = '';
            }, 3000);
        } catch (error) {
            console.error('Cache clearing failed:', error);
            clearMessage = '❌ Cache clearing failed. Please try again.';
            
            // Clear error message after 3 seconds
            setTimeout(() => {
                clearMessage = '';
            }, 3000);
        } finally {
            isClearing = false;
        }
    }
</script>

<div class="settings-container">
    <!-- Settings Navigation -->
    <div class="settings-nav">
        <h2 class="settings-title">
            <span class="title-icon">⚙️</span>
            Settings
        </h2>
        
        <div class="category-list">
            {#each categories as category}
                <button 
                    class="category-item"
                    class:active={activeCategory === category.id}
                    on:click={() => selectCategory(category.id)}
                >
                    <span class="category-icon">{category.icon}</span>
                    <span class="category-label">{category.label}</span>
                </button>
            {/each}
        </div>
    </div>
    
    <!-- Settings Content -->
    <div class="settings-content">
        {#if activeCategory === 'notifications'}
            <div class="settings-section">
                <h3 class="section-title">Notification Settings</h3>
                <p class="section-description">
                    Configure how you receive and hear notifications when using the app.
                </p>
                
                <!-- Sound Controls -->
                <div class="settings-group">
                    <NotificationSoundControls />
                </div>
                
                <!-- Additional notification settings can go here -->
                <div class="settings-group">
                    <div class="setting-item">
                        <h4>Push Notifications</h4>
                        <p class="setting-description">
                            Browser push notifications are handled by your system and browser settings.
                            The sound controls above only affect in-app notification sounds.
                        </p>
                    </div>
                </div>
            </div>
            
        {:else if activeCategory === 'appearance'}
            <div class="settings-section">
                <h3 class="section-title">Appearance Settings</h3>
                <p class="section-description">
                    Customize the look and feel of the application.
                </p>
                
                <div class="settings-group">
                    <div class="setting-item">
                        <h4>Theme</h4>
                        <p class="setting-description">Coming soon - Dark/Light theme selection</p>
                    </div>
                </div>
                
                <div class="settings-group">
                    <div class="setting-item">
                        <h4>Language</h4>
                        <p class="setting-description">Current: {$currentLocale}</p>
                    </div>
                </div>
            </div>
            
        {:else if activeCategory === 'privacy'}
            <div class="settings-section">
                <h3 class="section-title">Privacy Settings</h3>
                <p class="section-description">
                    Manage your privacy and data settings.
                </p>
                
                <div class="settings-group">
                    <div class="setting-item">
                        <h4>Data Storage</h4>
                        <p class="setting-description">
                            Your data is stored securely and only accessible by authorized personnel.
                        </p>
                    </div>
                </div>
            </div>
            
        {:else if activeCategory === 'system'}
            <div class="settings-section">
                <h3 class="section-title">System Settings</h3>
                <p class="section-description">
                    System information and advanced settings.
                </p>
                
                <div class="settings-group">
                    <div class="setting-item">
                        <h4>User Information</h4>
                        {#if user}
                            <div class="user-info">
                                <p><strong>Username:</strong> {user.username}</p>
                                <p><strong>Role:</strong> {user.role}</p>
                                <p><strong>User Type:</strong> {user.userType}</p>
                            </div>
                        {:else}
                            <p class="setting-description">No user information available</p>
                        {/if}
                    </div>
                </div>
                
                <div class="settings-group">
                    <div class="setting-item">
                        <h4>Browser Information</h4>
                        <div class="browser-info">
                            <p><strong>User Agent:</strong> {navigator.userAgent.split(' ').slice(0, 3).join(' ')}...</p>
                            <p><strong>Language:</strong> {navigator.language}</p>
                            <p><strong>Online:</strong> {navigator.onLine ? 'Yes' : 'No'}</p>
                        </div>
                    </div>
                </div>
                
                <div class="settings-group">
                    <div class="setting-item">
                        <h4>Cache Management</h4>
                        <p class="setting-description">
                            Clear application caches to free up storage and resolve potential issues.
                            This will not affect your login session or settings.
                        </p>
                        
                        <div class="cache-controls">
                            <button 
                                class="clear-cache-btn"
                                class:clearing={isClearing}
                                disabled={isClearing}
                                on:click={clearAllCaches}
                            >
                                {#if isClearing}
                                    <span class="loading-spinner">⟳</span>
                                    Clearing...
                                {:else}
                                    🧹 Clear All Caches
                                {/if}
                            </button>
                            
                            {#if clearMessage}
                                <p class="clear-message" class:success={clearMessage.includes('✅')} class:error={clearMessage.includes('❌')}>
                                    {clearMessage}
                                </p>
                            {/if}
                        </div>
                    </div>
                </div>
            </div>
        {/if}
    </div>
</div>

<style>
    .settings-container {
        display: flex;
        height: 100%;
        background: #ffffff;
        overflow: hidden;
    }
    
    .settings-nav {
        width: 250px;
        background: #f8fafc;
        border-right: 1px solid #e2e8f0;
        padding: 20px 0;
        overflow-y: auto;
        flex-shrink: 0;
    }
    
    .settings-title {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 20px;
        font-weight: 600;
        color: #1a202c;
        margin: 0 0 24px 0;
        padding: 0 20px;
    }
    
    .title-icon {
        font-size: 24px;
    }
    
    .category-list {
        display: flex;
        flex-direction: column;
        gap: 2px;
        padding: 0 12px;
    }
    
    .category-item {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 12px 16px;
        background: none;
        border: none;
        border-radius: 8px;
        cursor: pointer;
        transition: all 0.2s ease;
        text-align: left;
        color: #4a5568;
    }
    
    .category-item:hover {
        background: #e2e8f0;
        color: #2d3748;
    }
    
    .category-item.active {
        background: #3182ce;
        color: white;
        font-weight: 500;
    }
    
    .category-icon {
        font-size: 18px;
        flex-shrink: 0;
    }
    
    .category-label {
        font-size: 14px;
    }
    
    .settings-content {
        flex: 1;
        padding: 20px;
        overflow-y: auto;
    }
    
    .settings-section {
        max-width: 800px;
    }
    
    .section-title {
        font-size: 24px;
        font-weight: 600;
        color: #1a202c;
        margin: 0 0 8px 0;
    }
    
    .section-description {
        color: #718096;
        margin: 0 0 32px 0;
        line-height: 1.5;
    }
    
    .settings-group {
        margin-bottom: 32px;
    }
    
    .setting-item {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        padding: 20px;
    }
    
    .setting-item h4 {
        font-size: 16px;
        font-weight: 600;
        color: #2d3748;
        margin: 0 0 8px 0;
    }
    
    .setting-description {
        color: #718096;
        margin: 0;
        line-height: 1.5;
        font-size: 14px;
    }
    
    .user-info, .browser-info {
        margin-top: 12px;
    }
    
    .user-info p, .browser-info p {
        margin: 4px 0;
        font-size: 14px;
        color: #4a5568;
    }
    
    .user-info strong, .browser-info strong {
        color: #2d3748;
    }
    
    /* Custom scrollbar for settings nav */
    .settings-nav::-webkit-scrollbar {
        width: 6px;
    }
    
    .settings-nav::-webkit-scrollbar-track {
        background: #f1f5f9;
    }
    
    .settings-nav::-webkit-scrollbar-thumb {
        background: #cbd5e0;
        border-radius: 3px;
    }
    
    .settings-nav::-webkit-scrollbar-thumb:hover {
        background: #a0aec0;
    }
    
    /* Custom scrollbar for settings content */
    .settings-content::-webkit-scrollbar {
        width: 6px;
    }
    
    .settings-content::-webkit-scrollbar-track {
        background: #f9fafb;
    }
    
    .settings-content::-webkit-scrollbar-thumb {
        background: #d1d5db;
        border-radius: 3px;
    }
    
    .settings-content::-webkit-scrollbar-thumb:hover {
        background: #9ca3af;
    }
    
    /* Cache management styles */
    .cache-controls {
        margin-top: 16px;
        display: flex;
        flex-direction: column;
        gap: 12px;
    }
    
    .clear-cache-btn {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 12px 20px;
        background: #e53e3e;
        color: white;
        border: none;
        border-radius: 6px;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.2s ease;
        font-size: 14px;
        max-width: 200px;
    }
    
    .clear-cache-btn:hover:not(:disabled) {
        background: #c53030;
        transform: translateY(-1px);
    }
    
    .clear-cache-btn:disabled {
        opacity: 0.6;
        cursor: not-allowed;
        transform: none;
    }
    
    .clear-cache-btn.clearing {
        background: #4299e1;
    }
    
    .loading-spinner {
        animation: spin 1s linear infinite;
        font-size: 16px;
    }
    
    @keyframes spin {
        from { transform: rotate(0deg); }
        to { transform: rotate(360deg); }
    }
    
    .clear-message {
        margin: 0;
        padding: 8px 12px;
        border-radius: 4px;
        font-size: 14px;
        font-weight: 500;
    }
    
    .clear-message.success {
        background: #c6f6d5;
        color: #22543d;
        border: 1px solid #9ae6b4;
    }
    
    .clear-message.error {
        background: #fed7d7;
        color: #742a2a;
        border: 1px solid #fc8181;
    }
</style>