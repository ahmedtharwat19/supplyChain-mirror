// باقي importاتك كما هي
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/user_local_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:puresip_purchasing/debug_helper.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signInWithGoogle() async {
    try {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'login_hint': 'user@example.com'});

        await auth.signInWithProvider(googleProvider);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (!user.emailVerified) {
          await user.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('please_verify_email'.tr())),
            );
          }
          return;
        }

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          safeDebugPrint(
              'User not found in Firestore after Google sign-in. Redirecting to signup...');
          if (mounted) {
             _showErrorSnackBar('user_not_found_in_db'.tr());
            context.go('/signup'); // أو '/register'
          }
          return;
        }
        final userData = userDoc.data();
        safeDebugPrint('userData: $userData');
        safeDebugPrint('userData: ${userData?['isActive']}');

        if (userData != null) {
          final isActive = userData['isActive'];
          if (isActive == false) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('no_access_rights'.tr())),
              );
            }
            return;
          }

          await UserLocalStorage.setUser(userData);
          if (mounted) context.go('/dashboard');
        }

        //  if (mounted) context.go('/dashboard');
      }
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'popup-closed-by-user') {
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('google_signin_failed'.tr())),
        );
      }
    }
  }

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = credential.user;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          safeDebugPrint('User document exists: ${userDoc.exists}');

          if (!userDoc.exists) {
            if (mounted) {
              _showErrorSnackBar('user_not_found_in_db'.tr());
              context.go('/signup');
            }
            return;
          }

          final userData = userDoc.data()!;
          safeDebugPrint('User Data: $userData');

          final isActive = userData['isActive'] as bool? ?? false;
          if (!isActive) {
            if (mounted) {
              setState(() => _isLoading = false);
              await _showInactiveAccountDialog(context);
            }
            return;
          }

          await UserLocalStorage.setUser(userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('login_success'.tr())),
            );
            safeDebugPrint('Attempting to navigate to /dashboard');
            context.go('/dashboard');
          }
        }
      } catch (e) {
        safeDebugPrint('Login error: ${e.toString()}');
        if (mounted) {
          if (e is FirebaseAuthException) {
            _showErrorSnackBar(_getAuthErrorMessage(e));
          } else {
            _showErrorSnackBar('login_error'.tr());
          }
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showInactiveAccountDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('account_inactive_title'.tr()),
        content: Text('account_inactive_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('try_again'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('go_to_license'.tr()),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      if (!context.mounted) return;
      context.go('/license/request');
    }
  }

// دالة مساعدة لعرض رسائل الخطأ
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }


// دالة مساعدة لترجمة أخطاء Firebase
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'user_not_found'.tr();
      case 'wrong-password':
        return 'wrong_password'.tr();
      case 'user-disabled':
        return 'account_disabled'.tr();
      default:
        return 'login_error'.tr();
    }
  }

// Helper function
  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool get _shouldShowGoogleButton {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<bool> onPopInvokedWithResult(bool didPop, dynamic result) async {
    if (!didPop && !kIsWeb) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('exit_app_title'.tr()),
          content: Text('exit_app_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('exit'.tr()),
            ),
          ],
        ),
      );
      if (shouldExit ?? false) exit(0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: onPopInvokedWithResult,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'email'.tr()),
                  validator: (value) => value != null && value.contains('@')
                      ? null
                      : 'invalid_email'.tr(),
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocusNode),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) => value != null && value.length >= 6
                      ? null
                      : 'short_password'.tr(),
                  onFieldSubmitted: (_) => _loginWithEmailPassword(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithEmailPassword,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('login'.tr()),
                ),
                const SizedBox(height: 12),
                if (_shouldShowGoogleButton)
                  ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: Text('login_with_google'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text('no_account'.tr())),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: Text('signup'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
