import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

class GameDetailSheet extends StatefulWidget {
  final NearbyGame game;
  const GameDetailSheet({super.key, required this.game});

  @override
  State<GameDetailSheet> createState() => _GameDetailSheetState();
}

class _GameDetailSheetState extends State<GameDetailSheet> {
  bool _joined = false;

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month) return 'Dziś';
    if (dt.day == now.day + 1) return 'Jutro';
    const days = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
    return days[dt.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final g = widget.game;
    final total = g.spotsTotal;
    final taken = g.spotsTaken;

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: t.label4,
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        ChipBadge(
                          g.category == GameCategory.beach
                              ? '🏖️ Plaża'
                              : '🏛️ Hala',
                          variant: g.category == GameCategory.beach
                              ? ChipVariant.orange
                              : ChipVariant.blue,
                        ),
                        ChipBadge(g.level.label),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        g.title,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: t.label,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: t.label4.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(CupertinoIcons.xmark, size: 16, color: t.label2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Info rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IosCard(
              child: Column(children: [
                IosRow(
                  leading: SfIconBox(
                      emoji: '📍', bgColor: t.label4.withOpacity(0.3)),
                  title: Text(g.location,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.label)),
                  subtitle: Text('${g.distanceKm} km od Ciebie',
                      style: GoogleFonts.inter(fontSize: 13, color: t.label2)),
                  showChevron: false,
                ),
                const IosSeparator(indent: 16),
                IosRow(
                  leading: SfIconBox(
                      emoji: '🕐', bgColor: t.label4.withOpacity(0.3)),
                  title: Text(
                    '${_dayLabel(g.dateTime)}, '
                    '${g.dateTime.hour.toString().padLeft(2, '0')}:'
                    '${g.dateTime.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: t.label),
                  ),
                  subtitle: Text('Termin',
                      style: GoogleFonts.inter(fontSize: 13, color: t.label2)),
                  showChevron: false,
                ),
                const IosSeparator(indent: 16),
                IosRow(
                  leading: SfIconBox(
                      emoji: '🏐', bgColor: t.label4.withOpacity(0.3)),
                  title: Text(g.level.label,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.label)),
                  subtitle: Text('Poziom gry',
                      style: GoogleFonts.inter(fontSize: 13, color: t.label2)),
                  showChevron: false,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Spots bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IosCard(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Miejsca',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.label,
                        )),
                    Text(
                      g.isFull
                          ? 'Brak miejsc'
                          : '${g.spotsLeft} ${g.spotsLeft == 1 ? "wolne" : "wolnych"}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            g.spotsLeft <= 2 ? AppColors.red : AppColors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    total,
                    (i) => Expanded(
                      child: Container(
                        height: 8,
                        margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: i < taken
                              ? AppColors.blue
                              : (_joined && i == taken)
                                  ? AppColors.green
                                  : t.label4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: AppColors.blue)),
                      const SizedBox(width: 5),
                      Text('$taken zapisanych',
                          style:
                              GoogleFonts.inter(fontSize: 11, color: t.label2)),
                    ]),
                    Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: t.label4)),
                      const SizedBox(width: 5),
                      Text('${g.spotsLeft} wolnych',
                          style:
                              GoogleFonts.inter(fontSize: 11, color: t.label2)),
                    ]),
                  ],
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Organiser
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IosCard(
              child: IosRow(
                leading: UserAvatar(name: g.organizerName, size: 36),
                title: Text(g.organizerName,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: t.label)),
                subtitle: Text('Organizator · ${g.organizerRating} ⭐',
                    style: GoogleFonts.inter(fontSize: 13, color: t.label2)),
                showChevron: false,
                trailing: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.blue.withOpacity(0.1),
                    foregroundColor: AppColors.blue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Napisz',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: g.isFull
                ? _disabledBtn(context, 'Brak wolnych miejsc', t)
                : _joined
                    ? _joinedState(context, t)
                    : _joinBtn(context),
          ),
        ],
      ),
    );
  }

  Widget _joinBtn(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => setState(() => _joined = true),
          child: const Text('Zapisz się'),
        ),
      );

  Widget _joinedState(BuildContext context, AppTokens t) => Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.green.withOpacity(0.3), width: 1.5),
          ),
          child: Column(children: [
            Text('✓ Zapisano!',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green)),
            const SizedBox(height: 3),
            Text('Dostaniesz przypomnienie dzień wcześniej',
                style: GoogleFonts.inter(fontSize: 13, color: t.label2)),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _joined = false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Wypisz się',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ),
      ]);

  Widget _disabledBtn(BuildContext context, String label, AppTokens t) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: t.label4,
            disabledForegroundColor: t.label3,
          ),
          child: Text(label),
        ),
      );
}
