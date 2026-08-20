import React, { useState } from "react";
import { Music, Plus, Trash2, Edit3, Play, Pause, Disc } from "lucide-react";

const CATEGORIES = [
  { id: "all", label: "Barchasi", emoji: "🔥" },
  { id: "workout", label: "Mashg'ulot", emoji: "🏋️" },
  { id: "study", label: "Bilim olish", emoji: "📚" },
  { id: "zen", label: "Meditatsiya", emoji: "🧘" },
  { id: "gaming", label: "O'yin", emoji: "🎮" },
  { id: "motivation", label: "Motivatsiya", emoji: "⚡" },
];

const CATEGORY_MAP = {
  workout: { label: "Mashg'ulot", emoji: "🏋️", style: "bg-emerald-500/10 text-emerald-400 border-emerald-500/30" },
  study: { label: "Bilim olish", emoji: "📚", style: "bg-cyan-500/10 text-cyan-400 border-cyan-500/30" },
  zen: { label: "Meditatsiya", emoji: "🧘", style: "bg-purple-500/10 text-purple-400 border-purple-500/30" },
  gaming: { label: "O'yin", emoji: "🎮", style: "bg-rose-500/10 text-rose-400 border-rose-500/30" },
  motivation: { label: "Motivatsiya", emoji: "⚡", style: "bg-amber-500/10 text-amber-400 border-amber-500/30" },
};

export function MusicTab({ music = [], onAddMusic, onEditMusic, onDeleteMusic }) {
  const [playingId, setPlayingId] = useState(null);
  const [audioElement, setAudioElement] = useState(null);
  const [selectedCategory, setSelectedCategory] = useState("all");

  const togglePlay = (track) => {
    if (playingId === track.id) {
      audioElement?.pause();
      setPlayingId(null);
    } else {
      if (audioElement) audioElement.pause();
      const audio = new Audio(track.audioUrl);
      audio.play();
      audio.onended = () => setPlayingId(null);
      setAudioElement(audio);
      setPlayingId(track.id);
    }
  };

  const filteredMusic = selectedCategory === "all"
    ? music
    : music.filter((t) => {
        const cat = (t.category || t.genre || "").toLowerCase();
        return cat === selectedCategory || (selectedCategory === "study" && cat.includes("focus"));
      });

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* Top Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-2xl bg-zen-surface border border-zen-border">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-center text-purple-400">
            <Music size={20} />
          </div>
          <div>
            <h2 className="font-extrabold text-base text-zen-text">Musiqa & Fokus Audio</h2>
            <p className="text-xs text-zen-subtext">Mashg'ulot, bilim olish, meditatsiya va o'yin kuylari (MP3)</p>
          </div>
        </div>

        <button
          onClick={onAddMusic}
          className="flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-purple-500 hover:bg-purple-600 text-white font-bold text-xs shadow-lg active:scale-95 transition-all"
        >
          <Plus size={16} />
          <span>+ Yangi Musiqa (MP3)</span>
        </button>
      </div>

      {/* Category Filter Chips */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
        {CATEGORIES.map((cat) => {
          const isSelected = selectedCategory === cat.id;
          return (
            <button
              key={cat.id}
              onClick={() => setSelectedCategory(cat.id)}
              className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all ${
                isSelected
                  ? "bg-purple-500 text-white shadow-md shadow-purple-500/20"
                  : "bg-zen-surface text-zen-subtext hover:text-zen-text hover:bg-zen-muted border border-zen-border"
              }`}
            >
              <span>{cat.emoji}</span>
              <span>{cat.label}</span>
            </button>
          );
        })}
      </div>

      {/* Music Grid */}
      {filteredMusic.length === 0 ? (
        <div className="py-16 text-center rounded-2xl bg-zen-surface/60 border border-zen-border text-zen-subtext">
          <Music size={36} className="mx-auto text-purple-400/40 mb-3" />
          <p className="text-sm font-semibold text-zen-text">
            {selectedCategory === "all"
              ? "Hozircha musiqa treklari mavjud emas"
              : "Ushbu toifada treklar topilmadi"}
          </p>
          <p className="text-xs text-zen-subtext mt-1">Mobil ilovaga audio kuylarni yuklang</p>
          <button
            onClick={onAddMusic}
            className="mt-4 px-4 py-2.5 rounded-xl bg-purple-500 text-white font-bold text-xs hover:bg-purple-600 transition-all shadow-md"
          >
            + Musiqa qo'shish
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredMusic.map((track) => {
            const isThisPlaying = playingId === track.id;
            const trackCat = (track.category || track.genre || "workout").toLowerCase();
            const catInfo = CATEGORY_MAP[trackCat] || { label: track.genre || "Audio", emoji: "🎵", style: "bg-purple-500/10 text-purple-400 border-purple-500/30" };

            return (
              <div
                key={track.id}
                className={`p-4 rounded-2xl bg-zen-surface border transition-all duration-200 ${
                  isThisPlaying ? "border-purple-400/60 shadow-lg shadow-purple-500/10" : "border-zen-border hover:border-purple-400/30"
                }`}
              >
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => togglePlay(track)}
                    className={`w-12 h-12 rounded-xl flex items-center justify-center transition-transform active:scale-95 ${
                      isThisPlaying
                        ? "bg-purple-500 text-white animate-pulse"
                        : "bg-purple-500/10 text-purple-400 hover:bg-purple-500/20"
                    }`}
                  >
                    {isThisPlaying ? <Pause size={20} /> : <Play size={20} className="ml-0.5" />}
                  </button>

                  <div className="min-w-0 flex-1">
                    <h3 className="font-bold text-xs text-zen-text truncate">{track.title}</h3>
                    <div className="flex items-center gap-2 mt-1">
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md border flex items-center gap-1 ${catInfo.style}`}>
                        <span>{catInfo.emoji}</span>
                        <span>{catInfo.label}</span>
                      </span>
                    </div>
                    <div className="flex items-center gap-2 mt-1.5">
                      <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded bg-purple-500/10 text-purple-300">
                        {track.ptsCost ? `${track.ptsCost} PTS` : "Bepul"}
                      </span>
                      {isThisPlaying && (
                        <span className="text-[10px] text-purple-400 font-bold flex items-center gap-1">
                          <Disc size={12} className="animate-spin" /> Eshitilmoqda
                        </span>
                      )}
                    </div>
                  </div>
                </div>

                <div className="flex items-center justify-end gap-2 mt-3 pt-3 border-t border-zen-border/60">
                  <button
                    onClick={() => onEditMusic(track)}
                    className="p-1.5 text-zen-subtext hover:text-zen-text hover:bg-zen-muted rounded-lg transition-all"
                    title="Tahrirlash"
                  >
                    <Edit3 size={15} />
                  </button>
                  <button
                    onClick={() => onDeleteMusic(track.id)}
                    className="p-1.5 text-zen-subtext hover:text-red-400 hover:bg-zen-muted rounded-lg transition-all"
                    title="O'chirish"
                  >
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
