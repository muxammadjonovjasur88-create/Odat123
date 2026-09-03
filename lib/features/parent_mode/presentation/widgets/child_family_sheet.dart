import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

void showChildFamilySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF04050D),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x224AADDC)),
                child: const Icon(Icons.family_restroom_rounded, color: Color(0xFF3A7FCC), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'family.child_sheet_title'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'family.child_sheet_sub'.tr(),
                      style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Shared items list
          _sheetItem(Icons.check_circle_rounded, const Color(0xFF3A7FCC), 'family.shared_battery'.tr()),
          const SizedBox(height: 8),
          _sheetItem(Icons.check_circle_rounded, const Color(0xFF3A7FCC), 'family.shared_screentime'.tr()),
          const SizedBox(height: 8),
          _sheetItem(Icons.check_circle_rounded, const Color(0xFF3A7FCC), 'family.shared_study'.tr()),
          const SizedBox(height: 8),
          _sheetItem(Icons.check_circle_rounded, const Color(0xFF3A7FCC), 'family.shared_location'.tr()),
          const SizedBox(height: 12),

          // Strictly Protected items
          _sheetItem(Icons.cancel_rounded, const Color(0xFFFF5252), 'family.protected_ai_chat'.tr()),
          const SizedBox(height: 8),
          _sheetItem(Icons.cancel_rounded, const Color(0xFFFF5252), 'family.protected_notes'.tr()),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141F36),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('close'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _sheetItem(IconData icon, Color color, String text) {
  return Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
      ),
    ],
  );
}
