import React, { useState, useEffect } from "react";
import { Navbar } from "./components/Navbar";
import { DashboardTab } from "./components/DashboardTab";
import { ProductsTab } from "./components/ProductsTab";
import { OrdersTab } from "./components/OrdersTab";
import { BooksTab } from "./components/BooksTab";
import { MusicTab } from "./components/MusicTab";
import { AudiobooksTab } from "./components/AudiobooksTab";
import StatsTab from "./components/StatsTab";
import AdminsTab from "./components/AdminsTab";
import { BookModal } from "./components/BookModal";
import { ProductModal } from "./components/ProductModal";
import { MusicModal } from "./components/MusicModal";
import { AudiobookModal } from "./components/AudiobookModal";
import { LandingPage } from "./components/LandingPage";
import { api, getTelegramInitData } from "./services/api";
import {
  directUploadMusic,
  directUpdateMusic,
  directListMusic,
  directDeleteMusic,
  directListAudiobooks,
  directSaveAudiobook,
  directCreateShopItem,
  directUpdateShopItem,
  directDeleteShopItem,
  directUploadBook,
  directUpdateBook,
} from "./services/firebase";
import { signInWithCustomToken } from "firebase/auth";
import { auth } from "./services/firebase";

export default function App() {
  const [activeTab, setActiveTab] = useState("dashboard");

  const [user, setUser] = useState(null);
  const [isAuthLoading, setIsAuthLoading] = useState(true);
  const [authError, setAuthError] = useState(null);

  // Data states
  const [items, setItems] = useState([]);
  const [orders, setOrders] = useState([]);
  const [books, setBooks] = useState([]);
  const [music, setMusic] = useState([]);
  const [audiobooks, setAudiobooks] = useState([]);

  const [isDataLoading, setIsDataLoading] = useState(false);
  const [notification, setNotification] = useState(null);

  // Modals
  const [isBookModalOpen, setIsBookModalOpen] = useState(false);
  const [selectedBook, setSelectedBook] = useState(null);

  const [isProductModalOpen, setIsProductModalOpen] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState(null);

  const [isMusicModalOpen, setIsMusicModalOpen] = useState(false);
  const [selectedMusic, setSelectedMusic] = useState(null);

  const [isAudiobookModalOpen, setIsAudiobookModalOpen] = useState(false);
  const [selectedAudiobook, setSelectedAudiobook] = useState(null);

  const showNotification = (msg, type = "success") => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 3500);
  };

  const loadData = async () => {
    setIsDataLoading(true);
    try {
      const [itemsRes, ordersRes, booksRes, musicRes, audiobooksList] = await Promise.allSettled([
        api.listShopItems(),
        api.listGiftOrders("all"),
        api.listBooks(),
        directListMusic(),
        directListAudiobooks(),
      ]);

      if (itemsRes.status === "fulfilled") setItems(itemsRes.value?.items || []);
      if (ordersRes.status === "fulfilled") setOrders(ordersRes.value?.orders || []);
      if (booksRes.status === "fulfilled") setBooks(booksRes.value?.books || []);
      if (musicRes.status === "fulfilled") setMusic(Array.isArray(musicRes.value) ? musicRes.value : (musicRes.value?.tracks || []));
      if (audiobooksList.status === "fulfilled") setAudiobooks(audiobooksList.value || []);
    } catch (err) {
      showNotification(err.message || "Ma'lumotlarni yuklashda xatolik", "error");
    } finally {
      setIsDataLoading(false);
    }
  };

  useEffect(() => {
    const initAuth = async () => {
      setIsAuthLoading(true);
      setAuthError(null);
      try {
        const initData = getTelegramInitData();
        if (!initData) {
          throw new Error("Telegram avtorizatsiya ma'lumotlari (initData) topilmadi.");
        }

        const res = await api.checkAuth();
        if (res && res.success && res.user) {
          setUser(res.user);
          if (res.customToken) {
            try {
              await signInWithCustomToken(auth, res.customToken);
            } catch (e) {
              console.error("Custom token orqali kirishda xatolik:", e);
            }
          }
          await loadData();
        } else {
          throw new Error(res?.error || "Ushbu Telegram hisobi uchun admin huquqi berilmagan.");
        }
      } catch (err) {
        console.warn("Admin auth check failed:", err.message);
        setUser(null);
        setAuthError(err.message || "Ruxsat yo'q. Ushbu panel faqat Odat ma'murlari uchun.");
      } finally {
        setIsAuthLoading(false);
      }
    };

    initAuth();
  }, []);

  // 📚 Books Actions
  const handleSaveBook = async (bookData, bookId = null, onProgress) => {
    try {
      if (bookId) {
        await directUpdateBook(bookId, bookData, onProgress);
        try { await api.updateBook(bookId, bookData.book || bookData); } catch (_) {}
        showNotification("Kitob va PTS mukofoti muvaffaqiyatli saqlandi! 📚");
      } else {
        try {
          await directUploadBook(bookData, onProgress);
        } catch (directErr) {
          console.warn("Direct upload fallback to API:", directErr);
          await api.uploadBook(bookData);
        }
        showNotification("Yangi kitob kutubxonaga qo'shildi 🎉");
      }
      await loadData();
    } catch (err) {
      showNotification(err.message || "Kitobni saqlashda xatolik", "error");
      throw err;
    }
  };

  const handleDeleteBook = async (bookId) => {
    try {
      await api.deleteBook(bookId, false);
      showNotification("Kitob kutubxonadan olib tashlandi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "O'chirishda xatolik", "error");
    }
  };

  // 🛍️ Products Actions
  const handleSaveItem = async (itemData, itemId = null) => {
    try {
      if (itemId) {
        await directUpdateShopItem(itemId, itemData);
        try { await api.updateShopItem(itemId, itemData); } catch (_) {}
        showNotification("Mahsulot narxi va ma'lumotlari yangilandi! ✨");
      } else {
        try {
          await directCreateShopItem(itemData);
        } catch (directErr) {
          console.warn("Direct create fallback to API:", directErr);
          await api.createShopItem(itemData);
        }
        showNotification("Yangi mahsulot do'konga qo'shildi 🎉");
      }
      await loadData();
    } catch (err) {
      showNotification(err.message || "Saqlashda xatolik", "error");
      throw err;
    }
  };

  const handleDeleteItem = async (itemId) => {
    try {
      await directDeleteShopItem(itemId, false);
      try { await api.deleteShopItem(itemId, false); } catch (_) {}
      showNotification("Mahsulot do'kondan olib tashlandi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "O'chirishda xatolik", "error");
    }
  };

  const handleToggleActive = async (item) => {
    try {
      await directUpdateShopItem(item.id, { isActive: !item.isActive });
      try { await api.updateShopItem(item.id, { isActive: !item.isActive }); } catch (_) {}
      showNotification(item.isActive ? "Mahsulot noaktiv qilindi" : "Mahsulot faollashtirildi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "Holatni o'zgartirishda xatolik", "error");
    }
  };

  const handleUpdateOrderStatus = async (orderId, newStatus) => {
    try {
      await api.updateGiftOrderStatus(orderId, newStatus);
      showNotification("Buyurtma holati yangilandi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "Buyurtmani yangilashda xatolik", "error");
    }
  };

  // 🎵 Music Actions
  const handleSaveMusic = async (trackData, trackId = null, onProgress) => {
    try {
      if (trackId) {
        await directUpdateMusic(trackId, {
          audioFile: trackData.audioFile || null,
          title: trackData.title,
          artist: trackData.artist,
          genre: trackData.genre,
          ptsCost: trackData.ptsCost,
          audioUrl: trackData.audioUrl,
          category: trackData.category,
        }, onProgress);
        showNotification("Musiqa treki va PTS narxi yangilandi! 🎵");
      } else {
        await directUploadMusic({
          audioFile: trackData.audioFile || null,
          title: trackData.title,
          genre: trackData.genre,
          ptsCost: trackData.ptsCost,
          audioUrl: trackData.audioUrl,
        }, onProgress);
        showNotification("Yangi musiqa (MP3) muvaffaqiyatli yuklandi! 🎵");
      }
      await loadData();
    } catch (err) {
      showNotification(err.message || "Musiqani saqlashda xatolik", "error");
      throw err;
    }
  };

  const handleDeleteMusic = async (trackId) => {
    try {
      await directDeleteMusic(trackId);
      showNotification("Musiqa treki o'chirildi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "O'chirishda xatolik", "error");
    }
  };

  // 🎧 Audiobooks Actions
  const handleSaveAudiobook = async (audiobookData, audiobookId = null) => {
    try {
      await directSaveAudiobook(audiobookData, audiobookId);
      showNotification(audiobookId ? "Audio kitob muvaffaqiyatli yangilandi! 🎧" : "Yangi audio kitob saqlandi! 🎉");
      await loadData();
    } catch (err) {
      showNotification(err.message || "Audio kitobni saqlashda xatolik", "error");
      throw err;
    }
  };

  const handleDeleteAudiobook = async (audiobookId) => {
    try {
      await directDeleteAudiobook(audiobookId);
      showNotification("Audio kitob muvaffaqiyatli o'chirildi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "O'chirishda xatolik", "error");
    }
  };

  // 1. Loading State
  if (isAuthLoading) {
    return (
      <div className="min-h-screen bg-zen-void text-zen-text flex flex-col items-center justify-center p-6 text-center font-sans">
        <div className="w-16 h-16 rounded-3xl bg-zen-surface border border-zen-border flex items-center justify-center mb-6 shadow-glow-lime animate-pulse">
          <span className="text-3xl">🛡️</span>
        </div>
        <h2 className="text-xl font-black text-white tracking-wide mb-2">ODAT</h2>
        <p className="text-sm text-zen-muted mb-6">Yuklanmoqda...</p>
        <div className="w-8 h-8 border-3 border-zen-lime border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  // 2. Non-Admin or Public Web Visitor
  if (!user || authError) {
    const isTelegramEnv = Boolean(window.Telegram?.WebApp?.initData);
    if (!isTelegramEnv) {
      return <LandingPage />;
    }

    return (
      <div className="min-h-screen bg-zen-void text-zen-text flex flex-col items-center justify-center p-6 text-center font-sans">
        <div className="w-20 h-20 rounded-3xl bg-red-500/10 border border-red-500/30 flex items-center justify-center mb-6 shadow-lg shadow-red-500/10">
          <span className="text-4xl">🔒</span>
        </div>
        <div className="inline-block px-3 py-1 bg-red-500/20 text-red-400 border border-red-500/30 rounded-full text-xs font-black tracking-widest uppercase mb-3">
          403 Ruxsat Berilmagan
        </div>
        <h1 className="text-2xl font-black text-white mb-3">Kirish Taqiqlangan</h1>
        <p className="text-sm text-zen-muted max-w-md leading-relaxed mb-6">
          {authError || "Ushbu boshqaruv paneli faqat Odat ma'murlari (Adminlar) uchun mo'ljallangan. Sizning Telegram hisobingiz adminlar ro'yxatida mavjud emas."}
        </p>
        <button
          onClick={() => {
            if (window.Telegram?.WebApp?.close) {
              window.Telegram.WebApp.close();
            } else {
              window.location.href = "https://t.me/odat_fenix_bot";
            }
          }}
          className="px-6 py-3 bg-zen-surface hover:bg-zen-card text-white font-bold text-sm rounded-2xl border border-zen-border transition-all flex items-center gap-2"
        >
          <span>✕</span>
          <span>Mini App'ni Yopish</span>
        </button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-zen-void text-zen-text flex flex-col font-sans selection:bg-zen-lime selection:text-zen-void">
      {/* Toast Notification */}
      {notification && (
        <div className="fixed top-4 right-4 z-50 animate-bounce">
          <div
            className={`px-4 py-3 rounded-2xl shadow-glass-card text-xs font-bold flex items-center gap-2.5 border ${
              notification.type === "error"
                ? "bg-red-500/90 text-white border-red-400"
                : "bg-zen-lime text-zen-void border-zen-lime shadow-glow-lime"
            }`}
          >
            <span>{notification.msg}</span>
          </div>
        </div>
      )}

      {/* Modern Clean Navbar */}
      <Navbar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        user={user}
        onRefresh={loadData}
        isLoading={isDataLoading}
        pendingOrdersCount={orders.filter((o) => o.status === "pending" || o.status === "processing").length}
      />

      {/* Main Content Area */}
      <main className="flex-1 max-w-6xl w-full mx-auto p-4 md:p-6">
        {activeTab === "dashboard" && (
          <DashboardTab
            books={books}
            items={items}
            orders={orders}
            music={music}
            onNavigate={(tab) => setActiveTab(tab)}
            onOpenAddBook={() => {
              setSelectedBook(null);
              setIsBookModalOpen(true);
            }}
            onOpenAddProduct={() => {
              setSelectedProduct(null);
              setIsProductModalOpen(true);
            }}
            onOpenAddMusic={() => {
              setSelectedMusic(null);
              setIsMusicModalOpen(true);
            }}
          />
        )}

        {activeTab === "books" && (
          <BooksTab
            books={books}
            onSaveBook={handleSaveBook}
            onAddBook={() => {
              setSelectedBook(null);
              setIsBookModalOpen(true);
            }}
            onEditBook={(book) => {
              setSelectedBook(book);
              setIsBookModalOpen(true);
            }}
            onDeleteBook={handleDeleteBook}
          />
        )}

        {activeTab === "products" && (
          <ProductsTab
            items={items}
            onSaveItem={handleSaveItem}
            onAddItem={() => {
              setSelectedProduct(null);
              setIsProductModalOpen(true);
            }}
            onEditItem={(item) => {
              setSelectedProduct(item);
              setIsProductModalOpen(true);
            }}
            onDeleteItem={handleDeleteItem}
            onToggleActive={handleToggleActive}
          />
        )}

        {activeTab === "music" && (
          <MusicTab
            music={music}
            onAddMusic={() => {
              setSelectedMusic(null);
              setIsMusicModalOpen(true);
            }}
            onEditMusic={(track) => {
              setSelectedMusic(track);
              setIsMusicModalOpen(true);
            }}
            onDeleteMusic={handleDeleteMusic}
          />
        )}

        {activeTab === "audiobooks" && (
          <AudiobooksTab
            audiobooks={audiobooks}
            onAddAudiobook={() => {
              setSelectedAudiobook(null);
              setIsAudiobookModalOpen(true);
            }}
            onEditAudiobook={(book) => {
              setSelectedAudiobook(book);
              setIsAudiobookModalOpen(true);
            }}
            onDeleteAudiobook={handleDeleteAudiobook}
          />
        )}

        {activeTab === "stats" && (
          <StatsTab />
        )}

        {activeTab === "admins" && (
          <AdminsTab />
        )}

        {activeTab === "orders" && (
          <OrdersTab orders={orders} onUpdateStatus={handleUpdateOrderStatus} />
        )}
      </main>

      {/* Modals */}
      <BookModal
        isOpen={isBookModalOpen}
        onClose={() => {
          setIsBookModalOpen(false);
          setSelectedBook(null);
        }}
        onSave={handleSaveBook}
        book={selectedBook}
      />

      <ProductModal
        isOpen={isProductModalOpen}
        onClose={() => {
          setIsProductModalOpen(false);
          setSelectedProduct(null);
        }}
        onSave={handleSaveItem}
        item={selectedProduct}
      />

      <MusicModal
        isOpen={isMusicModalOpen}
        onClose={() => {
          setIsMusicModalOpen(false);
          setSelectedMusic(null);
        }}
        onSave={handleSaveMusic}
        track={selectedMusic}
      />

      <AudiobookModal
        isOpen={isAudiobookModalOpen}
        onClose={() => {
          setIsAudiobookModalOpen(false);
          setSelectedAudiobook(null);
        }}
        onSave={handleSaveAudiobook}
        audiobook={selectedAudiobook}
      />
    </div>
  );
}
