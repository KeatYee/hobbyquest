# Community Guild and Social Interaction

## Purpose

The Community Guild is HobbyQuest's social learning space. It lets users share progress, ask for advice, celebrate achievements, react to each other's posts, and give structured peer feedback.

The guild supports the core learning loop by making progress visible to other learners. Quests and growth letters are mostly private progression artifacts until the user chooses to share them. The guild turns those artifacts into social motivation, feedback, and accountability.

The current implementation centers on:

- A personalized guild feed.
- User-created posts.
- Optional image sharing.
- Achievement sharing after quest completion.
- Growth-letter sharing.
- Reactions.
- One-time peer reviews.
- Peer review stats.
- Public user profiles.
- User-specific guild post history.
- Push notifications for post reactions and reviews.
- Privacy controls for profile and post stats visibility.

## Functional Description

### 1. Guild Feed

The guild feed is the main community view. It appears as the Guild tab in the dashboard.

The feed shows guild posts with:

- Author avatar.
- Author nickname.
- Hobby.
- Relative post time.
- Post title.
- Post body.
- Optional image.
- Reaction buttons.
- Peer review button.
- Optional stats menu.

Posts are loaded from the global `guild_posts` collection. The feed can be personalized and filtered so users see content that is more relevant to their current learning context.

### 2. Feed Filters

The guild feed supports three filter modes:

| Filter | Behavior |
| --- | --- |
| For You | Sorts all posts by relevance to the current user. |
| Same Hobby | Shows posts whose hobby matches the current user's hobby. |
| Same Character | Shows posts from users with the same avatar character class. |

The "For You" feed is scored locally using:

- Same hobby: strongest match.
- Same category: medium match when hobby differs.
- Same avatar character class: weaker match.
- Creation time: tie-breaker, newest first.

If the app cannot resolve the user's hobby, the feed falls back to chronological sorting.

### 3. Creating a Guild Post

Users can create a post from the guild empty state, from quest completion sharing, or from growth-letter sharing.

A post includes:

- Hobby.
- Category ID.
- Title.
- Body.
- Optional image.
- Created timestamp.
- Empty reaction map.
- Empty peer review map.

The title and body are required. The image is optional.

If an image is selected, it is uploaded through `ImgBBService`, and the resulting URL is stored on the post.

After successful creation:

- The post is written to Firestore.
- Guild data is reloaded.
- The user sees a success message.

### 4. Sharing Quest Achievements

After a quest is completed, the quest detail controller asks whether the user wants to share the achievement with the guild.

If the user accepts:

- The guild post sheet opens.
- The title is prefilled as `Completed: {questTitle}`.
- The body is prefilled with the reflection note.
- The image evidence can be passed through as the initial image.
- The app tries to resolve the current hobby's category.

This sharing step is optional. Quest completion and XP rewards are already saved before the user decides whether to post.

### 5. Sharing Growth Letters

Growth letters can also be shared to the guild.

When the user chooses to add a growth letter to the guild:

- The app ensures guild categories are loaded.
- It resolves the user's hobby to a category.
- If no exact category match exists, it falls back to the first available category.
- The post dialog opens with growth-letter content prefilled.

This lets users turn weekly reflection into community-facing progress updates.

### 6. Reactions

Guild posts support three reaction types in the controller:

- Fire
- Clap
- Idea

Each reaction stores a list of user IDs who selected that reaction.

A user can toggle each reaction on or off. If the user has already reacted with a given reaction type, tapping it removes their ID. If they have not reacted, tapping it adds their ID.

When post stats are visible, reaction counts appear next to the reaction buttons. When stats are hidden, users can still react, but counts are not shown to viewers who are not allowed to see stats.

### 7. Peer Reviews

Peer reviews provide structured feedback on guild posts.

Each user can submit only one peer review per post. After submitting, the button changes to `Reviewed` and becomes disabled.

Peer reviews use sliders from 1 to 5. The axes are hobby-specific. For example:

- Painting can use axes such as Creativity, Technique, and Color Theory.
- Coding can use axes such as Code Quality, Efficiency, and Readability.
- Yoga can use axes such as Alignment, Flexibility, and Mindfulness.

If no hobby-specific axes are available, the app falls back to generic axes:

- Quality
- Effort
- Impact

Before submitting, the app shows a confirmation dialog explaining that the review can only be submitted once and cannot be changed or undone.

### 8. Peer Review Stats

When stats are visible, a post exposes a stats menu.

The stats dialog shows:

- Average ratings by axis.
- A radar chart when there are enough axes.
- A reviewed-by list with reviewer avatars and names.
- An empty state when no reviews exist.

Average ratings are computed locally from all peer reviews on the post.

### 9. Public Profiles

Users can open another user's public profile from a guild post author avatar.

The user profile page displays:

- Avatar.
- Nickname.
- User ID.
- Level.
- Total XP.
- XP to next level.
- Guild post count.

The profile respects privacy settings:

- If `profileVisible` is false and the viewer is not the profile owner, the page shows a private profile state.
- If `postStatsVisible` is false and the viewer is not the profile owner, public stats are hidden.

### 10. User Guild Posts Page

Users can open a list of all guild posts by a specific user.

The page:

- Loads the target user's profile.
- Checks profile visibility.
- Loads posts where `userId` matches the target user.
- Sorts posts newest first.
- Loads profiles for authors, reactors, and reviewers.
- Displays each post with optional image and metrics.

If the profile is private, the page shows a private state. If no posts exist, it shows an empty state.

### 11. Privacy Controls

The app provides two relevant privacy toggles:

| Setting | Field | Effect |
| --- | --- | --- |
| Profile visibility | `profileVisible` | Controls whether other users can view the public profile. |
| Post stats visibility | `postStatsVisible` | Controls whether other users can see reaction and review stats on guild posts. |

Owners can always see their own profile and stats.

When post stats visibility is changed, `ProfileController` also updates `GuildController.userPostStatsVisible` for the current user if the guild controller is registered.

### 12. Notifications

The backend creates notifications when another user reacts to or reviews a guild post.

The notification system ignores self-activity. If the post owner reacts to or reviews their own post, no notification is created for that activity.

Notification types:

- `post_reaction`
- `post_review`

Notifications are saved under the post owner's user document and can also be sent through Firebase Cloud Messaging when device tokens are available and notifications are enabled.

When the user taps a guild notification:

- The app opens the dashboard.
- The Guild tab is selected.
- The post ID is passed as an argument.
- The guild feed focuses that post visually.

### 13. Seeded Demo Content

`GuildController` currently seeds demo users and demo guild posts during initialization.

Seeded posts include:

- Example authors.
- Hobby and category mappings.
- Reaction maps.
- Peer review maps.
- Created dates.

The seeding code checks for existing posts by title before inserting, which helps avoid duplicate seeded posts.

This appears intended for development/demo data, but it runs from `GuildController.onInit`.

## Technical Implementation

### 1. Key Files

Client-side files:

- `lib/app/controllers/guild_controller.dart`
- `lib/app/models/guild_post_model.dart`
- `lib/app/models/category_model.dart`
- `lib/app/views/pages/guild_page.dart`
- `lib/app/views/dialogs/add_guild_post_dialog.dart`
- `lib/app/views/pages/user_profile_page.dart`
- `lib/app/views/pages/user_guild_posts_page.dart`
- `lib/app/views/pages/privacy_security_page.dart`
- `lib/app/controllers/profile_controller.dart`
- `lib/app/controllers/quest_detail_controller.dart`
- `lib/app/views/pages/growth_letter_page.dart`
- `lib/app/services/push_notification_service.dart`

Backend file:

- `functions/index.js`

### 2. Data Model

Guild posts are represented by `GuildPostModel`.

Fields:

```text
id: string
userId: string
hobby: string
categoryId: string
title: string
body: string
imageUrl: string
reactions: map<string, string[]>
peerReviews: map<string, map<string, number>>
createdAt: timestamp
```

Firestore path:

```text
guild_posts/{postId}
```

Example shape:

```text
guild_posts/{postId}
  userId: "abc123"
  hobby: "Painting"
  categoryId: "categoryDocId"
  title: "Completed: Color Mixing Practice"
  body: "I learned that warmer shadows need less black."
  imageUrl: "https://..."
  reactions:
    fire: ["uid1", "uid2"]
    clap: ["uid3"]
  peerReviews:
    reviewerUid:
      Creativity: 4.0
      Technique: 3.5
      Color Theory: 5.0
  createdAt: timestamp
```

In the current code, reaction keys are emoji strings rather than text labels.

### 3. Category and Review Axis Model

Categories are represented by `CategoryModel`.

Each category has:

- Firestore document ID.
- Name.
- Description.
- Icon code point.
- Optional icon font family.
- A list of hobbies.

Each hobby is a `HobbyEntry`:

```text
name: string
axes: PeerReviewAxisModel[]
```

Each peer review axis stores:

```text
label: string
iconCodePoint: number
iconFontFamily?: string
```

The guild uses `CategoryModel.getAxisForHobby(hobby)` to resolve the axes for peer review.

### 4. Controller State

`GuildController` owns the main guild state:

```text
posts: RxList<GuildPostModel>
categories: RxList<CategoryModel>
isLoading: RxBool
userAvatars: RxMap<String, String>
userNicknames: RxMap<String, String>
userPostStatsVisible: RxMap<String, bool>
selectedCategoryId: Rx<String?>
selectedFeedFilter: Rx<GuildFeedFilter>
userReactions: RxMap<String, Set<String>>
userPeerReviews: RxMap<String, Set<String>>
currentUserId: Rx<String?>
focusedPostId: Rx<String?>
```

The controller listens to Firebase Auth state changes. When the user changes, it:

- Updates `currentUserId`.
- Loads the current user's profile.
- Rebuilds local user reaction and review state from loaded posts.

### 5. Loading Guild Data

`GuildController.loadAllData()` loads:

1. All categories.
2. All guild posts ordered by `createdAt` descending.
3. User profiles for post authors.
4. User profiles for reviewers.

Loaded user data is cached into:

- `userAvatars`
- `userNicknames`
- `userPostStatsVisible`

After loading posts, `_populateCurrentUserState()` creates local maps that indicate:

- Which reactions the current user has selected for each post.
- Which posts the current user has reviewed.

### 6. Feed Filtering and Sorting

The selected filter is stored in:

```text
selectedFeedFilter
```

`visiblePosts` returns posts based on the selected filter:

- `forYou`: `sortedByRelevance`
- `sameHobby`: posts where post hobby matches current hobby.
- `sameCharacter`: posts where author avatar class matches current user's avatar class.

`sortedByRelevance` computes a score for each post:

```text
score = 0
if same hobby: score += 5
if same category and different hobby: score += 2
if same character class: score += 1
```

Posts are sorted by score descending, then `createdAt` descending.

If `focusedPostId` is set, the focused post is moved to the top of the sorted list when present.

### 7. Creating Posts

`AddGuildPostDialog` collects:

- Title.
- Body.
- Optional image.

It receives fixed `hobby` and `categoryId` from the caller.

Validation:

- Title must not be empty.
- Body must not be empty.

Submission calls:

```text
GuildController.addPost(...)
```

`addPost`:

1. Checks the current user.
2. Uploads the image through `ImgBBService` if provided.
3. Creates a `GuildPostModel`.
4. Adds it to `guild_posts`.
5. Reloads guild data.
6. Returns the new document ID.

### 8. Reactions

Reaction toggling is handled by:

```text
GuildController.toggleReaction(postId, reactionKey)
```

The method:

1. Checks the current user.
2. Finds the post in local state.
3. Checks whether the user already selected the reaction.
4. If selected, removes the user ID with `FieldValue.arrayRemove`.
5. If not selected, adds the user ID with `FieldValue.arrayUnion`.
6. Updates the local post reaction map.
7. Updates the local `userReactions` map.
8. Refreshes the post list.

Reaction storage:

```text
reactions.{reactionKey}: string[]
```

### 9. Peer Reviews

Peer review submission is handled by:

```text
GuildController.submitPeerReview(postId, hobby, ratings)
```

The method:

1. Checks the current user.
2. Verifies the user has not already reviewed the post.
3. Loads the current post document.
4. Copies the current `peerReviews` map.
5. Adds the current user's ratings.
6. Writes the whole `peerReviews` map back to Firestore.
7. Updates local post state.
8. Updates `userPeerReviews`.
9. Ensures the reviewer's profile is cached.

Peer review storage:

```text
peerReviews.{reviewerUid}.{axisLabel}: number
```

The UI initializes each slider at `3.0`, with a minimum of `1`, maximum of `5`, and four divisions.

### 10. Peer Review Averages

Average ratings are computed locally.

The algorithm:

1. Iterate through every review.
2. Add each axis rating into a totals map.
3. Count each axis occurrence.
4. Divide total by count.

Result:

```text
averageRatings[axis] = sum(axis ratings) / count(axis ratings)
```

The main guild page displays averages on a radar chart using the hobby's expected axes. The user guild posts page displays a radar chart when there are at least three axes and bar charts otherwise.

### 11. Profile and Privacy Implementation

Privacy fields live on the user document:

```text
profileVisible: boolean
postStatsVisible: boolean
notificationsEnabled: boolean
```

`ProfileController` updates privacy settings with Firestore merge writes.

`UserProfilePage` enforces:

- Private profile: show private state to other users.
- Hidden post stats: hide profile stats and guild post count from other users.

`GuildController.canViewPostStats(post)` returns true when:

```text
currentUserId == post.userId || userPostStatsVisible[post.userId] != false
```

The guild post card uses this to decide whether to show:

- Reaction counts.
- Stats menu.
- Peer review stats.

### 12. Notifications Backend

The Cloud Function is:

```text
notifyPostOwnerOnGuildPostActivity
```

Trigger:

```text
onDocumentUpdated("guild_posts/{postId}")
```

The function compares the before and after post data.

For reactions, it detects users newly added to any reaction list:

```text
getNewReactionEvents(before.reactions, after.reactions)
```

For peer reviews, it detects newly added reviewer IDs:

```text
getNewReviewEvents(before.peerReviews, after.peerReviews)
```

It filters out activity where the actor is the post owner.

For every remaining activity, it writes a notification to:

```text
users/{postOwnerId}/notifications/{notificationId}
```

Notification fields include:

```text
actorId
actorName
createdAt
guildPostPath
isRead
postId
postTitle
recipientId
title
body
type
reaction?
```

Notification document IDs are idempotent:

- Reaction: based on post ID, actor ID, and reaction key.
- Review: based on post ID and actor ID.

This prevents duplicate notification documents for the same user reaction type or review.

### 13. Push Notification Delivery

The Cloud Function sends FCM pushes to all recipient device tokens stored on the user document.

Token fields:

```text
fcmTokens: string[]
fcmToken?: string
fcmTokenUpdatedAt: timestamp
```

If `notificationsEnabled` is false, no tokens are returned and no push is sent.

Invalid FCM tokens are removed from the user document.

The push payload includes:

```text
type
postId
actorId
guildPostPath
```

### 14. Client Push Notification Handling

`PushNotificationService`:

- Requests notification permission.
- Registers the current device token.
- Saves tokens to the user document.
- Removes tokens when notifications are disabled or the user signs out.
- Handles token refresh.
- Displays foreground notifications as GetX snackbars.
- Handles notification taps.

When a guild notification is tapped, the service builds dashboard arguments:

```text
{
  tabIndex: 2,
  notificationType: type,
  postId: postId,
  actorId: actorId,
  guildPostPath: guildPostPath
}
```

The dashboard opens to the Guild tab. `GuildPage` reads the arguments, calls `focusPost(postId)`, and the feed highlights the post if it is present.

### 15. User Post History Implementation

`UserGuildPostsPage` loads one user's posts with:

```text
guild_posts.where("userId", isEqualTo: userId)
```

It sorts posts client-side by `createdAt` descending.

It also loads profiles for:

- The author.
- Reaction users.
- Reviewer users.

The page respects profile privacy. If another user attempts to view posts for a private profile, it shows a private state instead of the post list.

## Sequence Flows

### Create Post

```text
User
  opens AddGuildPostDialog
  enters title/body/image
AddGuildPostDialog
  validates required fields
  calls GuildController.addPost
GuildController
  uploads image if present
  adds GuildPostModel to guild_posts
  reloads guild data
AddGuildPostDialog
  closes sheet
  shows success dialog
```

### React To Post

```text
User
  taps reaction
GuildPostCard
  calls GuildController.toggleReaction
GuildController
  updates reactions.{reactionKey} with arrayUnion or arrayRemove
  updates local post state
Cloud Function
  detects newly added reaction user
  writes notification for post owner
  sends FCM push if enabled
```

### Submit Peer Review

```text
User
  taps Peer Review
GuildPage
  loads hobby review axes
  shows rating sliders
User
  confirms submit
GuildController
  checks one-review rule
  writes peerReviews.{uid}
  updates local state
Cloud Function
  detects newly added reviewer
  writes notification for post owner
  sends FCM push if enabled
```

### Open Notification

```text
User
  taps push notification
PushNotificationService
  extracts postId and notification type
  opens dashboard with tabIndex 2
Dashboard
  opens Guild tab
GuildPage
  focuses matching post
```

## Acceptance Criteria

A complete community guild implementation should satisfy:

- Guild feed loads categories and posts from Firestore.
- Guild feed shows loading and empty states.
- Users can filter by For You, Same Hobby, and Same Character.
- For You sorting prioritizes same hobby, same category, same character, then recency.
- Users can create a post with title and body.
- Empty title or body blocks post creation.
- Users can attach an optional image to a post.
- Successful post creation reloads the feed.
- Quest completion can prefill a guild post.
- Growth letters can prefill a guild post.
- Users can toggle each reaction type on and off.
- Reaction counts are visible only when post stats are viewable.
- Users can submit one peer review per post.
- Peer review axes match the post hobby when available.
- Peer review falls back to generic axes when needed.
- Peer review stats average ratings correctly.
- Post owners can view their own stats regardless of privacy settings.
- Other users cannot view stats when `postStatsVisible` is false.
- Other users cannot view a profile when `profileVisible` is false.
- Guild activity from other users creates owner notifications.
- Self-reactions and self-reviews do not create owner notifications.
- Notification taps open the Guild tab and focus the post.
- Disabling notifications removes or ignores device tokens.

## Current Limitations and Risks

Known limitations:

- Demo seeding runs from `GuildController.onInit`, which can be surprising in production.
- Guild posts are loaded as a full collection rather than paginated.
- User profile lookup for authors and reviewers is done with multiple individual reads.
- Peer review writes replace the full `peerReviews` map after reading it, which can risk lost updates if two users review at the same time.
- Reactions use Firestore update paths with emoji keys. This currently works for the seeded keys but can be fragile if arbitrary reaction keys are added.
- The UI prevents repeat reviews locally, but stronger protection should exist in security rules or a per-review subcollection.
- There is no moderation workflow for posts, images, reactions, or reviews.
- There is no delete UI shown on the main guild card, although `GuildController.deletePost` exists.
- Post creation uses `DateTime.now()` instead of `FieldValue.serverTimestamp()`.
- Push notification documents are created, but this codebase does not show a notification inbox page.
- The focused post only moves to the top if it is present in the currently loaded and filtered post list.

## Recommended Improvements

Recommended next steps:

- Move demo seeding behind a development flag or admin-only script.
- Add pagination or infinite scrolling for `guild_posts`.
- Use batched or cached profile loading for post authors, reactors, and reviewers.
- Store peer reviews in a subcollection such as `guild_posts/{postId}/peerReviews/{uid}` to avoid map overwrite races.
- Store reactions in a normalized structure if more reaction types are added.
- Add Firestore security rules enforcing one review per user per post.
- Add content moderation for post text and uploaded images.
- Add owner-only edit/delete UI for posts.
- Use server timestamps for post creation.
- Add a notification inbox that reads `users/{uid}/notifications`.
- Add unread notification badges for guild activity.
- Add report/block controls for community safety.
