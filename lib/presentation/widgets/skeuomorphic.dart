import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A quiet, physical backdrop: warm stone in light mode, charcoal leather in
/// dark mode, with a soft overhead light, a gentle vignette, and fine grain.
///
/// Wrap the whole app with this once (see `MaterialApp.builder`) and keep
/// scaffolds transparent so every route shares the same material.
class SkeuoBackdrop extends StatelessWidget {
  final Widget child;

  const SkeuoBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(isDark: isDark),
        isComplex: true,
        willChange: false,
        child: child,
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final bool isDark;

  _BackdropPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final top = isDark ? const Color(0xFF161819) : const Color(0xFFF2EFE7);
    final bottom = isDark ? const Color(0xFF08090A) : const Color(0xFFDCD6C9);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );

    // Overhead light.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -1.05),
          radius: 1.35,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.075 : 0.42),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // Edge vignette so panels feel inset into the material.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.05,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
          ],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );

    // Fine grain, deterministic so it never shimmers between frames.
    final random = math.Random(isDark ? 11 : 23);
    final grainPaint = Paint();
    final count = (size.width * size.height / 780).clamp(360, 2400).toInt();
    for (var i = 0; i < count; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final alpha =
          (isDark ? 0.030 : 0.040) * (0.35 + random.nextDouble() * 0.65);
      grainPaint.color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(dx, dy),
        0.25 + random.nextDouble() * 0.65,
        grainPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// A raised, beveled surface. The top edge catches light; the bottom edge falls
/// into shadow. Pass [inset] for a debossed well, and [hero] for the darker
/// plaques used by balance and data summaries.
class SkeuoPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool inset;
  final bool hero;
  final bool ornament;
  final Color? color;
  final BorderRadius? borderRadius;

  const SkeuoPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 18,
    this.inset = false,
    this.hero = false,
    this.ornament = false,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final base = color ??
        (hero
            ? (isDark ? const Color(0xFF1A1D1F) : const Color(0xFF24272A))
            : (isDark ? AppColors.darkCard : AppColors.cardWhite));
    final lightEdge = Color.lerp(
      base,
      Colors.white,
      isDark ? 0.055 : 0.42,
    )!;
    final darkEdge = Color.lerp(
      base,
      Colors.black,
      isDark ? 0.24 : 0.045,
    )!;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(radius);
    final borderColor = hero
        ? Colors.white.withValues(alpha: isDark ? 0.14 : 0.20)
        : AppColors.borderOf(context);

    final shadows = inset
        ? const <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.46 : 0.13),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.07),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: isDark ? 0.035 : 0.55),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          ];

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: inset ? [darkEdge, lightEdge] : [lightEdge, darkEdge],
        ),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Stack(
          children: [
            if (inset) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 9,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: isDark ? 0.30 : 0.13),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 6,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: isDark ? 0.05 : 0.28),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Positioned(
                top: 0,
                left: 14,
                right: 14,
                height: 1,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.white.withValues(
                      alpha: isDark ? 0.09 : 0.65,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 0,
                height: 1,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.45 : 0.08,
                    ),
                  ),
                ),
              ),
            ],
            if (ornament)
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(math.max(radius - 6, 4)),
                        border: Border.all(
                          color: AppColors.brassBorderOf(context),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding ?? const EdgeInsets.all(18),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// A debossed well for icons, search fields, progress tracks, and medallions.
class SkeuoInset extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? width;
  final double? height;

  const SkeuoInset({
    super.key,
    required this.child,
    this.radius = 12,
    this.padding,
    this.color,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: SkeuoPanel(
        radius: radius,
        inset: true,
        color: color,
        padding: padding ?? EdgeInsets.zero,
        child: Center(child: child),
      ),
    );
  }
}

class SkeuoIconWell extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final double radius;
  final Color? color;

  const SkeuoIconWell({
    super.key,
    required this.icon,
    this.size = 42,
    this.iconSize = 20,
    this.radius = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SkeuoInset(
      width: size,
      height: size,
      radius: radius,
      child: Icon(
        icon,
        size: iconSize,
        color: color ?? AppColors.accentOf(context),
      ),
    );
  }
}

/// A two-line rule: a dark groove with a light lip below it.
class SkeuoDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  final double height;

  const SkeuoDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Padding(
      padding: EdgeInsets.only(
        top: height / 2,
        bottom: height / 2,
        left: indent,
        right: endIndent,
      ),
      child: Column(
        children: [
          Container(
            height: 1,
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.10),
          ),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.55),
          ),
        ],
      ),
    );
  }
}

/// A tactile primary or secondary action. The surface compresses slightly
/// while held, and the bevel catches light along its top edge.
class SkeuoButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool danger;
  final bool expand;
  final double height;
  final Widget? trailing;

  const SkeuoButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.secondary = false,
    this.danger = false,
    this.expand = true,
    this.height = 52,
    this.trailing,
  });

  @override
  State<SkeuoButton> createState() => _SkeuoButtonState();
}

class _SkeuoButtonState extends State<SkeuoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final enabled = widget.onPressed != null;

    late final List<Color> gradient;
    late final Color foreground;
    late final Color borderColor;

    if (widget.secondary) {
      gradient = isDark
          ? [const Color(0xFF22262A), const Color(0xFF141617)]
          : [const Color(0xFFFBF8F1), const Color(0xFFE5DFD3)];
      foreground = AppColors.textPrimaryOf(context);
      borderColor = AppColors.borderOf(context);
    } else if (widget.danger) {
      gradient = isDark
          ? [const Color(0xFF6B352D), const Color(0xFF3D1D19)]
          : [const Color(0xFF9C5347), const Color(0xFF74372F)];
      foreground = const Color(0xFFFFF4EF);
      borderColor = Colors.white.withValues(alpha: 0.20);
    } else {
      gradient = isDark
          ? [const Color(0xFF2C3033), const Color(0xFF101214)]
          : [const Color(0xFF34383B), const Color(0xFF171A1C)];
      foreground = const Color(0xFFF3EEE4);
      borderColor = Colors.white.withValues(alpha: isDark ? 0.18 : 0.24);
    }

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 19, color: foreground),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.35,
              color: foreground,
            ),
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 10),
          widget.trailing!,
        ],
      ],
    );

    final button = AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? gradient
                : [
                    gradient.first.withValues(alpha: 0.5),
                    gradient.last.withValues(alpha: 0.5),
                  ],
          ),
          border: Border.all(
            color: enabled
                ? borderColor
                : borderColor.withValues(alpha: 0.35),
          ),
          boxShadow: _pressed || !enabled
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.55 : 0.28,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
        ),
        child: content,
      ),
    );

    final tappable = widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        child: tappable,
      ),
    );
  }
}

enum SkeuoBadgeTone { accent, neutral, danger }

class SkeuoBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final SkeuoBadgeTone tone;

  const SkeuoBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = SkeuoBadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    late final Color background;
    late final Color foreground;
    late final Color border;

    switch (tone) {
      case SkeuoBadgeTone.accent:
        background = isDark
            ? const Color(0xFF2A2519)
            : const Color(0xFFE9E1CF);
        foreground = isDark
            ? const Color(0xFFE0C892)
            : const Color(0xFF5F4D2A);
        border = isDark
            ? const Color(0x55C9AD72)
            : const Color(0x558A6F3F);
        break;
      case SkeuoBadgeTone.danger:
        background = isDark
            ? const Color(0xFF2E1D1A)
            : const Color(0xFFEFDCD6);
        foreground =
            isDark ? const Color(0xFFE0A396) : const Color(0xFF7F4238);
        border = isDark
            ? const Color(0x55C47E6E)
            : const Color(0x559C5347);
        break;
      case SkeuoBadgeTone.neutral:
        background = isDark
            ? const Color(0xFF1B1E20)
            : const Color(0xFFF0EBE0);
        foreground = AppColors.textSecondaryOf(context);
        border = AppColors.borderOf(context);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.55),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.35,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// An inset track with a softly lit fill, used for bundle allowance.
class SkeuoProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const SkeuoProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 9,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final fill = color ?? AppColors.accentOf(context);
    final clamped = value.clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0A0B0C), const Color(0xFF1D2022)]
              : [const Color(0xFFCEC8BB), const Color(0xFFEDE8DD)],
        ),
        border: Border.all(
          color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.10),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: clamped == 0 ? 0.001 : clamped,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(fill, Colors.white, 0.20)!,
                      fill,
                      Color.lerp(fill, Colors.black, 0.18)!,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase engraved caption used above grouped content.
class SkeuoSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SkeuoSectionLabel({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
