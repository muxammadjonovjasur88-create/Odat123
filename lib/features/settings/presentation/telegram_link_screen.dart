import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Bosqich A — Sozlamalar ekranidagi "Telegram'ni ulash" ekrani.
///
/// Qanday ishlaydi:
///   1. Bot nomini ko'rsatadi.
///   2. Foydalanuvchi /start bosib unique kod (UID) ni ko'chiradi.
///   3. Foydalanuvchi botga /start [UID] yuboradi.
///   4. Webhook (Cloud Function linkTelegramChatId) chat_id ni Firestore'ga yozadi.
///   5. Agar foydalanuvchi chat_id ni qo'lda kiritmoqchi bo'lsa, manual
///      input ham qo'llab-quvvatlanadi (test uchun foydali).
class TelegramLinkScreen extends ConsumerStatefulWidget {
  const TelegramLinkScreen({super.key});

  @override
  ConsumerState<TelegramLinkScreen> createState() => _TelegramLinkScreenState();
}

class _TelegramLinkScreenState extends ConsumerState<TelegramLinkScreen> {
  final _chatIdController = TextEditingController();
  bool _isLoading = false;
  bool _showManual = false;

  @override
  void dispose() {
    _chatIdController.dispose();
    super.dispose();
  }

  Future<void> _saveChatId() async {
    final chatId = _chatIdController.text.trim();
    if (chatId.isEmpty) return;
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(userRepositoryProvider).saveTelegramChatId(uid, chatId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.telegram_connected'.tr())),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.telegram_unlink'.tr()),
        content: Text('settings.telegram_unlink_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('settings.telegram_unlink_btn'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(userRepositoryProvider).disconnectTelegram(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.telegram_unlinked'.tr())),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final uid = ref.watch(authStateProvider).asData?.value?.uid ?? '';
    final isLinked = (profile?.telegramChatId ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('settings.telegram_link_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status banner
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isLinked
                          ? const Color(0xFF26A5E4).withValues(alpha: 0.15)
                          : colors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.telegram_rounded,
                      color: isLinked
                          ? const Color(0xFF26A5E4)
                          : colors.textSecondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLinked ? 'Telegram ulangan ✅' : 'Telegram ulanmagan',
                          style: AppTextStyles.h3.copyWith(
                            color: isLinked
                                ? const Color(0xFF26A5E4)
                                : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLinked
                              ? 'Do\'stlaringiz isbot yuborilganda Telegram xabar oladi.'
                              : 'Ulasangiz do\'stlaringiz isbot natijalari haqida Telegram orqali xabar oladi.',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (!isLinked) ...[
              // Qadamlar
              Text(
                'Qanday ulash kerak?',
                style:
                    AppTextStyles.h3.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 14),

              _StepTile(
                step: '1',
                colors: colors,
                text: 'Telegram\'da @flowwabuddybot ni toping',
              ),
              const SizedBox(height: 10),
              _StepTile(
                step: '2',
                colors: colors,
                text: 'Botga quyidagi kodni nusxalab /start bilan yuboring:',
                trailing: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '/start $uid'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('common.code_copied'.tr())),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '/start $uid',
                            style: AppTextStyles.caption.copyWith(
                              color: colors.textPrimary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _StepTile(
                step: '3',
                colors: colors,
                text: 'Bot "Muvaffaqiyatli ulandi!" deb javob beradi — tayyor!',
              ),

              const SizedBox(height: 24),

              // Manual ulanish (backup)
              GestureDetector(
                onTap: () => setState(() => _showManual = !_showManual),
                child: Row(
                  children: [
                    Icon(
                      _showManual
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Qo\'lda chat ID kiritish (muqobil)',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),

              if (_showManual) ...[
                const SizedBox(height: 14),
                Text(
                  'Telegram ID ni topish uchun @userinfobot ga /start yuboring.',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _chatIdController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Telegram Chat ID',
                    hintText: 'Masalan: 123456789',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'common.save'.tr(),
                  onPressed: _isLoading ? null : _saveChatId,
                ),
              ],
            ] else ...[
              // Ulangan holat — uzish tugmasi
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link_off_rounded, color: Colors.red),
                  label: Text(
                    'settings.telegram_unlink'.tr(),
                    style: const TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _disconnect,
                ),
              ),
            ],

            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.colors,
    required this.text,
    this.trailing,
  });

  final String step;
  final AppColorScheme colors;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: AppTextStyles.label.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style:
                    AppTextStyles.body.copyWith(color: colors.textPrimary),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}
