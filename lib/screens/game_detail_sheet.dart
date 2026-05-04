import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

class GameDetailSheet extends ConsumerStatefulWidget {
  final NearbyGame game;
  const GameDetailSheet({super.key, required this.game});

  @override
  ConsumerState<GameDetailSheet> createState() => _GameDetailSheetState();
}

class _GameDetailSheetState extends ConsumerState<GameDetailSheet> {
  bool _joined = false;
  bool _hasRated = false;
  bool _checkingRating = true;
  bool _savingRating = false;

  @override
  void initState() {
    super.initState();
    _checkExistingRating();
  }

  Future<void> _checkExistingRating() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
    if (uid.isEmpty || widget.game.organizerId.isEmpty) {
      setState(() => _checkingRating = false);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('ratings')
        .where('gameId', isEqualTo: widget.game.id)
        .where('raterId', isEqualTo: uid)
        .limit(1)
        .get();
    if (mounted) {
      setState(() {
        _hasRated = snap.docs.isNotEmpty;
        _checkingRating = false;
      });
    }
  }

  Future<void> _submitRating(int stars) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    setState(() => _savingRating = true);
    try {
      await FirebaseFirestore.instance.collection('ratings').add({
        'gameId': widget.game.id,
        'raterId': uid,
        'organizerId': widget.game.organizerId,
        'rating': stars,
        'createdAt': Timestamp.now(),
      });
      await ref
          .read(userRepositoryProvider)
          .updateOrganizerRating(widget.game.organizerId);
      if (mounted) {
        setState(() => _hasRated = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ocena zapisana', style: AppTheme.inter()),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Nie udało się zapisać oceny', style: AppTheme.inter()),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _savingRating = false);
    }
  }

  Future<void> _showRatingDialog() async {
    int selected = 0;
    final t = AppTokens.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: t.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Oceń organizatora',
            style: AppTheme.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: t.label),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.game.organizerName.isNotEmpty
                    ? widget.game.organizerName
                    : 'Organizator',
                style: AppTheme.inter(fontSize: 14, color: t.label2),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selected = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        selected >= star
                            ? CupertinoIcons.star_fill
                            : CupertinoIcons.star,
                        size: 36,
                        color: selected >= star
                            ? AppColors.orange
                            : t.label4,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Anuluj',
                  style: AppTheme.inter(fontSize: 15, color: t.label2)),
            ),
            TextButton(
              onPressed: selected == 0
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _submitRating(selected);
                    },
              child: Text('Zapisz',
                  style: AppTheme.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected == 0 ? t.label4 : AppColors.blue,
                  )),
            ),
          ],
        ),
      ),
    );
  }

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
    final isPast = g.dateTime.isBefore(DateTime.now());
    final canRate = isPast &&
        g.organizerId.isNotEmpty &&
        !_hasRated &&
        !_checkingRating;

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
                        if (isPast)
                          const ChipBadge('Zakończona',
                              variant: ChipVariant.green),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        g.title,
                        style: AppTheme.inter(
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
                      color: t.label4.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.xmark,
                        size: 16, color: t.label2),
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
                      emoji: '📍',
                      bgColor: t.label4.withValues(alpha: 0.3)),
                  title: Text(g.location,
                      style: AppTheme.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.label)),
                  subtitle: Text('${g.distanceKm} km od Ciebie',
                      style: AppTheme.inter(fontSize: 13, color: t.label2)),
                  showChevron: false,
                ),
                const IosSeparator(indent: 16),
                IosRow(
                  leading: SfIconBox(
                      emoji: '🕐',
                      bgColor: t.label4.withValues(alpha: 0.3)),
                  title: Text(
                    '${_dayLabel(g.dateTime)}, '
                    '${g.dateTime.hour.toString().padLeft(2, '0')}:'
                    '${g.dateTime.minute.toString().padLeft(2, '0')}',
                    style: AppTheme.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: t.label),
                  ),
                  subtitle: Text('Termin',
                      style:
                          AppTheme.inter(fontSize: 13, color: t.label2)),
                  showChevron: false,
                ),
                const IosSeparator(indent: 16),
                IosRow(
                  leading: SfIconBox(
                      emoji: '🏐',
                      bgColor: t.label4.withValues(alpha: 0.3)),
                  title: Text(g.level.label,
                      style: AppTheme.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.label)),
                  subtitle: Text('Poziom gry',
                      style:
                          AppTheme.inter(fontSize: 13, color: t.label2)),
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
                        style: AppTheme.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.label,
                        )),
                    Text(
                      g.isFull
                          ? 'Brak miejsc'
                          : '${g.spotsLeft} ${g.spotsLeft == 1 ? "wolne" : "wolnych"}',
                      style: AppTheme.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: g.spotsLeft <= 2
                            ? AppColors.red
                            : AppColors.green,
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
                        margin: EdgeInsets.only(
                            right: i < total - 1 ? 4 : 0),
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
                              shape: BoxShape.circle,
                              color: AppColors.blue)),
                      const SizedBox(width: 5),
                      Text('$taken zapisanych',
                          style: AppTheme.inter(
                              fontSize: 11, color: t.label2)),
                    ]),
                    Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: t.label4)),
                      const SizedBox(width: 5),
                      Text('${g.spotsLeft} wolnych',
                          style: AppTheme.inter(
                              fontSize: 11, color: t.label2)),
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
              child: Column(
                children: [
                  IosRow(
                    leading: UserAvatar(name: g.organizerName, size: 36),
                    title: Text(
                      g.organizerName.isNotEmpty
                          ? g.organizerName
                          : 'Organizator',
                      style: AppTheme.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.label),
                    ),
                    subtitle: Text(
                      g.organizerRating > 0
                          ? 'Organizator · ${g.organizerRating.toStringAsFixed(1)} ⭐'
                          : 'Organizator',
                      style:
                          AppTheme.inter(fontSize: 13, color: t.label2),
                    ),
                    showChevron: false,
                    trailing: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        backgroundColor:
                            AppColors.blue.withValues(alpha: 0.1),
                        foregroundColor: AppColors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Napisz',
                          style: AppTheme.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (canRate || _hasRated) ...[
                    const IosSeparator(indent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: _hasRated
                          ? Row(children: [
                              const Icon(CupertinoIcons.star_fill,
                                  size: 14, color: AppColors.orange),
                              const SizedBox(width: 6),
                              Text(
                                'Już oceniłeś/aś tę grę',
                                style: AppTheme.inter(
                                    fontSize: 13, color: t.label2),
                              ),
                            ])
                          : SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _savingRating
                                    ? null
                                    : _showRatingDialog,
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      AppColors.orange.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.orange,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: _savingRating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            color: AppColors.orange,
                                            strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              CupertinoIcons.star_fill,
                                              size: 14),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Oceń organizatora',
                                            style: AppTheme.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // CTA
          if (!isPast)
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

  Widget _joinedState(BuildContext context, AppTokens t) =>
      Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.green.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(children: [
            Text('✓ Zapisano!',
                style: AppTheme.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green)),
            const SizedBox(height: 3),
            Text('Dostaniesz przypomnienie dzień wcześniej',
                style: AppTheme.inter(fontSize: 13, color: t.label2)),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _joined = false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(
                  color: AppColors.red.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Wypisz się',
                style: AppTheme.inter(
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
