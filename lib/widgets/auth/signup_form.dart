// signup_form.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/auto_license_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _clearCache();
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_name');
      await prefs.remove('cached_stats');
      safeDebugPrint('🧹 Cache cleared on signup page open');
    } catch (e) {
      safeDebugPrint('Cache clear error: $e');
    }
  }

  /// ✅ التسجيل: بيعمل حساب Firebase Auth + document في users، ثم يستدعي
  /// AutoLicenseService فورًا لإنشاء ترخيص تجريبي لشهر واحد. لا نعتمد على
  /// مرور المستخدم بـ splash_screen.dart بعد التسجيل لأن التنقل يذهب
  /// مباشرة لـ /dashboard، وكان هذا يمنع إنشاء الترخيص حتى يُغلق المستخدم
  /// التطبيق ويعيد فتحه.
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

      // ✅ مزامنة الاسم مع Firebase Auth Profile نفسه (لا يكفي حفظه في
      // Firestore فقط)، عشان أي كود بيقرأ currentUser.displayName يلاقيه
      // متاح فورًا بدون الحاجة لإغلاق وإعادة فتح التطبيق.
      await createdUser.updateDisplayName(displayName);
      await createdUser.reload();
      final activeUser = FirebaseAuth.instance.currentUser ?? createdUser;
      createdUser = activeUser;

      // 2️⃣ إنشاء user document فقط — بدون أي license هنا خالص
      await FirebaseFirestore.instance
          .collection('users')
          .doc(activeUser.uid)
          .set({
        'userId': activeUser.uid,
        'email': activeUser.email,
        'displayName': displayName,
        'phoneNumber': _phoneController.text.trim(),
        'companyIds': [],
        'supplierIds': [],
        'factoryIds': [],
        'isActive': true,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'trialUsed': false,
      });

      // ✅ تخزين الاسم فورًا في نفس الكاش اللي بتقرأه dashboard_page.dart
      // (مفتاح 'cached_user_name')، عشان ميفضل فاضي لحد ما يكمل
      // _refreshInBackground في الداشبورد (وده اللي كان بيخلي الاسم يظهر
      // بس بعد إغلاق وإعادة فتح التطبيق).
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_name', displayName);
      } catch (e) {
        safeDebugPrint('⚠️ Failed to seed cached_user_name on signup: $e');
      }

      // 3️⃣ إنشاء الترخيص التجريبي (شهر واحد) فورًا — لا ننتظر splash_screen
      // لأن التنقل بعد التسجيل يذهب مباشرة لـ /dashboard ولا يمر بالـ
      // splash، فكان الترخيص لا يُنشأ إلا بعد إغلاق وفتح التطبيق من جديد.
      try {
        final license = await AutoLicenseService()
            .createAutoLicenseForNewUser(activeUser.uid);
        if (license != null) {
          safeDebugPrint('✅ Trial license created on signup: $license');
        } else {
          safeDebugPrint('⚠️ Trial license NOT created on signup (will retry on splash)');
        }
      } catch (e) {
        // ✅ لا نفشل عملية التسجيل لو فشل إنشاء الترخيص هنا — splash_screen
        // سيحاول مرة أخرى عند أول فتح للتطبيق
        safeDebugPrint('⚠️ Error creating trial license on signup: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('account_created_successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/dashboard');
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