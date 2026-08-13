import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../insights/data/weekly_insight_repository.dart';

class WeeklyInsightCard extends ConsumerStatefulWidget {
  const WeeklyInsightCard({super.key, this.testUid, this.insightOverride});

  final String? testUid;
  final String? insightOverride;

  @override
  ConsumerState<WeeklyInsightCard> createState() => _WeeklyInsightCardState();
}

class _WeeklyInsightCardState extends ConsumerState<WeeklyInsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.insightOverride != null) {
      return _buildCard(context, widget.insightOverride!);
    }
    final uid = widget.testUid ?? ref.watch(authStateProvider).asData?.value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final snapshot = ref.watch(weeklyInsightProvider(uid));

    return snapshot.when(
      data: (insight) {
        if (insight == null || insight.trim().isEmpty) return const SizedBox.shrink();
        return _buildCard(context, insight);
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeleton(width: 160, height: 16),
              SizedBox(height: 8),
              AppSkeleton(width: double.infinity, height: 12),
            ],
          ),
        ),
      ),
      error: (e, st) {
        debugPrint('weekly insight load error: $e');
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCard(BuildContext context, String insight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('✨', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'insights.weekly_title'.tr(),
                    style: AppTextStyles.h3.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight,
              maxLines: _expanded ? 100 : 3,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
