# Firestore rules audit (working document)

This file records the access model used to generate and review the prototype
rules.

- `users/{uid}`: private profile and progression state. Owner-only client read
  and validated writes. Contains birth date and preferences, so it must never be
  readable by other users.
- `publicProfiles/{uid}`: nickname, avatar asset identifier, visibility flags,
  total XP, and update timestamp. Authenticated reads; owner writes must mirror
  the private profile using `getAfter()`.
- `users/{uid}/plans/{planId}` plus `milestones` and `quests`: owner-only plan
  data. Queries order milestones by `order`; growth-letter queries completed
  quests by `completedAt`. Quest documents may omit `image_rubric` and
  `rubricAssessments` for legacy compatibility. When present, `image_rubric`
  must contain exactly three non-empty strings of at most 120 characters, and
  `rubricAssessments` must contain exactly three strict maps with only
  `criterion`, `met`, and `feedback`. Assessments are accepted only on a
  completed rubric-aware quest, and their criteria must match the stored rubric
  by index.
- `users/{uid}/tree/{treeId}`, `goalHistory`, and `growthLetters`: owner-only.
- `users/{uid}/notifications/{id}`: owner read/update/delete; Admin Functions
  create notification documents.
- `categories/{id}`: authenticated read, no client writes. Existing category
  seed data is treated as application configuration.
- `guild_posts/{postId}`: authenticated read; owner creates/deletes. Reactions
  and peer reviews now mutate only through callable Functions, so client update
  is denied.

Queries requiring explicit review:

- `guild_posts orderBy(createdAt desc)` and `where(userId == uid)` use automatic
  single-field indexes.
- `milestones orderBy(order)`, `tree orderBy(treeIndex)`, and growth-letter
  single-field filters/orders also use automatic indexes.
- The Admin SDK collection-group notification query bypasses client rules.

Attack review:

- Anonymous access: denied globally.
- Cross-user private profile/subcollection access: denied by UID ownership.
- Public-profile PII leak: avoided by splitting public fields from `users`.
- Public-profile spoofing: blocked by matching fields against the private user
  document after the batch.
- Guild reaction/review overwrite: client updates denied; callable Functions
  validate identity and perform transactions.
- Ownership hijack: guild `userId` must equal the authenticated UID and is never
  client-updatable.
- Schema pollution and oversized strings/maps: validators and allowed-key lists
  are applied on create and update paths.
- Rubric bypass and parser abuse: wrong list lengths, empty or oversized
  criteria, non-boolean `met` values, oversized feedback, and extra assessment
  keys are denied on both quest creation and update. Assessments attached to an
  incomplete or rubric-less quest, or renamed criteria, are also denied.
- Orphaned user subcollections: access requires the parent user document.
- Category configuration tampering: client writes denied.

Rubric-specific verification:

- Valid legacy quest documents and valid rubric-aware quest documents pass.
- Two-entry rubrics and criteria longer than 120 characters fail.
- Assessment maps with additional keys or non-boolean `met` values fail.
- Cross-user quest writes fail even when the quest schema is otherwise valid.
- No new query shape or Firestore index is introduced.
- Firebase CLI dry-run compiled `firestore.rules` successfully.
- Firestore emulator tests passed all four authorization/schema scenarios.

Auditor result:

```json
{
  "score": 4,
  "summary": "Private data ownership, strict rubric shape and size limits, public/private profile separation, and server-owned guild engagement are enforced. Legacy quests remain compatible. Remaining risk is limited to a user falsifying their own progression or rubric result through a modified client because quest completion and XP remain owner-authorized client transactions.",
  "findings": [
    {
      "check": "Business Logic vs. Rules",
      "severity": "minor",
      "issue": "An owner can construct valid-looking XP, grove, or rubric-assessment updates outside the official client within the validator bounds.",
      "recommendation": "Move quest completion and tree planting transactions fully into callable Functions, then lock their progression fields against direct client updates."
    }
  ]
}
```
