// In-App Notification Sound System
// Works even when app is minimized/background but user is logged in
// Separate from push notifications - for real-time in-app notifications

import { get } from "svelte/store";
import { currentUser } from "$lib/utils/persistentAuth";

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
  type: "info" | "success" | "warning" | "error";
  priority: "low" | "medium" | "high";
  timestamp: Date;
  read: boolean;
  soundEnabled?: boolean;
}

class InAppNotificationSoundManager {
  private audio: HTMLAudioElement | null = null;
  private config: NotificationSoundConfig;
  private isEnabled: boolean = true;
  private wakeLock: any = null; // For keeping app active in background
  private audioUnlocked: boolean = false; // Track if audio is unlocked for mobile
  private isMobileDevice: boolean = false;

  constructor() {
    // Detect mobile device
    this.isMobileDevice = this.detectMobileDevice();

    this.config = {
      enabled: true,
      volume: 0.7,
      soundFile: "/sounds/notification.mp3", // Use MP3 file
      repeatCount: 1,
      respectSystemSettings: true,
    };

    // Only initialize in browser environment
    if (typeof window !== "undefined") {
      this.initializeAudio();
      this.loadUserPreferences();
      this.setupVisibilityHandling();
      this.requestWakeLock();
      this.setupMobileAudioUnlock();
    }
  }

  private initializeAudio(): void {
    try {
      this.audio = new Audio();
      this.audio.preload = "auto";
      this.audio.volume = this.config.volume;

      // Load the MP3 notification sound
      this.audio.src = this.config.soundFile;
      this.audio.load();

      console.log("🔊 MP3 notification sound system initialized");
    } catch (error) {
      console.error("❌ Failed to initialize audio system:", error);
    }
  }

  private loadUserPreferences(): void {
    try {
      if (typeof localStorage !== "undefined") {
        const savedConfig = localStorage.getItem("notificationSoundConfig");
        if (savedConfig) {
          this.config = { ...this.config, ...JSON.parse(savedConfig) };
          if (this.audio) {
            this.audio.volume = this.config.volume;
          }
        }
      }
    } catch (error) {
      console.error("❌ Failed to load sound preferences:", error);
    }
  }

  private saveUserPreferences(): void {
    try {
      if (typeof localStorage !== "undefined") {
        localStorage.setItem(
          "notificationSoundConfig",
          JSON.stringify(this.config),
        );
      }
    } catch (error) {
      console.error("❌ Failed to save sound preferences:", error);
    }
  }

  private setupVisibilityHandling(): void {
    // Check if running in browser environment
    if (typeof document === "undefined" || typeof window === "undefined") {
      return;
    }

    // Handle page visibility changes
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "hidden") {
        console.log("📱 App moved to background - sound system remains active");
      } else {
        console.log("📱 App returned to foreground");
      }
    });

    // Handle window focus/blur
    window.addEventListener("blur", () => {
      console.log("🔊 Window lost focus - keeping sound system active");
    });

    window.addEventListener("focus", () => {
      console.log("🔊 Window gained focus");
    });
  }

  private async requestWakeLock(): Promise<void> {
    try {
      if (typeof navigator !== "undefined" && "wakeLock" in navigator) {
        this.wakeLock = await (navigator as any).wakeLock.request("screen");
        console.log(
          "🔒 Wake lock acquired - app will stay active for notifications",
        );

        this.wakeLock.addEventListener("release", () => {
          console.log("🔓 Wake lock released");
        });
      }
    } catch (error) {
      console.log("⚠️ Wake lock not supported or failed:", error);
    }
  }

  private detectMobileDevice(): boolean {
    if (typeof window === "undefined") return false;

    // Check for mobile/tablet devices
    const userAgent =
      navigator.userAgent || navigator.vendor || (window as any).opera;
    const mobileRegex =
      /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i;
    const isMobile = mobileRegex.test(userAgent);

    // Also check for touch device
    const hasTouch = "ontouchstart" in window || navigator.maxTouchPoints > 0;

    // Check for mobile interface route - THIS IS KEY FOR DESKTOP MOBILE INTERFACE
    const isMobileRoute = window.location.pathname.startsWith("/mobile-interface");

    // IMPORTANT: Treat mobile interface as mobile even on desktop
    // This ensures sound system works properly for mobile interface users on desktop
    const result = isMobile || hasTouch || isMobileRoute;

    console.log("📱 [SoundManager] Mobile device detection:", {
      userAgent: userAgent.substring(0, 50) + "...",
      mobileRegex: isMobile,
      hasTouch,
      isMobileRoute,
      result,
      note: isMobileRoute
        ? "Mobile interface detected - treating as mobile for sound system"
        : "Not mobile interface",
    });

    return result;
  }

  private setupMobileAudioUnlock(): void {
    const isMobileInterface =
      typeof window !== "undefined" &&
      window.location.pathname.startsWith("/mobile-interface");

    if (!this.isMobileDevice && !isMobileInterface) {
      console.log(
        "🔊 [SoundManager] Desktop interface detected - no audio unlock needed",
      );
      this.audioUnlocked = true;
      return;
    }

    console.log(
      "📱 [SoundManager] Mobile interface detected - setting up audio unlock",
      {
        actualDevice: this.isMobileDevice ? "mobile" : "desktop",
        interface: isMobileInterface ? "mobile interface" : "desktop interface",
        reason: isMobileInterface
          ? "Mobile interface requires audio unlock even on desktop"
          : "Mobile device detected",
      },
    );

    // On mobile interface (regardless of device), audio needs user interaction to unlock
    const unlockAudio = async () => {
      if (this.audioUnlocked || !this.audio) return;

      try {
        // Try to play and immediately pause to unlock audio
        this.audio.muted = true;
        const playPromise = this.audio.play();
        if (playPromise !== undefined) {
          await playPromise;
          this.audio.pause();
          this.audio.currentTime = 0;
          this.audio.muted = false;
        }

        this.audioUnlocked = true;
        console.log(
          "🔓 [SoundManager] Mobile interface audio unlocked successfully",
        );

        // Remove the unlock prompt if it exists
        const prompt = document.getElementById("audio-unlock-prompt");
        if (prompt) {
          prompt.style.opacity = "0";
          setTimeout(() => prompt.remove(), 300);
          console.log("📢 [SoundManager] Audio unlock prompt removed");
        }

        // Remove listeners once unlocked
        document.removeEventListener("touchstart", unlockAudio, {
          capture: true,
        });
        document.removeEventListener("touchend", unlockAudio, {
          capture: true,
        });
        document.removeEventListener("click", unlockAudio, { capture: true });
      } catch (error) {
        console.warn(
          "⚠️ [SoundManager] Failed to unlock mobile interface audio:",
          error,
        );
      }
    };

    // Add event listeners for user interaction (both touch and click for desktop support)
    document.addEventListener("touchstart", unlockAudio, {
      capture: true,
      once: false,
    });
    document.addEventListener("touchend", unlockAudio, {
      capture: true,
      once: false,
    });
    document.addEventListener("click", unlockAudio, {
      capture: true,
      once: false,
    });

    console.log(
      "📱 [SoundManager] Mobile interface audio unlock listeners added (touch + click)",
    );
  }

  private async checkSystemPermissions(): Promise<boolean> {
    // Check if system allows notification sounds
    if (typeof window !== "undefined" && this.config.respectSystemSettings) {
      if ("Notification" in window) {
        const permission = await Notification.requestPermission();
        return permission === "granted";
      }
    }
    return true;
  }

  private showAudioUnlockPrompt(): void {
    // Show a brief, non-intrusive prompt for user interaction
    if (
      typeof window !== "undefined" &&
      !window.document.getElementById("audio-unlock-prompt")
    ) {
      const prompt = window.document.createElement("div");
      prompt.id = "audio-unlock-prompt";
      prompt.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                background: #2563eb;
                color: white;
                padding: 12px 16px;
                border-radius: 8px;
                font-size: 14px;
                font-weight: 500;
                z-index: 9999;
                box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
                cursor: pointer;
                transition: all 0.3s ease;
                max-width: 300px;
                text-align: center;
            `;
      prompt.innerHTML = `
                🔊 Click anywhere to enable notification sounds
                <div style="font-size: 12px; margin-top: 4px; opacity: 0.9;">
                    Browser requires user interaction for audio
                </div>
            `;

      // Auto-remove after 8 seconds or on click
      const removePrompt = () => {
        if (prompt.parentNode) {
          prompt.style.opacity = "0";
          setTimeout(() => prompt.remove(), 300);
        }
      };

      prompt.addEventListener("click", removePrompt);
      setTimeout(removePrompt, 8000);

      // Add hover effect
      prompt.addEventListener("mouseenter", () => {
        prompt.style.transform = "scale(1.02)";
        prompt.style.boxShadow = "0 6px 16px rgba(37, 99, 235, 0.4)";
      });
      prompt.addEventListener("mouseleave", () => {
        prompt.style.transform = "scale(1)";
        prompt.style.boxShadow = "0 4px 12px rgba(37, 99, 235, 0.3)";
      });

      window.document.body.appendChild(prompt);

      console.log("📢 [SoundManager] Audio unlock prompt displayed");
    }
  }

  private shouldPlaySound(notification: InAppNotification): boolean {
    // Check if sound should be played based on various conditions
    const user = get(currentUser);

    // soundEnabled defaults to true if undefined (only false if explicitly set to false)
    const soundEnabledForNotification = notification.soundEnabled !== false;

    const result =
      this.config.enabled &&
      this.isEnabled &&
      user && // User is logged in
      soundEnabledForNotification &&
      (notification.priority === "high" || notification.priority === "medium");

    console.log("🔍 [SoundManager] shouldPlaySound check:", {
      notification: {
        id: notification.id,
        title: notification.title,
        priority: notification.priority,
      },
      configEnabled: this.config.enabled,
      isEnabled: this.isEnabled,
      userLoggedIn: !!user,
      soundEnabled: notification.soundEnabled,
      soundEnabledForNotification,
      priority: notification.priority,
      priorityAllowed:
        notification.priority === "high" || notification.priority === "medium",
      result,
    });

    return result;
  }

  public async playNotificationSound(
    notification: InAppNotification,
  ): Promise<void> {
    console.log("🔊 [SoundManager] playNotificationSound called:", {
      notification: {
        id: notification.id,
        title: notification.title,
        type: notification.type,
        priority: notification.priority,
      },
      audioElement: !!this.audio,
      audioSrc: this.audio?.src,
      config: this.config,
      isMobileDevice: this.isMobileDevice,
      audioUnlocked: this.audioUnlocked,
    });

    if (!this.shouldPlaySound(notification)) {
      console.log(
        "🔇 [SoundManager] Sound playback skipped - conditions not met",
      );
      return;
    }

    // On mobile, check if audio is unlocked
    if (this.isMobileDevice && !this.audioUnlocked) {
      console.warn(
        "📱 [SoundManager] Mobile audio not yet unlocked - user interaction needed",
      );
      // Still try to play, might work on some browsers
    }

    try {
      // Check system permissions
      const hasPermission = await this.checkSystemPermissions();
      if (!hasPermission) {
        console.log("⚠️ [SoundManager] System notification permission denied");
        return;
      }

      // Play default notification sound
      if (this.audio) {
        console.log("🔊 [SoundManager] Attempting to play audio...", {
          currentTime: this.audio.currentTime,
          volume: this.audio.volume,
          readyState: this.audio.readyState,
          networkState: this.audio.networkState,
          src: this.audio.src,
          muted: this.audio.muted,
          paused: this.audio.paused,
        });

        // For mobile interface, try to unlock audio if not already unlocked
        const isMobileInterface =
          typeof window !== "undefined" &&
          window.location.pathname.startsWith("/mobile-interface");
        if ((this.isMobileDevice || isMobileInterface) && !this.audioUnlocked) {
          console.log(
            "🔓 [SoundManager] Audio not unlocked, attempting unlock before playback...",
          );
          try {
            await this.unlockMobileAudio();
          } catch (unlockError) {
            console.warn(
              "⚠️ [SoundManager] Could not unlock audio, continuing with playback attempt...",
            );
          }
        }

        // Reset audio to beginning
        this.audio.currentTime = 0;

        // Set volume based on config and priority
        const priorityVolume = this.getVolumeForPriority(notification.priority);
        this.audio.volume = priorityVolume;

        // Ensure not muted
        this.audio.muted = false;

        // Play sound
        const playPromise = this.audio.play();

        if (playPromise !== undefined) {
          await playPromise;
          console.log(
            `✅ [SoundManager] Successfully played notification sound for: ${notification.title}`,
          );

          // Handle repeat if configured
          if (this.config.repeatCount > 1) {
            this.handleSoundRepeat(notification);
          }
        } else {
          console.warn("⚠️ [SoundManager] Play promise was undefined");
        }
      } else {
        console.log("⚠️ [SoundManager] Audio element not available");
      }
    } catch (error) {
      console.error(
        "❌ [SoundManager] Failed to play notification sound:",
        error,
      );

      // If it's a user interaction error, try to re-unlock audio automatically
      if (
        error.name === "NotAllowedError" &&
        error.message.includes("user didn't interact")
      ) {
        console.log(
          "🔓 [SoundManager] Auto-retry: Re-unlocking audio due to interaction requirement...",
        );
        this.audioUnlocked = false; // Reset the unlock flag

        // Show user-friendly prompt for interaction
        this.showAudioUnlockPrompt();

        // For mobile interface, we need to wait for next user interaction
        const isMobileInterface =
          typeof window !== "undefined" &&
          window.location.pathname.startsWith("/mobile-interface");
        if (isMobileInterface) {
          console.log(
            "📱 [SoundManager] Setting up re-unlock listeners for mobile interface...",
          );
          this.setupMobileAudioUnlock(); // Re-setup the unlock listeners
          console.log(
            "ℹ️ [SoundManager] Sound will work after next user interaction (click/touch)",
          );
        } else {
          // For desktop, try immediate unlock
          try {
            await this.unlockMobileAudio();
            // Retry playing the sound if unlock was successful
            if (this.audioUnlocked) {
              console.log(
                "🔄 [SoundManager] Retrying sound after auto-unlock...",
              );
              return this.playNotificationSound(notification);
            }
          } catch (unlockError) {
            console.error("❌ [SoundManager] Auto-unlock failed:", unlockError);
          }
        }
      }

      // Fallback: try to play a system beep
      console.log("🔊 [SoundManager] Attempting fallback system beep...");
      this.playSystemBeep();
    }
  }

  private getVolumeForPriority(priority: string): number {
    switch (priority) {
      case "high":
        return Math.min(this.config.volume * 1.2, 1.0);
      case "medium":
        return this.config.volume;
      case "low":
        return this.config.volume * 0.7;
      default:
        return this.config.volume;
    }
  }

  private handleSoundRepeat(notification: InAppNotification): void {
    if (notification.priority === "high") {
      let repeatCount = 0;
      const repeatInterval = setInterval(() => {
        repeatCount++;
        if (
          repeatCount >= this.config.repeatCount ||
          !this.shouldPlaySound(notification)
        ) {
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
      const audioContext = new (window.AudioContext ||
        (window as any).webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const gainNode = audioContext.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(audioContext.destination);

      oscillator.frequency.setValueAtTime(800, audioContext.currentTime);
      oscillator.type = "sine";

      gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(
        0.01,
        audioContext.currentTime + 0.3,
      );

      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.3);

      console.log("🔊 Played system beep as fallback");
    } catch (error) {
      console.error("❌ Failed to play system beep:", error);
    }
  }

  // Public API methods
  public enableSounds(): void {
    this.isEnabled = true;
    console.log("🔊 Notification sounds enabled");
  }

  public disableSounds(): void {
    this.isEnabled = false;
    console.log("🔇 Notification sounds disabled");
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
      id: "test-" + Date.now(),
      title: "Test Notification",
      message: "This is a test notification sound",
      type: "info",
      priority: "medium",
      timestamp: new Date(),
      read: false,
      soundEnabled: true,
    };

    // On mobile, try to unlock audio first
    if (this.isMobileDevice && !this.audioUnlocked) {
      console.log(
        "📱 [SoundManager] Test triggered - attempting to unlock mobile audio",
      );
      this.unlockMobileAudio();
    }

    return this.playNotificationSound(testNotification);
  }

  public async unlockMobileAudio(force: boolean = false): Promise<boolean> {
    // For mobile interface, always try to unlock regardless of device type
    const isMobileInterface =
      typeof window !== "undefined" &&
      window.location.pathname.startsWith("/mobile-interface");

    if ((!this.isMobileDevice && !isMobileInterface) || !this.audio) {
      console.log(
        "🔊 [SoundManager] Audio unlock not needed - not mobile interface or no audio element",
      );
      return this.audioUnlocked;
    }

    if (this.audioUnlocked && !force) {
      console.log("🔊 [SoundManager] Audio unlock not needed:", {
        isMobileDevice: this.isMobileDevice,
        isMobileInterface,
        audioUnlocked: this.audioUnlocked,
        hasAudio: !!this.audio,
        note: "Use force=true to override",
      });
      return this.audioUnlocked;
    }

    try {
      console.log("🔓 [SoundManager] Manually unlocking mobile audio...", {
        deviceType: this.isMobileDevice ? "mobile" : "desktop",
        interface: isMobileInterface ? "mobile interface" : "desktop interface",
        forced: force,
      });

      this.audio.muted = true;
      const playPromise = this.audio.play();
      if (playPromise !== undefined) {
        await playPromise;
        this.audio.pause();
        this.audio.currentTime = 0;
        this.audio.muted = false;
      }

      this.audioUnlocked = true;
      console.log(
        "✅ [SoundManager] Mobile audio manually unlocked for mobile interface",
      );
      return true;
    } catch (error) {
      console.error(
        "❌ [SoundManager] Failed to manually unlock mobile audio:",
        error,
      );
      return false;
    }
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
    console.log("🔊 Notification sound config updated");
  }

  public cleanup(): void {
    if (this.wakeLock) {
      this.wakeLock.release();
    }

    if (this.audio) {
      this.audio.pause();
      this.audio = null;
    }

    console.log("🔊 Notification sound system cleaned up");
  }
}

// Singleton instance - only create in browser environment
export const notificationSoundManager =
  typeof window !== "undefined"
    ? new InAppNotificationSoundManager()
    : (null as any as InAppNotificationSoundManager);

// Make available globally for debugging
if (typeof window !== "undefined" && notificationSoundManager) {
  (window as any).aquraSoundDebug = {
    manager: notificationSoundManager,
    testSound: () => notificationSoundManager.testSound(),
    playSystemBeep: () => notificationSoundManager["playSystemBeep"](),
    getConfig: () => notificationSoundManager.getConfig(),
    unlockMobileAudio: () => notificationSoundManager.unlockMobileAudio(),
    forceUnlock: () => notificationSoundManager.unlockMobileAudio(true),
    showPrompt: () => (notificationSoundManager as any).showAudioUnlockPrompt(),
    removePrompt: () => {
      const prompt = document.getElementById("audio-unlock-prompt");
      if (prompt) {
        prompt.style.opacity = "0";
        setTimeout(() => prompt.remove(), 300);
        console.log("📢 [SoundManager] Prompt manually removed");
      } else {
        console.log("📢 [SoundManager] No prompt to remove");
      }
    },
    isMobile: () => (notificationSoundManager as any).isMobileDevice,
    isMobileInterface: () => window.location.pathname.startsWith("/mobile-interface"),
    isAudioUnlocked: () => (notificationSoundManager as any).audioUnlocked,
    checkAudio: () => {
      const audio = (notificationSoundManager as any).audio;
      return {
        exists: !!audio,
        src: audio?.src,
        volume: audio?.volume,
        readyState: audio?.readyState,
        networkState: audio?.networkState,
        currentTime: audio?.currentTime,
        duration: audio?.duration,
        muted: audio?.muted,
        paused: audio?.paused,
      };
    },
  };
  console.log(
    "🔧 [SoundManager] Debug tools available: window.aquraSoundDebug",
  );
  console.log("📱 [SoundManager] Device detection:", {
    isMobileDevice: (notificationSoundManager as any).isMobileDevice,
    isMobileInterface: window.location.pathname.startsWith("/mobile-interface"),
    shouldUseMobileAudio:
      (notificationSoundManager as any).isMobileDevice ||
      window.location.pathname.startsWith("/mobile-interface"),
  });
}

// Export types for use in other components
export type { InAppNotification, NotificationSoundConfig };
