/* /* // باقي importاتك كما هي
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';
//import 'package:hive/hive.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

import '../../utils/user_local_storage.dart';

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

/* 
          ..setCustomParameters({
            'login_hint': 'user@example.com',
            // 🚀 قم بلصق الـ Web Client ID المنسوخ من كونسول الفايربيس هنا
            'client_id':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
            'audience':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
          });

           */

/*   Future<void> _signInWithGoogle() async {
    try {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({
            'login_hint': 'user@example.com',
            'client_id':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
            'audience':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
          });

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

        // 🔍 1. الفحص هل المستخدم مسجل مسبقاً في جدول users أم لا؟
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        // 🚀 2. ميزة إنشاء حساب تلقائي للمستخدم الجديد بـ Google
        if (!userDoc.exists) {
          safeDebugPrint('➕ New Google User detected! Creating user document in Firestore...');
          
          final now = DateTime.now().toUtc();
          await userDocRef.set({
            'userId': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? user.email?.split('@').first,
            'createdAt': Timestamp.fromDate(now),
            'isActive': true, // تفعيله تلقائياً للحصول على الشهر المجاني
            'role': 'user',
            'licenseKey': '', // سيتم تحديثه في خطوة الـ _handleLogin التالية
            'maxDevices': 1,
          });
          
          safeDebugPrint('✅ User document created successfully for UID: ${user.uid}');
        }

        // 3. قراءة البيانات المحدثة (سواء كان قديماً أو تم إنشاؤه للتو)
        final updatedUserDoc = await userDocRef.get();
        final userData = updatedUserDoc.data();

        if (userData != null) {
          final isActive = userData['isActive'] as bool? ?? false;
          if (!isActive) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('no_access_rights'.tr())),
              );
            }
            return;
          }

          // حفظ البيانات محلياً وتمرير عملية الدخول والشهر المجاني
          await UserLocalStorage.setUser(userData);
          _handleLogin(user);
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Google Sign-In internal error: $e');
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
 */

/*   Future<void> _signInWithGoogle() async {
    try {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({
            'login_hint': 'user@example.com',
            // 🚀 قم بلصق الـ Web Client ID المنسوخ من كونسول الفايربيس هنا
            'client_id':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
            'audience':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
          });

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
/*           // بعد تسجيل الدخول الناجح
          await Hive.box('auth').put('user', {
            'uid': user.uid,
            'email': user.email,
            // أي بيانات أخرى تحتاجها
          });
          if (mounted) context.go('/dashboard'); */
          _handleLogin(user);
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
 */
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
/*             // بعد تسجيل الدخول الناجح
            await Hive.box('auth').put('user', {
              'uid': user.uid,
              'email': user.email,
              // أي بيانات أخرى تحتاجها
            });
            if (!mounted)return;
            context.go('/dashboard'); */
            _handleLogin(user);
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

  // في login_page.dart
/* Future<void> _handleLogin(User user) async {
  try {
    // حفظ بيانات المصادقة
    await HiveService.saveAuthData({
      'userId': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? user.email?.split('@').first,
      'lastLogin': DateTime.now().toIso8601String(),
    });

    // حفظ بيانات المستخدم الأساسية
    await HiveService.saveUserData({
      'companies': [],
      'factories': [],
      'suppliers': [],
      'preferences': {
        'language': 'ar',
        'theme': 'light'
      }
    });

     if (mounted) { // أضف هذا التحقق
      context.go('/dashboard');
    }
  } catch (e) {
    safeDebugPrint('Login error: $e');
  }
}
 */

/*   Future<void> _handleLogin(User user) async {
    try {
      // حفظ بيانات المصادقة
      await HiveService.saveAuthData({
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
      });

      // جلب بيانات المستخدم الحالية من Hive لو موجودة
      final existingUserData = await HiveService.getUserData() ?? {};

      // تحديث بيانات المستخدم مع الحفاظ على الحقول القديمة مثل isAdmin و createdAt
      final updatedUserData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'preferences': {
          'language': 'ar',
          'theme': 'light',
        },
        ...existingUserData, // ← لاحقًا وليس أولًا
      };

      await HiveService.saveUserData(updatedUserData);

      /// ✅ أضف هذا الجزء: جلب الترخيص من Firestore
      final subscriptionResult =
          await UserSubscriptionService().checkUserSubscription();
      if (subscriptionResult.licenseId != null) {
        await HiveService.saveLicense(subscriptionResult.licenseId!);
        safeDebugPrint("✅ License saved after login");
      }
      if (mounted) {
        context.go('/dashboard');
      }
      safeDebugPrint('✅ Hive user data updated on login.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
    }
  }
 */
 
   Future<void> _handleLogin(User user) async {
    try {
      // 1. حفظ بيانات المصادقة الأساسية في Hive
      await HiveService.saveAuthData({
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
      });

      // 2. التحقق من وجود ترخيص فعال مسبقاً في Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String? licenseKey;
      if (userDoc.exists) {
        final userData = userDoc.data();
        licenseKey = userData?['licenseKey'];
      }

      // 🚀 3. ميزة المنح التلقائي للشهر المجاني للمستخدم الجديد
      if (licenseKey == null || licenseKey.isEmpty) {
        safeDebugPrint('🎁 New user detected! Checking for real license requests...');
        
        final licenseService = LicenseService();
        String targetRequestId = "REQ-${user.uid}"; // معرف افتراضي في حال عدم وجود طلب

        // 🔍 البحث عن أول طلب معلق حقيقي أرسله هذا المستخدم بالسيرفر لإغلاقه وتحويله لـ approved
        final pendingRequests = await FirebaseFirestore.instance
            .collection('license_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (pendingRequests.docs.isNotEmpty) {
          targetRequestId = pendingRequests.docs.first.id;
          safeDebugPrint('🎯 Found real pending request in Firestore: $targetRequestId');
        } else {
          safeDebugPrint('➕ No pending request found, creating an approved one for reference...');
          await FirebaseFirestore.instance.collection('license_requests').doc(targetRequestId).set({
            'userId': user.uid,
            'status': 'pending', 
            'reason': 'First time registration free trial',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        // استدعاء خدمة التراخيص لإنشاء رخصة شهر مجاني (1) وجهاز واحد (1) وربطها بالطلب
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1, 
          maxDevices: 1,      
          requestId: targetRequestId, 
        );
        
        safeDebugPrint('✅ Free trial license created and linked to request: $targetRequestId');
      }

      // 4. حفظ الترخيص الناتج محلياً في الـ Hive
      if (licenseKey.isNotEmpty) {
        await HiveService.saveLicense(licenseKey);
      }

      // 5. جلب بيانات المستخدم الحالية من Hive لو موجودة لدمجها بنفس طريقتك
      final existingUserData = await HiveService.getUserData() ?? {};

      // تحديث بيانات المستخدم مع الحفاظ على الحقول القديمة مثل isAdmin و createdAt
      final updatedUserData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'licenseKey': licenseKey, // إضافة الـ licenseKey الجديد للـ Hive
        'preferences': {
          'language': 'ar',
          'theme': 'light',
        },
        ...existingUserData, // لاحقاً وليس أولاً للحفاظ على حقولك القديمة
      };

      await HiveService.saveUserData(updatedUserData);

      // 6. جلب والتحقق النهائي من الاشتراك من Firestore وحفظه بالـ Hive
      final subscriptionResult = await UserSubscriptionService().checkUserSubscription();
      if (subscriptionResult.licenseId != null) {
        await HiveService.saveLicense(subscriptionResult.licenseId!);
        safeDebugPrint("✅ License verified and saved after login");
      }

      // 7. النقل المباشر والآمن إلى لوحة التحكم
      if (mounted) {
        context.go('/dashboard');
      }
      safeDebugPrint('✅ Hive user data updated on login. Redirected to Dashboard.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
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

/*   bool get _shouldShowGoogleButton {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
 */
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
/*                 const SizedBox(height: 12),
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
  */               const SizedBox(height: 16),
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
 */
/* 
// widgets/auth/login_form.dart - الجزء المصحح
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ أضف هذا import
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ مفاتيح التخزين
  static const String _keyAuthData = 'auth_data';
  static const String _keyUserData = 'user_data';
  static const String _keyLicense = 'license';

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('login_success'.tr())),
            );
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

  Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. حفظ بيانات المصادقة الأساسية في SecureStorage
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
      };
      await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));

      // 2. التحقق من وجود ترخيص فعال مسبقاً في Firestore
      String? licenseKey = userData['licenseKey'];

      // 3. ميزة المنح التلقائي للشهر المجاني للمستخدم الجديد
      if (licenseKey == null || licenseKey.isEmpty) {
        safeDebugPrint('🎁 New user detected! Creating free trial license...');
        
        final licenseService = LicenseService();
        String targetRequestId = "REQ-${user.uid}";

        final pendingRequests = await FirebaseFirestore.instance
            .collection('license_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (pendingRequests.docs.isNotEmpty) {
          targetRequestId = pendingRequests.docs.first.id;
          safeDebugPrint('🎯 Found real pending request: $targetRequestId');
        } else {
          await FirebaseFirestore.instance.collection('license_requests').doc(targetRequestId).set({
            'userId': user.uid,
            'status': 'pending',
            'reason': 'First time registration free trial',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: targetRequestId,
        );
        
        safeDebugPrint('✅ Free trial license created: $targetRequestId');
      }

      // 4. حفظ الترخيص في SecureStorage
      if (licenseKey.isNotEmpty) {
        await _secureStorage.write(key: _keyLicense, value: licenseKey);
      }

      // 5. حفظ بيانات المستخدم في SharedPreferences
      final updatedUserData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'licenseKey': licenseKey,
        'isAdmin': userData['isAdmin'] ?? false,
        'companyIds': userData['companyIds'] ?? [],
        'preferences': {
          'language': 'ar',
          'theme': 'light',
        },
      };
      
      await prefs.setString(_keyUserData, json.encode(updatedUserData));
      
      // حفظ اسم المستخدم بشكل منفصل للوصول السريع
      final userName = updatedUserData['displayName'] ?? 'User';
      await prefs.setString('user_name', userName);

      // 6. التحقق النهائي من الاشتراك
      final subscriptionResult = await UserSubscriptionService().checkUserSubscription();
      if (subscriptionResult.licenseId != null && subscriptionResult.licenseId!.isNotEmpty) {
        await _secureStorage.write(key: _keyLicense, value: subscriptionResult.licenseId);
        safeDebugPrint("✅ License verified and saved after login");
      }

      // 7. الانتقال إلى لوحة التحكم
      if (mounted) {
        context.go('/dashboard');
      }
      safeDebugPrint('✅ Login completed. Redirected to Dashboard.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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

  // ✅ إصلاح الخطأ الثاني: إزالة المقارنة غير الضرورية مع null
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
      // ✅ إصلاح: shouldExit يمكن أن يكون null، نتحقق منه بشكل صحيح
      if (shouldExit == true) exit(0);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
} */
/* 
// widgets/auth/login_form.dart - النسخة النهائية بدون Hive
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/stats_service.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ مفاتيح التخزين
  static const String _keyAuthData = 'auth_data';
  static const String _keyUserData = 'user_data';
  static const String _keyLicense = 'license';
  static const String _keyUserName = 'user_name';

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('login_success'.tr())),
            );
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

  Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAdmin = userData['isAdmin'] == true;
      
      // 1. حفظ بيانات المصادقة الأساسية في SecureStorage
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
        'isAdmin': isAdmin,
      };
      await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
      await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());

      // 2. ✅ إذا كان المستخدم Admin، لا ننشئ له ترخيص
      String? licenseKey = userData['licenseKey'];
      
      if (!isAdmin && (licenseKey == null || licenseKey.isEmpty)) {
        safeDebugPrint('🎁 New user detected! Creating free trial license...');
        
        final licenseService = LicenseService();
        String targetRequestId = "REQ-${user.uid}";

        final pendingRequests = await FirebaseFirestore.instance
            .collection('license_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (pendingRequests.docs.isNotEmpty) {
          targetRequestId = pendingRequests.docs.first.id;
          safeDebugPrint('🎯 Found real pending request: $targetRequestId');
        } else {
          await FirebaseFirestore.instance.collection('license_requests').doc(targetRequestId).set({
            'userId': user.uid,
            'status': 'pending',
            'reason': 'First time registration free trial',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: targetRequestId,
        );
        
        safeDebugPrint('✅ Free trial license created: $targetRequestId');
      }

      // 3. حفظ الترخيص في SecureStorage (للمستخدمين العاديين فقط)
      if (licenseKey != null && licenseKey.isNotEmpty && !isAdmin) {
        await _secureStorage.write(key: _keyLicense, value: licenseKey);
      }

      // 4. حفظ بيانات المستخدم في SharedPreferences
      final displayName = user.displayName ?? user.email?.split('@').first ?? 'User';
      final userName = userData['displayName'] ?? userData['name'] ?? displayName;
      
      final updatedUserData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': userName,
        'name': userData['name'] ?? '',
        'licenseKey': licenseKey,
        'isAdmin': isAdmin,
        'companyIds': userData['companyIds'] ?? [],
        'factoryIds': userData['factoryIds'] ?? [],
        'supplierIds': userData['supplierIds'] ?? [],
      };
      
      await prefs.setString(_keyUserData, json.encode(updatedUserData));
      await prefs.setString(_keyUserName, userName);

      // 5. ✅ تحديث إحصائيات المستخدم (للمستخدمين العاديين فقط)
      if (!isAdmin) {
        final statsService = StatsService();
        await statsService.updateUserStats(user.uid);
      }

      // 6. الانتقال إلى لوحة التحكم
      if (mounted) {
        context.go('/dashboard');
      }
      safeDebugPrint('✅ Login completed. Redirected to Dashboard.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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
      if (shouldExit == true) exit(0);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
} */
/* 
// widgets/auth/login_form.dart - الكود المصحح
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/stats_service.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ مفاتيح التخزين (فقط المستخدمة)
  static const String _keyAuthData = 'auth_data';
  static const String _keyLicense = 'license';

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('login_success'.tr())),
            );
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

  Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final isAdmin = userData['isAdmin'] == true;
      
      // 1. حفظ بيانات المصادقة الأساسية في SecureStorage
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
        'isAdmin': isAdmin,
      };
      await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
      await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());

      // 2. ✅ Admin: انتقل فوراً إلى Dashboard (بدون ترخيص)
      if (isAdmin) {
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }

      // 3. ✅ مستخدم عادي: تحقق سريع من الترخيص
      String? licenseKey = userData['licenseKey'];
      
      if (licenseKey == null || licenseKey.isEmpty) {
        final licenseService = LicenseService();
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: "REQ-${user.uid}",
        );
        if (licenseKey.isNotEmpty) {
          await _secureStorage.write(key: _keyLicense, value: licenseKey);
        }
      }

      // 4. ✅ تحديث الإحصائيات في الخلفية (لا تنتظر)
      unawaited(StatsService().updateUserStats(user.uid));

      // 5. ✅ الانتقال فوراً إلى Dashboard
      if (mounted) {
        context.go('/dashboard');
      }
      
      safeDebugPrint('✅ Login completed. Redirected to Dashboard.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
      if (mounted) {
        context.go('/dashboard');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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
        if (shouldExit == true) {
      exit(0);
    }
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
} */

// widgets/auth/login_form.dart - الكود المصحح بالكامل

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ مفاتيح التخزين
  static const String _keyAuthData = 'auth_data';
  static const String _keyLicense = 'license';
  static const String _keyUserName = 'user_name'; // ✅ إضافة مفتاح اسم المستخدم

/*   Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('login_success'.tr()),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
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
        setState(() => _isLoading = false);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
 */

  // login_form.dart - تعديل دالة _loginWithEmailPassword

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        // ✅ تنظيف جميع البيانات المخزنة قبل تسجيل الدخول بحساب جديد
        await _clearAllStoredData();

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

          // ✅ إذا كان الحساب غير نشط، نظف البيانات واعرض رسالة
          if (!isActive) {
            if (mounted) {
              setState(() => _isLoading = false);
              await _showInactiveAccountDialog(context);
            }
            return;
          }

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('login_success'.tr()),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
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
        setState(() => _isLoading = false);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ دالة تنظيف جميع البيانات المخزنة
  Future<void> _clearAllStoredData() async {
    try {
      safeDebugPrint('🗑️ Clearing all stored data before login...');

      // تنظيف SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // تنظيف SecureStorage
      await _secureStorage.deleteAll();

      safeDebugPrint('✅ All stored data cleared successfully');
    } catch (e) {
      safeDebugPrint('❌ Error clearing stored data: $e');
    }
  }

// login_form.dart - تعديل دالة _handleLogin للمستخدمين العاديين

/* Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
  try {
    final isAdmin = userData['isAdmin'] == true;
    
    // ✅ الحصول على اسم المستخدم
    String userName = user.displayName ?? 
                      userData['displayName'] ?? 
                      user.email?.split('@').first ?? 
                      'User';
    
    safeDebugPrint('📱 User name resolved: $userName');
    
    // ✅ حفظ البيانات
    final authData = {
      'userId': user.uid,
      'email': user.email,
      'displayName': userName,
      'lastLogin': DateTime.now().toIso8601String(),
      'isAdmin': isAdmin,
    };
    await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
    await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());
    //await _secureStorage.write(key: 'user_name', value: userName);
    await _secureStorage.write(key: _keyUserName, value: userName);

    final prefs = await SharedPreferences.getInstance();
   // await prefs.setString('user_name', userName);
   await prefs.setString(_keyUserName, userName);

    
    // ✅ Admin يمر مباشرة
    if (isAdmin) {
      safeDebugPrint('👑 Admin login: $userName');
      if (mounted) {
        context.go('/dashboard');
      }
      return;
    }
    
    // ✅ مستخدم عادي: تحقق من الترخيص
    String? licenseKey = userData['licenseKey'];
    final licenseExpiry = userData['license_expiry'] as Timestamp?;
    
    // ✅ إذا كان المستخدم جديداً (ليس له ترخيص)
    if (licenseKey == null || licenseKey.isEmpty) {
      safeDebugPrint('⚠️ No license found for user: $userName');
      
      // ✅ التحقق مما إذا كان قد استخدم النسخة التجريبية من قبل
      final hasUsedTrial = userData['trialUsed'] == true;
      
      if (!hasUsedTrial) {
        // ✅ إنشاء ترخيص تجريبي للمستخدم الجديد
        safeDebugPrint('🎁 Creating trial license for new user...');
        final licenseService = LicenseService();
        final newLicenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: "login_${user.uid}_${DateTime.now().millisecondsSinceEpoch}",
        );
        
        if (newLicenseKey.isNotEmpty) {
          licenseKey = newLicenseKey;
          final newExpiryDate = DateTime.now().add(const Duration(days: 30));
          
          // ✅ تحديث المستخدم بالترخيص الجديد
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'licenseKey': licenseKey,
            'license_expiry': Timestamp.fromDate(newExpiryDate),
            'trialUsed': true,
            'trialExpiryDate': Timestamp.fromDate(newExpiryDate),
          });
          
          await _secureStorage.write(key: _keyLicense, value: licenseKey);
          await prefs.setString('licenseKey', licenseKey);
          safeDebugPrint('✅ Trial license created for user: $userName');
        }
      } else {
        // ❌ استخدم النسخة التجريبية من قبل وليس لديه ترخيص
        safeDebugPrint('❌ User has used trial but no active license');
        if (mounted) {
          _showNoLicenseDialog();
        }
        return;
      }
    }
    
    // ✅ التحقق من صلاحية الترخيص
    if (licenseKey != null && licenseKey.isNotEmpty) {
      final expiryDate = licenseExpiry?.toDate();
      final isLicenseValid = expiryDate != null && expiryDate.isAfter(DateTime.now());
      
      if (!isLicenseValid) {
        safeDebugPrint('❌ License expired for user: $userName');
        if (mounted) {
          _showLicenseExpiredDialog();
        }
        return;
      }
      
      // ✅ حفظ الترخيص
      await _secureStorage.write(key: _keyLicense, value: licenseKey);
    }
    
    // ✅ تحديث الإحصائيات
    unawaited(StatsService().updateUserStats(user.uid));
    
    // ✅ الانتقال إلى Dashboard
    if (mounted) {
      context.go('/dashboard');
    }
    
    safeDebugPrint('✅ Login completed for: $userName');
  } catch (e) {
    safeDebugPrint('❌ Error handling login: $e');
    if (mounted) {
      context.go('/dashboard');
    }
  }
}
 */

// login_form.dart - تعديل دالة _handleLogin للمستخدمين العاديين

  Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final isAdmin = userData['isAdmin'] == true;

      // ✅ الحصول على اسم المستخدم
      String userName = user.displayName ??
          userData['displayName'] ??
          user.email?.split('@').first ??
          'User';

      safeDebugPrint('📱 User name resolved: $userName');

      // ✅ حفظ البيانات
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': userName,
        'lastLogin': DateTime.now().toIso8601String(),
        'isAdmin': isAdmin,
      };
      await _secureStorage.write(
          key: _keyAuthData, value: json.encode(authData));
      await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());
      //  await _secureStorage.write(key: 'user_name', value: userName);
      await _secureStorage.write(key: _keyUserName, value: userName);

      final prefs = await SharedPreferences.getInstance();
      //   await prefs.setString('user_name', userName);
      await prefs.setString(_keyUserName, userName);

      // ✅ Admin يمر مباشرة
      if (isAdmin) {
        safeDebugPrint('👑 Admin login: $userName');
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }

      // ✅ مستخدم عادي: تحقق من الترخيص
      String? licenseKey = userData['licenseKey'];
      final licenseExpiry = userData['license_expiry'] as Timestamp?;

      // ✅ إذا كان المستخدم جديداً (ليس له ترخيص)
      if (licenseKey == null || licenseKey.isEmpty) {
        safeDebugPrint('⚠️ No license found for user: $userName');

        // ✅ التحقق مما إذا كان قد استخدم النسخة التجريبية من قبل
        final hasUsedTrial = userData['trialUsed'] == true;

        if (!hasUsedTrial) {
          // ✅ إنشاء ترخيص تجريبي للمستخدم الجديد
          safeDebugPrint('🎁 Creating trial license for new user...');
          final licenseService = LicenseService();
          final newLicenseKey = await licenseService.createLicense(
            userId: user.uid,
            durationMonths: 1,
            maxDevices: 1,
            requestId:
                "login_${user.uid}_${DateTime.now().millisecondsSinceEpoch}",
          );

          if (newLicenseKey.isNotEmpty) {
            licenseKey = newLicenseKey;
            final newExpiryDate = DateTime.now().add(const Duration(days: 30));

            // ✅ تحديث المستخدم بالترخيص الجديد
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'licenseKey': licenseKey,
              'license_expiry': Timestamp.fromDate(newExpiryDate),
              'trialUsed': true,
              'trialExpiryDate': Timestamp.fromDate(newExpiryDate),
            });

            await _secureStorage.write(key: _keyLicense, value: licenseKey);
            await prefs.setString('licenseKey', licenseKey);
            safeDebugPrint('✅ Trial license created for user: $userName');
          }
        } else {
          // ❌ استخدم النسخة التجريبية من قبل وليس لديه ترخيص
          safeDebugPrint('❌ User has used trial but no active license');
          if (mounted) {
            _showNoLicenseDialog();
          }
          return;
        }
      }

      // ✅ التحقق من صلاحية الترخيص
      if (licenseKey != null && licenseKey.isNotEmpty) {
        final expiryDate = licenseExpiry?.toDate();
        final isLicenseValid =
            expiryDate != null && expiryDate.isAfter(DateTime.now());

        if (!isLicenseValid) {
          safeDebugPrint('❌ License expired for user: $userName');
          if (mounted) {
            _showLicenseExpiredDialog();
          }
          return;
        }

        // ✅ حفظ الترخيص
        await _secureStorage.write(key: _keyLicense, value: licenseKey);
      }

      // ✅ تحديث الإحصائيات
      unawaited(StatsService().updateUserStats(user.uid));

      // ✅ الانتقال إلى Dashboard
      if (mounted) {
        context.go('/dashboard');
      }

      safeDebugPrint('✅ Login completed for: $userName');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
      if (mounted) {
        context.go('/dashboard');
      }
    }
  }

  /// ✅ عرض حوار عدم وجود ترخيص
  void _showNoLicenseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('no_license_title'.tr()),
        content: Text('no_license_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => context.go('/logout'),
            child: Text('logout'.tr()),
          ),
          TextButton(
            onPressed: () => context.go('/license/request'),
            child: Text('request_license'.tr()),
          ),
        ],
      ),
    );
  }

  /// ✅ عرض حوار انتهاء الترخيص
  void _showLicenseExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('license_expired_title'.tr()),
        content: Text('license_expired_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => context.go('/logout'),
            child: Text('logout'.tr()),
          ),
          TextButton(
            onPressed: () => context.go('/license/request'),
            child: Text('renew_license'.tr()),
          ),
        ],
      ),
    );
  }

/* /// ✅ عرض حوار عدم وجود ترخيص
void _showNoLicenseDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('no_license_title'.tr()),
      content: Text('no_license_message'.tr()),
      actions: [
        TextButton(
          onPressed: () => context.go('/logout'),
          child: Text('logout'.tr()),
        ),
        TextButton(
          onPressed: () => context.go('/license/request'),
          child: Text('request_license'.tr()),
        ),
      ],
    ),
  );
}

/// ✅ عرض حوار انتهاء الترخيص
void _showLicenseExpiredDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('license_expired_title'.tr()),
      content: Text('license_expired_message'.tr()),
      actions: [
        TextButton(
          onPressed: () => context.go('/logout'),
          child: Text('logout'.tr()),
        ),
        TextButton(
          onPressed: () => context.go('/license/request'),
          child: Text('renew_license'.tr()),
        ),
      ],
    ),
  );
}

 */
// login_form.dart - تعديل دالة _handleLogin

/* Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
  try {
    final isAdmin = userData['isAdmin'] == true;
    
    // ✅ الحصول على اسم المستخدم
    String userName = user.displayName ?? 
                      userData['displayName'] ?? 
                      user.email?.split('@').first ?? 
                      'User';
    
    safeDebugPrint('📱 User name resolved: $userName');
    
    // ✅ حفظ بيانات المستخدم الجديد في SecureStorage
    final authData = {
      'userId': user.uid,
      'email': user.email,
      'displayName': userName,
      'lastLogin': DateTime.now().toIso8601String(),
      'isAdmin': isAdmin,
    };
    await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
    await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());
    await _secureStorage.write(key: 'user_name', value: userName);
    
          await _secureStorage.write(key: _keyUserName, value: userName);


    // ✅ حفظ في SharedPreferences أيضاً
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', userName);
    await prefs.setString('isAdmin', isAdmin.toString());
          await prefs.setString(_keyUserName, userName);

    
    // ✅ تحديث displayName في Firebase Auth
    if (user.displayName == null || user.displayName!.isEmpty) {
      await user.updateDisplayName(userName);
    }
    
    safeDebugPrint('✅ User data saved for: $userName');
    
    // ✅ إذا كان Admin، اذهب إلى Dashboard مباشرة
    if (isAdmin) {
      safeDebugPrint('👑 Admin login: $userName');
      if (mounted) {
        context.go('/dashboard');
      }
      return;
    }
    
    // ✅ للمستخدمين العاديين: تحقق من الترخيص
    String? licenseKey = userData['licenseKey'];
    
    if (licenseKey == null || licenseKey.isEmpty) {
      safeDebugPrint('No license found, creating new license...');
      final licenseService = LicenseService();
      licenseKey = await licenseService.createLicense(
        userId: user.uid,
        durationMonths: 1,
        maxDevices: 1,
        requestId: "REQ-${user.uid}",
      );
      if (licenseKey.isNotEmpty) {
        await _secureStorage.write(key: _keyLicense, value: licenseKey);
        await prefs.setString('licenseKey', licenseKey);
      }
    } else {
      // ✅ حفظ الترخيص الموجود
      await _secureStorage.write(key: _keyLicense, value: licenseKey);
      await prefs.setString('licenseKey', licenseKey);
    }
    
    // ✅ تحديث الإحصائيات في الخلفية
    unawaited(StatsService().updateUserStats(user.uid));

    // ✅ الانتقال إلى Dashboard
    if (mounted) {
      context.go('/dashboard');
    }
    
    safeDebugPrint('✅ Login completed for: $userName');
  } catch (e) {
    safeDebugPrint('❌ Error handling login: $e');
    if (mounted) {
      context.go('/dashboard');
    }
  }
}
 */

/*   Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final isAdmin = userData['isAdmin'] == true;
      
      // ✅ الحصول على اسم المستخدم
      String userName = user.displayName ?? 
                        userData['displayName'] ?? 
                        user.email?.split('@').first ?? 
                        'User';
      
      // ✅ حفظ بيانات المصادقة الأساسية في SecureStorage
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': userName,
        'lastLogin': DateTime.now().toIso8601String(),
        'isAdmin': isAdmin,
      };
      await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
      await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());
      await _secureStorage.write(key: _keyUserName, value: userName);  // ✅ حفظ اسم المستخدم
      
      // ✅ تحديث displayName في Firebase Auth إذا كان فارغاً
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(userName);
      }

      // ✅ Admin: انتقل فوراً إلى Dashboard
      if (isAdmin) {
        safeDebugPrint('👑 Admin login: $userName');
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }

      // ✅ مستخدم عادي: تحقق من الترخيص
      String? licenseKey = userData['licenseKey'];
      
      if (licenseKey == null || licenseKey.isEmpty) {
        safeDebugPrint('No license found, creating new license...');
        final licenseService = LicenseService();
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: "REQ-${user.uid}",
        );
        if (licenseKey.isNotEmpty) {
          await _secureStorage.write(key: _keyLicense, value: licenseKey);
        }
      }

      // ✅ تحديث الإحصائيات في الخلفية
      unawaited(StatsService().updateUserStats(user.uid));

      // ✅ الانتقال إلى Dashboard
      if (mounted) {
        context.go('/dashboard');
      }
      
      safeDebugPrint('✅ Login completed for: $userName');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
      if (mounted) {
        context.go('/dashboard');
      }
    }
  }
 */
  Future<void> _showInactiveAccountDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'user_not_found'.tr();
      case 'wrong-password':
        return 'wrong_password'.tr();
      case 'user-disabled':
        return 'account_disabled'.tr();
      case 'too-many-requests':
        return 'too_many_requests'.tr();
      case 'invalid-email':
        return 'invalid_email'.tr();
      default:
        return 'login_error'.tr();
    }
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
      if (shouldExit == true) {
        exit(0);
      }
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
                  decoration: InputDecoration(
                    labelText: 'email'.tr(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'email_required'.tr();
                    }
                    if (!value.contains('@')) {
                      return 'invalid_email'.tr();
                    }
                    return null;
                  },
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'password_required'.tr();
                    }
                    if (value.length < 6) {
                      return 'short_password'.tr();
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _loginWithEmailPassword(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithEmailPassword,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('login'.tr(),
                            style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('no_account'.tr()),
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
 */

/* // باقي importاتك كما هي
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';
//import 'package:hive/hive.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

import '../../utils/user_local_storage.dart';

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

/* 
          ..setCustomParameters({
            'login_hint': 'user@example.com',
            // 🚀 قم بلصق الـ Web Client ID المنسوخ من كونسول الفايربيس هنا
            'client_id':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
            'audience':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
          });

           */

/*   Future<void> _signInWithGoogle() async {
    try {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({
            'login_hint': 'user@example.com',
            'client_id':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
            'audience':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
          });

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

        // 🔍 1. الفحص هل المستخدم مسجل مسبقاً في جدول users أم لا؟
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        // 🚀 2. ميزة إنشاء حساب تلقائي للمستخدم الجديد بـ Google
        if (!userDoc.exists) {
          safeDebugPrint('➕ New Google User detected! Creating user document in Firestore...');
          
          final now = DateTime.now().toUtc();
          await userDocRef.set({
            'userId': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? user.email?.split('@').first,
            'createdAt': Timestamp.fromDate(now),
            'isActive': true, // تفعيله تلقائياً للحصول على الشهر المجاني
            'role': 'user',
            'licenseKey': '', // سيتم تحديثه في خطوة الـ _handleLogin التالية
            'maxDevices': 1,
          });
          
          safeDebugPrint('✅ User document created successfully for UID: ${user.uid}');
        }

        // 3. قراءة البيانات المحدثة (سواء كان قديماً أو تم إنشاؤه للتو)
        final updatedUserDoc = await userDocRef.get();
        final userData = updatedUserDoc.data();

        if (userData != null) {
          final isActive = userData['isActive'] as bool? ?? false;
          if (!isActive) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('no_access_rights'.tr())),
              );
            }
            return;
          }

          // حفظ البيانات محلياً وتمرير عملية الدخول والشهر المجاني
          await UserLocalStorage.setUser(userData);
          _handleLogin(user);
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Google Sign-In internal error: $e');
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
 */

/*   Future<void> _signInWithGoogle() async {
    try {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({
            'login_hint': 'user@example.com',
            // 🚀 قم بلصق الـ Web Client ID المنسوخ من كونسول الفايربيس هنا
            'client_id':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
            'audience':
                '766925810788-t91vcvhqnclgs1g853bip6doo3uu35ou.apps.googleusercontent.com',
          });

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
/*           // بعد تسجيل الدخول الناجح
          await Hive.box('auth').put('user', {
            'uid': user.uid,
            'email': user.email,
            // أي بيانات أخرى تحتاجها
          });
          if (mounted) context.go('/dashboard'); */
          _handleLogin(user);
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
 */
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
/*             // بعد تسجيل الدخول الناجح
            await Hive.box('auth').put('user', {
              'uid': user.uid,
              'email': user.email,
              // أي بيانات أخرى تحتاجها
            });
            if (!mounted)return;
            context.go('/dashboard'); */
            _handleLogin(user);
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

  // في login_page.dart
/* Future<void> _handleLogin(User user) async {
  try {
    // حفظ بيانات المصادقة
    await HiveService.saveAuthData({
      'userId': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? user.email?.split('@').first,
      'lastLogin': DateTime.now().toIso8601String(),
    });

    // حفظ بيانات المستخدم الأساسية
    await HiveService.saveUserData({
      'companies': [],
      'factories': [],
      'suppliers': [],
      'preferences': {
        'language': 'ar',
        'theme': 'light'
      }
    });

     if (mounted) { // أضف هذا التحقق
      context.go('/dashboard');
    }
  } catch (e) {
    safeDebugPrint('Login error: $e');
  }
}
 */

/*   Future<void> _handleLogin(User user) async {
    try {
      // حفظ بيانات المصادقة
      await HiveService.saveAuthData({
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
      });

      // جلب بيانات المستخدم الحالية من Hive لو موجودة
      final existingUserData = await HiveService.getUserData() ?? {};

      // تحديث بيانات المستخدم مع الحفاظ على الحقول القديمة مثل isAdmin و createdAt
      final updatedUserData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'preferences': {
          'language': 'ar',
          'theme': 'light',
        },
        ...existingUserData, // ← لاحقًا وليس أولًا
      };

      await HiveService.saveUserData(updatedUserData);

      /// ✅ أضف هذا الجزء: جلب الترخيص من Firestore
      final subscriptionResult =
          await UserSubscriptionService().checkUserSubscription();
      if (subscriptionResult.licenseId != null) {
        await HiveService.saveLicense(subscriptionResult.licenseId!);
        safeDebugPrint("✅ License saved after login");
      }
      if (mounted) {
        context.go('/dashboard');
      }
      safeDebugPrint('✅ Hive user data updated on login.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
    }
  }
 */
 
   Future<void> _handleLogin(User user) async {
    try {
      // 1. حفظ بيانات المصادقة الأساسية في Hive
      await HiveService.saveAuthData({
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
      });

      // 2. التحقق من وجود ترخيص فعال مسبقاً في Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String? licenseKey;
      if (userDoc.exists) {
        final userData = userDoc.data();
        licenseKey = userData?['licenseKey'];
      }

      // 🚀 3. ميزة المنح التلقائي للشهر المجاني للمستخدم الجديد
      if (licenseKey == null || licenseKey.isEmpty) {
        safeDebugPrint('🎁 New user detected! Checking for real license requests...');
        
        final licenseService = LicenseService();
        String targetRequestId = "REQ-${user.uid}"; // معرف افتراضي في حال عدم وجود طلب

        // 🔍 البحث عن أول طلب معلق حقيقي أرسله هذا المستخدم بالسيرفر لإغلاقه وتحويله لـ approved
        final pendingRequests = await FirebaseFirestore.instance
            .collection('license_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (pendingRequests.docs.isNotEmpty) {
          targetRequestId = pendingRequests.docs.first.id;
          safeDebugPrint('🎯 Found real pending request in Firestore: $targetRequestId');
        } else {
          safeDebugPrint('➕ No pending request found, creating an approved one for reference...');
          await FirebaseFirestore.instance.collection('license_requests').doc(targetRequestId).set({
            'userId': user.uid,
            'status': 'pending', 
            'reason': 'First time registration free trial',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        // استدعاء خدمة التراخيص لإنشاء رخصة شهر مجاني (1) وجهاز واحد (1) وربطها بالطلب
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1, 
          maxDevices: 1,      
          requestId: targetRequestId, 
        );
        
        safeDebugPrint('✅ Free trial license created and linked to request: $targetRequestId');
      }

      // 4. حفظ الترخيص الناتج محلياً في الـ Hive
      if (licenseKey.isNotEmpty) {
        await HiveService.saveLicense(licenseKey);
      }

      // 5. جلب بيانات المستخدم الحالية من Hive لو موجودة لدمجها بنفس طريقتك
      final existingUserData = await HiveService.getUserData() ?? {};

      // تحديث بيانات المستخدم مع الحفاظ على الحقول القديمة مثل isAdmin و createdAt
      final updatedUserData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'licenseKey': licenseKey, // إضافة الـ licenseKey الجديد للـ Hive
        'preferences': {
          'language': 'ar',
          'theme': 'light',
        },
        ...existingUserData, // لاحقاً وليس أولاً للحفاظ على حقولك القديمة
      };

      await HiveService.saveUserData(updatedUserData);

      // 6. جلب والتحقق النهائي من الاشتراك من Firestore وحفظه بالـ Hive
      final subscriptionResult = await UserSubscriptionService().checkUserSubscription();
      if (subscriptionResult.licenseId != null) {
        await HiveService.saveLicense(subscriptionResult.licenseId!);
        safeDebugPrint("✅ License verified and saved after login");
      }

      // 7. النقل المباشر والآمن إلى لوحة التحكم
      if (mounted) {
        context.go('/dashboard');
      }
      safeDebugPrint('✅ Hive user data updated on login. Redirected to Dashboard.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
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

/*   bool get _shouldShowGoogleButton {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
 */
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
/*                 const SizedBox(height: 12),
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
  */               const SizedBox(height: 16),
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
 */
/* 
// widgets/auth/login_form.dart - الجزء المصحح
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ أضف هذا import
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ مفاتيح التخزين
  static const String _keyAuthData = 'auth_data';
  static const String _keyUserData = 'user_data';
  static const String _keyLicense = 'license';

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('login_success'.tr())),
            );
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

  Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. حفظ بيانات المصادقة الأساسية في SecureStorage
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
      };
      await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));

      // 2. التحقق من وجود ترخيص فعال مسبقاً في Firestore
      String? licenseKey = userData['licenseKey'];

      // 3. ميزة المنح التلقائي للشهر المجاني للمستخدم الجديد
      if (licenseKey == null || licenseKey.isEmpty) {
        safeDebugPrint('🎁 New user detected! Creating free trial license...');
        
        final licenseService = LicenseService();
        String targetRequestId = "REQ-${user.uid}";

        final pendingRequests = await FirebaseFirestore.instance
            .collection('license_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (pendingRequests.docs.isNotEmpty) {
          targetRequestId = pendingRequests.docs.first.id;
          safeDebugPrint('🎯 Found real pending request: $targetRequestId');
        } else {
          await FirebaseFirestore.instance.collection('license_requests').doc(targetRequestId).set({
            'userId': user.uid,
            'status': 'pending',
            'reason': 'First time registration free trial',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: targetRequestId,
        );
        
        safeDebugPrint('✅ Free trial license created: $targetRequestId');
      }

      // 4. حفظ الترخيص في SecureStorage
      if (licenseKey.isNotEmpty) {
        await _secureStorage.write(key: _keyLicense, value: licenseKey);
      }

      // 5. حفظ بيانات المستخدم في SharedPreferences
      final updatedUserData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'licenseKey': licenseKey,
        'isAdmin': userData['isAdmin'] ?? false,
        'companyIds': userData['companyIds'] ?? [],
        'preferences': {
          'language': 'ar',
          'theme': 'light',
        },
      };
      
      await prefs.setString(_keyUserData, json.encode(updatedUserData));
      
      // حفظ اسم المستخدم بشكل منفصل للوصول السريع
      final userName = updatedUserData['displayName'] ?? 'User';
      await prefs.setString('cached_user_name', userName); // ✅ موحّد مع dashboard_page

      // 6. التحقق النهائي من الاشتراك
      final subscriptionResult = await UserSubscriptionService().checkUserSubscription();
      if (subscriptionResult.licenseId != null && subscriptionResult.licenseId!.isNotEmpty) {
        await _secureStorage.write(key: _keyLicense, value: subscriptionResult.licenseId);
        safeDebugPrint("✅ License verified and saved after login");
      }

      // 7. الانتقال إلى لوحة التحكم
      if (mounted) {
        context.go('/dashboard');
      }
      safeDebugPrint('✅ Login completed. Redirected to Dashboard.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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

  // ✅ إصلاح الخطأ الثاني: إزالة المقارنة غير الضرورية مع null
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
      // ✅ إصلاح: shouldExit يمكن أن يكون null، نتحقق منه بشكل صحيح
      if (shouldExit == true) exit(0);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
} */
/* 
// widgets/auth/login_form.dart - النسخة النهائية بدون Hive
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/stats_service.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ مفاتيح التخزين
  static const String _keyAuthData = 'auth_data';
  static const String _keyUserData = 'user_data';
  static const String _keyLicense = 'license';
  static const String _keyUserName = 'cached_user_name'; // ✅ موحّد مع dashboard_page

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('login_success'.tr())),
            );
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

  Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAdmin = userData['isAdmin'] == true;
      
      // 1. حفظ بيانات المصادقة الأساسية في SecureStorage
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
        'isAdmin': isAdmin,
      };
      await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
      await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());

      // 2. ✅ إذا كان المستخدم Admin، لا ننشئ له ترخيص
      String? licenseKey = userData['licenseKey'];
      
      if (!isAdmin && (licenseKey == null || licenseKey.isEmpty)) {
        safeDebugPrint('🎁 New user detected! Creating free trial license...');
        
        final licenseService = LicenseService();
        String targetRequestId = "REQ-${user.uid}";

        final pendingRequests = await FirebaseFirestore.instance
            .collection('license_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (pendingRequests.docs.isNotEmpty) {
          targetRequestId = pendingRequests.docs.first.id;
          safeDebugPrint('🎯 Found real pending request: $targetRequestId');
        } else {
          await FirebaseFirestore.instance.collection('license_requests').doc(targetRequestId).set({
            'userId': user.uid,
            'status': 'pending',
            'reason': 'First time registration free trial',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: targetRequestId,
        );
        
        safeDebugPrint('✅ Free trial license created: $targetRequestId');
      }

      // 3. حفظ الترخيص في SecureStorage (للمستخدمين العاديين فقط)
      if (licenseKey != null && licenseKey.isNotEmpty && !isAdmin) {
        await _secureStorage.write(key: _keyLicense, value: licenseKey);
      }

      // 4. حفظ بيانات المستخدم في SharedPreferences
      final displayName = user.displayName ?? user.email?.split('@').first ?? 'User';
      final userName = userData['displayName'] ?? userData['name'] ?? displayName;
      
      final updatedUserData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': userName,
        'name': userData['name'] ?? '',
        'licenseKey': licenseKey,
        'isAdmin': isAdmin,
        'companyIds': userData['companyIds'] ?? [],
        'factoryIds': userData['factoryIds'] ?? [],
        'supplierIds': userData['supplierIds'] ?? [],
      };
      
      await prefs.setString(_keyUserData, json.encode(updatedUserData));
      await prefs.setString(_keyUserName, userName);

      // 5. ✅ تحديث إحصائيات المستخدم (للمستخدمين العاديين فقط)
      if (!isAdmin) {
        final statsService = StatsService();
        await statsService.updateUserStats(user.uid);
      }

      // 6. الانتقال إلى لوحة التحكم
      if (mounted) {
        context.go('/dashboard');
      }
      safeDebugPrint('✅ Login completed. Redirected to Dashboard.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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
      if (shouldExit == true) exit(0);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
} */
/* 
// widgets/auth/login_form.dart - الكود المصحح
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/stats_service.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ مفاتيح التخزين (فقط المستخدمة)
  static const String _keyAuthData = 'auth_data';
  static const String _keyLicense = 'license';

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('login_success'.tr())),
            );
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

  Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final isAdmin = userData['isAdmin'] == true;
      
      // 1. حفظ بيانات المصادقة الأساسية في SecureStorage
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'lastLogin': DateTime.now().toIso8601String(),
        'isAdmin': isAdmin,
      };
      await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
      await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());

      // 2. ✅ Admin: انتقل فوراً إلى Dashboard (بدون ترخيص)
      if (isAdmin) {
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }

      // 3. ✅ مستخدم عادي: تحقق سريع من الترخيص
      String? licenseKey = userData['licenseKey'];
      
      if (licenseKey == null || licenseKey.isEmpty) {
        final licenseService = LicenseService();
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: "REQ-${user.uid}",
        );
        if (licenseKey.isNotEmpty) {
          await _secureStorage.write(key: _keyLicense, value: licenseKey);
        }
      }

      // 4. ✅ تحديث الإحصائيات في الخلفية (لا تنتظر)
      unawaited(StatsService().updateUserStats(user.uid));

      // 5. ✅ الانتقال فوراً إلى Dashboard
      if (mounted) {
        context.go('/dashboard');
      }
      
      safeDebugPrint('✅ Login completed. Redirected to Dashboard.');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
      if (mounted) {
        context.go('/dashboard');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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
        if (shouldExit == true) {
      exit(0);
    }
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
} */

// widgets/auth/login_form.dart - الكود المصحح بالكامل

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ مفاتيح التخزين
  static const String _keyAuthData = 'auth_data';
  static const String _keyLicense = 'license';
  static const String _keyUserName = 'cached_user_name'; // ✅ موحّد مع dashboard_page // ✅ إضافة مفتاح اسم المستخدم

/*   Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('login_success'.tr()),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
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
        setState(() => _isLoading = false);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
 */

  // login_form.dart - تعديل دالة _loginWithEmailPassword

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        // ✅ تنظيف جميع البيانات المخزنة قبل تسجيل الدخول بحساب جديد
      //  await _clearAllStoredData();

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

          // ✅ إذا كان الحساب غير نشط، نظف البيانات واعرض رسالة
          if (!isActive) {
            if (mounted) {
              setState(() => _isLoading = false);
              await _showInactiveAccountDialog(context);
            }
            return;
          }

          await _handleLogin(user, userData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('login_success'.tr()),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
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
        setState(() => _isLoading = false);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ دالة تنظيف جميع البيانات المخزنة
/*   Future<void> _clearAllStoredData() async {
    try {
      safeDebugPrint('🗑️ Clearing all stored data before login...');

      // تنظيف SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // تنظيف SecureStorage
      await _secureStorage.deleteAll();

      safeDebugPrint('✅ All stored data cleared successfully');
    } catch (e) {
      safeDebugPrint('❌ Error clearing stored data: $e');
    }
  }
 */


// login_form.dart - تعديل دالة _handleLogin للمستخدمين العاديين

/* Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
  try {
    final isAdmin = userData['isAdmin'] == true;
    
    // ✅ الحصول على اسم المستخدم
    String userName = user.displayName ?? 
                      userData['displayName'] ?? 
                      user.email?.split('@').first ?? 
                      'User';
    
    safeDebugPrint('📱 User name resolved: $userName');
    
    // ✅ حفظ البيانات
    final authData = {
      'userId': user.uid,
      'email': user.email,
      'displayName': userName,
      'lastLogin': DateTime.now().toIso8601String(),
      'isAdmin': isAdmin,
    };
    await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
    await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());
    //await _secureStorage.write(key: 'user_name', value: userName);
    await _secureStorage.write(key: _keyUserName, value: userName);

    final prefs = await SharedPreferences.getInstance();
   // await prefs.setString('user_name', userName);
   await prefs.setString(_keyUserName, userName);

    
    // ✅ Admin يمر مباشرة
    if (isAdmin) {
      safeDebugPrint('👑 Admin login: $userName');
      if (mounted) {
        context.go('/dashboard');
      }
      return;
    }
    
    // ✅ مستخدم عادي: تحقق من الترخيص
    String? licenseKey = userData['licenseKey'];
    final licenseExpiry = userData['license_expiry'] as Timestamp?;
    
    // ✅ إذا كان المستخدم جديداً (ليس له ترخيص)
    if (licenseKey == null || licenseKey.isEmpty) {
      safeDebugPrint('⚠️ No license found for user: $userName');
      
      // ✅ التحقق مما إذا كان قد استخدم النسخة التجريبية من قبل
      final hasUsedTrial = userData['trialUsed'] == true;
      
      if (!hasUsedTrial) {
        // ✅ إنشاء ترخيص تجريبي للمستخدم الجديد
        safeDebugPrint('🎁 Creating trial license for new user...');
        final licenseService = LicenseService();
        final newLicenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: "login_${user.uid}_${DateTime.now().millisecondsSinceEpoch}",
        );
        
        if (newLicenseKey.isNotEmpty) {
          licenseKey = newLicenseKey;
          final newExpiryDate = DateTime.now().add(const Duration(days: 30));
          
          // ✅ تحديث المستخدم بالترخيص الجديد
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'licenseKey': licenseKey,
            'license_expiry': Timestamp.fromDate(newExpiryDate),
            'trialUsed': true,
            'trialExpiryDate': Timestamp.fromDate(newExpiryDate),
          });
          
          await _secureStorage.write(key: _keyLicense, value: licenseKey);
          await prefs.setString('licenseKey', licenseKey);
          safeDebugPrint('✅ Trial license created for user: $userName');
        }
      } else {
        // ❌ استخدم النسخة التجريبية من قبل وليس لديه ترخيص
        safeDebugPrint('❌ User has used trial but no active license');
        if (mounted) {
          _showNoLicenseDialog();
        }
        return;
      }
    }
    
    // ✅ التحقق من صلاحية الترخيص
    if (licenseKey != null && licenseKey.isNotEmpty) {
      final expiryDate = licenseExpiry?.toDate();
      final isLicenseValid = expiryDate != null && expiryDate.isAfter(DateTime.now());
      
      if (!isLicenseValid) {
        safeDebugPrint('❌ License expired for user: $userName');
        if (mounted) {
          _showLicenseExpiredDialog();
        }
        return;
      }
      
      // ✅ حفظ الترخيص
      await _secureStorage.write(key: _keyLicense, value: licenseKey);
    }
    
    // ✅ تحديث الإحصائيات
    unawaited(StatsService().updateUserStats(user.uid));
    
    // ✅ الانتقال إلى Dashboard
    if (mounted) {
      context.go('/dashboard');
    }
    
    safeDebugPrint('✅ Login completed for: $userName');
  } catch (e) {
    safeDebugPrint('❌ Error handling login: $e');
    if (mounted) {
      context.go('/dashboard');
    }
  }
}
 */

// login_form.dart - تعديل دالة _handleLogin للمستخدمين العاديين

  Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final isAdmin = userData['isAdmin'] == true;

      // ✅ الحصول على اسم المستخدم
      String userName = user.displayName ??
          userData['displayName'] ??
          user.email?.split('@').first ??
          'User';

      safeDebugPrint('📱 User name resolved: $userName');

      // ✅ حفظ البيانات
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': userName,
        'lastLogin': DateTime.now().toIso8601String(),
        'isAdmin': isAdmin,
      };
      await _secureStorage.write(
          key: _keyAuthData, value: json.encode(authData));
      await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());
      //  await _secureStorage.write(key: 'user_name', value: userName);
      await _secureStorage.write(key: _keyUserName, value: userName);

      final prefs = await SharedPreferences.getInstance();
      //   await prefs.setString('user_name', userName);
      await prefs.setString(_keyUserName, userName);

      // ✅ Admin يمر مباشرة
      if (isAdmin) {
        safeDebugPrint('👑 Admin login: $userName');
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }

      // ✅ مستخدم عادي: تحقق من الترخيص
      String? licenseKey = userData['licenseKey'];
      final licenseExpiry = userData['license_expiry'] as Timestamp?;

      // ✅ إذا كان المستخدم جديداً (ليس له ترخيص)
      if (licenseKey == null || licenseKey.isEmpty) {
        safeDebugPrint('⚠️ No license found for user: $userName');

        // ✅ التحقق مما إذا كان قد استخدم النسخة التجريبية من قبل
        final hasUsedTrial = userData['trialUsed'] == true;

        if (!hasUsedTrial) {
          // ✅ إنشاء ترخيص تجريبي للمستخدم الجديد
          safeDebugPrint('🎁 Creating trial license for new user...');
          final licenseService = LicenseService();
          final newLicenseKey = await licenseService.createLicense(
            userId: user.uid,
            durationMonths: 1,
            maxDevices: 1,
            requestId:
                "login_${user.uid}_${DateTime.now().millisecondsSinceEpoch}",
          );

          if (newLicenseKey.isNotEmpty) {
            licenseKey = newLicenseKey;
            final newExpiryDate = DateTime.now().add(const Duration(days: 30));

            // ✅ تحديث المستخدم بالترخيص الجديد
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'licenseKey': licenseKey,
              'license_expiry': Timestamp.fromDate(newExpiryDate),
              'trialUsed': true,
              'trialExpiryDate': Timestamp.fromDate(newExpiryDate),
            });

            await _secureStorage.write(key: _keyLicense, value: licenseKey);
            await prefs.setString('licenseKey', licenseKey);
            safeDebugPrint('✅ Trial license created for user: $userName');
          }
        } else {
          // ❌ استخدم النسخة التجريبية من قبل وليس لديه ترخيص
          safeDebugPrint('❌ User has used trial but no active license');
          if (mounted) {
            _showNoLicenseDialog();
          }
          return;
        }
      }

      // ✅ التحقق من صلاحية الترخيص
      if (licenseKey != null && licenseKey.isNotEmpty) {
        final expiryDate = licenseExpiry?.toDate();
        final isLicenseValid =
            expiryDate != null && expiryDate.isAfter(DateTime.now());

        if (!isLicenseValid) {
          safeDebugPrint('❌ License expired for user: $userName');
          if (mounted) {
            _showLicenseExpiredDialog();
          }
          return;
        }

        // ✅ حفظ الترخيص
        await _secureStorage.write(key: _keyLicense, value: licenseKey);
      }

      // ✅ تحديث الإحصائيات
      unawaited(StatsService().updateUserStats(user.uid));

      // ✅ الانتقال إلى Dashboard
      if (mounted) {
        context.go('/dashboard');
      }

      safeDebugPrint('✅ Login completed for: $userName');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
      if (mounted) {
        context.go('/dashboard');
      }
    }
  }

  /// ✅ عرض حوار عدم وجود ترخيص
  void _showNoLicenseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('no_license_title'.tr()),
        content: Text('no_license_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => context.go('/logout'),
            child: Text('logout'.tr()),
          ),
          TextButton(
            onPressed: () => context.go('/license/request'),
            child: Text('request_license'.tr()),
          ),
        ],
      ),
    );
  }

  /// ✅ عرض حوار انتهاء الترخيص
  void _showLicenseExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('license_expired_title'.tr()),
        content: Text('license_expired_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => context.go('/logout'),
            child: Text('logout'.tr()),
          ),
          TextButton(
            onPressed: () => context.go('/license/request'),
            child: Text('renew_license'.tr()),
          ),
        ],
      ),
    );
  }

/* /// ✅ عرض حوار عدم وجود ترخيص
void _showNoLicenseDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('no_license_title'.tr()),
      content: Text('no_license_message'.tr()),
      actions: [
        TextButton(
          onPressed: () => context.go('/logout'),
          child: Text('logout'.tr()),
        ),
        TextButton(
          onPressed: () => context.go('/license/request'),
          child: Text('request_license'.tr()),
        ),
      ],
    ),
  );
}

/// ✅ عرض حوار انتهاء الترخيص
void _showLicenseExpiredDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('license_expired_title'.tr()),
      content: Text('license_expired_message'.tr()),
      actions: [
        TextButton(
          onPressed: () => context.go('/logout'),
          child: Text('logout'.tr()),
        ),
        TextButton(
          onPressed: () => context.go('/license/request'),
          child: Text('renew_license'.tr()),
        ),
      ],
    ),
  );
}

 */
// login_form.dart - تعديل دالة _handleLogin

/* Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
  try {
    final isAdmin = userData['isAdmin'] == true;
    
    // ✅ الحصول على اسم المستخدم
    String userName = user.displayName ?? 
                      userData['displayName'] ?? 
                      user.email?.split('@').first ?? 
                      'User';
    
    safeDebugPrint('📱 User name resolved: $userName');
    
    // ✅ حفظ بيانات المستخدم الجديد في SecureStorage
    final authData = {
      'userId': user.uid,
      'email': user.email,
      'displayName': userName,
      'lastLogin': DateTime.now().toIso8601String(),
      'isAdmin': isAdmin,
    };
    await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
    await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());
    await _secureStorage.write(key: _keyUserName, value: userName);

    // ✅ حفظ في SharedPreferences — مفتاح موحّد مع dashboard_page
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, userName); // cached_user_name
    await prefs.setString('isAdmin', isAdmin.toString());

    
    // ✅ تحديث displayName في Firebase Auth
    if (user.displayName == null || user.displayName!.isEmpty) {
      await user.updateDisplayName(userName);
    }
    
    safeDebugPrint('✅ User data saved for: $userName');
    
    // ✅ إذا كان Admin، اذهب إلى Dashboard مباشرة
    if (isAdmin) {
      safeDebugPrint('👑 Admin login: $userName');
      if (mounted) {
        context.go('/dashboard');
      }
      return;
    }
    
    // ✅ للمستخدمين العاديين: تحقق من الترخيص
    String? licenseKey = userData['licenseKey'];
    
    if (licenseKey == null || licenseKey.isEmpty) {
      safeDebugPrint('No license found, creating new license...');
      final licenseService = LicenseService();
      licenseKey = await licenseService.createLicense(
        userId: user.uid,
        durationMonths: 1,
        maxDevices: 1,
        requestId: "REQ-${user.uid}",
      );
      if (licenseKey.isNotEmpty) {
        await _secureStorage.write(key: _keyLicense, value: licenseKey);
        await prefs.setString('licenseKey', licenseKey);
      }
    } else {
      // ✅ حفظ الترخيص الموجود
      await _secureStorage.write(key: _keyLicense, value: licenseKey);
      await prefs.setString('licenseKey', licenseKey);
    }
    
    // ✅ تحديث الإحصائيات في الخلفية
    unawaited(StatsService().updateUserStats(user.uid));

    // ✅ الانتقال إلى Dashboard
    if (mounted) {
      context.go('/dashboard');
    }
    
    safeDebugPrint('✅ Login completed for: $userName');
  } catch (e) {
    safeDebugPrint('❌ Error handling login: $e');
    if (mounted) {
      context.go('/dashboard');
    }
  }
}
 */

/*   Future<void> _handleLogin(User user, Map<String, dynamic> userData) async {
    try {
      final isAdmin = userData['isAdmin'] == true;
      
      // ✅ الحصول على اسم المستخدم
      String userName = user.displayName ?? 
                        userData['displayName'] ?? 
                        user.email?.split('@').first ?? 
                        'User';
      
      // ✅ حفظ بيانات المصادقة الأساسية في SecureStorage
      final authData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': userName,
        'lastLogin': DateTime.now().toIso8601String(),
        'isAdmin': isAdmin,
      };
      await _secureStorage.write(key: _keyAuthData, value: json.encode(authData));
      await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());
      await _secureStorage.write(key: _keyUserName, value: userName);  // ✅ حفظ اسم المستخدم
      
      // ✅ تحديث displayName في Firebase Auth إذا كان فارغاً
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(userName);
      }

      // ✅ Admin: انتقل فوراً إلى Dashboard
      if (isAdmin) {
        safeDebugPrint('👑 Admin login: $userName');
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }

      // ✅ مستخدم عادي: تحقق من الترخيص
      String? licenseKey = userData['licenseKey'];
      
      if (licenseKey == null || licenseKey.isEmpty) {
        safeDebugPrint('No license found, creating new license...');
        final licenseService = LicenseService();
        licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: "REQ-${user.uid}",
        );
        if (licenseKey.isNotEmpty) {
          await _secureStorage.write(key: _keyLicense, value: licenseKey);
        }
      }

      // ✅ تحديث الإحصائيات في الخلفية
      unawaited(StatsService().updateUserStats(user.uid));

      // ✅ الانتقال إلى Dashboard
      if (mounted) {
        context.go('/dashboard');
      }
      
      safeDebugPrint('✅ Login completed for: $userName');
    } catch (e) {
      safeDebugPrint('❌ Error handling login: $e');
      if (mounted) {
        context.go('/dashboard');
      }
    }
  }
 */
  Future<void> _showInactiveAccountDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'user_not_found'.tr();
      case 'wrong-password':
        return 'wrong_password'.tr();
      case 'user-disabled':
        return 'account_disabled'.tr();
      case 'too-many-requests':
        return 'too_many_requests'.tr();
      case 'invalid-email':
        return 'invalid_email'.tr();
      default:
        return 'login_error'.tr();
    }
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
      if (shouldExit == true) {
        exit(0);
      }
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
                  decoration: InputDecoration(
                    labelText: 'email'.tr(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'email_required'.tr();
                    }
                    if (!value.contains('@')) {
                      return 'invalid_email'.tr();
                    }
                    return null;
                  },
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'password_required'.tr();
                    }
                    if (value.length < 6) {
                      return 'short_password'.tr();
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _loginWithEmailPassword(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithEmailPassword,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('login'.tr(),
                            style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('no_account'.tr()),
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