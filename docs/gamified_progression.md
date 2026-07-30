# Gamified Progression

## Purpose

HobbyQuest uses gamified progression to make hobby learning feel visible, paced, and rewarding. The system converts completed learning actions into XP, levels, streaks, milestone advancement, category tree growth, and long-term forest collectibles.

The core loop is:

1. The learner completes an active quest.
2. The app records proof of effort through a reflection, and sometimes a photo.
3. The quest is marked complete in the active plan.
4. XP is awarded to the learner's global progression and the relevant hobby category.
5. The UI reacts with progress bars, level-up feedback, milestone feedback, tree growth, and optional guild sharing.
6. When a milestone's quests are complete, the next milestone generates a new quest set.
7. When a category tree reaches maturity, the learner names it and plants it in the forest.

This design gives users both short-term rewards, such as quest XP and progress bars, and long-term rewards, such as levels, streaks, completed milestones, and a growing forest.

## Functional Description

### 1. Player Identity and Starting State

During onboarding, the user creates a learner identity by choosing:

- Nickname
- Birth date
- Gender
- Avatar class and avatar image
- Hobby category
- Hobby
- Skill level
- Goal
- Learning pace

After the user accepts the generated plan, the app creates:

- A user profile document.
- An active quest plan.
- Four or more milestones for the plan.
- The first milestone's quest graph.
- Initial progression values.
- Per-category XP entries initialized to zero.

The initial progression state is:

- `totalXP = 0`
- `currentStreak = 0`
- `categoryXp.{categoryName} = 0` for each seeded category
- `currentMilestoneIndex = 0`
- All first-milestone quests are incomplete.

### 2. Quest Progression

Quests are the smallest progression unit. Each quest has:

- A unique node ID.
- A title and description.
- A list of steps.
- A quest type.
- A duration estimate.
- An XP reward.
- Dependency IDs.
- Completion state.
- Active or locked state.
- Optional image evidence and AI feedback metadata.

Quest types currently used by the UI are:

- `knowledge`: reading, watching, observing, or concept-building quests.
- `practice`: hands-on repetition or applied learning quests.
- `challenge`: proof-based quests that require a photo.

Quest cards expose XP as an explicit reward. On the detail screen, users can only complete a quest when:

- The quest is active.
- The quest is not already completed.
- The reflection text is at least 15 characters.
- If the quest type is `challenge`, a photo is attached.

If the quest includes a YouTube search query, the detail screen also lets the learner open a tutorial search.

### 3. Quest Graph and Unlocking

The active plan stores quests as a dependency graph. A quest can depend on one or more previous quest IDs.

A quest is considered ready when:

- It is not completed.
- It has no dependencies, or every dependency is already completed.

The home controller recomputes active states from the graph instead of trusting stale stored values. This allows the UI to show:

- Completed quests.
- Active quests whose dependencies are satisfied.
- Locked quests whose dependencies are not yet satisfied.

Completed quests are sorted ahead of active and locked quests so users can see their progress trail.

### 4. Quest Completion Requirements

A learner completes a quest from the quest detail screen.

The completion flow is:

1. The user writes a reflection.
2. The user optionally attaches a photo, unless the quest is a challenge quest where the photo is required.
3. If a photo is attached, the image is reviewed by Gemini before completion proceeds.
4. If Gemini rejects the photo, the quest is not completed and no XP is awarded.
5. If Gemini approves the photo, the image is uploaded and stored as quest evidence.
6. The quest is marked completed.
7. XP is awarded.
8. The user's visible quest graph is refreshed.
9. The user may share the achievement to the guild.

This makes XP an outcome of verified effort, not just tapping a button.

### 5. XP Rewards

Each quest has a base XP reward stored on the quest node.

The default reward is `100 XP` when no explicit quest reward exists. Gemini-generated quests can assign rewards by type.

A photo evidence bonus is currently implemented:

- `+50 XP` when a quest is completed with an approved uploaded image.

Total awarded XP for a completion is:

```text
totalQuestXP = quest.xpReward + optionalPhotoBonus
```

The app awards this XP to two places:

- Global user progression through `totalXP`.
- Category progression through `categoryXp.{categoryName}`.

Global XP drives account level. Category XP drives tree growth.

### 6. Global Levels

Global levels are derived from total lifetime XP.

The current formula is:

```text
level = floor(totalXP / 1000) + 1
currentXpInLevel = totalXP % 1000
levelProgress = currentXpInLevel / 1000
xpToNextLevel = 1000 - currentXpInLevel
```

Examples:

| Total XP | Level | Current XP In Level | XP To Next Level |
| --- | ---: | ---: | ---: |
| 0 | 1 | 0 | 1000 |
| 999 | 1 | 999 | 1 |
| 1000 | 2 | 0 | 1000 |
| 2450 | 3 | 450 | 550 |

When a quest pushes the user across a level boundary, the app stores a pending level-up state and later shows a dedicated level-up modal.

The level-up modal is intentionally delayed until after the quest detail page closes. This prevents stacked navigation conflicts and lets the reward moment appear cleanly after the completion action.

### 7. Streaks

The streak system tracks consecutive calendar days with at least one completed quest.

On quest completion, the app compares today's local date with `lastStreakDate`.

Streak behavior:

- If there is no previous streak date, the streak becomes `1`.
- If the last streak date is today, the streak remains unchanged.
- If the last streak date was yesterday, the streak increments by `1`.
- If the gap is more than one day, the streak resets to `1`.

The user document stores:

- `currentStreak`
- `lastStreakDate`

The profile page displays the current streak as an adventure stat.

### 8. Milestone XP Thresholds

The progression controller also checks global XP thresholds:

- `2000 XP`
- `4000 XP`
- `6000 XP`
- `8000 XP`

When a quest completion crosses one of these thresholds, the app shows a "Milestone Unlocked" modal.

This threshold system is separate from learning-plan milestones. Threshold milestones are global XP achievements, while learning-plan milestones are phases in the user's active hobby plan.

### 9. Learning-Plan Milestones

The active plan contains ordered milestones. Each milestone represents a phase of the user's goal.

Plan milestone progress is controlled by:

- `currentMilestoneIndex`
- The completion state of quests in the current milestone's quest graph.
- The ordered milestone list.

When all quests in the current milestone are completed and there is another milestone available:

1. The quest detail page detects milestone completion.
2. The app shows the milestone-complete screen.
3. After confirmation, the home controller advances to the next milestone.
4. The previous milestone is marked completed.
5. Gemini generates a new quest graph for the next milestone.
6. The new quest graph replaces the previous active quest set for the plan.
7. The user's home page refreshes with the next milestone's quests.

This separates skill progression from raw XP. XP rewards effort volume, while plan milestones represent structured goal progress.

### 10. Category Tree Growth

Each hobby belongs to a category, such as Creative Arts, Music & Performing, Lifestyle & Wellness, or Skill & Strategy.

When a quest is completed, the app resolves the current hobby's category and adds the awarded XP to that category's XP bucket.

Category XP drives tree growth on the map page.

Current tree stages:

| Stage | Label | Required Category XP | Asset |
| --- | --- | ---: | --- |
| 0 | Seed | 0 | `assets/images/seed.png` |
| 1 | Sprout | 100 | `assets/images/sprout.png` |
| 2 | Seedling | 300 | `assets/images/seedling.png` |
| 3 | Young Tree | 500 | `assets/images/young_tree.png` |
| 4 | Mature Tree | 800 | `assets/images/mature_tree.png` |

Tree progress is calculated between the current stage threshold and the next stage threshold.

Example:

```text
categoryXP = 420
stage = Seedling
currentStageMin = 300
nextStageMax = 500
progress = (420 - 300) / (500 - 300) = 0.60
xpToNext = 80
```

When a category has enough XP for a new stage, the tree does not instantly jump visually. The page shows a "Tap me to grow!" prompt so the user gets a tactile reward moment. Tapping the tree advances the displayed stage and triggers a shake animation.

When the tree reaches stage 4, the user can name the tree and save it to the forest.

### 11. Forest Collection

The forest is the long-term collection layer. A mature tree can be planted into the user's forest.

When the user saves a mature tree:

1. The app asks for a tree name.
2. It finds the first free forest spot.
3. It records a tree document in `users/{uid}/tree`.
4. It captures the user's completed quest count and total learning minutes from the current plan.
5. It stores the mature tree with metadata.
6. It resets the relevant `categoryXp.{categoryName}` value to `0`.
7. The learner can start growing a new tree in that category.

The forest page displays:

- A grid of planted trees.
- Empty planting spots.
- Total trees grown.
- Total XP represented by planted trees.
- Tree details such as name, XP required, growth date, quest count, and learning time.

Trees can be renamed and repositioned through drag-and-drop.

### 12. Profile and Public Stats

The profile page summarizes progression through:

- Level.
- Current XP within the level.
- XP progress bar.
- Total XP.
- Current streak.
- Guild post count.

Other user profile views also derive level and progress from `totalXP` using the same 1,000 XP per level formula.

### 13. Growth Letters

Growth letters are a reflective progression reward. They turn completed quests and written reflections into a weekly narrative summary.

A growth letter becomes available when:

- The user has an active plan.
- The user has completed at least one quest in the latest seven-day period.
- There is no unread growth letter already waiting.
- At least seven days have passed since the latest generated letter, unless an existing letter needs missing stats or insights backfilled.

Growth letters include:

- The hobby and nickname.
- A generated letter.
- Quest count.
- Reflection count.
- Weekly streak days.
- Completed quest IDs.
- Strongest growth area.
- Focus area.
- Suggested next-week focus.
- Period start and end dates.
- Read state.

This feature rewards consistency without adding more raw XP. It gives the learner a sense of narrative progress: "Here is what changed because you kept showing up."

Growth letters can also be shared to the guild, which connects private reflection with community encouragement.

### 14. Guild Sharing

After a successful quest completion, the app prompts the learner to share the achievement to the guild.

The sharing prompt is not required for progression. XP and quest completion are already saved before the guild prompt appears.

If the learner chooses to share:

- The post dialog is prefilled with the quest title.
- The reflection becomes the initial body.
- The image can be reused when present.
- The app attempts to resolve the hobby's guild category.

This turns private progression into an optional social reinforcement loop.

### 15. Guild Reactions, Peer Reviews, and Feed Relevance

The guild is a social gamification layer. It gives learners feedback loops beyond XP.

Guild posts support:

- Reactions from other users.
- One peer review per user per post.
- Hobby-specific peer review axes.
- Author avatars and nicknames.
- Public or hidden post stats based on privacy settings.

The guild feed can be filtered by:

- Personalized "for you" relevance.
- Same hobby.
- Same character class.

The relevance sort rewards affinity:

- Same hobby has the strongest weight.
- Same category is a medium signal.
- Same avatar character class is a weaker signal.
- Newer posts win tie-breakers.

Peer review axes come from the category model. For example, a painting post can be reviewed on painting-specific criteria, while a coding post can be reviewed on coding-specific criteria. If no hobby-specific axes are found, the app falls back to generic quality, effort, and impact axes.

This creates a second progression economy: reputation, feedback, and social proof. It does not currently award XP, but it motivates continued participation and makes completed quests feel visible.

### 16. Goal History

Goal history stores previous learning goals after onboarding or goal setup. This is not a reward system by itself, but it supports long-term progression by preserving the user's learning journey over time.

Goal history entries include:

- Hobby.
- Skill level.
- Goal.
- Learning pace.
- Category.
- Created date.

The profile page links to goal history so users can look back at earlier learning arcs.

## Technical Implementation

### 1. Main Classes

Key implementation files:

- `lib/app/controllers/progression_controller.dart`
- `lib/app/controllers/quest_detail_controller.dart`
- `lib/app/controllers/home_controller.dart`
- `lib/app/services/quest_service.dart`
- `lib/app/models/user_model.dart`
- `lib/app/models/quest_plan_model.dart`
- `lib/app/models/quest_node_model.dart`
- `lib/app/models/milestone_model.dart`
- `lib/app/models/tree_model.dart`
- `lib/app/views/pages/map_page.dart`
- `lib/app/views/pages/forest_page.dart`
- `lib/app/views/pages/profile_page.dart`

### 2. Source of Truth

The user document is the source of truth for account-level progression:

```text
users/{uid}
  totalXP: number
  currentStreak: number
  lastStreakDate: timestamp
  lastQuestCompletionDate: timestamp
  categoryXp: map<string, number>
  activePlanId: string
  mapTutorialDone: boolean
  updatedAt: timestamp
```

The active learning plan is stored under:

```text
users/{uid}/plans/{planId}
  id: string
  hobby: string
  level: string
  goal: string
  learningPace: string
  progress: number
  currentMilestoneIndex: number
  isActive: boolean
```

Plan milestones are stored under:

```text
users/{uid}/plans/{planId}/milestones/{milestoneId}
  id: string
  title: string
  task: string
  completed: boolean
  order: number
```

Plan quests are stored under:

```text
users/{uid}/plans/{planId}/quests/{questId}
  node_id: string
  title: string
  desc: string
  steps: string[]
  xp_reward: number
  type: string
  duration_minutes: number
  depends_on: string[]
  isCompleted: boolean
  isActive: boolean
  reflectionNote: string
  completedAt: timestamp
  imageUrl?: string
  greeting?: string
  observation?: string
  tip?: string
  youtube_search_query?: string
```

Planted forest trees are stored under:

```text
users/{uid}/tree/{treeId}
  treeName: string
  categoryId: string
  xpRequired: number
  treeIndex: number
  questsCompleted: number
  learningMinutes: number
  createdAt: timestamp
  grownAt: timestamp
```

Growth letters are stored under:

```text
users/{uid}/growthLetters/{letterId}
  uid: string
  planId: string
  hobby: string
  nickname: string
  letter: string
  questCount: number
  reflectionCount: number
  weeklyStreakDays: number
  questIds: string[]
  strongestGrowth: string
  focusArea: string
  nextWeekFocus: string
  hasPersonalizedInsights: boolean
  periodStart: timestamp
  periodEnd: timestamp
  createdAt: timestamp
  readAt?: timestamp
```

Guild posts are stored in the top-level collection:

```text
guild_posts/{postId}
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

### 3. Reactive State

The app uses GetX observables for local UI state.

`ProgressionController` exposes:

```text
totalXP: RxInt
streak: RxInt
categoryXp: RxMap<String, int>
isLoading: RxBool
```

Computed getters derive current level state:

```text
currentLevel
currentXpInLevel
levelProgress
xpToNextLevel
```

`HomeController` exposes the active user and quest list:

```text
user: Rx<UserModel?>
dailyQuests: RxList<QuestNodeModel>
hobby, goal, learningPace, level: RxString
hasAvailableGrowthLetter: RxBool
```

Pages such as the profile page, map page, and quest list observe these values and rebuild automatically.

### 4. Quest Completion Sequence

The technical quest completion sequence is coordinated by `QuestDetailController.completeQuest`.

High-level sequence:

```text
QuestDetailPage._completeQuest()
  -> QuestDetailController.completeQuest(reflectionNote, imageFile)
    -> optional Gemini image review
    -> optional ImgBB image upload
    -> QuestService.completeQuestTransaction(...)
    -> ProgressionController.completeQuest(...)
    -> refresh HomeController user and quest graph
    -> refresh growth letter availability
    -> prompt guild sharing
  -> close quest detail page
  -> ProgressionController.showPendingLevelUp()
  -> optional MilestoneCompleteScreen
```

The completion flow intentionally separates quest state and XP state:

- `QuestService.completeQuestTransaction` marks the quest completed.
- `ProgressionController.completeQuest` awards XP, updates streaks, and updates category XP.

This separation makes each part easier to reason about, but it also means the two writes are not currently part of one shared transaction. If quest completion succeeds and XP awarding fails, the quest could be complete without XP. A future hardening pass should combine these writes or add an idempotent completion ledger.

### 5. Quest Persistence

`QuestService.completeQuestTransaction` uses a Firestore transaction to:

- Read the user document.
- Resolve the active plan ID.
- Set the quest document fields:
  - `isCompleted = true`
  - `isActive = false`
  - `reflectionNote`
  - `completedAt`
  - Optional image URL and AI feedback fields
- Update the user document:
  - `updatedAt`
  - `lastQuestCompletionDate`

After the transaction, the service reloads:

- Plan metadata.
- Milestones.
- Quests.
- User profile.

It then returns a rebuilt `UserModel` with a fully populated `currentPlan`.

### 6. XP Award Transaction

`ProgressionController.completeQuest` uses a Firestore transaction on `users/{uid}`.

The transaction:

1. Reads the current user document.
2. Reads the current total XP, including legacy fallback fields.
3. Calculates `updatedXP = currentXP + xpReward`.
4. Calculates the new streak.
5. Reads the category XP map.
6. Adds XP to the resolved category.
7. Merges the updated fields back into the user document.

Updated user fields:

```text
totalXP
currentStreak
lastStreakDate
categoryXp
updatedAt
```

After the transaction, local reactive values are updated:

```text
totalXP.value = updatedXP
streak.value = updatedStreak
categoryXp[resolvedCategory] += xpReward
```

The controller then checks:

- Whether the level increased.
- Whether any global XP thresholds were crossed.

### 7. Category Resolution

If the caller does not provide a category name, `ProgressionController` resolves the current category using the current hobby from `HomeController`.

Resolution order:

1. Exact hobby match against category hobby names.
2. Partial category or hobby-name match.
3. Fallback to the first loaded category.

The category data comes from `CategoryService.getCategories()`.

This keeps quest completion code simple but introduces a dependency on category data quality. If a hobby cannot be matched correctly, category XP can be assigned to the fallback category.

### 8. Level-Up Detection

The controller compares the previous level with the new level:

```text
previousLevel = floor(previousXP / 1000) + 1
newLevel = floor(updatedXP / 1000) + 1
```

If `newLevel > previousLevel`, it stores:

```text
_pendingLevelUpLevel = newLevel
```

The quest detail page later calls:

```text
ProgressionController.showPendingLevelUp()
```

This shows `LevelUpScreen(newLevel: level)` through `Get.generalDialog`.

### 9. Milestone Threshold Detection

Global XP milestone detection runs after each XP award:

```text
for threshold in [2000, 4000, 6000, 8000]:
  if previousXP < threshold && updatedXP >= threshold:
    show milestone modal
```

This supports multiple threshold crossings from one large XP reward, although normal quest rewards are small.

### 10. Plan Milestone Advancement

`HomeController.hasCompletedMilestone` returns true when:

- The active plan exists.
- Every quest in the current plan's quest list is completed.
- There is another milestone after the current one.

`HomeController.advanceToNextMilestone`:

1. Reads the current user, active plan, and plan ID.
2. Computes `nextIndex = currentMilestoneIndex + 1`.
3. Marks the current milestone completed.
4. Uses Gemini to generate a new phase quest graph for the next milestone.
5. Calls `QuestService.addQuestsToPlan`.
6. Updates local user and quest state.

`QuestService.addQuestsToPlan` writes:

- New quest documents.
- Milestone documents.
- Updated plan metadata.
- Updated `activePlanId` on the user document.

### 11. Tree Growth Implementation

The map page reads category XP directly from `ProgressionController.categoryXp`.

For the selected category:

```text
xp = categoryXp[category.name] ?? 0
thresholds = [0, 100, 300, 500, 800]
labels = [Seed, Sprout, Seedling, Young Tree, Mature Tree]
```

The actual stage is the highest threshold less than or equal to the category XP.

The page maintains separate display state:

```text
_displayedStage
_displayedStageCategory
```

This allows delayed visual growth. If the actual stage is higher than the displayed stage, the tree shows a tap prompt. Tapping increments `_displayedStage` by one and starts the shake animation.

If the category switches, the displayed stage is reset to that category's actual stage. If XP regresses after saving a tree, the displayed stage syncs downward.

### 12. Saving a Mature Tree

When a tree reaches the mature stage, the map page calls `_showTreeNamingDialog`.

After the user enters a valid name, `_saveTreeToForest`:

1. Loads existing tree documents.
2. Finds the first free `treeIndex`.
3. Reads the current plan from the user document.
4. Counts completed quests.
5. Sums completed quest duration.
6. Creates a `TreeModel`.
7. Adds it to `users/{uid}/tree`.
8. Resets `categoryXp.{categoryName}` to `0`.
9. Updates local `ProgressionController.categoryXp`.

The tree's `xpRequired` is currently stored as `800`, matching the mature tree threshold.

### 13. Forest Display Implementation

The forest page listens to:

```text
users/{uid}/tree.orderBy('treeIndex').snapshots()
```

It maps each tree document into a `TreeModel` and places it into a nine-slot grid.

The page supports:

- Viewing tree details.
- Renaming a tree.
- Dragging a tree onto another tree to swap positions.
- Dragging a tree into an empty spot.

Forest summary stats are derived from the snapshot:

```text
treesGrown = count(tree.grownAt != null)
totalXp = sum(tree.xpRequired)
```

### 14. Growth Letter Implementation

`GrowthLetterService` handles growth-letter availability, generation, reuse, read state, and cleanup.

Availability is checked by:

```text
GrowthLetterService.checkGrowthLetterAvailability(uid, planId)
```

The service returns available when:

- There is an unread latest letter, or
- The latest letter is at least seven days old and the user completed quests in the latest seven-day period.

Generation is handled by:

```text
GrowthLetterService.generateWeeklyGrowthLetter(user)
```

The service:

1. Resolves the active user and plan.
2. Defines a seven-day period.
3. Reuses the latest letter if a new one is not allowed yet.
4. Loads completed quests for the period.
5. Calculates weekly streak days from distinct quest completion dates.
6. Extracts up to eight non-empty reflections.
7. Calls Gemini to generate a narrative letter and insight fields.
8. Saves the letter under `users/{uid}/growthLetters`.

`GrowthLetterController` loads or writes the letter when the page opens, then marks the current letter as read and syncs the dashboard unread state.

`HomeController` watches the latest growth letter and keeps `hasAvailableGrowthLetter` current. After quest completion, the quest detail controller refreshes growth-letter availability.

### 15. Guild Social Feedback Implementation

`GuildController` manages guild posts, reactions, peer reviews, profile lookups, and feed relevance.

Reaction state is stored inline on the post document:

```text
reactions.{reactionKey}: string[]
```

Toggling a reaction:

1. Checks the current user.
2. Reads the local post state.
3. Uses `FieldValue.arrayUnion` or `FieldValue.arrayRemove`.
4. Updates the local `posts` list and `userReactions` map.

Peer reviews are also stored inline:

```text
peerReviews.{reviewerUid}.{axisLabel}: rating
```

Submitting a peer review:

1. Checks that the user has not already reviewed the post.
2. Fetches the post's current `peerReviews` map.
3. Adds the current user's ratings.
4. Writes the whole peer review map back to Firestore.
5. Updates local `posts` and `userPeerReviews`.

Review axes are resolved from category data by hobby. If no axes are found, the controller uses default axes.

Feed relevance is computed locally by scoring posts against the current user's hobby, category, and avatar character class, then sorting by score and creation date.

### 16. Goal History Implementation

`GoalHistoryService.saveGoalHistory` is called during onboarding after the accepted plan is saved. The entry captures the user's chosen category, hobby, skill level, goal, and learning pace.

Goal history is stored under the user document's goal-history subcollection and is deleted during account deletion.

### 17. Legacy Compatibility

The progression model includes legacy fallback support.

If `totalXP` is absent, the app derives total XP from older fields:

```text
legacyTotalXP = ((level - 1) * 1000) + currentXp
```

`UserModel` also supports legacy category XP fields formatted like:

```text
categoryXp.Creative Arts: 100
```

and converts them into:

```text
categoryXp: {
  "Creative Arts": 100
}
```

This reduces breakage for users created before the current flat progression model.

### 18. Data Consistency Considerations

Current safeguards:

- Quest completion uses a Firestore transaction.
- XP awarding uses a Firestore transaction.
- Category XP updates are derived from the transaction snapshot.
- The quest graph's active state is recomputed locally from dependencies.
- Level is derived from total XP, so there is no separate level field to keep in sync.
- Tree collection stats are derived from tree documents.

Known risks and recommended hardening:

- Quest completion and XP awarding are separate operations. Add an idempotent completion ledger or combine both writes in one transaction to prevent double XP or missing XP.
- `questId` is passed into `ProgressionController.completeQuest` but is not currently used for idempotency.
- Streaks use device-local `DateTime.now()`. For stronger consistency, compute streak dates from server timestamps or a normalized user timezone.
- `dailyQuestCompletionCount` exists on `UserModel` but is not currently updated in the progression controller.
- Category resolution falls back to the first category, which can misattribute XP when categories are missing or hobby names do not match.
- Saving a mature tree reads `currentPlan` from the user document, but plan quests now live in subcollections. This can undercount completed quests and learning minutes unless the user document has a denormalized `currentPlan.quests` array.
- The map page writes `categoryXp.${category.name}`. Category names containing dots or reserved path characters would be unsafe as Firestore update paths. Current seeded category names avoid this, but a safer implementation would use category IDs as map keys or `FieldPath`.

## Acceptance Criteria

A complete gamified progression flow should satisfy these behaviors:

- A new user starts at level 1 with 0 XP and 0 streak.
- Completing an active quest marks only that quest completed.
- Locked quests become active when their dependencies are completed.
- Completing a quest adds its XP reward to `totalXP`.
- Completing a quest adds the same XP to the matching `categoryXp` bucket.
- Completing a quest with approved photo evidence adds the 50 XP bonus.
- Rejected photo evidence blocks completion and awards no XP.
- Crossing each 1,000 XP boundary triggers a level-up modal.
- Completing multiple quests on the same day does not increment the streak more than once.
- Completing quests on consecutive days increments the streak.
- Missing a day resets the streak to 1 on the next completion.
- Crossing 2,000, 4,000, 6,000, or 8,000 total XP shows a global milestone modal.
- Completing all quests in a plan milestone shows the milestone-complete screen.
- Advancing a milestone generates and stores the next quest graph.
- Category tree stages update at 100, 300, 500, and 800 category XP.
- A mature tree can be named and planted in the forest.
- Planting a tree resets that category's XP to 0.
- The forest displays planted trees, stats, and tree details.
- A growth letter becomes available after completed quest activity in an eligible seven-day period.
- Opening a growth letter marks it as read and clears the dashboard unread state.
- A completed quest can be shared to the guild without affecting XP state.
- Guild posts can receive reactions.
- Guild posts can receive one peer review per user.
- Peer review axes match the post hobby when category data is available.
- Guild post stats respect user privacy settings.

## Future Enhancements

Possible future improvements:

- Add an XP ledger collection with one immutable record per XP grant.
- Make quest completion idempotent with `questId` and `completedAt`.
- Store progression events for analytics and debugging.
- Add achievements for streak lengths, category mastery, and guild participation.
- Add variable level curves instead of a flat 1,000 XP per level.
- Add category-specific levels in addition to tree stages.
- Use category IDs instead of display names as `categoryXp` keys.
- Replace device-local streak calculation with timezone-aware server-side logic.
- Show a detailed post-quest reward summary with base XP, bonus XP, total XP, level progress, streak result, and tree progress.
