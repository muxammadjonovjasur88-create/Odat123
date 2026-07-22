import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/lobby_repository.dart';
import '../domain/lobby.dart';

/// Lists the private lobbies the user belongs to, with Create + Join actions.
class LobbiesScreen extends ConsumerWidget {
  const LobbiesScreen({super.key});

  String? _uid(WidgetRef ref) => ref.read(authStateProvider).asData?.value?.uid;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _promptText(
      context,
      title: 'lobby.create_title'.tr(),
      hint: 'lobby.create_hint'.tr(),
      action: 'lobby.create_action'.tr(),
    );
    if (name == null) return;
    final uid = _uid(ref);
    if (uid == null) return;
    try {
      final lobby = await ref
          .read(lobbyRepositoryProvider)
          .createLobby(uid: uid, name: name);
      if (context.mounted) context.push('${AppRoutes.lobby}/${lobby.id}');
    } catch (_) {
      if (context.mounted) _snack(context, 'lobby.create_failed'.tr());
    }
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final code = await _promptText(
      context,
      title: 'lobby.join_title'.tr(),
      hint: 'lobby.join_hint'.tr(),
      action: 'lobby.join_action'.tr(),
      autoUpper: true,
    );
    if (code == null) return;
    final uid = _uid(ref);
    if (uid == null) return;
    final outcome = await ref
        .read(lobbyRepositoryProvider)
        .joinByCode(uid: uid, code: code);
    if (!context.mounted) return;
    switch (outcome.result) {
      case JoinResult.ok:
      case JoinResult.alreadyMember:
        final msg = outcome.result == JoinResult.ok
            ? 'lobby.join_welcome'.tr()
            : 'lobby.join_already'.tr();
        _snack(context, msg);
        if (outcome.lobbyId != null) {
          context.push('${AppRoutes.lobby}/${outcome.lobbyId}');
        }
      case JoinResult.notFound:
        _snack(context, 'lobby.join_not_found'.tr());
      case JoinResult.full:
        _snack(
          context,
          'lobby.join_full'.tr(namedArgs: {'max': '$kLobbyMemberLimit'}),
        );
      case JoinResult.error:
        _snack(context, 'lobby.join_error'.tr());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lobbiesAsync = ref.watch(myLobbiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('lobby.list_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'lobby.list_intro'.tr(),
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            // Stacked full-width buttons so they never overflow on narrow phones.
            AppButton(
              label: 'lobby.create_button'.tr(),
              icon: Icons.add_rounded,
              onPressed: () => _create(context, ref),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'lobby.join_button'.tr(),
              icon: Icons.tag_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => _join(context, ref),
            ),
            const SizedBox(height: 24),
            Text(
              'lobby.your_lobbies'.tr(),
              style: AppTextStyles.overline.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            lobbiesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: FlowaLoading(size: 64)),
              ),
              error: (e, _) => AppErrorView(
                message: 'lobby.list_load_error'.tr(),
                onRetry: () => ref.invalidate(myLobbiesProvider),
              ),
              data: (lobbies) {
                if (lobbies.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.groups_2_outlined,
                    title: 'lobby.empty_title'.tr(),
                    message: 'lobby.empty_message'.tr(),
                  );
                }
                final uid = _uid(ref);
                return Column(
                  children: [
                    for (var i = 0; i < lobbies.length; i++)
                      FadeSlideIn(
                        delay: FadeSlideIn.stagger(i),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LobbyCard(
                            lobby: lobbies[i],
                            isCreator: lobbies[i].isCreator(uid ?? ''),
                            onTap: () => context.push(
                              '${AppRoutes.lobby}/${lobbies[i].id}',
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LobbyCard extends StatelessWidget {
  const _LobbyCard({
    required this.lobby,
    required this.isCreator,
    required this.onTap,
  });

  final Lobby lobby;
  final bool isCreator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.tintSage,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups_rounded, color: colors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lobby.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  '${'lobby.member_count'.plural(lobby.memberCount)} • '
                  '${lobby.code}${isCreator ? ' • ${'lobby.host'.tr()}' : ''}',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks for a single line of text in a calm, keyboard-aware bottom sheet and
/// returns the trimmed value (or null if cancelled/empty).
///
/// Deliberately a bottom sheet, NOT an [AlertDialog]: an [AlertDialog] wraps its
/// content in an `IntrinsicWidth`, and a focused `TextField` there tears its
/// inherited dependencies down out of order when dismissed, crashing with
/// `'_dependents.isEmpty': is not true`. The sheet also owns its controller in a
/// [State] so it's disposed only after the sheet is fully gone.
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String hint,
  required String action,
  bool autoUpper = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TextPromptSheet(
      title: title,
      hint: hint,
      action: action,
      autoUpper: autoUpper,
    ),
  );
}

class _TextPromptSheet extends StatefulWidget {
  const _TextPromptSheet({
    required this.title,
    required this.hint,
    required this.action,
    required this.autoUpper,
  });

  final String title;
  final String hint;
  final String action;
  final bool autoUpper;

  @override
  State<_TextPromptSheet> createState() => _TextPromptSheetState();
}

class _TextPromptSheetState extends State<_TextPromptSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    Navigator.of(context).pop(v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: _controller,
            hint: widget.hint,
            autofocus: true,
            textCapitalization: widget.autoUpper
                ? TextCapitalization.characters
                : TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'common.cancel'.tr(),
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(label: widget.action, onPressed: _submit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
