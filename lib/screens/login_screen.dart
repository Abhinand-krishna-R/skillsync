import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_state.dart';
import '../theme/app_theme.dart';
import 'reset_password_screen.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin; // kept for API compat but unused — auth gate handles nav
  const LoginScreen({super.key, required this.onLogin});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); _confirmPassCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final name = _nameCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text;

    if (email.isEmpty || pass.isEmpty) { setState(() => _error = 'Please fill in all fields.'); return; }
    
    // Client-side validation
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    if (_isRegister && name.isEmpty) { setState(() => _error = 'Please enter your name.'); return; }
    if (_isRegister && pass != confirmPass) { setState(() => _error = 'Passwords do not match.'); return; }

    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthState>();
    try {
      if (_isRegister) {
        await auth.register(email, pass, name);
      } else {
        await auth.signIn(email, pass);
      }
      if (mounted) setState(() => _loading = false);
      // On success: _AuthGate reacts to auth stream automatically
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = authErrorMessage(e.code); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Something went wrong. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Logo
          Center(child: Column(children: [
            ShaderMask(blendMode: BlendMode.srcIn,
              shaderCallback: (b) => AppColors.grad1.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
              child: Text('SkillSync', style: GoogleFonts.spaceGrotesk(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.6))),
            const SizedBox(height: 6),
            Text('Know your gaps. Close them fast.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.txt3)),
          ])),
          const SizedBox(height: 44),

          // Title
          Text(_isRegister ? 'Create account' : 'Welcome back',
            style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.txt, letterSpacing: -0.8)),
          const SizedBox(height: 4),
          Text(_isRegister ? 'Start your career intelligence journey' : 'Sign in to continue your career journey',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.txt3)),
          const SizedBox(height: 28),

          // Form (Animated layout transition)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
              child: child,
            )),
            child: Column(
              key: ValueKey<bool>(_isRegister),
              children: [
                // Name (register only)
                if (_isRegister) ...[
                  _Field(ctrl: _nameCtrl, hint: 'Full name', icon: Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                ],

                // Email
                _Field(ctrl: _emailCtrl, hint: 'Email address', icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress, autofillHints: const [AutofillHints.email]),
                const SizedBox(height: 12),

                // Password
                _Field(ctrl: _passCtrl, hint: 'Password', icon: Icons.lock_outline_rounded, obscure: _obscure, autofillHints: const [AutofillHints.password],
                  suffix: GestureDetector(onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.txt3, size: 18))),
                    
                if (_isRegister) ...[
                  const SizedBox(height: 12),
                  _Field(ctrl: _confirmPassCtrl, hint: 'Confirm password', icon: Icons.lock_outline_rounded, obscure: _obscureConfirm, autofillHints: const [AutofillHints.newPassword],
                    suffix: GestureDetector(onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.txt3, size: 18))),
                ],
              ],
            ),
          ),
            
          const SizedBox(height: 8),

          // Forgot password
          if (!_isRegister) Align(alignment: Alignment.centerRight,
            child: GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
              child: ShaderMask(blendMode: BlendMode.srcIn,
                shaderCallback: (b) => AppColors.grad1.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
                child: Text('Forgot password?', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))))),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.hot.withValues(alpha: 0.1), border: Border.all(color: AppColors.hot.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: AppColors.hot, size: 16), const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.hot))),
              ])),
          ],

          const SizedBox(height: 20),

          // Submit button
          GestureDetector(onTap: _loading ? null : _submit,
            child: AnimatedContainer(duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                gradient: _loading ? null : AppColors.grad1,
                color: _loading ? AppColors.s3 : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _loading ? null : [BoxShadow(color: AppColors.neon.withValues(alpha: 0.4), blurRadius: 20, offset: Offset(0, 4))],
              ),
              child: Center(child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17), const SizedBox(width: 8),
                    Text(_isRegister ? 'CREATE ACCOUNT' : 'SIGN IN',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white, letterSpacing: 0.04)),
                  ])))),

          const SizedBox(height: 24),
          Center(child: GestureDetector(
            onTap: () => setState(() {
              _isRegister = !_isRegister;
              _error = null;
              // Preserve email — user may have already typed it.
              // Only clear password fields and name on mode switch.
              _passCtrl.clear();
              _confirmPassCtrl.clear();
              _nameCtrl.clear();
            }),
            child: RichText(text: TextSpan(children: [
              TextSpan(text: _isRegister ? 'Already have an account? ' : 'New here? ', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.txt3)),
              WidgetSpan(child: ShaderMask(blendMode: BlendMode.srcIn,
                shaderCallback: (b) => AppColors.grad1.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
                child: Text(_isRegister ? 'Sign in' : 'Create account',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))),
            ])),
          )),
        ]),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  final Iterable<String>? autofillHints;

  const _Field({required this.ctrl, required this.hint, required this.icon,
    this.obscure = false, this.suffix, this.keyboard, this.autofillHints});

  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.s2, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Padding(padding: const EdgeInsets.only(left: 14), child: Icon(icon, color: AppColors.txt3, size: 17)),
      Expanded(child: TextField(controller: ctrl, obscureText: obscure, keyboardType: keyboard, autofillHints: autofillHints,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.txt),
        decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.txt3, fontSize: 14),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)))),
      if (suffix != null) Padding(padding: const EdgeInsets.only(right: 14), child: suffix!),
    ]),
  );
}
