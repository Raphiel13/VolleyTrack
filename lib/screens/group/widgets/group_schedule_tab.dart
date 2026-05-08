import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/events_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../models/models.dart';
import 'add_event_sheet.dart';
import 'event_tile.dart';

// ─── GroupScheduleTab ─────────────────────────────────────────────────────────

class GroupScheduleTab extends ConsumerWidget {
  final Group group;
  const GroupScheduleTab({super.key, required this.group});

  void _showAddSheet(BuildContext context, String uid, String organizerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEventSheet(
        groupId: group.id,
        uid: uid,
        groupName: group.name,
        organizerName: organizerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final currentUser = ref.watch(authRepositoryProvider).currentUser;
    final uid = currentUser?.uid ?? '';
    final organizerName = currentUser?.displayName ?? '';
    // group.adminName przechowuje adminId — mapowanie w GroupRepository._fromDoc
    final isAdmin = uid.isNotEmpty && uid == group.adminName;
    final eventsAsync = ref.watch(groupEventsProvider(group.id));

    return Stack(
      children: [
        eventsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.blue, strokeWidth: 2.5),
          ),
          error: (_, __) => Center(
            child: Text('Nie udało się załadować terminarza',
                style: AppTheme.inter(fontSize: 14, color: t.label3)),
          ),
          data: (events) {
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 44, color: t.label4),
                    const SizedBox(height: 12),
                    Text('Brak zaplanowanych terminów',
                        style: AppTheme.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.label2)),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin
                          ? 'Kliknij + aby dodać pierwszy termin'
                          : 'Admin jeszcze nie dodał terminów',
                      style: AppTheme.inter(fontSize: 13, color: t.label3),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding:
                  EdgeInsets.fromLTRB(16, 12, 16, isAdmin ? 96 : 32),
              itemCount: events.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EventTile(
                  event: events[i],
                  isAdmin: isAdmin,
                  uid: uid,
                  groupId: group.id,
                ),
              ),
            );
          },
        ),

        // ── Admin FAB ─────────────────────────────────────────────────────
        if (isAdmin)
          Positioned(
            right: 20,
            bottom: 24,
            child: GestureDetector(
              onTap: () => _showAddSheet(context, uid, organizerName),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
            ),
          ),
      ],
    );
  }
}
