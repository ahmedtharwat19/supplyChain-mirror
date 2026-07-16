// signup_form.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  /// ✅ التسجيل: بيعمل بس حساب Firebase Auth + document في users
  /// (بدون trialUsed أو license خالص). إنشاء الـ trial license الكامل
  /// (بكل بيانات الجهاز والبصمة) بيتم تلقائيًا من AutoLicenseService
  /// في splash_screen.dart بعد أول تسجيل دخول مباشرة — مصدر واحد بس
  /// للحقيقة، عشان نمنع تكرار/تعارض إنشاء التراخيص.
  void _signup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    User? createdUser;

    try {
      // 1️⃣ إنشاء الحساب في Firebase Auth
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      createdUser = credential.user;
      if (createdUser == null) return;

      await createdUser.sendEmailVerification();

      final displayName = _displayNameController.text.trim().isEmpty
          ? _emailController.text.trim().split('@')[0]
          : _displayNameController.text.trim();

      // 2️⃣ إنشاء user document فقط — بدون أي license هنا خالص
      await FirebaseFirestore.instance
          .collection('users')
          .doc(createdUser.uid)
          .set({
        'userId': createdUser.uid,
        'email': createdUser.email,
        'displayName': displayName,
        'phoneNumber': _phoneController.text.trim(),
        'companyIds': [],
        'supplierIds': [],
        'factoryIds': [],
        'isActive': true,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'trialUsed': false, // ✅ AutoLicenseService هيشوفها ويعمل trial تلقائي
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('account_created_successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        // ✅ التوجيه لـ /splash (أو /dashboard لو الراوتر بيعمل redirect
        // تلقائي للـ splash) — هناك AutoLicenseService هيتكفل بإنشاء
        // الـ trial license الكامل بأول فتح للتطبيق بعد التسجيل.
        //context.go('/dashboard');
        context.go('/splash');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'signup_error'.tr();
      if (e.code == 'email-already-in-use') {
        message = 'email_already_in_use'.tr();
      } else if (e.code == 'weak-password') {
        message = 'weak_password'.tr();
      } else if (e.code == 'invalid-email') {
        message = 'invalid_email'.tr();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      safeDebugPrint('Signup error: $e');

      // ✅ Rollback: حذف حساب Auth لو فشلت كتابة user document
      if (createdUser != null) {
        try {
          await createdUser.delete();
          safeDebugPrint('🗑️ Auth user rolled back');
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('unexpected_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'invalid_email'.tr(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(labelText: 'display_name'.tr()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(labelText: 'phone_number'.tr()),
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                validator: (value) => value != null && value.trim().length >= 6
                    ? null
                    : 'invalid_phone'.tr(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'password'.tr(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : 'short_password'.tr(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: InputDecoration(
                  labelText: 'confirm_password'.tr(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                validator: (value) => value == _passwordController.text
                    ? null
                    : 'passwords_do_not_match'.tr(),
                onFieldSubmitted: (_) => _signup(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('signup'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
