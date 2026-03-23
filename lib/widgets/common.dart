import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── Gradient Text ─────────────────────────────────────────────
class GradText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final LinearGradient? gradient;
  const GradText(this.text, {super.key, this.style, this.gradient});
  @override
  Widget build(BuildContext context) {
    final grad = gradient ?? AppColors.grad1;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => grad.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(text.toUpperCase(), style: GoogleFonts.plusJakartaSans(
        fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.12))),
      if (trailing != null) trailing!,
    ]);
  }
}

// ── Glass Card ─────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? radius;
  const GlassCard({super.key, required this.child, this.padding, this.radius});
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: 12),
    padding: padding ?? EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white10.withValues(alpha: 0.03), // Subtle tweak for glass effect
      border: Border.all(color: AppColors.white08),
      borderRadius: radius ?? BorderRadius.circular(14),
    ),
    child: child,
  );
}

// ── App Card ───────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool selected;
  const AppCard({super.key, required this.child, this.padding, this.onTap, this.selected = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.neon.withValues(alpha: 0.08) : AppColors.s1,
        border: Border.all(color: selected ? AppColors.neon : AppColors.s3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected ? [BoxShadow(color: AppColors.neon.withValues(alpha: 0.2), blurRadius: 20)] : null,
      ),
      child: child,
    ),
  );
}

// ── Chip ───────────────────────────────────────────────────────
enum ChipVariant { green, cyan, amber, red, neutral, gradient }
class SkillChip extends StatelessWidget {
  final String label;
  final ChipVariant variant;
  const SkillChip(this.label, {super.key, this.variant = ChipVariant.neutral});
  @override
  Widget build(BuildContext context) {
    Color bg, textColor, border;
    switch (variant) {
      case ChipVariant.green: bg = Color(0xFF10B981).withValues(alpha: 0.15); textColor = Color(0xFF34D399); border = Color(0xFF10B981).withValues(alpha: 0.3); break;
      case ChipVariant.cyan: bg = Color(0xFF06B6D4).withValues(alpha: 0.12); textColor = Color(0xFF22D3EE); border = Color(0xFF06B6D4).withValues(alpha: 0.25); break;
      case ChipVariant.amber: bg = Color(0xFFF59E0B).withValues(alpha: 0.12); textColor = Color(0xFFFBBF24); border = Color(0xFFF59E0B).withValues(alpha: 0.3); break;
      case ChipVariant.red: bg = Color(0xFFFF3B6B).withValues(alpha: 0.1); textColor = Color(0xFFFF6B8A); border = Color(0xFFFF3B6B).withValues(alpha: 0.25); break;
      case ChipVariant.gradient: bg = AppColors.neon.withValues(alpha: 0.15); textColor = AppColors.txt; border = Colors.transparent; break;
      default: bg = AppColors.s2; textColor = AppColors.txt3; border = AppColors.s4;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(20)),
      child: Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 0.04)),
    );
  }
}

// ── Progress Bar ───────────────────────────────────────────────
class SkillBar extends StatelessWidget {
  final String name; final int level; final String? sublabel;
  const SkillBar({super.key, required this.name, required this.level, this.sublabel});
  @override
  Widget build(BuildContext context) {
    final c = level >= 70 ? AppColors.neon : level >= 40 ? AppColors.gold : AppColors.hot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Row(children: [
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.txt2))),
            if (sublabel != null) ...[
              SizedBox(width: 6),
              Text(sublabel!.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: c.withValues(alpha: 0.7), letterSpacing: 0.04)),
            ],
          ])),
          Text('$level', style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
        ]),
        const SizedBox(height: 4),
        Container(height: 3, decoration: BoxDecoration(color: AppColors.s3, borderRadius: BorderRadius.circular(100)),
          child: FractionallySizedBox(widthFactor: level.clamp(0, 100) / 100, alignment: Alignment.centerLeft,
            child: Container(decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)],
            )))),
      ]),
    );
  }
}

// ── Score Ring ─────────────────────────────────────────────────
class ScoreRing extends StatelessWidget {
  final int score; final double size; final double strokeWidth;
  const ScoreRing({super.key, required this.score, this.size = 160, this.strokeWidth = 10});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.scoreColor(score); final c2 = AppColors.scoreColor2(score);
    final label = score >= 80 ? 'Expert' : score >= 60 ? 'Advanced' : score >= 40 ? 'Intermediate' : 'Beginner';
    return SizedBox(width: size, height: size,
      child: CustomPaint(
        painter: _RingPainter(score: score, color: c, color2: c2, strokeWidth: strokeWidth),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (b) => LinearGradient(colors: [c, c2]).createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
            child: Text('$score%', style: GoogleFonts.spaceGrotesk(fontSize: size * 0.2, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: size * 0.075, fontWeight: FontWeight.w600, color: AppColors.txt3)),
        ])),
      ));
  }
}

class _RingPainter extends CustomPainter {
  final int score; final Color color, color2; final double strokeWidth;
  _RingPainter({required this.score, required this.color, required this.color2, required this.strokeWidth});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width - strokeWidth) / 2;
    final bgPaint = Paint()..color = AppColors.white08..style = PaintingStyle.stroke..strokeWidth = strokeWidth;
    canvas.drawCircle(c, r, bgPaint);
    final fgPaint = Paint()
      ..shader = SweepGradient(colors: [color, color2], startAngle: -1.5708, endAngle: -1.5708 + 3.14159 * 2,
          stops: [score / 100, score / 100]).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -1.5708, 3.14159 * 2 * score / 100, false, fgPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter p) => true;
}

// ── Neon Button ────────────────────────────────────────────────
class NeonButton extends StatelessWidget {
  final String label; final VoidCallback? onTap; final bool secondary; final bool small; final IconData? icon;
  const NeonButton(this.label, {super.key, this.onTap, this.secondary = false, this.small = false, this.icon});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: small ? 40 : 52,
      decoration: BoxDecoration(
        gradient: secondary ? null : AppColors.grad1,
        color: secondary ? Colors.transparent : null,
        border: secondary ? Border.all(color: AppColors.s4) : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: secondary ? null : [BoxShadow(color: AppColors.neon.withValues(alpha: 0.4), blurRadius: 20, offset: Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[Icon(icon, size: small ? 15 : 17, color: secondary ? AppColors.txt3 : Colors.white), const SizedBox(width: 8)],
        Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: small ? 11 : 13, fontWeight: FontWeight.w700, color: secondary ? AppColors.txt3 : Colors.white, letterSpacing: 0.04)),
      ]),
    ),
  );
}

// ── TopBar ─────────────────────────────────────────────────────
class SkillTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; final bool showBack; final List<Widget>? actions;
  const SkillTopBar(this.title, {super.key, this.showBack = false, this.actions});
  @override Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    decoration: BoxDecoration(
      color: AppColors.bg.withValues(alpha: 0.9),
      border: Border(bottom: BorderSide(color: AppColors.s3)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(children: [
      if (showBack) ...[
        GestureDetector(onTap: () => Navigator.pop(context),
          child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.s1, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.chevron_left_rounded, color: AppColors.txt3, size: 20))),
        const SizedBox(width: 12),
      ],
      Expanded(child: Text(title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.txt, letterSpacing: -0.3))),
      if (actions != null) ...actions!,
    ]),
  );
}

// ── Tabs ───────────────────────────────────────────────────────
class AppTabs extends StatelessWidget {
  final List<String> tabs; final int current; final ValueChanged<int> onChanged;
  const AppTabs({super.key, required this.tabs, required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.s1,
    child: Row(children: List.generate(tabs.length, (i) => Expanded(child: GestureDetector(
      onTap: () => onChanged(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(
          color: i == current ? AppColors.neon : Colors.transparent, width: 2))),
        child: Text(tabs[i].toUpperCase(), textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700,
            color: i == current ? AppColors.neon : AppColors.txt3, letterSpacing: 0.04,
            shadows: i == current ? [Shadow(color: AppColors.neon.withValues(alpha: 0.6), blurRadius: 12)] : null)),
      ),
    )))),
  );
}

// ── Toast ──────────────────────────────────────────────────────
void showToast(BuildContext context, String message, {bool warn = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(warn ? Icons.warning_rounded : Icons.check_rounded, color: Colors.white, size: 15),
      SizedBox(width: 8),
      Text(message.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.02)),
    ]),
    backgroundColor: warn ? AppColors.gold.withValues(alpha: 0.9) : AppColors.neon.withValues(alpha: 0.9),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    duration: const Duration(milliseconds: 2700),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
  ));
}

String authErrorMessage(String code) {
  switch (code) {
    case 'invalid-credential': return 'Incorrect email or password.';
    case 'user-not-found': return 'No account found with this email.';
    case 'wrong-password': return 'Incorrect password.';
    case 'email-already-in-use': return 'This email is already registered.';
    case 'invalid-email': return 'Please enter a valid email address.';
    case 'weak-password': return 'Password must be at least 6 characters.';
    case 'network-request-failed': return 'Network error. Check your connection.';
    default: return 'Something went wrong. Please try again.';
  }
}

IconData roleIcon(String? iconSlug) {
  switch (iconSlug?.toLowerCase()) {
    case 'code': return Icons.code_rounded;
    case 'palette': return Icons.palette_rounded;
    case 'storage': return Icons.storage_rounded;
    case 'terminal': return Icons.terminal_rounded;
    case 'smartphone': return Icons.smartphone_rounded;
    case 'cloud': return Icons.cloud_queue_rounded;
    case 'security': return Icons.security_rounded;
    case 'analytics': return Icons.analytics_rounded;
    case 'psychology': return Icons.psychology_rounded;
    case 'language': return Icons.language_rounded;
    case 'science': return Icons.science_rounded;
    case 'auto_awesome': return Icons.auto_awesome_rounded;
    case 'target': return Icons.track_changes_rounded;
    case 'trending_up': return Icons.trending_up_rounded;
    default: return Icons.work_outline_rounded;
  }
}

// ── Loading Dialog ───────────────────────────────────────────
void showLoadingDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.s1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.s3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.neon),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.txt2,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a minute...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.txt3,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
