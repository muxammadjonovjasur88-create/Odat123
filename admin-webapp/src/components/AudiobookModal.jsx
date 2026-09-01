import React, { useState, useEffect } from "react";
import { X, Headphones, AlertCircle, Sparkles, Clock, Mic, Link as LinkIcon, User } from "lucide-react";

export function AudiobookModal({ isOpen, onClose, onSave, audiobook = null }) {
  const isEdit = Boolean(audiobook);

  const [formData, setFormData] = useState({
    title: "",
    author: "",
    narrator: "",
    durationMin: 30,
    desc: "",
    emoji: "🎧",
    audioUrl: "",
    telegramUrl: "https://t.me/odat_fenix",
  });

  const [error, setError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (audiobook) {
      setFormData({
        title: audiobook.title || "",
        author: audiobook.author || "",
        narrator: audiobook.narrator || "",
        durationMin: audiobook.durationMin || 30,
        desc: audiobook.desc || "",
        emoji: audiobook.emoji || "🎧",
        audioUrl: audiobook.audioUrl || "",
        telegramUrl: audiobook.telegramUrl || "https://t.me/odat_fenix",
      });
    } else {
      setFormData({
        title: "",
        author: "",
        narrator: "",
        durationMin: 30,
        desc: "",
        emoji: "🎧",
        audioUrl: "",
        telegramUrl: "https://t.me/odat_fenix",
      });
    }
    setError("");
  }, [audiobook, isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.title.trim()) {
      setError("Audio kitob nomini kiriting.");
      return;
    }

    setIsSubmitting(true);
    setError("");

    try {
      await onSave({
        ...formData,
        durationMin: Math.max(1, parseInt(formData.durationMin || 30, 10)),
      }, audiobook?.id);
      onClose();
    } catch (err) {
      setError(err.message || "Saqlashda xatolik yuz berdi");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm overflow-y-auto">
      <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-lg p-6 shadow-2xl my-8 relative animate-fadeIn">
        {/* Close */}
        <button
          onClick={onClose}
          className="absolute top-5 right-5 text-slate-400 hover:text-slate-200 p-2 rounded-xl hover:bg-slate-800 transition-colors"
        >
          <X size={18} />
        </button>

        {/* Header */}
        <div className="flex items-center gap-3 pb-4 border-b border-slate-800 mb-5">
          <div className="w-10 h-10 rounded-2xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400 font-bold text-lg">
            <span>🎧</span>
          </div>
          <div>
            <h2 className="font-extrabold text-base text-white">
              {isEdit ? "Audio kitobni tahrirlash" : "Yangi Audio Kitob qo'shish"}
            </h2>
            <p className="text-xs text-slate-400">ODAT ilovasida real-vaqtda yangilanadi</p>
          </div>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-400 text-xs flex items-start gap-2">
            <AlertCircle size={16} className="shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Nomi */}
          <div>
            <label className="block text-xs font-bold text-slate-300 mb-1">
              Audio kitob nomi <span className="text-rose-400">*</span>
            </label>
            <input
              type="text"
              required
              placeholder="Masalan: Atom Odatlar yoki Vaqt Qadri"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500 transition-colors"
            />
          </div>

          {/* Muallif va Ovoz beruvchi */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1 flex items-center gap-1">
                <User size={12} className="text-cyan-400" /> Muallif
              </label>
              <input
                type="text"
                placeholder="Jeyms Klir"
                value={formData.author}
                onChange={(e) => setFormData({ ...formData, author: e.target.value })}
                className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1 flex items-center gap-1">
                <Mic size={12} className="text-amber-400" /> Suxandon / Ovoz
              </label>
              <input
                type="text"
                placeholder="O‘zbekcha ovoz"
                value={formData.narrator}
                onChange={(e) => setFormData({ ...formData, narrator: e.target.value })}
                className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
              />
            </div>
          </div>

          {/* Davomiyligi & Emoji */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1 flex items-center gap-1">
                <Clock size={12} className="text-purple-400" /> Davomiyligi (daqiqa)
              </label>
              <input
                type="number"
                min="1"
                placeholder="45"
                value={formData.durationMin}
                onChange={(e) => setFormData({ ...formData, durationMin: e.target.value })}
                className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1">
                Belgisi (Emoji)
              </label>
              <input
                type="text"
                placeholder="🎧"
                value={formData.emoji}
                onChange={(e) => setFormData({ ...formData, emoji: e.target.value })}
                className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500 text-center"
              />
            </div>
          </div>

          {/* Audio Link (MP3 URL) */}
          <div>
            <label className="block text-xs font-bold text-slate-300 mb-1 flex items-center gap-1">
              <LinkIcon size={12} className="text-cyan-400" /> MP3 Audio Havolasi (URL)
            </label>
            <input
              type="url"
              placeholder="https://example.com/audiobook.mp3"
              value={formData.audioUrl}
              onChange={(e) => setFormData({ ...formData, audioUrl: e.target.value })}
              className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
            />
          </div>

          {/* Telegram Havola */}
          <div>
            <label className="block text-xs font-bold text-slate-300 mb-1 flex items-center gap-1">
              ✈️ Telegram Kanal Havolasi
            </label>
            <input
              type="text"
              placeholder="https://t.me/odat_fenix"
              value={formData.telegramUrl}
              onChange={(e) => setFormData({ ...formData, telegramUrl: e.target.value })}
              className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
            />
          </div>

          {/* Tavsif */}
          <div>
            <label className="block text-xs font-bold text-slate-300 mb-1">
              Qisqacha Tavsif
            </label>
            <textarea
              rows="3"
              placeholder="Kitob haqida qisqacha ma'lumot..."
              value={formData.desc}
              onChange={(e) => setFormData({ ...formData, desc: e.target.value })}
              className="w-full bg-slate-800/80 border border-slate-700 rounded-xl p-3 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500 resize-none"
            ></textarea>
          </div>

          {/* Actions */}
          <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-xs font-bold text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            >
              Bekor qilish
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-5 py-2.5 rounded-xl text-xs font-black bg-cyan-500 hover:bg-cyan-400 text-black shadow-lg shadow-cyan-500/20 active:scale-95 transition-all flex items-center gap-2 disabled:opacity-50"
            >
              <Sparkles size={14} />
              <span>{isSubmitting ? "Saqlanmoqda..." : (isEdit ? "Saqlash" : "Qo'shish")}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
