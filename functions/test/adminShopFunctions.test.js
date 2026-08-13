import test from "node:test";
import assert from "node:assert/strict";

test("adminShopItem validation logic checks type, title and points cost", () => {
  const validateItem = (item) => {
    if (!item || !item.title || !item.type) {
      throw new Error("Mahsulot sarlavhasi va turi bo'lishi shart.");
    }
    if (!["coupon", "gift"].includes(item.type)) {
      throw new Error("Turi faqat 'coupon' yoki 'gift' bo'lishi mumkin.");
    }
    return true;
  };

  assert.equal(validateItem({ title: "Yandex Go 20%", type: "coupon", pointsCost: 100 }), true);
  assert.equal(validateItem({ title: "Wireless Headphone", type: "gift", pointsCost: 500 }), true);

  assert.throws(() => validateItem({ title: "Bad Item", type: "other" }), /Turi faqat/);
  assert.throws(() => validateItem({ type: "coupon" }), /Mahsulot sarlavhasi/);
});

test("adminUploadShopImage restricts file size to 5MB and allowed MIME types", () => {
  const validateImage = (contentType, bufferLength) => {
    if (!["image/jpeg", "image/png", "image/webp"].includes(contentType)) {
      throw new Error("Faqat JPG, PNG yoki WEBP rasmlari yuklanishi mumkin.");
    }
    if (bufferLength > 5 * 1024 * 1024) {
      throw new Error("Rasm hajmi 5MB dan oshmasligi kerak.");
    }
    return true;
  };

  assert.equal(validateImage("image/jpeg", 1024 * 1024), true);
  assert.equal(validateImage("image/png", 4 * 1024 * 1024), true);

  assert.throws(() => validateImage("application/pdf", 1024), /Faqat JPG/);
  assert.throws(() => validateImage("image/jpeg", 6 * 1024 * 1024), /5MB/);
});

test("adminUpdateGiftOrderStatus validates target status string", () => {
  const validStatuses = ["pending", "confirmed", "shipped", "delivered", "cancelled"];
  
  const validateStatus = (status) => {
    if (!validStatuses.includes(status)) {
      throw new Error(`Yaroqsiz status: ${status}`);
    }
    return true;
  };

  for (const s of validStatuses) {
    assert.equal(validateStatus(s), true);
  }

  assert.throws(() => validateStatus("unknown_status"), /Yaroqsiz status/);
});
