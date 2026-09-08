# Notification Sounds

This directory contains audio files for in-app notifications.

## Current Sound Files
- `notification.mp3` - Default notification bell sound (downloaded)

## Supported File Formats
- MP3 (.mp3) - Primary format, best browser compatibility
- WAV (.wav) - For high quality, uncompressed audio  
- OGG (.ogg) - For smaller file sizes

## Sound File Guidelines
- Keep files under 2MB for better performance
- Use mono or stereo audio
- Recommended duration: 1-3 seconds for notification sounds
- Sample rate: 44.1kHz or 48kHz

## Adding Custom MP3 Sounds
1. Place your MP3 files in this directory
2. Update the sound options in `NotificationSoundControls.svelte`
3. Ensure files are accessible via `/sounds/filename.mp3` URLs

## Testing Sounds
Use the "Test Sound" button in the Notification Center to verify your audio files work correctly.