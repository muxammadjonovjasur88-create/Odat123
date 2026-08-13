import React, { useState } from "react";
import { Phone, MapPin, Calendar, Clock, CheckCircle2, Truck, PackageCheck, XCircle, Copy, Check, MessageSquare, Loader2 } from "lucide-react";

const STATUS_CONFIG = {
  pending: { label: "Kutilmoqda", bg: "bg-amber-500/10", border: "border-amber-500/30", text: "text-amber-400", icon: Clock },
  confirmed: { label: "Tasdiqlandi", bg: "bg-blue-500/10", border: "border-blue-500/30", text: "text-blue-400", icon: CheckCircle2 },
  shipped: { label: "Yo'lda", bg: "bg-purple-500/10", border: "border-purple-500/30", text: "text-purple-400", icon: Truck },
  delivered: { label: "Yetkazildi", bg: "bg-emerald-500/10", border: "border-emerald-500/30", text: "text-emerald-400", icon: PackageCheck },
  cancelled: { label: "Bekor qilindi", bg: "bg-rose-500/10", border: "border-rose-500/30", text: "text-rose-400", icon: XCircle },
};

export function OrdersTab({ orders = [], onUpdateStatus, isLoading }) {
  const [selectedStatusFilter, setSelectedStatusFilter] = useState("pending"); // Default to pending so admin sees urgent new orders first
  const [copiedId, setCopiedId] = useState(null);
  const [editingNoteId, setEditingNoteId] = useState(null);
  const [noteText, setNoteText] = useState("");
  const [updatingOrderId, setUpdatingOrderId] = useState(null);

  const filteredOrders = orders.filter((order) => {
    if (selectedStatusFilter === "all") return true;
    return order.status === selectedStatusFilter;
  });

  const handleCopyPhone = (phoneNumber, id) => {
    navigator.clipboard.writeText(phoneNumber);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleStatusChange = async (orderId, newStatus) => {
    setUpdatingOrderId(orderId);
    try {
      await onUpdateStatus(orderId, newStatus);
    } finally {
      setUpdatingOrderId(null);
    }
  };

  const handleSaveNote = async (orderId) => {
    setUpdatingOrderId(orderId);
    try {
      const order = orders.find((o) => o.id === orderId);
      await onUpdateStatus(orderId, order?.status || "pending", noteText);
      setEditingNoteId(null);
    } finally {
      setUpdatingOrderId(null);
    }
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return "";
    const date = timestamp.seconds ? new Date(timestamp.seconds * 1000) : new Date(timestamp);
    return date.toLocaleString("uz-UZ", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  return (
    <div className="space-y-4">
      {/* Filter Chips */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
        <button
          onClick={() => setSelectedStatusFilter("pending")}
          className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
            selectedStatusFilter === "pending"
              ? "bg-amber-500 text-slate-950 font-bold shadow-md shadow-amber-500/20"
              : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
          }`}
        >
          ⏳ Kutilmoqda ({orders.filter((o) => o.status === "pending").length})
        </button>

        <button
          onClick={() => setSelectedStatusFilter("confirmed")}
          className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
            selectedStatusFilter === "confirmed"
              ? "bg-blue-500 text-white shadow-md shadow-blue-500/20"
              : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
          }`}
        >
          ✅ Tasdiqlandi ({orders.filter((o) => o.status === "confirmed").length})
        </button>

        <button
          onClick={() => setSelectedStatusFilter("shipped")}
          className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
            selectedStatusFilter === "shipped"
              ? "bg-purple-500 text-white shadow-md shadow-purple-500/20"
              : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
          }`}
        >
          🚚 Yo'lda ({orders.filter((o) => o.status === "shipped").length})
        </button>

        <button
          onClick={() => setSelectedStatusFilter("delivered")}
          className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
            selectedStatusFilter === "delivered"
              ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
              : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
          }`}
        >
          🎁 Yetkazildi ({orders.filter((o) => o.status === "delivered").length})
        </button>

        <button
          onClick={() => setSelectedStatusFilter("cancelled")}
          className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
            selectedStatusFilter === "cancelled"
              ? "bg-rose-500 text-white shadow-md shadow-rose-500/20"
              : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
          }`}
        >
          ❌ Bekor qilindi ({orders.filter((o) => o.status === "cancelled").length})
        </button>

        <button
          onClick={() => setSelectedStatusFilter("all")}
          className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
            selectedStatusFilter === "all"
              ? "bg-slate-200 text-slate-950 font-bold"
              : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
          }`}
        >
          Barchasi ({orders.length})
        </button>
      </div>

      {/* Orders List */}
      {isLoading ? (
        <div className="py-12 text-center text-slate-500 text-xs flex flex-col items-center gap-2">
          <div className="w-6 h-6 border-2 border-emerald-500 border-t-transparent rounded-full animate-spin" />
          <span>Buyurtmalar yuklanmoqda...</span>
        </div>
      ) : filteredOrders.length === 0 ? (
        <div className="py-12 text-center text-slate-500 text-xs border border-dashed border-slate-800 rounded-2xl p-6">
          <PackageCheck size={32} className="mx-auto mb-2 opacity-50 text-slate-600" />
          <p className="font-semibold text-slate-400">Bu statusda buyurtmalar yo'q</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredOrders.map((order) => {
            const statusConfig = STATUS_CONFIG[order.status] || STATUS_CONFIG.pending;
            const StatusIcon = statusConfig.icon;
            const isUpdating = updatingOrderId === order.id;

            return (
              <div
                key={order.id}
                className="bg-slate-900 border border-slate-800 hover:border-slate-700/80 rounded-2xl p-4 space-y-3 shadow-lg transition-all"
              >
                {/* Header: Customer Name & Status Badge */}
                <div className="flex items-start justify-between gap-2 border-b border-slate-800/80 pb-3">
                  <div>
                    <h3 className="font-bold text-sm text-slate-100">{order.fullName || "Ism ko'rsatilmadi"}</h3>
                    <p className="text-[11px] text-slate-500 flex items-center gap-1 mt-0.5">
                      <Calendar size={12} /> {formatDate(order.createdAt)}
                    </p>
                  </div>

                  <div
                    className={`px-2.5 py-1 rounded-xl border text-[11px] font-bold flex items-center gap-1.5 ${statusConfig.bg} ${statusConfig.border} ${statusConfig.text}`}
                  >
                    <StatusIcon size={13} />
                    <span>{statusConfig.label}</span>
                  </div>
                </div>

                {/* Ordered Product Card */}
                {order.shopItem && (
                  <div className="flex items-center gap-3 bg-slate-950/80 border border-slate-800/80 rounded-xl p-2.5">
                    <img
                      src={order.shopItem.imageUrl}
                      alt={order.shopItem.title}
                      className="w-12 h-12 rounded-lg object-cover bg-slate-900 border border-slate-800 shrink-0"
                    />
                    <div className="min-w-0 flex-1">
                      <h4 className="font-semibold text-xs text-slate-200 truncate">{order.shopItem.title}</h4>
                      <p className="text-[11px] text-emerald-400 font-medium mt-0.5">
                        💎 {order.shopItem.pointsCost} ball
                      </p>
                    </div>
                  </div>
                )}

                {/* Shipping & Contact Details */}
                <div className="space-y-2 text-xs">
                  {/* Phone number */}
                  <div className="flex items-center justify-between bg-slate-950/40 p-2 rounded-xl border border-slate-800/50">
                    <div className="flex items-center gap-2 text-slate-300">
                      <Phone size={14} className="text-emerald-400 shrink-0" />
                      <a
                        href={`tel:${order.phoneNumber}`}
                        className="font-mono font-semibold text-emerald-400 hover:underline"
                      >
                        {order.phoneNumber}
                      </a>
                    </div>
                    <button
                      onClick={() => handleCopyPhone(order.phoneNumber, order.id)}
                      className="px-2 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white rounded-lg text-[10px] font-semibold flex items-center gap-1 transition-colors"
                    >
                      {copiedId === order.id ? (
                        <>
                          <Check size={11} className="text-emerald-400" />
                          <span>Nusxalandi</span>
                        </>
                      ) : (
                        <>
                          <Copy size={11} />
                          <span>Nusxalash</span>
                        </>
                      )}
                    </button>
                  </div>

                  {/* Delivery Address */}
                  <div className="flex items-start gap-2 bg-slate-950/40 p-2.5 rounded-xl border border-slate-800/50 text-slate-300">
                    <MapPin size={14} className="text-amber-400 shrink-0 mt-0.5" />
                    <span className="leading-relaxed text-[11px] font-medium">{order.address || "Manzil ko'rsatilmagan"}</span>
                  </div>

                  {/* Admin Note if exists */}
                  {order.adminNote && (
                    <div className="bg-amber-500/5 border border-amber-500/20 p-2.5 rounded-xl text-[11px] text-amber-300 flex items-start gap-2">
                      <MessageSquare size={13} className="shrink-0 mt-0.5" />
                      <div>
                        <span className="font-bold">Admin izohi:</span> {order.adminNote}
                      </div>
                    </div>
                  )}
                </div>

                {/* Status Change Selector Buttons */}
                <div className="pt-2 border-t border-slate-800/80 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-[11px] font-semibold text-slate-400">Statusni o'zgartirish:</span>
                    {isUpdating && <Loader2 size={14} className="animate-spin text-emerald-400" />}
                  </div>

                  <div className="grid grid-cols-3 sm:grid-cols-5 gap-1.5">
                    {Object.entries(STATUS_CONFIG).map(([statusKey, cfg]) => (
                      <button
                        key={statusKey}
                        disabled={isUpdating || order.status === statusKey}
                        onClick={() => handleStatusChange(order.id, statusKey)}
                        className={`py-1.5 px-2 rounded-xl text-[10px] font-bold border transition-all ${
                          order.status === statusKey
                            ? `${cfg.bg} ${cfg.border} ${cfg.text} ring-1 ring-emerald-500/30`
                            : "bg-slate-950/60 border-slate-800 text-slate-400 hover:border-slate-700 hover:text-slate-200"
                        } disabled:opacity-50`}
                      >
                        {cfg.label}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
