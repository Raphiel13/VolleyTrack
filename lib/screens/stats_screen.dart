import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/stats_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ios_widgets.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _showAddSheet = false;

  static const _days = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final stats = ref.watch(statsProvider(uid)).valueOrNull ?? UserStats.empty;
    final matchesAsync = ref.watch(matchesProvider(uid));

    // Normalize weekly activity to [0.0–1.0] for the bar chart.
    final rawActivity = _days.map((d) => (stats.weeklyActivity[d] ?? 0).toDouble()).toList();
    final maxActivity = rawActivity.fold(0.0, math.max);
    final activity = rawActivity.map((v) => maxActivity > 0 ? v / maxActivity : 0.0).toList();
    final weekTotal = rawActivity.fold(0, (sum, v) => sum + v.toInt());

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statystyki',
                        style: AppTheme.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: t.label,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Sezon 2025',
                        style: AppTheme.inter(fontSize: 15, color: t.label3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // ── Summary grid ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IosCard(
                    child: Row(
                      children: [
                        ['${stats.totalGames}', 'Meczów'],
                        ['${stats.wins}', 'Wygranych'],
                        ['${(stats.winRate * 100).round()}%', 'Win%'],
                        [
                          stats.avgPoints == 0
                              ? '0'
                              : stats.avgPoints.toStringAsFixed(1),
                          'Pkt/mecz'
                        ],
                      ].asMap().entries.map((e) {
                        return Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              border: e.key < 3
                                  ? Border(
                                      right: BorderSide(
                                        color: t.separator,
                                        width: 0.5,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Column(children: [
                              Text(
                                e.value[0],
                                style: AppTheme.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: t.label,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                e.value[1],
                                style: AppTheme.inter(
                                    fontSize: 11, color: t.label2),
                                textAlign: TextAlign.center,
                              ),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // ── Activity chart ─────────────────────────────────
                const SectionLabel('Aktywność tego tygodnia'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IosCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              weekTotal == 1
                                  ? '1 mecz w tym tygodniu'
                                  : '$weekTotal meczów w tym tygodniu',
                              style: AppTheme.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: t.label,
                              ),
                            ),
                            if (weekTotal > 0)
                              const ChipBadge('↑ aktywny',
                                  variant: ChipVariant.green),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 100,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: 1.0,
                              barTouchData: BarTouchData(enabled: false),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) => Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        _days[v.toInt()],
                                        style: AppTheme.inter(
                                          fontSize: 11,
                                          color: t.label3,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              barGroups: List.generate(7, (i) {
                                final val = activity[i];
                                final isMax = val == 1.0;
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: val == 0 ? 0.05 : val,
                                      width: 22,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(5)),
                                      gradient: isMax
                                          ? const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                AppColors.blue,
                                                Color(0x803B7BFF),
                                              ],
                                            )
                                          : LinearGradient(
                                              colors: [
                                                val > 0
                                                    ? AppColors.blue
                                                        .withOpacity(0.3)
                                                    : const Color(0x1E767680),
                                                val > 0
                                                    ? AppColors.blue
                                                        .withOpacity(0.3)
                                                    : const Color(0x1E767680),
                                              ],
                                            ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Season detail ──────────────────────────────────
                const SectionLabel('Sezon – szczegóły'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IosCard(
                    child: Column(
                      children: [
                        (Icons.bolt, 'Asy', '${stats.totalAces}', AppColors.blue),
                        (Icons.shield_outlined, 'Bloki', '${stats.totalBlocks}', AppColors.orange),
                        (Icons.sports_handball, 'Przyjęcia', '${stats.totalReceptions}', AppColors.green),
                        (Icons.close_rounded, 'Błędy', '${stats.totalErrors}', AppColors.red),
                      ].asMap().entries.map((e) {
                        final (icon, label, val, color) = e.value;
                        return Column(children: [
                          IosRow(
                            leading: SfIconBox(
                              iconWidget: Icon(icon, size: 18, color: color),
                              bgColor: color.withValues(alpha: 0.12),
                            ),
                            title: Text(label,
                                style: AppTheme.inter(
                                    fontSize: 16, color: t.label)),
                            trailing: Text(
                              val,
                              style: AppTheme.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          if (e.key < 3) const IosSeparator(),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),

                // ── Match history header ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 7),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'HISTORIA MECZÓW',
                        style: AppTheme.inter(
                          fontSize: 13,
                          color: t.label2,
                          letterSpacing: 0.3,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _showAddSheet = true),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          '+ Dodaj',
                          style: AppTheme.inter(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Match history list ─────────────────────────────
                matchesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: IosCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.blue,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: IosCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Nie udało się załadować meczów',
                            style: AppTheme.inter(
                                fontSize: 14, color: t.label3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  data: (matches) {
                    if (matches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: IosCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Column(
                              children: [
                                Icon(Icons.sports_volleyball,
                                    size: 36, color: t.label4),
                                const SizedBox(height: 10),
                                Text(
                                  'Brak historii meczów',
                                  style: AppTheme.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: t.label2),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dodaj swój pierwszy mecz poniżej',
                                  style: AppTheme.inter(
                                      fontSize: 13, color: t.label3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: IosCard(
                        child: Column(
                          children: matches.asMap().entries.map((e) {
                            final m = e.value;
                            final i = e.key;
                            return Column(children: [
                              IosRow(
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: m.isWin
                                        ? AppColors.green.withValues(alpha: 0.12)
                                        : AppColors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      m.isWin ? 'W' : 'L',
                                      style: AppTheme.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: m.isWin
                                            ? AppColors.green
                                            : AppColors.red,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  m.opponent,
                                  style: AppTheme.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: t.label,
                                  ),
                                ),
                                subtitle: Text(
                                  '${m.date} · ${m.score}',
                                  style: AppTheme.inter(
                                      fontSize: 13, color: t.label2),
                                ),
                                trailing: Text(
                                  '${m.points} pkt',
                                  style: AppTheme.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: m.isWin
                                        ? AppColors.green
                                        : t.label2,
                                  ),
                                ),
                              ),
                              if (i < matches.length - 1)
                                const IosSeparator(),
                            ]);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ],
        ),

        // ── Add match sheet overlay ──────────────────────────────────
        if (_showAddSheet)
          _AddMatchSheet(onClose: () => setState(() => _showAddSheet = false)),
      ],
    );
  }
}

// ── Add Match Sheet ───────────────────────────────────────────────────────────

class _AddMatchSheet extends StatefulWidget {
  final VoidCallback onClose;
  const _AddMatchSheet({required this.onClose});

  @override
  State<_AddMatchSheet> createState() => _AddMatchSheetState();
}

class _AddMatchSheetState extends State<_AddMatchSheet> {
  bool? _win;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: t.label4,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(
                    'Nowy mecz',
                    style: AppTheme.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: t.label,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...['Rywal / drużyna', 'Wynik (np. 3–1)', 'Twoje punkty']
                      .map((h) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextField(
                              decoration: InputDecoration(hintText: h),
                            ),
                          )),
                  Row(children: [
                    Expanded(
                        child: _resultBtn('✓ Wygrana', _win == true,
                            () => setState(() => _win = true))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _resultBtn('✗ Przegrana', _win == false,
                            () => setState(() => _win = false))),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onClose,
                      child: const Text('Zapisz mecz'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBtn(String lbl, bool active, VoidCallback onTap) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.blue.withOpacity(0.1) : t.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.blue : t.separator,
          ),
        ),
        child: Center(
          child: Text(
            lbl,
            style: AppTheme.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: active ? AppColors.blue : t.label,
            ),
          ),
        ),
      ),
    );
  }
}
