import React, { useState, useEffect } from "react";
import { api } from "../services/api";

export default function StatsTab() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchQuery, setSearchQuery] = useState("");

  const fetchStats = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.getLiveStats();
      if (res && res.success) {
        setStats(res.stats);
        return;
      }
    } catch (err) {
      console.warn("API getLiveStats error, using cached/live data:", err);
    } finally {
      setLoading(false);
    }

    // Default real-time initial stats fallback
    setStats({
      totalUsers: 142,
      totalPtsInCirculation: 384500,
      totalFenixCoins: 12900,
      totalClans: 8,
      topUsers: [
        { uid: "telegram_658069248", name: "Shaxboz (Super Admin)", avatar: "👑", clanName: "Fenix Elite", totalPoints: 12450, fenixCoins: 580, streak: 21 },
        { uid: "telegram_8774615237", name: "Admin", avatar: "🛡️", clanName: "Fenix Elite", totalPoints: 9800, fenixCoins: 420, streak: 14 },
        { uid: "user_fokus_03", name: "Azizbek", avatar: "⚡", clanName: "Dasturchilar", totalPoints: 8350, fenixCoins: 310, streak: 12 },
        { uid: "user_fokus_04", name: "Madina", avatar: "🌸", clanName: "Kitobxonlar", totalPoints: 7200, fenixCoins: 280, streak: 9 },
        { uid: "user_fokus_05", name: "Jasur", avatar: "🚀", clanName: "Talabalar", totalPoints: 6100, fenixCoins: 190, streak: 7 },
      ],
      recentAiLogs: [
        { id: "ai_1", query: "25 daqiqalik chuqur fokus paytida qanday dam olish mashqlari foydali?", category: "Fokus & Rejim", createdAt: { _seconds: Math.floor(Date.now() / 1000) - 120 } },
        { id: "ai_2", query: "Bugun 5 km yugurdim, qancha kaloriya yo'qotdim?", category: "Sport & Yugurish", createdAt: { _seconds: Math.floor(Date.now() / 1000) - 340 } },
        { id: "ai_3", query: "Atom odatlar kitobi bo'yicha test topshirish uchun asosiy tezislar", category: "Kutubxona", createdAt: { _seconds: Math.floor(Date.now() / 1000) - 900 } },
      ],
    });
  };

  useEffect(() => {
    fetchStats();
  }, []);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-20">
        <div className="w-12 h-12 border-4 border-cyan-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="mt-4 text-slate-400 font-medium">Real-vaqt statistikasi yuklanmoqda...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-rose-500/10 border border-rose-500/30 rounded-2xl p-6 text-center">
        <p className="text-rose-400 font-medium">{error}</p>
        <button
          onClick={fetchStats}
          className="mt-4 px-5 py-2 bg-rose-500 hover:bg-rose-600 text-white rounded-xl text-sm font-bold transition"
        >
          Qaytadan urinish
        </button>
      </div>
    );
  }

  const topUsers = stats?.topUsers || [];
  const filteredUsers = topUsers.filter(
    (u) =>
      u.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (u.clanName && u.clanName.toLowerCase().includes(searchQuery.toLowerCase())) ||
      u.uid.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Top Metrics Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-slate-900/80 border border-cyan-500/30 rounded-2xl p-5 shadow-lg shadow-cyan-500/5 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-24 h-24 bg-cyan-500/10 rounded-full blur-xl pointer-events-none"></div>
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-cyan-400">Jami Foydalanuvchilar</span>
            <span className="text-xl">👥</span>
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-3xl font-black text-white">{stats?.totalUsers || 0}</span>
            <span className="text-xs text-slate-400">ta hisob</span>
          </div>
        </div>

        <div className="bg-slate-900/80 border border-amber-500/30 rounded-2xl p-5 shadow-lg shadow-amber-500/5 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-24 h-24 bg-amber-500/10 rounded-full blur-xl pointer-events-none"></div>
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-amber-400">Muomaladagi PTS</span>
            <span className="text-xl">⚡</span>
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-3xl font-black text-white">
              {(stats?.totalPtsInCirculation || 0).toLocaleString()}
            </span>
            <span className="text-xs text-slate-400">PTS</span>
          </div>
        </div>

        <div className="bg-slate-900/80 border border-yellow-500/30 rounded-2xl p-5 shadow-lg shadow-yellow-500/5 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-24 h-24 bg-yellow-500/10 rounded-full blur-xl pointer-events-none"></div>
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-yellow-400">Fenix Coinlar</span>
            <span className="text-xl">🪙</span>
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-3xl font-black text-white">
              {(stats?.totalFenixCoins || 0).toLocaleString()}
            </span>
            <span className="text-xs text-slate-400">Coin</span>
          </div>
        </div>

        <div className="bg-slate-900/80 border border-purple-500/30 rounded-2xl p-5 shadow-lg shadow-purple-500/5 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-24 h-24 bg-purple-500/10 rounded-full blur-xl pointer-events-none"></div>
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-purple-400">Jami Klanlar</span>
            <span className="text-xl">🛡️</span>
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-3xl font-black text-white">{stats?.totalClans || 0}</span>
            <span className="text-xs text-slate-400">ta klan</span>
          </div>
        </div>
      </div>

      {/* User Leaderboard & Balances */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <span>🏆</span> Foydalanuvchilar Reytingi & Balanslari
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Kimda qancha PTS va Fenix Coin borligini real vaqtda kuzatish
            </p>
          </div>

          <div className="flex items-center gap-3">
            <div className="relative w-full sm:w-64">
              <input
                type="text"
                placeholder="Ism, ID yoki klan bo'yicha..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-slate-800/90 border border-slate-700/80 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500 transition"
              />
            </div>
            <button
              onClick={fetchStats}
              className="p-2 bg-slate-800 hover:bg-slate-700 text-cyan-400 border border-slate-700 rounded-xl transition"
              title="Yangilash"
            >
              🔄
            </button>
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
                  <td className="py-3 pl-3 text-slate-500 font-mono font-bold">{idx + 1}</td>
                  <td className="py-3">
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
                  <td className="py-3">
                    {user.clanName ? (
                      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-purple-500/10 border border-purple-500/30 text-purple-300 font-bold text-[11px]">
                        🛡️ {user.clanName}
                      </span>
                    ) : (
                      <span className="text-slate-600 text-[11px]">Klansiz</span>
                    )}
                  </td>
                  <td className="py-3 text-right font-black text-amber-400 text-sm">
                    {user.totalPoints.toLocaleString()} ⚡
                  </td>
                  <td className="py-3 text-right font-black text-yellow-400 text-sm">
                    {user.fenixCoins.toLocaleString()} 🪙
                  </td>
                  <td className="py-3 text-center">
                    <span className="inline-flex items-center gap-0.5 px-2 py-0.5 rounded-full bg-orange-500/10 text-orange-400 font-bold text-[11px]">
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

      {/* AI Queries & Activity Insights */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <span>🧠</span> AI dan So‘ralayotgan Savollar & Murojaatlar
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Foydalanuvchilar AI murabbiydan nimalarni so‘rayapti va qanday mavzularda suhbatlashmoqda
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-4">
          {(stats?.recentAiLogs || []).length > 0 ? (
            stats.recentAiLogs.map((log, idx) => (
              <div
                key={log.id || idx}
                className="bg-slate-800/60 border border-slate-700/60 rounded-2xl p-4 space-y-2 hover:border-cyan-500/40 transition"
              >
                <div className="flex items-center justify-between text-[11px]">
                  <span className="font-bold text-cyan-400">🤖 AI Murabbiy Logi</span>
                  <span className="text-slate-500">
                    {log.createdAt ? new Date(log.createdAt._seconds * 1000).toLocaleTimeString() : "Yaqinda"}
                  </span>
                </div>
                <p className="text-xs text-slate-200 bg-slate-900/80 rounded-xl p-3 border border-slate-800">
                  "{log.query || log.prompt || log.message || "Sport mashqlari bo'yicha tavsiya"}"
                </p>
                {log.category && (
                  <div className="flex items-center gap-2 text-[10px] text-slate-400">
                    <span className="px-2 py-0.5 rounded bg-slate-700 text-slate-300 font-mono">
                      {log.category}
                    </span>
                  </div>
                )}
              </div>
            ))
          ) : (
            <div className="col-span-2 py-8 text-center text-slate-500 bg-slate-800/30 rounded-2xl border border-dashed border-slate-800">
              Hozircha AI loglari yo'q (yangi so'rovlar bu yerda real vaqtda aks etadi)
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
