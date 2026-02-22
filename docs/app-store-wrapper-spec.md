# MaiTribe App Store Wrapper Specification

Last updated: 2026-02-21  
Target: Publish MaiTribe PWA as installable native apps on iOS App Store and Google Play Store.

## 1) Goal and Constraints
- Existing product remains a web app (PWA) and keeps one core UI codebase.
- Wrapper should minimize engineering overhead for a solo founder.
- Push notifications are required for reminders and event follow-ups.
- Budget-sensitive implementation.

## 2) Recommended Wrapper Stack
Primary recommendation: **Capacitor (Ionic toolchain optional)**

Why this option:
- Best iOS + Android push reliability (native APNs/FCM bridge).
- Better App Review survivability than a thin generic webview wrapper.
- Keeps PWA frontend reusable while enabling native capabilities.

## 3) High-Level Architecture
- Web app build output is copied into Capacitor `webDir`.
- Capacitor provides native iOS/Android shells.
- Push handled through native bridge:
  - iOS: APNs via Firebase Cloud Messaging (FCM) integration
  - Android: FCM directly
- Supabase remains backend/auth/database.
- n8n/Edge Functions continue as notification orchestration backend.

## 4) iOS Wrapper (App Store)

### 4.1 Project setup
```bash
npm install @capacitor/core @capacitor/cli @capacitor/ios
npx cap init maitribe com.maitribe.app --web-dir=.
npx cap add ios
```

Notes:
- If frontend gets a build step later, set `--web-dir=dist` and run build before `npx cap sync`.
- Keep app-like navigation and avoid exposing a raw browser shell feel.

### 4.2 iOS native configuration
- Open `ios/App/App.xcworkspace` in Xcode.
- Set bundle identifier, team signing, deployment target (recommended iOS 16+ for modern web capabilities).
- Configure permissions strings in `Info.plist` as needed (notifications, microphone if voice features used).
- Add app icons and launch/splash assets in Xcode asset catalog.

### 4.3 iOS production checklist
- `WKWebView` loads app shell from bundled assets.
- Deep link strategy defined (universal links optional but recommended).
- Privacy manifest and data use metadata prepared for App Store Connect.
- TestFlight test pass before review submission.

## 5) Android Wrapper (Google Play)

### 5.1 Project setup
```bash
npm install @capacitor/android
npx cap add android
npx cap sync android
```

### 5.2 Android native configuration
- Open Android project in Android Studio.
- Set application ID (package name), min SDK, target SDK.
- Configure signing for release build (`keystore`).
- Add adaptive app icons and splash resources.

### 5.3 Android production checklist
- Test on physical devices (background behavior, notification delivery).
- Verify battery optimization impact on notification timing.
- Build signed AAB and upload to Play Console internal testing track.

## 6) Push Notification Setup (APNs + FCM)

## 6.1 Firebase project
- Create Firebase project for MaiTribe mobile apps.
- Register iOS bundle ID and Android package ID.
- Download platform config files:
  - iOS: `GoogleService-Info.plist`
  - Android: `google-services.json`

## 6.2 APNs setup (iOS)
- Create APNs Auth Key in Apple Developer portal.
- In Firebase Console -> Cloud Messaging -> iOS app config:
  - Upload APNs key (`.p8`)
  - Enter Key ID and Apple Team ID
- In Xcode capabilities enable:
  - Push Notifications
  - Background Modes -> Remote notifications

## 6.3 Capacitor push plugin integration
Install:
```bash
npm install @capacitor/push-notifications
npx cap sync
```

Runtime flow:
1. Request push permission in app.
2. Register device token.
3. Persist token/subscription in Supabase (`users.push_token` or dedicated `device_tokens` table).
4. Send push via backend (recommended: Supabase Edge Function or n8n webhook).

## 6.4 Backend delivery model
Recommended for scale:
- Store device tokens per user and platform.
- Send via FCM HTTP v1 API.
- For iOS, FCM bridges to APNs.
- Handle invalid tokens and prune on delivery failures.

## 7) Required Store Assets

## 7.1 iOS (App Store Connect)
- App icon (1024x1024, no alpha)
- iPhone screenshots (6.7" and 6.5" required sets; additional sizes optional)
- Optional iPad screenshots (if iPad supported)
- App subtitle, promotional text, description
- Privacy policy URL
- Support URL
- Age rating questionnaire

## 7.2 Android (Google Play Console)
- App icon (512x512)
- Feature graphic (1024x500)
- Phone screenshots (minimum 2)
- Optional tablet screenshots
- Short description, full description
- Privacy policy URL
- Data safety form
- Content rating form

## 8) Store Approval Risk Controls
- Ensure app provides clear native-value behavior (not just a static website clone).
- Add stable onboarding, authenticated user journeys, and reliable offline/error states.
- Ensure legal docs are available in-app and on web:
  - Privacy Policy
  - Terms of Service
- Validate all broken-link and blank-state scenarios before submission.

## 9) Estimated Timeline
| Phase | Scope | Estimate |
|---|---|---|
| 1 | Capacitor bootstrap + iOS/Android shells | 1-2 days |
| 2 | Push integration (FCM + APNs + token persistence) | 2-4 days |
| 3 | QA on real devices + bug fixes | 3-5 days |
| 4 | Store metadata/assets preparation | 1-2 days |
| 5 | Submission + review cycles | 3-10 days |

Expected first production release window: **~2 to 4 weeks** for a solo founder.

## 10) Estimated Costs
| Item | Cost |
|---|---|
| Apple Developer Program | USD 99/year |
| Google Play Console | USD 25 one-time |
| Capacitor/Ionic framework | Free (open source) |
| Firebase Cloud Messaging | Free tier (typical early-stage usage) |
| Optional design assets/tools | Variable (USD 0-200+) |

## 11) Suggested Execution Order
1. Implement Capacitor wrapper and publish Android first (faster feedback loop).
2. Finalize APNs + FCM and validate iOS push on TestFlight.
3. Submit iOS after push and onboarding flows are stable.
4. Move all push sending to backend workflows (n8n + Edge Functions) and remove client-only assumptions.
