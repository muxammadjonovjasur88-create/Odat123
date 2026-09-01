import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../data/digital_wellbeing_service.dart';
import '../../domain/app_usage_info.dart';
import '../../domain/installed_app.dart';
import '../providers/digital_wellbeing_provider.dart';

class AppLimitsScreen extends ConsumerStatefulWidget {
  const AppLimitsScreen({super.key});

  @override
  ConsumerState<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends ConsumerState<AppLimitsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<InstalledApp> _allApps = [];
  List<InstalledApp> _filteredApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _allApps;
      } else {
        _filteredApps = _allApps.where((a) {
          return a.name.toLowerCase().contains(query) || a.packageName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadInstalledApps() async {
    final apps = await ref.read(digitalWellbeingServiceProvider).getInstalledApps();
    if (mounted) {
      setState(() {
        _allApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitsAsync = ref.watch(appLimitsProvider);
    final limits = limitsAsync.asData?.value ?? [];
    final limitMap = {for (final l in limits) l.packageName: l};

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'wellbeing.app_limits_title'.tr(),
          style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'wellbeing.search_apps'.tr(),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5BC8FA), size: 20),
                filled: true,
                fillColor: const Color(0xFF131929),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Apps List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF5BC8FA)))
                : _filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          'wellbeing.no_apps_found'.tr(),
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredApps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final rule = limitMap[app.packageName];
                          final hasLimit = rule != null && rule.isEnabled;

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1220),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasLimit ? const Color(0xFF5BC8FA).withValues(alpha: 0.4) : Colors.white10,
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0x22FFFFFF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: app.icon != null && app.icon!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          app.icon!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(Icons.android_rounded, color: Colors.white70),
                                        ),
                                      )
                                    : const Icon(Icons.android_rounded, color: Colors.white70),
                              ),
                              title: Text(
                                app.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              subtitle: Text(
                                hasLimit
                                    ? '${rule.limitMinutes} daqiqa/kun • ${rule.disciplineLevel.name.toUpperCase()}'
                                    : 'wellbeing.no_limit'.tr(),
                                style: TextStyle(
                                  color: hasLimit ? const Color(0xFF5BC8FA) : Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  hasLimit ? Icons.edit_calendar_rounded : Icons.add_circle_outline_rounded,
                                  color: hasLimit ? const Color(0xFF3B9BFF) : Colors.white54,
                                ),
                                onPressed: () => _showLimitDialog(context, app, rule),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showLimitDialog(BuildContext context, InstalledApp app, AppLimitRule? existingRule) {
    int selectedMinutes = existingRule?.limitMinutes ?? 45;
    DisciplineLevel selectedLevel = existingRule?.disciplineLevel ?? DisciplineLevel.strict;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1220),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
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
                    Text(
                      'wellbeing.configure_limit'.tr(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        app.name,
                        style: const TextStyle(color: Color(0xFF5BC8FA), fontSize: 15, fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Minutes selector chips
                Text('wellbeing.daily_time_limit'.tr(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [15, 30, 45, 60, 90, 120].map((mins) {
                    final isSel = selectedMinutes == mins;
                    return ChoiceChip(
                      selected: isSel,
                      onSelected: (_) => setModalState(() => selectedMinutes = mins),
                      label: Text('$mins daq'),
                      selectedColor: const Color(0xFF5BC8FA),
                      backgroundColor: const Color(0xFF131929),
                      labelStyle: TextStyle(
                        color: isSel ? const Color(0xFF080B14) : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Discipline level selection
                Text('wellbeing.discipline_level'.tr(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _levelChoice(DisciplineLevel.gentle, 'Gentle', 'Ogohlantirish', selectedLevel, (lvl) => setModalState(() => selectedLevel = lvl)),
                    const SizedBox(width: 8),
                    _levelChoice(DisciplineLevel.focus, 'Focus', 'Tasdiqlash', selectedLevel, (lvl) => setModalState(() => selectedLevel = lvl)),
                    const SizedBox(width: 8),
                    _levelChoice(DisciplineLevel.strict, 'Strict', 'To‘liq to‘siq', selectedLevel, (lvl) => setModalState(() => selectedLevel = lvl)),
                  ],
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    if (existingRule != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(appLimitsProvider.notifier).removeAppLimit(app.packageName);
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFF5252)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('delete'.tr(), style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref.read(appLimitsProvider.notifier).setAppLimit(
                                packageName: app.packageName,
                                appName: app.name,
                                limitMinutes: selectedMinutes,
                                level: selectedLevel,
                              );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B9BFF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'save'.tr(),
                          style: const TextStyle(color: Color(0xFF080B14), fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _levelChoice(DisciplineLevel level, String title, String subtitle, DisciplineLevel current, Function(DisciplineLevel) onSelect) {
    final isSel = current == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0x225BC8FA) : const Color(0xFF131929),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? const Color(0xFF5BC8FA) : Colors.white10),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSel ? const Color(0xFF5BC8FA) : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
