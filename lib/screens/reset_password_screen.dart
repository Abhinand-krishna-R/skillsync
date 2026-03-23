import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _sendResetLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { setState(() => _error = 'Please enter your email address.'); return; }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Reset link sent to email');
      Navigator.pop(context); // Return to login
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = authErrorMessage(e.code); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Something went wrong. Please try again.'; _loading = false; });
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Reset Password", style: GoogleFonts.spaceGrotesk(color: AppColors.txt, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.txt3),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Enter your email", style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.txt3)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: AppColors.s2, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Padding(padding: EdgeInsets.only(left: 14), child: Icon(Icons.mail_outline_rounded, color: AppColors.txt3, size: 17)),
                Expanded(child: TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.txt),
                  decoration: InputDecoration(hintText: "Email address", hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.txt3, fontSize: 14),
                    border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)))),
              ]),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.hot.withValues(alpha: 0.1), border: Border.all(color: AppColors.hot.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: AppColors.hot, size: 16), const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.hot))),
                ])),
            ],
            const SizedBox(height: 24),
            GestureDetector(onTap: _loading ? null : _sendResetLink,
              child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                height: 52,
                decoration: BoxDecoration(gradient: _loading ? null : AppColors.grad1, color: _loading ? AppColors.s3 : null, borderRadius: BorderRadius.circular(12)),
                child: Center(child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('SEND RESET LINK', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white, letterSpacing: 0.04))))),
          ]),
        ),
      ),
    );
  }
}
