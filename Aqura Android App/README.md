# Aqura Android App

Standalone Android WebView shell for Aqura. It loads the hosted staff mobile interface, so ordinary Svelte/UI deployments appear in the Android app without publishing a new APK or AAB.

## Production URL

The default is:

`https://aqura-frontend.vercel.app/mobile-interface`

This stable alias was confirmed against the linked Vercel project. If the production domain changes, either edit `aquraUrl` in `gradle.properties`, or build with:

```powershell
.\gradlew.bat bundleRelease -PaquraUrl=https://your-domain.example/mobile-interface
```

Only HTTPS is allowed. Navigation stays inside the app for the configured Aqura host; links to other hosts and custom schemes open in the appropriate external app.

## Open in Android Studio

1. Install Android Studio with Android SDK 35 and JDK 17.
2. Open this folder directly (not the main Aqura repository).
3. Let Gradle sync.
4. Run the `app` configuration on an Android 7.0+ device or emulator.

Debug command:

```powershell
.\gradlew.bat assembleDebug
```

Release bundle command:

```powershell
.\gradlew.bat bundleRelease -PaquraUrl=https://your-production-domain/mobile-interface
```

The release bundle will be at `app/build/outputs/bundle/release/app-release.aab`. A Play App Signing upload key must be configured in Android Studio or a private, uncommitted Gradle properties file before uploading.

## Included behavior

- Persistent cookies and DOM storage for Aqura sessions
- Android back-button navigation
- Loading and connection-error UI with retry
- File upload chooser
- Camera, microphone, and location permission bridging for trusted Aqura pages
- External links, downloads, phone links, maps, and other app schemes
- HTTPS-only traffic and trusted-host checks for sensitive WebView permissions
- Custom deep links in the form `aqura://open?path=/tasks`

## Push notifications

Native notifications use Firebase Cloud Messaging. The Android bridge requests permission, obtains the device token, and lets the authenticated Aqura frontend register it alongside existing browser Web Push subscriptions. The self-hosted `send-push-notification` Edge Function sends through VAPID or FCM according to the subscription provider.

The local `app/google-services.json` is required to build but intentionally excluded from Git. Firebase service-account credentials belong only in the protected self-hosted Edge Functions environment. Never commit signing keys or service-account credentials.

## When a new Android release is required

Normal hosted UI changes do not require one. Publish a new Android version when changing native permissions/features, the app icon/name, signing or Firebase configuration, Android SDK requirements, or Play policy-related native behavior.
