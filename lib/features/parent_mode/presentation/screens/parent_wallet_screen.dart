import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/family_models.dart';
import '../providers/family_providers.dart';

class ParentWalletScreen extends ConsumerStatefulWidget {
  const ParentWalletScreen({super.key});

  @override
  ConsumerState<ParentWalletScreen> createState() => _ParentWalletScreenState();
}

class _ParentWalletScreenState extends ConsumerState<ParentWalletScreen> {
  int _simulationYears = 1;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(fenixWalletProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'family.wallet_title'.tr(),
          style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: walletAsync.when(
        data: (wallet) {
          if (wallet == null) {
            return Center(
              child: Text(
                'family.no_wallet_data'.tr(),
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            );
          }
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              // Master Wallet Hero Card
              _buildWalletHeroCard(wallet),
              SizedBox(height: 20),

              // Savings Goals Section
              Text(
                'family.savings_goals'.tr(),
                style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
              SizedBox(height: 10),
              for (final goal in wallet.goals) ...[
                _buildGoalTile(goal),
                SizedBox(height: 10),
              ],
              SizedBox(height: 20),

              // Fenix Savings Lab (Educational Compounding Simulator)
              _buildSavingsLabCard(wallet.savingsVaultCoins),
              SizedBox(height: 24),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: Color(0xFFFFB703))),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 48),
                SizedBox(height: 14),
                Text(
                  'family.wallet_load_error'.tr(),
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(fenixWalletProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2D4A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Qayta urinish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletHeroCard(FenixWalletModel wallet) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF261D10), Color(0xFF13100B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x33FFB703), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'family.total_balance'.tr(),
                style: const TextStyle(color: Color(0xFFFFB703), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x3300FF88),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${wallet.todayEarnedCoins} FC ${'family.today'.tr()}',
                  style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFFB703), size: 36),
              SizedBox(width: 10),
              Text(
                '${wallet.totalBalance} FC',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: 18),

          // Two Sub-balances: Available vs Savings Vault
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF04050D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('family.available_coins'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                      SizedBox(height: 4),
                      Text('${wallet.availableCoins} FC', style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF04050D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('family.savings_vault'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                      SizedBox(height: 4),
                      Text('${wallet.savingsVaultCoins} FC', style: const TextStyle(color: Color(0xFFFFB703), fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalTile(SavingsGoal goal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.title,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              Text(
                '${goal.savedCoins} / ${goal.targetCoins} FC',
                style: const TextStyle(color: Color(0xFFFFB703), fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsLabCard(int principalCoins) {
    // 25% educational annual compounding formula
    int projectedCoins = (principalCoins * (1 + 0.25 * _simulationYears)).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF142034), Color(0xFF0C1422)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF4AADDC).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_rounded, color: Color(0xFF4AADDC), size: 20),
              SizedBox(width: 10),
              Text(
                'family.savings_lab_title'.tr(),
                style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'family.savings_lab_desc'.tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          SizedBox(height: 14),

          // Year Selector Chips
          Row(
            children: [1, 2, 3, 5].map((y) {
              final isSel = _simulationYears == y;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$y ${'family.year'.tr()}'),
                  selected: isSel,
                  onSelected: (_) => setState(() => _simulationYears = y),
                  selectedColor: const Color(0xFF4AADDC),
                  backgroundColor: const Color(0xFF04050D),
                  labelStyle: TextStyle(color: isSel ? const Color(0xFF04050D) : Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF04050D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_simulationYears yildan so‘ng taxminiy:', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('~$projectedCoins FC (+25%/yil)', style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 13.5, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          SizedBox(height: 10),

          // Educational Disclaimer
          Text(
            '⚠️ ${'family.savings_lab_disclaimer'.tr()}',
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
