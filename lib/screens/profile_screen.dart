import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile user;
  final ValueChanged<UserProfile> onSave;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _name;
  late TextEditingController _bio;
  late PlayerLevel _level;
  late List<PlayerPosition> _positions;
  late AppThemeMode _themeMode;
  bool _saved = false;

  bool _notifGames = true;
  bool _notifGroups = true;
  bool _notifResults = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _bio = TextEditingController(text: widget.user.bio);
    _level = widget.user.level;
    _positions = List.from(widget.user.positions);
    _themeMode = widget.user.themeMode;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(widget.user.copyWith(
      name: _name.text.trim(),
      bio: _bio.text.trim(),
      level: _level,
      positions: _positions,
      themeMode: _themeMode,
    ));
    setState(() => _saved = true);
    Future.delayed(
      const Duration(seconds: 2),
      () => setState(() => _saved = false),
    );
  }

  void _togglePos(PlayerPosition p) {
    setState(() {
      if (_positions.contains(p)) {
        _positions.remove(p);
      } else {
        _positions.add(p);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final levelIdx = PlayerLevel.values.indexOf(_level);

    return CustomScrollView(
      slivers: [
        // ── Profile hero ───────────────────────────────────────────
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.blue.withOpacity(0.14),
                    t.bg.withOpacity(0),
                  ],
                ),
              ),
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              child: Column(children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.blue, AppColors.teal],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x59007AFF),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _name.text
                              .split(' ')
                              .map((n) => n.isNotEmpty ? n[0] : '')
                              .take(2)
                              .join()
                              .toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: -4,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: t.bg2,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.separator),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('✏️', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _name.text.isEmpty ? 'Twój profil' : _name.text,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: t.label,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_level.label,
                    style: GoogleFonts.inter(fontSize: 15, color: t.label2)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ['24', 'Mecze'],
                    ['16', 'W'],
                    ['67%', 'Win%'],
                  ].asMap().entries.map((e) {
                    return Row(children: [
                      if (e.key > 0)
                        Container(
                          width: 1,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          color: t.separator,
                        ),
                      Column(children: [
                        Text(e.value[0],
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: t.label,
                              letterSpacing: -0.5,
                            )),
                        Text(e.value[1],
                            style: GoogleFonts.inter(
                                fontSize: 13, color: t.label2)),
                      ]),
                    ]);
                  }).toList(),
                ),
              ]),
            ),
          ),
        ),

        SliverList(
          delegate: SliverChildListDelegate([
            // ── Personal data ────────────────────────────────────
            const SectionLabel('Dane osobowe'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Imię i nazwisko',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: t.label2)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _name,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                          ),
                          style:
                              GoogleFonts.inter(fontSize: 16, color: t.label),
                        ),
                      ],
                    ),
                  ),
                  const IosSeparator(indent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: t.label2)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _bio,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Napisz coś o sobie…',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                            hintStyle: GoogleFonts.inter(
                                color: t.label3, fontSize: 15),
                          ),
                          style:
                              GoogleFonts.inter(fontSize: 15, color: t.label),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),

            // ── Level slider ─────────────────────────────────────
            const SectionLabel('Poziom gry'),
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
                        Text(_level.label,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.levelColors[levelIdx],
                            )),
                        Row(
                          children: List.generate(5, (i) {
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _level = PlayerLevel.values[i]),
                              child: Container(
                                width: 28,
                                height: 5,
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  color: i <= levelIdx
                                      ? AppColors.levelColors[levelIdx]
                                      : t.label4,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: AppColors.levelColors[levelIdx],
                        inactiveTrackColor: t.label4,
                        thumbColor: Colors.white,
                        overlayColor:
                            AppColors.levelColors[levelIdx].withOpacity(0.15),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 12),
                        showValueIndicator: ShowValueIndicator.never,
                      ),
                      child: Slider(
                        value: levelIdx.toDouble(),
                        min: 0,
                        max: PlayerLevel.values.length - 1,
                        divisions: PlayerLevel.values.length - 1,
                        onChanged: (v) => setState(
                            () => _level = PlayerLevel.values[v.round()]),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Początkujący',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: t.label3)),
                        Text('Wyczynowy',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: t.label3)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '💡 Wpływa na dopasowanie gier w wyszukiwarce',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Positions ────────────────────────────────────────
            const SectionLabel('Preferowane pozycje'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PlayerPosition.values.map((p) {
                        final sel = _positions.contains(p);
                        return GestureDetector(
                          onTap: () => _togglePos(p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.blue : t.bg2,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: sel ? AppColors.blue : t.separator,
                              ),
                            ),
                            child: Text(p.label,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: sel ? Colors.white : t.label,
                                )),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Wybrano: ${_positions.isEmpty ? "brak" : _positions.map((p) => p.label).join(", ")}',
                      style: GoogleFonts.inter(fontSize: 13, color: t.label3),
                    ),
                  ],
                ),
              ),
            ),

            // ── Theme picker ─────────────────────────────────────
            const SectionLabel('Wygląd'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tryb kolorów',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: t.label,
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  IosSegmentedControl<AppThemeMode>(
                    options: const [
                      (AppThemeMode.light, '☀️ Jasny'),
                      (AppThemeMode.system, 'Systemowy'),
                      (AppThemeMode.dark, '🌙 Ciemny'),
                    ],
                    selected: _themeMode,
                    onChanged: (v) {
                      setState(() => _themeMode = v);
                      widget.onSave(widget.user.copyWith(themeMode: v));
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    switch (_themeMode) {
                      AppThemeMode.system => 'Podąża za ustawieniami systemu',
                      AppThemeMode.dark => 'Wymuszony tryb ciemny',
                      AppThemeMode.light => 'Wymuszony tryb jasny',
                    },
                    style: GoogleFonts.inter(fontSize: 12, color: t.label3),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ),

            // ── Notifications ────────────────────────────────────
            const SectionLabel('Powiadomienia'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Column(children: [
                  IosRow(
                    leading: SfIconBox(
                        emoji: '📍', bgColor: AppColors.blue.withOpacity(0.12)),
                    title: Text('Nowe gry w okolicy',
                        style: GoogleFonts.inter(fontSize: 16, color: t.label)),
                    showChevron: false,
                    trailing: IosSwitch(
                      value: _notifGames,
                      onChanged: (v) => setState(() => _notifGames = v),
                    ),
                  ),
                  const IosSeparator(),
                  IosRow(
                    leading: SfIconBox(
                        emoji: '👥', bgColor: AppColors.teal.withOpacity(0.12)),
                    title: Text('Zapisy grupowe',
                        style: GoogleFonts.inter(fontSize: 16, color: t.label)),
                    showChevron: false,
                    trailing: IosSwitch(
                      value: _notifGroups,
                      onChanged: (v) => setState(() => _notifGroups = v),
                    ),
                  ),
                  const IosSeparator(),
                  IosRow(
                    leading: SfIconBox(
                        emoji: '📊',
                        bgColor: AppColors.orange.withOpacity(0.12)),
                    title: Text('Wyniki meczów',
                        style: GoogleFonts.inter(fontSize: 16, color: t.label)),
                    showChevron: false,
                    trailing: IosSwitch(
                      value: _notifResults,
                      onChanged: (v) => setState(() => _notifResults = v),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // ── Save button ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    key: ValueKey(_saved),
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _saved ? AppColors.green : AppColors.blue,
                    ),
                    child: Text(_saved ? '✓ Zapisano!' : 'Zapisz profil'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Sign out ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Wyloguj się',
                      style: GoogleFonts.inter(
                          fontSize: 17, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ],
    );
  }
}
