import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' show placemarkFromCoordinates;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../repositories/events_repository.dart';
import '../../../repositories/group_repository.dart';
import '../../../repositories/notifications_repository.dart';
import '../../../theme/app_theme.dart';

// ─── AddEventSheet ────────────────────────────────────────────────────────────

class AddEventSheet extends ConsumerStatefulWidget {
  final String groupId;
  final String uid;
  final String groupName;
  final String organizerName;

  const AddEventSheet({
    super.key,
    required this.groupId,
    required this.uid,
    required this.groupName,
    required this.organizerName,
  });

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  final _locationCtrl = TextEditingController();
  final _maxPlayersCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate = _roundedNow();
  bool _isOpenToPublic = false;
  bool _loading = false;
  double? _latitude;
  double? _longitude;

  static DateTime _roundedNow() {
    final base = DateTime.now().add(const Duration(days: 1));
    final minute = (base.minute ~/ 5) * 5;
    return DateTime(base.year, base.month, base.day, base.hour, minute);
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _maxPlayersCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker(BuildContext context) async {
    final initialLoc = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : null;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _LocationPickerScreen(initialLocation: initialLoc),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result['lat'] as double;
        _longitude = result['lng'] as double;
        _locationCtrl.text = result['address'] as String;
      });
    }
  }

  void _pickDateTime(BuildContext context) {
    final t = AppTokens.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      // Użycie kontekstu popupu do Navigator.pop — kontekst zewnętrzny może wygasnąć
      // gdy picker jest widoczny, co powoduje błąd null w Navigator.of(context)
      builder: (popupCtx) => Container(
        height: 300,
        color: t.bg,
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: t.bg2,
                border: Border(
                    bottom: BorderSide(color: t.separator, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(popupCtx),
                    child: Text('Anuluj',
                        style: AppTheme.inter(
                            fontSize: 16, color: t.label2)),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(popupCtx),
                    child: Text('Gotowe',
                        style: AppTheme.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: _selectedDate,
                minimumDate: DateTime.now(),
                use24hFormat: true,
                minuteInterval: 5,
                onDateTimeChanged: (dt) =>
                    setState(() => _selectedDate = dt),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Podaj lokalizację', style: AppTheme.inter()),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Wybierz lokalizację z listy sugestii',
            style: AppTheme.inter()),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _loading = true);

    try {
      // Tworzenie terminu, aktualizacja nextGame w grupie i wysyłanie powiadomień do członków
      // 1. Utwórz dokument terminu
      await ref.read(eventsRepositoryProvider).createEvent(
            groupId: widget.groupId,
            groupName: widget.groupName,
            dateTime: _selectedDate,
            location: _locationCtrl.text.trim(),
            createdBy: FirebaseAuth.instance.currentUser!.uid,
            createdByName: widget.organizerName,
            isOpenToPublic: _isOpenToPublic,
            maxPlayers: _isOpenToPublic
                ? int.tryParse(_maxPlayersCtrl.text) ?? 10
                : null,
            latitude: _latitude,
            longitude: _longitude,
            price: double.tryParse(
                _priceCtrl.text.trim().replaceAll(',', '.')),
          );

      // 2. Zaktualizuj etykietę nextGame w dokumencie grupy
      await ref.read(groupRepositoryProvider).setNextGame(
          widget.groupId,
          DateFormat('dd.MM.yyyy HH:mm').format(_selectedDate));

      // 3. Pobierz listę członków i wyślij powiadomienia
      final groupDoc = await ref
          .read(groupRepositoryProvider)
          .getGroupDoc(widget.groupId);
      final gd = groupDoc.data();
      if (gd != null) {
        final memberIds =
            List<String>.from((gd['members'] as List?) ?? []);
        final groupName = gd['name'] as String? ?? '';
        await ref
            .read(notificationsRepositoryProvider)
            .sendNewEventNotifications(
              groupId: widget.groupId,
              groupName: groupName,
              memberIds: memberIds,
            );
      }

      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      debugPrint('Błąd: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Nie udało się dodać terminu',
              style: AppTheme.inter()),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    const weekdays = [
      '', 'Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'
    ];
    const months = [
      '', 'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
      'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
    ];
    final dt = _selectedDate;
    final dateLabel =
        '${weekdays[dt.weekday]}, ${dt.day} ${months[dt.month]} · '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Nowy termin',
                style: AppTheme.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: t.label),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // ── Date & time picker ───────────────────────────────────────
            Text('Data i godzina',
                style: AppTheme.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: t.label2)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _pickDateTime(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(CupertinoIcons.calendar,
                      size: 18, color: AppColors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(dateLabel,
                        style: AppTheme.inter(
                            fontSize: 15, color: t.label)),
                  ),
                  Icon(CupertinoIcons.chevron_right,
                      size: 14, color: t.label3),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // ── Location field ───────────────────────────────────────────
            Text('Lokalizacja',
                style: AppTheme.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: t.label2)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openLocationPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: _latitude != null
                      ? Border.all(color: AppColors.blue, width: 1.5)
                      : null,
                ),
                child: Row(children: [
                  Icon(
                    _latitude != null
                        ? CupertinoIcons.location_fill
                        : CupertinoIcons.location,
                    size: 16,
                    color:
                        _latitude != null ? AppColors.blue : t.label3,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locationCtrl.text.isNotEmpty
                          ? _locationCtrl.text
                          : 'Zaznacz na mapie',
                      style: AppTheme.inter(
                        fontSize: 15,
                        color: _locationCtrl.text.isNotEmpty
                            ? t.label
                            : t.label4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right,
                      size: 14, color: t.label3),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // ── Open to public ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Otwarta dla osób spoza grupy',
                          style: AppTheme.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: t.label)),
                      const SizedBox(height: 2),
                      Text('Gra pojawi się na mapie publicznej',
                          style: AppTheme.inter(
                              fontSize: 12, color: t.label2)),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: _isOpenToPublic,
                  activeTrackColor: AppColors.green,
                  onChanged: (v) =>
                      setState(() => _isOpenToPublic = v),
                ),
              ]),
            ),
            if (_isOpenToPublic) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _maxPlayersCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Maks. liczba graczy (domyślnie 10)',
                  hintStyle: AppTheme.inter(color: t.label4),
                  filled: true,
                  fillColor: t.bg2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.blue, width: 1.5),
                  ),
                  prefixIcon: const Icon(CupertinoIcons.person_2,
                      size: 16, color: AppColors.blue),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                style: AppTheme.inter(fontSize: 15, color: t.label),
              ),
            ],
            const SizedBox(height: 10),

            // ── Price ─────────────────────────────────────────────────────
            TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Cena (opcjonalnie, np. 15.00)',
                hintStyle: AppTheme.inter(color: t.label4),
                filled: true,
                fillColor: t.bg2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.blue, width: 1.5),
                ),
                prefixIcon: const Icon(CupertinoIcons.money_dollar_circle,
                    size: 16, color: AppColors.blue),
                suffixText: 'zł',
                suffixStyle: AppTheme.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blue),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              style: AppTheme.inter(fontSize: 15, color: t.label),
            ),
            const SizedBox(height: 28),

            // ── Submit ───────────────────────────────────────────────────
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  disabledBackgroundColor:
                      AppColors.blue.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text('Dodaj termin',
                        style: AppTheme.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _LocationPickerScreen ────────────────────────────────────────────────────

class _LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const _LocationPickerScreen({this.initialLocation});

  @override
  State<_LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  static const _kPoland = LatLng(52.0, 19.0);

  GoogleMapController? _mapCtrl;
  late LatLng _center;
  String _address = '';
  bool _geocoding = false;
  Timer? _geocodeTimer;

  @override
  void initState() {
    super.initState();
    _center = widget.initialLocation ?? _kPoland;
    _reverseGeocode(_center);
    if (widget.initialLocation == null) _tryUserLocation();
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _tryUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) { return; }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = loc);
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(loc, 14));
      _reverseGeocode(loc);
    } catch (_) {}
  }

  // Odwrotne geokodowanie współrzędnych na adres — aktualizacja przy każdym zatrzymaniu kamery
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() {
      _geocoding = true;
      _address = '';
    });
    try {
      final marks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (marks.isNotEmpty) {
        final p = marks.first;
        final parts = <String>[
          if (p.street?.isNotEmpty == true) p.street!,
          if (p.subLocality?.isNotEmpty == true) p.subLocality!,
          if (p.locality?.isNotEmpty == true) p.locality!,
        ];
        setState(() => _address = parts.isNotEmpty
            ? parts.join(', ')
            : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _address =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.blue,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Wybierz lokalizację',
            style: AppTheme.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.label)),
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: t.separator),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: widget.initialLocation != null ? 15.0 : 6.0,
                  ),
                  onMapCreated: (c) => _mapCtrl = c,
                  onCameraMove: (pos) => _center = pos.target,
                  onCameraIdle: () {
                    _geocodeTimer?.cancel();
                    _geocodeTimer = Timer(
                      const Duration(milliseconds: 500),
                      () => _reverseGeocode(_center),
                    );
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  gestureRecognizers: const {},
                ),
                // Niebieski pin jako nakładka — nieruchomy względem mapy
                Center(
                  child: Padding(
                    // Przesunięcie w górę o połowę wysokości pinu — czubek wskazuje środek mapy
                    padding: const EdgeInsets.only(bottom: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x59007AFF),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.location_pin,
                              color: Colors.white, size: 22),
                        ),
                        // Nóżka pinu
                        Container(
                            width: 3, height: 12, color: AppColors.blue),
                        Container(
                          width: 8,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(children: [
                    _ZoomButton(
                        label: '+',
                        onTap: () => _mapCtrl
                            ?.animateCamera(CameraUpdate.zoomIn())),
                    const SizedBox(height: 1),
                    _ZoomButton(
                        label: '−',
                        onTap: () => _mapCtrl
                            ?.animateCamera(CameraUpdate.zoomOut())),
                  ]),
                ),
              ],
            ),
          ),
          // Adres i przycisk potwierdzenia
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: t.bg,
              border:
                  Border(top: BorderSide(color: t.separator, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 36,
                  child: _geocoding
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.blue, strokeWidth: 2.5),
                          ),
                        )
                      : Row(children: [
                          const Icon(CupertinoIcons.location_fill,
                              size: 16, color: AppColors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _address.isNotEmpty
                                  ? _address
                                  : 'Przesuń mapę, aby wybrać miejsce',
                              style: AppTheme.inter(
                                fontSize: 14,
                                color: _address.isNotEmpty
                                    ? t.label
                                    : t.label3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_address.isEmpty || _geocoding)
                        ? null
                        : () => Navigator.pop(context, {
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'address': _address,
                            }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      disabledBackgroundColor:
                          AppColors.blue.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Potwierdź lokalizację',
                        style: AppTheme.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _ZoomButton ──────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ZoomButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }
}
