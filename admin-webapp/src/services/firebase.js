import { initializeApp, getApps, getApp } from "firebase/app";
import {
  getFirestore,
  collection,
  addDoc,
  getDocs,
  deleteDoc,
  doc,
  serverTimestamp,
  query,
  orderBy,
} from "firebase/firestore";
import { getStorage, ref, uploadBytes, getDownloadURL } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyBEhqM5KjIqSWFJx_sUbozulv4h6CN-jtg",
  authDomain: "flowa-4fca9.firebaseapp.com",
  projectId: "flowa-4fca9",
  storageBucket: "flowa-4fca9.firebasestorage.app",
  messagingSenderId: "124357149675",
  appId: "1:124357149675:web:344a0063f7468cdd448fae",
};

const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const storage = getStorage(app);

const categoryMap = {
  "Focus": "study",
  "Focus Ambient": "study",
  "Workout": "workout",
  "Gaming": "gaming",
  "Zen": "zen",
  "Motivation": "motivation",
  "Nasheed": "nasheed",
};

const coverEmojiMap = {
  "workout": "🏋️",
  "study": "📚",
  "gaming": "🎮",
  "zen": "🧘",
  "motivation": "⚡",
  "nasheed": "🌙",
};

/**
 * Uploads an MP3 audio file directly to Firebase Storage and saves metadata in Firestore `music_tracks`.
 */
export async function directUploadMusic({ audioFile, title, genre, ptsCost, audioUrl }) {
  let finalAudioUrl = audioUrl || "";

  if (audioFile) {
    const cleanFileName = audioFile.name.replace(/[^a-zA-Z0-9._-]/g, "_");
    const storagePath = `music/${Date.now()}_${cleanFileName}`;
    const storageRef = ref(storage, storagePath);

    const snapshot = await uploadBytes(storageRef, audioFile, {
      contentType: audioFile.type || "audio/mpeg",
    });
    finalAudioUrl = await getDownloadURL(snapshot.ref);
  }

  const category = categoryMap[genre] || "workout";
  const coverEmoji = coverEmojiMap[category] || "🎵";

  const trackDoc = {
    title: String(title).trim(),
    artist: "ODAT Audio",
    genre: String(genre || "Focus Ambient").trim(),
    category: category,
    durationSec: 180,
    audioUrl: finalAudioUrl,
    coverEmoji: coverEmoji,
    ptsCost: Number(ptsCost || 50),
    isActive: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, "music_tracks"), trackDoc);
  return { id: docRef.id, ...trackDoc };
}

/**
 * Lists all tracks from Firestore `music_tracks`.
 */
export async function directListMusic() {
  try {
    const q = query(collection(db, "music_tracks"), orderBy("createdAt", "desc"));
    const snap = await getDocs(q);
    return snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
    }));
  } catch (_) {
    // Fallback without ordering if index not yet generated
    const snap = await getDocs(collection(db, "music_tracks"));
    return snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
    }));
  }
}

/**
 * Deletes a track from Firestore `music_tracks`.
 */
export async function directDeleteMusic(trackId) {
  await deleteDoc(doc(db, "music_tracks", trackId));
  return true;
}
