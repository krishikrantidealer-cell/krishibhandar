/**
 * Production FCM Sender Function (2nd Gen)
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { DateTime } = require("luxon");

admin.initializeApp();

const TOPIC = "all_users";
const TZ = "Asia/Kolkata";

/**
 * 1. FIRESTORE TRIGGER: sendNotificationOnCreate
 * (Existing logic - DO NOT MODIFY)
 */
exports.sendNotificationOnCreate = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.warn("No data associated with the event");
    return;
  }

  const docId = event.params.notificationId;
  const docRef = snapshot.ref;

  const shouldProceed = await admin.firestore().runTransaction(async (transaction) => {
    const freshDoc = await transaction.get(docRef);
    const freshData = freshDoc.data();

    if (freshData.status && freshData.status !== "pending") {
      logger.info(`Notification ${docId} already in state: ${freshData.status}. Skipping.`);
      return false;
    }

    transaction.update(docRef, {
      status: "processing",
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return freshData;
  });

  if (!shouldProceed) return;

  const data = shouldProceed;

  try {
    const title = data.title;
    const body = data.body;
    const image = data.image;

    if (!title || typeof title !== "string" || title.trim() === "") {
      throw new Error("Invalid or missing 'title'");
    }
    if (!body || typeof body !== "string" || body.trim() === "") {
      throw new Error("Invalid or missing 'body'");
    }

    if (image && typeof image === "string") {
      if (!image.startsWith("https://")) {
        throw new Error("'image' must be a valid HTTPS URL");
      }
    }

    const message = {
      topic: TOPIC,
      data: {
        title: String(title),
        body: String(body),
        ...(image ? { image: String(image) } : {}),
      },
      android: {
        priority: "high",
      },
    };

    logger.info(`Sending FCM to topic ${TOPIC}`, message);
    const response = await admin.messaging().send(message);

    await snapshot.ref.update({
      status: "sent",
      messageId: response,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Successfully sent message ${response} for doc ${docId}`);

  } catch (error) {
    logger.error(`Error sending notification ${docId}:`, error);
    await snapshot.ref.update({
      status: "failed",
      error: error.message,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * 2. ADMIN CALLABLE: createQueuedNotification
 * Manually queue a notification from the Admin UI
 */
exports.admin_createQueuedNotification = onCall(async (request) => {
  // Security: Verify Admin Custom Claim
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Unauthorized access. Admin privileges required.");
  }

  const { title, body, image } = request.data;

  // Hardening: Validate title and body
  if (!title || typeof title !== "string" || title.trim() === "") {
    throw new HttpsError("invalid-argument", "Title must be a non-empty string.");
  }
  if (!body || typeof body !== "string" || body.trim() === "") {
    throw new HttpsError("invalid-argument", "Body must be a non-empty string.");
  }

  // Hardening: Validate image
  if (image) {
    if (typeof image !== "string" || !image.startsWith("https://")) {
      throw new HttpsError("invalid-argument", "Image URL must be a valid HTTPS URL.");
    }
  }

  try {
    const docRef = await admin.firestore().collection("notifications").add({
      title: title.trim(),
      body: body.trim(),
      image: image ? image.trim() : null,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: request.auth.uid,
      type: "manual",
    });

    return { success: true, id: docRef.id };
  } catch (error) {
    logger.error("Error creating queued notification:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * 3. ADMIN CALLABLE: saveScheduledNotification
 * Create or Update a recurring schedule
 */
exports.admin_saveScheduledNotification = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Unauthorized access.");
  }

  const { id, title, body, image, times, active } = request.data;

  // Hardening: Validate title and body
  if (!title || typeof title !== "string" || title.trim() === "") {
    throw new HttpsError("invalid-argument", "Title must be a non-empty string.");
  }
  if (!body || typeof body !== "string" || body.trim() === "") {
    throw new HttpsError("invalid-argument", "Body must be a non-empty string.");
  }

  // Hardening: Validate image
  if (image) {
    if (typeof image !== "string" || !image.startsWith("https://")) {
      throw new HttpsError("invalid-argument", "Image must be a valid HTTPS URL.");
    }
  }

  // Hardening: Validate times array
  if (!Array.isArray(times) || times.length === 0) {
    throw new HttpsError("invalid-argument", "Times must be a non-empty array.");
  }

  const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)$/;
  const validatedTimes = [];
  for (const t of times) {
    if (typeof t !== "string" || !timeRegex.test(t)) {
      throw new HttpsError("invalid-argument", `Invalid time format: ${t}. Expected HH:mm (24h).`);
    }
    validatedTimes.push(t);
  }

  // Remove duplicates and sort
  const normalizedTimes = [...new Set(validatedTimes)].sort();

  const scheduleData = {
    title: title.trim(),
    body: body.trim(),
    image: image ? image.trim() : null,
    times: normalizedTimes,
    active: active ?? true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
    frequency: "daily",
    timezone: TZ,
  };

  try {
    const coll = admin.firestore().collection("scheduled_notifications");
    if (id) {
      await coll.doc(id).update(scheduleData);
      return { success: true, id: id };
    } else {
      scheduleData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      scheduleData.lastRuns = {}; // Tracks { "HH:mm": timestamp }
      const docRef = await coll.add(scheduleData);
      return { success: true, id: docRef.id };
    }
  } catch (error) {
    logger.error("Error saving scheduled notification:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * 4. ADMIN CALLABLE: getScheduledNotifications
 * Fetch all schedules (excluding soft-deleted)
 */
exports.admin_getScheduledNotifications = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Unauthorized access.");
  }

  try {
    const snapshot = await admin.firestore()
      .collection("scheduled_notifications")
      .orderBy("updatedAt", "desc")
      .get();

    const schedules = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      // Only include if not soft-deleted
      if (!data.deletedAt) {
        schedules.push({
          id: doc.id,
          ...data,
          createdAt: data.createdAt?.toDate ? data.createdAt.toDate().toISOString() : null,
          updatedAt: data.updatedAt?.toDate ? data.updatedAt.toDate().toISOString() : null,
        });
      }
    });

    return schedules;
  } catch (error) {
    logger.error("Error fetching schedules:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * 5. ADMIN CALLABLE: deleteScheduledNotification
 * Soft delete a schedule
 */
exports.admin_deleteScheduledNotification = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Unauthorized access.");
  }

  const { id } = request.data;
  if (!id) {
    throw new HttpsError("invalid-argument", "Schedule ID is required.");
  }

  try {
    await admin.firestore().collection("scheduled_notifications").doc(id).update({
      active: false,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    });
    return { success: true };
  } catch (error) {
    logger.error("Error deleting schedule:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * 6. SCHEDULER: cron_checkSchedules
 * Runs every 5 minutes to trigger due schedules
 */
exports.cron_checkSchedules = onSchedule({
  schedule: "*/5 * * * *",
  timeZone: TZ,
  memory: "256MiB",
}, async (event) => {
  const now = DateTime.now().setZone(TZ);
  const todayStr = now.toFormat("yyyy-MM-dd");

  logger.info(`Running scheduler check at ${now.toISO()} for date ${todayStr}`);

  const snapshot = await admin.firestore()
    .collection("scheduled_notifications")
    .where("active", "==", true)
    .get();

  if (snapshot.empty) {
    logger.info("No active schedules found.");
    return;
  }

  const promises = [];

  snapshot.docs.forEach((doc) => {
    const schedule = doc.data();
    const docId = doc.id;

    // Hardening: Safely handle missing or invalid times field
    if (!Array.isArray(schedule.times) || schedule.times.length === 0) {
      logger.warn(`Schedule ${docId} has missing or invalid times array. Skipping.`);
      return;
    }

    schedule.times.forEach((slotTime) => {
      // Hardening: Skip invalid slot formats
      if (typeof slotTime !== "string" || !slotTime.includes(":")) {
        logger.warn(`Schedule ${docId} has invalid time slot format: ${slotTime}. Skipping slot.`);
        return;
      }

      // 1. Determine if this slot is "due" in the current 5-min window
      // SlotTime is "HH:mm". We create a DateTime for this slot today.
      const [hour, minute] = slotTime.split(":").map(Number);
      const slotDateTime = now.set({ hour, minute, second: 0, millisecond: 0 });

      // Window is [slotDateTime, slotDateTime + 5 mins)
      const diffMinutes = now.diff(slotDateTime, "minutes").minutes;

      // Only execute if now is within [0, 5) minutes AFTER the slot time
      if (diffMinutes >= 0 && diffMinutes < 5) {
        promises.push(processDueSchedule(doc.ref, schedule, slotTime, todayStr));
      } else {
        // logger.debug(`Schedule ${docId} slot ${slotTime} not in window (diff: ${diffMinutes}m).`);
      }
    });
  });

  await Promise.all(promises);
});

async function processDueSchedule(docRef, schedule, slotTime, todayStr) {
  const docId = docRef.id;

  return admin.firestore().runTransaction(async (transaction) => {
    const freshDoc = await transaction.get(docRef);
    const freshData = freshDoc.data();

    if (!freshData || !freshData.active) return;

    const lastRuns = freshData.lastRuns || {};
    const lastRunTimestamp = lastRuns[slotTime];

    // Idempotency: Verify it hasn't run today for this slot
    if (lastRunTimestamp) {
      const lastRunDate = DateTime.fromJSDate(lastRunTimestamp.toDate()).setZone(TZ).toFormat("yyyy-MM-dd");
      if (lastRunDate === todayStr) {
        // logger.info(`Schedule ${docId} for slot ${slotTime} already executed today.`);
        return;
      }
    }

    // Atomic Claim: Update lastRuns for this slot
    transaction.update(docRef, {
      [`lastRuns.${slotTime}`]: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create the actual notification document
    const notificationRef = admin.firestore().collection("notifications").doc();
    transaction.set(notificationRef, {
      title: freshData.title,
      body: freshData.body,
      image: freshData.image,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      type: "scheduled",
      scheduleId: docId,
      slotTime: slotTime,
    });

    logger.info(`Triggered scheduled notification for ${docId} (Slot: ${slotTime})`);
  });
}
