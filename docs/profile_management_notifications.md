# Profile Management and Notifications

## Purpose

Profile Management controls the user's identity, account settings, privacy settings, public profile visibility, and account lifecycle in HobbyQuest.

Notifications support the social feedback loop by alerting users when another user reacts to or reviews their guild post. The notification system connects Firebase Cloud Messaging, user device tokens, user notification preferences, Cloud Functions, and dashboard navigation.

Together, these features allow users to:

- Create and maintain their learner profile.
- View their progression stats.
- Update account details.
- Control public visibility.
- Enable or disable guild alerts.
- Sign out safely.
- Delete their account and related app data.
- Receive guild activity notifications.
- Tap notifications and return directly to the relevant guild post.

## Functional Description

### 1. Profile Creation

A profile is created after authentication and onboarding.

The authentication account can exist before the app profile exists. A new user first creates or signs into a Firebase Auth account, then completes onboarding to create the Firestore user document.

Onboarding collects:

- Nickname.
- Birth date.
- Gender.
- Avatar image.
- Hobby category.
- Hobby.
- Skill level.
- Goal.
- Learning pace.

When onboarding is accepted, the app creates:

- The user profile document.
- The active plan ID.
- Initial progression values.
- Initial privacy settings.
- Initial notification settings.
- Initial category XP buckets.
- Initial plan metadata.
- Initial milestones.
- Initial quests.
- Initial goal history.

The app then registers the current device for push notifications if notification service is available and the user's notification preference allows it.

### 2. Authentication and Profile Routing

The app separates Firebase Auth identity from the HobbyQuest profile document.

Startup routing works as follows:

- If no Firebase Auth user exists, the user is sent to the welcome/login flow.
- If a Firebase Auth user exists and a matching `users/{uid}` document exists, the user is sent to the dashboard.
- If a Firebase Auth user exists but no profile document exists, the user is sent to onboarding.

This prevents users from entering the dashboard with an incomplete or missing app profile.

### 3. Profile Page

The profile page is the user's account hub.

It displays:

- Avatar.
- Nickname.
- Email address.
- Level.
- Current XP in level.
- XP progress bar.
- Total XP.
- Current streak.
- Guild post count.
- Account settings.
- General settings.
- Logout action.
- Delete account action.

The page uses the current Firebase Auth user for email and the Firestore user document for profile and progression data.

### 4. Adventure Stats

The profile page summarizes user progress with an "Adventure Stats" section.

Stats include:

- Rank / level.
- Total XP.
- Current streak.
- Guild post count.

Level and current XP are derived from `totalXP`:

```text
level = floor(totalXP / 1000) + 1
currentXp = totalXP % 1000
```

The guild post count is calculated by querying `guild_posts` where `userId` equals the current user ID.

### 5. Editable Account Fields

Users can edit:

- Email address.
- Avatar name / nickname.
- Birth date.

The avatar image and gender are selected during onboarding and are not currently editable from the profile page.

#### Email

Changing email uses Firebase Auth's email update flow.

The user enters a new email address. The app validates the basic format, then calls Firebase Auth's `verifyBeforeUpdateEmail`.

If Firebase requires recent login, the app tells the user to log out and sign in again before retrying.

#### Avatar Name

The avatar name is the public display nickname.

Validation rules:

- Must not be empty.
- Must be at least 2 characters.
- Must be 50 characters or fewer.

On success, the nickname is updated in Firestore and local profile state.

#### Birth Date

Birth date is stored as a string in `YYYY-MM-DD` format.

Validation rules:

- Must match `YYYY-MM-DD`.
- Must parse as a date.
- Must not be in the future.
- Age must not be more than 150.
- Age must not be less than 5.

On success, the birth date is updated in Firestore and local profile state.

### 6. Privacy and Security

The Privacy & Security page exposes two privacy switches:

| Setting | Field | User-facing behavior |
| --- | --- | --- |
| Profile visibility | `profileVisible` | Controls whether other users can view the public profile. |
| Post stats visibility | `postStatsVisible` | Controls whether other users can see reaction and review stats on guild posts. |

The profile owner can always view their own profile and stats.

If `profileVisible` is false:

- Other users see a private profile state.
- Other users cannot view that user's guild post history page.

If `postStatsVisible` is false:

- Other users see that post stats are hidden.
- Reaction and peer review counts are not shown to them.
- The post owner can still view their own stats.

The Privacy & Security page also shows a privacy policy dialog explaining what data the app stores and how the visibility toggles affect public views.

### 7. Notification Preference

The profile page includes a notification switch.

When notifications are enabled:

- The app saves `notificationsEnabled = true`.
- The app requests notification permission.
- The app retrieves the device's FCM token.
- The token is added to the user's `fcmTokens` array.
- Guild alerts can be sent to the device.

When notifications are disabled:

- The app saves `notificationsEnabled = false`.
- The current device token is removed from the user's `fcmTokens` array.
- The device stops receiving guild push alerts.

The profile page shows a loading spinner while the notification preference update is in progress.

### 8. Guild Notification Events

The backend currently creates notifications for guild post activity.

Supported notification events:

- Another user reacts to the user's guild post.
- Another user submits a peer review on the user's guild post.

Self-activity is ignored. If the post owner reacts to or reviews their own post, no notification is sent to themselves.

Notification records are saved under the post owner's user document. Push notifications are also sent through Firebase Cloud Messaging when device tokens are available and notification preferences allow delivery.

### 9. Foreground Notifications

When the app is open and a push notification arrives, the app displays a snackbar.

The snackbar includes:

- Notification title.
- Notification body.
- Notification icon.
- Tap behavior.

Tapping the snackbar routes the user to the relevant guild post.

### 10. Notification Tap Routing

When the user taps a push notification:

1. The app extracts notification data.
2. The app checks whether it is a guild post notification.
3. If the user is signed in, the app opens the dashboard.
4. The dashboard receives arguments selecting the Guild tab.
5. The target post ID is passed to the Guild page.
6. The Guild page focuses the matching post when present.

If the user is not signed in, the app stores the tap arguments, sends the user to the welcome page, and opens the pending notification target after the user signs in.

### 11. Logout

Logout is a user-confirmed action.

When the user confirms logout:

1. A loading dialog appears.
2. The app signs out of Google Sign-In.
3. The app signs out of Firebase Auth.
4. The user is sent to the welcome page.

The notification service listens to auth state changes. When the Firebase Auth user becomes null, it removes the last known token from the previous user's document.

### 12. Account Deletion

Account deletion is permanent and requires confirmation.

The app asks the user to confirm destructive deletion. If confirmed, `ProfileController.deleteAccount` runs.

Deletion flow:

1. Show loading dialog.
2. Delete the Firebase Auth account.
3. Delete plan quest documents.
4. Delete plan milestone documents.
5. Delete plan documents.
6. Delete tree documents.
7. Delete legacy saved tree documents.
8. Delete goal history.
9. Delete growth letters.
10. Delete feedback documents.
11. Delete the user document.
12. Commit the Firestore batch.
13. Sign out from Google.
14. Return to the welcome page.

If Firebase Auth requires recent login, the app tells the user to log out, sign in again, and retry.

## Technical Implementation

### 1. Key Files

Profile and account files:

- `lib/app/controllers/profile_controller.dart`
- `lib/app/views/pages/profile_page.dart`
- `lib/app/views/pages/privacy_security_page.dart`
- `lib/app/views/pages/user_profile_page.dart`
- `lib/app/views/pages/user_guild_posts_page.dart`
- `lib/app/models/user_model.dart`
- `lib/app/controllers/auth_controller.dart`
- `lib/app/views/pages/login_page.dart`
- `lib/app/controllers/onboarding_controller.dart`
- `lib/app/bindings/initial_binding.dart`

Notification files:

- `lib/app/services/push_notification_service.dart`
- `functions/index.js`

Related services:

- `lib/app/services/goal_history_service.dart`
- `lib/app/services/growth_letter_service.dart`
- `lib/app/controllers/guild_controller.dart`

### 2. User Document Schema

The main profile data is stored at:

```text
users/{uid}
```

Important profile fields:

```text
nickname: string
birthDate: string
gender: string
avatarSvg: string
isOnboardingComplete: boolean
activePlanId: string
notificationsEnabled: boolean
profileVisible: boolean
postStatsVisible: boolean
createdAt: timestamp
updatedAt: timestamp
```

Progression fields shown on the profile:

```text
totalXP: number
currentStreak: number
dailyQuestCompletionCount: number
categoryXp: map<string, number>
lastRerollDate: timestamp
lastStreakDate: timestamp
lastQuestCompletionDate: timestamp
```

Notification token fields:

```text
fcmTokens: string[]
fcmToken?: string
fcmTokenUpdatedAt: timestamp
```

The app still supports legacy level/current XP parsing through `UserModel`, but the current source of truth is `totalXP`.

### 3. UserModel

`UserModel` is the typed representation of the Firestore user document.

It includes:

- Identity fields.
- Progression fields.
- Category XP.
- Tutorial flags.
- Privacy settings.
- Notification preference.
- Timestamps.
- Active plan ID.
- Current plan.

Important defaults:

- `notificationsEnabled = true`
- `profileVisible = true`
- `postStatsVisible = true`
- `currentStreak = 0`
- `dailyQuestCompletionCount = 0`
- `categoryXp = {}`

The model provides:

- `fromJson`
- `toJson`
- `toFirestore`
- `copyWith`
- Derived `level`
- Derived `currentXp`

### 4. Dependency Injection

`InitialBinding` registers these app-wide services/controllers:

```text
PushNotificationService().init()
AuthController()
GuildController()
```

`PushNotificationService` is registered asynchronously and permanently. `AuthController` and `GuildController` are also permanent.

This means auth routing, guild state, and notification handling are available across the app lifecycle.

### 5. AuthController Routing

`AuthController.checkUserStatus()` determines where the user should go.

Logic:

```text
if FirebaseAuth.currentUser == null:
  go to WELCOME
else:
  read users/{uid}
  if document exists:
    register current device
    go to DASHBOARD
    open pending notification if any
  else:
    go to ONBOARDING
```

If Firestore returns permission denied while reading the user document, the user is returned to the welcome page.

### 6. Login and Registration

`LoginPage` supports:

- Email/password registration.
- Email/password login.
- Google Sign-In.

Email/password registration:

1. Validate email and password.
2. Call `FirebaseAuth.createUserWithEmailAndPassword`.
3. Show success message.
4. Navigate to onboarding.

Email/password login:

1. Validate email and password.
2. Call `FirebaseAuth.signInWithEmailAndPassword`.
3. Show welcome message.
4. Call `AuthController.checkUserStatus`.

Google Sign-In:

1. Initialize Google Sign-In.
2. Authenticate with email/profile scope.
3. Get the Google ID token.
4. Create a Firebase credential.
5. Sign in with Firebase.
6. Call `AuthController.checkUserStatus`.

### 7. Onboarding Save

The profile is created in `OnboardingController._saveUserDataToFirestore()`.

The method:

1. Reads the current Firebase Auth user.
2. Builds the initial quest plan.
3. Creates plan ID `plan_001`.
4. Builds milestone IDs.
5. Creates initial quest documents.
6. Creates a `UserModel`.
7. Writes the user document with server timestamps.
8. Writes plan metadata.
9. Writes milestones.
10. Writes quests.
11. Saves initial goal history.
12. Registers the current device for push notifications.

This is the first point where the Firebase Auth user becomes a complete HobbyQuest profile.

### 8. ProfileController State

`ProfileController` owns profile page state:

```text
isLoading: RxBool
isUpdatingNotifications: RxBool
isUpdatingPrivacy: RxBool
userModel: Rxn<UserModel>
guildPostCount: RxInt
notificationsEnabled: RxBool
profileVisible: RxBool
postStatsVisible: RxBool
```

Convenience getters expose:

```text
totalXP
level
xp
streak
nickname
avatarSvg
birthDate
email
uid
```

### 9. Loading Profile Data

`ProfileController.loadProfile()`:

1. Checks the current Firebase Auth user.
2. Reads `users/{uid}`.
3. Queries `guild_posts` where `userId == uid`.
4. Converts the user document to `UserModel`.
5. Copies notification and privacy values into reactive fields.
6. Stores guild post count.

If the profile fails to load, it shows an error dialog.

### 10. Updating Nickname

Method:

```text
ProfileController.updateNickname(newNickname)
```

Validation:

```text
trimmed.isNotEmpty
trimmed.length >= 2
trimmed.length <= 50
```

Firestore update:

```text
users/{uid}
  nickname: trimmed
  updatedAt: serverTimestamp
```

Local state:

```text
userModel.value = userModel.value.copyWith(nickname: trimmed)
```

### 11. Updating Email

Method:

```text
ProfileController.changeEmail(newEmail)
```

Validation:

- Must not be empty.
- Must contain `@`.
- Must contain `.`.
- UI validation additionally checks that username exists before `@` and domain exists after `@`.

Firebase Auth calls:

```text
user.verifyBeforeUpdateEmail(trimmed)
user.sendEmailVerification()
```

This sends verification for the new email. Firestore user profile email is not stored separately in `UserModel`; the app displays `FirebaseAuth.currentUser.email`.

### 12. Updating Birth Date

Method:

```text
ProfileController.updateBirthDate(newBirthDate)
```

Validation:

```text
YYYY-MM-DD regex
DateTime.parse succeeds
date is not future
age <= 150
age >= 5
```

Firestore update:

```text
users/{uid}
  birthDate: newBirthDate
  updatedAt: serverTimestamp
```

Local state is updated with `copyWith(birthDate: newBirthDate)`.

### 13. Updating Notification Preference

Method:

```text
ProfileController.updateNotificationsEnabled(enabled)
```

Behavior:

1. Read current Firebase Auth user.
2. Ignore request if an update is already in progress.
3. Optimistically update `notificationsEnabled`.
4. Save the preference to Firestore.
5. Call `PushNotificationService.applyNotificationPreference(enabled)`.
6. Update local `UserModel`.
7. Show success dialog.
8. Revert local state on error.

Firestore write:

```text
users/{uid}
  notificationsEnabled: enabled
  updatedAt: serverTimestamp
```

### 14. Updating Privacy Settings

Privacy settings use shared helper:

```text
ProfileController._updatePrivacySetting(...)
```

It:

1. Checks current user.
2. Blocks concurrent privacy updates.
3. Optimistically updates the RxBool.
4. Writes the field to Firestore with merge.
5. Updates the local `UserModel`.
6. Shows success dialog.
7. Reverts the RxBool on failure.

Profile visibility:

```text
ProfileController.updateProfileVisibility(visible)
```

Post stats visibility:

```text
ProfileController.updatePostStatsVisibility(visible)
```

When post stats visibility changes, the controller also updates:

```text
GuildController.userPostStatsVisible[uid] = visible
```

This keeps the guild feed's local visibility cache in sync.

### 15. Public Profile Enforcement

`UserProfilePage` reads the target user's document and builds a `UserModel`.

It determines:

```text
isOwnProfile = currentUid == userId
canViewProfile = isOwnProfile || userModel.profileVisible
canViewStats = isOwnProfile || userModel.postStatsVisible
```

If `canViewProfile` is false, it shows a private profile state.

If `canViewStats` is false, it hides public stats and shows a stats-hidden card.

### 16. Notification Service Initialization

`PushNotificationService.init()`:

1. Requests notification permission.
2. Binds message handlers.
3. Registers the current device.
4. Subscribes to Firebase Auth state changes.
5. Subscribes to FCM token refresh.

Notification permission request:

```text
alert: true
badge: true
sound: true
```

Foreground presentation options:

```text
alert: true
badge: true
sound: true
```

### 17. Device Token Registration

Method:

```text
PushNotificationService.registerCurrentDevice()
```

Behavior:

1. Read current user ID.
2. Check `notificationsEnabled`.
3. If disabled, remove current device token.
4. If enabled, get FCM token.
5. Save token to Firestore.

Token save:

```text
users/{uid}
  fcmTokens: arrayUnion([token])
  fcmTokenUpdatedAt: serverTimestamp
```

The service also tracks:

```text
_lastUid
_lastToken
```

These are used for cleanup during sign-out or token refresh.

### 18. Device Token Cleanup

The service removes tokens in these situations:

- User signs out.
- Notifications are disabled.
- FCM token refreshes and the old token should be removed.
- Cloud Function detects invalid tokens after a push attempt.

Client cleanup methods:

```text
_removeToken(uid, token)
_removeCurrentDeviceToken(uid)
_removeLastToken()
```

All remove tokens using:

```text
FieldValue.arrayRemove(...)
```

### 19. FCM Token Refresh

`PushNotificationService` listens to:

```text
FirebaseMessaging.onTokenRefresh
```

When a token refreshes:

1. If no user is signed in, ignore it.
2. If notifications are disabled, remove the refreshed token.
3. If notifications are enabled, remove the last token and save the new token.

This prevents stale device tokens from accumulating.

### 20. Foreground Message Handling

Foreground messages are handled by:

```text
_handleForegroundMessage(RemoteMessage message)
```

If the message has a title or body, the app shows a GetX snackbar.

The snackbar:

- Appears at the top.
- Uses app surface and text colors.
- Shows a notification icon.
- Lasts five seconds.
- Routes on tap through `_handleNotificationTap`.

### 21. Notification Tap Handling

Notification taps are handled by:

```text
_handleNotificationTap(RemoteMessage message)
```

The method:

1. Builds route arguments from message data.
2. Ignores unsupported notification types.
3. Deduplicates repeated handling with `_lastHandledMessageKey`.
4. If signed out, stores pending arguments and routes to welcome.
5. If signed in, opens the dashboard with arguments.

Supported guild notification data:

```text
type: post_reaction | post_review
postId: string
actorId: string
guildPostPath: guild_posts/{postId}
```

Dashboard arguments:

```text
{
  tabIndex: 2,
  notificationType: type,
  postId: postId,
  actorId: actorId,
  guildPostPath: guildPostPath
}
```

### 22. Pending Notification Handling

If a notification opens the app before navigation is ready, the service stores it as `_pendingInitialMessage`.

If the user is signed out when they tap a notification, the service stores route arguments as `_pendingTapArguments`.

After login or auth restoration, the service calls:

```text
openPendingInitialMessageIfAny()
_openPendingTapArguments()
```

This lets the user return to the intended guild post after authentication.

### 23. Backend Notification Creation

The Cloud Function is:

```text
notifyPostOwnerOnGuildPostActivity
```

Trigger:

```text
onDocumentUpdated("guild_posts/{postId}")
```

The function compares before and after data for:

- New reaction users.
- New peer review users.

It filters out activities where:

```text
activity.actorId == postOwnerId
```

Then it writes notification documents under:

```text
users/{postOwnerId}/notifications/{notificationId}
```

### 24. Backend Notification Payload

Common notification fields:

```text
actorId: string
actorName: string
createdAt: serverTimestamp
guildPostPath: string
isRead: false
postId: string
postTitle: string
recipientId: string
title: string
body: string
type: string
```

Reaction notification:

```text
title: "New reaction"
body: "{actorName} reacted {emoji} to your post."
type: "post_reaction"
reaction: emoji
```

Review notification:

```text
title: "New review"
body: "{actorName} reviewed your post."
type: "post_review"
```

### 25. Backend Push Delivery

The Cloud Function reads tokens from:

```text
users/{recipientId}.fcmTokens
users/{recipientId}.fcmToken
```

If `notificationsEnabled === false`, no tokens are returned.

The function sends messages in chunks of 500 tokens with:

- Notification title.
- Notification body.
- Data payload.
- Android click action.
- APNs default sound.

Invalid tokens are removed from the recipient user document.

### 26. Logout Implementation

Method:

```text
ProfileController.logout()
```

It:

1. Shows loading dialog.
2. Calls `GoogleSignIn.instance.signOut()`.
3. Calls `FirebaseAuth.signOut()`.
4. Dismisses loading.
5. Shows logged out message.
6. Routes to welcome.

Notification token cleanup is handled by `PushNotificationService` through its auth-state listener.

### 27. Account Deletion Implementation

Method:

```text
ProfileController.deleteAccount()
```

Important behavior:

- It deletes the Firebase Auth user first.
- If Auth deletion fails, Firestore profile data is kept.
- It then deletes several Firestore subcollections and the user document.
- It signs out from Google after Firestore cleanup.

Firestore cleanup includes:

```text
users/{uid}/plans/{planId}/quests/*
users/{uid}/plans/{planId}/milestones/*
users/{uid}/plans/{planId}
users/{uid}/tree/*
users/{uid}/savedTrees/*
users/{uid}/goalHistory/*
users/{uid}/growthLetters/*
users/{uid}/feedback/*
users/{uid}
```

Known scope note: the current deletion code does not delete top-level `guild_posts` authored by the user or notification documents under `users/{uid}/notifications`.

## Sequence Flows

### Profile Load

```text
ProfilePage
  creates ProfileController
ProfileController
  reads FirebaseAuth.currentUser
  loads users/{uid}
  queries guild_posts by userId
  builds UserModel
  updates reactive state
ProfilePage
  renders profile header, stats, account settings, and privacy/notification options
```

### Update Notification Preference

```text
User
  toggles notification switch
ProfileController
  optimistically updates notificationsEnabled
  writes users/{uid}.notificationsEnabled
  calls PushNotificationService.applyNotificationPreference
PushNotificationService
  if enabled: request permission and save FCM token
  if disabled: remove current device token
ProfileController
  updates UserModel
  shows success or rolls back on failure
```

### Receive Guild Push

```text
User B
  reacts to or reviews User A's guild post
Cloud Function
  detects new reaction/review
  writes users/{userA}/notifications/{notificationId}
  sends FCM push to User A's saved tokens
PushNotificationService
  receives foreground message or tap event
  routes to Dashboard with Guild tab arguments
GuildPage
  focuses target post
```

### Delete Account

```text
User
  confirms delete account
ProfileController
  deletes Firebase Auth user
  deletes app-owned user subcollections
  deletes users/{uid}
  signs out from Google
  routes to welcome
```

## Acceptance Criteria

A complete profile and notification implementation should satisfy:

- New Auth users without profiles are routed to onboarding.
- Auth users with profiles are routed to dashboard.
- Onboarding creates a user document with identity, privacy, notification, and progression fields.
- Profile page displays avatar, nickname, email, level, XP, streak, and guild post count.
- Nickname update validates length and updates Firestore.
- Birth date update validates format, date bounds, and age bounds.
- Email update uses Firebase Auth verification flow.
- Profile visibility controls public profile access.
- Post stats visibility controls public reaction/review stat access.
- Notification toggle saves preference to Firestore.
- Enabling notifications registers the current FCM token.
- Disabling notifications removes current device tokens.
- Token refresh replaces stale tokens.
- Logout signs out Firebase Auth and Google Sign-In.
- Account deletion removes the Auth user and app-owned user data.
- Guild reaction/review updates create notification records for post owners.
- Self activity does not notify the post owner.
- Push notifications are not sent when `notificationsEnabled` is false.
- Foreground pushes show a snackbar.
- Notification taps open the Guild tab and focus the relevant post.

## Current Limitations and Risks

Known limitations:

- Account deletion deletes the Firebase Auth user before Firestore cleanup. If Firestore cleanup fails afterward, orphaned data may remain.
- Account deletion does not remove top-level guild posts authored by the user.
- Account deletion does not explicitly delete `users/{uid}/notifications`.
- Email validation is basic and may accept some invalid addresses or reject some valid edge cases.
- Changing email sends verification but does not update any separate Firestore email field because email is read from Firebase Auth.
- Avatar image and gender are not editable from the profile page.
- Notification permission denial is logged but not surfaced as a dedicated user-facing state.
- There is no notification inbox UI even though notification documents are written.
- Notification read state is written by the backend as `isRead: false`, but this codebase does not show read/unread management.
- Token cleanup depends on best-effort client and backend behavior.
- Public privacy enforcement is implemented in UI code; Firestore security rules should also enforce it for strong privacy.
- `dailyQuestCompletionCount` is displayed in the data model but not surfaced on the profile page.

## Recommended Improvements

Recommended next steps:

- Move account deletion cleanup into a backend callable function for stronger consistency.
- Delete or anonymize top-level guild posts during account deletion.
- Delete `users/{uid}/notifications` during account deletion.
- Add a notification inbox page.
- Add notification read/unread state management.
- Show notification permission-denied guidance in the UI.
- Add avatar and gender editing if desired.
- Add stronger email validation or rely entirely on Firebase Auth errors.
- Add re-authentication prompts for email change and account deletion.
- Enforce privacy and ownership in Firestore security rules.
- Add tests for profile update validation and notification preference token behavior.
