import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Admin panel — kitob / audio kitob qo'shish va tahrirlash.
/// Faqat isAdmin = true bo'lgan foydalanuvchilar ko'rishi kerak.
class AdminBooksScreen extends StatefulWidget {
  const AdminBooksScreen({super.key});

  @override
  State<AdminBooksScreen> createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends State<AdminBooksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '⚙️ Admin Panel — Kitoblar',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF9B4FE8),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded), text: 'Kitoblar'),
            Tab(icon: Icon(Icons.headphones_rounded), text: 'Audio Kitoblar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _BooksAdminTab(),
          _AudiobooksAdminTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: BOOKS
// ─────────────────────────────────────────────────────────────────────────────
class _BooksAdminTab extends StatefulWidget {
  const _BooksAdminTab();

  @override
  State<_BooksAdminTab> createState() => _BooksAdminTabState();
}

class _BooksAdminTabState extends State<_BooksAdminTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditBookDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4FE8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yangi Kitob Qo\'shish',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('books').snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF9B4FE8)));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text('Hali kitob yo\'q',
                      style: TextStyle(color: Colors.white54)),
                );
              }
              final docs = snap.data!.docs;
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final coverUrl = data['coverImageUrl'] as String? ?? '';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        // Cover preview
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildCoverPreview(coverUrl, 48, 64),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] as String? ?? 'Nomsiz',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${data['author'] ?? ''} • ${data['category'] ?? ''}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                coverUrl.isEmpty
                                    ? '⚠️ Rasm yo\'q'
                                    : '✅ Rasm bor',
                                style: TextStyle(
                                  color: coverUrl.isEmpty
                                      ? Colors.orangeAccent
                                      : const Color(0xFF4AADDC),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Edit button
                        IconButton(
                          onPressed: () =>
                              _showAddEditBookDialog(context, doc: doc),
                          icon: const Icon(Icons.edit_rounded,
                              color: Color(0xFF9B4FE8), size: 22),
                        ),
                        // Delete button
                        IconButton(
                          onPressed: () =>
                              _confirmDelete(context, doc.reference, doc['title'] ?? ''),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 22),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, DocumentReference ref, String title) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        title: const Text('O\'chirishni tasdiqlang',
            style: TextStyle(color: Colors.white)),
        content: Text('«$title» kitobini o\'chirasizmi?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('O\'chirish',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) await ref.delete();
  }

  void _showAddEditBookDialog(BuildContext ctx,
      {QueryDocumentSnapshot? doc}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookFormSheet(doc: doc),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOK FORM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _BookFormSheet extends StatefulWidget {
  final QueryDocumentSnapshot? doc;
  const _BookFormSheet({this.doc});

  @override
  State<_BookFormSheet> createState() => _BookFormSheetState();
}

class _BookFormSheetState extends State<_BookFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _pdfUrl;
  late final TextEditingController _totalPages;
  late final TextEditingController _pointsReward;

  String _coverImageBase64 = '';
  String _existingCoverUrl = '';
  bool _isSaving = false;

  final _categories = [
    'Shaxsiy rivojlanish',
    'Badiiy',
    'Ilmiy',
    'Biznes',
    'Motivatsion',
    'Psixologiya',
    'Diniy-ma\'rifiy',
    'Texnologiya',
  ];
  String _selectedCategory = 'Shaxsiy rivojlanish';

  @override
  void initState() {
    super.initState();
    final d = widget.doc?.data() as Map<String, dynamic>? ?? {};
    _title = TextEditingController(text: d['title'] as String? ?? '');
    _author = TextEditingController(text: d['author'] as String? ?? '');
    _description = TextEditingController(text: d['description'] as String? ?? '');
    _category = TextEditingController(text: d['category'] as String? ?? '');
    _pdfUrl = TextEditingController(text: d['pdfUrl'] as String? ?? '');
    _totalPages = TextEditingController(
        text: (d['totalPages'] as num?)?.toString() ?? '1');
    _pointsReward = TextEditingController(
        text: (d['pointsReward'] as num?)?.toString() ?? '100');
    _existingCoverUrl = d['coverImageUrl'] as String? ?? '';
    _selectedCategory = (_categories.contains(d['category']))
        ? d['category'] as String
        : _categories.first;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _author,
      _description,
      _category,
      _pdfUrl,
      _totalPages,
      _pointsReward,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 1200,
    );
    if (picked == null) return;

    try {
      // Compress for Firestore (keep under 1 MB)
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: 75,
        minWidth: 400,
        minHeight: 600,
      );
      final bytes = compressed ?? await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      setState(() {
        _coverImageBase64 = 'data:image/jpeg;base64,$base64Str';
        _existingCoverUrl = ''; // use new image
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rasm yuklashda xato: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final coverUrl = _coverImageBase64.isNotEmpty
          ? _coverImageBase64
          : _existingCoverUrl;

      final data = {
        'title': _title.text.trim(),
        'author': _author.text.trim(),
        'description': _description.text.trim(),
        'category': _selectedCategory,
        'pdfUrl': _pdfUrl.text.trim(),
        'totalPages': int.tryParse(_totalPages.text.trim()) ?? 1,
        'pointsReward': int.tryParse(_pointsReward.text.trim()) ?? 100,
        'coverImageUrl': coverUrl,
        'isActive': true,
        'hasQuiz': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.doc == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('books').add(data);
      } else {
        await widget.doc!.reference.set(data, SetOptions(merge: true));
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Saqlashda xato: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverToShow =
        _coverImageBase64.isNotEmpty ? _coverImageBase64 : _existingCoverUrl;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF090B18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    widget.doc == null ? 'Yangi Kitob' : 'Kitobni Tahrirlash',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  const Spacer(),
                  if (_isSaving)
                    const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF9B4FE8)))
                  else
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B4FE8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Saqlash',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 20),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Cover Image Picker ──
                      const _SectionLabel('Muqova Rasmı'),
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 170,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E1020),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: coverToShow.isNotEmpty
                                    ? const Color(0xFF9B4FE8)
                                    : Colors.white24,
                                width: coverToShow.isNotEmpty ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: coverToShow.isNotEmpty
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildCoverPreview(
                                          coverToShow, 120, 170),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          color: Colors.black54,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.edit_rounded,
                                                  color: Colors.white,
                                                  size: 14),
                                              SizedBox(width: 4),
                                              Text('O\'zgartirish',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded,
                                          color: Color(0xFF9B4FE8), size: 36),
                                      SizedBox(height: 8),
                                      Text('Rasm tanlash',
                                          style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Fields ──
                      const _SectionLabel('Kitob nomi *'),
                      _field(
                        _title,
                        'Masalan: Atom Odatlar',
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Nom kiritilishi shart'
                            : null,
                      ),

                      const _SectionLabel('Muallif'),
                      _field(_author, 'James Clear'),

                      const _SectionLabel('Tavsif'),
                      _field(_description, 'Kitob haqida qisqacha...',
                          maxLines: 3),

                      const _SectionLabel('Kategoriya'),
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1020),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            dropdownColor: const Color(0xFF090B18),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5),
                            isExpanded: true,
                            items: _categories
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedCategory = v);
                              }
                            },
                          ),
                        ),
                      ),

                      const _SectionLabel('PDF URL (ixtiyoriy)'),
                      _field(_pdfUrl, 'https://... yoki bo\'sh qoldiring'),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionLabel('Sahifalar soni'),
                                _field(_totalPages, '150',
                                    keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionLabel('Ball mukofoti'),
                                _field(_pointsReward, '100',
                                    keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
          filled: true,
          fillColor: const Color(0xFF0E1020),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9B4FE8)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: AUDIOBOOKS
// ─────────────────────────────────────────────────────────────────────────────
class _AudiobooksAdminTab extends StatefulWidget {
  const _AudiobooksAdminTab();

  @override
  State<_AudiobooksAdminTab> createState() => _AudiobooksAdminTabState();
}

class _AudiobooksAdminTabState extends State<_AudiobooksAdminTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAudioForm(context, 'audiobooks'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4AADDC),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.headphones_rounded, size: 18),
                  label: const Text('Audio Kitob',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAudioForm(context, 'podcasts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB703),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.podcasts_rounded, size: 18),
                  label: const Text('Podkast',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('audiobooks')
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF4AADDC)));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('Audio kitoblar yo\'q',
                      style: TextStyle(color: Colors.white54)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final hasUrl = (data['audioUrl'] as String? ?? '').isNotEmpty;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4AADDC).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.headphones_rounded,
                              color: Color(0xFF4AADDC), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] as String? ?? 'Nomsiz',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                data['author'] as String? ?? '',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11),
                              ),
                              Text(
                                hasUrl
                                    ? '✅ Audio URL bor'
                                    : '⚠️ Audio URL yo\'q',
                                style: TextStyle(
                                  color: hasUrl
                                      ? const Color(0xFF4AADDC)
                                      : Colors.orangeAccent,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _showAudioForm(context, 'audiobooks', doc: doc),
                          icon: const Icon(Icons.edit_rounded,
                              color: Color(0xFF4AADDC), size: 22),
                        ),
                        IconButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xFF090B18),
                                title: const Text('O\'chirasizmi?',
                                    style: TextStyle(color: Colors.white)),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Yo\'q',
                                          style: TextStyle(
                                              color: Colors.white54))),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Ha',
                                          style: TextStyle(
                                              color: Colors.redAccent))),
                                ],
                              ),
                            );
                            if (ok == true) await doc.reference.delete();
                          },
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 22),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAudioForm(BuildContext ctx, String collection,
      {QueryDocumentSnapshot? doc}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AudioFormSheet(collection: collection, doc: doc),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUDIO FORM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AudioFormSheet extends StatefulWidget {
  final String collection;
  final QueryDocumentSnapshot? doc;
  const _AudioFormSheet({required this.collection, this.doc});

  @override
  State<_AudioFormSheet> createState() => _AudioFormSheetState();
}

class _AudioFormSheetState extends State<_AudioFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _narrator;
  late final TextEditingController _desc;
  late final TextEditingController _audioUrl;
  late final TextEditingController _telegramUrl;
  late final TextEditingController _durationMin;
  late final TextEditingController _emoji;

  String _selectedCategory = 'badiiy';
  bool _isSaving = false;

  final _categories = [
    'badiiy',
    'walk_learn',
    'business',
    'psychology',
    'it',
    'audiobooks',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.doc?.data() as Map<String, dynamic>? ?? {};
    _title = TextEditingController(text: d['title'] as String? ?? '');
    _author = TextEditingController(text: d['author'] as String? ?? '');
    _narrator = TextEditingController(text: d['narrator'] as String? ?? '');
    _desc = TextEditingController(text: d['desc'] as String? ?? '');
    _audioUrl = TextEditingController(text: d['audioUrl'] as String? ?? '');
    _telegramUrl =
        TextEditingController(text: d['telegramUrl'] as String? ?? '');
    _durationMin = TextEditingController(
        text: (d['durationMin'] as num?)?.toString() ?? '15');
    _emoji = TextEditingController(text: d['emoji'] as String? ?? '🎧');
    final cat = d['category'] as String? ?? 'badiiy';
    _selectedCategory = _categories.contains(cat) ? cat : _categories.first;
  }

  @override
  void dispose() {
    for (final c in [
      _title, _author, _narrator, _desc,
      _audioUrl, _telegramUrl, _durationMin, _emoji,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final data = {
        'title': _title.text.trim(),
        'author': _author.text.trim(),
        'narrator': _narrator.text.trim(),
        'desc': _desc.text.trim(),
        'audioUrl': _audioUrl.text.trim(),
        'telegramUrl': _telegramUrl.text.trim(),
        'durationMin': int.tryParse(_durationMin.text.trim()) ?? 15,
        'emoji': _emoji.text.trim().isEmpty ? '🎧' : _emoji.text.trim(),
        'category': _selectedCategory,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.doc == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection(widget.collection)
            .add(data);
      } else {
        await widget.doc!.reference.set(data, SetOptions(merge: true));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Xato: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF090B18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    widget.doc == null
                        ? 'Yangi ${widget.collection == "audiobooks" ? "Audio Kitob" : "Podkast"}'
                        : 'Tahrirlash',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17),
                  ),
                  const Spacer(),
                  if (_isSaving)
                    const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF4AADDC)))
                  else
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4AADDC),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Saqlash',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('Sarlavha *'),
                      _field(_title, 'Masalan: Atom Odatlar',
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Majburiy'
                              : null),
                      const _SectionLabel('Muallif'),
                      _field(_author, 'James Clear'),
                      const _SectionLabel('Ovoz beruvchi'),
                      _field(_narrator, 'O\'zbekcha ovoz'),
                      const _SectionLabel('Tavsif'),
                      _field(_desc, 'Qisqacha ma\'lumot...', maxLines: 2),
                      const _SectionLabel('Kategoriya'),
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1020),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            dropdownColor: const Color(0xFF090B18),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5),
                            isExpanded: true,
                            items: _categories
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedCategory = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const _SectionLabel('Audio URL (stream linki)'),
                      _field(_audioUrl,
                          'https://... yoki Firebase Storage URL'),
                      const _SectionLabel('Telegram URL (zaxira havola)'),
                      _field(_telegramUrl, 'https://t.me/odat_fenix'),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionLabel('Davomiyligi (daqiqa)'),
                                _field(_durationMin, '30',
                                    keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionLabel('Emoji'),
                                _field(_emoji, '🎧'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF0E1020),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4AADDC)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white60,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3),
      ),
    );
  }
}

Widget _buildCoverPreview(String url, double w, double h) {
  if (url.isEmpty) {
    return Container(
      width: w,
      height: h,
      color: const Color(0xFF0E1020),
      child: const Icon(Icons.menu_book_rounded,
          color: Color(0xFF9B4FE8), size: 28),
    );
  }
  if (url.startsWith('data:image') || url.startsWith('data:application')) {
    try {
      final idx = url.indexOf(',');
      final b64 = idx != -1 ? url.substring(idx + 1) : url;
      final bytes = base64Decode(b64.trim());
      return Image.memory(bytes,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _noImage(w, h));
    } catch (_) {}
  }
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return Image.network(url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _noImage(w, h));
  }
  return _noImage(w, h);
}

Widget _noImage(double w, double h) => Container(
      width: w,
      height: h,
      color: const Color(0xFF0E1020),
      child: const Icon(Icons.broken_image_rounded,
          color: Colors.white24, size: 24),
    );
