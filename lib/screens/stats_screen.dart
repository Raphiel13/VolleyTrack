import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const _activity = [0.0, 0.0, 0.6, 0.0, 0.8, 1.0, 0.4];
  static const _days = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return CustomScrollView(
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
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: t.label,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Sezon 2025',
                    style: GoogleFonts.inter(
                        fontSize: 15, color: t.label3),
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),

            // ── Summary grid ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Row(
                  children: [
                    ['24', 'Meczów'],
                    ['16', 'Wygranych'],
                    ['67%', 'Win%'],
                    ['11.4', 'Pkt/mecz'],
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
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: t.label,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            e.value[1],
                            style: GoogleFonts.inter(
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

            // ── Activity chart ───────────────────────────────────────
            const SectionLabel('Aktywność tego tygodnia'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '3 mecze w tym tygodniu',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: t.label,
                          ),
                        ),
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
                          barTouchData:
                              BarTouchData(enabled: false),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) => Padding(
                                  padding:
                                      const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _days[v.toInt()],
                                    style: GoogleFonts.inter(
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
                            final val = _activity[i];
                            final isMax = val == 1.0;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: val == 0 ? 0.05 : val,
                                  width: 22,
                                  borderRadius:
                                      const BorderRadius.vertical(
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
                                      : LinearGradient(colors: [
                                          val > 0
                                              ? AppColors.blue
                                                  .withOpacity(0.3)
                                              : const Color(
                                                  0x1E767680),
                                          val > 0
                                              ? AppColors.blue
                                                  .withOpacity(0.3)
                                              : const Color(
                                                  0x1E767680),
                                        ]),
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

            // ── Season detail ────────────────────────────────────────
            const SectionLabel('Sezon – szczegóły'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Column(
                  children: [
                    ('⚡', 'Asy', '14', AppColors.blue),
                    ('🛡️', 'Bloki', '9', AppColors.orange),
                    ('🤝', 'Przyjęcia', '38', AppColors.green),
                    ('❌', 'Błędy', '7', AppColors.red),
                  ].asMap().entries.map((e) {
                    final (emoji, label, val, color) = e.value;
                    return Column(children: [
                      IosRow(
                        leading: SfIconBox(
                          emoji: emoji,
                          bgColor: t.label4.withOpacity(0.4),
                        ),
                        title: Text(label,
                            style: GoogleFonts.inter(
                                fontSize: 16, color: t.label)),
                        trailing: Text(
                          val,
                          style: GoogleFonts.inter(
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

            // ── Match history ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 7),
              child: Text(
                'HISTORIA MECZÓW',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: t.label2,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Column(
                  children: MockData.matches
                      .asMap()
                      .entries
                      .map((e) {
                    final m = e.value;
                    final i = e.key;
                    return Column(children: [
                      IosRow(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: m.isWin
                                ? AppColors.green.withOpacity(0.12)
                                : AppColors.red.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              m.isWin ? 'W' : 'L',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: m.isWin
                                    ? AppColors.green
                                    : AppColors.red,
                              ),
                            ),
                          ),
                        ),
                        title: Text(m.opponent,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: t.label,
                            )),
                        subtitle: Text(
                          '${m.date} · ${m.score}',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: t.label2),
                        ),
                        trailing: Text(
                          '${m.points} pkt',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: m.isWin
                                ? AppColors.green
                                : t.label2,
                          ),
                        ),
                      ),
                      if (i < MockData.matches.length - 1)
                        const IosSeparator(),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  }
}