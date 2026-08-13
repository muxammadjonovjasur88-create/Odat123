import React, { useState } from "react";
import {
  Plus,
  Edit2,
  Trash2,
  Eye,
  EyeOff,
  BookOpen,
  Award,
  AlertTriangle,
  Sparkles,
  CheckCircle2,
  HelpCircle,
  Loader2,
  FileText,
} from "lucide-react";
import { BookModal } from "./BookModal";

export function BooksTab({
  books = [],
  onSaveBook,
  onDeleteBook,
  onToggleActive,
  onGenerateQuiz,
  isLoading,
  autoOpenAddModal = false,
}) {
  const [filterCategory, setFilterCategory] = useState("all");
  const [isModalOpen, setIsModalOpen] = useState(autoOpenAddModal);
  const [editingBook, setEditingBook] = useState(null);
  const [deletingBook, setDeletingBook] = useState(null);
  const [generatingQuizId, setGeneratingQuizId] = useState(null);

  // Extract list of unique categories
  const categories = Array.from(new Set(books.map((b) => b.category).filter(Boolean)));

  const filteredBooks = books.filter((book) => {
    if (filterCategory === "has_quiz") return book.hasQuiz === true;
    if (filterCategory === "no_quiz") return !book.hasQuiz;
    if (filterCategory === "inactive") return book.isActive === false;
    if (filterCategory !== "all" && book.category !== filterCategory) return false;
    return true;
  });

  const handleEdit = (book) => {
    setEditingBook(book);
    setIsModalOpen(true);
  };

  const handleCreateNew = () => {
    setEditingBook(null);
    setIsModalOpen(true);
  };

  const confirmDelete = async () => {
    if (!deletingBook) return;
    await onDeleteBook(deletingBook.id);
    setDeletingBook(null);
  };

  const handleQuizClick = async (bookId) => {
    setGeneratingQuizId(bookId);
    try {
      await onGenerateQuiz(bookId);
    } finally {
      setGeneratingQuizId(null);
    }
  };

  return (
    <div className="space-y-4">
      {/* Top Header & Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        {/* Filter Chips */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 scrollbar-none text-xs font-semibold">
          <button
            onClick={() => setFilterCategory("all")}
            className={`px-3 py-1.5 rounded-xl whitespace-nowrap transition-all ${
              filterCategory === "all"
                ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
                : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
            }`}
          >
            Barchasi ({books.length})
          </button>

          <button
            onClick={() => setFilterCategory("has_quiz")}
            className={`px-3 py-1.5 rounded-xl whitespace-nowrap transition-all ${
              filterCategory === "has_quiz"
                ? "bg-teal-500 text-white shadow-md shadow-teal-500/20"
                : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
            }`}
          >
            ✨ Test bor ({books.filter((b) => b.hasQuiz).length})
          </button>

          <button
            onClick={() => setFilterCategory("no_quiz")}
            className={`px-3 py-1.5 rounded-xl whitespace-nowrap transition-all ${
              filterCategory === "no_quiz"
                ? "bg-amber-500 text-slate-950 shadow-md shadow-amber-500/20"
                : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
            }`}
          >
            ⚡ Test yo'q ({books.filter((b) => !b.hasQuiz).length})
          </button>

          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setFilterCategory(cat)}
              className={`px-3 py-1.5 rounded-xl whitespace-nowrap transition-all ${
                filterCategory === cat
                  ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
                  : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
              }`}
            >
              📚 {cat}
            </button>
          ))}

          <button
            onClick={() => setFilterCategory("inactive")}
            className={`px-3 py-1.5 rounded-xl whitespace-nowrap transition-all ${
              filterCategory === "inactive"
                ? "bg-rose-500 text-white shadow-md shadow-rose-500/20"
                : "bg-slate-800/80 text-slate-400 hover:text-slate-200"
            }`}
          >
            🚫 Noaktiv ({books.filter((b) => b.isActive === false).length})
          </button>
        </div>

        {/* Add Book Button */}
        <button
          onClick={handleCreateNew}
          className="w-full sm:w-auto px-4 py-2 bg-emerald-500 hover:bg-emerald-400 active:scale-95 text-white text-xs font-bold rounded-xl shadow-lg shadow-emerald-500/20 flex items-center justify-center gap-1.5 transition-all shrink-0"
        >
          <Plus size={16} />
          <span>Yangi Kitob</span>
        </button>
      </div>

      {/* Book List / Grid */}
      {isLoading ? (
        <div className="py-12 text-center text-slate-500 text-xs flex flex-col items-center gap-2">
          <div className="w-6 h-6 border-2 border-emerald-500 border-t-transparent rounded-full animate-spin" />
          <span>Kitoblar yuklanmoqda...</span>
        </div>
      ) : filteredBooks.length === 0 ? (
        <div className="py-12 text-center text-slate-500 text-xs border border-dashed border-slate-800 rounded-2xl p-6">
          <BookOpen size={32} className="mx-auto mb-2 opacity-50" />
          <p className="font-semibold text-slate-400">Kitoblar topilmadi</p>
          <p className="mt-1 text-slate-600">"Yangi Kitob" tugmasi orqali birinchi kitobni qo'shing.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {filteredBooks.map((book) => {
            const isGeneratingThisQuiz = generatingQuizId === book.id;

            return (
              <div
                key={book.id}
                className={`bg-slate-900 border rounded-2xl p-3.5 flex gap-3 relative transition-all ${
                  book.isActive === false
                    ? "border-slate-800 opacity-60"
                    : "border-slate-800 hover:border-slate-700"
                }`}
              >
                {/* Book Cover */}
                <div className="w-20 h-28 rounded-xl overflow-hidden bg-slate-950 border border-slate-800 shrink-0 relative flex items-center justify-center text-slate-600">
                  {book.coverImageUrl ? (
                    <img
                      src={book.coverImageUrl}
                      alt={book.title}
                      className="w-full h-full object-cover"
                      onError={(e) => {
                        e.target.style.display = "none";
                      }}
                    />
                  ) : (
                    <BookOpen size={24} />
                  )}
                  {book.category && (
                    <span className="absolute bottom-1 left-1 right-1 bg-slate-950/90 text-slate-300 text-[8px] font-bold px-1 py-0.5 rounded text-center truncate backdrop-blur-sm">
                      {book.category}
                    </span>
                  )}
                </div>

                {/* Details */}
                <div className="flex-1 min-w-0 flex flex-col justify-between">
                  <div>
                    {/* Title & Author */}
                    <h3 className="font-semibold text-xs text-slate-100 truncate">{book.title}</h3>
                    <p className="text-[11px] text-slate-400 font-medium truncate mt-0.5">
                      ✍️ {book.author || "Muallif ko'rsatilmagan"}
                    </p>

                    {/* Description preview */}
                    {book.description && (
                      <p className="text-[10px] text-slate-500 line-clamp-2 mt-1 leading-tight">
                        {book.description}
                      </p>
                    )}

                    {/* Metadata chips */}
                    <div className="flex flex-wrap items-center gap-1.5 mt-2">
                      {/* Points Reward */}
                      <span className="bg-amber-500/10 border border-amber-500/20 text-amber-400 text-[10px] font-bold px-2 py-0.5 rounded-lg flex items-center gap-1">
                        <Award size={11} /> +{book.pointsReward || 100} ball
                      </span>

                      {/* PDF Pages count */}
                      {book.totalPages > 1 && (
                        <span className="bg-slate-800 text-slate-400 text-[10px] font-mono px-1.5 py-0.5 rounded-md flex items-center gap-1">
                          <FileText size={10} /> {book.totalPages} bet
                        </span>
                      )}

                      {/* Quiz status badge */}
                      {book.hasQuiz ? (
                        <span className="bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-[10px] font-semibold px-2 py-0.5 rounded-lg flex items-center gap-1">
                          <CheckCircle2 size={11} /> Test tayyor
                        </span>
                      ) : (
                        <span className="bg-amber-500/10 border border-amber-500/20 text-amber-400 text-[10px] font-semibold px-2 py-0.5 rounded-lg flex items-center gap-1">
                          <HelpCircle size={11} /> Test hali yo'q
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Actions Bar */}
                  <div className="flex items-center justify-between pt-2 border-t border-slate-800/80 mt-2 gap-1">
                    {/* Generate Quiz Button */}
                    <button
                      onClick={() => handleQuizClick(book.id)}
                      disabled={isGeneratingThisQuiz}
                      className={`text-[10px] font-bold px-2.5 py-1 rounded-lg flex items-center gap-1 transition-all ${
                        book.hasQuiz
                          ? "bg-slate-800 text-slate-300 hover:bg-slate-700"
                          : "bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-400 hover:to-teal-400 text-white shadow-sm shadow-emerald-500/20"
                      } disabled:opacity-50`}
                      title={book.hasQuiz ? "Testni qayta yaratish" : "AI orqali test yaratish"}
                    >
                      {isGeneratingThisQuiz ? (
                        <>
                          <Loader2 size={12} className="animate-spin text-emerald-300" />
                          <span>Yaratilmoqda...</span>
                        </>
                      ) : (
                        <>
                          <Sparkles size={11} className={book.hasQuiz ? "text-slate-400" : "text-amber-300"} />
                          <span>{book.hasQuiz ? "Qayta yaratish" : "Test yaratish"}</span>
                        </>
                      )}
                    </button>

                    <div className="flex items-center gap-1">
                      {/* Toggle Active */}
                      <button
                        onClick={() => onToggleActive(book)}
                        className={`p-1.5 rounded-lg transition-colors text-[10px] ${
                          book.isActive !== false
                            ? "text-emerald-400 hover:bg-slate-800"
                            : "text-rose-400 hover:bg-rose-500/10"
                        }`}
                        title={book.isActive !== false ? "Faol (bosing: noaktiv qilish)" : "Noaktiv (bosing: faollashtirish)"}
                      >
                        {book.isActive !== false ? <Eye size={14} /> : <EyeOff size={14} />}
                      </button>

                      {/* Edit */}
                      <button
                        onClick={() => handleEdit(book)}
                        className="p-1.5 text-slate-400 hover:text-slate-200 hover:bg-slate-800 rounded-lg transition-colors"
                        title="Tahrirlash"
                      >
                        <Edit2 size={13} />
                      </button>

                      {/* Soft Delete */}
                      <button
                        onClick={() => setDeletingBook(book)}
                        className="p-1.5 text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 rounded-lg transition-colors"
                        title="O'chirish"
                      >
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Edit / Create Book Modal */}
      <BookModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSave={(data) => onSaveBook(data, editingBook?.id)}
        book={editingBook}
      />

      {/* Delete Confirmation Modal */}
      {deletingBook && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-sm w-full p-5 shadow-2xl space-y-4 text-xs">
            <div className="w-10 h-10 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center justify-center mx-auto">
              <AlertTriangle size={20} />
            </div>
            <div className="text-center">
              <h3 className="font-bold text-sm text-slate-100">Kitobni o'chirish</h3>
              <p className="text-xs text-slate-400 mt-1">
                "<span className="text-slate-200">{deletingBook.title}</span>" kitobini noaktiv qilmoqchimisiz?
              </p>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={() => setDeletingBook(null)}
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
