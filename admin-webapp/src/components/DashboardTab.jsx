import React, { useState, useEffect } from "react";
import {
  Users,
  Zap,
  Coins,
  Shield,
  BookOpen,
  ShoppingBag,
  Music,
  PackageCheck,
  Plus,
  ArrowUpRight,
  RefreshCw,
  Search,
  Bot,
  Crown,
  UserPlus,
  Trash2,
  CheckCircle2,
  Flame,
} from "lucide-react";
import { api } from "../services/api";

export function DashboardTab({
  books = [],
  items = [],
  orders = [],
  music = [],
  onNavigate,
  onOpenAddBook,
  onOpenAddProduct,
  onOpenAddMusic,
}) {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");

  // Admin delegation states
  const [adminsData, setAdminsData] = useState(null);
  const [newAdminId, setNewAdminId] = useState("");
  const [newAdminName, setNewAdminName] = useState("");
  const [adminActionMsg, setAdminActionMsg] = useState("");
  const [adminSubmitting, setAdminSubmitting] = useState(false);

  const fetchLiveData = async () => {
    try {
      setLoading(true);
      const [statsRes, adminsRes] = await Promise.allSettled([
        api.getLiveStats(),
        api.listAdmins(),
      ]);

      if (statsRes.status === "fulfilled" && statsRes.value?.success) {
        setStats(statsRes.value.stats);
      }
      if (adminsRes.status === "fulfilled" && adminsRes.value?.success) {
        setAdminsData(adminsRes.value);
      }
    } catch (e) {
      console.error("Dashboard fetch error:", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLiveData();
  }, []);

  const handleAddAdmin = async (e) => {
    e.preventDefault();
    if (!newAdminId.trim()) return;

    try {
      setAdminSubmitting(true);
      setAdminActionMsg("");
      const res = await api.addAdmin(newAdminId.trim(), newAdminName.trim());
      if (res.success) {
        setAdminActionMsg(`✅ ${res.message || "Admin qo'shildi!"}`);
        setNewAdminId("");
        setNewAdminName("");
        fetchLiveData();
      }
    } catch (err) {
      setAdminActionMsg(`❌ Xatolik: ${err.message}`);
    } finally {
      setAdminSubmitting(false);
    }
  };

  const handleRemoveAdmin = async (telegramId) => {
    if (!confirm(`Haqiqatan ham ${telegramId} admin huquqini bekor qilmoqchimisiz?`)) return;

    try {
      setAdminSubmitting(true);
      const res = await api.removeAdmin(telegramId);
      if (res.success) {
        setAdminActionMsg(`✅ Admin ${telegramId} o'chirildi!`);
        fetchLiveData();
      }
    } catch (err) {
      setAdminActionMsg(`❌ Xatolik: ${err.message}`);
    } finally {
      setAdminSubmitting(false);
    }
  };

  const topUsers = stats?.topUsers || [];
  const filteredUsers = topUsers.filter(
    (u) =>
      u.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (u.clanName && u.clanName.toLowerCase().includes(searchQuery.toLowerCase())) ||
      u.uid.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const pendingOrdersCount = orders.filter((o) => o.status === "pending" || o.status === "processing").length;
  const isSuperAdmin = adminsData?.isSuperAdmin;
  const admins = adminsData?.admins || [];

  return (
    <div className="space-y-8 animate-fadeIn pb-16">
      {/* Hero Action Banner */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-slate-900 via-indigo-950/80 to-slate-900 border border-cyan-500/30 p-6 md:p-8 shadow-2xl">
        <div className="absolute top-0 right-0 -mr-16 -mt-16 w-64 h-64 rounded-full bg-cyan-500/10 blur-3xl pointer-events-none"></div>
        <div className="absolute bottom-0 left-1/3 -mb-16 w-64 h-64 rounded-full bg-purple-500/10 blur-3xl pointer-events-none"></div>

        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-cyan-500/10 border border-cyan-500/30 text-cyan-400 text-xs font-bold mb-3">
              <Crown size={14} className="text-amber-400" />
              <span>ODAT & Flowa Bosh Admin Paneli (ID: 658069248)</span>
            </div>
            <h1 className="text-2xl md:text-3xl font-black text-white tracking-tight">
              Real-Vaqt Statistikasi & Boshqaruv
            </h1>
            <p className="text-xs md:text-sm text-slate-300 mt-1 max-w-xl">
              Foydalanuvchilar soni, balanslar (PTS & Fenix Coin), AI so‘rovlari, kitoblar (PDF), musiqa (MP3) va sovg‘alarni to‘liq nazorat qiling.
            </p>
          </div>

          {/* Quick Action Buttons */}
          <div className="flex flex-wrap gap-2.5">
            <button
              onClick={onOpenAddBook}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-blue-500 text-black font-black text-xs hover:opacity-90 active:scale-95 transition-all shadow-lg shadow-cyan-500/20"
            >
              <Plus size={16} />
              <span>+ Kitob (PDF)</span>
            </button>

            <button
              onClick={onOpenAddProduct}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-white font-bold text-xs active:scale-95 transition-all"
            >
              <Plus size={16} />
              <span>+ Sovg'a (PTS)</span>
            </button>

            <button
              onClick={onOpenAddMusic}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-white font-bold text-xs active:scale-95 transition-all"
            >
              <Plus size={16} />
              <span>+ Musiqa (MP3)</span>
            </button>

            <button
              onClick={fetchLiveData}
              className="p-2.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 text-cyan-400 rounded-xl transition"
              title="Yangilash"
            >
              <RefreshCw size={16} className={loading ? "animate-spin" : ""} />
            </button>
          </div>
        </div>
      </div>

      {/* 📊 LIVE STATISTICS KPI CARDS */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-base font-black uppercase tracking-wider text-cyan-400 flex items-center gap-2">
            <span>📊</span> Asosiy Real-Vaqt Ko‘rsatkichlari
          </h2>
          <span className="text-xs text-slate-500 font-mono">Real-time Firestore</span>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {/* Total Users */}
          <div className="bg-slate-900/90 border border-cyan-500/30 rounded-2xl p-5 shadow-lg relative overflow-hidden">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-cyan-400">Jami Foydalanuvchilar</span>
              <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center text-cyan-400">
                <Users size={18} />
              </div>
            </div>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="text-3xl font-black text-white">{stats?.totalUsers || 0}</span>
              <span className="text-xs text-slate-400">ta hisob</span>
            </div>
          </div>

          {/* PTS in Circulation */}
          <div className="bg-slate-900/90 border border-amber-500/30 rounded-2xl p-5 shadow-lg relative overflow-hidden">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-amber-400">Muomaladagi PTS</span>
              <div className="w-8 h-8 rounded-lg bg-amber-500/10 flex items-center justify-center text-amber-400">
                <Zap size={18} />
              </div>
            </div>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="text-3xl font-black text-white">
                {(stats?.totalPtsInCirculation || 0).toLocaleString()}
              </span>
              <span className="text-xs text-amber-400 font-bold">⚡ PTS</span>
            </div>
          </div>

          {/* Fenix Coins */}
          <div className="bg-slate-900/90 border border-yellow-500/30 rounded-2xl p-5 shadow-lg relative overflow-hidden">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-yellow-400">Fenix Coinlar</span>
              <div className="w-8 h-8 rounded-lg bg-yellow-500/10 flex items-center justify-center text-yellow-400">
                <Coins size={18} />
              </div>
            </div>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="text-3xl font-black text-white">
                {(stats?.totalFenixCoins || 0).toLocaleString()}
              </span>
              <span className="text-xs text-yellow-400 font-bold">🪙 Coin</span>
            </div>
          </div>

          {/* Total Clans */}
          <div className="bg-slate-900/90 border border-purple-500/30 rounded-2xl p-5 shadow-lg relative overflow-hidden">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-purple-400">Jami Klanlar</span>
              <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center text-purple-400">
                <Shield size={18} />
              </div>
            </div>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="text-3xl font-black text-white">{stats?.totalClans || 0}</span>
              <span className="text-xs text-purple-400 font-bold">ta klan</span>
            </div>
          </div>
        </div>
      </div>

      {/* Second Row Quick Access Cards (Books, Products, Music, Orders) */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div
          onClick={() => onNavigate("books")}
          className="cursor-pointer bg-slate-900/80 border border-slate-800 hover:border-cyan-500/40 rounded-2xl p-4 transition group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-400">📚 Kutubxona</span>
            <ArrowUpRight size={16} className="text-slate-500 group-hover:text-cyan-400 transition" />
          </div>
          <p className="text-2xl font-black text-white mt-2">{books.length}</p>
          <p className="text-[11px] text-cyan-400 font-medium mt-0.5">ta kitob (PDF)</p>
        </div>

        <div
          onClick={() => onNavigate("products")}
          className="cursor-pointer bg-slate-900/80 border border-slate-800 hover:border-cyan-500/40 rounded-2xl p-4 transition group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-400">🎁 Do'kon & Sovg'alar</span>
            <ArrowUpRight size={16} className="text-slate-500 group-hover:text-cyan-400 transition" />
          </div>
          <p className="text-2xl font-black text-white mt-2">{items.length}</p>
          <p className="text-[11px] text-emerald-400 font-medium mt-0.5">ta mahsulot</p>
        </div>

        <div
          onClick={() => onNavigate("music")}
          className="cursor-pointer bg-slate-900/80 border border-slate-800 hover:border-cyan-500/40 rounded-2xl p-4 transition group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-400">🎵 Musiqalar</span>
            <ArrowUpRight size={16} className="text-slate-500 group-hover:text-cyan-400 transition" />
          </div>
          <p className="text-2xl font-black text-white mt-2">{music.length}</p>
          <p className="text-[11px] text-purple-400 font-medium mt-0.5">ta trek (MP3)</p>
        </div>

        <div
          onClick={() => onNavigate("orders")}
          className="cursor-pointer bg-slate-900/80 border border-slate-800 hover:border-cyan-500/40 rounded-2xl p-4 transition group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-400">📦 Buyurtmalar</span>
            {pendingOrdersCount > 0 && (
              <span className="px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300 text-[10px] font-bold animate-pulse">
                {pendingOrdersCount} yangi
              </span>
            )}
          </div>
          <p className="text-2xl font-black text-white mt-2">{orders.length}</p>
          <p className="text-[11px] text-amber-400 font-medium mt-0.5">jami buyurtma</p>
        </div>
      </div>

      {/* 🏆 USER BALANCES & LEADERBOARD TABLE */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h3 className="text-lg font-black text-white flex items-center gap-2">
              <span>🏆</span> Foydalanuvchilar Balanslari & Real-Vaqt Reytingi
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Barcha foydalanuvchilarning PTS (⚡) va Fenix Coin (🪙) hisoblarini bevosita kuzatish
            </p>
          </div>

          <div className="flex items-center gap-3">
            <div className="relative w-full sm:w-64">
              <input
                type="text"
                placeholder="Ism, ID yoki klan qidirish..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500 transition"
              />
            </div>
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 uppercase font-bold tracking-wider">
                <th className="pb-3 pl-3">#</th>
                <th className="pb-3">Foydalanuvchi</th>
                <th className="pb-3">Klan</th>
                <th className="pb-3 text-right">PTS (⚡)</th>
                <th className="pb-3 text-right">Fenix Coin (🪙)</th>
                <th className="pb-3 text-center">Streak</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {filteredUsers.map((user, idx) => (
                <tr key={user.uid} className="hover:bg-slate-800/40 transition">
                  <td className="py-3.5 pl-3 text-slate-500 font-mono font-bold">{idx + 1}</td>
                  <td className="py-3.5">
                    <div className="flex items-center gap-3">
                      <span className="w-8 h-8 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-sm">
                        {user.avatar && user.avatar.length <= 4 ? user.avatar : "👤"}
                      </span>
                      <div>
                        <p className="font-bold text-white leading-tight">{user.name}</p>
                        <p className="text-[10px] text-slate-500 font-mono">{user.uid.substring(0, 10)}...</p>
                      </div>
                    </div>
                  </td>
                  <td className="py-3.5">
                    {user.clanName ? (
                      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-purple-500/10 border border-purple-500/30 text-purple-300 font-bold text-[11px]">
                        🛡️ {user.clanName}
                      </span>
                    ) : (
                      <span className="text-slate-600 text-[11px]">Klansiz</span>
                    )}
                  </td>
                  <td className="py-3.5 text-right font-black text-amber-400 text-sm">
                    {user.totalPoints.toLocaleString()} ⚡
                  </td>
                  <td className="py-3.5 text-right font-black text-yellow-400 text-sm">
                    {user.fenixCoins.toLocaleString()} 🪙
                  </td>
                  <td className="py-3.5 text-center">
                    <span className="inline-flex items-center gap-0.5 px-2.5 py-0.5 rounded-full bg-orange-500/10 text-orange-400 font-bold text-[11px]">
                      🔥 {user.streak} kun
                    </span>
                  </td>
                </tr>
              ))}
              {filteredUsers.length === 0 && (
                <tr>
                  <td colSpan="6" className="py-8 text-center text-slate-500">
                    Foydalanuvchilar topilmadi
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* 🧠 AI QUERY LOGS */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
        <div>
          <h3 className="text-lg font-black text-white flex items-center gap-2">
            <span>🧠</span> Foydalanuvchilar AI Murabbiydan Nimalarni So‘ramoqda
          </h3>
          <p className="text-xs text-slate-400 mt-1">
            Foydalanuvchilar AI murabbiy bilan qilayotgan muloqotlari va so‘rovlar jurnali
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-2">
          {(stats?.recentAiLogs || []).length > 0 ? (
            stats.recentAiLogs.map((log, idx) => (
              <div
                key={log.id || idx}
                className="bg-slate-800/60 border border-slate-700/60 rounded-2xl p-4 space-y-2 hover:border-cyan-500/40 transition"
              >
                <div className="flex items-center justify-between text-[11px]">
                  <span className="font-bold text-cyan-400 flex items-center gap-1">
                    <Bot size={13} /> AI Muloqot Logi
                  </span>
                  <span className="text-slate-500">
                    {log.createdAt ? new Date(log.createdAt._seconds * 1000).toLocaleTimeString() : "Hozir"}
                  </span>
                </div>
                <p className="text-xs text-slate-200 bg-slate-900/80 rounded-xl p-3 border border-slate-800">
                  "{log.query || log.prompt || log.message || "Fokus va intizom mashqi bo'yicha tavsiya"}"
                </p>
              </div>
            ))
          ) : (
            <div className="col-span-2 py-8 text-center text-slate-500 bg-slate-800/30 rounded-2xl border border-dashed border-slate-800">
              Yangi AI so‘rovlari ushbu bo‘limda real vaqtda paydo bo‘ladi
            </div>
          )}
        </div>
      </div>

      {/* 👑 SUPER ADMIN DELEGATION (ADD NEW ADMINS BY ID) */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center text-lg font-bold">
              👑
            </div>
            <div>
              <h3 className="text-base font-black text-white">Admin Qo‘shish & Boshqarish</h3>
              <p className="text-xs text-slate-400">
                Faqat Bosh Admin (`658069248`) Telegram ID orqali yangi adminlarni tayinlay oladi.
              </p>
            </div>
          </div>
        </div>

        {adminActionMsg && (
          <div
            className={`p-3.5 rounded-xl text-xs font-bold border ${
              adminActionMsg.startsWith("✅")
                ? "bg-emerald-500/10 border-emerald-500/30 text-emerald-400"
                : "bg-rose-500/10 border-rose-500/30 text-rose-400"
            }`}
          >
            {adminActionMsg}
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleAddAdmin} className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
          <div>
            <label className="block text-[11px] font-bold text-slate-400 mb-1">Telegram ID raqami *</label>
            <input
              type="text"
              required
              placeholder="Masalan: 123456789"
              value={newAdminId}
              onChange={(e) => setNewAdminId(e.target.value)}
              className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500 font-mono"
            />
          </div>

          <div>
            <label className="block text-[11px] font-bold text-slate-400 mb-1">Admin Ismi / Izoh</label>
            <input
              type="text"
              placeholder="Masalan: Jasur (Menejer)"
              value={newAdminName}
              onChange={(e) => setNewAdminName(e.target.value)}
              className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
            />
          </div>

          <div className="flex items-end">
            <button
              type="submit"
              disabled={adminSubmitting}
              className="w-full bg-gradient-to-r from-cyan-500 to-blue-500 hover:from-cyan-400 hover:to-blue-400 text-black font-black text-xs uppercase py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <UserPlus size={15} />
              <span>{adminSubmitting ? "Qo'shilmoqda..." : "Admin Qilish"}</span>
            </button>
          </div>
        </form>

        {/* Admins List */}
        <div className="space-y-2 pt-3">
          <div className="flex items-center justify-between p-3.5 rounded-xl bg-cyan-950/40 border border-cyan-500/30">
            <div className="flex items-center gap-3">
              <span className="text-base">👑</span>
              <div>
                <p className="font-bold text-white text-xs">Shaxboz Salomov (Super Admin)</p>
                <p className="text-[11px] text-cyan-400 font-mono">Telegram ID: 658069248</p>
              </div>
            </div>
            <span className="px-2 py-0.5 bg-cyan-500/20 text-cyan-300 font-bold text-[10px] rounded-full border border-cyan-500/40">
              Bosh Admin
            </span>
          </div>

          {admins.map((adm) => (
            <div
              key={adm.id}
              className="flex items-center justify-between p-3 rounded-xl bg-slate-800/40 border border-slate-700/60 hover:border-slate-600 transition"
            >
              <div className="flex items-center gap-3">
                <span className="text-base">👤</span>
                <div>
                  <p className="font-bold text-white text-xs">{adm.name || `Admin ${adm.telegramId}`}</p>
                  <p className="text-[10px] text-slate-400 font-mono">Telegram ID: {adm.telegramId || adm.id}</p>
                </div>
              </div>

              <button
                onClick={() => handleRemoveAdmin(adm.telegramId || adm.id)}
                disabled={adminSubmitting}
                className="px-2.5 py-1 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border border-rose-500/30 font-bold text-[11px] rounded-lg transition"
              >
                O‘chirish
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
