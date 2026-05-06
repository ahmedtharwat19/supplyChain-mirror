// splash_screen.dart

// splash_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/app_initializer_service.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppInitializerService _initializer = AppInitializerService();
  final LicenseService _licenseService = LicenseService();
  String _loadingMessage = "initializing".tr();
  bool _showError = false;
  String _appVersion = "";

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _initializeApp();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
    });
  }

  Future<void> _initializeApp() async {
    try {
      _updateLoadingMessage("preparing_storage".tr());
      await Future.delayed(const Duration(milliseconds: 500));

      _updateLoadingMessage("checking_auth".tr());
      await Future.delayed(const Duration(milliseconds: 300));

      _updateLoadingMessage("checking_connection".tr());
      await Future.delayed(const Duration(milliseconds: 300));

      // تنفيذ التهيئة الفعلية
      final result = await _initializer.initializeApp();

      if (!mounted) return;

      // ✅ محاولة ترقية التراخيص القديمة (للمستخدم الأدمن فقط)
      await _tryMigrateLicenses();

      // معالجة الرسائل إذا وجدت
      if (result.showMessage != null) {
        await _showMessageDialog(result.showMessage!);
      }

      // التنقل إلى الصفحة المناسبة
      _safeNavigate(() {
        if (result.extraData != null) {
          context.go(result.shouldNavigateTo, extra: result.extraData);
        } else {
          context.go(result.shouldNavigateTo);
        }
      });
    } catch (e) {
      safeDebugPrint('❌ Splash screen initialization error: $e');

      if (mounted) {
        setState(() {
          _loadingMessage = "initialization_failed".tr();
          _showError = true;
        });

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _safeNavigate(() => context.go('/login'));
        }
      }
    }
  }

  /// ✅ محاولة ترقية التراخيص القديمة (للمستخدم الأدمن فقط)
  Future<void> _tryMigrateLicenses() async {
    try {
      _updateLoadingMessage("checking_licenses".tr());
      await Future.delayed(const Duration(milliseconds: 200));
      
      // هذه الدالة ستقوم بالترقية فقط إذا كان المستخدم أدمن
      await _licenseService.migrateLicensesWithNewFields();
    } catch (e) {
      safeDebugPrint('⚠️ License migration skipped or failed: $e');
      // لا نعرض خطأ للمستخدم لأن هذه عملية خلفية
    }
  }

  void _updateLoadingMessage(String message) {
    if (mounted) {
      setState(() => _loadingMessage = message);
    }
  }

  Future<void> _showMessageDialog(String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("notice".tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("ok".tr()),
          )
        ],
      ),
    );
  }

  void _safeNavigate(VoidCallback navigation) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) navigation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAppLogo(),
                const SizedBox(height: 32),
                _buildLoadingIndicator(),
                const SizedBox(height: 24),
                _buildLoadingMessage(),
                if (_showError) _buildErrorWidget(),
              ],
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: _buildFooterInfo(currentYear),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogo() {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          _showError ? Colors.red : Colors.green,
        ),
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _loadingMessage,
        key: ValueKey<String>(_loadingMessage),
        style: TextStyle(
          fontSize: 16,
          color: _showError ? Colors.red : Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        "splash_error_message".tr(),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.red,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFooterInfo(int currentYear) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          const Text(
            'Ahmed Tharwat tech.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '© $currentYear ALL RIGHTS ARE RESERVED',
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
          if (_appVersion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "v$_appVersion",
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}



/* import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/app_initializer_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppInitializerService _initializer = AppInitializerService();
  String _loadingMessage = "initializing".tr();
  bool _showError = false;
  String _appVersion = "";

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _initializeApp();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version; // مثال: 1.0.0
    });
  }

  Future<void> _initializeApp() async {
    try {
      // تحديث رسالة التحميل بشكل تدريجي
      _updateLoadingMessage("preparing_storage".tr());
      await Future.delayed(const Duration(milliseconds: 500));

      _updateLoadingMessage("checking_auth".tr());
      await Future.delayed(const Duration(milliseconds: 300));

      _updateLoadingMessage("checking_connection".tr());
      await Future.delayed(const Duration(milliseconds: 300));

      // تنفيذ التهيئة الفعلية
      final result = await _initializer.initializeApp();

      if (!mounted) return;

      // معالجة الرسائل إذا وجدت
      if (result.showMessage != null) {
        await _showMessageDialog(result.showMessage!);
      }

      // التنقل إلى الصفحة المناسبة
      _safeNavigate(() {
        if (result.extraData != null) {
          context.go(result.shouldNavigateTo, extra: result.extraData);
        } else {
          context.go(result.shouldNavigateTo);
        }
      });
    } catch (e) {
      safeDebugPrint('❌ Splash screen initialization error: $e');

      if (mounted) {
        setState(() {
          _loadingMessage = "initialization_failed".tr();
          _showError = true;
        });

        // الانتقال إلى login بعد فترة في حالة الخطأ
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _safeNavigate(() => context.go('/login'));
        }
      }
    }
  }

  void _updateLoadingMessage(String message) {
    if (mounted) {
      setState(() => _loadingMessage = message);
    }
  }

  Future<void> _showMessageDialog(String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("notice".tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("ok".tr()),
          )
        ],
      ),
    );
  }

  void _safeNavigate(VoidCallback navigation) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) navigation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAppLogo(),
                const SizedBox(height: 32),
                _buildLoadingIndicator(),
                const SizedBox(height: 24),
                _buildLoadingMessage(),
                if (_showError) _buildErrorWidget(),
                // const SizedBox(height: 48),
                // _buildFooterInfo(currentYear),
              ],
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: _buildFooterInfo(currentYear),
          ),
        ],
      ),
    );
  }

/*   Widget _buildAppLogo() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.green[50],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(75),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
 */

  Widget _buildAppLogo() {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          _showError ? Colors.red : Colors.green,
        ),
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _loadingMessage,
        key: ValueKey<String>(_loadingMessage),
        style: TextStyle(
          fontSize: 16,
          color: _showError ? Colors.red : Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        "splash_error_message".tr(),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.red,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFooterInfo(int currentYear) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          const Text(
            'Ahmed Tharwat tech.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '© $currentYear ALL RIGHTS ARE RESERVED',
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
          if (_appVersion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "v$_appVersion",
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}
 */
/* // splash_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/app_initializer_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppInitializerService _initializer = AppInitializerService();
  String _loadingMessage = "initializing".tr();
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // تحديث رسالة التحميل بشكل تدريجي
      _updateLoadingMessage("preparing_storage".tr());
      await Future.delayed(const Duration(milliseconds: 500));

      _updateLoadingMessage("checking_auth".tr());
      await Future.delayed(const Duration(milliseconds: 300));

      _updateLoadingMessage("checking_connection".tr());
      await Future.delayed(const Duration(milliseconds: 300));

      // تنفيذ التهيئة الفعلية
      final result = await _initializer.initializeApp();

      if (!mounted) return;

      // معالجة الرسائل إذا وجدت
      if (result.showMessage != null) {
        await _showMessageDialog(result.showMessage!);
      }

      // التنقل إلى الصفحة المناسبة
      _safeNavigate(() {
        if (result.extraData != null) {
          context.go(result.shouldNavigateTo, extra: result.extraData);
        } else {
          context.go(result.shouldNavigateTo);
        }
      });

    } catch (e) {
      safeDebugPrint('❌ Splash screen initialization error: $e');
      
      if (mounted) {
        setState(() {
          _loadingMessage = "initialization_failed".tr();
          _showError = true;
        });

        // الانتقال إلى login بعد فترة في حالة الخطأ
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _safeNavigate(() => context.go('/login'));
        }
      }
    }
  }

  void _updateLoadingMessage(String message) {
    if (mounted) {
      setState(() => _loadingMessage = message);
    }
  }

  Future<void> _showMessageDialog(String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("notice".tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("ok".tr()),
          )
        ],
      ),
    );
  }

  void _safeNavigate(VoidCallback navigation) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) navigation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // شعار التطبيق
            _buildAppLogo(),
            const SizedBox(height: 32),
            
            // مؤشر التحميل
            _buildLoadingIndicator(),
            const SizedBox(height: 24),
            
            // رسالة التحميل
            _buildLoadingMessage(),
            
            // رسالة الخطأ إذا وجدت
            if (_showError) _buildErrorWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.green[50],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(75),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Icon(
        Icons.inventory_2,
        size: 60,
        color: Colors.green[700],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          _showError ? Colors.red : Colors.green,
        ),
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _loadingMessage,
        key: ValueKey<String>(_loadingMessage),
        style: TextStyle(
          fontSize: 16,
          color: _showError ? Colors.red : Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        "splash_error_message".tr(),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.red,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
} */

/* import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/firestore_date_services.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
//import 'package:puresip_purchasing/services/firestore_data_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    try {
      setState(() => _loadingMessage = "Preparing local storage...");
      await HiveService.init();

      final hasAuthData = await HiveService.hasAuthData();
      final hasLicense = await HiveService.getLicense() != null;

      if (!hasAuthData) {
        _safeNavigate(() => context.go('/login'));
        return;
      }

      if (hasAuthData && hasLicense) {
        // ✅ جلب البيانات في الخلفية بدون تعطيل الانتقال
        _fetchUserDataInBackground();

        final authData = await HiveService.getAuthData();
        _safeNavigate(() => context.go('/dashboard', extra: authData));
        return;
      }

      setState(() => _loadingMessage = "Checking subscription...");
      final hasInternet = await _checkInternetConnection();

      if (hasInternet) {
        final subscriptionService = UserSubscriptionService();
        final result = await subscriptionService.checkUserSubscription();

        if (!mounted) return;

        if (result.isValid && !result.isExpired) {
          if (result.licenseId != null) {
            await HiveService.saveLicense(result.licenseId!);
          }

          // ✅ جلب البيانات في الخلفية
          _fetchUserDataInBackground();

          _safeNavigate(() => context.go('/dashboard'));
        } else {
          if (result.timeLeftFormatted != null &&
              result.timeLeftFormatted!.contains('device')) {
            await _showDeviceLimitMessage(result.timeLeftFormatted!);
          }
          _safeNavigate(() => context.go('/license/request'));
        }
      } else {
        final authData = await HiveService.getAuthData();
        await _showDeviceLimitMessage('no_internet'.tr());
        _safeNavigate(() => context.go('/dashboard', extra: authData));
      }
    } catch (e) {
      debugPrint('Splash screen error: $e');
      final hasAuthData = await HiveService.hasAuthData();
      _safeNavigate(() => context.go(hasAuthData ? '/dashboard' : '/login'));
    }
  }

  Future<void> _fetchUserDataInBackground() async {
    try {
      setState(() => _loadingMessage = "Syncing data in background...");
      final firestoreService = FirestoreDataService();
      await firestoreService.fetchAllUserData();
    } catch (e) {
      debugPrint('⚠️ Error fetching user data: $e');
    }
  }

  Future<bool> _checkInternetConnection() async {
    // ضع كود التحقق من الانترنت هنا
    return true;
  }

  void _safeNavigate(VoidCallback callback) {
    if (!mounted) return;
    callback();
  }

  Future<void> _showDeviceLimitMessage(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Device Limit"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _loadingMessage,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
 */

/* import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
   _initializeAndNavigate();
  }

Future<void> _initializeAndNavigate() async {
    try {
      // تهيئة Hive أولاً
      await HiveService.init();

      // التحقق من وجود بيانات المصادقة والترخيص
      final hasAuthData = await HiveService.hasAuthData();
      final hasLicense = await HiveService.getLicense() != null;

      if (!hasAuthData) {
        _safeNavigate(() => context.go('/login'));
        return;
      }

      if (hasAuthData && hasLicense) {
        // تحميل البيانات المخزنة بسرعة
        final authData = await HiveService.getAuthData();
        _safeNavigate(() => context.go('/dashboard', extra: authData));
        return;
      }

      // الباقي من منطقك الأصلي...
      final hasInternet = await _checkInternetConnection();

      if (hasInternet) {
        final subscriptionService = UserSubscriptionService();
        final result = await subscriptionService.checkUserSubscription();

        if (!mounted) return;

        if (result.isValid && !result.isExpired) {
          // حفظ الترخيص الجديد
          if (result.licenseId != null) {
            await HiveService.saveLicense(result.licenseId!);
          }
          _safeNavigate(() => context.go('/dashboard'));
        } else {
          if (result.timeLeftFormatted != null &&
              result.timeLeftFormatted!.contains('device')) {
            await _showDeviceLimitMessage(result.timeLeftFormatted!);
          }
          _safeNavigate(() => context.go('/license/request'));
        }
      } else {
        // استخدام البيانات المخزنة محلياً
        final authData = await HiveService.getAuthData();
        await _showDeviceLimitMessage('no_internet'.tr());
        _safeNavigate(() => context.go('/dashboard', extra: authData));
      }
    } catch (e) {
      safeDebugPrint('Splash screen error: $e');
      final hasAuthData = await HiveService.hasAuthData();
      _safeNavigate(() => context.go(hasAuthData ? '/dashboard' : '/login'));
    }
  }
  Future<void> _startApp() async {
      await Future.delayed(const Duration(milliseconds: 500));
    try {
      final hasUserInHive = await _checkUserExistsInHive();
      final hasLicenseInHive = await _checkLicenseInHive();

      if (!hasUserInHive) {
        _safeNavigate(() => context.go('/login'));
        return;
      }

      if (hasUserInHive && hasLicenseInHive) {
        _safeNavigate(() => context.go('/dashboard'));
        return;
      }

      final hasInternet = await _checkInternetConnection();

      if (hasInternet) {
        final subscriptionService = UserSubscriptionService();
        final result = await subscriptionService.checkUserSubscription();

        if (!mounted) return;

        if (result.isValid && !result.isExpired) {
          _safeNavigate(() => context.go('/dashboard'));
        } else {
          if (result.timeLeftFormatted != null &&
              result.timeLeftFormatted!.contains('device')) {
            await _showDeviceLimitMessage(result.timeLeftFormatted!);
          }
          _safeNavigate(() => context.go('/license/request'));
        }
      } else {
        await _showDeviceLimitMessage('no_internet'.tr());
        _safeNavigate(() => context.go('/dashboard'));
      }
    } catch (e) {
      final hasUserInHive = await _checkUserExistsInHive();
      _safeNavigate(() => context.go(hasUserInHive ? '/dashboard' : '/login'));
    }
  }

  /// التنقل الآمن باستخدام mounted و post frame
  void _safeNavigate(VoidCallback navigation) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) navigation();
    });
  }

  Future<void> _showDeviceLimitMessage(String message) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    await messenger
        .showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        )
        .closed;
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();

      debugPrint('Connectivity result: $result, type: ${result.runtimeType}');
      debugPrint(
          'ConnectivityResult.none type: ${ConnectivityResult.none.runtimeType}');
      //return result != ConnectivityResult.none; // error here
      return result.isNotEmpty &&
          result.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity error: $e');
      return false;
    }
  }

  Future<bool> _checkUserExistsInHive() async {
    if (!Hive.isBoxOpen('auth')) {
      await Hive.openBox('auth');
    }
    final box = Hive.box('auth');
    return box.containsKey('user');
  }

  Future<bool> _checkLicenseInHive() async {
    if (!Hive.isBoxOpen('auth')) {
      await Hive.openBox('auth');
    }
    final box = Hive.box('auth');
    return box.containsKey('license');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

 */
/* import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/subscription_notifier.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _appVersion = '';
  late AnimationController _versionController;
  late Animation<Offset> _versionOffset;
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _startConnectivityListener();

    _versionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _versionOffset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _versionController, curve: Curves.easeOut),
    );

    _versionController.forward();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);

    _fadeController.forward();

    _fadeController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        await Future.delayed(const Duration(seconds: 1));
        _checkUserAndStartApp();
      }
    });
  }

  // الاستماع لتغيرات حالة الاتصال - الإصلاح هنا
  void _startConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final isOnline = results.any((result) => result != ConnectivityResult.none);
        
        setState(() {
          _isOnline = isOnline;
        });
        
        // إظهار/إخفاء شريط حالة الاتصال
        if (!_isOnline && mounted) {
          _showOfflineWarning();
        } else if (mounted) {
          // إخفاء الشريط عند عودة الاتصال
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      },
    );
  }

  void _showOfflineWarning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_internet_warning'.tr()),
          backgroundColor: Colors.orange,
          duration: const Duration(hours: 1),
          action: SnackBarAction(
            label: 'dismiss'.tr(),
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${info.version}.${info.buildNumber}';
    });
  }

  // التحقق من وجود بيانات المستخدم في Hive
  Future<bool> _checkUserExistsInHive() async {
    try {
      final userData = await UserLocalStorage.getUser();
      safeDebugPrint('Hive user check - Data: $userData');
      return userData != null && userData['userId'] != null;
    } catch (e) {
      safeDebugPrint('Error checking Hive user data: $e');
      return false;
    }
  }

  // التحقق من وجود ترخيص في Hive باستخدام HiveService
  Future<bool> _checkLicenseInHive() async {
    try {
      final licenseKey = await HiveService.getLicense();
      safeDebugPrint('Hive license check - Key: $licenseKey');
      
      if (licenseKey != null && licenseKey.isNotEmpty) {
        return _validateLicenseFormat(licenseKey);
      }
      
      return false;
    } catch (e) {
      safeDebugPrint('Error checking Hive license: $e');
      return false;
    }
  }

  // دالة مساعدة للتحقق من تنسيق الترخيص
  bool _validateLicenseFormat(String licenseKey) {
    return licenseKey.startsWith('LIC-') && licenseKey.length > 10;
  }

  // التحقق من الاتصال بالإنترنت - الإصلاح هنا
  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);

      setState(() {
        _isOnline = isOnline;
      });
      
      if (!isOnline) {
        _showOfflineWarning();
      }
      
      return isOnline;
    } catch (e) {
      safeDebugPrint('Error checking internet connection: $e');
      return false;
    }
  }

  // الدالة الرئيسية المعدلة
  Future<void> _checkUserAndStartApp() async {
    try {
      // التحقق أولاً من وجود بيانات المستخدم في Hive
      final hasUserInHive = await _checkUserExistsInHive();
      final hasLicenseInHive = await _checkLicenseInHive();

      safeDebugPrint('''
      Local Data Check:
      - User in Hive: $hasUserInHive
      - License in Hive: $hasLicenseInHive
      ''');

      if (!hasUserInHive) {
        safeDebugPrint('No user data in Hive, redirecting to login');
        if (mounted) context.go('/login');
        return;
      }

      // إذا كان هناك مستخدم وترخيص في Hive، انتقل مباشرة إلى Dashboard
      if (hasUserInHive && hasLicenseInHive) {
        safeDebugPrint('Valid local data found, proceeding to dashboard');
        if (mounted) context.go('/dashboard');
        return;
      }

      // إذا كان هناك مستخدم ولكن لا يوجد ترخيص في Hive، تحقق من الإنترنت
      final hasInternet = await _checkInternetConnection();

      if (hasInternet) {
        safeDebugPrint('Internet available, checking online subscription...');
        final subscriptionService = UserSubscriptionService();
        final result = await subscriptionService.checkUserSubscription();

        if (!mounted) return;

        safeDebugPrint('''
        Online Subscription Check:
        - isValid: ${result.isValid}
        - isExpired: ${result.isExpired}
        - Time Left: ${result.timeLeftFormatted}
        ''');

        if (result.isValid && !result.isExpired) {
          // حفظ الترخيص في Hive للاستخدام المستقبلي
          if (result.expiryDate != null) {
            await _saveLicenseToHive(result);
          }
          
          if (result.isExpiringSoon && mounted) {
            SubscriptionNotifier.showWarning(
              context,
              timeLeft: result.timeLeftFormatted ?? '',
            );
          }

          if (mounted) context.go('/dashboard');
        } else {
          safeDebugPrint('Invalid or expired subscription, redirecting to license request');
          if (mounted) context.go('/license/request');
        }
      } else {
        // لا يوجد اتصال ولكن هناك مستخدم - انتقل إلى Dashboard في الوضع المحدود
        safeDebugPrint('No internet but user exists, proceeding to dashboard in limited mode');
        if (mounted) context.go('/dashboard');
        
        // إظهار تحذير أن التطبيق يعمل بدون اتصال
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('offline_mode_warning'.tr()),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        });
      }
    } catch (e) {
      safeDebugPrint('Error in _checkUserAndStartApp: $e');
      
      // في حالة الخطأ، حاول الذهاب إلى Dashboard إذا كان هناك مستخدم في Hive
      final hasUserInHive = await _checkUserExistsInHive();
      if (hasUserInHive && mounted) {
        safeDebugPrint('Error occurred but user exists in Hive, proceeding to dashboard');
        context.go('/dashboard');
      } else if (mounted) {
        context.go('/login');
      }
    }
  }

  // حفظ الترخيص في Hive
  Future<void> _saveLicenseToHive(SubscriptionResult result) async {
    try {
      if (result.expiryDate != null) {
        final licenseInfo = 'LIC-${result.expiryDate!.millisecondsSinceEpoch}';
        await HiveService.saveLicense(licenseInfo);
        safeDebugPrint('License data saved to Hive: $licenseInfo');
      }
    } catch (e) {
      safeDebugPrint('Error saving license to Hive: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _versionController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/splash_screen.jpg',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      const Text(
                        'Ahmed Tharwat tech.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ALL RIGHTS ARE RESERVED',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SlideTransition(
                        position: _versionOffset,
                        child: AnimatedOpacity(
                          opacity: _appVersion.isNotEmpty ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            _appVersion,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // شريط حالة الاتصال في الأعلى
          if (!_isOnline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.orange,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'no_internet_warning'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
 */
/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/subscription_notifier.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _appVersion = '';
  late AnimationController _versionController;
  late Animation<Offset> _versionOffset;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    _versionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _versionOffset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _versionController, curve: Curves.easeOut),
    );

    _versionController.forward();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);

    _fadeController.forward();

    _fadeController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        await Future.delayed(const Duration(seconds: 1));
        _checkUserAndStartApp();
      }
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${info.version}.${info.buildNumber}';
    });
  }

  // دالة للتحقق من وجود بيانات المستخدم باستخدام المعرف فقط
  Future<bool> _checkUserExists() async {
    try {
      final userId = await UserLocalStorage.getUserId();

      safeDebugPrint('User check - ID: $userId');

      // إذا لم يكن هناك معرف مستخدم، يعتبر غير مسجل
      return userId != null && userId.isNotEmpty;
    } catch (e) {
      safeDebugPrint('Error checking user data: $e');
      return false;
    }
  }

  // الدالة الرئيسية المعدلة للتحقق من المستخدم أولاً
  Future<void> _checkUserAndStartApp() async {
    try {
      // التحقق أولاً من وجود بيانات المستخدم
      final userExists = await _checkUserExists();

      if (!mounted) return;

      if (!userExists) {
        safeDebugPrint('No user data found, redirecting to login');
        context.go('/login');
        return;
      }

      safeDebugPrint('User data found, checking subscription...');

      // إذا كان المستخدم موجوداً، التحقق من الاشتراك
      final subscriptionService = UserSubscriptionService();
      final result = await subscriptionService.checkUserSubscription();

      if (!mounted) return;

      safeDebugPrint('''
      Subscription Check Results:
      - isValid: ${result.isValid}
      - isExpired: ${result.isExpired}
      - Days Left: ${result.timeLeftFormatted}
    ''');

      if (!result.isValid || result.isExpired) {
        if (!mounted) return;
        // تأكد من أن showExpiredDialog متوافقة مع المعلمات
        // SubscriptionNotifier.showExpiredDialog(
        //   context,
        //   expiryDate: result.expiryDate ?? DateTime.now(),
        // );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        context.go('/login');
        return;
      }

      if (result.isExpiringSoon) {
        if (!mounted) return;
        SubscriptionNotifier.showWarning(
          context,
          timeLeft: result.timeLeftFormatted ?? '',
        );
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      safeDebugPrint('Error in _checkUserAndStartApp: $e');
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  const Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SlideTransition(
                    position: _versionOffset,
                    child: AnimatedOpacity(
                      opacity: _appVersion.isNotEmpty ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        _appVersion,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} */

/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _appVersion = '';
  late AnimationController _versionController;
  late Animation<Offset> _versionOffset;

  @override
  void initState() {
    super.initState();
    _loadAppVersion(); // ← تحميل رقم الإصدار
    _versionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _versionOffset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _versionController, curve: Curves.easeOut),
    );

// شغّل الحركة بعد ظهور الـ splash مباشرة
    _versionController.forward();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);

    _fadeController.forward();

    // بعد انتهاء التحريك، انتظر ثانية ثم ابدأ التنقل
    _fadeController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        await Future.delayed(const Duration(seconds: 1));
       _startApp(); // ← تابع تحميل التطبيق بعد الانتظار
      }
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${info.version}.${info.buildNumber}';
    });
  }

/*   Future<void> _startApp() async {
  final subscriptionService = UserSubscriptionService();
  final result = await subscriptionService.checkUserSubscription();

  if (!mounted) return;

  if (!result.isValid || result.isExpired) {
    SubscriptionNotifier.showExpiredDialog(context);
    await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return; 
    context.go('/login');
    return;
  }

  SubscriptionNotifier.showWarning(context, result);
  context.go(result.isValid ? '/dashboard' : '/login');
}
   */

/* Future<void> _startApp() async {
  try {
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    if (!mounted) return;

    safeDebugPrint('''
      Subscription Check Results:
      - isValid: ${result.isValid}
      - isExpired: ${result.isExpired}
      - Days Remaining: ${result.daysRemaining}
    ''');

    if (!result.isValid || result.isExpired) {
      if (!mounted) return;
      await SubscriptionNotifier.showExpiredDialog(context);
      if (!mounted) return;
      context.go('/login');
      return;
    }

    if (result.daysRemaining <= 7) {
      if (!mounted) return;
      await SubscriptionNotifier.showWarning(context, result);
    }

    if (!mounted) return;
    context.go('/dashboard');
  } catch (e) {
    safeDebugPrint('Error in _startApp: $e');
    if (!mounted) return;
    context.go('/login');
  }
}
 */

  Future<void> _startApp() async {
    try {
      final subscriptionService = UserSubscriptionService();
      final result = await subscriptionService.checkUserSubscription();

      if (!mounted) return;

      safeDebugPrint('''
      Subscription Check Results:
      - isValid: ${result.isValid}
      - isExpired: ${result.isExpired}
      - Days Left: ${result.daysLeft}
    ''');

      if (!result.isValid || result.isExpired) {
        if (!mounted) return;
        SubscriptionNotifier.showExpiredDialog(
          context,
          expiryDate: result.expiryDate ?? DateTime.now(),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        context.go('/login');
        return;
      }

      if (result.daysLeft <= 30) {
        if (!mounted) return;
        SubscriptionNotifier.showWarning(
          context,
          daysLeft: result.daysLeft,
        );
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      safeDebugPrint('Error in _startApp: $e');
      if (!mounted) return;
      context.go('/login');
    }
  }
 
  
  
  @override
  void dispose() {
    _fadeController.dispose();
    _versionController.dispose(); // ✅
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  const Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SlideTransition(
                    position: _versionOffset,
                    child: AnimatedOpacity(
                      opacity: _appVersion.isNotEmpty ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        _appVersion,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
/*                   Text(
                    _appVersion,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ), */
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 */

/*   void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(tr('membership_expired_title')),
        content: Text(tr('membership_expired_message')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
  }
 */
/*   void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('error'.tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startApp(); // إعادة المحاولة
            },
            child: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }
 */
 

/*   Future<void> _startApp() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    safeDebugPrint('📶 Connectivity result: ${connectivityResult.runtimeType}');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showErrorDialog('no_internet'.tr());
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      safeDebugPrint('❌ ${'user_not_logged_in'.tr()}');
      if (!mounted) return;
      context.go('/login');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isActive = userDoc.data()?['isActive'] == true;

      if (!userDoc.exists || !isActive) {
        safeDebugPrint('❗️ Showing inactive account dialog');
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(tr('membership_expired_title')),
            content: Text(tr('membership_expired_message')),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (mounted) context.go('/login');
                },
                child: Text(tr('ok')),
              ),
            ],
          ),
        );

        return; // مهم جدًا حتى لا يكمل الكود للتنقل إلى /dashboard
      }

      // إذا كان المستخدم نشطًا - نحفظ بياناته محليًا
      final localUser = await UserLocalStorage.getUser();
      if (localUser == null) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        );
        safeDebugPrint('📦 ${'local_user_saved'.tr()}');
      } else {
        safeDebugPrint('📦 ${'local_user_exists'.tr(args: [
              localUser['displayName'] ?? ''
            ])}');
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      safeDebugPrint('🔥 Firestore error: $e');

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('error')),
          content: Text(tr('membership_expired_message')),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (mounted) context.go('/login');
              },
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
      return;
    }
  }
 */

/*   Future<void> _startApp() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    safeDebugPrint('📶 Connectivity result: ${connectivityResult.runtimeType}');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showErrorDialog('no_internet'.tr());
      return;
    }

    final localUser = await UserLocalStorage.getUser();

    if (localUser == null) {
      safeDebugPrint('🚫 No local user. Redirecting to login.');
      if (!mounted) return;
      context.go('/login');
      return;
    }

    safeDebugPrint('✅ Local user found: ${localUser['email']}');

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        safeDebugPrint('❌ Firebase user not logged in');
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isActive = userDoc.data()?['isActive'] == true;

      if (!userDoc.exists || !isActive) {
        safeDebugPrint('⛔️ User inactive or document not found');
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(tr('membership_expired_title')),
            content: Text(tr('membership_expired_message')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/login');
                },
                child: Text(tr('ok')),
              ),
            ],
          ),
        );

        return;
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      safeDebugPrint('🔥 Firestore error: $e');
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('error')),
          content: Text(tr('membership_expired_message')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
    }
  }
 */

/* 
last update 05-08-2025
Future<void> _startApp() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  safeDebugPrint('📶 Connectivity result: ${connectivityResult.runtimeType}');

  if (connectivityResult.contains(ConnectivityResult.none)) {
    _showErrorDialog('no_internet'.tr());
    return;
  }

  final localUser = await UserLocalStorage.getUser();

  if (localUser == null) {
    safeDebugPrint('🚫 No local user. Redirecting to login.');
    if (!mounted) return;
    context.go('/login');
    return;
  }

  safeDebugPrint('✅ Local user found: ${localUser['email']}');

  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      safeDebugPrint('❌ Firebase user not logged in');
      if (!mounted) return;
      context.go('/login');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      safeDebugPrint('⛔️ User document not found');
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/login');
      return;
    }

    final data = userDoc.data();
    final isActive = data?['isActive'] == true;
    final durationDays = data?['subscriptionDurationInDays'] ?? 30;
    final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();

    if (!isActive || createdAt == null) {
      safeDebugPrint('⛔️ User inactive or missing createdAt');
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showExpiredDialog();
      return;
    }

    final now = DateTime.now();
    final expiryDate = createdAt.add(Duration(days: durationDays));
    final daysLeft = expiryDate.difference(now).inDays;

    if (now.isAfter(expiryDate)) {
      safeDebugPrint('🔴 Subscription expired on $expiryDate');

      // إلغاء تفعيل الحساب في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'isActive': false});

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      _showExpiredDialog();
      return;
    }

    // تذكير بقرب انتهاء الاشتراك
    if (daysLeft <= 3) {
      safeDebugPrint('⚠️ Subscription expires in $daysLeft day(s)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('subscription_expires_soon')),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    // ✅ كل شيء تمام، توجه إلى لوحة التحكم
    if (!mounted) return;
    context.go('/dashboard');
  } catch (e) {
    safeDebugPrint('🔥 Firestore error: $e');
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    _showExpiredDialog();
  }
}
 */

 /*  Future<void> _startApp() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    safeDebugPrint('📶 Connectivity result: $connectivityResult');

    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    if (isOffline) {
      // 📴 عرض رسالة بأن الإنترنت غير متاح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('no_internet_connection')),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // 👤 محاولة استخدام بيانات المستخدم من SharedPreferences
      final localUser = await UserLocalStorage.getUser();
      if (localUser == null) {
        safeDebugPrint('🚫 No local user. Redirecting to login.');
        if (mounted) context.go('/login');
        return;
      }

      final createdAtString = localUser['createdAt'] as String?;
      final createdAt =
          createdAtString != null ? DateTime.tryParse(createdAtString) : null;

      final duration = localUser['subscriptionDurationInDays'] as int? ?? 30;

      if (createdAt == null) {
        safeDebugPrint('⚠️ createdAt not found in local user data.');
        if (mounted) context.go('/login');
        return;
      }

      final now = DateTime.now();
      final expiryDate = createdAt.add(Duration(days: duration));

      if (now.isAfter(expiryDate)) {
        safeDebugPrint('🔴 Local subscription expired on $expiryDate');

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: Text(tr('membership_expired_title')),
              content: Text(tr('membership_expired_message')),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/login');
                  },
                  child: Text(tr('ok')),
                ),
              ],
            ),
          );
        }
        return;
      }

      // ✅ الاشتراك ما زال ساريًا
      safeDebugPrint('🟢 Local subscription still valid until $expiryDate');
      if (mounted) context.go('/dashboard');
      return;
    }

    // ✅ إذا كان هناك إنترنت، نتابع التحقق من Firebase (نفس الكود السابق)
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        safeDebugPrint('❌ Firebase user not logged in');
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        safeDebugPrint('⛔️ User document not found');
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final data = userDoc.data();
      final isActive = data?['isActive'] == true;
      final durationDays = data?['subscriptionDurationInDays'] ?? 30;
      final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();

      if (!isActive || createdAt == null) {
        safeDebugPrint('⛔️ User inactive or missing createdAt');
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showExpiredDialog();
        return;
      }

      final now = DateTime.now();
      final expiryDate = createdAt.add(Duration(days: durationDays));
      final daysLeft = expiryDate.difference(now).inDays;

      if (now.isAfter(expiryDate)) {
        safeDebugPrint('🔴 Subscription expired on $expiryDate');

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'isActive': false});

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        _showExpiredDialog();
        return;
      }

      // ⚠️ إشعار المستخدم باقتراب انتهاء الاشتراك
      if (daysLeft <= 3) {
        safeDebugPrint('⚠️ Subscription expires in $daysLeft day(s)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  tr('subscription_expires_soon', args: [daysLeft.toString()])),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // ✅ حفظ المستخدم محليًا إن لم يكن موجود
      final localUser = await UserLocalStorage.getUser();
      if (localUser == null) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          subscriptionDurationInDays: durationDays,
          createdAt: createdAt,
          companyIds: List<String>.from(data?['companyIds'] ?? []),
          factoryIds: List<String>.from(data?['factoryIds'] ?? []),
          supplierIds: List<String>.from(data?['supplierIds'] ?? []),
          isActive: data?['isActive'] == true,
        );
        safeDebugPrint('📦 Local user saved.');
      }

      if (mounted) context.go('/dashboard');
    } catch (e) {
      safeDebugPrint('🔥 Firestore error: $e');
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showExpiredDialog();
    }
  }
 */
  

/*   @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();

    _startApp();
  }
 */


/*   Future<void> _startApp() async {
    //  await Future.delayed(const Duration(seconds: 2));

    final connectivityResult = await Connectivity().checkConnectivity();

    safeDebugPrint('📶 Connectivity result: ${connectivityResult.runtimeType}');
    // المقارنة صحيحة لأن connectivityResult من نوع ConnectivityResult
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showErrorDialog('no_internet'.tr());
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      safeDebugPrint('❌ ${'user_not_logged_in'.tr()}');
      if (!mounted) return;
      context.go('/login');
      return;
    }

      /* 
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (!userDoc.exists || userDoc.data()?['isActive'] == false) {
            safeDebugPrint('⛔️ ${'account_inactive'.tr()}');
            safeDebugPrint('❗️ Showing inactive account dialog');

            await FirebaseAuth.instance.signOut();
            _showErrorDialog('account_inactive'.tr());
            await Future.delayed(const Duration(milliseconds: 500));
            await FirebaseAuth.instance.signOut();
            return;
          } */
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || userDoc.data()?['isActive'] == false) {
        safeDebugPrint('❗️ Showing inactive account dialog');
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(tr('membership_expired_title')),
            content: Text(tr('membership_expired_message')),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  Future.microtask(() {
                    if (mounted) context.go('/login');
                  });
                 // context.go('/login');
                },
                child: Text(tr('ok')),
              ),
            ],
          ),
        );

        return;
      }
    } catch (e) {
      safeDebugPrint('🔥 Firestore error: $e');

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('error')),
          content: Text(tr('membership_expired_message')), // يمكن تخصيص رسالة
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                Future.microtask(() {
                  if (mounted) context.go('/login');
                });
                context.go('/login');
              },
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
      return;
    }

    final localUser = await UserLocalStorage.getUser();
    if (localUser == null) {
      await UserLocalStorage.saveUser(
        userId: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
      );
      safeDebugPrint('📦 ${'local_user_saved'.tr()}');
    } else {
      safeDebugPrint('📦 ${'local_user_exists'.tr(args: [
            localUser['displayName'] ?? ''
          ])}');
    }

    if (!mounted) return;
    context.go('/dashboard');
  } */



/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
//import 'package:puresip_purchasing/services/user_local_storage.dart'; // تأكد من استيراد المسار الصحيح

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    safeDebugPrint('📱 Splash started');

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2)); // لإظهار السبلاتش

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      safeDebugPrint('✅ Firebase user found: ${user.uid}');

      // تحقق إن كانت البيانات المحلية محفوظة
      final localUser = await UserLocalStorage.getUser();

      if (localUser == null) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        );
        safeDebugPrint('📦 Local user data saved from Firebase.');
      } else {
        safeDebugPrint('📦 Loaded local user: ${localUser['displayName']}');
      }

      if (!mounted) return;
      context.go('/dashboard');
    } else {
      safeDebugPrint('❌ No Firebase user found, redirecting to login');
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}







/*
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/user_local_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();

    _handleStartupFlow();
  }

  Future<void> _handleStartupFlow() async {
    await Future.delayed(const Duration(seconds: 2));

    // ✅ التحقق من الاتصال
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorAndExit('لا يوجد اتصال بالإنترنت');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      safeDebugPrint('❌ No authenticated user.');
      if (!mounted) return;
      context.go('/login');
      return;
    }

    safeDebugPrint('✅ Firebase user found: ${user.uid}');

    // ✅ التحقق من صلاحيات المستخدم (مثال: هل حسابه مفعل؟)
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists || (userDoc.data()?['isActive'] == false)) {
      safeDebugPrint('⛔️ User is not authorized.');
      await FirebaseAuth.instance.signOut();
      _showErrorAndExit('حسابك غير مفعل، تواصل مع الإدارة.');
      return;
    }

    // ✅ تخزين بيانات المستخدم محليًا إن لم تكن موجودة
    final localUser = await UserLocalStorage.getUser();
    if (localUser == null) {
      await UserLocalStorage.saveUser(
        userId: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
      );
      safeDebugPrint('📦 Local user saved.');
    } else {
      safeDebugPrint('📦 Loaded local user: ${localUser['displayName']}');
    }

    if (!mounted) return;
    context.go('/dashboard');
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => exit(0), // يمكنك استبدالها بإعادة المحاولة أو تسجيل الخروج
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

*/








/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    safeDebugPrint('📱 Splash started on Android');
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();

    Timer(const Duration(seconds: 3), () {
      _fadeController.stop();
      if (mounted) {
        safeDebugPrint('🚀 Navigating to / from splash');
        context.go('/dashboard'); // انتقل إلى الصفحة الرئيسية بعد السبلاتش
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation, // ← استخدم المتغير فعليًا هنا
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 */ */