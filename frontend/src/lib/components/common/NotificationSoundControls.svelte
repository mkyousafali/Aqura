<!-- Notification Sound Controls Component -->
<script lang="ts">
    import { notificationSoundManager } from '$lib/utils/inAppNotificationSounds';
    
    let soundConfig = notificationSoundManager.getConfig();
    let isEnabled = soundConfig.enabled;
    let volume = Math.round(soundConfig.volume * 100);
    
    // Update config when changes are made
    function updateSoundSettings() {
        notificationSoundManager.updateConfig({
            enabled: isEnabled,
            volume: volume / 100
        });
        soundConfig = notificationSoundManager.getConfig();
    }
    
    // Sound file options
    const soundOptions = [
        { value: '/sounds/notification.mp3', label: 'Default Bell' }
    ];
    
    function changeSoundFile(event: Event) {
        const target = event.target as HTMLSelectElement;
        notificationSoundManager.setSoundFile(target.value);
        soundConfig = notificationSoundManager.getConfig();
    }
</script>

<div class="sound-controls">
    <div class="sound-controls-header">
        <h4>🔊 Notification Sounds</h4>
    </div>
    
    <div class="sound-settings">
        <!-- Enable/Disable Sounds -->
        <div class="setting-row">
            <label>
                <input 
                    type="checkbox" 
                    bind:checked={isEnabled}
                    on:change={updateSoundSettings}
                />
                Enable notification sounds
            </label>
        </div>
        
        <!-- Volume Control -->
        <div class="setting-row">
            <label for="volume">Volume: {volume}%</label>
            <input 
                id="volume"
                type="range" 
                min="0" 
                max="100" 
                step="5"
                bind:value={volume}
                on:input={updateSoundSettings}
                disabled={!isEnabled}
            />
        </div>
        
        <!-- Sound Type Info -->
        <div class="setting-row">
            <label for="sound-select">Sound:</label>
            <select 
                id="sound-select"
                value={soundConfig.soundFile}
                on:change={changeSoundFile}
                disabled={!isEnabled}
            >
                {#each soundOptions as option}
                    <option value={option.value}>{option.label}</option>
                {/each}
            </select>
        </div>
        
        <!-- Status Info -->
        <div class="sound-status">
            <small>
                {#if isEnabled}
                    ✅ Sounds will play when app is open (even minimized)
                {:else}
                    🔇 Notification sounds are disabled
                {/if}
            </small>
        </div>
    </div>
</div>

<style>
    .sound-controls {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        padding: 16px;
        margin-bottom: 16px;
    }
    
    .sound-controls-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 16px;
    }
    
    .sound-controls-header h4 {
        margin: 0;
        color: #2d3748;
        font-size: 14px;
        font-weight: 600;
    }
    
    .sound-settings {
        display: flex;
        flex-direction: column;
        gap: 12px;
    }
    
    .setting-row {
        display: flex;
        flex-direction: column;
        gap: 4px;
    }
    
    .setting-row label {
        font-size: 13px;
        color: #4a5568;
        display: flex;
        align-items: center;
        gap: 8px;
    }
    
    .setting-row input[type="checkbox"] {
        margin-right: 4px;
    }
    
    .setting-row input[type="range"] {
        width: 100%;
        height: 4px;
        background: #cbd5e0;
        border-radius: 2px;
        outline: none;
        opacity: 0.7;
        transition: opacity 0.2s;
    }
    
    .setting-row input[type="range"]:hover {
        opacity: 1;
    }
    
    .setting-row input[type="range"]:disabled {
        opacity: 0.3;
        cursor: not-allowed;
    }
    
    .setting-row select {
        padding: 4px 8px;
        border: 1px solid #e2e8f0;
        border-radius: 4px;
        background: #ffffff;
        color: #4a5568;
        font-size: 12px;
    }
    
    .setting-row select:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }
    
    .sound-status {
        padding: 8px;
        background: #f7fafc;
        border-radius: 4px;
        text-align: center;
    }
    
    .sound-status small {
        color: #718096;
        font-size: 11px;
    }
</style>