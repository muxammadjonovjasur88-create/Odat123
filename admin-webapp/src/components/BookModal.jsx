import React, { useState, useEffect, useRef } from "react";
import { X, Upload, Book, FileText, Image as ImageIcon, AlertCircle, Loader2, CheckCircle, Award } from "lucide-react";

const CATEGORY_OPTIONS = [
  "Shaxsiy rivojlanish",
  "Badiiy",
  "Ilmiy",
  "Biznes",
  "Motivatsion",
  "Psixologiya",
  "Diniy-ma'rifiy",
  "Texnologiya",
];

const MAX_PDF_SIZE_BYTES = 200 * 1024 * 1024; // 200 MB limit for Cloud Functions base64 payload
const MAX_COVER_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

export function BookModal({ isOpen, onClose, onSave, book = null }) {
  const isEdit = !!book;
  const modalRef = useRef(null);

  const [formData, setFormData] = useState({
    title: "",
    author: "",
    description: "",
    category: "Shaxsiy rivojlanish",
    pointsReward: 100,
    coverImageUrl: "",
    pdfUrl: "",
    isActive: true,
  });

  // Selected file objects
  const [coverFile, setCoverFile] = useState(null);
  const [coverPreview, setCoverPreview] = useState("");

  const [pdfFile, setPdfFile] = useState(null);
  const [pdfFileName, setPdfFileName] = useState("");
  const [pdfFileSizeMb, setPdfFileSizeMb] = useState(0);

  // Status & Progress
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadStage, setUploadStage] = useState(""); // "reading_pdf", "reading_cover", "saving"
  const [error, setError] = useState("");

  useEffect(() => {
    if (error && modalRef.current) {
      modalRef.current.scrollTo({ top: 0, behavior: "smooth" });
    }
  }, [error]);

  useEffect(() => {
    if (book) {
      setFormData({
        title: book.title || "",
        author: book.author || "",
        description: book.description || "",
        category: book.category || "Shaxsiy rivojlanish",
        pointsReward: book.pointsReward !== undefined ? book.pointsReward : 100,
        coverImageUrl: book.coverImageUrl || "",
        pdfUrl: book.pdfUrl || "",
        isActive: book.isActive !== false,
      });
      setCoverPreview(book.coverImageUrl || "");
      setPdfFileName(book.pdfUrl ? "Mavjud PDF fayl saqlangan" : "");
    } else {
      setFormData({
        title: "",
        author: "",
        description: "",
        category: "Shaxsiy rivojlanish",
        pointsReward: 100,
        coverImageUrl: "",
        pdfUrl: "",
        isActive: true,
      });
      setCoverPreview("");
      setPdfFileName("");
    }
    setCoverFile(null);
    setPdfFile(null);
    setPdfFileSizeMb(0);
    setError("");
    setUploadProgress(0);
    setUploadStage("");
    setIsUploading(false);
  }, [book, isOpen]);

  if (!isOpen) return null;

  // Compress image client-side to prevent large base64 payload
  const compressImageFile = (file, maxWidth = 800, maxHeight = 1200, quality = 0.8) => {
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

  // Cover image selection & client-side validation
  const handleCoverChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const allowed = ["image/jpeg", "image/png", "image/webp"];
    if (!allowed.includes(file.type)) {
      setError("Rasm formati noto'g'ri. Faqat JPG, PNG yoki WEBP rasmlari yuklanishi mumkin.");
      return;
    }

    if (file.size > MAX_COVER_SIZE_BYTES) {
      setError(`Muqova rasm hajmi 5MB dan oshmasligi kerak (tanlangan: ${(file.size / (1024 * 1024)).toFixed(1)}MB).`);
      return;
    }

    setError("");
    const compressed = await compressImageFile(file);
    setCoverFile(compressed);
    
    // Generate safe Base64 preview for Telegram WebView compatibility
    const reader = new FileReader();
    reader.onloadend = () => {
      setCoverPreview(reader.result);
    };
    reader.readAsDataURL(compressed);
  };

  // PDF file selection & client-side validation
  const handlePdfChange = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.type !== "application/pdf" && !file.name.toLowerCase().endsWith(".pdf")) {
      setError("Noto'g'ri fayl formati. Faqat PDF (.pdf) formatidagi fayllar yuklanishi mumkin.");
      return;
    }

    if (file.size > MAX_PDF_SIZE_BYTES) {
      setError(`PDF fayl hajmi 200MB limitidan oshmasligi kerak (tanlangan: ${(file.size / (1024 * 1024)).toFixed(1)}MB).`);
      return;
    }

    setError("");
    setPdfFile(file);
    setPdfFileName(file.name);
    setPdfFileSizeMb((file.size / (1024 * 1024)).toFixed(1));
  };

  // Read file as Base64 with progress callback
  const readFileAsBase64 = (file, onProgress) => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onprogress = (e) => {
        if (e.lengthComputable && onProgress) {
          const percent = Math.round((e.loaded / e.total) * 100);
          onProgress(percent);
        }
      };

      reader.onload = () => resolve(reader.result);
      reader.onerror = (err) => reject(new Error("Faylni o'qishda xatolik yuz berdi: " + err));
      reader.readAsDataURL(file);
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");

    // Form field validations
    if (!formData.title.trim()) {
      setError("Kitob nomi kiritilishi shart.");
      return;
    }

    if (!isEdit && !pdfFile && !formData.pdfUrl.trim()) {
      setError("PDF fayl tanlanishi yoki PDF URL manzili kiritilishi shart.");
      return;
    }

    setIsUploading(true);
    setUploadProgress(5);
    setUploadStage("Tayyorlanmoqda...");

    try {
      const payload = {
        book: {
          title: formData.title.trim(),
          author: formData.author.trim(),
          description: formData.description.trim(),
          category: formData.category,
          pointsReward: Math.max(0, parseInt(formData.pointsReward || 100, 10)),
          isActive: formData.isActive,
          coverImageUrl: formData.coverImageUrl,
          pdfUrl: formData.pdfUrl,
        },
        pdfFile: pdfFile || null,
        coverFile: coverFile || null,
        coverContentType: coverFile ? coverFile.type : "image/jpeg",
      };

      await onSave(payload, isEdit ? book.id : null, (stage, pct) => {
        setUploadStage(stage);
        setUploadProgress(pct);
      });

      setUploadProgress(100);
      setUploadStage("Muvaffaqiyatli saqlandi!");
      onClose();
    } catch (err) {
      console.error("Book save error:", err);
      setError(err.message || "Saqlashda kutilmagan xatolik yuz berdi. Iltimos, tarmoq va qayta urinib ko'ring.");
    } finally {
      setIsUploading(false);
    }

  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm overflow-y-auto">
      <div ref={modalRef} className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-lg p-5 shadow-2xl my-6 relative text-xs max-h-[90vh] overflow-y-auto">
        {/* Close Button */}
        <button
          onClick={onClose}
          disabled={isUploading}
          className="absolute top-4 right-4 text-slate-400 hover:text-slate-200 p-1.5 rounded-lg hover:bg-slate-800 transition-colors disabled:opacity-50"
        >
          <X size={18} />
        </button>

        <h2 className="text-base font-bold text-slate-100 mb-4 flex items-center gap-2">
          <Book size={18} className="text-emerald-400" />
          <span>{isEdit ? "✏️ Kitobni tahrirlash" : "➕ Yangi kitob qo'shish"}</span>
        </h2>

        {/* Error Alert */}
        {error && (
          <div className="mb-4 p-3 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-400 text-xs flex items-start gap-2 animate-shake">
            <AlertCircle size={16} className="shrink-0 mt-0.5" />
            <div className="flex-1">
              <span className="font-semibold block">Xatolik:</span>
              <span>{error}</span>
            </div>
          </div>
        )}

        {/* Upload Progress Overlay / Banner */}
        {isUploading && (
          <div className="mb-4 p-3 bg-slate-950 border border-emerald-500/30 rounded-xl space-y-2">
            <div className="flex items-center justify-between text-[11px]">
              <span className="font-medium text-emerald-400 flex items-center gap-1.5">
                <Loader2 size={13} className="animate-spin" />
                {uploadStage}
              </span>
              <span className="font-bold text-emerald-400">{uploadProgress}%</span>
            </div>
            <div className="w-full h-2 bg-slate-800 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-emerald-500 to-teal-400 transition-all duration-300 rounded-full"
                style={{ width: `${uploadProgress}%` }}
              />
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Title & Author */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-slate-400 font-medium mb-1">Kitob nomi *</label>
              <input
                type="text"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                placeholder="Masalan: Atom Odatlar"
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
              />
            </div>
            <div>
              <label className="block text-slate-400 font-medium mb-1">Muallif</label>
              <input
                type="text"
                value={formData.author}
                onChange={(e) => setFormData({ ...formData, author: e.target.value })}
                placeholder="Masalan: Jeyms Klir"
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
              />
            </div>
          </div>

          {/* Category & Points Reward */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-slate-400 font-medium mb-1">Kategoriya</label>
              <select
                value={formData.category}
                onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 focus:outline-none focus:border-emerald-500"
              >
                {CATEGORY_OPTIONS.map((cat) => (
                  <option key={cat} value={cat}>
                    {cat}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-slate-400 font-medium mb-1 flex items-center gap-1">
                <Award size={13} className="text-amber-400" />
                <span>Test mukofoti (ball)</span>
              </label>
              <input
                type="number"
                min="0"
                step="10"
                value={formData.pointsReward}
                onChange={(e) => setFormData({ ...formData, pointsReward: e.target.value })}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 focus:outline-none focus:border-emerald-500 font-bold text-amber-400"
              />
            </div>
          </div>

          {/* Description */}
          <div>
            <label className="block text-slate-400 font-medium mb-1">Tavsif (qisqa)</label>
            <textarea
              rows={2}
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="Kitob haqida qisqacha ma'lumot..."
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
            />
          </div>

          {/* Cover Image Upload */}
          <div>
            <label className="block text-slate-400 font-medium mb-1">Muqova rasmi (Max 5MB)</label>
            <div className="flex items-center gap-3">
              {coverPreview ? (
                <div className="relative w-16 h-20 rounded-xl overflow-hidden border border-slate-700 shrink-0 bg-slate-950">
                  <img src={coverPreview} alt="Muqova preview" className="w-full h-full object-cover" />
                  <button
                    type="button"
                    onClick={() => {
                      setCoverFile(null);
                      setCoverPreview("");
                      setFormData((p) => ({ ...p, coverImageUrl: "" }));
                    }}
                    className="absolute top-1 right-1 bg-slate-950/80 p-0.5 rounded-full text-slate-300 hover:text-white"
                  >
                    <X size={12} />
                  </button>
                </div>
              ) : (
                <div className="w-16 h-20 rounded-xl border border-dashed border-slate-800 shrink-0 flex items-center justify-center text-slate-600 bg-slate-950">
                  <ImageIcon size={20} />
                </div>
              )}

              <div className="flex-1">
                <label className="cursor-pointer inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium text-xs transition-colors w-full">
                  <Upload size={14} />
                  <span>{coverFile ? "Boshqa rasm tanlash" : "Rasm fayl tanlash"}</span>
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    onChange={handleCoverChange}
                    disabled={isUploading}
                    className="hidden"
                  />
                </label>
                <p className="text-[10px] text-slate-500 mt-1">Formatlar: JPG, PNG, WEBP</p>
              </div>
            </div>
          </div>

          {/* PDF File Upload */}
          <div className="bg-slate-950/60 p-3 rounded-xl border border-slate-800 space-y-2">
            <label className="block text-slate-300 font-semibold flex items-center justify-between">
              <span className="flex items-center gap-1.5">
                <FileText size={15} className="text-emerald-400" />
                PDF Fayl yuklash {!isEdit && "*"}
              </span>
              <span className="text-[10px] text-slate-500 font-normal">Max: 50 MB</span>
            </label>

            <div className="flex items-center gap-2">
              <label className="cursor-pointer inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-500/10 border border-emerald-500/30 hover:bg-emerald-500/20 text-emerald-400 font-semibold text-xs transition-colors shrink-0">
                <Upload size={14} />
                <span>{pdfFile ? "Faylni o'zgartirish" : "PDF fayl tanlash"}</span>
                <input
                  type="file"
                  accept="application/pdf,.pdf"
                  onChange={handlePdfChange}
                  disabled={isUploading}
                  className="hidden"
                />
              </label>

              <div className="flex-1 min-w-0">
                {pdfFile ? (
                  <div className="flex items-center gap-1.5 text-slate-200 text-[11px]">
                    <CheckCircle size={14} className="text-emerald-400 shrink-0" />
                    <span className="truncate font-medium">{pdfFileName}</span>
                    <span className="text-slate-400 font-mono text-[10px]">({pdfFileSizeMb} MB)</span>
                  </div>
                ) : isEdit && formData.pdfUrl ? (
                  <span className="text-slate-400 text-[11px] truncate block">
                    ✓ Mavjud PDF saqlangan (almashtirish ixtiyoriy)
                  </span>
                ) : (
                  <span className="text-slate-500 text-[11px]">Hali fayl tanlanmadi</span>
                )}
              </div>
            </div>
          </div>

          {/* Active Status */}
          <div className="flex items-center justify-between pt-1">
            <span className="text-slate-300 font-medium">Kitob faol (kutubxonada ko'rinadi)</span>
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

          {/* Bottom Error Alert */}
          {error && (
            <div className="p-3 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-400 text-xs flex items-start gap-2 animate-shake">
              <AlertCircle size={16} className="shrink-0 mt-0.5" />
              <div className="flex-1">
                <span className="font-semibold block">Xatolik:</span>
                <span>{error}</span>
              </div>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex items-center gap-2 pt-3">
            <button
              type="button"
              onClick={onClose}
              disabled={isUploading}
              className="flex-1 py-2.5 rounded-xl border border-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-800/50 font-semibold transition-colors disabled:opacity-50"
            >
              Bekor qilish
            </button>
            <button
              type="submit"
              disabled={isUploading}
              className="flex-1 py-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-white font-semibold shadow-lg shadow-emerald-500/20 transition-all flex items-center justify-center gap-1.5 disabled:opacity-50"
            >
              {isUploading ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  <span>Yuklanmoqda...</span>
                </>
              ) : (
                "Saqlash"
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
