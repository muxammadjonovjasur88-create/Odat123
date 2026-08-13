const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging } = require('firebase-admin/messaging');

if (!getApps().length) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    // Vercel dashboardida maxsus saqlanadi
    initializeApp({
      credential: cert(serviceAccount),
    });
  } catch (error) {
    console.error('Firebase initialization error:', error);
  }
}

const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

module.exports = { db, auth, getAuth, messaging, FieldValue };
