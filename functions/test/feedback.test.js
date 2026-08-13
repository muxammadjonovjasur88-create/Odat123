import test from "node:test";
import assert from "node:assert/strict";
import {
  selectRandomFeedbackRecipient,
  validateFeedbackMessage,
  FEEDBACK_RECIPIENT_1,
  FEEDBACK_RECIPIENT_2,
} from "../index.js";

test("validateFeedbackMessage rejects empty, null, or whitespace-only messages", () => {
  assert.equal(validateFeedbackMessage(null).valid, false);
  assert.equal(validateFeedbackMessage(undefined).valid, false);
  assert.equal(validateFeedbackMessage("").valid, false);
  assert.equal(validateFeedbackMessage("   \n\t ").valid, false);
  assert.equal(validateFeedbackMessage(123).valid, false);
});

test("validateFeedbackMessage accepts non-empty string and trims it", () => {
  const result = validateFeedbackMessage("  Salom, ilova juda zo'r!  ");
  assert.equal(result.valid, true);
  assert.equal(result.text, "Salom, ilova juda zo'r!");
});

test("selectRandomFeedbackRecipient randomly selects both recipient IDs over multiple iterations", () => {
  const recipients = ["ID_ALPHA", "ID_BETA"];
  const counts = { ID_ALPHA: 0, ID_BETA: 0 };

  const totalRuns = 200;
  for (let i = 0; i < totalRuns; i++) {
    const selected = selectRandomFeedbackRecipient(recipients);
    assert.ok(recipients.includes(selected), `Unexpected recipient selected: ${selected}`);
    counts[selected]++;
  }

  // Ensure both recipients were selected at least once (probabilistically 100% true with 200 runs)
  assert.ok(counts.ID_ALPHA > 0, `ID_ALPHA was never selected! Counts: ${JSON.stringify(counts)}`);
  assert.ok(counts.ID_BETA > 0, `ID_BETA was never selected! Counts: ${JSON.stringify(counts)}`);
});

test("default FEEDBACK_RECIPIENT placeholders are defined", () => {
  assert.ok(typeof FEEDBACK_RECIPIENT_1 === "string");
  assert.ok(typeof FEEDBACK_RECIPIENT_2 === "string");
  assert.ok(FEEDBACK_RECIPIENT_1.length > 0);
  assert.ok(FEEDBACK_RECIPIENT_2.length > 0);
});
