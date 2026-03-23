import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl, _textCtrl, _dotsCtrl;
  late Animation<double> _logoScale, _logoOpacity, _textOpacity, _textSlide, _dotsOpacity;

  @override void initState() {
    super.initState();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _dotsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _logoScale = Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(_textCtrl);
    _textSlide = Tween(begin: 14.0, end: 0.0).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _dotsOpacity = Tween(begin: 0.0, end: 1.0).animate(_dotsCtrl);

    Future.delayed(const Duration(milliseconds: 150), () => _logoCtrl.forward());
    Future.delayed(const Duration(milliseconds: 500), () => _textCtrl.forward());
    Future.delayed(const Duration(milliseconds: 1100), () => _dotsCtrl.forward());
    Future.delayed(const Duration(milliseconds: 2400), () { if (mounted) widget.onComplete(); });
  }

  @override void dispose() { _logoCtrl.dispose(); _textCtrl.dispose(); _dotsCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Material(
    color: AppColors.bg,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(animation: _logoCtrl, builder: (_, __) => Transform.scale(scale: _logoScale.value,
        child: Opacity(opacity: _logoOpacity.value,
          child: Container(width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.grad1, borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: AppColors.neon.withValues(alpha: 0.6), blurRadius: 40), BoxShadow(color: AppColors.neon2.withValues(alpha: 0.3), blurRadius: 80)],
            ),
            child: Center(child: Text('S', style: GoogleFonts.spaceGrotesk(fontSize: 48, fontWeight: FontWeight.w700, color: Colors.white))),
          )))),
      const SizedBox(height: 20),
      AnimatedBuilder(animation: _textCtrl, builder: (_, __) => Transform.translate(
        offset: Offset(0, _textSlide.value),
        child: Opacity(opacity: _textOpacity.value, child: Column(children: [
          ShaderMask(blendMode: BlendMode.srcIn,
            shaderCallback: (b) => AppColors.grad1.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Text('SkillSync', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1.2, decoration: TextDecoration.none)),
            )),
          const SizedBox(height: 6),
          Text('CAREER INTELLIGENCE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.18)),
        ])),
      )),
      const SizedBox(height: 32),
      AnimatedBuilder(animation: _dotsCtrl, builder: (_, __) => Opacity(opacity: _dotsOpacity.value,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _PulseDot(color: AppColors.neon, delay: 100),
          const SizedBox(width: 6),
          _PulseDot(color: AppColors.neon2, delay: 400),
          const SizedBox(width: 6),
          _PulseDot(color: AppColors.neon3, delay: 700),
        ]),
      )),
    ]),
  );
}

class _PulseDot extends StatefulWidget {
  final Color color; final int delay;
  const _PulseDot({required this.color, required this.delay});
  @override State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Opacity(opacity: 0.3 + 0.7 * _ctrl.value,
      child: Container(width: 6, height: 6, decoration: BoxDecoration(
        color: widget.color, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: widget.color, blurRadius: 8)]))));
}
