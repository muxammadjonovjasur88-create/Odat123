import React, { useState, useEffect } from "react";
import { X, Upload, Coins, Tag, Store, Image as ImageIcon, AlertCircle, Loader2 } from "lucide-react";
import { api } from "../services/api";

export function ProductModal({ isOpen, onClose, onSave, item = null }) {
  const isEdit = !!item;

  const [formData, setFormData] = useState({
    type: "coupon",
    title: "",
    description: "",
    partnerName: "",
    pointsCost: 100,
    imageUrl: "",
    stock: "",
    isActive: true,
    discountText: "",
  });

  const [isUploading, setIsUploading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (item) {
      setFormData({
        type: item.type || "coupon",
        title: item.title || "",
        description: item.description || "",
        partnerName: item.partnerName || "",
        pointsCost: item.pointsCost || 100,
        imageUrl: item.imageUrl || "",
        stock: item.stock !== null && item.stock !== undefined ? String(item.stock) : "",
        isActive: item.isActive !== false,
        discountText: item.discountText || "",
      });
    } else {
      setFormData({
        type: "coupon",
        title: "",
        description: "",
        partnerName: "",
        pointsCost: 100,
        imageUrl: "",
        stock: "",
        isActive: true,
        discountText: "",
      });
    }
    setError("");
  }, [item, isOpen]);

  if (!isOpen) return null;

  // Compress image client-side to keep base64 payload small and fast
  const compressImageFile = (file, maxWidth = 800, maxHeight = 800, quality = 0.8) => {
    return new Promise((resolve) => {
      if (!file || !file.type.startsWith("image/")) {
        resolve(file);
        return;
      }
      const img = new Image();
      const url = URL.createObjectURL(file);
      img.onload = () => {
        URL.revokeObjectURL(url);
        let width = img.width;
        let height = img.height;

        if (width <= maxWidth && height <= maxHeight) {
          resolve(file);
          return;
        }

        const ratio = Math.min(maxWidth / width, maxHeight / height);
        width = Math.round(width * ratio);
        height = Math.round(height * ratio);

        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, width, height);

        canvas.toBlob(
          (blob) => {
            if (!blob) {
              resolve(file);
              return;
            }
            const resizedFile = new File([blob], file.name.replace(/\.\w+$/, ".jpg"), {
              type: "image/jpeg",
              lastModified: Date.now(),
            });
            resolve(resizedFile);
          },
          "image/jpeg",
          quality
        );
      };
      img.onerror = () => {
        URL.revokeObjectURL(url);
        resolve(file);
      };
      img.src = url;
    });
  };

  const handleImageFileChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      setError("Faqat JPG, PNG yoki WEBP rasmlar yuklash mumkin.");
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setError("Rasm hajmi 5MB dan oshmasligi kerak.");
      return;
    }

    setError("");
    setIsUploading(true);

    try {
      const compressedFile = await compressImageFile(file);
      const reader = new FileReader();
      reader.onload = async () => {
        const base64 = reader.result;
        try {
          const res = await api.uploadImage(base64, compressedFile.name, compressedFile.type);
          setFormData((prev) => ({ ...prev, imageUrl: res.imageUrl }));
        } catch (err) {
          setError(err.message || "Rasm yuklashda xatolik yuz berdi");
        } finally {
          setIsUploading(false);
        }
      };
      reader.onerror = () => {
        setError("Faylni o'qishda xatolik");
        setIsUploading(false);
      };
      reader.readAsDataURL(compressedFile);
    } catch (err) {
      setError("Rasm yuklashda xatolik");
      setIsUploading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.title.trim()) {
      setError("Mahsulot nomi kiritilishi shart.");
      return;
    }
    if (!formData.imageUrl.trim()) {
      setError("Mahsulot rasmi yuklanishi shart.");
      return;
    }

    setError("");
    setIsSubmitting(true);

    try {
      const payload = {
        type: formData.type,
        title: formData.title.trim(),
        description: formData.description.trim(),
        partnerName: formData.type === "coupon" ? formData.partnerName.trim() : (formData.partnerName.trim() || null),
        discountText: formData.type === "coupon" ? formData.discountText.trim() : null,
        pointsCost: Math.max(0, parseInt(formData.pointsCost || 0, 10)),
        imageUrl: formData.imageUrl.trim(),
        stock: formData.stock !== "" ? Math.max(0, parseInt(formData.stock, 10)) : null,
        isActive: formData.isActive,
        requiresShipping: formData.type === "gift",
      };

      await onSave(payload, item?.id);
      onClose();
    } catch (err) {
      setError(err.message || "Saqlashda xatolik yuz berdi");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm overflow-y-auto">
      <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-md p-5 shadow-2xl my-8 relative">
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-slate-400 hover:text-slate-200 p-1.5 rounded-lg hover:bg-slate-800 transition-colors"
        >
          <X size={18} />
        </button>

        <h2 className="text-lg font-bold text-slate-100 mb-4 flex items-center gap-2">
          {isEdit ? "✏️ Mahsulotni tahrirlash" : "➕ Yangi mahsulot qo'shish"}
        </h2>

        {error && (
          <div className="mb-4 p-3 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-400 text-xs flex items-start gap-2">
            <AlertCircle size={16} className="shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4 text-xs">
          {/* Type Selection */}
          <div>
            <label className="block text-slate-400 font-medium mb-1.5">Mahsulot turi</label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setFormData({ ...formData, type: "coupon" })}
                className={`py-2 px-3 rounded-xl border font-semibold flex items-center justify-center gap-2 transition-all ${
                  formData.type === "coupon"
                    ? "bg-amber-500/10 border-amber-500/40 text-amber-400"
                    : "bg-slate-800/40 border-slate-700/50 text-slate-400"
                }`}
              >
                🎟️ Chegirma Kuponi
              </button>
              <button
                type="button"
                onClick={() => setFormData({ ...formData, type: "gift" })}
                className={`py-2 px-3 rounded-xl border font-semibold flex items-center justify-center gap-2 transition-all ${
                  formData.type === "gift"
                    ? "bg-emerald-500/10 border-emerald-500/40 text-emerald-400"
                    : "bg-slate-800/40 border-slate-700/50 text-slate-400"
                }`}
              >
                🎁 Real Sovg'a
              </button>
            </div>
          </div>

          {/* Title */}
          <div>
            <label className="block text-slate-400 font-medium mb-1">Nomi</label>
            <input
              type="text"
              required
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              placeholder={formData.type === "coupon" ? "Masalan: Yandex Go 20% Chegirma" : "Masalan: Wireless Headphone"}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
            />
          </div>

          {/* Partner & Discount for Coupon */}
          {formData.type === "coupon" && (
            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="block text-slate-400 font-medium mb-1">Sherik do'kon</label>
                <input
                  type="text"
                  value={formData.partnerName}
                  onChange={(e) => setFormData({ ...formData, partnerName: e.target.value })}
                  placeholder="Yandex Go"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                />
              </div>
              <div>
                <label className="block text-slate-400 font-medium mb-1">Chegirma matni</label>
                <input
                  type="text"
                  value={formData.discountText}
                  onChange={(e) => setFormData({ ...formData, discountText: e.target.value })}
                  placeholder="20% chegirma"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                />
              </div>
            </div>
          )}

          {/* Description */}
          <div>
            <label className="block text-slate-400 font-medium mb-1">Tavsif</label>
            <textarea
              rows={2}
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="Mahsulot haqida qisqacha ma'lumot..."
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
            />
          </div>

          {/* Points Cost & Stock */}
          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="block text-slate-400 font-medium mb-1">Narxi (Ochko)</label>
              <input
                type="number"
                min="1"
                required
                value={formData.pointsCost}
                onChange={(e) => setFormData({ ...formData, pointsCost: e.target.value })}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 focus:outline-none focus:border-emerald-500"
              />
            </div>
            <div>
              <label className="block text-slate-400 font-medium mb-1">Zaxira (dona, bo'sh = cheksiz)</label>
              <input
                type="number"
                min="0"
                value={formData.stock}
                onChange={(e) => setFormData({ ...formData, stock: e.target.value })}
                placeholder="Cheksiz"
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
              />
            </div>
          </div>

          {/* Image Upload */}
          <div>
            <label className="block text-slate-400 font-medium mb-1">Mahsulot rasmi</label>
            <div className="flex items-center gap-3">
              {formData.imageUrl ? (
                <div className="relative w-16 h-16 rounded-xl overflow-hidden border border-slate-700 shrink-0 bg-slate-950">
                  <img src={formData.imageUrl} alt="Preview" className="w-full h-full object-cover" />
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, imageUrl: "" })}
                    className="absolute top-0.5 right-0.5 bg-slate-900/80 p-0.5 rounded-full text-slate-300 hover:text-white"
                  >
                    <X size={12} />
                  </button>
                </div>
              ) : (
                <div className="w-16 h-16 rounded-xl border border-dashed border-slate-700 shrink-0 flex items-center justify-center text-slate-600 bg-slate-950/50">
                  <ImageIcon size={20} />
                </div>
              )}

              <div className="flex-1">
                <label className="cursor-pointer inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium text-xs transition-colors w-full">
                  {isUploading ? (
                    <>
                      <Loader2 size={14} className="animate-spin text-emerald-400" />
                      <span>Yuklanmoqda...</span>
                    </>
                  ) : (
                    <>
                      <Upload size={14} />
                      <span>Rasm yuklash</span>
                    </>
                  )}
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    onChange={handleImageFileChange}
                    disabled={isUploading}
                    className="hidden"
                  />
                </label>
                <input
                  type="text"
                  value={formData.imageUrl}
                  onChange={(e) => setFormData({ ...formData, imageUrl: e.target.value })}
                  placeholder="Yoki rasm URL manzilini kiriting"
                  className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-lg px-2.5 py-1 text-[11px] text-slate-300 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                />
              </div>
            </div>
          </div>

          {/* Active Switch */}
          <div className="flex items-center justify-between pt-1">
            <span className="text-slate-300 font-medium">Mahsulot faol (do'konda ko'rinadi)</span>
            <button
              type="button"
              onClick={() => setFormData({ ...formData, isActive: !formData.isActive })}
              className={`w-11 h-6 rounded-full transition-colors relative p-0.5 ${
                formData.isActive ? "bg-emerald-500" : "bg-slate-700"
              }`}
            >
              <div
                className={`w-5 h-5 rounded-full bg-white transition-transform ${
                  formData.isActive ? "translate-x-5" : "translate-x-0"
                }`}
              />
            </button>
          </div>

          {/* Submit buttons */}
          <div className="flex items-center gap-2 pt-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2.5 rounded-xl border border-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-800/50 font-semibold transition-colors"
            >
              Bekor qilish
            </button>
            <button
              type="submit"
              disabled={isSubmitting || isUploading}
              className="flex-1 py-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-white font-semibold shadow-lg shadow-emerald-500/20 transition-all flex items-center justify-center gap-1.5 disabled:opacity-50"
            >
              {isSubmitting ? <Loader2 size={16} className="animate-spin" /> : "Saqlash"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
