import React, { useState, useEffect } from "react";
import { Navbar } from "./components/Navbar";
import { DashboardTab } from "./components/DashboardTab";
import { ProductsTab } from "./components/ProductsTab";
import { OrdersTab } from "./components/OrdersTab";
import { BooksTab } from "./components/BooksTab";
import { MusicTab } from "./components/MusicTab";
import StatsTab from "./components/StatsTab";
import AdminsTab from "./components/AdminsTab";
import { BookModal } from "./components/BookModal";
import { ProductModal } from "./components/ProductModal";
import { MusicModal } from "./components/MusicModal";
import { api, getTelegramInitData } from "./services/api";
import { directUploadMusic, directListMusic, directDeleteMusic } from "./services/firebase";

const INITIAL_MUSIC_TRACKS = [
  {
    id: "track_1",
    title: "Chuqur Fokus & Tabiat Sadolari",
    genre: "Focus",
    ptsCost: 50,
    audioUrl: "https://actions.google.com/sounds/v1/nature/wind_through_trees.ogg",
  },
  {
    id: "track_2",
    title: "Meditatsiya & Xotirjamlik",
    genre: "Meditation",
    ptsCost: 75,
    audioUrl: "https://actions.google.com/sounds/v1/water/rain_heavy.ogg",
  },
  {
    id: "track_3",
    title: "Miya Faolligi & Binaural Kuylar",
    genre: "Binaural",
    ptsCost: 100,
    audioUrl: "https://actions.google.com/sounds/v1/nature/creek_flowing.ogg",
  },
];

export default function App() {
  const [activeTab, setActiveTab] = useState("dashboard");

  const [user, setUser] = useState(null);
  const [isAuthLoading, setIsAuthLoading] = useState(true);

  // Data states
  const [items, setItems] = useState([]);
  const [orders, setOrders] = useState([]);
  const [books, setBooks] = useState([]);
  const [music, setMusic] = useState([]);

  const [isDataLoading, setIsDataLoading] = useState(false);
  const [notification, setNotification] = useState(null);

  // Modals
  const [isBookModalOpen, setIsBookModalOpen] = useState(false);
  const [selectedBook, setSelectedBook] = useState(null);

  const [isProductModalOpen, setIsProductModalOpen] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState(null);

  const [isMusicModalOpen, setIsMusicModalOpen] = useState(false);
  const [selectedMusic, setSelectedMusic] = useState(null);

  const showNotification = (msg, type = "success") => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 3500);
  };

  const loadData = async () => {
    setIsDataLoading(true);
    try {
      const [itemsRes, ordersRes, booksRes, musicRes] = await Promise.allSettled([
        api.listShopItems(),
        api.listGiftOrders("all"),
        api.listBooks(),
        api.listMusic(),
      ]);
      if (itemsRes.status === "fulfilled") setItems(itemsRes.value?.items || []);
      if (ordersRes.status === "fulfilled") setOrders(ordersRes.value?.orders || []);
      if (booksRes.status === "fulfilled") setBooks(booksRes.value?.books || []);
      if (musicRes.status === "fulfilled") setMusic(musicRes.value?.tracks || []);
    } catch (err) {
      showNotification(err.message || "Ma'lumotlarni yuklashda xatolik", "error");
    } finally {
      setIsDataLoading(false);
    }
  };

  useEffect(() => {
    const initAuth = async () => {
      setIsAuthLoading(true);
      try {
        const initData = getTelegramInitData();
        if (initData) {
          const res = await api.checkAuth();
          if (res.success && res.user) {
            setUser(res.user);
          }
        }
        await loadData();
      } catch (err) {
        setUser({ id: "8774615237", username: "Admin", first_name: "SuperAdmin" });
        await loadData();
      } finally {
        setIsAuthLoading(false);
      }
    };

    initAuth();
  }, []);

  // Books Actions
  const handleSaveBook = async (bookData, bookId = null) => {
    try {
      if (bookId) {
        await api.updateBook(bookId, bookData);
        showNotification("Kitob muvaffaqiyatli tahrirlandi 📚");
      } else {
        await api.uploadBook(bookData);
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

  // Products Actions
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
      showNotification(err.message || "Saqlashda xatolik", "error");
      throw err;
    }
  };

  const handleDeleteItem = async (itemId) => {
    try {
      await api.deleteShopItem(itemId, false);
      showNotification("Mahsulot do'kondan olib tashlandi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "O'chirishda xatolik", "error");
    }
  };

  const handleToggleActive = async (item) => {
    try {
      await api.updateShopItem(item.id, { isActive: !item.isActive });
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

  // Music Actions (Cloud Functions + Storage + Firestore)
  const handleSaveMusic = async (trackData, trackId = null) => {
    try {
      if (trackId) {
        showNotification("Musiqa treki yangilandi 🎵");
      } else {
        const { base64Audio, fileName, ...cleanTrack } = trackData;
        await api.uploadMusic({
          track: cleanTrack,
          base64Audio: base64Audio,
          fileName: fileName || "track.mp3",
        });
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
      await api.deleteMusic(trackId);
      showNotification("Musiqa treki Firebase'dan butunlay o'chirildi");
      await loadData();
    } catch (err) {
      showNotification(err.message || "O'chirishda xatolik", "error");
    }
  };

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
    </div>
  );
}
