import admin from "firebase-admin";
import { readFile } from "fs/promises";

// Load service account securely from environment variables if in production,
// or fallback to the local JSON file during development.
let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } catch (error) {
    console.error("❌ Failed to parse FIREBASE_SERVICE_ACCOUNT environment variable:", error);
  }
}

if (!serviceAccount) {
  try {
    serviceAccount = JSON.parse(
      await readFile(new URL("./avd-3690-firebase-adminsdk-fbsvc-ef8f74fa07.json", import.meta.url))
    );
  } catch (error) {
    console.warn("⚠️ Warning: Local Firebase credentials file not found. Set FIREBASE_SERVICE_ACCOUNT env variable.");
  }
}

if (serviceAccount) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} else {
  console.warn("⚠️ Warning: Firebase Admin SDK is not initialized. Push notifications will be disabled until FIREBASE_SERVICE_ACCOUNT is configured.");
}

export const sendPushNotification = async (fcmToken, title, body, data = {}) => {
  try {
    // FCM requires all data values to be strings
    const stringData = {};
    Object.keys(data).forEach(key => {
      stringData[key] = String(data[key]);
    });

    // Add standard Flutter click action if not present
    if (!stringData.click_action) {
      stringData.click_action = "FLUTTER_NOTIFICATION_CLICK";
    }

    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          priority: "high",
          channelId: "high_importance_channel", // Matches common Flutter setups
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            contentAvailable: true, // Important for background processing
          },
        },
      },
      data: stringData,
    };

    const response = await admin.messaging().send(message);
    console.log("✅ Notification sent successfully:", response);
    return response;
  } catch (error) {
    console.error("❌ Error sending notification:", error);
    throw error;
  }
};

export default admin;
