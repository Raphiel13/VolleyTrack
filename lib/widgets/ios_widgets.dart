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