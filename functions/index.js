const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

setGlobalOptions({maxInstances: 10});

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
  const actorName = await getActorName(activity.actorId);
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
 * @return {Promise<string>}
 */
async function getActorName(actorId) {
  try {
    const snapshot = await db.collection("users").doc(actorId).get();
    const data = snapshot.data() || {};
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
