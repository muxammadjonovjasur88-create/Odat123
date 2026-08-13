import React from "react";
import { ShoppingBag, PackageCheck, BookOpen, RefreshCw, ShieldCheck } from "lucide-react";

export function Navbar({ activeTab, setActiveTab, user, onRefresh, isLoading }) {
  return (
    <header className="sticky top-0 z-30 bg-[#0f172a]/95 backdrop-blur-md border-b border-slate-800 px-4 py-3">
      <div className="max-w-4xl mx-auto flex items-center justify-between">
        {/* Brand */}
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-amber-400 via-yellow-500 to-amber-600 flex items-center justify-center font-bold text-lg shadow-lg shadow-amber-500/20 text-white">
            🪙
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <h1 className="font-bold text-base text-slate-100 leading-none">Odat Admin</h1>
              <span className="bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-[10px] font-semibold px-1.5 py-0.5 rounded-full flex items-center gap-0.5">
                <ShieldCheck size={10} /> WEB APP
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              {user ? `@${user.username || user.first_name || user.id}` : "Telegram Admin"}
            </p>
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-2">
          <button
            onClick={onRefresh}
            disabled={isLoading}
            className="p-2 text-slate-400 hover:text-slate-200 bg-slate-800/80 hover:bg-slate-800 rounded-lg transition-all active:scale-95 disabled:opacity-50"
            title="Yangilash"
          >
            <RefreshCw size={16} className={isLoading ? "animate-spin text-emerald-400" : ""} />
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="max-w-4xl mx-auto mt-3 flex p-1 bg-slate-900/80 rounded-xl border border-slate-800/80 gap-1">
        <button
          onClick={() => setActiveTab("products")}
          className={`flex-1 py-2 px-2 sm:px-3 rounded-lg text-xs font-semibold flex items-center justify-center gap-1.5 transition-all ${
            activeTab === "products"
              ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
              : "text-slate-400 hover:text-slate-200"
          }`}
        >
          <ShoppingBag size={15} />
          <span>Mahsulotlar</span>
        </button>
        <button
          onClick={() => setActiveTab("orders")}
          className={`flex-1 py-2 px-2 sm:px-3 rounded-lg text-xs font-semibold flex items-center justify-center gap-1.5 transition-all ${
            activeTab === "orders"
              ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
              : "text-slate-400 hover:text-slate-200"
          }`}
        >
          <PackageCheck size={15} />
          <span>Buyurtmalar</span>
        </button>
        <button
          onClick={() => setActiveTab("books")}
          className={`flex-1 py-2 px-2 sm:px-3 rounded-lg text-xs font-semibold flex items-center justify-center gap-1.5 transition-all ${
            activeTab === "books"
              ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
              : "text-slate-400 hover:text-slate-200"
          }`}
        >
          <BookOpen size={15} />
          <span>Kitoblar</span>
        </button>
      </div>
    </header>
  );
}
