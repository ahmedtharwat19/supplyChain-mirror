// signup_form.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';

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

/*   void _signup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.sendEmailVerification();

        final displayName = _displayNameController.text.trim().isEmpty
            ? _emailController.text.trim().split('@')[0]
            : _displayNameController.text.trim();

        final phone = _phoneController.text.trim();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email,
          'displayName': displayName,
          'phoneNumber': phone,
          'companyIds': [],
          'supplierIds': [],
          'factoriesIds': [],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final licenseService = LicenseService();
        await licenseService.initialize();

        final licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 60 * 60 * 24 * 30, // مثال: 30 يوم بالثواني
          maxDevices: 1,
          requestId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        );

        // تسجيل الجهاز الحالي تلقائيًا (من غير محاولة أخذ قيمة)
        await licenseService.registerCurrentDevice(licenseKey);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('account_created_successfully'.tr())),
          );
          context.go('/login');
        }
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
 */

  void _signup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.sendEmailVerification();

        final displayName = _displayNameController.text.trim().isEmpty
            ? _emailController.text.trim().split('@')[0]
            : _displayNameController.text.trim();

        final phone = _phoneController.text.trim();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email,
          'displayName': displayName,
          'phoneNumber': phone,
          'companyIds': [],
          'supplierIds': [],
          'factoriesIds': [],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final licenseService = LicenseService();
        await licenseService.initialize();

        // إنشاء الترخيص - 1 شهر تجريبي
        final licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1, // 1 شهر تجريبي
          maxDevices: 1,
          requestId: 'signup_${DateTime.now().millisecondsSinceEpoch}',
        );

        // تحديث مستخدم برقم الترخيص
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'licenseKey': licenseKey,
        });

        // التحقق من الترخيص لتسجيل الجهاز تلقائياً
        final status = await licenseService.checkLicenseStatus(licenseKey);

        if (mounted) {
          if (status.isValid) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('account_created_successfully'.tr())),
            );
            context.go('/login');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('license_activation_failed'.tr())),
            );
          }
        }
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('unexpected_error'.tr())),
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
