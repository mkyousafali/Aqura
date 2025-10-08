// In-App Notification Sound System
// Works even when app is minimized/background but user is logged in
// Separate from push notifications - for real-time in-app notifications

import { get } from 'svelte/store';
import { currentUser } from '$lib/utils/persistentAuth';

interface NotificationSoundConfig {
    enabled: boolean;
    volume: number;
    soundFile: string;
    repeatCount: number;
    respectSystemSettings: boolean;
}

interface InAppNotification {
    id: string;
    title: string;
    message: string;
    type: 'info' | 'success' | 'warning' | 'error';
    priority: 'low' | 'medium' | 'high';
    timestamp: Date;
    read: boolean;
    soundEnabled?: boolean;
}

class InAppNotificationSoundManager {
    private audio: HTMLAudioElement | null = null;
    private config: NotificationSoundConfig;
    private isEnabled: boolean = true;
    private wakeLock: any = null; // For keeping app active in background

    constructor() {
        this.config = {
            enabled: true,
            volume: 0.7,
            soundFile: '/sounds/notification.mp3', // Use MP3 file
            repeatCount: 1,
            respectSystemSettings: true
        };

        // Only initialize in browser environment
        if (typeof window !== 'undefined') {
            this.initializeAudio();
            this.loadUserPreferences();
            this.setupVisibilityHandling();
            this.requestWakeLock();
        }
    }

    private initializeAudio(): void {
        try {
            this.audio = new Audio();
            this.audio.preload = 'auto';
            this.audio.volume = this.config.volume;
            
            // Load the MP3 notification sound
            this.audio.src = this.config.soundFile;
            this.audio.load();
            
            console.log('🔊 MP3 notification sound system initialized');
        } catch (error) {
            console.error('❌ Failed to initialize audio system:', error);
        }
    }

    private loadUserPreferences(): void {
        try {
            if (typeof localStorage !== 'undefined') {
                const savedConfig = localStorage.getItem('notificationSoundConfig');
                if (savedConfig) {
                    this.config = { ...this.config, ...JSON.parse(savedConfig) };
                    if (this.audio) {
                        this.audio.volume = this.config.volume;
                    }
                }
            }
        } catch (error) {
            console.error('❌ Failed to load sound preferences:', error);
        }
    }

    private saveUserPreferences(): void {
        try {
            if (typeof localStorage !== 'undefined') {
                localStorage.setItem('notificationSoundConfig', JSON.stringify(this.config));
            }
        } catch (error) {
            console.error('❌ Failed to save sound preferences:', error);
        }
    }

    private setupVisibilityHandling(): void {
        // Check if running in browser environment
        if (typeof document === 'undefined' || typeof window === 'undefined') {
            return;
        }

        // Handle page visibility changes
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'hidden') {
                console.log('📱 App moved to background - sound system remains active');
            } else {
                console.log('📱 App returned to foreground');
            }
        });

        // Handle window focus/blur
        window.addEventListener('blur', () => {
            console.log('🔊 Window lost focus - keeping sound system active');
        });

        window.addEventListener('focus', () => {
            console.log('🔊 Window gained focus');
        });
    }

    private async requestWakeLock(): Promise<void> {
        try {
            if (typeof navigator !== 'undefined' && 'wakeLock' in navigator) {
                this.wakeLock = await (navigator as any).wakeLock.request('screen');
                console.log('🔒 Wake lock acquired - app will stay active for notifications');
                
                this.wakeLock.addEventListener('release', () => {
                    console.log('🔓 Wake lock released');
                });
            }
        } catch (error) {
            console.log('⚠️ Wake lock not supported or failed:', error);
        }
    }

    private async checkSystemPermissions(): Promise<boolean> {
        // Check if system allows notification sounds
        if (typeof window !== 'undefined' && this.config.respectSystemSettings) {
            if ('Notification' in window) {
                const permission = await Notification.requestPermission();
                return permission === 'granted';
            }
        }
        return true;
    }

    private shouldPlaySound(notification: InAppNotification): boolean {
        // Check if sound should be played based on various conditions
        const user = get(currentUser);
        
        const result = (
            this.config.enabled &&
            this.isEnabled &&
            user && // User is logged in
            notification.soundEnabled !== false &&
            (notification.priority === 'high' || notification.priority === 'medium')
        );

        console.log('🔍 [SoundManager] shouldPlaySound check:', {
            notification: { id: notification.id, title: notification.title, priority: notification.priority },
            configEnabled: this.config.enabled,
            isEnabled: this.isEnabled,
            userLoggedIn: !!user,
            soundEnabled: notification.soundEnabled,
            priority: notification.priority,
            priorityAllowed: notification.priority === 'high' || notification.priority === 'medium',
            result
        });
        
        return result;
    }

    public async playNotificationSound(notification: InAppNotification): Promise<void> {
        console.log('🔊 [SoundManager] playNotificationSound called:', {
            notification: { id: notification.id, title: notification.title, type: notification.type, priority: notification.priority },
            audioElement: !!this.audio,
            audioSrc: this.audio?.src,
            config: this.config
        });

        if (!this.shouldPlaySound(notification)) {
            console.log('🔇 [SoundManager] Sound playback skipped - conditions not met');
            return;
        }

        try {
            // Check system permissions
            const hasPermission = await this.checkSystemPermissions();
            if (!hasPermission) {
                console.log('⚠️ [SoundManager] System notification permission denied');
                return;
            }

            // Play default notification sound
            if (this.audio) {
                console.log('🔊 [SoundManager] Attempting to play audio...', {
                    currentTime: this.audio.currentTime,
                    volume: this.audio.volume,
                    readyState: this.audio.readyState,
                    networkState: this.audio.networkState,
                    src: this.audio.src
                });

                // Reset audio to beginning
                this.audio.currentTime = 0;
                
                // Set volume based on config
                this.audio.volume = this.config.volume;
                
                // Play sound
                const playPromise = this.audio.play();
                
                if (playPromise !== undefined) {
                    await playPromise;
                    console.log(`🔊 [SoundManager] Successfully played notification sound for: ${notification.title}`);
                    
                    // Handle repeat if configured
                    if (this.config.repeatCount > 1) {
                        this.handleSoundRepeat(notification);
                    }
                } else {
                    console.warn('⚠️ [SoundManager] Play promise was undefined');
                }
            } else {
                console.log('⚠️ [SoundManager] Audio element not available');
            }
        } catch (error) {
            console.error('❌ [SoundManager] Failed to play notification sound:', error);
            
            // Fallback: try to play a system beep
            console.log('🔊 [SoundManager] Attempting fallback system beep...');
            this.playSystemBeep();
        }
    }

    private getVolumeForPriority(priority: string): number {
        switch (priority) {
            case 'high':
                return Math.min(this.config.volume * 1.2, 1.0);
            case 'medium':
                return this.config.volume;
            case 'low':
                return this.config.volume * 0.7;
            default:
                return this.config.volume;
        }
    }

    private handleSoundRepeat(notification: InAppNotification): void {
        if (notification.priority === 'high') {
            let repeatCount = 0;
            const repeatInterval = setInterval(() => {
                repeatCount++;
                if (repeatCount >= this.config.repeatCount || !this.shouldPlaySound(notification)) {
                    clearInterval(repeatInterval);
                    return;
                }
                
                // Play sound again
                if (this.audio) {
                    this.audio.currentTime = 0;
                    this.audio.play().catch(console.error);
                }
            }, 1500); // Repeat every 1.5 seconds
        }
    }

    private playSystemBeep(): void {
        try {
            // Create a short beep sound using Web Audio API as fallback
            const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();
            
            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);
            
            oscillator.frequency.setValueAtTime(800, audioContext.currentTime);
            oscillator.type = 'sine';
            
            gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.3);
            
            oscillator.start(audioContext.currentTime);
            oscillator.stop(audioContext.currentTime + 0.3);
            
            console.log('🔊 Played system beep as fallback');
        } catch (error) {
            console.error('❌ Failed to play system beep:', error);
        }
    }

    // Public API methods
    public enableSounds(): void {
        this.isEnabled = true;
        console.log('🔊 Notification sounds enabled');
    }

    public disableSounds(): void {
        this.isEnabled = false;
        console.log('🔇 Notification sounds disabled');
    }

    public setVolume(volume: number): void {
        this.config.volume = Math.max(0, Math.min(1, volume));
        if (this.audio) {
            this.audio.volume = this.config.volume;
        }
        this.saveUserPreferences();
        console.log(`🔊 Volume set to: ${Math.round(this.config.volume * 100)}%`);
    }

    public setSoundFile(soundFile: string): void {
        this.config.soundFile = soundFile;
        if (this.audio) {
            this.audio.src = soundFile;
            this.audio.load();
        }
        this.saveUserPreferences();
        console.log(`🔊 Sound file changed to: ${soundFile}`);
    }

    public testSound(): Promise<void> {
        const testNotification: InAppNotification = {
            id: 'test-' + Date.now(),
            title: 'Test Notification',
            message: 'This is a test notification sound',
            type: 'info',
            priority: 'medium',
            timestamp: new Date(),
            read: false,
            soundEnabled: true
        };
        
        return this.playNotificationSound(testNotification);
    }

    public getConfig(): NotificationSoundConfig {
        return { ...this.config };
    }

    public updateConfig(newConfig: Partial<NotificationSoundConfig>): void {
        this.config = { ...this.config, ...newConfig };
        // Update volume if audio is available
        if (this.audio && newConfig.volume !== undefined) {
            this.audio.volume = this.config.volume;
        }
        
        // Update sound file if specified
        if (this.audio && newConfig.soundFile) {
            this.audio.src = this.config.soundFile;
            this.audio.load();
        }
        
        this.saveUserPreferences();
        console.log('🔊 Notification sound config updated');
    }

    public cleanup(): void {
        if (this.wakeLock) {
            this.wakeLock.release();
        }
        
        if (this.audio) {
            this.audio.pause();
            this.audio = null;
        }
        
        console.log('🔊 Notification sound system cleaned up');
    }
}

// Singleton instance - only create in browser environment
export const notificationSoundManager = typeof window !== 'undefined' 
    ? new InAppNotificationSoundManager() 
    : null as any as InAppNotificationSoundManager;

// Make available globally for debugging
if (typeof window !== 'undefined' && notificationSoundManager) {
    (window as any).aquraSoundDebug = {
        manager: notificationSoundManager,
        testSound: () => notificationSoundManager.testSound(),
        playSystemBeep: () => notificationSoundManager['playSystemBeep'](),
        getConfig: () => notificationSoundManager.getConfig(),
        checkAudio: () => {
            const audio = (notificationSoundManager as any).audio;
            return {
                exists: !!audio,
                src: audio?.src,
                volume: audio?.volume,
                readyState: audio?.readyState,
                networkState: audio?.networkState,
                currentTime: audio?.currentTime,
                duration: audio?.duration
            };
        }
    };
    console.log('🔧 [SoundManager] Debug tools available: window.aquraSoundDebug');
}

// Export types for use in other components
export type { InAppNotification, NotificationSoundConfig };