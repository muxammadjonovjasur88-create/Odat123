import React, { useState } from "react";
import { Headphones, Plus, Search, Edit2, Trash2, Play, Pause, ExternalLink, Clock, Mic, User } from "lucide-react";

export function AudiobooksTab({ audiobooks = [], onAddAudiobook, onEditAudiobook, onDeleteAudiobook }) {
  const [search, setSearch] = useState("");
  const [playingId, setPlayingId] = useState(null);
  const [audioElement, setAudioElement] = useState(null);

  const togglePlay = (book) => {
    if (!book.audioUrl) {
      alert("Ushbu audio kitobda audio fayl havolasi mavjud emas.");
      return;
    }

    if (playingId === book.id) {
      audioElement?.pause();
      setPlayingId(null);
    } else {
      if (audioElement) audioElement.pause();
      const audio = new Audio(book.audioUrl);
      audio.play();
      audio.onended = () => setPlayingId(null);
      setAudioElement(audio);
      setPlayingId(book.id);
    }
  };

  const filtered = audiobooks.filter((b) =>
    (b.title || "").toLowerCase().includes(search.toLowerCase()) ||
    (b.author || "").toLowerCase().includes(search.toLowerCase()) ||
    (b.narrator || "").toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6 animate-fadeIn pb-16">
      {/* Top Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-slate-900/90 border border-slate-800 p-5 rounded-3xl backdrop-blur-md">
        <div>
          <div className="flex items-center gap-2.5">
            <span className="p-2 rounded-xl bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
              <Headphones size={20} />
            </span>
            <h2 className="text-lg font-black text-white">Audio Kitoblar Boshqaruvi</h2>
          </div>
          <p className="text-xs text-slate-400 mt-1">
            ODAT ilovasi audio pleerida real-vaqtda yangilanadigan audio kitoblar ({audiobooks.length} ta)
          </p>
        </div>

        <button
          onClick={onAddAudiobook}
          className="flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-black font-black text-xs shadow-lg shadow-cyan-500/20 active:scale-95 transition-all"
        >
          <Plus size={16} />
          <span>+ Yangi Audio Kitob</span>
        </button>
      </div>

      {/* Search Filter */}
      <div className="relative max-w-md">
        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
        <input
          type="text"
          placeholder="Audio kitob nomi yoki muallifi bo‘yicha qidiruv..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2.5 rounded-2xl bg-slate-900 border border-slate-800 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500 transition-colors"
        />
      </div>

      {/* Audiobooks Grid */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center bg-slate-900/50 border border-slate-800/80 rounded-3xl">
          <span className="text-4xl">🎧</span>
          <p className="text-sm font-bold text-slate-300 mt-3">Hozircha audio kitoblar topilmadi</p>
          <p className="text-xs text-slate-500 mt-1">Yangi audio kitob qo'shish uchun yuqoridagi tugmani bosing</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((b) => (
            <div
              key={b.id}
              className="bg-slate-900/90 border border-slate-800/80 hover:border-cyan-500/40 rounded-3xl p-5 shadow-glass-card transition-all flex flex-col justify-between group"
            >
              <div>
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-cyan-500/20 to-indigo-500/20 border border-cyan-500/30 flex items-center justify-center text-2xl shadow-lg">
                      <span>{b.emoji || "🎧"}</span>
                    </div>
                    <div>
                      <h3 className="font-extrabold text-sm text-white line-clamp-1 group-hover:text-cyan-400 transition-colors">
                        {b.title}
                      </h3>
                      <p className="text-xs text-slate-400 flex items-center gap-1 mt-0.5">
                        <User size={11} className="text-cyan-400" /> {b.author || "Muallif"}
                      </p>
                    </div>
                  </div>

                  {b.audioUrl && (
                    <button
                      onClick={() => togglePlay(b)}
                      className={`p-2.5 rounded-xl border transition-all ${
                        playingId === b.id
                          ? "bg-cyan-500 text-black border-cyan-400 shadow-lg shadow-cyan-500/30"
                          : "bg-slate-800/80 text-cyan-400 border-slate-700 hover:bg-slate-700"
                      }`}
                      title={playingId === b.id ? "Pauza" : "Eshatib ko'rish"}
                    >
                      {playingId === b.id ? <Pause size={16} /> : <Play size={16} />}
                    </button>
                  )}
                </div>

                {/* Metadata */}
                <div className="mt-4 pt-3 border-t border-slate-800/80 flex flex-wrap gap-2 text-[11px]">
                  <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 flex items-center gap-1">
                    <Mic size={11} className="text-amber-400" /> {b.narrator || "O‘zbekcha"}
                  </span>
                  <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 flex items-center gap-1">
                    <Clock size={11} className="text-purple-400" /> {b.durationMin || 30} daqiqa
                  </span>
                </div>

                {b.desc && (
                  <p className="text-xs text-slate-400 mt-2.5 line-clamp-2 bg-slate-950/40 p-2.5 rounded-xl border border-slate-800/50">
                    {b.desc}
                  </p>
                )}
              </div>

              {/* Action Buttons */}
              <div className="mt-4 pt-3 border-t border-slate-800 flex items-center justify-between gap-2">
                {b.telegramUrl ? (
                  <a
                    href={b.telegramUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="text-[11px] font-bold text-cyan-400 hover:underline flex items-center gap-1"
                  >
                    <span>Telegram</span> <ExternalLink size={11} />
                  </a>
                ) : <span />}

                <div className="flex items-center gap-1.5">
                  <button
                    onClick={() => onEditAudiobook(b)}
                    className="p-2 text-slate-400 hover:text-cyan-400 bg-slate-800/60 hover:bg-slate-800 border border-slate-700/60 rounded-xl transition-colors"
                    title="Tahrirlash"
                  >
                    <Edit2 size={14} />
                  </button>
                  <button
                    onClick={() => {
                      if (confirm(`"${b.title}" audio kitobini o‘chirmoqchimisiz?`)) {
                        onDeleteAudiobook(b.id);
                      }
                    }}
                    className="p-2 text-slate-400 hover:text-rose-400 bg-slate-800/60 hover:bg-rose-500/10 border border-slate-700/60 hover:border-rose-500/30 rounded-xl transition-colors"
                    title="O'chirish"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
