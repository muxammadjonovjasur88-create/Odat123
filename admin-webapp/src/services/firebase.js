import { initializeApp, getApps, getApp } from "firebase/app";
import {
  getFirestore,
  collection,
  addDoc,
  setDoc,
  getDocs,
  deleteDoc,
  updateDoc,
  doc,
  serverTimestamp,
  query,
  orderBy,
} from "firebase/firestore";
import {
  getStorage,
  ref,
  uploadBytes,
  uploadBytesResumable,
  getDownloadURL,
  deleteObject,
} from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyBEhqM5KjIqSWFJx_sUbozulv4h6CN-jtg",
  authDomain: "flowa-4fca9.firebaseapp.com",
  projectId: "flowa-4fca9",
  storageBucket: "flowa-4fca9.firebasestorage.app",
  messagingSenderId: "124357149675",
  appId: "1:124357149675:web:344a0063f7468cdd448fae",
};

import { getAuth } from "firebase/auth";

const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const auth = getAuth(app);

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
  "study": "🧠",
  "gaming": "🎮",
  "zen": "🌊",
  "motivation": "⚡",
  "nasheed": "🌙",
};

/**
 * Upload audio file to Firebase Storage with progress callback.
 * Returns the download URL.
 * @param {File} audioFile
 * @param {string} trackId - Firestore document ID (used as storage path)
 * @param {(progress: number) => void} [onProgress] - 0–100
 */
async function uploadAudioToStorage(audioFile, trackId, onProgress) {
  const ext = audioFile.name.split(".").pop() || "mp3";
  const storageRef = ref(storage, `music_tracks/${trackId}.${ext}`);
  const metadata = {
    contentType: audioFile.type || "audio/mpeg",
    cacheControl: "public, max-age=31536000",
  };

  return new Promise((resolve, reject) => {
    const task = uploadBytesResumable(storageRef, audioFile, metadata);
    task.on(
      "state_changed",
      (snap) => {
        if (onProgress) {
          const pct = Math.round((snap.bytesTransferred / snap.totalBytes) * 100);
          onProgress(pct);
        }
      },
      reject,
      async () => {
        try {
          const url = await getDownloadURL(task.snapshot.ref);
          resolve(url);
        } catch (e) {
          reject(e);
        }
      }
    );
  });
}

/**
 * @deprecated Use uploadAudioToStorage instead.
 * Legacy Firestore chunk approach — kept only for old track migration.
 */
export async function saveAudioBase64Chunks(trackDocRef, rawBase64) {
  const cleanBase64 = rawBase64.replace(/^data:audio\/\w+;base64,/, "").replace(/^data:application\/octet-stream;base64,/, "");
  const CHUNK_SIZE = 300 * 1024;
  const chunksCount = Math.ceil(cleanBase64.length / CHUNK_SIZE);
  const chunksCol = collection(trackDocRef, "audioChunks");

  for (let i = 0; i < chunksCount; i++) {
    const chunkData = cleanBase64.substring(i * CHUNK_SIZE, (i + 1) * CHUNK_SIZE);
    await setDoc(doc(chunksCol, `chunk_${String(i).padStart(4, "0")}`), {
      chunkIndex: i,
      data: chunkData,
    });
  }
}

/**
 * ──────────────────────────────────────────────────────────────────────────
 * 🎵 MUSIQA (MUSIC TRACKS) CRUD
 * ──────────────────────────────────────────────────────────────────────────
 */

/**
 * Upload new music track.
 * Audio is uploaded to Firebase Storage (fast, streamable).
 * @param {{ audioFile?: File, title: string, genre: string, ptsCost: number, audioUrl?: string }} param0
 * @param {(progress: number) => void} [onProgress]
 */
export async function directUploadMusic({ audioFile, title, genre, ptsCost, audioUrl }, onProgress) {
  const category = categoryMap[genre] || "workout";
  const coverEmoji = coverEmojiMap[category] || "🎵";

  // 1. Create Firestore doc first to get the ID for the storage path
  const trackDoc = {
    title: String(title).trim(),
    artist: "ODAT Audio",
    genre: String(genre || "Focus Ambient").trim(),
    category: category,
    durationSec: 180,
    audioUrl: audioUrl || "",
    coverEmoji: coverEmoji,
    ptsCost: Number(ptsCost || 50),
    isActive: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, "music_tracks"), trackDoc);

  // 2. Upload audio to Firebase Storage (fast, streamable, no Firestore chunks)
  if (audioFile) {
    try {
      const uploadedUrl = await uploadAudioToStorage(audioFile, docRef.id, onProgress);
      await updateDoc(docRef, { audioUrl: uploadedUrl, updatedAt: serverTimestamp() });
      trackDoc.audioUrl = uploadedUrl;
    } catch (err) {
      console.error("Audio upload error:", err);
    }
  }

  return { id: docRef.id, ...trackDoc };
}

export async function directUpdateMusic(trackId, { audioFile, title, artist, genre, ptsCost, audioUrl, category }, onProgress) {
  const cat = category || categoryMap[genre] || "workout";
  const coverEmoji = coverEmojiMap[cat] || "🎵";

  const updates = {
    title: String(title).trim(),
    artist: String(artist || "ODAT Audio").trim(),
    genre: String(genre || "Focus Ambient").trim(),
    category: cat,
    coverEmoji: coverEmoji,
    ptsCost: Number(ptsCost !== undefined ? ptsCost : 50),
    updatedAt: serverTimestamp(),
  };

  if (audioUrl) {
    updates.audioUrl = audioUrl;
  }

  // Upload new audio file if provided
  if (audioFile) {
    try {
      const uploadedUrl = await uploadAudioToStorage(audioFile, trackId, onProgress);
      updates.audioUrl = uploadedUrl;
    } catch (err) {
      console.error("Audio update upload error:", err);
    }
  }

  await updateDoc(doc(db, "music_tracks", trackId), updates);
  return { id: trackId, ...updates };
}

export async function directListMusic() {
  try {
    const q = query(collection(db, "music_tracks"), orderBy("createdAt", "desc"));
    const snap = await getDocs(q);
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (_) {
    const snap = await getDocs(collection(db, "music_tracks"));
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  }
}

export async function directDeleteMusic(trackId) {
  await deleteDoc(doc(db, "music_tracks", trackId));
  // Also try to remove the stored audio file (non-blocking)
  try {
    const storageRef = ref(storage, `music_tracks/${trackId}.mp3`);
    await deleteObject(storageRef);
  } catch (_) {}
  return true;
}

/**
 * ──────────────────────────────────────────────────────────────────────────
 * 🎧 AUDIO KITOBLAR (AUDIOBOOKS) CRUD
 * ──────────────────────────────────────────────────────────────────────────
 */
export async function directListAudiobooks() {
  try {
    const snap = await getDocs(collection(db, "audiobooks"));
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (err) {
    console.error("List audiobooks error:", err);
    return [];
  }
}

export async function directSaveAudiobook(audiobookData, audiobookId = null) {
  const cleanData = {
    title: String(audiobookData.title || "").trim(),
    author: String(audiobookData.author || "Muallif").trim(),
    narrator: String(audiobookData.narrator || "O‘zbekcha ovoz").trim(),
    durationMin: Math.max(1, parseInt(audiobookData.durationMin || 30, 10)),
    desc: String(audiobookData.desc || "").trim(),
    emoji: audiobookData.emoji || "🎧",
    audioUrl: String(audiobookData.audioUrl || "").trim(),
    telegramUrl: String(audiobookData.telegramUrl || "https://t.me/odat_fenix").trim(),
    updatedAt: serverTimestamp(),
  };

  if (audiobookId) {
    await updateDoc(doc(db, "audiobooks", audiobookId), cleanData);
    return { id: audiobookId, ...cleanData };
  } else {
    cleanData.createdAt = serverTimestamp();
    const docRef = await addDoc(collection(db, "audiobooks"), cleanData);
    return { id: docRef.id, ...cleanData };
  }
}

export async function directDeleteAudiobook(audiobookId) {
  await deleteDoc(doc(db, "audiobooks", audiobookId));
  return true;
}

/**
 * ──────────────────────────────────────────────────────────────────────────
 * 🛍️ DO'KON & SOVG'ALAR TO'G'RIDAN-TO'G'RI (Direct Shop Item CRUD)
 * ──────────────────────────────────────────────────────────────────────────
 */
export async function directCreateShopItem(itemData) {
  const cleanData = {
    title: String(itemData.title || "").trim(),
    description: String(itemData.description || "").trim(),
    pointsCost: Math.max(0, parseInt(itemData.pointsCost || 0, 10)),
    type: itemData.type || "gift",
    stock: itemData.stock !== null && itemData.stock !== undefined ? Math.max(0, parseInt(itemData.stock, 10)) : 10,
    imageUrl: String(itemData.imageUrl || "").trim(),
    partnerName: itemData.partnerName || "ODAT Do'koni",
    discountText: itemData.discountText || null,
    requiresShipping: itemData.type === "gift",
    isActive: itemData.isActive !== false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, "shopItems"), cleanData);
  return { id: docRef.id, ...cleanData };
}

export async function directUpdateShopItem(itemId, itemData) {
  const updates = {
    title: String(itemData.title || "").trim(),
    description: String(itemData.description || "").trim(),
    pointsCost: Math.max(0, parseInt(itemData.pointsCost || 0, 10)),
    type: itemData.type || "gift",
    stock: itemData.stock !== null && itemData.stock !== undefined ? Math.max(0, parseInt(itemData.stock, 10)) : 10,
    imageUrl: String(itemData.imageUrl || "").trim(),
    partnerName: itemData.partnerName || "ODAT Do'koni",
    discountText: itemData.discountText || null,
    requiresShipping: itemData.type === "gift",
    isActive: itemData.isActive !== false,
    updatedAt: serverTimestamp(),
  };

  await updateDoc(doc(db, "shopItems", itemId), updates);
  return { id: itemId, ...updates };
}

export async function directDeleteShopItem(itemId, hardDelete = false) {
  if (hardDelete) {
    await deleteDoc(doc(db, "shopItems", itemId));
  } else {
    await updateDoc(doc(db, "shopItems", itemId), {
      isActive: false,
      updatedAt: serverTimestamp(),
    });
  }
  return true;
}

/**
 * Upload file to Firebase Storage with resumable upload (supports progress).
 * @param {string} path - Storage path
 * @param {File} file
 * @param {string} contentType
 * @param {(pct: number) => void} [onProgress]
 */
async function uploadFileWithProgress(path, file, contentType, onProgress) {
  const storageRef = ref(storage, path);
  const metadata = {
    contentType: contentType || file.type || "application/octet-stream",
    cacheControl: "public, max-age=31536000",
  };
  return new Promise((resolve, reject) => {
    const task = uploadBytesResumable(storageRef, file, metadata);
    task.on(
      "state_changed",
      (snap) => {
        if (onProgress) {
          const pct = Math.round((snap.bytesTransferred / snap.totalBytes) * 100);
          onProgress(pct);
        }
      },
      reject,
      async () => {
        try {
          resolve(await getDownloadURL(task.snapshot.ref));
        } catch (e) {
          reject(e);
        }
      }
    );
  });
}

/**
 * Upload new book (cover image + PDF) to Firebase Storage with progress.
 * @param {object} bookData
 * @param {(stage: string, pct: number) => void} [onProgress]
 */
export async function directUploadBook(bookData, onProgress) {
  const b = bookData.book || bookData;
  let coverImageUrl = b.coverImageUrl || "";
  let pdfUrl = b.pdfUrl || "";

  // 1. Upload Cover Image to Firebase Storage
  if (bookData.coverFile) {
    try {
      onProgress?.("Muqova rasmi yuklanmoqda...", 5);
      coverImageUrl = await uploadFileWithProgress(
        `books/covers/${Date.now()}_${bookData.coverFile.name}`,
        bookData.coverFile,
        bookData.coverContentType || bookData.coverFile.type || "image/jpeg",
        (pct) => onProgress?.("Muqova rasmi yuklanmoqda...", Math.round(5 + pct * 0.2))
      );
    } catch (err) {
      console.error("Cover upload error:", err);
    }
  }

  // 2. Upload PDF to Firebase Storage with progress
  if (bookData.pdfFile) {
    try {
      onProgress?.("PDF fayli yuklanmoqda...", 25);
      pdfUrl = await uploadFileWithProgress(
        `books/pdfs/${Date.now()}_${bookData.pdfFile.name}`,
        bookData.pdfFile,
        "application/pdf",
        (pct) => onProgress?.("PDF fayli yuklanmoqda...", Math.round(25 + pct * 0.7))
      );
    } catch (err) {
      console.error("PDF upload error:", err);
    }
  }

  const bookDoc = {
    title: String(b.title || "").trim(),
    author: String(b.author || "").trim(),
    description: String(b.description || "").trim(),
    category: b.category || "Badiiy",
    pointsReward: Math.max(0, parseInt(b.pointsReward || 100, 10)),
    totalPages: b.totalPages || 100,
    coverImageUrl: coverImageUrl,
    pdfUrl: pdfUrl,
    isActive: b.isActive !== false,
    hasQuiz: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, "books"), bookDoc);
  return { id: docRef.id, ...bookDoc };
}

/**
 * ──────────────────────────────────────────────────────────────────────────
 * 📚 KITOBLAR TO'G'RIDAN-TO'G'RI YANGILASH (Direct Book Update)
 * ──────────────────────────────────────────────────────────────────────────
 */
export async function directUpdateBook(bookId, bookData, onProgress) {
  const b = bookData.book || bookData;
  let coverImageUrl = b.coverImageUrl || "";
  let pdfUrl = b.pdfUrl || "";

  // 1. Upload Cover Image to Firebase Storage if new file is selected
  if (bookData.coverFile) {
    try {
      onProgress?.("Muqova rasmi yuklanmoqda...", 5);
      coverImageUrl = await uploadFileWithProgress(
        `books/covers/${Date.now()}_${bookData.coverFile.name}`,
        bookData.coverFile,
        bookData.coverContentType || bookData.coverFile.type || "image/jpeg",
        (pct) => onProgress?.("Muqova rasmi yuklanmoqda...", Math.round(5 + pct * 0.2))
      );
    } catch (err) {
      console.error("Cover upload error during update:", err);
    }
  }

  // 2. Upload PDF to Firebase Storage if new file is selected
  if (bookData.pdfFile) {
    try {
      onProgress?.("PDF fayli yuklanmoqda...", 25);
      pdfUrl = await uploadFileWithProgress(
        `books/pdfs/${Date.now()}_${bookData.pdfFile.name}`,
        bookData.pdfFile,
        "application/pdf",
        (pct) => onProgress?.("PDF fayli yuklanmoqda...", Math.round(25 + pct * 0.7))
      );
    } catch (err) {
      console.error("PDF upload error during update:", err);
    }
  }

  const updates = {
    title: String(b.title || "").trim(),
    author: String(b.author || "").trim(),
    description: String(b.description || "").trim(),
    category: b.category || "O'zini rivojlantirish",
    pointsReward: Math.max(0, parseInt(b.pointsReward || 100, 10)),
    isActive: b.isActive !== false,
    coverImageUrl: coverImageUrl,
    pdfUrl: pdfUrl,
    updatedAt: serverTimestamp(),
  };

  await updateDoc(doc(db, "books", bookId), updates);
  return { id: bookId, ...updates };
}

