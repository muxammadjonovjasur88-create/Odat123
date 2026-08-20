import React, { useState, useEffect } from "react";
import { api } from "../services/api";

export default function AdminsTab() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Form states
  const [newTelegramId, setNewTelegramId] = useState("");
  const [newAdminName, setNewAdminName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [actionMsg, setActionMsg] = useState("");

  const fetchAdmins = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.listAdmins();
      if (res.success) {
        setData(res);
      }
    } catch (err) {
      setError(err.message || "Adminlar ro'yxatini yuklashda xatolik");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAdmins();
  }, []);

  const handleAddAdmin = async (e) => {
    e.preventDefault();
    if (!newTelegramId.trim()) return;

    try {
      setSubmitting(true);
      setActionMsg("");
      const res = await api.addAdmin(newTelegramId.trim(), newAdminName.trim());
      if (res.success) {
        setActionMsg(`✅ ${res.message || "Admin qo'shildi!"}`);
        setNewTelegramId("");
        setNewAdminName("");
        fetchAdmins();
      }
    } catch (err) {
      setActionMsg(`❌ Xatolik: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleRemoveAdmin = async (telegramId) => {
    if (!confirm(`Haqiqatan ham ${telegramId} admin huquqini bekor qilmoqchimisiz?`)) {
      return;
    }

    try {
      setSubmitting(true);
      const res = await api.removeAdmin(telegramId);
      if (res.success) {
        setActionMsg(`✅ Admin ${telegramId} o'chirildi!`);
        fetchAdmins();
      }
    } catch (err) {
      setActionMsg(`❌ Xatolik: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-20">
        <div className="w-12 h-12 border-4 border-cyan-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="mt-4 text-slate-400 font-medium">Adminlar yuklanmoqda...</p>
      </div>
    );
  }

  const isSuperAdmin = data?.isSuperAdmin;
  const admins = data?.admins || [];

  return (
    <div className="space-y-8 animate-fadeIn max-w-4xl mx-auto">
      {/* Super Admin Notice Card */}
      <div className="bg-gradient-to-r from-cyan-950/80 via-slate-900 to-indigo-950/80 border border-cyan-500/30 rounded-3xl p-6 shadow-xl relative overflow-hidden">
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-cyan-500/20 border border-cyan-500/40 flex items-center justify-center text-3xl">
              👑
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-xl font-black text-white">Bosh Admin (Super Admin)</h3>
                <span className="px-2.5 py-0.5 rounded-full bg-cyan-500/20 text-cyan-300 font-bold text-xs border border-cyan-500/40">
                  ID: 658069248
                </span>
              </div>
              <p className="text-xs text-slate-300 mt-1">
                Faqat siz yangi adminlarni ID orqali qo'sha olasiz va ularning huquqlarini bekor qila olasiz.
              </p>
            </div>
          </div>
        </div>
      </div>

      {actionMsg && (
        <div
          className={`p-4 rounded-2xl text-sm font-bold border ${
            actionMsg.startsWith("✅")
              ? "bg-emerald-500/10 border-emerald-500/30 text-emerald-400"
              : "bg-rose-500/10 border-rose-500/30 text-rose-400"
          }`}
        >
          {actionMsg}
        </div>
      )}

      {/* Add New Admin Form (Super Admin Only) */}
      {isSuperAdmin && (
        <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
          <div className="flex items-center gap-2">
            <span className="text-xl">➕</span>
            <div>
              <h4 className="text-base font-bold text-white">Yangi Admin Qo‘shish</h4>
              <p className="text-xs text-slate-400">
                Telegram ID raqamini kiriting, u Mini App ga admin sifatida kirish huquqini oladi.
              </p>
            </div>
          </div>

          <form onSubmit={handleAddAdmin} className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-2">
            <div>
              <label className="block text-xs font-bold text-slate-400 mb-1">Telegram ID raqami *</label>
              <input
                type="text"
                required
                placeholder="Masalan: 123456789"
                value={newTelegramId}
                onChange={(e) => setNewTelegramId(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500 font-mono"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-400 mb-1">Admin Ismi / Izoh</label>
              <input
                type="text"
                placeholder="Masalan: Ali (Kontent Menejer)"
                value={newAdminName}
                onChange={(e) => setNewAdminName(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
              />
            </div>

            <div className="flex items-end">
              <button
                type="submit"
                disabled={submitting}
                className="w-full bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-black font-black text-xs uppercase tracking-wider py-3 rounded-xl shadow-lg shadow-cyan-500/20 transition disabled:opacity-50"
              >
                {submitting ? "Qo'shilmoqda..." : "Admin Qilib Qo'shish 🚀"}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Active Admins List */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
        <h4 className="text-base font-bold text-white flex items-center gap-2">
          <span>🛡️</span> Faol Adminlar Ro‘yxati ({admins.length + 1})
        </h4>

        <div className="space-y-3 pt-2">
          {/* Super Admin Item */}
          <div className="flex items-center justify-between p-4 rounded-2xl bg-cyan-950/30 border border-cyan-500/30">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center text-lg font-bold">
                👑
              </div>
              <div>
                <p className="font-bold text-white text-sm">Shaxboz Salomov (Super Admin)</p>
                <p className="text-xs text-cyan-400 font-mono">Telegram ID: 658069248</p>
              </div>
            </div>
            <span className="px-3 py-1 bg-cyan-500/20 text-cyan-300 font-bold text-xs rounded-full border border-cyan-500/40">
              Asosiy Rahbar
            </span>
          </div>

          {/* Sub Admins */}
          {admins.map((adm) => (
            <div
              key={adm.id}
              className="flex items-center justify-between p-4 rounded-2xl bg-slate-800/50 border border-slate-700/60 hover:border-slate-600 transition"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-slate-700 text-slate-300 flex items-center justify-center text-base font-bold">
                  👤
                </div>
                <div>
                  <p className="font-bold text-white text-sm">{adm.name || `Admin ${adm.telegramId}`}</p>
                  <p className="text-xs text-slate-400 font-mono">Telegram ID: {adm.telegramId || adm.id}</p>
                </div>
              </div>

              {isSuperAdmin && (
                <button
                  onClick={() => handleRemoveAdmin(adm.telegramId || adm.id)}
                  disabled={submitting}
                  className="px-3 py-1.5 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border border-rose-500/30 font-bold text-xs rounded-xl transition"
                >
                  O‘chirish 🗑️
                </button>
              )}
            </div>
          ))}

          {admins.length === 0 && (
            <p className="text-center text-xs text-slate-500 py-4">
              Qo'shimcha tayinlangan adminlar mavjud emas
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
