import test from "node:test";
import assert from "node:assert/strict";
import {
  validateBookPdfFile,
  validateBookCoverImage,
  prepareTextForGemini,
  parseAndValidateQuizResponse,
  calculateQuizScore,
  calculateBookProgressStatus,
} from "../bookFunctions.js";

test("validateBookPdfFile restricts format to PDF and max size to 100MB", () => {
  // Valid PDF
  assert.equal(validateBookPdfFile("application/pdf", 10 * 1024 * 1024, "%PDF-1.4"), true);
  assert.equal(validateBookPdfFile(null, 99 * 1024 * 1024, "%PDF-1.7"), true);

  // Invalid MIME type
  assert.throws(
    () => validateBookPdfFile("image/jpeg", 1024, "%PDF-"),
    /Faqat PDF formatidagi/
  );

  // Exceeding 100MB size limit
  assert.throws(
    () => validateBookPdfFile("application/pdf", 101 * 1024 * 1024, "%PDF-"),
    /100MB dan oshmasligi kerak/
  );

  // Invalid PDF header signature
  assert.throws(
    () => validateBookPdfFile("application/pdf", 1024, "NOT_A_PDF"),
    /yaroqsiz PDF/
  );
});

test("validateBookCoverImage restricts image MIME type and max size to 5MB", () => {
  assert.equal(validateBookCoverImage("image/jpeg", 2 * 1024 * 1024), true);
  assert.equal(validateBookCoverImage("image/png", 4 * 1024 * 1024), true);
  assert.equal(validateBookCoverImage("image/webp", 1 * 1024 * 1024), true);

  // Invalid format
  assert.throws(
    () => validateBookCoverImage("application/pdf", 1024),
    /Faqat JPG, PNG yoki WEBP/
  );

  // Exceeding 5MB limit
  assert.throws(
    () => validateBookCoverImage("image/jpeg", 6 * 1024 * 1024),
    /5MB dan oshmasligi kerak/
  );
});

test("prepareTextForGemini handles short and long book texts appropriately", () => {
  const shortText = "Bu kichik kitob matni.";
  assert.equal(prepareTextForGemini(shortText), "Bu kichik kitob matni.");

  const longText = "A".repeat(50000);
  const prepared = prepareTextForGemini(longText);
  assert.ok(prepared.includes("[... MATN QISQARTIRILDI ...]"));
  assert.ok(prepared.length < 50000);
});

test("parseAndValidateQuizResponse strictly validates 10 questions and 4 options per question", () => {
  const sampleQuiz = {
    questions: Array.from({ length: 10 }, (_, i) => ({
      question: `Savol #${i + 1} matni?`,
      options: ["A variant", "B variant", "C variant", "D variant"],
      correctAnswerIndex: i % 4,
    })),
  };

  const validated = parseAndValidateQuizResponse(JSON.stringify(sampleQuiz));
  assert.equal(validated.length, 10);
  assert.equal(validated[0].question, "Savol #1 matni?");
  assert.equal(validated[0].options.length, 4);

  // Less than 10 questions throws error
  const invalidQuizShort = {
    questions: sampleQuiz.questions.slice(0, 5),
  };
  assert.throws(
    () => parseAndValidateQuizResponse(JSON.stringify(invalidQuizShort)),
    /savol qaytardi/
  );

  // Invalid options count throws error
  const invalidOptionsQuiz = {
    questions: Array.from({ length: 10 }, (_, i) => ({
      question: `Savol #${i + 1}`,
      options: ["A", "B"],
      correctAnswerIndex: 0,
    })),
  };
  assert.throws(
    () => parseAndValidateQuizResponse(JSON.stringify(invalidOptionsQuiz)),
    /formati noto'g'ri/
  );
});

test("calculateQuizScore calculates score and proportional points reward", () => {
  const questions = Array.from({ length: 10 }, (_, i) => ({
    question: `Q${i}`,
    options: ["1", "2", "3", "4"],
    correctAnswerIndex: 0,
  }));

  // All 10 correct with 100 points reward
  const userAnswers10 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  const res100 = calculateQuizScore(userAnswers10, questions, 100);
  assert.equal(res100.score, 10);
  assert.equal(res100.totalQuestions, 10);
  assert.equal(res100.pointsEarned, 100);

  // 7 out of 10 correct with 200 points reward -> Math.round((7/10)*200) = 140
  const userAnswers7 = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1];
  const res70 = calculateQuizScore(userAnswers7, questions, 200);
  assert.equal(res70.score, 7);
  assert.equal(res70.pointsEarned, 140);

  // 0 correct -> 0 points
  const userAnswers0 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
  const res0 = calculateQuizScore(userAnswers0, questions, 100);
  assert.equal(res0.score, 0);
  assert.equal(res0.pointsEarned, 0);
});

test("preventing re-submission point exploitation logic simulation", () => {
  // Simulated submission transaction logic
  let userTotalPoints = 500;
  let userWeeklyPoints = 200;
  const dbQuizResults = new Map();

  const submitQuizTxn = (uid, bookId, userAnswers, questions, pointsReward) => {
    const key = `${uid}_${bookId}`;
    const { score, totalQuestions, pointsEarned } = calculateQuizScore(userAnswers, questions, pointsReward);

    if (dbQuizResults.has(key)) {
      // Re-submission: zero points earned
      dbQuizResults.set(key, { score, totalQuestions, pointsEarned: 0, reSubmitted: true });
      return { score, totalQuestions, pointsEarned: 0, alreadySubmitted: true };
    }

    // First time submission: award points
    dbQuizResults.set(key, { score, totalQuestions, pointsEarned, reSubmitted: false });
    userTotalPoints += pointsEarned;
    userWeeklyPoints += pointsEarned;
    return { score, totalQuestions, pointsEarned, alreadySubmitted: false };
  };

  const questions = Array.from({ length: 10 }, () => ({ correctAnswerIndex: 0 }));

  // First submission (10/10 correct, 100 points reward)
  const firstAttempt = submitQuizTxn("user123", "book_abc", [0,0,0,0,0,0,0,0,0,0], questions, 100);
  assert.equal(firstAttempt.alreadySubmitted, false);
  assert.equal(firstAttempt.pointsEarned, 100);
  assert.equal(userTotalPoints, 600);
  assert.equal(userWeeklyPoints, 300);

  // Second submission for same book -> alreadySubmitted = true, pointsEarned = 0, user points unchanged
  const secondAttempt = submitQuizTxn("user123", "book_abc", [0,0,0,0,0,0,0,0,0,0], questions, 100);
  assert.equal(secondAttempt.alreadySubmitted, true);
  assert.equal(secondAttempt.pointsEarned, 0);
  assert.equal(userTotalPoints, 600); // Unchanged!
  assert.equal(userWeeklyPoints, 300); // Unchanged!
});

test("calculateBookProgressStatus determines reading vs completed status", () => {
  const p1 = calculateBookProgressStatus(5, 100);
  assert.equal(p1.status, "reading");
  assert.equal(p1.isCompleted, false);

  const p2 = calculateBookProgressStatus(100, 100);
  assert.equal(p2.status, "completed");
  assert.equal(p2.isCompleted, true);

  const p3 = calculateBookProgressStatus(150, 100);
  assert.equal(p3.status, "completed");
  assert.equal(p3.isCompleted, true);
});
