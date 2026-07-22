# Firestore rules audit (working document)

This file records the access model used to generate the prototype rules. It is
intentionally untracked while the rules are being reviewed.

- `users/{uid}`: private profile and progression state. Owner-only client read
  and validated writes. Contains birth date and preferences, so it must never be
  readable by other users.
- `publicProfiles/{uid}`: nickname, avatar asset identifier, visibility flags,
  total XP, and update timestamp. Authenticated reads; owner writes must mirror
  the private profile using `getAfter()`.
- `users/{uid}/plans/{planId}` plus `milestones` and `quests`: owner-only plan
  data. Queries order milestones by `order`; growth-letter queries completed
  quests by `completedAt`.
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
- Orphaned user subcollections: access requires the parent user document.
- Category configuration tampering: client writes denied.

Auditor result:

```json
{
  "score": 4,
  "summary": "Private data ownership, schema limits, public/private profile separation, and server-owned guild engagement are enforced. Remaining risk is limited to a user falsifying their own progression through a modified client because quest and tree progression still use owner-authorized Firestore transactions.",
  "findings": [
    {
      "check": "Business Logic vs. Rules",
      "severity": "minor",
      "issue": "An owner can construct valid-looking XP or grove updates outside the official client within the validator bounds.",
      "recommendation": "Move quest completion and tree planting transactions fully into callable Functions, then lock their progression fields against direct client updates."
    }
  ]
}
```
