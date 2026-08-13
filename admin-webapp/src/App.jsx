import React, { useState, useEffect } from "react";
import { Navbar } from "./components/Navbar";
import { ProductsTab } from "./components/ProductsTab";
import { OrdersTab } from "./components/OrdersTab";
import { BooksTab } from "./components/BooksTab";
import { api, getTelegramInitData } from "./services/api";
import { ShieldAlert, RefreshCw, AlertCircle, Sparkles } from "lucide-react";

export default function App() {
  const [activeTab, setActiveTab] = useState(() => {
    const params = new URLSearchParams(window.location.search);
    const tabParam = params.get("tab");
    if (tabParam && ["products", "orders", "books"].includes(tabParam)) {
      return tabParam;
    }
    return "products";
  });

  const [autoOpenAddBook, setAutoOpenAddBook] = useState(() => {
    const params = new URLSearchParams(window.location.search);
    return params.get("tab") === "books" && params.get("action") === "add";
  });

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get("action")) {
      const tabParam = params.get("tab");
      const newUrl = window.location.pathname + (tabParam ? `?tab=${tabParam}` : "");
      window.history.replaceState({}, "", newUrl);
    }
  }, []);

  const [user, setUser] = useState(null);
  const [isAuthLoading, setIsAuthLoading] = useState(true);
  const [authError, setAuthError] = useState("");

  const [items, setItems] = useState([]);
  const [orders, setOrders] = useState([]);
  const [books, setBooks] = useState([]);
  const [isDataLoading, setIsDataLoading] = useState(false);
  const [notification, setNotification] = useState(null);

  const showNotification = (msg, type = "success") => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 3500);
  };

  const loadData = async () => {
    setIsDataLoading(true);
    try {
      const [itemsRes, ordersRes, booksRes] = await Promise.all([
        api.listShopItems(),
        api.listGiftOrders("all"),
        api.listBooks(),
      ]);
      setItems(itemsRes.items || []);
      setOrders(ordersRes.orders || []);
      setBooks(booksRes.books || []);
    } catch (err) {
      showNotification(err.message || "Ma'lumotlarni yuklashda xatolik", "error");
    } finally {
      setIsDataLoading(false);
    }
  };

  useEffect(() => {
    const initAuth = async () => {
      setIsAuthLoading(true);
      setAuthError("");
      try {
        const initData = getTelegramInitData();
        if (!initData) {
          throw new Error("Telegram Mini App initData topilmadi. Iltimos, Telegram botidagi /admin tugmasi orqali kiring.");
        }

        const res = await api.checkAuth();
        if (res.success && res.user) {
          setUser(res.user);
          await loadData();
        } else {
          throw new Error("Admin huquqlari tasdiqlanmadi.");
        }
      } catch (err) {
        setAuthError(err.message || "Kirish rad etildi");
      } finally {
        setIsAuthLoading(false);
      }
    };

    initAuth();
  }, []);

  const handleSaveItem = async (itemData, itemId = null) => {
    try {
      if (itemId) {
        await api.updateShopItem(itemId, itemData);
        showNotification("Mahsulot muvaffaqiyatli tahrirlandi ✨");
      } else {
        await api.createShopItem(itemData);
        showNotification("Yangi mahsulot do'konga qo'shildi 🎉");
      }
      await loadData();
    } catch (err) {
      showNotification(err.message || "Saqlashda xatolik yuz berdi", "error");
      throw err;
    }
  };

  const handleDeleteItem = async (itemId) => {
    try {
      await api.deleteShopItem(itemId, false); // Soft-delete
      showNotification("Mahsulot noaktiv qilindi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "O'chirishda xatolik", "error");
    }
  };

  const handleToggleActive = async (item) => {
    try {
      await api.updateShopItem(item.id, { ...item, isActive: !item.isActive });
      showNotification(`Mahsulot statusi ${!item.isActive ? "faol" : "noaktiv"} qilindi`);
      await loadData();
    } catch (err) {
      showNotification(err.message || "Statusni o'zgartirishda xatolik", "error");
    }
  };

  const handleUpdateOrderStatus = async (orderId, newStatus, adminNote) => {
    try {
      await api.updateGiftOrderStatus(orderId, newStatus, adminNote);
      showNotification("Buyurtma statusi yangilandi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "Statusni yangilashda xatolik", "error");
    }
  };

  // Books Handlers
  const handleSaveBook = async (payload, bookId = null) => {
    try {
      if (bookId) {
        if (payload.base64Pdf || payload.base64Cover) {
          await api.uploadBook({ ...payload, bookId });
        } else {
          await api.updateBook(bookId, payload.book);
        }
        showNotification("Kitob muvaffaqiyatli tahrirlandi ✨");
      } else {
        await api.uploadBook(payload);
        showNotification("Yangi kitob kutubxonaga qo'shildi 🎉");
      }
      await loadData();
    } catch (err) {
      showNotification(err.message || "Kitobni saqlashda xatolik yuz berdi", "error");
      throw err;
    }
  };

  const handleDeleteBook = async (bookId) => {
    try {
      await api.deleteBook(bookId, false);
      showNotification("Kitob noaktiv qilindi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "O'chirishda xatolik", "error");
    }
  };

  const handleToggleActiveBook = async (book) => {
    try {
      await api.updateBook(book.id, { ...book, isActive: !book.isActive });
      showNotification(`Kitob statusi ${!book.isActive ? "faol" : "noaktiv"} qilindi`);
      await loadData();
    } catch (err) {
      showNotification(err.message || "Statusni o'zgartirishda xatolik", "error");
    }
  };

  const handleGenerateQuiz = async (bookId) => {
    try {
      const res = await api.generateBookQuiz(bookId);
      if (res?.reused) {
        showNotification("Mavjud test biriktirildi ✨");
      } else {
        showNotification("Gemini AI orqali 10 ta test savoli yaratildi! 🎉");
      }
      await loadData();
    } catch (err) {
      showNotification(err.message || "Test yaratishda xatolik yuz berdi", "error");
    }
  };

  // Loading Screen
  if (isAuthLoading) {
    return (
      <div className="min-h-screen bg-[#0f172a] text-slate-100 flex flex-col items-center justify-center p-6 text-center">
        <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-amber-400 via-yellow-500 to-amber-600 p-0.5 shadow-xl shadow-amber-500/25 mb-4 animate-pulse">
          <div className="w-full h-full bg-slate-950 rounded-[14px] flex items-center justify-center text-2xl">
            🪙
          </div>
        </div>
        <h2 className="font-bold text-base text-slate-200">Odat Admin Panel</h2>
        <p className="text-xs text-slate-500 mt-1">Telegram autentifikatsiya tekshirilmoqda...</p>
      </div>
    );
  }

  // Auth Error Screen
  if (authError) {
    return (
      <div className="min-h-screen bg-[#0f172a] text-slate-100 flex flex-col items-center justify-center p-6 text-center">
        <div className="max-w-md w-full bg-slate-900 border border-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
          <div className="w-14 h-14 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center justify-center mx-auto">
            <ShieldAlert size={28} />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-100">Kirish rad etildi</h2>
            <p className="text-xs text-slate-400 mt-2 leading-relaxed">{authError}</p>
          </div>
          <div className="bg-slate-950 p-3 rounded-xl border border-slate-800 text-[11px] text-slate-400 text-left space-y-1">
            <p className="font-semibold text-slate-300">💡 Qanday kirish kerak?</p>
            <p>1. Telegram botingizga kiring</p>
            <p>2. <code className="bg-slate-800 px-1 py-0.5 rounded text-emerald-400 font-mono">/admin</code> buyrug'ini yuboring</p>
            <p>3. Yuborilgan "Admin Panelni ochish" tugmasini bosing</p>
          </div>
          <button
            onClick={() => window.location.reload()}
            className="w-full py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-bold text-slate-200 transition-colors flex items-center justify-center gap-1.5"
          >
            <RefreshCw size={14} />
            <span>Qayta urinish</span>
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0f172a] text-slate-100 pb-12">
      {/* Toast Notification */}
      {notification && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50 max-w-sm w-full px-4">
          <div
            className={`p-3 rounded-2xl border text-xs font-semibold shadow-2xl flex items-center gap-2 backdrop-blur-md ${
              notification.type === "error"
                ? "bg-rose-900/90 border-rose-700 text-rose-100 shadow-rose-950/50"
                : "bg-emerald-900/90 border-emerald-700 text-emerald-100 shadow-emerald-950/50"
            }`}
          >
            {notification.type === "error" ? <AlertCircle size={16} /> : <Sparkles size={16} />}
            <span>{notification.msg}</span>
          </div>
        </div>
      )}

      {/* Navbar Header */}
      <Navbar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        user={user}
        onRefresh={loadData}
        isLoading={isDataLoading}
      />

      {/* Main Content */}
      <main className="max-w-4xl mx-auto px-4 pt-4">
        {activeTab === "products" ? (
          <ProductsTab
            items={items}
            onSaveItem={handleSaveItem}
            onDeleteItem={handleDeleteItem}
            onToggleActive={handleToggleActive}
            isLoading={isDataLoading}
          />
        ) : activeTab === "orders" ? (
          <OrdersTab
            orders={orders}
            onUpdateStatus={handleUpdateOrderStatus}
            isLoading={isDataLoading}
          />
        ) : (
          <BooksTab
            books={books}
            onSaveBook={handleSaveBook}
            onDeleteBook={handleDeleteBook}
            onToggleActive={handleToggleActiveBook}
            onGenerateQuiz={handleGenerateQuiz}
            isLoading={isDataLoading}
            autoOpenAddModal={autoOpenAddBook}
          />
        )}
      </main>
    </div>
  );
}
