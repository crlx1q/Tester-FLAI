const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || 
  path.join(__dirname, '..', 'foodlensaipro-firebase-adminsdk-fbsvc-ccd8330dee.json');

let firebaseInitialized = false;

if (fs.existsSync(serviceAccountPath)) {
  try {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    firebaseInitialized = true;
    console.log('Firebase Admin SDK initialized');
  } catch (error) {
    console.error('Firebase Admin SDK init error:', error.message);
  }
} else {
  console.warn('Firebase service account not found at:', serviceAccountPath);
}

/**
 * Send push notification to a specific user
 * @param {string} fcmToken - User's FCM token
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Optional data payload
 */
async function sendPushNotification(fcmToken, title, body, data = {}) {
  if (!firebaseInitialized || !fcmToken) return false;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'meal_reminders',
          priority: 'high',
          defaultSound: true,
        },
      },
    });
    return true;
  } catch (error) {
    if (error.code === 'messaging/registration-token-not-registered' ||
        error.code === 'messaging/invalid-registration-token') {
      console.log('Invalid FCM token, should be removed');
    } else {
      console.error('Push notification error:', error.message);
    }
    return false;
  }
}

/**
 * Send push to multiple users
 * @param {Array<{fcmToken: string}>} users - Array of user objects with fcmToken
 * @param {string} title
 * @param {string} body
 * @param {object} data
 */
async function sendPushToMany(users, title, body, data = {}) {
  if (!firebaseInitialized) return;

  const tokens = users.filter(u => u.fcmToken).map(u => u.fcmToken);
  if (tokens.length === 0) return;

  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: {
        priority: 'high',
        notification: {
          channelId: 'meal_reminders',
          priority: 'high',
          defaultSound: true,
        },
      },
    });
  } catch (error) {
    console.error('Multicast push error:', error.message);
  }
}

module.exports = { sendPushNotification, sendPushToMany, firebaseInitialized };
