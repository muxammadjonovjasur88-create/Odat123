import React, { useState } from "react";
import { Plus, Edit2, Trash2, Eye, EyeOff, Coins, Tag, Box, AlertTriangle, CheckCircle2 } from "lucide-react";
import { ProductModal } from "./ProductModal";

export function ProductsTab({ items = [], onSaveItem, onDeleteItem, onToggleActive, isLoading }) {
  const [filterType, setFilterType] = useState("all");
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState(null);
  const [deletingItem, setDeletingItem] = useState(null);

  const filteredItems = items.filter((item) => {
    if (filterType === "coupon") return item.type === "coupon";
    if (filterType === "gift") return item.type === "gift";
    if (filterType === "inactive") return item.isActive === false;
    return true;
  });

  const handleEdit = (item) => {
    setEditingItem(item);
    setIsModalOpen(true);
  };

  const handleCreateNew = () => {
    setEditingItem(null);
    setIsModalOpen(true);
  };

  const confirmDelete = async () => {
    if (!deletingItem) return;
    await onDeleteItem(deletingItem.id);
    setDeletingItem(null);
  };

  return (
    <div className="space-y-4">
      {/* Top Header & Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        {/* Filter Chips */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 scrollbar-none">
          <button
            onClick={() => setFilterType("all")}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
              filterType === "all"
                ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
                : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
            }`}
          >
            Barchasi ({items.length})
          </button>
          <button
            onClick={() => setFilterType("coupon")}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
              filterType === "coupon"
                ? "bg-amber-500 text-slate-950 font-bold shadow-md shadow-amber-500/20"
                : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
            }`}
          >
            🎟️ Kuponlar ({items.filter((i) => i.type === "coupon").length})
          </button>
          <button
            onClick={() => setFilterType("gift")}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
              filterType === "gift"
                ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
                : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
            }`}
          >
            🎁 Sovg'alar ({items.filter((i) => i.type === "gift").length})
          </button>
          <button
            onClick={() => setFilterType("inactive")}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
              filterType === "inactive"
                ? "bg-rose-500 text-white shadow-md shadow-rose-500/20"
                : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
            }`}
          >
            🚫 Noaktiv ({items.filter((i) => i.isActive === false).length})
          </button>
        </div>

        {/* Add Product Button */}
        <button
          onClick={handleCreateNew}
          className="w-full sm:w-auto px-4 py-2 bg-emerald-500 hover:bg-emerald-400 active:scale-95 text-white text-xs font-bold rounded-xl shadow-lg shadow-emerald-500/20 flex items-center justify-center gap-1.5 transition-all"
        >
          <Plus size={16} />
          <span>Yangi Mahsulot</span>
        </button>
      </div>

      {/* Product List */}
      {isLoading ? (
        <div className="py-12 text-center text-slate-500 text-xs flex flex-col items-center gap-2">
          <div className="w-6 h-6 border-2 border-emerald-500 border-t-transparent rounded-full animate-spin" />
          <span>Mahsulotlar yuklanmoqda...</span>
        </div>
      ) : filteredItems.length === 0 ? (
        <div className="py-12 text-center text-slate-500 text-xs border border-dashed border-slate-800 rounded-2xl p-6">
          <Box size={32} className="mx-auto mb-2 opacity-50" />
          <p className="font-semibold text-slate-400">Mahsulotlar topilmadi</p>
          <p className="mt-1 text-slate-600">"Yangi Mahsulot" tugmasi orqali birinchi mahsulotni qo'shing.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {filteredItems.map((item) => (
            <div
              key={item.id}
              className={`bg-slate-900 border rounded-2xl p-3.5 flex gap-3 relative transition-all ${
                item.isActive === false ? "border-slate-800 opacity-60" : "border-slate-800 hover:border-slate-700"
              }`}
            >
              {/* Product Image */}
              <div className="w-20 h-20 rounded-xl overflow-hidden bg-slate-950 border border-slate-800 shrink-0 relative">
                <img
                  src={item.imageUrl}
                  alt={item.title}
                  className="w-full h-full object-cover"
                  onError={(e) => {
                    e.target.src = "https://via.placeholder.com/150?text=Odat";
                  }}
                />
                <span
                  className={`absolute top-1 left-1 px-1.5 py-0.5 text-[9px] font-bold rounded-md uppercase tracking-wider ${
                    item.type === "coupon" ? "bg-amber-500 text-slate-950" : "bg-emerald-500 text-white"
                  }`}
                >
                  {item.type === "coupon" ? "Kupon" : "Sovg'a"}
                </span>
              </div>

              {/* Details */}
              <div className="flex-1 min-w-0 flex flex-col justify-between">
                <div>
                  <div className="flex items-start justify-between gap-1">
                    <h3 className="font-semibold text-xs text-slate-100 truncate">{item.title}</h3>
                  </div>

                  {item.partnerName && (
                    <p className="text-[11px] text-amber-400/90 font-medium truncate mt-0.5">
                      🏬 {item.partnerName} {item.discountText ? `• ${item.discountText}` : ""}
                    </p>
                  )}

                  <div className="flex items-center gap-2 mt-1.5">
                    <span className="bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-[11px] font-bold px-2 py-0.5 rounded-lg flex items-center gap-1">
                      <Coins size={11} /> {item.pointsCost} ball
                    </span>

                    <span className="text-[11px] text-slate-400">
                      {item.stock !== null && item.stock !== undefined ? (
                        item.stock > 0 ? (
                          `📦 ${item.stock} dona`
                        ) : (
                          <span className="text-rose-400 font-semibold">Tugadi</span>
                        )
                      ) : (
                        "♾️ Cheksiz"
                      )}
                    </span>
                  </div>
                </div>

                {/* Card Actions */}
                <div className="flex items-center justify-between pt-2 border-t border-slate-800/80 mt-2">
                  <button
                    onClick={() => onToggleActive(item)}
                    className={`text-[10px] font-semibold px-2 py-1 rounded-lg flex items-center gap-1 transition-colors ${
                      item.isActive !== false
                        ? "bg-slate-800 text-emerald-400 hover:bg-slate-700"
                        : "bg-rose-500/10 text-rose-400 hover:bg-rose-500/20"
                    }`}
                  >
                    {item.isActive !== false ? <Eye size={12} /> : <EyeOff size={12} />}
                    {item.isActive !== false ? "Faol" : "Noaktiv"}
                  </button>

                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => handleEdit(item)}
                      className="p-1.5 text-slate-400 hover:text-slate-200 hover:bg-slate-800 rounded-lg transition-colors"
                      title="Tahrirlash"
                    >
                      <Edit2 size={13} />
                    </button>
                    <button
                      onClick={() => setDeletingItem(item)}
                      className="p-1.5 text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 rounded-lg transition-colors"
                      title="O'chirish"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Edit/Create Modal */}
      <ProductModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSave={(data) => onSaveItem(data, editingItem?.id)}
        item={editingItem}
      />

      {/* Delete Confirmation Modal */}
      {deletingItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-sm w-full p-5 shadow-2xl space-y-4">
            <div className="w-10 h-10 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center justify-center mx-auto">
              <AlertTriangle size={20} />
            </div>
            <div className="text-center">
              <h3 className="font-bold text-sm text-slate-100">Mahsulotni o'chirish</h3>
              <p className="text-xs text-slate-400 mt-1">
                "<span className="text-slate-200">{deletingItem.title}</span>" mahsulotini do'kondan olib tashlamoqchimisiz?
              </p>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={() => setDeletingItem(null)}
                className="flex-1 py-2 rounded-xl border border-slate-800 text-xs font-semibold text-slate-400 hover:text-slate-200 hover:bg-slate-800/50"
              >
                Bekor qilish
              </button>
              <button
                onClick={confirmDelete}
                className="flex-1 py-2 rounded-xl bg-rose-500 hover:bg-rose-400 text-xs font-semibold text-white shadow-lg shadow-rose-500/20"
              >
                O'chirish (Noaktiv)
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
