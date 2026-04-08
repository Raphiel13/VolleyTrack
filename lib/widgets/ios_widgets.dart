import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

// ─── IosCard ──────────────────────────────────────────────────────────────────

class IosCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;

  const IosCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Material(
      color: t.bg2,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// ─── IosRow ───────────────────────────────────────────────────────────────────

class IosRow extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const IosRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right,
                  size: 14, color: t.label4),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── IosSeparator ─────────────────────────────────────────────────────────────

class IosSeparator extends StatelessWidget {
  final double indent;

  const IosSeparator({super.key, this.indent = 56});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(height: 0.5, thickness: 0.5, color: t.separator),
    );
  }
}

// ─── SectionLabel ─────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const SectionLabel(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: t.label2,
              letterSpacing: 0.3,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── SfIconBox ────────────────────────────────────────────────────────────────

class SfIconBox extends StatelessWidget {
  final String emoji;
  final Color bgColor;
  final double size;

  const SfIconBox({
    super.key,
    required this.emoji,
    required this.bgColor,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}

// ─── UserAvatar ───────────────────────────────────────────────────────────────

class UserAvatar extends StatelessWidget {
  final String name;
  final double size;

  const UserAvatar({super.key, required this.name, this.size = 40});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue, AppColors.teal],
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: GoogleFonts.inter(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── ChipBadge ────────────────────────────────────────────────────────────────

enum ChipVariant { blue, green, orange, red, gray }

class ChipBadge extends StatelessWidget {
  final String label;
  final ChipVariant variant;

  const ChipBadge(this.label, {super.key, this.variant = ChipVariant.gray});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      ChipVariant.blue   => (AppColors.blue.withOpacity(0.12),   AppColors.blue),
      ChipVariant.green  => (AppColors.green.withOpacity(0.12),  AppColors.green),
      ChipVariant.orange => (AppColors.orange.withOpacity(0.12), AppColors.orange),
      ChipVariant.red    => (AppColors.red.withOpacity(0.12),    AppColors.red),
      ChipVariant.gray   => (
          const Color(0x1E767680),
          const Color(0xFF8E8E93),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ─── LevelDots ────────────────────────────────────────────────────────────────

class LevelDots extends StatelessWidget {
  final PlayerLevel level;
  final int max;

  const LevelDots({super.key, required this.level, this.max = 5});

  @override
  Widget build(BuildContext context) {
    final idx = PlayerLevel.values.indexOf(level);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        max,
        (i) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i <= idx
                ? AppColors.levelColors[idx]
                : AppTokens.of(context).label4,
          ),
        ),
      ),
    );
  }
}

// ─── IosSegmentedControl ──────────────────────────────────────────────────────

class IosSegmentedControl<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const IosSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0x1E767680),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: options.map((opt) {
          final isActive = opt.$1 == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive ? t.bg2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    opt.$2,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isActive ? t.label : t.label2,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── IosSwitch ────────────────────────────────────────────────────────────────

class IosSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const IosSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.green,
    );
  }
}

// ─── KmSlider ─────────────────────────────────────────────────────────────────

class KmSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  static const double _min = 0.5;
  static const double _max = 50.0;
  static const List<double> _snaps = [
    0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 20.0, 30.0, 50.0,
  ];

  const KmSlider({super.key, required this.value, required this.onChanged});

  String _fmt(double v) {
    if (v < 1) return '${(v * 1000).round()} m';
    return v == v.roundToDouble()
        ? '${v.round()} km'
        : '${v.toStringAsFixed(1)} km';
  }

  double _toSlider(double km) =>
      (_log(km / _min) / _log(_max / _min)).clamp(0.0, 1.0);

  double _fromSlider(double t) {
    final raw = _min * _pow(_max / _min, t);
    for (final s in _snaps) {
      if ((_toSlider(s) - t).abs() < 0.04) return s;
    }
    return (raw * 10).round() / 10.0;
  }

  double _log(num x) {
    if (x <= 0) return 0;
    double r = 0;
    double n = x.toDouble();
    while (n >= 2.71828) {
      r++;
      n /= 2.71828;
    }
    return r + (n - 1);
  }

  double _pow(double base, double exp) {
    if (base <= 0) return 0;
    double r = 1, term = 1;
    final x = exp * _log(base);
    for (int i = 1; i < 20; i++) {
      term *= x / i;
      r += term;
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final pct = _toSlider(value);
    final count = value <= 2
        ? 1
        : value <= 5
            ? 2
            : value <= 15
                ? 3
                : value <= 30
                    ? 4
                    : 5;

    return IosCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zasięg wyszukiwania',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.label,
                      ),
                    ),
                    Text(
                      'Przeciągnij aby zmienić obszar',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: t.label2),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _fmt(value),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.blue,
              inactiveTrackColor: t.label4,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 13),
              overlayColor: AppColors.blue.withOpacity(0.15),
              overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 22),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: pct,
              onChanged: (v) => onChanged(_fromSlider(v)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _snaps.asMap().entries.map((e) {
              final isActive = e.value == value;
              final lbl = e.key == 0
                  ? '500m'
                  : e.key == _snaps.length - 1
                      ? '50km'
                      : '${e.value.round()}';
              return GestureDetector(
                onTap: () => onChanged(e.value),
                child: Text(
                  lbl,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isActive ? AppColors.blue : t.label3,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.green.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Text(
                  '$count gier ',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
                Text(
                  'w promieniu ${_fmt(value)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: t.label2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GameCard ─────────────────────────────────────────────────────────────────

class GameCard extends StatelessWidget {
  final NearbyGame game;
  final bool isMatch;
  final VoidCallback? onTap;

  const GameCard({
    super.key,
    required this.game,
    this.isMatch = false,
    this.onTap,
  });

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month) return 'Dziś';
    if (dt.day == now.day + 1 && dt.month == now.month) return 'Jutro';
    const days = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
    return days[dt.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(16),
        border: isMatch
            ? Border.all(color: AppColors.blue.withOpacity(0.3))
            : null,
        boxShadow: isMatch
            ? [
                BoxShadow(
                  color: AppColors.blue.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SfIconBox(
                  emoji: game.category == GameCategory.beach
                      ? '🏖️'
                      : '🏛️',
                  bgColor: game.category == GameCategory.beach
                      ? AppColors.orange.withOpacity(0.12)
                      : AppColors.blue.withOpacity(0.12),
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMatch) ...[
                        ChipBadge(
                          '✦ Pasuje do profilu',
                          variant: ChipVariant.blue,
                        ),
                        const SizedBox(height: 5),
                      ],
                      Text(
                        game.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: t.label,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '📍 ${game.location}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: t.label2),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ChipBadge(game.level.label),
                          ChipBadge(
                            '${game.spotsLeft} '
                            '${game.spotsLeft == 1 ? "miejsce" : "miejsca"}',
                            variant: game.spotsLeft <= 2
                                ? ChipVariant.red
                                : ChipVariant.green,
                          ),
                          ChipBadge('${game.distanceKm} km'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${game.dateTime.hour.toString().padLeft(2, '0')}:'
                      '${game.dateTime.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dayLabel(game.dateTime),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: t.label3),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_right,
                    size: 14, color: t.label4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}