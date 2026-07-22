import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/default_avatars.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../premium/domain/premium.dart';

/// Screen 05 — first-login profile setup. Saving creates `users/{uid}` in
/// Firestore, which flips the auth gate to Home.
class SetupProfileScreen extends ConsumerStatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  static const _focusOptions = ['Study', 'Sport', 'Work', 'Personal'];

  final _nameController = TextEditingController();
  String _avatarKey = kDefaultAvatars.first.key;
  String _focus = _focusOptions.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool skip = false}) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    final name = skip
        ? (_nameController.text.trim().isEmpty
              ? 'setup.default_name'.tr()
              : _nameController.text.trim())
        : _nameController.text.trim();

    if (!skip && name.isEmpty) {
      _snack('setup.error_no_name'.tr());
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .createProfile(
            UserProfile(
              uid: user.uid,
              name: name,
              avatar: _avatarKey,
              focusType: _focus,
              email: user.email,
              photoUrl: user.photoURL,
            ),
          );
      // Auth gate redirects to Home once the profile document exists.
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('setup.error_save'.tr());
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAvatar() async {
    final colors = context.colors;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AvatarPicker(selected: _avatarKey),
    );
    if (selected != null) setState(() => _avatarKey = selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avatar = avatarForKey(_avatarKey);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BrandLogo(),
                  TextButton(
                    onPressed: _saving ? null : () => _submit(skip: true),
                    child: Text(
                      'setup.skip'.tr(),
                      style: AppTextStyles.label.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'setup.title'.tr(),
                style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'setup.subtitle'.tr(),
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: avatar.background,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                avatar.icon,
                                size: 40,
                                color: avatar.foreground,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'setup.your_avatar'.tr(),
                            style: AppTextStyles.h3.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'setup.avatar_hint'.tr(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'setup.name_label'.tr(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppInput(
                      controller: _nameController,
                      hint: 'setup.name_hint'.tr(),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'setup.focus_label'.tr(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final option in _focusOptions)
                          AppChip(
                            label: 'setup.focus_${option.toLowerCase()}'.tr(),
                            selected: _focus == option,
                            onTap: () => setState(() => _focus = option),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'setup.lets_go'.tr(),
                icon: Icons.arrow_forward_rounded,
                loading: _saving,
                onPressed: _saving ? null : () => _submit(),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'setup.change_later'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'setup.choose_avatar'.tr(),
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final a in kDefaultAvatars)
                GestureDetector(
                  onTap: () {
                    // Premium avatars are locked while the system is on.
                    if (kPremiumEnabled && a.isPremium) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              'setup.premium_avatar_locked'.tr(),
                            ),
                          ),
                        );
                      return;
                    }
                    Navigator.of(context).pop(a.key);
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: a.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: a.key == selected
                                ? colors.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: Icon(a.icon, color: a.foreground),
                      ),
                      if (kPremiumEnabled && a.isPremium)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: kPremiumGold,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
