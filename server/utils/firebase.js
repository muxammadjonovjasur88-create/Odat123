const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { getMessaging } = require('firebase-admin/messaging');

if (!getApps().length) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    // Vercel dashboardida maxsus saqlanadi
    initializeApp({
      credential: cert(serviceAccount)
    });
  } catch (error) {
    console.error('Firebase initialization error:', error);
  }
}

const db = getFirestore();
const messaging = getMessaging();

// getStorage funksiyasi kerak bo'lganda bucket() chaqiriladi
module.exports = { db, messaging, getStorage, FieldValue };
