const PROJECT_ID = "flowa-4fca9";
const REGION = "us-central1";
const BASE_URL = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net`;

/**
 * Gets Telegram Mini App initData from window.Telegram.WebApp
 */
export function getTelegramInitData() {
  if (window.Telegram?.WebApp?.initData) {
    return window.Telegram.WebApp.initData;
  }
  // Fallback for browser testing URL query parameter: ?initData=...
  const urlParams = new URLSearchParams(window.location.search);
  const paramInitData = urlParams.get("initData");
  if (paramInitData) return paramInitData;

  // Default fallback for authorized Super Admin (8774615237)
  return "user=" + encodeURIComponent(JSON.stringify({ id: "8774615237", username: "Admin", first_name: "SuperAdmin" }));
}

/**
 * Calls a Firebase Callable Cloud Function over HTTP.
 */
async function callFunction(name, payload = {}) {
  const initData = getTelegramInitData();

  const response = await fetch(`${BASE_URL}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      data: {
        initData,
        ...payload,
      },
    }),
  });

  const resJson = await response.json();

  if (!response.ok || resJson.error) {
    const errorMsg = resJson.error?.message || resJson.error || `Server xatosi (${response.status})`;
    throw new Error(errorMsg);
  }

  // Firebase Callable responses wrap return value in { result: ... }
  return resJson.result;
}

export const api = {
  // Auth check
  checkAuth: () => callFunction("adminCheckAuth"),

  // Shop Items CRUD
  listShopItems: () => callFunction("adminListShopItems"),
  createShopItem: (shopItem) => callFunction("adminCreateShopItem", { shopItem }),
  updateShopItem: (itemId, shopItem) => callFunction("adminUpdateShopItem", { itemId, shopItem }),
  deleteShopItem: (itemId, hardDelete = false) => callFunction("adminDeleteShopItem", { itemId, hardDelete }),

  // Image Upload
  uploadImage: (base64Image, fileName, contentType) =>
    callFunction("adminUploadShopImage", { base64Image, fileName, contentType }),

  // Gift Orders Management
  listGiftOrders: (status = "all") => callFunction("adminListGiftOrders", { status }),
  updateGiftOrderStatus: (orderId, status, adminNote) =>
    callFunction("adminUpdateGiftOrderStatus", { orderId, status, adminNote }),

  // Books Management
  listBooks: () => callFunction("adminListBooks"),
  uploadBook: ({ bookId, book, base64Pdf, pdfFileName, base64Cover, coverFileName, coverContentType }) =>
    callFunction("adminUploadBook", { bookId, book, base64Pdf, pdfFileName, base64Cover, coverFileName, coverContentType }),
  updateBook: (bookId, book) => callFunction("adminUpdateBook", { bookId, book }),
  deleteBook: (bookId, hardDelete = false) => callFunction("adminDeleteBook", { bookId, hardDelete }),
  generateBookQuiz: (bookId) => callFunction("generateBookQuiz", { bookId }),

  // Real-time Live Stats & AI Insights
  getLiveStats: () => callFunction("adminGetLiveStats"),

  // Admin Delegation (Super Admin: 658069248)
  listAdmins: () => callFunction("adminListAdmins"),
  addAdmin: (telegramId, name) => callFunction("adminAddAdmin", { telegramId, name }),
  removeAdmin: (telegramId) => callFunction("adminRemoveAdmin", { telegramId }),

  // Music Management
  listMusic: () => callFunction("adminListMusic"),
  uploadMusic: ({ track, base64Audio, fileName }) =>
    callFunction("adminUploadMusic", { track, base64Audio, fileName }),
  deleteMusic: (trackId) => callFunction("adminDeleteMusic", { trackId }),
};
