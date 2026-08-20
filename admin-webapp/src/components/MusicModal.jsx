import React, { useState, useEffect } from "react";
import { X, Music, Upload, Play, Pause, AlertCircle, Loader2, Disc } from "lucide-react";

export function MusicModal({ isOpen, onClose, onSave, track = null }) {
  const isEdit = !!track;

  const [formData, setFormData] = useState({
    title: "",
    genre: "workout",
    audioUrl: "",
    ptsCost: 50,
  });

  const [audioFile, setAudioFile] = useState(null);
  const [audioFileName, setAudioFileName] = useState("");
  const [isPlaying, setIsPlaying] = useState(false);
  const [audioPreviewUrl, setAudioPreviewUrl] = useState("");
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (track) {
      setFormData({
        title: track.title || "",
        genre: track.category || track.genre || "workout",
        audioUrl: track.audioUrl || "",
        ptsCost: track.ptsCost !== undefined ? track.ptsCost : 50,
      });
      setAudioPreviewUrl(track.audioUrl || "");
      setAudioFileName(track.audioUrl ? "Mavjud audio fayl" : "");
    } else {
      setFormData({
        title: "",
        genre: "workout",
        audioUrl: "",
        ptsCost: 50,
      });
      setAudioPreviewUrl("");
      setAudioFileName("");
    }
    setAudioFile(null);
    setIsPlaying(false);
    setError("");
    setIsUploading(false);
  }, [track, isOpen]);

  if (!isOpen) return null;

  const handleFileChange = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith("audio/") && !file.name.endsWith(".mp3")) {
      setError("Faqat MP3 yoki audio formatdagi fayllarni tanlang.");
      return;
    }

    setAudioFile(file);
    setAudioFileName(file.name);
    setAudioPreviewUrl(URL.createObjectURL(file));
    if (!formData.title) {
      const cleanName = file.name.replace(/\.[^/.]+$/, "");
      setFormData((prev) => ({ ...prev, title: cleanName }));
    }
    setError("");
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.title.trim()) {
      setError("Trek nomini kiriting.");
      return;
    }
    if (!formData.audioUrl.trim() && !audioFile) {
      setError("Audio (MP3) faylni tanlang yoki Audio URL manzilini kiriting.");
      return;
    }

    setIsUploading(true);
    setError("");

    try {
      let base64Audio = null;
      if (audioFile) {
        const reader = new FileReader();
        const base64Promise = new Promise((resolve, reject) => {
          reader.onload = () => resolve(reader.result);
          reader.onerror = reject;
        });
        reader.readAsDataURL(audioFile);
        base64Audio = await base64Promise;
      }

      await onSave({
        ...formData,
        category: formData.genre,
        base64Audio,
        fileName: audioFileName || audioFile?.name || "track.mp3",
      }, track?.id);
      onClose();
    } catch (err) {
      setError(err.message || "Saqlashda xatolik yuz berdi");
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-zen-void/80 backdrop-blur-md animate-fadeIn">
      <div className="relative w-full max-w-lg rounded-3xl bg-zen-surface border border-zen-border shadow-2xl overflow-hidden p-6 md:p-8">
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-zen-border">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-center text-purple-400">
              <Music size={20} />
            </div>
            <div>
              <h2 className="font-extrabold text-base text-zen-text">
                {isEdit ? "Trekni tahrirlash" : "Yangi Musiqa (MP3) yuklash"}
              </h2>
              <p className="text-xs text-zen-subtext">Mashg'ulot, bilim olish, meditatsiya va o'yin kuylari</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-zen-subtext hover:text-zen-text hover:bg-zen-muted transition-all"
          >
            <X size={18} />
          </button>
        </div>

        {error && (
          <div className="mt-4 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-xs flex items-center gap-2">
            <AlertCircle size={16} />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="mt-5 space-y-4">
          {/* File Upload Box */}
          <div>
            <label className="block text-xs font-bold text-zen-subtext mb-1.5">
              Audio Fayl (.mp3)
            </label>
            <div className="relative border-2 border-dashed border-zen-border hover:border-purple-400/50 rounded-2xl p-4 text-center bg-zen-muted/30 transition-all">
              <input
                type="file"
                accept="audio/*,.mp3"
                onChange={handleFileChange}
                className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
              />
              <Upload size={24} className="mx-auto text-purple-400 mb-1.5" />
              <p className="text-xs font-bold text-zen-text truncate">
                {audioFileName || "MP3 faylni tanlang yoki shu yerga tashlang"}
              </p>
              <p className="text-[11px] text-zen-subtext mt-0.5">MP3, WAV yoki AAC audio format</p>
            </div>
          </div>

          {/* Audio Preview Player if available */}
          {audioPreviewUrl && (
            <div className="p-3 rounded-xl bg-zen-muted/60 border border-zen-border flex items-center gap-3">
              <Disc size={20} className="text-purple-400 animate-spin" />
              <audio controls src={audioPreviewUrl} className="w-full h-8" />
            </div>
          )}

          {/* Title */}
          <div>
            <label className="block text-xs font-bold text-zen-subtext mb-1">
              Trek Nomi *
            </label>
            <input
              type="text"
              required
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              placeholder="Masalan: Chuqur Fokus & Motivatsiya"
              className="w-full px-3.5 py-2.5 rounded-xl bg-zen-muted border border-zen-border text-zen-text text-xs focus:outline-none focus:border-purple-400 transition-all"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            {/* Genre / Kategoriya */}
            <div>
              <label className="block text-xs font-bold text-zen-subtext mb-1">
                Kategoriya / Rejim
              </label>
              <select
                value={formData.genre}
                onChange={(e) => setFormData({ ...formData, genre: e.target.value })}
                className="w-full px-3 py-2.5 rounded-xl bg-zen-muted border border-zen-border text-zen-text text-xs focus:outline-none focus:border-purple-400 transition-all cursor-pointer"
              >
                <option value="workout">🏋️ Mashg'ulot</option>
                <option value="study">📚 Bilim olish</option>
                <option value="zen">🧘 Meditatsiya</option>
                <option value="gaming">🎮 O'yin</option>
                <option value="motivation">⚡ Motivatsiya</option>
              </select>
            </div>

            {/* PTS Cost */}
            <div>
              <label className="block text-xs font-bold text-zen-subtext mb-1">
                Narxi (PTS)
              </label>
              <input
                type="number"
                min="0"
                value={formData.ptsCost}
                onChange={(e) => setFormData({ ...formData, ptsCost: Number(e.target.value) })}
                className="w-full px-3 py-2.5 rounded-xl bg-zen-muted border border-zen-border text-zen-text text-xs focus:outline-none focus:border-purple-400 transition-all"
              />
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center justify-end gap-3 pt-3 border-t border-zen-border mt-6">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2.5 rounded-xl text-xs font-bold text-zen-subtext hover:text-zen-text hover:bg-zen-muted transition-all"
            >
              Bekor qilish
            </button>
            <button
              type="submit"
              disabled={isUploading}
              className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-purple-500 to-indigo-500 text-white text-xs font-bold shadow-lg hover:opacity-90 active:scale-95 transition-all flex items-center gap-2 disabled:opacity-50"
            >
              {isUploading ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  <span>Yuklanmoqda...</span>
                </>
              ) : (
                <span>{isEdit ? "O'zgarishlarni saqlash" : "Yuklash & Saqlash"}</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
