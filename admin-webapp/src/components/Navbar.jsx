import React from "react";
import { LayoutDashboard, BookOpen, ShoppingBag, Music, Headphones, PackageCheck, RefreshCw, BarChart3, ShieldCheck } from "lucide-react";

export function Navbar({ activeTab, setActiveTab, user, onRefresh, isLoading, pendingOrdersCount = 0 }) {
  return (
    <header className="sticky top-0 z-40 bg-zen-void/90 backdrop-blur-xl border-b border-zen-border/80 px-4 py-3 shadow-glass-card">
      <div className="max-w-6xl mx-auto flex items-center justify-between">
        {/* Brand */}
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-cyan-500 via-teal-400 to-emerald-400 flex items-center justify-center font-bold text-lg shadow-lg shadow-cyan-500/20 text-black">
            <span className="text-xl">🌿</span>
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="font-extrabold text-sm sm:text-base tracking-tight text-white flex items-center gap-1.5">
                ODAT <span className="text-cyan-400 font-mono text-[10px] font-bold px-2 py-0.5 rounded-full bg-cyan-500/10 border border-cyan-500/30">ADMIN PANEL</span>
              </h1>
            </div>
            <p className="text-[11px] text-slate-400 flex items-center gap-1.5 mt-0.5">
              <span className="inline-block w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
              {user ? `@${user.username || user.first_name || "Admin"}` : "Admin Shaxboz (658069248)"}
            </p>
          </div>
        </div>

        {/* Refresh button */}
        <div className="flex items-center gap-2">
          <button
            onClick={onRefresh}
            disabled={isLoading}
            className="p-2.5 text-slate-400 hover:text-cyan-400 bg-slate-800/80 hover:bg-slate-700 border border-slate-700 rounded-xl transition-all duration-200 active:scale-95 disabled:opacity-50"
            title="Yangilash"
          >
            <RefreshCw size={16} className={isLoading ? "animate-spin text-cyan-400" : ""} />
          </button>
        </div>
      </div>

      {/* Clean Modern Navigation Tabs */}
      <div className="max-w-6xl mx-auto mt-3 flex p-1.5 bg-slate-900/90 backdrop-blur-md rounded-2xl border border-slate-800 gap-1.5 overflow-x-auto no-scrollbar">
        <button
          onClick={() => setActiveTab("dashboard")}
          className={`flex-1 min-w-[105px] py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all duration-200 ${
            activeTab === "dashboard"
              ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
              : "text-slate-400 hover:text-white hover:bg-slate-800/50"
          }`}
        >
          <LayoutDashboard size={15} />
          <span>Boshqaruv</span>
        </button>

        <button
          onClick={() => setActiveTab("stats")}
          className={`flex-1 min-w-[110px] py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all duration-200 ${
            activeTab === "stats"
              ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
              : "text-slate-400 hover:text-white hover:bg-slate-800/50"
          }`}
        >
          <BarChart3 size={15} />
          <span>Statistika</span>
        </button>

        <button
          onClick={() => setActiveTab("books")}
          className={`flex-1 min-w-[125px] py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all duration-200 ${
            activeTab === "books"
              ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
              : "text-slate-400 hover:text-white hover:bg-slate-800/50"
          }`}
        >
          <BookOpen size={15} />
          <span>Kitoblar (PDF)</span>
        </button>

        <button
          onClick={() => setActiveTab("products")}
          className={`flex-1 min-w-[130px] py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all duration-200 ${
            activeTab === "products"
              ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
              : "text-slate-400 hover:text-white hover:bg-slate-800/50"
          }`}
        >
          <ShoppingBag size={15} />
          <span>Do'kon & Sovg'a</span>
        </button>

        <button
          onClick={() => setActiveTab("music")}
          className={`flex-1 min-w-[120px] py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all duration-200 ${
            activeTab === "music"
              ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
              : "text-slate-400 hover:text-white hover:bg-slate-800/50"
          }`}
        >
          <Music size={15} />
          <span>Musiqa (MP3)</span>
        </button>

        <button
          onClick={() => setActiveTab("audiobooks")}
          className={`flex-1 min-w-[130px] py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all duration-200 ${
            activeTab === "audiobooks"
              ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
              : "text-slate-400 hover:text-white hover:bg-slate-800/50"
          }`}
        >
          <Headphones size={15} />
          <span>Audio Kitoblar</span>
        </button>

        <button
          onClick={() => setActiveTab("orders")}
          className={`flex-1 min-w-[110px] py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all duration-200 relative ${
            activeTab === "orders"
              ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
              : "text-slate-400 hover:text-white hover:bg-slate-800/50"
          }`}
        >
          <PackageCheck size={15} />
          <span>Buyurtmalar</span>
          {pendingOrdersCount > 0 && (
            <span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse"></span>
          )}
        </button>

        <button
          onClick={() => setActiveTab("admins")}
          className={`flex-1 min-w-[110px] py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all duration-200 ${
            activeTab === "admins"
              ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
              : "text-slate-400 hover:text-white hover:bg-slate-800/50"
          }`}
        >
          <ShieldCheck size={15} />
          <span>Adminlar</span>
        </button>
      </div>
    </header>
  );
}
