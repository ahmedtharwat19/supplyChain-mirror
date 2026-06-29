import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload(); // تحديث بيانات المستخدم من السيرفر
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        if (!mounted) return;
        context.go('/dashboard'); // أو أي وجهة مناسبة
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('email_not_verified_yet'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('verification_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('email_verification'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email, size: 100, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              'verification_email_sent'.tr(),
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isChecking ? null : _checkVerification,
                child: _isChecking
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : Text('i_verified'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
