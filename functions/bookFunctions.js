import { HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { createClient } from "@supabase/supabase-js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { createRequire } from "module";
import { assertAdminAuth } from "./telegramAdminAuth.js";

const require = createRequire(import.meta.url);

/**
 * Validates PDF file parameters: buffer size, MIME type / header signature.
 */
export function validateBookPdfFile(contentType, bufferLength, bufferSignature) {
  if (contentType && contentType !== "application/pdf" && !contentType.includes("pdf")) {
    throw new Error("Faqat PDF formatidagi fayllar yuklanishi mumkin.");
  }
  const MAX_SIZE = 200 * 1024 * 1024; // 200MB
  if (bufferLength > MAX_SIZE) {
    throw new Error("PDF fayl hajmi 200MB dan oshmasligi kerak.");
  }
  if (bufferSignature && !bufferSignature.startsWith("%PDF-")) {
    throw new Error("Fayl formati yaroqsiz PDF fayl (PDF signaturasi topilmadi).");
  }
  return true;
}

/**
 * Validates cover image parameters for books.
 */
export function validateBookCoverImage(contentType, bufferLength) {
  const allowed = ["image/jpeg", "image/png", "image/webp"];
  if (contentType && !allowed.includes(contentType)) {
    throw new Error("Faqat JPG, PNG yoki WEBP rasmlari yuklanishi mumkin.");
  }
  const MAX_SIZE = 5 * 1024 * 1024; // 5MB
  if (bufferLength > MAX_SIZE) {
    throw new Error("Muqova rasm hajmi 5MB dan oshmasligi kerak.");
  }
  return true;
}

/**
 * Extracts text and total pages from a PDF Buffer using pdf-parse.
 */
export async function extractPdfTextAndPages(buffer) {
  try {
    const { PDFParse } = require("pdf-parse");
    const parser = new PDFParse({ data: buffer });
    const result = await parser.getText();
    const text = typeof result.text === "string" ? result.text.trim() : "";
    const totalPages = typeof result.total === "number" && result.total > 0 ? result.total : 1;
    return { text, totalPages };
  } catch (err) {
    console.warn("pdf-parse text extraction warning:", err.message);
    return { text: "", totalPages: 1 };
  }
}

/**
 * Truncates or samples very long book text for Gemini prompt token efficiency.
 */
export function prepareTextForGemini(text) {
  const trimmed = String(text || "").replace(/\s+/g, " ").trim();
  if (trimmed.length <= 35000) {
    return trimmed;
  }

  // Sample start, middle, and end of the book
  const part1 = trimmed.slice(0, 15000);
  const midStart = Math.floor(trimmed.length / 2) - 5000;
  const part2 = trimmed.slice(midStart, midStart + 10000);
  const part3 = trimmed.slice(trimmed.length - 10000);

  return `${part1}\n\n[... MATN QISQARTIRILDI ...]\n\n${part2}\n\n[... MATN QISQARTIRILDI ...]\n\n${part3}`;
}

/**
 * Builds Gemini prompt for 10 quiz questions.
 */
export function buildBookQuizPrompt(bookTitle, bookAuthor, textContent) {
  return `
Sen professional ta'lim mutaxassisisan. Quyida taqdim etilgan kitob matni bo'yicha foydalanuvchi bilmini sinash uchun aynan 10 TA TEST SAVOLI (multiple-choice quiz) tayyorla.

KITOB MA'LUMOTLARI:
- Sarlavha: "${bookTitle}"
- Muallif: "${bookAuthor || "Noma'lum"}"

KITOB MATNI (QISMAN/TO'LIQ):
"""
${textContent}
"""

TALABLAR VA QOIDALAR:
1. Aynan 10 ta test savoli yaratilishi shart.
2. Har bir savol kitob mazmuni va undagi muhim g'oyalar, voqealar yoki tushunchalarga asoslangan bo'lishi kerak.
3. Har bir savol uchun aynan 4 ta variant (options) berilishi kerak.
4. Javob variantlari mantiqiy, mazmunli va bir-biridan farqli bo'lsin.
5. "correctAnswerIndex" 0, 1, 2 yoki 3 bo'lishi shart (0 - birinchi variant, 1 - ikkinchi variant va h.k.).
6. Barcha matnlar O'zbek tilida (lotin yozuvida) bo'lishi kerak.
7. FAQAT KELTIRILGAN JSON STRUKTURASIDA JAVOB BER. Boshqa hech qanday qo'shimcha matn yozma.

JSON STRUKTURASI:
{
  "questions": [
    {
      "question": "Savol matni...",
      "options": [
        "1-variant",
        "2-variant",
        "3-variant",
        "4-variant"
      ],
      "correctAnswerIndex": 0
    }
  ]
}
`.trim();
}

/**
 * Parses and strictly validates Gemini JSON quiz response.
 */
export function parseAndValidateQuizResponse(rawJsonStr) {
  let parsed;
  try {
    parsed = JSON.parse(rawJsonStr);
  } catch (e) {
    const match = rawJsonStr.match(/\{[\s\S]*\}/);
    if (match) {
      parsed = JSON.parse(match[0]);
    } else {
      throw new Error("Gemini javobidan yaroqli JSON topilmadi.");
    }
  }

  if (!parsed || !Array.isArray(parsed.questions) || parsed.questions.length === 0) {
    throw new Error("Gemini JSON javobida 'questions' massivi topilmadi.");
  }

  if (parsed.questions.length < 10) {
    throw new Error(`Gemini ${parsed.questions.length} ta savol qaytardi, lekin 10 ta talab qilingan.`);
  }

  const validQuestions = parsed.questions.slice(0, 10).map((q, idx) => {
    const questionText = typeof q.question === "string" ? q.question.trim() : "";
    const options = Array.isArray(q.options) ? q.options.map((o) => String(o).trim()) : [];
    let correctIdx = parseInt(q.correctAnswerIndex, 10);
    if (isNaN(correctIdx) || correctIdx < 0 || correctIdx > 3) {
      correctIdx = 0;
    }

    if (!questionText || options.length !== 4 || options.some((opt) => !opt)) {
      throw new Error(`Savol #${idx + 1} formati noto'g'ri (savol matni va 4 ta variant bo'lishi shart).`);
    }

    return {
      question: questionText,
      options: options,
      correctAnswerIndex: correctIdx,
    };
  });

  return validQuestions;
}

/**
 * Calculates quiz score and points earned based on book's pointsReward.
 */
export function calculateQuizScore(userAnswers, questions, pointsReward = 100) {
  const totalQuestions = questions ? questions.length : 0;
  if (totalQuestions === 0) {
    return { score: 0, totalQuestions: 0, pointsEarned: 0 };
  }

  let score = 0;
  for (let i = 0; i < totalQuestions; i++) {
    const userAns = userAnswers && userAnswers[i] !== undefined ? parseInt(userAnswers[i], 10) : -1;
    if (userAns === questions[i].correctAnswerIndex) {
      score++;
    }
  }

  const reward = Math.max(0, parseInt(pointsReward, 10) || 100);
  const pointsEarned = Math.round((score / totalQuestions) * reward);

  return {
    score,
    totalQuestions,
    pointsEarned,
  };
}

/**
 * Calculates book reading progress status.
 */
export function calculateBookProgressStatus(currentPage, totalPages) {
  const cur = Math.max(1, parseInt(currentPage || 1, 10));
  const tot = Math.max(1, parseInt(totalPages || 1, 10));
  const isCompleted = cur >= tot;
  return {
    currentPage: cur,
    totalPages: tot,
    status: isCompleted ? "completed" : "reading",
    isCompleted,
  };
}

/**
 * Helper to upload buffer to Firebase Cloud Storage.
 */
async function uploadToFirebaseStorage(filePath, buffer, contentType) {
  let defaultBucketName = null;
  try {
    const defaultBucket = getStorage().bucket();
    if (defaultBucket && defaultBucket.name) {
      defaultBucketName = defaultBucket.name;
    }
  } catch (e) {
    // ignore
  }

  const candidateBuckets = Array.from(
    new Set(
      [
        defaultBucketName,
        "flowa-4fca9.firebasestorage.app",
        "flowa-4fca9.appspot.com",
        process.env.GCP_PROJECT ? `${process.env.GCP_PROJECT}.appspot.com` : null,
        process.env.GCP_PROJECT ? `${process.env.GCP_PROJECT}.firebasestorage.app` : null,
      ].filter(Boolean)
    )
  );

  for (const bucketName of candidateBuckets) {
    try {
      const bucket = getStorage().bucket(bucketName);
      const file = bucket.file(filePath);
      await file.save(buffer, {
        metadata: { contentType },
        public: true,
        resumable: false,
      });
      try {
        await file.makePublic();
      } catch (e) {
        // Ignore if ACL/rules handle public access
      }
      return `https://storage.googleapis.com/${bucketName}/${filePath}`;
    } catch (err) {
      console.warn(`Firebase Storage upload attempt for bucket ${bucketName} failed:`, err.message);
    }
  }
  return null;
}

/**
 * Helper to upload buffer to Supabase Storage with bucket fallback.
 */
async function uploadToSupabase(supabaseUrl, supabaseKey, primaryBucket, filePath, buffer, contentType) {
  if (!supabaseKey || !supabaseUrl) {
    return null;
  }
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);

    let bucket = primaryBucket;
    let { error } = await supabase.storage
      .from(bucket)
      .upload(filePath, buffer, {
        contentType: contentType,
        upsert: true,
      });

    if (error && bucket !== "shop-items") {
      bucket = "shop-items";
      const res = await supabase.storage
        .from(bucket)
        .upload(filePath, buffer, {
          contentType: contentType,
          upsert: true,
        });
      error = res.error;
    }

    if (error) {
      console.warn("Supabase upload error:", error.message);
      return null;
    }

    const { data: publicData } = supabase.storage
      .from(bucket)
      .getPublicUrl(filePath);

    return publicData?.publicUrl || null;
  } catch (err) {
    console.warn("Supabase network/upload failed:", err.message);
    return null;
  }
}

/**
 * Helper to split a large base64 string into 300KB chunks and save to Firestore subcollection.
 * CHUNK_SIZE = 300 * 1024 (307,200 chars), strictly below Firestore's 1MB single field limit.
 */
async function saveBase64Chunks(db, subcollectionRef, base64String) {
  const CHUNK_SIZE = 300 * 1024;
  const chunksCount = Math.ceil(base64String.length / CHUNK_SIZE);

  const oldSnap = await subcollectionRef.get();
  if (!oldSnap.empty) {
    const deleteBatch = db.batch();
    oldSnap.forEach((doc) => deleteBatch.delete(doc.ref));
    await deleteBatch.commit();
  }

  const batchSize = 400;
  for (let i = 0; i < chunksCount; i += batchSize) {
    const batch = db.batch();
    const end = Math.min(i + batchSize, chunksCount);
    for (let j = i; j < end; j++) {
      const chunkData = base64String.substring(j * CHUNK_SIZE, (j + 1) * CHUNK_SIZE);
      const chunkRef = subcollectionRef.doc(`chunk_${String(j).padStart(4, "0")}`);
      batch.set(chunkRef, {
        chunkIndex: j,
        data: chunkData,
      });
    }
    await batch.commit();
  }
}

// ============================================================================
// HANDLER FUNCTIONS
// ============================================================================

export const adminUploadBookHandler = async (db, request, secrets) => {
  const { botToken, supabaseUrl, supabaseKey } = secrets;
  const initData = request.data?.initData;
  const adminUser = await assertAdminAuth(db, initData, botToken);

  const bookData = request.data?.book || {};
  const base64Pdf = request.data?.base64Pdf;
  const pdfFileName = request.data?.pdfFileName || `book_${Date.now()}.pdf`;
  const base64Cover = request.data?.base64Cover;
  const coverFileName = request.data?.coverFileName || `cover_${Date.now()}.jpg`;
  const coverContentType = request.data?.coverContentType || "image/jpeg";

  if (!bookData.title) {
    throw new HttpsError("invalid-argument", "Kitob sarlavhasi kiritilishi shart.");
  }

  const bookId = request.data?.bookId;
  const docRef = bookId ? db.collection("books").doc(bookId) : db.collection("books").doc();
  const existingDoc = bookId ? await docRef.get() : null;
  const existingData = existingDoc?.exists ? existingDoc.data() : {};

  let pdfUrl = bookData.pdfUrl || existingData.pdfUrl || "";
  let extractedTotalPages = parseInt(bookData.totalPages || 0, 10);

  if (base64Pdf) {
    const cleanBase64Pdf = base64Pdf.replace(/^data:application\/pdf;base64,/, "");
    const pdfBuffer = Buffer.from(cleanBase64Pdf, "base64");
    const bufferSig = pdfBuffer.toString("utf8", 0, 5);

    try {
      validateBookPdfFile("application/pdf", pdfBuffer.length, bufferSig);
    } catch (err) {
      throw new HttpsError("invalid-argument", err.message);
    }

    const { text, totalPages } = await extractPdfTextAndPages(pdfBuffer);
    if (!extractedTotalPages || extractedTotalPages < 1) {
      extractedTotalPages = totalPages;
    }

    const pdfPath = `pdfs/${Date.now()}_${pdfFileName}`;
    let uploadedUrl = await uploadToSupabase(supabaseUrl, supabaseKey, "books", pdfPath, pdfBuffer, "application/pdf");
    if (!uploadedUrl) {
      uploadedUrl = await uploadToFirebaseStorage(pdfPath, pdfBuffer, "application/pdf");
    }

    if (uploadedUrl) {
      pdfUrl = uploadedUrl;
    } else if (bookData.pdfUrl && bookData.pdfUrl.startsWith("http") && !bookData.pdfUrl.includes("getBookPdf")) {
      pdfUrl = bookData.pdfUrl;
    } else if (cleanBase64Pdf.length < 300000) {
      pdfUrl = `data:application/pdf;base64,${cleanBase64Pdf}`;
    } else {
      await saveBase64Chunks(db, docRef.collection("pdfChunks"), cleanBase64Pdf);
      pdfUrl = `https://us-central1-flowa-4fca9.cloudfunctions.net/getBookPdf?bookId=${docRef.id}`;
    }
  }

  if (!pdfUrl) {
    throw new HttpsError("invalid-argument", "PDF fayl yuklanmadi va pdfUrl taqdim etilmadi.");
  }

  let coverImageUrl = bookData.coverImageUrl || existingData.coverImageUrl || "";
  if (base64Cover) {
    const cleanCover = base64Cover.replace(/^data:image\/\w+;base64,/, "");
    const coverBuffer = Buffer.from(cleanCover, "base64");
    try {
      validateBookCoverImage(coverContentType, coverBuffer.length);
    } catch (err) {
      throw new HttpsError("invalid-argument", err.message);
    }

    const coverPath = `covers/${Date.now()}_${coverFileName}`;
    let uploadedUrl = await uploadToSupabase(supabaseUrl, supabaseKey, "books", coverPath, coverBuffer, coverContentType);
    if (!uploadedUrl) {
      uploadedUrl = await uploadToFirebaseStorage(coverPath, coverBuffer, coverContentType);
    }

    if (uploadedUrl) {
      coverImageUrl = uploadedUrl;
    } else if (bookData.coverImageUrl && bookData.coverImageUrl.startsWith("http") && !bookData.coverImageUrl.includes("getBookPdf")) {
      coverImageUrl = bookData.coverImageUrl;
    } else if (cleanCover.length < 300000) {
      coverImageUrl = `data:${coverContentType};base64,${cleanCover}`;
    } else {
      await saveBase64Chunks(db, docRef.collection("coverChunks"), cleanCover);
      await docRef.collection("coverChunks").doc("meta").set({ contentType: coverContentType }, { merge: true });
      coverImageUrl = `https://us-central1-flowa-4fca9.cloudfunctions.net/getBookPdf?bookId=${docRef.id}&type=cover`;
    }
  }

  const newBook = {
    title: String(bookData.title).trim(),
    author: String(bookData.author || "").trim(),
    description: String(bookData.description || "").trim(),
    category: String(bookData.category || "Shaxsiy rivojlanish").trim(),
    pointsReward: Math.max(0, parseInt(bookData.pointsReward || 100, 10)),
    totalPages: Math.max(1, extractedTotalPages || existingData.totalPages || 1),
    coverImageUrl: String(coverImageUrl || existingData.coverImageUrl || "").trim(),
    pdfUrl: String(pdfUrl || existingData.pdfUrl || "").trim(),
    isActive: bookData.isActive !== false,
    createdAt: existingData.createdAt || FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    uploadedBy: existingData.uploadedBy || String(adminUser.id),
  };

  await docRef.set(newBook, { merge: true });

  await db.collection("auditLogs").add({
    action: "upload_book",
    bookId: docRef.id,
    adminTelegramId: String(adminUser.id),
    timestamp: FieldValue.serverTimestamp(),
    details: { title: newBook.title, author: newBook.author },
  });

  return { success: true, id: docRef.id, book: { id: docRef.id, ...newBook } };
};

export const adminListBooksHandler = async (db, request, secrets) => {
  const { botToken } = secrets;
  const initData = request.data?.initData;
  await assertAdminAuth(db, initData, botToken);

  const [booksSnap, quizzesSnap] = await Promise.all([
    db.collection("books").get(),
    db.collection("bookQuizzes").get(),
  ]);

  const quizBookIds = new Set(quizzesSnap.docs.map((doc) => doc.id));

  const books = booksSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    hasQuiz: quizBookIds.has(doc.id),
  }));

  return { success: true, books };
};

export const adminUpdateBookHandler = async (db, request, secrets) => {
  const { botToken } = secrets;
  const initData = request.data?.initData;
  const bookId = request.data?.bookId;
  const bookData = request.data?.book;
  const adminUser = await assertAdminAuth(db, initData, botToken);

  if (!bookId || !bookData) {
    throw new HttpsError("invalid-argument", "bookId va book ma'lumotlari taqdim etilishi kerak.");
  }

  const docRef = db.collection("books").doc(bookId);
  const existing = await docRef.get();
  if (!existing.exists) {
    throw new HttpsError("not-found", "Kitob topilmadi.");
  }

  const updates = {
    ...bookData,
    updatedAt: FieldValue.serverTimestamp(),
    lastModifiedBy: String(adminUser.id),
  };

  delete updates.id;
  delete updates.createdAt;

  await docRef.update(updates);

  await db.collection("auditLogs").add({
    action: "update_book",
    bookId: bookId,
    adminTelegramId: String(adminUser.id),
    timestamp: FieldValue.serverTimestamp(),
  });

  return { success: true };
};

export const adminDeleteBookHandler = async (db, request, secrets) => {
  const { botToken } = secrets;
  const initData = request.data?.initData;
  const bookId = request.data?.bookId;
  const hardDelete = request.data?.hardDelete === true;
  const adminUser = await assertAdminAuth(db, initData, botToken);

  if (!bookId) {
    throw new HttpsError("invalid-argument", "bookId taqdim etilishi kerak.");
  }

  const docRef = db.collection("books").doc(bookId);

  if (hardDelete) {
    const pdfSnap = await docRef.collection("pdfChunks").get();
    if (!pdfSnap.empty) {
      const deleteBatch = db.batch();
      pdfSnap.forEach((doc) => deleteBatch.delete(doc.ref));
      await deleteBatch.commit();
    }
    const coverSnap = await docRef.collection("coverChunks").get();
    if (!coverSnap.empty) {
      const deleteBatch = db.batch();
      coverSnap.forEach((doc) => deleteBatch.delete(doc.ref));
      await deleteBatch.commit();
    }
    await docRef.delete();
  } else {
    await docRef.update({
      isActive: false,
      updatedAt: FieldValue.serverTimestamp(),
      lastModifiedBy: String(adminUser.id),
    });
  }

  await db.collection("auditLogs").add({
    action: hardDelete ? "hard_delete_book" : "soft_delete_book",
    bookId: bookId,
    adminTelegramId: String(adminUser.id),
    timestamp: FieldValue.serverTimestamp(),
  });

  return { success: true };
};

export const generateBookQuizHandler = async (db, request, secrets) => {
  const { botToken } = secrets || {};
  if (!request.auth && !request.data?.initData) {
    throw new HttpsError("unauthenticated", "Tizimga kirish shart.");
  }
  if (!request.auth && request.data?.initData) {
    await assertAdminAuth(db, request.data.initData, botToken);
  }

  const bookId = request.data?.bookId;
  if (!bookId || typeof bookId !== "string") {
    throw new HttpsError("invalid-argument", "bookId kiritilmadi.");
  }

  // 1. Check if quiz already exists
  const quizDocRef = db.collection("bookQuizzes").doc(bookId);
  const quizSnap = await quizDocRef.get();
  if (quizSnap.exists) {
    const existingQuiz = quizSnap.data();
    if (Array.isArray(existingQuiz.questions) && existingQuiz.questions.length >= 10) {
      return { success: true, quiz: existingQuiz, reused: true };
    }
  }

  // 2. Fetch book doc
  const bookSnap = await db.collection("books").doc(bookId).get();
  if (!bookSnap.exists || bookSnap.data()?.isActive === false) {
    throw new HttpsError("not-found", "Kitob topilmadi yoki faol emas.");
  }

  const book = bookSnap.data();
  const pdfUrl = book.pdfUrl;
  if (!pdfUrl) {
    throw new HttpsError("failed-precondition", "Kitob uchun PDF fayli ko'rsatilmagan.");
  }

  // 3. Download & extract text from PDF
  let pdfBuffer;
  try {
    if (pdfUrl.startsWith("data:application/pdf;base64,")) {
      pdfBuffer = Buffer.from(pdfUrl.replace(/^data:application\/pdf;base64,/, ""), "base64");
    } else {
      const response = await fetch(pdfUrl);
      if (!response.ok) {
        throw new Error(`PDF faylni yuklab bo'lmadi: ${response.statusText}`);
      }
      const arrayBuf = await response.arrayBuffer();
      pdfBuffer = Buffer.from(arrayBuf);
    }
  } catch (err) {
    console.error("PDF download error:", err);
    throw new HttpsError("unavailable", `PDF faylni yuklab bo'lmadi: ${err.message}`);
  }

  const { text: rawText, totalPages } = await extractPdfTextAndPages(pdfBuffer);
  if (!rawText || rawText.length < 50) {
    throw new HttpsError("failed-precondition", "Kitob PDF faylidan matn ajratib bo'lmadi.");
  }

  // Update book's totalPages if missing
  if (totalPages > 1 && (!book.totalPages || book.totalPages === 1)) {
    await db.collection("books").doc(bookId).update({ totalPages });
  }

  // 4. Truncate/sample text for Gemini prompt
  const preparedText = prepareTextForGemini(rawText);
  const prompt = buildBookQuizPrompt(book.title, book.author, preparedText);

  // 5. Call Gemini API
  const apiKey = secrets.geminiApiKey;
  if (!apiKey) {
    throw new HttpsError("internal", "Gemini API kaliti sozlanmagan.");
  }

  let rawGeminiText;
  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      generationConfig: {
        temperature: 0.3,
        responseMimeType: "application/json",
      },
    });

    const result = await model.generateContent(prompt);
    const response = await result.response;
    rawGeminiText = response.text();
  } catch (err) {
    console.error("Gemini quiz generation error:", err);
    throw new HttpsError("unavailable", "Gemini AI orqali test savollarini yaratib bo'lmadi. Keyinroq qayta urinib ko'ring.");
  }

  // 6. Validate questions
  let questions;
  try {
    questions = parseAndValidateQuizResponse(rawGeminiText);
  } catch (err) {
    console.error("Quiz response parse error:", err, "Raw Gemini Output:", rawGeminiText);
    throw new HttpsError("internal", `AI javobini qayta ishlashda xatolik: ${err.message}`);
  }

  // 7. Save quiz to bookQuizzes
  const newQuiz = {
    bookId: bookId,
    questions: questions,
    generatedAt: FieldValue.serverTimestamp(),
  };

  await quizDocRef.set(newQuiz);

  return {
    success: true,
    quiz: {
      bookId,
      questions,
      generatedAt: new Date().toISOString(),
    },
    reused: false,
  };
};

export const updateBookProgressHandler = async (db, request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Tizimga kirish shart.");
  }

  const uid = request.auth.uid;
  const bookId = request.data?.bookId;
  const currentPage = Math.max(1, parseInt(request.data?.currentPage || 1, 10));

  if (!bookId || typeof bookId !== "string") {
    throw new HttpsError("invalid-argument", "bookId kiritilmadi.");
  }

  const bookSnap = await db.collection("books").doc(bookId).get();
  if (!bookSnap.exists) {
    throw new HttpsError("not-found", "Kitob topilmadi.");
  }

  const bookData = bookSnap.data() || {};
  const totalPages = Math.max(1, parseInt(bookData.totalPages || 1, 10));
  const { status, isCompleted } = calculateBookProgressStatus(currentPage, totalPages);

  const progressRef = db.collection("users").doc(uid).collection("bookProgress").doc(bookId);
  const progressSnap = await progressRef.get();

  const updates = {
    lastPageRead: currentPage,
    totalPages: totalPages,
    status: status,
    lastReadAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (!progressSnap.exists) {
    updates.startedAt = FieldValue.serverTimestamp();
  }

  if (isCompleted && (!progressSnap.exists || progressSnap.data()?.status !== "completed")) {
    updates.completedAt = FieldValue.serverTimestamp();
  }

  await progressRef.set(updates, { merge: true });

  return {
    success: true,
    progress: {
      bookId,
      lastPageRead: currentPage,
      totalPages,
      status,
    },
  };
};

export const submitBookQuizHandler = async (db, request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Tizimga kirish shart.");
  }

  const uid = request.auth.uid;
  const bookId = request.data?.bookId;
  const userAnswers = request.data?.answers;

  if (!bookId || typeof bookId !== "string") {
    throw new HttpsError("invalid-argument", "bookId kiritilmadi.");
  }

  if (!Array.isArray(userAnswers)) {
    throw new HttpsError("invalid-argument", "answers massivi taqdim etilishi kerak.");
  }

  // Fetch quiz doc
  const quizSnap = await db.collection("bookQuizzes").doc(bookId).get();
  if (!quizSnap.exists) {
    throw new HttpsError("not-found", "Ushbu kitob uchun test topilmadi.");
  }

  const quizData = quizSnap.data() || {};
  const questions = quizData.questions || [];
  if (questions.length === 0) {
    throw new HttpsError("failed-precondition", "Test savollari yaroqsiz.");
  }

  // Fetch book doc for pointsReward
  const bookSnap = await db.collection("books").doc(bookId).get();
  const bookData = bookSnap.exists ? bookSnap.data() : {};
  const pointsReward = bookData.pointsReward !== undefined ? bookData.pointsReward : 100;

  // Calculate score
  const { score, totalQuestions, pointsEarned } = calculateQuizScore(userAnswers, questions, pointsReward);

  const resultRef = db.collection("users").doc(uid).collection("quizResults").doc(bookId);
  const userRef = db.collection("users").doc(uid);

  let finalPointsEarned = 0;
  let alreadySubmitted = false;

  await db.runTransaction(async (transaction) => {
    const existingResultSnap = await transaction.get(resultRef);

    if (existingResultSnap.exists) {
      alreadySubmitted = true;
      finalPointsEarned = 0;
    } else {
      alreadySubmitted = false;
      finalPointsEarned = pointsEarned;
    }

    transaction.set(
      resultRef,
      {
        bookId: bookId,
        score: score,
        totalQuestions: totalQuestions,
        pointsEarned: finalPointsEarned,
        answers: userAnswers,
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (!alreadySubmitted && finalPointsEarned > 0) {
      transaction.update(userRef, {
        totalPoints: FieldValue.increment(finalPointsEarned),
        weeklyPoints: FieldValue.increment(finalPointsEarned),
      });
    }
  });

  return {
    success: true,
    score,
    totalQuestions,
    pointsEarned: finalPointsEarned,
    alreadySubmitted,
  };
};
