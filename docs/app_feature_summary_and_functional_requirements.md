# HobbyQuest App Feature Summary and Functional Requirements

## 1. Document Purpose

This document summarizes the implemented features of the HobbyQuest application and converts those features into functional requirements suitable for a project report.

The summary is based on the current Flutter codebase, Firebase integration, Cloud Functions backend, and existing feature documentation under `docs/`.

## 2. Application Overview

HobbyQuest is a gamified hobby-learning mobile application built with Flutter. It helps users choose a hobby goal, receive an AI-generated learning plan, complete structured quests, earn XP, grow category trees, collect trees in a forest, reflect on progress, and interact with other learners through a community guild.

The application combines:

- User authentication and onboarding.
- AI-assisted goal validation and quest-plan generation.
- Quest-based learning with dependencies.
- Reflection and optional image evidence.
- XP, levels, streaks, milestones, and tree growth.
- Weekly AI-generated growth letters.
- A guild feed for sharing achievements and receiving peer feedback.
- Privacy, notifications, profile management, and account lifecycle controls.

## 3. Primary Users and Actors

### 3.1 Learner

The learner is the main app user. The learner can:

- Register and log in.
- Complete onboarding.
- Select a hobby and goal.
- Complete quests.
- Earn XP and grow trees.
- Share progress to the guild.
- React to and review other guild posts.
- Manage profile, privacy, and notification settings.

### 3.2 Firebase Authentication User

Firebase Authentication represents the user's login identity. An authenticated Firebase account may exist before a full HobbyQuest profile is created.

### 3.3 HobbyQuest Profile User

The HobbyQuest profile is the app-specific Firestore document under `users/{uid}`. It stores the user's nickname, avatar, active plan, XP, streak, category XP, privacy settings, notification settings, and timestamps.

### 3.4 AI Service

Gemini is used as the AI service for:

- Validating custom goals.
- Generating four-part learning plans.
- Generating 20-node quest graphs for each milestone.
- Rerolling individual quests.
- Reviewing quest photo evidence.
- Generating weekly growth letters.

### 3.5 Guild Community Member

A guild member is any authenticated user who creates, reacts to, reviews, or views public guild posts.

### 3.6 Backend Notification Function

The Firebase Cloud Function detects guild post updates and sends notifications when a post receives a new reaction or peer review from another user.

## 4. Technology Stack

### 4.1 Frontend

- Flutter.
- GetX for routing, dependency injection, and reactive state.
- Material UI.
- Rive for animations.
- Google Fonts.
- Image picker for photo evidence and guild images.
- Video player support.
- Confetti and custom reward screens.

### 4.2 Backend and Cloud Services

- Firebase Core.
- Firebase Authentication.
- Cloud Firestore.
- Firebase Cloud Messaging.
- Firebase Cloud Functions.
- Google Sign-In.

### 4.3 External Services

- Gemini API through `google_generative_ai`.
- ImgBB image upload service.
- YouTube search links through generated search queries.

## 5. Application Navigation

### 5.1 Main Routes

The application defines these named routes:

- `/welcome`
- `/login`
- `/onboarding`
- `/dashboard`
- `/home`
- `/quest-detail`
- `/user-profile`
- `/user-guild-posts`
- `/forest`
- `/goal-history`
- `/privacy-security`
- `/help-support`
- `/growth-letter`

### 5.2 Dashboard Tabs

The dashboard uses an `IndexedStack` to preserve tab state. It contains four main tabs:

- Home: current learning plan and quests.
- Forest: map/tree growth and forest collection.
- Guild: community feed.
- Profile: account and settings.

### 5.3 Notification Deep Linking

Guild push notifications can open the dashboard directly to the Guild tab and focus a target guild post.

## 6. Authentication and Startup Routing

### 6.1 Feature Summary

The app separates login identity from app profile completion. A user may be authenticated through Firebase Auth but still need onboarding before accessing the dashboard.

Startup routing behavior:

- If no Firebase Auth user exists, the app routes to the welcome page.
- If a Firebase Auth user exists and `users/{uid}` exists, the app routes to the dashboard.
- If a Firebase Auth user exists but no app profile document exists, the app routes to onboarding.
- If Firestore denies access while checking the profile, the app routes to the welcome page.

### 6.2 Login and Registration

The login page supports:

- Email and password registration.
- Email and password login.
- Google Sign-In.

After authentication, the app checks whether the user's profile document exists before deciding whether to open onboarding or the dashboard.

## 7. Onboarding and Learner Setup

### 7.1 Feature Summary

Onboarding collects learner identity, hobby selection, skill level, goal, and learning pace. It then uses AI to generate a personalized quest blueprint.

The onboarding flow has four steps:

1. Profile identity.
2. Hobby category and hobby selection.
3. Current skill level.
4. Goal and learning pace.

After the generated plan is shown, the user can accept it to create the profile and initial learning data.

### 7.2 Profile Identity Step

The user enters or selects:

- Nickname, called "Hero Name".
- Gender or character type.
- Birth date.
- Avatar.

Avatar choices are grouped by character class:

- Cultivator.
- Earthbreaker.
- Grovekeeper.
- Harvester.
- Nurturer.
- Wildseed.

Each avatar class has a short learning-style description and trait labels. The gender selection filters avatar artwork, while "Other" shows all available avatar variants.

### 7.3 Category and Hobby Step

The app loads categories from Firestore and seeds default categories when the collection is empty.

Seeded categories include:

- Creative Arts.
- Music & Performing.
- Lifestyle & Wellness.
- Skill & Strategy.

Each category contains hobbies and peer review axes. Current UI behavior allows selection of Drawing while other hobbies are displayed as locked.

### 7.4 Skill Level Step

The user selects one skill level:

- Novice.
- Intermediate.
- Expert.

The selected level is passed into AI plan generation and stored in the active plan.

### 7.5 Goal and Learning Pace Step

The user can choose a predefined goal template or write a custom goal.

For Drawing, predefined goals are based on skill level. Examples include:

- Novice: learn basic shading, sketch a coffee cup, draw a simple cartoon.
- Intermediate: draw a realistic portrait, master two-point perspective, learn to draw hands.
- Expert: design dynamic action poses, complete an anatomy study, master hyper-realistic lighting.

The user also selects a learning pace:

- Casual Explorer.
- Steady Learner.
- Hardcore Grinder.

### 7.6 AI Goal Validation

Custom goals are validated before plan generation. Validation checks whether the goal is:

- Relevant to the selected hobby.
- Appropriate for the selected skill level.
- Specific enough for a step-by-step plan.

If no Gemini API key exists, local validation is used.

### 7.7 AI Plan Generation

The app generates a quest plan with exactly four milestones. If AI generation fails or no API key is available, fallback milestones are generated locally.

The generated plan summary shows:

- User avatar.
- Nickname.
- Starting level.
- Hobby.
- Main quest.
- Character type.
- Four milestone titles.
- XP threshold labels.

### 7.8 Profile and Plan Creation

When the user accepts the generated plan, the app creates:

- The `users/{uid}` profile document.
- Active plan ID `plan_001`.
- Plan metadata under `users/{uid}/plans/{planId}`.
- Milestones under `users/{uid}/plans/{planId}/milestones`.
- Initial quests under `users/{uid}/plans/{planId}/quests`.
- Initial category XP values.
- Initial goal history entry.
- Initial privacy and notification defaults.

The first milestone's quest graph is generated as a 20-node directed acyclic graph.

## 8. AI Quest Planning

### 8.1 Feature Summary

HobbyQuest uses Gemini to convert a learning goal into structured milestone phases and quest nodes.

### 8.2 Milestone Generation

The app asks Gemini to generate four major milestones. Each milestone represents a phase of the user's journey.

If Gemini returns invalid or insufficient data, fallback milestones are used.

### 8.3 Quest Graph Generation

For each milestone, Gemini generates 20 quest nodes.

Each quest node includes:

- Node ID.
- Title.
- Description.
- Five steps.
- Duration estimate.
- Quest type.
- YouTube search query.
- Dependencies.

The prompt requires:

- Exactly 20 nodes.
- Exactly three foundational root nodes.
- Parallel branches, not a single line.
- Dependencies that only point backward.
- Converging advanced nodes.

### 8.4 Quest Types

The app supports three quest types:

- `knowledge`: theory, observation, reading, or watching.
- `practice`: hands-on skill-building tasks.
- `challenge`: boss-level practical tasks requiring photo proof.

### 8.5 XP by Quest Type

Default XP rewards are:

- Knowledge: 50 XP.
- Practice: 100 XP.
- Challenge: 150 XP.

### 8.6 Fallback Quest Generation

If AI generation fails, the app generates fallback quest nodes locally. Fallback nodes still include:

- Node IDs.
- Titles.
- Descriptions.
- Steps.
- XP rewards.
- Quest types.
- Durations based on learning pace.
- Dependencies across three lanes.

## 9. Home Page and Quest List

### 9.1 Feature Summary

The home page displays the user's current profile, plan details, active quest graph, completed quests, growth letter availability, and quest actions.

The `HomeController` loads:

- User profile.
- Active plan metadata.
- Plan milestones.
- Plan quests.
- Growth letter availability.

### 9.2 Quest Active State

The app recomputes quest active states from dependencies instead of relying only on stored `isActive` values.

A quest is active when:

- It is incomplete.
- It has no dependencies, or all dependencies are completed.

Completed quests appear before active and locked quests in the sorted list.

### 9.3 Locked Quests

Locked quests are quests whose dependency requirements are not yet satisfied. They remain visible in the quest graph but cannot be completed until prerequisites are completed.

### 9.4 Completed Quests

Completed quests remain visible as progress history. The home page includes state for expanding or collapsing completed quest sections.

### 9.5 Growth Letter Indicator

The home controller watches the latest growth letter and checks whether a new letter is available. It can update the dashboard when a letter is unread or when the next letter becomes available.

## 10. Quest Detail and Completion

### 10.1 Feature Summary

The quest detail screen lets a learner review quest information, complete required steps, submit a reflection, optionally add image evidence, receive AI feedback on the image, and complete the quest.

### 10.2 Quest Detail Data

A quest can display:

- Title.
- Description.
- Quest type.
- XP reward.
- Duration estimate.
- Step list.
- Completion status.
- Reflection note.
- Uploaded image URL.
- AI feedback fields.
- YouTube search query.

### 10.3 Reflection Requirement

Quest completion requires a reflection note. The existing progression documentation states a minimum reflection length of 15 characters.

### 10.4 Challenge Photo Requirement

Challenge quests require a photo attachment before completion. Knowledge and practice quests can include an image optionally.

### 10.5 AI Image Review

If the learner attaches a photo, Gemini reviews the image evidence before the quest can be completed.

The AI review returns:

- Approval status.
- Short greeting.
- Observation.
- Tip.

If the photo is rejected, the quest is not completed and no XP is awarded.

### 10.6 Image Upload

Approved image evidence is uploaded through ImgBB. The resulting image URL is stored on the completed quest.

### 10.7 Quest Completion Write

Quest completion updates the quest document under:

`users/{uid}/plans/{planId}/quests/{questId}`

Completion stores:

- `isCompleted = true`.
- `isActive = false`.
- Reflection note.
- Completion timestamp.
- Optional image URL.
- Optional AI feedback fields.

The user document is also updated with `lastQuestCompletionDate` and `updatedAt`.

### 10.8 XP Awarding

After quest completion is saved, the progression controller awards XP.

The total XP award is:

- Quest base XP.
- Plus 50 XP when approved image evidence is uploaded.

XP is added to:

- `totalXP`.
- The matching category XP bucket under `categoryXp`.

### 10.9 Optional Guild Sharing

After successful completion, the app asks whether the learner wants to share the achievement to the guild.

If accepted, the guild post dialog opens with:

- Title prefilled as `Completed: {questTitle}`.
- Body prefilled with the reflection.
- Optional image evidence reused.
- Hobby and category inferred from the active plan.

## 11. Quest Reroll

### 11.1 Feature Summary

The reroll feature lets a learner replace the contents of an active incomplete quest while keeping the same quest identity and progression position.

### 11.2 Reroll Flow

When the user taps reroll:

1. The app shows a confirmation dialog.
2. The user confirms or cancels.
3. If confirmed, Gemini generates an alternative quest.
4. The existing quest document is updated.
5. The active plan is reloaded.
6. The UI refreshes.
7. A success or failure dialog is shown.

### 11.3 Reroll Fields Changed

Reroll updates:

- Quest title.
- Quest description.
- Quest steps.
- YouTube search query.

### 11.4 Reroll Fields Preserved

Reroll keeps:

- Quest ID.
- Quest type.
- XP reward.
- Duration.
- Dependencies.
- Active state.
- Completion state.
- Reflection note.
- Completion timestamp.
- Evidence image.
- AI feedback.
- Milestone index.
- Plan ID.

### 11.5 Reroll Timestamp

After successful reroll, the app updates `users/{uid}.lastRerollDate`.

The timestamp is currently recorded but not used to enforce cooldowns or limits.

## 12. Gamified Progression

### 12.1 Feature Summary

HobbyQuest turns learning activity into game-like progression through XP, levels, streaks, milestones, tree growth, and forest collection.

### 12.2 Global XP

The user document stores `totalXP`. This is the source of truth for overall progression.

### 12.3 Level Formula

Level is derived from total XP:

```text
level = floor(totalXP / 1000) + 1
currentXp = totalXP % 1000
xpToNextLevel = 1000 - currentXp
```

### 12.4 Level-Up Feedback

When a quest completion crosses a 1,000 XP boundary, the app stores a pending level-up state and later shows a level-up modal.

### 12.5 Streaks

The streak system tracks consecutive calendar days with at least one completed quest.

On quest completion:

- No previous streak date: streak becomes 1.
- Last streak date is today: streak remains unchanged.
- Last streak date was yesterday: streak increments.
- Last streak date is older: streak resets to 1.

The user document stores:

- `currentStreak`.
- `lastStreakDate`.

### 12.6 Global XP Milestones

The app checks XP thresholds:

- 2,000 XP.
- 4,000 XP.
- 6,000 XP.
- 8,000 XP.

Crossing a threshold can trigger a milestone reward modal.

### 12.7 Learning-Plan Milestones

The active plan contains four ordered milestones. When all quests in the current milestone are complete and another milestone exists:

1. The app detects milestone completion.
2. The milestone-complete screen is shown.
3. The user confirms advancement.
4. The current milestone is marked complete.
5. Gemini generates the next milestone quest graph.
6. New quest documents are written.
7. The current milestone index is advanced.
8. The home quest list refreshes.

### 12.8 Category XP

Each hobby belongs to a category. When a quest is completed, XP is added to the category's XP bucket.

Category XP is stored in:

`users/{uid}.categoryXp`

### 12.9 Category Resolution

The app resolves the category for a quest based on the current hobby. It attempts exact hobby matching first, partial matching next, and falls back to the first loaded category when needed.

## 13. Tree Growth and Forest Collection

### 13.1 Feature Summary

Category XP grows a tree on the map page. When a tree reaches maturity, the user can name it and plant it into the forest.

### 13.2 Tree Growth Stages

Tree stages are based on category XP:

| Stage | Label | Required XP | Asset |
| --- | --- | ---: | --- |
| 0 | Seed | 0 | `seed.png` |
| 1 | Sprout | 100 | `sprout.png` |
| 2 | Seedling | 300 | `seedling.png` |
| 3 | Young Tree | 500 | `young_tree.png` |
| 4 | Mature Tree | 800 | `mature_tree.png` |

### 13.3 Interactive Tree Growth

The map page separates actual stage from displayed stage. If the user has enough XP for a new stage, the page shows a prompt such as "Tap me to grow!" and waits for the user to tap the tree.

### 13.4 Saving a Mature Tree

When a tree reaches mature stage:

1. The app asks for a tree name.
2. It finds the first free forest slot.
3. It saves a tree document under `users/{uid}/tree`.
4. It stores metadata such as category, XP required, quest count, and learning minutes.
5. It resets that category's XP to 0.

### 13.5 Forest Page

The forest page displays planted trees in a grid.

The forest supports:

- Viewing planted trees.
- Empty planting spots.
- Total trees grown.
- Total XP represented by planted trees.
- Tree details.
- Renaming trees.
- Dragging trees to swap or move positions.

## 14. Growth Letters

### 14.1 Feature Summary

Growth letters are weekly AI-generated reflection rewards. They summarize recent quest completion and turn progress into a narrative letter.

### 14.2 Availability Rules

A growth letter is available when:

- The user has an active plan.
- The user completed at least one quest in the latest seven-day period.
- There is no unread letter already waiting.
- At least seven days have passed since the latest generated letter, unless an existing letter needs missing stats or insights backfilled.

### 14.3 Letter Content

A growth letter stores:

- User ID.
- Plan ID.
- Hobby.
- Nickname.
- Letter text.
- Quest count.
- Reflection count.
- Weekly streak days.
- Completed quest IDs.
- Strongest growth area.
- Focus area.
- Suggested next-week focus.
- Period start.
- Period end.
- Created timestamp.
- Read timestamp.

### 14.4 Read State

When the growth letter page opens the current letter, the app marks it as read and updates the dashboard unread state.

### 14.5 Guild Sharing

Growth letters can be shared to the guild. The guild post dialog is prefilled with growth-letter content and the app resolves the user's hobby category.

## 15. Community Guild

### 15.1 Feature Summary

The Community Guild is the social learning area. It allows users to create posts, share quest achievements, share growth letters, react to posts, submit structured peer reviews, view public profiles, and receive push notifications about guild activity.

### 15.2 Guild Feed

Guild posts display:

- Author avatar.
- Author nickname.
- Hobby.
- Relative post time.
- Title.
- Body.
- Optional image.
- Reaction buttons.
- Peer review button.
- Optional stats menu.

### 15.3 Feed Filters

The feed supports:

- For You.
- Same Hobby.
- Same Character.

The For You feed scores posts by:

- Same hobby.
- Same category.
- Same avatar character class.
- Recency.

### 15.4 Creating Posts

Users can create posts with:

- Required title.
- Required body.
- Optional image.
- Hobby.
- Category ID.

Images are uploaded with ImgBB before the post is saved.

### 15.5 Quest Achievement Sharing

Completed quests can be shared to the guild through a prefilled post dialog. This sharing is optional and does not affect XP or completion state.

### 15.6 Growth Letter Sharing

Growth letters can be shared as guild posts. The app resolves the user's hobby and category before opening the dialog.

### 15.7 Reactions

Guild posts support reactions. The controller currently uses three reaction types:

- Fire.
- Clap.
- Idea.

Reaction data is stored as a map of reaction keys to user ID arrays.

Users can toggle reactions on and off.

### 15.8 Peer Reviews

Users can submit one peer review per post.

Peer reviews:

- Use sliders from 1 to 5.
- Use hobby-specific review axes when available.
- Fall back to generic axes when needed.
- Require confirmation before submission.
- Cannot be changed through the current UI after submission.

### 15.9 Peer Review Stats

When visible, peer review stats show:

- Average rating by axis.
- Radar chart when enough axes are available.
- Reviewer list.
- Empty state when no reviews exist.

### 15.10 Public Profiles

Users can open public profiles from guild posts. Public profiles show:

- Avatar.
- Nickname.
- User ID.
- Level.
- Total XP.
- XP to next level.
- Guild post count.

Profile visibility settings can hide this information from other users.

### 15.11 User Guild Post History

The app can show all guild posts by a selected user. The page respects profile visibility and loads related author, reactor, and reviewer profiles.

### 15.12 Demo Data Seeding

The guild controller currently seeds demo users and demo guild posts during initialization when needed. This appears intended for demonstration or development data.

## 16. Notifications

### 16.1 Feature Summary

The notification system alerts users when another user reacts to or reviews their guild post.

### 16.2 Notification Events

Supported events:

- `post_reaction`.
- `post_review`.

Self-activity is ignored, so users do not receive notifications for reacting to or reviewing their own posts.

### 16.3 Notification Storage

Notification documents are stored under:

`users/{recipientId}/notifications/{notificationId}`

Notification fields include:

- Actor ID.
- Actor name.
- Created timestamp.
- Guild post path.
- Read state.
- Post ID.
- Post title.
- Recipient ID.
- Title.
- Body.
- Type.
- Optional reaction value.

### 16.4 Push Delivery

The Cloud Function sends Firebase Cloud Messaging pushes to saved recipient tokens.

It reads:

- `fcmTokens`.
- Legacy `fcmToken`.
- `notificationsEnabled`.

If `notificationsEnabled` is false, no push is sent.

Invalid FCM tokens are removed from the user's document.

### 16.5 Foreground Messages

When a notification arrives while the app is open, the app shows a snackbar with the notification title and body.

### 16.6 Notification Tap Routing

When a user taps a guild notification:

1. The app extracts notification data.
2. It builds dashboard route arguments.
3. It selects the Guild tab.
4. It passes the post ID.
5. The guild page focuses the matching post.

If the user is signed out, the app stores pending notification arguments and opens them after login.

### 16.7 Device Token Management

The notification service:

- Requests permission.
- Registers the current FCM token.
- Saves tokens to the user profile.
- Removes tokens when notifications are disabled.
- Removes tokens when the user signs out.
- Handles token refresh.

## 17. Profile Management

### 17.1 Feature Summary

The profile page is the user's account hub. It displays identity, progression stats, account settings, privacy settings, notifications, logout, and deletion actions.

### 17.2 Profile Display

The profile page displays:

- Avatar.
- Nickname.
- Email.
- Level.
- Current XP.
- XP progress bar.
- Total XP.
- Current streak.
- Guild post count.

### 17.3 Editable Account Fields

Users can edit:

- Email address.
- Nickname or avatar name.
- Birth date.

Nickname validation:

- Required.
- At least 2 characters.
- Maximum 50 characters.

Birth date validation:

- Must use `YYYY-MM-DD`.
- Must parse as a date.
- Cannot be in the future.
- Age cannot exceed 150.
- Age cannot be below 5.

Email change uses Firebase Auth `verifyBeforeUpdateEmail`.

### 17.4 Privacy Settings

The Privacy and Security page exposes:

- Profile visibility.
- Post stats visibility.

Profile visibility controls whether other users can view public profile details.

Post stats visibility controls whether other users can see reaction and review statistics on guild posts.

The owner can always view their own profile and post stats.

### 17.5 Notification Settings

The user can enable or disable guild push notifications.

When enabled:

- The preference is saved.
- Permission is requested.
- The current FCM token is registered.

When disabled:

- The preference is saved.
- The current device token is removed.

### 17.6 Logout

Logout:

1. Shows a loading dialog.
2. Signs out of Google Sign-In.
3. Signs out of Firebase Auth.
4. Routes to the welcome page.

Notification token cleanup is handled by the notification service auth-state listener.

### 17.7 Account Deletion

Account deletion permanently removes the Firebase Auth account and app-owned user data.

The app attempts to delete:

- Firebase Auth account.
- User plans.
- Plan quests.
- Plan milestones.
- Tree documents.
- Legacy saved trees.
- Goal history.
- Growth letters.
- Feedback documents.
- User document.

Known current scope note: top-level guild posts authored by the user and notification documents are not explicitly deleted by the current account deletion flow.

## 18. Goal History

### 18.1 Feature Summary

Goal history preserves a record of the user's learning plans.

Each goal history entry includes:

- Hobby.
- Skill level.
- Goal.
- Learning pace.
- Category.
- Created date.

### 18.2 Storage

Goal history entries are stored under:

`users/{uid}/goalHistory/{historyId}`

### 18.3 User Access

The profile page links to goal history so users can review previous learning goals.

### 18.4 Deletion

Goal history is deleted during account deletion.

## 19. Help and Support

### 19.1 Feature Summary

The Help and Support page provides:

- Contact email.
- App name.
- Version label.
- Display version.

The support email shown in the app is:

`hobbyquest@gmail.com`

## 20. Core Data Model Summary

### 20.1 User Document

Path:

`users/{uid}`

Important fields:

- `nickname`
- `birthDate`
- `gender`
- `avatarSvg`
- `isOnboardingComplete`
- `activePlanId`
- `totalXP`
- `currentStreak`
- `lastStreakDate`
- `lastQuestCompletionDate`
- `lastRerollDate`
- `categoryXp`
- `notificationsEnabled`
- `profileVisible`
- `postStatsVisible`
- `fcmTokens`
- `fcmToken`
- `fcmTokenUpdatedAt`
- `mapTutorialDone`
- `createdAt`
- `updatedAt`

### 20.2 Plan Document

Path:

`users/{uid}/plans/{planId}`

Important fields:

- `id`
- `hobby`
- `level`
- `goal`
- `learningPace`
- `progress`
- `currentMilestoneIndex`
- `isActive`

### 20.3 Milestone Documents

Path:

`users/{uid}/plans/{planId}/milestones/{milestoneId}`

Important fields:

- `id`
- `title`
- `task`
- `completed`
- `order`

### 20.4 Quest Documents

Path:

`users/{uid}/plans/{planId}/quests/{questId}`

Important fields:

- `node_id`
- `title`
- `desc`
- `steps`
- `xp_reward`
- `type`
- `duration_minutes`
- `depends_on`
- `isCompleted`
- `isActive`
- `reflectionNote`
- `completedAt`
- `imageUrl`
- `greeting`
- `observation`
- `tip`
- `youtube_search_query`

### 20.5 Guild Post Documents

Path:

`guild_posts/{postId}`

Important fields:

- `userId`
- `hobby`
- `categoryId`
- `title`
- `body`
- `imageUrl`
- `reactions`
- `peerReviews`
- `createdAt`

### 20.6 Tree Documents

Path:

`users/{uid}/tree/{treeId}`

Important fields:

- `treeName`
- `categoryId`
- `xpRequired`
- `treeIndex`
- `questsCompleted`
- `learningMinutes`
- `createdAt`
- `grownAt`

### 20.7 Growth Letter Documents

Path:

`users/{uid}/growthLetters/{letterId}`

Important fields:

- `uid`
- `planId`
- `hobby`
- `nickname`
- `letter`
- `questCount`
- `reflectionCount`
- `weeklyStreakDays`
- `questIds`
- `strongestGrowth`
- `focusArea`
- `nextWeekFocus`
- `periodStart`
- `periodEnd`
- `createdAt`
- `readAt`

### 20.8 Notification Documents

Path:

`users/{uid}/notifications/{notificationId}`

Important fields:

- `actorId`
- `actorName`
- `createdAt`
- `guildPostPath`
- `isRead`
- `postId`
- `postTitle`
- `recipientId`
- `title`
- `body`
- `type`
- `reaction`

## 21. Functional Requirements

### 21.1 Authentication Requirements

FR-AUTH-001: The system shall allow users to register using email and password.

FR-AUTH-002: The system shall allow users to log in using email and password.

FR-AUTH-003: The system shall allow users to sign in using Google Sign-In.

FR-AUTH-004: The system shall check Firebase Auth state during startup.

FR-AUTH-005: The system shall route unauthenticated users to the welcome or login flow.

FR-AUTH-006: The system shall route authenticated users with existing profile documents to the dashboard.

FR-AUTH-007: The system shall route authenticated users without profile documents to onboarding.

FR-AUTH-008: The system shall prevent users from entering the dashboard before profile creation is complete.

### 21.2 Onboarding Requirements

FR-ONB-001: The system shall collect a nickname during onboarding.

FR-ONB-002: The system shall collect a birth date during onboarding.

FR-ONB-003: The system shall collect a gender or character type during onboarding.

FR-ONB-004: The system shall require the user to select an avatar.

FR-ONB-005: The system shall display avatar classes with descriptions and traits.

FR-ONB-006: The system shall load hobby categories from Firestore.

FR-ONB-007: The system shall seed default hobby categories when none exist.

FR-ONB-008: The system shall require the user to select a hobby.

FR-ONB-009: The system shall allow the user to select Novice, Intermediate, or Expert skill level.

FR-ONB-010: The system shall provide predefined goal templates based on hobby and level.

FR-ONB-011: The system shall allow the user to enter a custom goal.

FR-ONB-012: The system shall validate custom goals before generating a plan.

FR-ONB-013: The system shall require the user to select a learning pace.

FR-ONB-014: The system shall generate a four-milestone learning plan.

FR-ONB-015: The system shall display a plan summary before saving onboarding data.

FR-ONB-016: The system shall create a user profile only after the user accepts the generated plan.

FR-ONB-017: The system shall create an active plan, milestones, initial quests, category XP, and goal history during onboarding.

### 21.3 AI Planning Requirements

FR-AI-001: The system shall use Gemini to validate user goals when an API key is available.

FR-AI-002: The system shall use local validation if Gemini is unavailable.

FR-AI-003: The system shall use Gemini to generate four plan milestones when available.

FR-AI-004: The system shall generate fallback milestones if Gemini plan generation fails.

FR-AI-005: The system shall use Gemini to generate 20 quest nodes for a milestone.

FR-AI-006: The system shall require generated quest nodes to include title, description, steps, duration, type, YouTube query, and dependencies.

FR-AI-007: The system shall sanitize quest types to knowledge, practice, or challenge.

FR-AI-008: The system shall generate fallback quest nodes if Gemini quest generation fails.

FR-AI-009: The system shall assign XP rewards based on quest type.

### 21.4 Quest Requirements

FR-QUEST-001: The system shall load the user's active plan from Firestore.

FR-QUEST-002: The system shall load plan milestones from a milestones subcollection.

FR-QUEST-003: The system shall load plan quests from a quests subcollection.

FR-QUEST-004: The system shall recompute quest active states based on dependencies.

FR-QUEST-005: The system shall display completed, active, and locked quests.

FR-QUEST-006: The system shall allow users to open a quest detail page.

FR-QUEST-007: The system shall display quest title, description, type, duration, XP reward, and steps.

FR-QUEST-008: The system shall require a reflection before completing a quest.

FR-QUEST-009: The system shall require photo evidence for challenge quests.

FR-QUEST-010: The system shall allow optional photo evidence for non-challenge quests.

FR-QUEST-011: The system shall submit attached photo evidence to Gemini for review.

FR-QUEST-012: The system shall block quest completion if photo evidence is rejected.

FR-QUEST-013: The system shall upload approved image evidence to ImgBB.

FR-QUEST-014: The system shall save quest completion state to Firestore.

FR-QUEST-015: The system shall save reflection text with the completed quest.

FR-QUEST-016: The system shall save AI image feedback with the completed quest when available.

FR-QUEST-017: The system shall refresh the visible quest graph after completion.

FR-QUEST-018: The system shall offer optional guild sharing after quest completion.

### 21.5 Reroll Requirements

FR-REROLL-001: The system shall provide a reroll action for incomplete active quests.

FR-REROLL-002: The system shall show a confirmation dialog before rerolling a quest.

FR-REROLL-003: The system shall cancel reroll when the user declines confirmation.

FR-REROLL-004: The system shall use Gemini to generate an alternative quest.

FR-REROLL-005: The system shall update the existing quest document rather than creating a new quest.

FR-REROLL-006: The system shall update quest title, description, steps, and YouTube query during reroll.

FR-REROLL-007: The system shall preserve quest ID, type, XP reward, duration, dependencies, and completion state during reroll.

FR-REROLL-008: The system shall reload the active plan after a successful reroll.

FR-REROLL-009: The system shall record `lastRerollDate` after successful reroll.

FR-REROLL-010: The system shall show success or failure feedback after reroll.

### 21.6 Progression Requirements

FR-PROG-001: The system shall award XP when a quest is completed.

FR-PROG-002: The system shall add awarded XP to the user's total XP.

FR-PROG-003: The system shall add awarded XP to the matching category XP bucket.

FR-PROG-004: The system shall award a 50 XP bonus when completion includes approved image evidence.

FR-PROG-005: The system shall derive level from total XP.

FR-PROG-006: The system shall derive current XP within level from total XP.

FR-PROG-007: The system shall show level-up feedback when a level boundary is crossed.

FR-PROG-008: The system shall update streaks based on quest completion dates.

FR-PROG-009: The system shall not increment streak more than once for multiple quests completed on the same day.

FR-PROG-010: The system shall reset streak when the user misses a day.

FR-PROG-011: The system shall check global XP milestone thresholds after XP changes.

FR-PROG-012: The system shall detect when all quests in the current learning milestone are complete.

FR-PROG-013: The system shall allow advancement to the next learning milestone when available.

FR-PROG-014: The system shall generate a new quest graph for the next milestone.

### 21.7 Tree and Forest Requirements

FR-TREE-001: The system shall display category tree growth based on category XP.

FR-TREE-002: The system shall support tree stages at 0, 100, 300, 500, and 800 XP.

FR-TREE-003: The system shall prompt the user to tap when the tree can grow to a new stage.

FR-TREE-004: The system shall allow a mature tree to be named.

FR-TREE-005: The system shall save a mature tree to the user's forest.

FR-TREE-006: The system shall assign a forest slot to a saved tree.

FR-TREE-007: The system shall reset the relevant category XP after saving a mature tree.

FR-TREE-008: The system shall display planted trees in a forest grid.

FR-TREE-009: The system shall display forest summary statistics.

FR-TREE-010: The system shall allow planted trees to be renamed.

FR-TREE-011: The system shall allow planted trees to be repositioned.

### 21.8 Growth Letter Requirements

FR-LETTER-001: The system shall check whether a growth letter is available.

FR-LETTER-002: The system shall make a growth letter available when the user has recent completed quest activity and timing rules are satisfied.

FR-LETTER-003: The system shall generate a weekly growth letter using completed quest data.

FR-LETTER-004: The system shall include quest count, reflection count, weekly streak days, and quest IDs in a growth letter.

FR-LETTER-005: The system shall include personalized insight fields in a growth letter.

FR-LETTER-006: The system shall save growth letters under the user's profile.

FR-LETTER-007: The system shall mark a growth letter as read when opened.

FR-LETTER-008: The system shall update the dashboard unread state after a letter is read.

FR-LETTER-009: The system shall allow a growth letter to be shared to the guild.

### 21.9 Guild Requirements

FR-GUILD-001: The system shall load guild posts from Firestore.

FR-GUILD-002: The system shall load hobby categories for guild filtering and review axes.

FR-GUILD-003: The system shall display a guild feed with author, hobby, title, body, image, reactions, and review actions.

FR-GUILD-004: The system shall support For You, Same Hobby, and Same Character feed filters.

FR-GUILD-005: The system shall sort For You posts by relevance and recency.

FR-GUILD-006: The system shall allow users to create guild posts.

FR-GUILD-007: The system shall require title and body for guild posts.

FR-GUILD-008: The system shall allow optional image upload for guild posts.

FR-GUILD-009: The system shall allow completed quests to prefill guild posts.

FR-GUILD-010: The system shall allow growth letters to prefill guild posts.

FR-GUILD-011: The system shall allow users to toggle reactions.

FR-GUILD-012: The system shall store reactions by reaction key and user ID.

FR-GUILD-013: The system shall allow users to submit one peer review per post.

FR-GUILD-014: The system shall use hobby-specific peer review axes when available.

FR-GUILD-015: The system shall use default review axes when hobby-specific axes are unavailable.

FR-GUILD-016: The system shall calculate peer review average ratings.

FR-GUILD-017: The system shall hide reaction and review stats from viewers when the author disables post stats visibility.

FR-GUILD-018: The system shall allow post owners to view their own post stats regardless of visibility settings.

FR-GUILD-019: The system shall allow users to open public profiles from guild posts.

FR-GUILD-020: The system shall allow users to view guild posts by a specific public user.

### 21.10 Notification Requirements

FR-NOTIF-001: The system shall request notification permission.

FR-NOTIF-002: The system shall save FCM tokens for users who enable notifications.

FR-NOTIF-003: The system shall remove FCM tokens when notifications are disabled.

FR-NOTIF-004: The system shall remove the previous token when an FCM token refreshes.

FR-NOTIF-005: The system shall remove saved tokens when the user signs out.

FR-NOTIF-006: The backend shall detect new reactions on guild posts.

FR-NOTIF-007: The backend shall detect new peer reviews on guild posts.

FR-NOTIF-008: The backend shall ignore self-reactions and self-reviews.

FR-NOTIF-009: The backend shall write notification documents for guild activity.

FR-NOTIF-010: The backend shall send FCM pushes when recipient tokens exist and notifications are enabled.

FR-NOTIF-011: The backend shall remove invalid FCM tokens.

FR-NOTIF-012: The client shall show foreground notification snackbars.

FR-NOTIF-013: The client shall route guild notification taps to the Guild tab.

FR-NOTIF-014: The client shall focus the related guild post when possible.

FR-NOTIF-015: The client shall defer notification routing until after login when the user is signed out.

### 21.11 Profile and Privacy Requirements

FR-PROFILE-001: The system shall display the user's avatar, nickname, email, level, XP, streak, and guild post count.

FR-PROFILE-002: The system shall allow the user to update their nickname.

FR-PROFILE-003: The system shall validate nickname length before saving.

FR-PROFILE-004: The system shall allow the user to start a Firebase Auth email update.

FR-PROFILE-005: The system shall require Firebase Auth verification for email changes.

FR-PROFILE-006: The system shall allow the user to update birth date.

FR-PROFILE-007: The system shall validate birth date format and age bounds.

FR-PROFILE-008: The system shall allow the user to enable or disable notifications.

FR-PROFILE-009: The system shall allow the user to toggle profile visibility.

FR-PROFILE-010: The system shall allow the user to toggle post stats visibility.

FR-PROFILE-011: The system shall hide public profile details when profile visibility is disabled.

FR-PROFILE-012: The system shall hide public guild stats when post stats visibility is disabled.

FR-PROFILE-013: The system shall allow the user to log out.

FR-PROFILE-014: The system shall allow the user to delete their account after confirmation.

FR-PROFILE-015: The system shall delete app-owned user data during account deletion.

### 21.12 Goal History Requirements

FR-GOAL-001: The system shall save a goal history entry when the user accepts an onboarding plan.

FR-GOAL-002: The system shall store hobby, level, goal, learning pace, category, and created date in goal history.

FR-GOAL-003: The system shall load goal history entries sorted by most recent.

FR-GOAL-004: The system shall delete goal history during account deletion.

### 21.13 Help and Support Requirements

FR-SUPPORT-001: The system shall provide a Help and Support page.

FR-SUPPORT-002: The system shall display a support email address.

FR-SUPPORT-003: The system shall display app version information.

## 22. Non-Functional and Quality Requirements

NFR-001: The app should preserve dashboard tab state while switching tabs.

NFR-002: The app should provide loading indicators for long-running operations such as AI generation, profile loading, and notification updates.

NFR-003: The app should provide success, error, warning, or confirmation dialogs for major user actions.

NFR-004: Firestore writes that change important user data should use transactions or batches where consistency is required.

NFR-005: The app should provide fallback behavior when Gemini is unavailable.

NFR-006: The app should avoid awarding XP when quest completion validation fails.

NFR-007: The app should not send push notifications to users who disabled notifications.

NFR-008: The app should avoid notifying users about their own guild activity.

NFR-009: Public profile and post-stat visibility should be enforced consistently in the UI and should also be protected by Firestore security rules.

NFR-010: Account deletion should be reliable and should avoid leaving orphaned user-owned data.

## 23. Current Limitations and Improvement Opportunities

The current implementation has several known limitations that can be included in a report as future work:

- Only Drawing appears selectable in onboarding while other hobbies are locked.
- Reroll records `lastRerollDate` but does not enforce cooldowns or limits.
- Quest completion and XP awarding are separate operations, which can be hardened with an idempotent XP ledger.
- Account deletion does not explicitly delete top-level guild posts authored by the user.
- Account deletion does not explicitly delete notification documents.
- Guild posts are loaded as a full collection rather than paginated.
- Peer review writes replace the full `peerReviews` map and can risk lost updates during simultaneous reviews.
- Demo guild seeding runs from controller initialization.
- Notification documents are written, but there is no notification inbox UI.
- Privacy enforcement is currently visible in UI logic; Firestore security rules should also enforce it.
- Category XP uses category names as map keys; category IDs would be safer for long-term data evolution.
- Streak calculation uses device-local dates and could be improved with timezone-aware server-side logic.

## 24. High-Level User Journey

1. The user opens the app.
2. The user signs in or registers.
3. If no profile exists, the user completes onboarding.
4. The user selects avatar, hobby, skill level, goal, and learning pace.
5. The app validates the goal and generates a quest blueprint.
6. The user accepts the plan.
7. The app creates profile, plan, milestones, quests, and goal history.
8. The user views active quests on the home page.
9. The user opens a quest, reflects, and optionally uploads evidence.
10. The app validates evidence when present.
11. The app completes the quest and awards XP.
12. The user's level, streak, category XP, and tree progress update.
13. The user may share the achievement to the guild.
14. Other users can react or submit peer reviews.
15. Guild activity can notify the post owner.
16. Over time, completed quests unlock milestones, growth letters, mature trees, and forest collection progress.

## 25. Report-Ready Feature List

The major features of HobbyQuest are:

- Firebase authentication with email/password and Google Sign-In.
- Profile-aware startup routing.
- Multi-step onboarding.
- Avatar and character-class selection.
- Firestore-backed hobby categories and review axes.
- AI-assisted goal validation.
- AI-generated four-milestone quest plan.
- AI-generated 20-node quest DAG for each milestone.
- Fallback plan and quest generation.
- Quest dependency unlocking.
- Quest detail and completion flow.
- Reflection-based quest completion.
- Photo evidence and AI image review.
- Image evidence upload.
- XP rewards by quest type.
- Bonus XP for approved image evidence.
- Level progression.
- Daily streak tracking.
- Global XP milestone rewards.
- Learning-plan milestone advancement.
- Quest reroll.
- YouTube tutorial search query support.
- Category XP tracking.
- Interactive tree growth.
- Mature tree naming.
- Forest collection.
- Tree renaming and repositioning.
- Weekly AI growth letters.
- Growth letter read/unread tracking.
- Growth letter sharing.
- Guild feed.
- Personalized guild sorting.
- Same-hobby and same-character filters.
- Guild post creation.
- Optional guild image upload.
- Quest achievement sharing.
- Guild reactions.
- One-time peer reviews.
- Hobby-specific peer review axes.
- Peer review stats and charts.
- Public profile viewing.
- User guild post history.
- Privacy controls for profile and post stats.
- Push notifications for guild reactions and reviews.
- Foreground notification snackbars.
- Notification tap deep linking.
- Profile editing.
- Notification preference management.
- Logout.
- Account deletion.
- Goal history.
- Help and support page.
