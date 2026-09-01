import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showSendTaskToChildDialog(BuildContext context, {required String childName}) {
  showDialog(
    context: context,
    builder: (ctx) => _SendTaskToChildDialog(childName: childName),
  );
}

class _SendTaskToChildDialog extends StatefulWidget {
  const _SendTaskToChildDialog({required this.childName});
  final String childName;

  @override
  State<_SendTaskToChildDialog> createState() => _SendTaskToChildDialogState();
}

class _SendTaskToChildDialogState extends State<_SendTaskToChildDialog> {
  final TextEditingController _titleController = TextEditingController(text: 'Matematika darsini takrorlash');
  String _selectedTime = '17:00';
  int _selectedDuration = 45;
  String _selectedType = 'focus'; // 'focus', 'exercise', 'note'
  bool _isSending = false;

  final List<String> _quickTimes = ['09:00', '14:00', '17:00', '19:00', '21:00'];
  final List<int> _quickDurations = [25, 45, 60, 90];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _sendTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    HapticFeedback.heavyImpact();
    setState(() => _isSending = true);

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF3B9BFF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.send_and_archive_rounded, color: Colors.black),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Vazifa «$title» ($_selectedTime) ${widget.childName}ga yuborildi! Bola tasdiqlasa, uning rejasiga avtomatik qo‘shiladi. 📋⏰',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x225BC8FA)),
                        child: const Icon(Icons.add_task_rounded, color: Color(0xFF5BC8FA), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Farzandga Vazifa Yuborish',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.childName} uchun vaqtli vazifa belgilang. Bola qabul qilsa, uning eslatmalariga qo‘shiladi.',
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 18),

              // Activity Type Selector
              const Text('FAOLIYAT TURI:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTypeOption('focus', '🎯 Fokus', const Color(0xFF7B2FFF)),
                  const SizedBox(width: 8),
                  _buildTypeOption('exercise', '🏃 Mashq', const Color(0xFF3B9BFF)),
                  const SizedBox(width: 8),
                  _buildTypeOption('note', '📝 Zametka', const Color(0xFFFFB703)),
                ],
              ),
              const SizedBox(height: 16),

              // Title input
              const Text('VAZIFA NOMI:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF141E33),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x335BC8FA)),
                ),
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'Masalan: Kitob mutolaasi...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time selector
              const Text('BAJARILISH VAQTI:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _quickTimes.map((t) {
                  final isSel = _selectedTime == t;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTime = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF5BC8FA) : const Color(0xFF141E33),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Duration selector
              const Text('DAVOMIYLIGI:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: _quickDurations.map((d) {
                  final isSel = _selectedDuration == d;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDuration = d),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF3B9BFF) : const Color(0xFF141E33),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '$d min',
                            style: TextStyle(
                              color: isSel ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5BC8FA),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'FARZANDGA YUBORISH 🚀',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, String label, Color color) {
    final isSel = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? color : const Color(0xFF141E33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? color : Colors.white10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSel ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
