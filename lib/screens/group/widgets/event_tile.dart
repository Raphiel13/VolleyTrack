import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/confirmations_repository.dart';
import '../../../repositories/events_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/ios_widgets.dart';

// ─── EventTile ────────────────────────────────────────────────────────────────

class EventTile extends ConsumerWidget {
  final GroupEvent event;
  final bool isAdmin;
  final String uid;
  final String groupId;

  const EventTile({
    super.key,
    required this.event,
    required this.uid,
    required this.groupId,
    this.isAdmin = false,
  });

  Future<void> _setConfirmation(WidgetRef ref, String status) async {
    if (status.isEmpty) {
      // Wyłączenie potwierdzenia — usunięcie dokumentu oznacza wycofanie zgłoszenia
      await ref.read(confirmationsRepositoryProvider).setConfirmation(
            eventId: event.id,
            userId: uid,
            groupId: groupId,
            status: '',
            userName: '',
          );
      return;
    }

    // Rozwiązanie nazwy wyświetlanej: users/{uid}.name → Auth displayName → 'Gracz'
    String userName =
        ref.read(authRepositoryProvider).currentUser?.displayName ?? '';
    if (uid.isNotEmpty) {
      final name = await ref.read(userRepositoryProvider).getUserName(uid);
      if (name.isNotEmpty) userName = name;
    }
    if (userName.isEmpty) userName = 'Gracz';

    await ref.read(confirmationsRepositoryProvider).setConfirmation(
          eventId: event.id,
          userId: FirebaseAuth.instance.currentUser!.uid,
          groupId: groupId,
          status: status,
          userName: userName,
        );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dlgCtx) => CupertinoAlertDialog(
        title: const Text('Anulować termin?'),
        content: const Text('Termin zostanie oznaczony jako odwołany.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Anuluj termin'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Wróć'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(eventsRepositoryProvider)
        .cancelEventDate(event.id, event.dateTime);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);

    final myStatus =
        ref.watch(userConfirmProvider((event.id, uid))).valueOrNull;
    final confirmedCount =
        ref.watch(confirmedCountProvider(event.id)).valueOrNull ??
            event.confirmedCount;

    const weekdays = ['', 'Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
    const months = [
      '', 'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
      'lip', 'sie', 'wrz', 'paź', 'lis', 'gru',
    ];
    final dt = event.dateTime;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return IosCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              // Kafelek daty
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(weekdays[dt.weekday],
                        style: AppTheme.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue)),
                    Text('${dt.day}',
                        style: AppTheme.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                            letterSpacing: -0.5)),
                    Text(months[dt.month],
                        style: AppTheme.inter(
                            fontSize: 11, color: AppColors.blue)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Szczegóły terminu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time,
                        style: AppTheme.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: t.label)),
                    const SizedBox(height: 3),
                    Text(event.location,
                        style: AppTheme.inter(
                            fontSize: 13, color: t.label2)),
                  ],
                ),
              ),
              // Liczba potwierdzeń
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$confirmedCount',
                      style: AppTheme.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green)),
                  Text('potw.',
                      style:
                          AppTheme.inter(fontSize: 11, color: t.label3)),
                ],
              ),
              // Akcje admina
              if (isAdmin) ...[
                const SizedBox(width: 8),
                // Przełączenie statusu publicznego terminu
                GestureDetector(
                  onTap: () => ref
                      .read(eventsRepositoryProvider)
                      .setOpenToPublic(event.id,
                          isOpen: !event.isOpenToPublic),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: event.isOpenToPublic
                          ? AppColors.green.withValues(alpha: 0.12)
                          : t.bg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: event.isOpenToPublic
                            ? AppColors.green
                            : t.separator,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      event.isOpenToPublic ? 'Otwarta' : 'Zamknij',
                      style: AppTheme.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: event.isOpenToPublic
                            ? AppColors.green
                            : t.label3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Anulowanie terminu
                GestureDetector(
                  onTap: () => _cancel(context, ref),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.xmark,
                        size: 14, color: AppColors.red),
                  ),
                ),
              ] else if (event.isOpenToPublic) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Otwarta',
                    style: AppTheme.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          Divider(height: 0.5, thickness: 0.5, color: t.separator),
          const SizedBox(height: 10),

          // ── Confirmation buttons ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ConfirmBtn(
                  label: '✓  Będę',
                  active: myStatus == 'yes',
                  activeColor: AppColors.green,
                  onTap: uid.isEmpty
                      ? null
                      : () => _setConfirmation(
                          ref, myStatus == 'yes' ? '' : 'yes'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConfirmBtn(
                  label: '✕  Nie mogę',
                  active: myStatus == 'no',
                  activeColor: AppColors.red,
                  onTap: uid.isEmpty
                      ? null
                      : () => _setConfirmation(
                          ref, myStatus == 'no' ? '' : 'no'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── _ConfirmBtn ──────────────────────────────────────────────────────────────

class _ConfirmBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ConfirmBtn({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.12) : t.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? activeColor : t.separator,
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.inter(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? activeColor : t.label2,
            ),
          ),
        ),
      ),
    );
  }
}
