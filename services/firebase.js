const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
let firebaseInitialized = false;

function getServiceAccount() {
  // Option 1: ENV variables (for hosting without JSON file)
  if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY) {
    return {
      type: process.env.FIREBASE_TYPE || 'service_account',
      project_id: process.env.FIREBASE_PROJECT_ID,
      private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
      private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      client_email: process.env.FIREBASE_CLIENT_EMAIL,
      client_id: process.env.FIREBASE_CLIENT_ID,
      auth_uri: process.env.FIREBASE_AUTH_URI || 'https://accounts.google.com/o/oauth2/auth',
      token_uri: process.env.FIREBASE_TOKEN_URI || 'https://oauth2.googleapis.com/token',
      auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_CERT_URL || 'https://www.googleapis.com/oauth2/v1/certs',
      client_x509_cert_url: process.env.FIREBASE_CLIENT_CERT_URL,
      universe_domain: 'googleapis.com',
    };
  }

  // Option 2: JSON file path
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || 
    path.join(__dirname, '..', 'foodlensaipro-firebase-adminsdk-fbsvc-ccd8330dee.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    return require(serviceAccountPath);
  }

  return null;
}

const serviceAccount = getServiceAccount();
if (serviceAccount) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    firebaseInitialized = true;
    console.log('Firebase Admin SDK initialized');
  } catch (error) {
    console.error('Firebase Admin SDK init error:', error.message);
  }
} else {
  console.warn('Firebase service account not found (no ENV vars and no JSON file)');
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
