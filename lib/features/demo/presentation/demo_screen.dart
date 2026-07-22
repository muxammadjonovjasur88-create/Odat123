import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_category.dart';
import '../../../core/services/theme_mode_controller.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Developer gallery (route `/demo`). Renders every shared widget so the design
/// foundation can be verified on a real device, and lets you flip the whole app
/// between light and dark. The top "Both modes" card shows light & dark at once.
class DemoScreen extends ConsumerStatefulWidget {
  const DemoScreen({super.key});

  @override
  ConsumerState<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends ConsumerState<DemoScreen> {
  AppCategory _selectedCategory = AppCategory.sport;
  AppNavTab _tab = AppNavTab.calendar;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flowa · Components'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light' : 'Switch to dark',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () => ref
                .read(themeModeProvider.notifier)
                .toggle(MediaQuery.platformBrightnessOf(context)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _sectionTitle(context, 'Both modes at a glance'),
          const _BothModesPreview(),
          _sectionTitle(context, 'Buttons'),
          AppButton(label: 'Create Goal', onPressed: () {}),
          const SizedBox(height: 12),
          AppButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Secondary',
            variant: AppButtonVariant.secondary,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: _loading ? 'Loading' : 'Tap to load',
                  loading: _loading,
                  onPressed: _simulateLoad,
                ),
              ),
              const SizedBox(width: 12),
              const AppButton(
                label: 'Disabled',
                variant: AppButtonVariant.secondary,
                onPressed: null,
              ),
            ],
          ),
          _sectionTitle(context, 'Inputs'),
          const AppInput(label: 'Goal title', hint: 'What will you focus on?'),
          const SizedBox(height: 16),
          const AppInput(
            hint: 'Search rituals',
            prefixIcon: Icon(Icons.search_rounded, size: 20),
          ),
          _sectionTitle(context, 'Category chips'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category in AppCategory.values)
                AppChip.category(
                  category,
                  selected: category == _selectedCategory,
                  onTap: () => setState(() => _selectedCategory = category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Selected: ${_selectedCategory.label}',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          _sectionTitle(context, 'Cards'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deep Work: Interface Design',
                  style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  '08:00 — 10:00',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 8, children: const [AppChip(label: '+120 pts')]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            onTap: () {},
            child: Row(
              children: [
                Icon(Icons.spa_outlined, color: colors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Tappable card',
                    style: AppTextStyles.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: _tab,
        onSelected: (tab) => setState(() => _tab = tab),
      ),
    );
  }

  Future<void> _simulateLoad() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _loading = false);
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 28, 0, 14),
    child: Text(
      text,
      style: AppTextStyles.overline.copyWith(
        color: context.colors.textSecondary,
      ),
    ),
  );
}

/// Shows the same mini-card rendered in forced light and forced dark side by
/// side, so both palettes are visible simultaneously regardless of app mode.
class _BothModesPreview extends StatelessWidget {
  const _BothModesPreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Swatch(theme: AppTheme.light, label: 'Light'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Swatch(theme: AppTheme.dark, label: 'Dark'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.overline.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Ritual',
                        style: AppTextStyles.h3.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppChip.category(AppCategory.sport, selected: true),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AppButton(label: 'Start', onPressed: () {}, expand: true),
              ],
            ),
          );
        },
      ),
    );
  }
}
