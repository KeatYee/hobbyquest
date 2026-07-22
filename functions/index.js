const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const ACCOUNT_DELETION_REGION = "asia-southeast1";
const ACCOUNT_CLEANUP_CONCURRENCY = 20;
const MAX_ACCOUNT_DELETION_AUTH_AGE_SECONDS = 5 * 60;

setGlobalOptions({maxInstances: 10});

/**
 * Permanently delete the authenticated account and its application data.
 * Firestore cleanup happens first so a failed attempt can be safely retried.
 */
exports.deleteAccount = onCall(
    {
      memory: "512MiB",
      region: ACCOUNT_DELETION_REGION,
      timeoutSeconds: 540,
    },
    async (request) => {
      const uid = asTrimmedString(request.auth && request.auth.uid);

      if (!uid) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to delete your account.",
        );
      }

      if (!hasRecentAuthentication(request.auth.token)) {
        throw new HttpsError(
            "failed-precondition",
            "Please sign out, sign in again, and retry account deletion.",
        );
      }

      const userRef = db.collection("users").doc(uid);

      try {
        await userRef.set({
          accountDeletionInProgress: true,
          accountDeletionRequestedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        const guildCleanup = await cleanupGuildData(uid);
        const deletedNotifications = await deleteActorNotifications(uid);

        // recursiveDelete includes every current and future user subcollection.
        await db.recursiveDelete(userRef);

        // Keep Auth until cleanup succeeds so failures remain retryable.
        await deleteAuthUser(uid);

        logger.info("Account deleted.", {
          deletedGuildPosts: guildCleanup.deletedPosts,
          deletedNotifications,
          removedGuildReferences: guildCleanup.updatedPosts,
          uid,
        });

        return {deleted: true};
      } catch (error) {
        logger.error("Account deletion failed.", {error, uid});

        // Do not recreate a profile if recursive deletion already removed it.
        await userRef.update({
          accountDeletionInProgress: FieldValue.delete(),
          accountDeletionRequestedAt: FieldValue.delete(),
        }).catch((markerError) => {
          logger.warn("Could not clear account deletion marker.", {
            markerError,
            uid,
          });
        });

        throw new HttpsError(
            "internal",
            "Account deletion could not be completed. Please try again.",
        );
      }
    },
);

/**
 * Notify a post owner when another user reacts to or reviews their guild post.
 */
exports.notifyPostOwnerOnGuildPostActivity = onDocumentUpdated(
    "guild_posts/{postId}",
    async (event) => {
      if (!event.data) {
        logger.warn("Guild post update event had no document data.");
        return;
      }

      const postId = event.params.postId;
      const before = event.data.before.data() || {};
      const after = event.data.after.data() || {};
      const postOwnerId = asTrimmedString(after.userId);

      if (!postOwnerId) {
        logger.warn("Guild post has no userId; skipping notification.", {
          postId,
        });
        return;
      }

      const reactionEvents = getNewReactionEvents(
          before.reactions,
          after.reactions,
      );
      const reviewEvents = getNewReviewEvents(
          before.peerReviews,
          after.peerReviews,
      );
      const activities = [...reactionEvents, ...reviewEvents].filter(
          (activity) => activity.actorId !== postOwnerId,
      );

      if (activities.length === 0) {
        return;
      }

      await Promise.all(activities.map((activity) => {
        return writeNotification({
          activity,
          post: after,
          postId,
          postOwnerId,
        });
      }));

      logger.info("Guild post notifications written.", {
        count: activities.length,
        postId,
        postOwnerId,
      });
    },
);

/**
 * Find users newly added to any reaction list.
 * @param {unknown} beforeReactions Previous reactions map.
 * @param {unknown} afterReactions Updated reactions map.
 * @return {Array<{type: string, actorId: string, emoji: string}>}
 */
function getNewReactionEvents(beforeReactions, afterReactions) {
  const beforeMap = asObject(beforeReactions);
  const afterMap = asObject(afterReactions);
  const events = [];

  for (const [emoji, afterUsers] of Object.entries(afterMap)) {
    const beforeUsers = new Set(asStringArray(beforeMap[emoji]));
    for (const actorId of asStringArray(afterUsers)) {
      if (!beforeUsers.has(actorId)) {
        events.push({
          type: "post_reaction",
          actorId,
          emoji,
        });
      }
    }
  }

  return events;
}

/**
 * Find users newly added to the peerReviews map.
 * @param {unknown} beforeReviews Previous peer reviews map.
 * @param {unknown} afterReviews Updated peer reviews map.
 * @return {Array<{type: string, actorId: string}>}
 */
function getNewReviewEvents(beforeReviews, afterReviews) {
  const beforeMap = asObject(beforeReviews);
  const afterMap = asObject(afterReviews);
  const events = [];

  for (const actorId of Object.keys(afterMap)) {
    if (!beforeMap[actorId] && actorId.trim()) {
      events.push({
        type: "post_review",
        actorId,
      });
    }
  }

  return events;
}

/**
 * Write a single notification for the post owner.
 * @param {object} params Notification parameters.
 * @param {object} params.activity Activity that triggered the notification.
 * @param {object} params.post Updated guild post data.
 * @param {string} params.postId Guild post document ID.
 * @param {string} params.postOwnerId Recipient user ID.
 * @return {Promise<void>}
 */
async function writeNotification(params) {
  const {activity, post, postId, postOwnerId} = params;
  const [actorName, recipientCanReceive] = await Promise.all([
    getActorName(activity.actorId),
    canReceiveNotification(postOwnerId),
  ]);

  if (!actorName || !recipientCanReceive) {
    logger.info("Skipped notification for an account being deleted.", {
      actorId: activity.actorId,
      postId,
      postOwnerId,
    });
    return;
  }

  const notification = buildNotification({
    activity,
    actorName,
    post,
    postId,
    postOwnerId,
  });
  const notificationRef = db
      .collection("users")
      .doc(postOwnerId)
      .collection("notifications")
      .doc(getNotificationId(postId, activity));

  await notificationRef.set(notification);

  try {
    await sendPushNotification(postOwnerId, notification);
  } catch (error) {
    logger.warn("Failed to send guild activity push notification.", {
      error,
      postId,
      postOwnerId,
      type: notification.type,
    });
  }
}

/**
 * Check that the notification recipient still has an active profile.
 * @param {string} recipientId Recipient user ID.
 * @return {Promise<boolean>}
 */
async function canReceiveNotification(recipientId) {
  const snapshot = await db.collection("users").doc(recipientId).get();
  const data = snapshot.data() || {};
  return snapshot.exists && data.accountDeletionInProgress !== true;
}

/**
 * Send an FCM push notification to all known recipient device tokens.
 * @param {string} recipientId User ID to notify.
 * @param {object} notification Notification payload.
 * @return {Promise<void>}
 */
async function sendPushNotification(recipientId, notification) {
  const tokens = await getRecipientTokens(recipientId);

  if (tokens.length === 0) {
    logger.info("No FCM tokens found for notification recipient.", {
      recipientId,
      type: notification.type,
      postId: notification.postId,
    });
    return;
  }

  const invalidTokens = [];
  const chunks = chunk(tokens, 500);

  for (const tokenChunk of chunks) {
    const response = await admin.messaging().sendEachForMulticast({
      tokens: tokenChunk,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: notification.type,
        postId: notification.postId,
        actorId: notification.actorId,
        guildPostPath: notification.guildPostPath,
      },
      android: {
        priority: "high",
        notification: {
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    response.responses.forEach((result, index) => {
      if (!result.success && isInvalidTokenError(result.error)) {
        invalidTokens.push(tokenChunk[index]);
      }
    });
  }

  if (invalidTokens.length > 0) {
    await db.collection("users").doc(recipientId).update({
      fcmTokens: FieldValue.arrayRemove(...invalidTokens),
      fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
    });
  }
}

/**
 * Read FCM tokens saved on the recipient user profile.
 * @param {string} recipientId User ID to notify.
 * @return {Promise<string[]>}
 */
async function getRecipientTokens(recipientId) {
  const snapshot = await db.collection("users").doc(recipientId).get();
  const data = snapshot.data() || {};
  if (data.notificationsEnabled === false) {
    return [];
  }

  const tokenSet = new Set(asStringArray(data.fcmTokens));
  const singleToken = asTrimmedString(data.fcmToken);

  if (singleToken) {
    tokenSet.add(singleToken);
  }

  return [...tokenSet];
}

/**
 * Whether a send error means the token should be removed.
 * @param {FirebaseError|undefined} error Firebase Admin messaging error.
 * @return {boolean}
 */
function isInvalidTokenError(error) {
  if (!error) {
    return false;
  }

  return [
    "messaging/invalid-registration-token",
    "messaging/registration-token-not-registered",
  ].includes(error.code);
}

/**
 * Build notification payload saved for the recipient.
 * @param {object} params Notification build parameters.
 * @param {object} params.activity Activity that triggered the notification.
 * @param {string} params.actorName Display name for the actor.
 * @param {object} params.post Updated guild post data.
 * @param {string} params.postId Guild post document ID.
 * @param {string} params.postOwnerId Recipient user ID.
 * @return {object}
 */
function buildNotification(params) {
  const {activity, actorName, post, postId, postOwnerId} = params;
  const postTitle = truncate(
      asTrimmedString(post.title) || "your post",
      120,
  );
  const common = {
    actorId: activity.actorId,
    actorName,
    createdAt: FieldValue.serverTimestamp(),
    guildPostPath: `guild_posts/${postId}`,
    isRead: false,
    postId,
    postTitle,
    recipientId: postOwnerId,
  };

  if (activity.type === "post_reaction") {
    return {
      ...common,
      body: `${actorName} reacted ${activity.emoji} to your post.`,
      reaction: activity.emoji,
      title: "New reaction",
      type: activity.type,
    };
  }

  return {
    ...common,
    body: `${actorName} reviewed your post.`,
    title: "New review",
    type: activity.type,
  };
}

/**
 * Resolve an actor display name from their user profile.
 * @param {string} actorId User ID of the actor.
 * @return {Promise<string|null>}
 */
async function getActorName(actorId) {
  try {
    const snapshot = await db.collection("users").doc(actorId).get();
    const data = snapshot.data() || {};

    if (!snapshot.exists || data.accountDeletionInProgress === true) {
      return null;
    }

    return truncate(
        asTrimmedString(data.nickname) ||
        asTrimmedString(data.displayName) ||
        "Someone",
        80,
    );
  } catch (error) {
    logger.warn("Failed to load notification actor profile.", {
      actorId,
      error,
    });
    return "Someone";
  }
}

/**
 * Remove the user from all guild posts they authored or interacted with.
 * Each post uses a transaction so concurrent reactions are not overwritten.
 * @param {string} uid User ID to remove.
 * @return {Promise<{deletedPosts: number, updatedPosts: number}>}
 */
async function cleanupGuildData(uid) {
  const snapshot = await db.collection("guild_posts")
      .select("userId", "reactions", "peerReviews")
      .get();
  let deletedPosts = 0;
  let updatedPosts = 0;

  await forEachInChunks(snapshot.docs, ACCOUNT_CLEANUP_CONCURRENCY,
      async (post) => {
        const result = await db.runTransaction(async (transaction) => {
          const current = await transaction.get(post.ref);
          if (!current.exists) {
            return "unchanged";
          }

          const data = current.data() || {};
          if (asTrimmedString(data.userId) === uid) {
            transaction.delete(current.ref);
            return "deleted";
          }

          const reactions = removeUserFromReactions(data.reactions, uid);
          const reviews = removeUserFromReviews(data.peerReviews, uid);
          if (!reactions.changed && !reviews.changed) {
            return "unchanged";
          }

          const update = {};
          if (reactions.changed) {
            update.reactions = reactions.value;
          }
          if (reviews.changed) {
            update.peerReviews = reviews.value;
          }
          transaction.update(current.ref, update);
          return "updated";
        });

        if (result === "deleted") {
          deletedPosts += 1;
        } else if (result === "updated") {
          updatedPosts += 1;
        }
      });

  return {deletedPosts, updatedPosts};
}

/**
 * Require a fresh sign-in before this destructive operation.
 * Refreshing an ID token does not change its original authentication time.
 * @param {object} token Decoded Firebase Auth token.
 * @return {boolean}
 */
function hasRecentAuthentication(token) {
  const authTime = token && token.auth_time;
  if (typeof authTime !== "number" || !Number.isFinite(authTime)) {
    return false;
  }

  const ageSeconds = Math.floor(Date.now() / 1000) - authTime;
  return ageSeconds >= 0 &&
      ageSeconds <= MAX_ACCOUNT_DELETION_AUTH_AGE_SECONDS;
}

/**
 * Delete an Auth user, treating an already deleted identity as success.
 * This keeps concurrent/retried cleanup calls idempotent.
 * @param {string} uid User ID to delete.
 * @return {Promise<void>}
 */
async function deleteAuthUser(uid) {
  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    if (error && error.code === "auth/user-not-found") {
      return;
    }
    throw error;
  }
}

/**
 * Delete notifications in other accounts that identify this user as actor.
 * A collection-group query is preferred; older projects without its index
 * fall back to collection-scoped queries that use automatic indexes.
 * @param {string} uid Actor user ID.
 * @return {Promise<number>}
 */
async function deleteActorNotifications(uid) {
  try {
    const snapshot = await db.collectionGroup("notifications")
        .where("actorId", "==", uid)
        .select()
        .get();
    return deleteDocuments(snapshot.docs);
  } catch (error) {
    logger.warn(
        "Collection-group notification cleanup failed; using fallback.",
        {error, uid},
    );
  }

  const users = await db.collection("users").select().get();
  let deletedCount = 0;

  await forEachInChunks(users.docs, ACCOUNT_CLEANUP_CONCURRENCY,
      async (user) => {
        if (user.id === uid) {
          return;
        }

        const notifications = await user.ref.collection("notifications")
            .where("actorId", "==", uid)
            .select()
            .get();
        deletedCount += notifications.size;
        await deleteDocuments(notifications.docs);
      });

  return deletedCount;
}

/**
 * Delete documents with BulkWriter so the cleanup is not limited to 500 writes.
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} documents Documents.
 * @return {Promise<number>}
 */
async function deleteDocuments(documents) {
  if (documents.length === 0) {
    return 0;
  }

  const writer = db.bulkWriter();
  const writes = documents.map((document) => writer.delete(document.ref));
  await Promise.all([writer.close(), ...writes]);
  return documents.length;
}

/**
 * Remove a user ID from every list in a reaction map.
 * @param {unknown} value Reactions value.
 * @param {string} uid User ID to remove.
 * @return {{value: object, changed: boolean}}
 */
function removeUserFromReactions(value, uid) {
  const reactions = {...asObject(value)};
  let changed = false;

  for (const [emoji, users] of Object.entries(reactions)) {
    if (!Array.isArray(users) || !users.includes(uid)) {
      continue;
    }

    const remainingUsers = users.filter((userId) => userId !== uid);
    if (remainingUsers.length === 0) {
      delete reactions[emoji];
    } else {
      reactions[emoji] = remainingUsers;
    }
    changed = true;
  }

  return {value: reactions, changed};
}

/**
 * Remove a user's entry from a peer review map.
 * @param {unknown} value Peer reviews value.
 * @param {string} uid User ID to remove.
 * @return {{value: object, changed: boolean}}
 */
function removeUserFromReviews(value, uid) {
  const reviews = {...asObject(value)};
  const changed = Object.prototype.hasOwnProperty.call(reviews, uid);

  if (changed) {
    delete reviews[uid];
  }

  return {value: reviews, changed};
}

/**
 * Process items with bounded concurrency.
 * @param {Array<unknown>} items Items to process.
 * @param {number} size Maximum concurrent operations.
 * @param {function(unknown): Promise<void>} callback Item callback.
 * @return {Promise<void>}
 */
async function forEachInChunks(items, size, callback) {
  for (const itemChunk of chunk(items, size)) {
    await Promise.all(itemChunk.map(callback));
  }
}

/**
 * Create an idempotent notification document ID.
 * @param {string} postId Guild post document ID.
 * @param {object} activity Activity that triggered the notification.
 * @return {string}
 */
function getNotificationId(postId, activity) {
  const actorId = toIdPart(activity.actorId);

  if (activity.type === "post_reaction") {
    const emojiId = toIdPart(activity.emoji);
    return `${postId}_reaction_${actorId}_${emojiId}`;
  }

  return `${postId}_review_${actorId}`;
}

/**
 * Encode arbitrary text for use in a Firestore document ID segment.
 * @param {string} value Text to encode.
 * @return {string}
 */
function toIdPart(value) {
  return Buffer.from(value).toString("base64url");
}

/**
 * Convert a value to a plain object.
 * @param {unknown} value Value to normalize.
 * @return {object}
 */
function asObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  return value;
}

/**
 * Convert an array-like Firestore field to trimmed strings.
 * @param {unknown} value Value to normalize.
 * @return {string[]}
 */
function asStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
      .map((item) => asTrimmedString(item))
      .filter((item) => item.length > 0);
}

/**
 * Split an array into fixed-size chunks.
 * @param {Array<unknown>} items Items to split.
 * @param {number} size Maximum chunk size.
 * @return {Array<Array<unknown>>}
 */
function chunk(items, size) {
  const chunks = [];

  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }

  return chunks;
}

/**
 * Convert a value to a trimmed string.
 * @param {unknown} value Value to normalize.
 * @return {string}
 */
function asTrimmedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Truncate long strings for notification display fields.
 * @param {string} value Value to truncate.
 * @param {number} maxLength Maximum string length.
 * @return {string}
 */
function truncate(value, maxLength) {
  if (value.length <= maxLength) {
    return value;
  }

  return `${value.slice(0, maxLength - 3)}...`;
}
