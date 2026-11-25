/**
 * Calm Hills Smart Home: push notifications for critical alerts (FCM).
 *
 * When the ESP32 writes a new alert state to the Realtime Database, these
 * functions send a push notification to every phone subscribed to the
 * "alerts" topic (the Flutter app subscribes after login).
 *
 * Deploy: npx firebase-tools deploy --only functions
 * (Cloud Functions needs the Firebase Blaze plan; usage here stays in the free tier.)
 */
const { onValueWritten } = require("firebase-functions/v2/database");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();

const INSTANCE = "calm-hills-smart-home-default-rtdb";
const TOPIC = "alerts";

async function notify(title, body, type) {
  await getMessaging().send({
    topic: TOPIC,
    notification: { title, body },
    data: { type },
    android: {
      priority: "high",
      notification: { channelId: "alerts", sound: "default" },
    },
  });
  logger.info(`pushed ${type}: ${title}`);
}

// Fire detected (false -> true)
exports.onFireAlert = onValueWritten(
  { ref: "/smartHome/fire/detected", instance: INSTANCE },
  async (event) => {
    const before = event.data.before.val();
    const after = event.data.after.val();
    if (after === true && before !== true) {
      await notify("🔥 Fire detected!", "The flame sensor detected fire. The alarm is sounding.", "fire");
    } else if (after === false && before === true) {
      await notify("Fire cleared", "The flame sensor no longer detects fire.", "fire_cleared");
    }
  },
);

// Rain started (false -> true): the clothes line closes itself
exports.onRainAlert = onValueWritten(
  { ref: "/smartHome/window/raining", instance: INSTANCE },
  async (event) => {
    const before = event.data.before.val();
    const after = event.data.after.val();
    if (after === true && before !== true) {
      await notify("🌧 It's raining", "The clothes line is closing automatically.", "rain");
    }
  },
);
