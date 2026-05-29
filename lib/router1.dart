/* /* // router.dart - النسخة النهائية المحسنة
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/pages/auth/login_page.dart';
import 'package:puresip_purchasing/pages/auth/signup_page.dart';
import 'package:puresip_purchasing/pages/companies/add_company_page.dart';
import 'package:puresip_purchasing/pages/companies/companies_page.dart';
import 'package:puresip_purchasing/pages/companies/company_added_page.dart';
import 'package:puresip_purchasing/pages/companies/edit_company_page.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_page.dart';
import 'package:puresip_purchasing/pages/dashboard/splash_screen.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_managment_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_registrations_handler.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_device_request_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_license_request.dart';
import 'package:puresip_purchasing/pages/factories/add_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/edit_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/factories_page.dart';
import 'package:puresip_purchasing/pages/finished_products/finished_products_page.dart';
import 'package:puresip_purchasing/pages/inventory/inventory_query_page.dart';
import 'package:puresip_purchasing/pages/items/add_item_page.dart';
import 'package:puresip_purchasing/pages/items/edit_item_page.dart';
import 'package:puresip_purchasing/pages/items/items_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/manufacturing_orders_screen.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/add_purchase_order_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/edit_puchase_order_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/purchase_order_details_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/purchase_orders_page.dart';
import 'package:puresip_purchasing/pages/purchasing/purchase_orders_analysis/pages/purchase_orders_analysis_page.dart';
import 'package:puresip_purchasing/pages/reports/abc_analysis_report.dart';
import 'package:puresip_purchasing/pages/reports/advanced_stock_movements_report.dart';
import 'package:puresip_purchasing/pages/reports/consumption_report.dart';
import 'package:puresip_purchasing/pages/reports/cost_analysis_report.dart';
import 'package:puresip_purchasing/pages/reports/expiry_report.dart';
import 'package:puresip_purchasing/pages/reports/inventory_report_page.dart';
import 'package:puresip_purchasing/pages/reports/reports_page.dart';
import 'package:puresip_purchasing/pages/reports/slow_moving_report.dart';
import 'package:puresip_purchasing/pages/reports/supplier_performance_report.dart';
import 'package:puresip_purchasing/pages/settings/additional_items_page.dart';
import 'package:puresip_purchasing/pages/settings/user_terms_management_page.dart';
import 'package:puresip_purchasing/pages/settings/settings_page.dart';
import 'package:puresip_purchasing/pages/stock_movements/stock_movements_page.dart';
import 'package:puresip_purchasing/pages/suppliers/add_supplier_page.dart';
import 'package:puresip_purchasing/pages/suppliers/edit_supplier_page.dart';
import 'package:puresip_purchasing/pages/suppliers/suppliers_page.dart';
import 'package:puresip_purchasing/services/auto_license_service.dart';
import 'package:puresip_purchasing/services/device_fingerprint.dart';
import 'package:puresip_purchasing/services/order_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/sync_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/widgets/auth/admin_license_management.dart';

// 🌐 مفتاح التنقل العام
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// أنشئ instance للخدمة
final AutoLicenseService _autoLicenseService = AutoLicenseService();
final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

// 🔁 قائمة المسارات المستثناة من التحقق الكامل
const List<String> licenseExemptPaths = [
  '/license/request',
  '/logout',
  '/device-management',
  '/device-registration',
  '/device-request'
];

// ✅ الكلاس المسؤول عن حالة الترخيص والتحقق من البصمة
class LicenseStatusWithFingerprint {
  final bool isValid;
  final bool isOffline;
  final DateTime? expiryDate;
  final int daysLeft;
  final int maxDevices;
  final int usedDevices;
  final String? reason;
  final bool deviceLimitExceeded;
  final String? licenseKey;
  final bool hasValidLicense;
  final bool deviceFingerprintValid;

  LicenseStatusWithFingerprint({
    required this.isValid,
    required this.isOffline,
    this.expiryDate,
    required this.daysLeft,
    required this.maxDevices,
    required this.usedDevices,
    this.reason,
    required this.deviceLimitExceeded,
    this.licenseKey,
    required this.hasValidLicense,
    required this.deviceFingerprintValid,
  });
}

// ==================== دوال التخزين المحسن ====================

/// ✅ التحقق من وجود ترخيص للمستخدم وإنشاء ترخيص تلقائي إذا لزم الأمر
Future<void> _ensureUserHasLicense(String userId) async {
  try {
    final existingLicenseKey = await _secureStorage.read(key: 'licenseKey');
    
    if (existingLicenseKey != null && existingLicenseKey.isNotEmpty) {
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(existingLicenseKey)
          .get();
      
      if (licenseDoc.exists) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        final isActive = licenseDoc.get('isActive') ?? false;
        
        if (isActive && expiry != null && expiry.isAfter(DateTime.now())) {
          safeDebugPrint('✅ User already has valid license: $existingLicenseKey');
          return;
        }
      }
    }
    
    safeDebugPrint('🔄 Creating auto-license for new user: $userId');
    final newLicenseKey = await _autoLicenseService.createAutoLicenseForNewUser(userId);
    
    if (newLicenseKey != null) {
      safeDebugPrint('✅ Auto-license created successfully: $newLicenseKey');
      await _secureStorage.write(key: 'licenseKey', value: newLicenseKey);
      await _syncLicenseData(userId);
    }
  } catch (e) {
    safeDebugPrint('❌ Error ensuring user has license: $e');
  }
}

/// ✅ مزامنة بيانات المستخدم (حساسة + غير حساسة)
Future<void> _syncUserData(String userId) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final prefs = await SharedPreferences.getInstance();

    // استخراج اسم المستخدم
    String userName = 'User';
    if (data['displayName'] != null && data['displayName'].toString().isNotEmpty) {
      userName = data['displayName'];
    } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
      userName = data['name'];
    } else if (data['email'] != null && data['email'].toString().isNotEmpty) {
      userName = data['email'].split('@').first;
    }

    // ✅ غير حساس → SharedPreferences
    await prefs.setString('userName', userName);
    await prefs.setString('lastSync', DateTime.now().toIso8601String());

    // ✅ حساس → SecureStorage
    String? activeLicenseKey;
    try {
      final licensesSnapshot = await FirebaseFirestore.instance
          .collection('licenses')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final licenseDoc in licensesSnapshot.docs) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          activeLicenseKey = licenseDoc.id;
          safeDebugPrint('✅ Found active license: $activeLicenseKey');
          break;
        }
      }
    } catch (e) {
      safeDebugPrint('⚠️ Could not fetch active licenses: $e');
    }

    final licenseKey = activeLicenseKey ?? data['licenseKey'] as String?;
    if (licenseKey != null) {
      await _secureStorage.write(key: 'licenseKey', value: licenseKey);
    }

    final isAdmin = data['isAdmin'] ?? false;
    await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());

    safeDebugPrint('[Sync] ✅ User data synced - Name: $userName, License: $licenseKey');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ User data sync failed: $e');
  }
}

/// ✅ مزامنة بيانات الترخيص (كلها حساسة → SecureStorage)
Future<void> _syncLicenseData(String userId) async {
  try {
    final currentLicenseKey = await _secureStorage.read(key: 'licenseKey');

    if (currentLicenseKey == null || currentLicenseKey.isEmpty) {
      safeDebugPrint('⚠️ No license key found');
      return;
    }

    final licenseDoc = await FirebaseFirestore.instance
        .collection('licenses')
        .doc(currentLicenseKey)
        .get();

    if (!licenseDoc.exists) {
      safeDebugPrint('⚠️ License document not found: $currentLicenseKey');
      return;
    }

    final data = licenseDoc.data()!;
    final expiry = (data['expiryDate'] as Timestamp?)?.toDate();
    final isActive = data['isActive'] ?? false;
    final devices = data['devices'] as List<dynamic>? ?? [];
    final maxDevices = data['maxDevices'] as int? ?? 1;
    final usedDevices = devices.length;

    final now = DateTime.now();
    final isValid = isActive && expiry != null && expiry.isAfter(now);

    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceFingerprintValid = devices.any((device) =>
        device is Map<String, dynamic> &&
        device['fingerprint'] == currentFingerprint);

    final statusData = {
      'isValid': isValid,
      'isActive': isActive,
      'expiryDate': expiry?.toIso8601String(),
      'daysLeft': expiry != null ? expiry.difference(now).inDays : 0,
      'maxDevices': maxDevices,
      'usedDevices': usedDevices,
      'reason': isValid ? 'Active' : 'Invalid license',
      'deviceLimitExceeded': usedDevices >= maxDevices && maxDevices > 0 && !deviceFingerprintValid,
      'licenseKey': currentLicenseKey,
      'deviceFingerprintValid': deviceFingerprintValid,
      'hasValidLicense': isValid && deviceFingerprintValid,
    };

    // ✅ كل هذه البيانات حساسة → تخزين في SecureStorage
    await _secureStorage.write(key: 'licenseStatus', value: json.encode(statusData));
    await _secureStorage.write(key: 'fingerprint', value: currentFingerprint);
    
    safeDebugPrint('[Sync] ✅ License data synced - Valid: $isValid, FingerprintValid: $deviceFingerprintValid');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ License sync failed: $e');
  }
}

/// ✅ تنظيف بيانات الترخيص غير الصالحة
Future<void> _cleanupInvalidLicenseData() async {
  try {
    final currentLicenseKey = await _secureStorage.read(key: 'licenseKey');

    if (currentLicenseKey != null) {
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(currentLicenseKey)
          .get();

      if (licenseDoc.exists) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        final isActive = licenseDoc.get('isActive') ?? false;

        if (!isActive || (expiry != null && expiry.isBefore(DateTime.now()))) {
          safeDebugPrint('🗑️ License $currentLicenseKey is invalid, clearing local data');
          await _secureStorage.delete(key: 'licenseKey');
          await _secureStorage.delete(key: 'fingerprint');
          await _secureStorage.delete(key: 'licenseStatus');
        }
      }
    }
  } catch (e) {
    safeDebugPrint('⚠️ Cleanup failed: $e');
  }
}

/// ✅ تنظيف التراخيص المنتهية والتبديل إلى ترخيص نشط
Future<void> _cleanupExpiredLicenses() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentLicenseKey = await _secureStorage.read(key: 'licenseKey');

    if (currentLicenseKey != null) {
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(currentLicenseKey)
          .get();

      if (licenseDoc.exists) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          safeDebugPrint('🗑️ Current license expired, finding active one...');
          final activeLicense = await _findActiveLicense(user.uid);
          if (activeLicense != null) {
            await _secureStorage.write(key: 'licenseKey', value: activeLicense);
            safeDebugPrint('✅ Switched to active license: $activeLicense');
          }
        }
      }
    }
  } catch (e) {
    safeDebugPrint('Error cleaning expired licenses: $e');
  }
}

/// ✅ البحث عن ترخيص نشط للمستخدم
Future<String?> _findActiveLicense(String userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('licenses')
      .where('userId', isEqualTo: userId)
      .where('isActive', isEqualTo: true)
      .get();

  for (final doc in snapshot.docs) {
    final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
    if (expiry != null && expiry.isAfter(DateTime.now())) {
      return doc.id;
    }
  }
  return null;
}

/// ✅ الحصول على حالة الترخيص مع التحقق من البصمة
Future<LicenseStatusWithFingerprint> _getLicenseStatusWithFingerprintCheck(
    String licenseKey) async {
  try {
    final cachedStatusJson = await _secureStorage.read(key: 'licenseStatus');

    if (cachedStatusJson != null) {
      final cachedStatus = json.decode(cachedStatusJson) as Map<String, dynamic>;
      
      bool isValid = cachedStatus['isValid'] ?? false;
      final deviceFingerprintValid = cachedStatus['deviceFingerprintValid'] ?? false;
      final expiryDateStr = cachedStatus['expiryDate'];
      final expiryDate = expiryDateStr != null ? DateTime.parse(expiryDateStr) : null;
      final daysLeft = cachedStatus['daysLeft'] ?? 0;
      final maxDevices = cachedStatus['maxDevices'] ?? 0;
      final usedDevices = cachedStatus['usedDevices'] ?? 0;
      final deviceLimitExceeded = cachedStatus['deviceLimitExceeded'] ?? false;
      final storedLicenseKey = cachedStatus['licenseKey'] as String?;

      if (expiryDate != null) {
        isValid = expiryDate.isAfter(DateTime.now());
      }

      return LicenseStatusWithFingerprint(
        isValid: isValid,
        isOffline: false,
        expiryDate: expiryDate,
        daysLeft: daysLeft,
        maxDevices: maxDevices,
        usedDevices: usedDevices,
        reason: isValid ? 'Active' : (cachedStatus['reason'] ?? 'Invalid'),
        deviceLimitExceeded: deviceLimitExceeded,
        licenseKey: storedLicenseKey ?? licenseKey,
        hasValidLicense: isValid && deviceFingerprintValid,
        deviceFingerprintValid: deviceFingerprintValid,
      );
    }

    return LicenseStatusWithFingerprint(
      isValid: false,
      isOffline: false,
      daysLeft: 0,
      maxDevices: 0,
      usedDevices: 0,
      deviceLimitExceeded: false,
      hasValidLicense: false,
      deviceFingerprintValid: false,
    );
  } catch (e) {
    safeDebugPrint('Error in _getLicenseStatusWithFingerprintCheck: $e');
    return LicenseStatusWithFingerprint(
      isValid: false,
      isOffline: false,
      daysLeft: 0,
      maxDevices: 0,
      usedDevices: 0,
      deviceLimitExceeded: false,
      hasValidLicense: false,
      deviceFingerprintValid: false,
    );
  }
}

/// ✅ التحقق من تسجيل الجهاز الحالي
Future<bool> _isCurrentDeviceRegistered(
    String licenseKey, String fingerprint) async {
  try {
    final licenseDoc = await FirebaseFirestore.instance
        .collection('licenses')
        .doc(licenseKey)
        .get();

    if (!licenseDoc.exists) return false;

    final devices = licenseDoc.data()?['devices'] as List<dynamic>? ?? [];
    return devices.any((device) =>
        device is Map<String, dynamic> && device['fingerprint'] == fingerprint);
  } catch (e) {
    safeDebugPrint('Error checking current device registration: $e');
    return false;
  }
}

/// 📬 التحقق من وجود طلبات ترخيص للمستخدم الحالي
Future<bool> _hasUserLicenseRequest() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final snapshot = await FirebaseFirestore.instance
      .collection('license_requests')
      .where('userId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'pending')
      .get();

  return snapshot.docs.isNotEmpty;
}

/// 📬 التحقق من وجود طلبات ترخيص عالقة للمشرف
Future<bool> _hasLicenseRequests() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('license_requests')
      .where('status', isEqualTo: 'pending')
      .get();

  return snapshot.docs.isNotEmpty;
}

// 🚦 الدالة الرئيسية لإعادة التوجيه
Future<String?> _appRedirectLogic(
    BuildContext context, GoRouterState state) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentPath = state.matchedLocation;

  if (currentPath == '/splash') return null;

  if (user == null) {
    return ['/login', '/signup'].contains(currentPath) ? null : '/login';
  }

  await _ensureUserHasLicense(user.uid);

  try {
    await _cleanupExpiredLicenses();
    await _cleanupInvalidLicenseData();
    await _syncUserData(user.uid);
    await _syncLicenseData(user.uid);

    final syncService = SyncService();
    await syncService.syncAllInBackground(force: true);

    // ✅ قراءة البيانات من SecureStorage (حساسة)
    final isAdminStr = await _secureStorage.read(key: 'isAdmin');
    final isAdmin = isAdminStr == 'true';
    final licenseKey = await _secureStorage.read(key: 'licenseKey');

    // ==================== معالج المسؤول ====================
    if (isAdmin) {
      final hasPendingRequests = await _hasLicenseRequests();
      if (currentPath == '/license/request') {
        return hasPendingRequests ? '/admin/licenses' : '/dashboard';
      }
      return null;
    }

    // ==================== معالج المستخدم العادي ====================
    
    final hasUserPendingRequest = await _hasUserLicenseRequest();
    if (hasUserPendingRequest && currentPath != '/license/request') {
      safeDebugPrint('📋 Redirecting to /license/request - Pending request exists');
      return '/license/request';
    }

    final licenseStatus = await _getLicenseStatusWithFingerprintCheck(licenseKey ?? '');

    safeDebugPrint('''
    🔍 Detailed License Check:
    - User ID: ${user.uid}
    - Is Admin: $isAdmin
    - Has Pending Request: $hasUserPendingRequest
    - Path: $currentPath
    - License Valid: ${licenseStatus.isValid}
    - Fingerprint Valid: ${licenseStatus.deviceFingerprintValid}
    - Device Limit: ${licenseStatus.deviceLimitExceeded}
    - Days Left: ${licenseStatus.daysLeft}
    ''');

    // ==================== المنطق المتسلسل للتوجيه ====================

    // 1. إذا كان هناك طلب ترخيص معلق
    if (hasUserPendingRequest && currentPath != '/license/request') {
      return '/license/request';
    }

    // 2. إذا كانت الرخصة غير صالحة
    if (!licenseStatus.isValid && licenseKey == null) {
      safeDebugPrint('🚫 Redirecting to /license/request - No valid license');
      return '/license/request';
    }

    // 3. التحقق من البصمة
    if (licenseStatus.isValid && !licenseStatus.deviceFingerprintValid) {
      if (licenseKey != null) {
        final subscriptionService = UserSubscriptionService();
        final canChangeDevice = await subscriptionService.canChangeDevice(licenseKey);

        if (canChangeDevice) {
          if (!['/device-management', '/device-change'].contains(currentPath)) {
            safeDebugPrint('🔄 Can change device - redirecting to device management');
            return '/device-management';
          }
          return null;
        }

        final registered = await subscriptionService.registerDeviceFingerprint(licenseKey);

        if (registered) {
          safeDebugPrint('✅ Device automatically registered!');
          if (currentPath == '/device-management' || currentPath == '/device-registration') {
            return '/dashboard';
          }
          return null;
        }
      }

      if (!['/device-management', '/device-registration', '/device-request', '/device-change']
          .contains(currentPath)) {
        safeDebugPrint('📱 Redirecting to /device-management - Invalid fingerprint');
        return '/device-management';
      }
      return null;
    }

    // 4. التحقق من الجهاز الحالي
    if (licenseStatus.licenseKey != null) {
      final currentFingerprint = await DeviceFingerprint.generate();
      final isCurrentDeviceRegistered = await _isCurrentDeviceRegistered(
          licenseStatus.licenseKey!, currentFingerprint);

      if (!isCurrentDeviceRegistered) {
        final subscriptionService = UserSubscriptionService();
        final canChangeDevice = await subscriptionService
            .canChangeDevice(licenseStatus.licenseKey!);

        if (canChangeDevice) {
          if (currentPath != '/device-management') {
            safeDebugPrint('🔄 Device not registered but can change - redirecting to device management');
            return '/device-management';
          }
          return null;
        }

        if (licenseStatus.deviceLimitExceeded) {
          if (currentPath != '/license/request' && currentPath != '/device-management') {
            safeDebugPrint('⚠️ Device limit exceeded - redirecting to license request');
            return '/license/request';
          }
          return null;
        }

        if (currentPath != '/license/request' && currentPath != '/device-management') {
          safeDebugPrint('⚠️ Device not registered - redirecting to license request');
          return '/license/request';
        }
        return null;
      }

      if (currentPath == '/device-management' || currentPath == '/device-registration') {
        safeDebugPrint('✅ Device is registered, navigating to dashboard');
        return '/dashboard';
      }
    }

    // 5. إذا كانت الرخصة والبصمة صالحتين
    if (licenseStatus.isValid && licenseStatus.deviceFingerprintValid) {
      if (licenseStatus.expiryDate != null && licenseStatus.expiryDate!.isBefore(DateTime.now())) {
        safeDebugPrint('⚠️ License expired - redirecting to license request');
        return '/license/request';
      }

      if ([
        '/license/request',
        '/device-management',
        '/device-registration',
        '/device-request'
      ].contains(currentPath)) {
        safeDebugPrint('✅ Redirecting to /dashboard - Valid license and fingerprint');
        return '/dashboard';
      }
      return null;
    }

    // 6. الحالات الأخرى
    if (!licenseExemptPaths.contains(currentPath)) {
      safeDebugPrint('🔁 Redirecting to /license/request - Fallback case');
      return '/license/request';
    }

    return null;
  } catch (e) {
    safeDebugPrint('❌ Router Error: $e');
    if (currentPath == '/dashboard') return null;
    return '/dashboard';
  }
}

// 🧭 تكوين المسارات
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  redirect: _appRedirectLogic,
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const SplashScreen()),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
    GoRoute(
        path: '/dashboard', builder: (context, state) => const DashboardPage()),
    GoRoute(
        path: '/companies', builder: (context, state) => const CompaniesPage()),
    GoRoute(
        path: '/add-company',
        builder: (context, state) => const AddCompanyPage()),
    GoRoute(
      path: '/edit-company/:id',
      builder: (context, state) =>
          EditCompanyPage(companyId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) {
        final allCards = state.extra as List<String>? ?? [];
        return SettingsPage(allCards: allCards);
      },
    ),
    GoRoute(
      path: '/company-added/:id',
      builder: (context, state) {
        final docId = state.pathParameters['id']!;
        final nameEn = state.uri.queryParameters['nameEn'] ?? '';
        return CompanyAddedPage(nameEn: nameEn, docId: docId);
      },
    ),
    GoRoute(
        path: '/suppliers', builder: (context, state) => const SuppliersPage()),
    GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsPage(),
        routes: [
          GoRoute(
            path: '/advanced-movements',
            builder: (context, state) => const AdvancedStockMovementsReport(),
          ),
          GoRoute(
            path: '/slow-moving',
            builder: (context, state) => const SlowMovingReport(),
          ),
          GoRoute(
            path: '/expiry',
            builder: (context, state) => const ExpiryReport(),
          ),
          GoRoute(
            path: '/supplier-performance',
            builder: (context, state) => const SupplierPerformanceReport(),
          ),
          GoRoute(
            path: '/abc-analysis',
            builder: (context, state) => const AbcAnalysisReport(),
          ),
          GoRoute(
            path: '/consumption',
            builder: (context, state) => const ConsumptionReport(),
          ),
          GoRoute(
            path: '/cost-analysis',
            builder: (context, state) => const CostAnalysisReport(),
          ),
          GoRoute(
            path: '/purchase-orders-analysis',
            builder: (context, state) => const PurchaseOrdersAnalysisPage(),
          ),
          GoRoute(
            path: '/report-inventory',
            builder: (context, state) => const InventoryAnalysisPage(),
          ),
        ]),
    GoRoute(
        path: '/add-supplier',
        builder: (context, state) => const AddSupplierPage()),
    GoRoute(
      path: '/edit-vendor/:id',
      builder: (context, state) =>
          EditSupplierPage(supplierId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/stock_movements',
      name: 'stock_movements',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const StockMovementsPage()),
    ),
    GoRoute(
      path: '/inventory-query',
      name: 'inventory-query',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const InventoryQueryPage()),
    ),
    GoRoute(
      path: '/manufacturing_orders',
      name: 'manufacturing_orders',
      pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey, child: const ManufacturingOrdersScreen()),
    ),
    GoRoute(
      path: '/finished_products',
      name: 'finished_products',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const FinishedProductsPage()),
    ),
    GoRoute(
        path: '/purchase-orders',
        builder: (context, state) => const PurchaseOrdersPage()),
    GoRoute(
      path: '/purchase/:id',
      name: 'purchase',
      builder: (context, state) {
        if (state.extra is PurchaseOrder) {
          final order = state.extra as PurchaseOrder;
          return order.status == 'pending'
              ? EditPurchaseOrderPage(order: order)
              : PurchaseOrderDetailsPage(order: order);
        } else {
          final id = state.pathParameters['id']!;
          return FutureBuilder<PurchaseOrder?>(
            future: OrderService.getOrderById(id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data == null) {
                return const Scaffold(
                  body: Center(child: Text('Order not found')),
                );
              }
              final order = snapshot.data!;
              return order.status == 'pending'
                  ? EditPurchaseOrderPage(order: order)
                  : PurchaseOrderDetailsPage(order: order);
            },
          );
        }
      },
    ),
    GoRoute(
      path: '/add-purchase-order',
      builder: (context, state) {
        final selectedCompany =
            state.uri.queryParameters['selectedCompany'] ?? '';
        return AddPurchaseOrderPage(selectedCompany: selectedCompany);
      },
    ),
    GoRoute(path: '/items', builder: (context, state) => const ItemsPage()),
    GoRoute(
        path: '/items/add', builder: (context, state) => const AddItemPage()),
    GoRoute(
      path: '/edit-item/:id',
      builder: (context, state) =>
          EditItemPage(itemId: state.pathParameters['id']!),
    ),
    GoRoute(
        path: '/factories', builder: (context, state) => const FactoriesPage()),
    GoRoute(
        path: '/add-factory',
        builder: (context, state) => const AddFactoryPage()),
    GoRoute(
      path: '/edit-factory/:id',
      builder: (context, state) =>
          EditFactoryPage(factoryId: state.pathParameters['id']!),
    ),
    GoRoute(
        path: '/device-registration',
        builder: (context, state) => const DeviceRegistrationHandler()),
    GoRoute(
      path: '/device-management',
      builder: (context, state) {
        final licenseId = state.extra as String?;
        return DeviceManagementPage(licenseId: licenseId);
      },
    ),
    GoRoute(
        path: '/device-request',
        builder: (context, state) => const DeviceRequestPage()),
    GoRoute(
        path: '/license/request',
        builder: (context, state) => const UserLicenseRequestPage()),
    GoRoute(
        path: '/admin/licenses',
        builder: (context, state) => const AdminLicenseManagementPage()),
    GoRoute(
      path: '/additional-items',
      builder: (context, state) => const AdditionalItemsPage(),
    ),
    GoRoute(
      path: '/user-terms',
      builder: (context, state) => const UserTermsManagementPage(),
    ),
  ],
); */

// router.dart - النسخة الكاملة المعدلة

import 'dart:convert';
import 'package:puresip_purchasing/pages/admin/force_update_all_stats.dart';
import 'package:puresip_purchasing/pages/admin/update_all_users_stats_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/pages/auth/login_page.dart';
import 'package:puresip_purchasing/pages/auth/signup_page.dart';
import 'package:puresip_purchasing/pages/companies/add_company_page.dart';
import 'package:puresip_purchasing/pages/companies/companies_page.dart';
import 'package:puresip_purchasing/pages/companies/company_added_page.dart';
import 'package:puresip_purchasing/pages/companies/edit_company_page.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_page.dart';
import 'package:puresip_purchasing/pages/dashboard/splash_screen.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_managment_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_registrations_handler.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_device_request_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_license_request.dart';
import 'package:puresip_purchasing/pages/factories/add_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/edit_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/factories_page.dart';
import 'package:puresip_purchasing/pages/finished_products/finished_products_page.dart';
import 'package:puresip_purchasing/pages/inventory/inventory_query_page.dart';
import 'package:puresip_purchasing/pages/items/add_item_page.dart';
import 'package:puresip_purchasing/pages/items/edit_item_page.dart';
import 'package:puresip_purchasing/pages/items/items_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/manufacturing_orders_screen.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/add_purchase_order_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/edit_puchase_order_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/purchase_order_details_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/purchase_orders_page.dart';
import 'package:puresip_purchasing/pages/purchasing/purchase_orders_analysis/pages/purchase_orders_analysis_page.dart';
import 'package:puresip_purchasing/pages/reports/abc_analysis_report.dart';
import 'package:puresip_purchasing/pages/reports/advanced_stock_movements_report.dart';
import 'package:puresip_purchasing/pages/reports/consumption_report.dart';
import 'package:puresip_purchasing/pages/reports/cost_analysis_report.dart';
import 'package:puresip_purchasing/pages/reports/expiry_report.dart';
import 'package:puresip_purchasing/pages/reports/inventory_report_page.dart';
import 'package:puresip_purchasing/pages/reports/reports_page.dart';
import 'package:puresip_purchasing/pages/reports/slow_moving_report.dart';
import 'package:puresip_purchasing/pages/reports/supplier_performance_report.dart';
import 'package:puresip_purchasing/pages/settings/additional_items_page.dart';
import 'package:puresip_purchasing/pages/settings/user_terms_management_page.dart';
import 'package:puresip_purchasing/pages/settings/settings_page.dart';
import 'package:puresip_purchasing/pages/stock_movements/stock_movements_page.dart';
import 'package:puresip_purchasing/pages/suppliers/add_supplier_page.dart';
import 'package:puresip_purchasing/pages/suppliers/edit_supplier_page.dart';
import 'package:puresip_purchasing/pages/suppliers/suppliers_page.dart';
import 'package:puresip_purchasing/pages/reset_page.dart';
import 'package:puresip_purchasing/services/auto_license_service.dart';
import 'package:puresip_purchasing/services/device_fingerprint.dart';
import 'package:puresip_purchasing/services/order_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/sync_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/widgets/auth/admin_license_management.dart';
import 'package:puresip_purchasing/widgets/keep_alive_wrapper.dart';

// 🌐 مفتاح التنقل العام
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// أنشئ instance للخدمة
final AutoLicenseService _autoLicenseService = AutoLicenseService();
final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

// 🔁 قائمة المسارات المستثناة من التحقق الكامل
const List<String> licenseExemptPaths = [
  '/license/request',
  '/logout',
  '/device-management',
  '/device-registration',
  '/device-request',
  '/reset'
];

// ✅ الكلاس المسؤول عن حالة الترخيص والتحقق من البصمة
class LicenseStatusWithFingerprint {
  final bool isValid;
  final bool isOffline;
  final DateTime? expiryDate;
  final int daysLeft;
  final int maxDevices;
  final int usedDevices;
  final String? reason;
  final bool deviceLimitExceeded;
  final String? licenseKey;
  final bool hasValidLicense;
  final bool deviceFingerprintValid;

  LicenseStatusWithFingerprint({
    required this.isValid,
    required this.isOffline,
    this.expiryDate,
    required this.daysLeft,
    required this.maxDevices,
    required this.usedDevices,
    this.reason,
    required this.deviceLimitExceeded,
    this.licenseKey,
    required this.hasValidLicense,
    required this.deviceFingerprintValid,
  });
}

// ==================== دوال التخزين المحسن ====================

/// ✅ التحقق من وجود ترخيص للمستخدم وإنشاء ترخيص تلقائي إذا لزم الأمر
/*   Future<void> _ensureUserHasLicense(String userId) async {
    try {
      final existingLicenseKey = await _secureStorage.read(key: 'licenseKey');
      
      if (existingLicenseKey != null && existingLicenseKey.isNotEmpty) {
        final licenseDoc = await FirebaseFirestore.instance
            .collection('licenses')
            .doc(existingLicenseKey)
            .get();
        
        if (licenseDoc.exists) {
          final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
          final isActive = licenseDoc.get('isActive') ?? false;
          
          if (isActive && expiry != null && expiry.isAfter(DateTime.now())) {
            safeDebugPrint('✅ User already has valid license: $existingLicenseKey');
            return;
          }
        }
      }
      
      safeDebugPrint('🔄 Creating auto-license for new user: $userId');
      final newLicenseKey = await _autoLicenseService.createAutoLicenseForNewUser(userId);
      
      if (newLicenseKey != null) {
        safeDebugPrint('✅ Auto-license created successfully: $newLicenseKey');
        await _secureStorage.write(key: 'licenseKey', value: newLicenseKey);
        await _syncLicenseData(userId);
      }
    } catch (e) {
      safeDebugPrint('❌ Error ensuring user has license: $e');
    }
  }
 */

// router.dart - تعديل دالة _ensureUserHasLicense

Future<void> _ensureUserHasLicense(String userId) async {
  try {
    // ✅ 1. التحقق: هل المستخدم Admin؟
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    final isAdmin = userDoc.data()?['isAdmin'] == true;

    if (isAdmin) {
      safeDebugPrint('👑 Admin user - no license needed');
      return;
    }

    // ✅ 2. التحقق: هل لدى المستخدم ترخيص بالفعل؟
    final existingLicenseKey = userDoc.data()?['licenseKey'] as String?;
    final hasAutoLicense = userDoc.data()?['hasAutoLicense'] == true;

    if ((existingLicenseKey != null && existingLicenseKey.isNotEmpty) ||
        hasAutoLicense) {
      safeDebugPrint('✅ User already has license: $existingLicenseKey');
      // ✅ التأكد من وجود الترخيص في SecureStorage
      if (existingLicenseKey != null) {
        await _secureStorage.write(
            key: 'licenseKey', value: existingLicenseKey);
      }
      return;
    }

    // ✅ 3. التحقق: هل الترخيص موجود في SecureStorage؟
    final storedLicenseKey = await _secureStorage.read(key: 'licenseKey');

    if (storedLicenseKey != null && storedLicenseKey.isNotEmpty) {
      // التحقق من صحة الترخيص المخزن
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(storedLicenseKey)
          .get();

      if (licenseDoc.exists) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        final isActive = licenseDoc.get('isActive') ?? false;

        if (isActive && expiry != null && expiry.isAfter(DateTime.now())) {
          safeDebugPrint('✅ User already has valid license: $storedLicenseKey');
          return;
        }
      }
    }

    // ✅ 4. إنشاء ترخيص تلقائي فقط للمستخدمين الجدد تماماً
    safeDebugPrint('🆕 New user detected - creating auto-license for: $userId');
    final newLicenseKey =
        await _autoLicenseService.createAutoLicenseForNewUser(userId);

    if (newLicenseKey != null) {
      safeDebugPrint(
          '✅ Auto-license created successfully for new user: $newLicenseKey');
      await _secureStorage.write(key: 'licenseKey', value: newLicenseKey);
      await _syncLicenseData(userId);
    } else {
      safeDebugPrint('⚠️ Failed to create auto-license for new user');
    }
  } catch (e) {
    safeDebugPrint('❌ Error ensuring user has license: $e');
  }
}

/// ✅ مزامنة بيانات المستخدم (حساسة + غير حساسة)
Future<void> _syncUserData(String userId) async {
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final prefs = await SharedPreferences.getInstance();

    // استخراج اسم المستخدم
    String userName = 'User';
    if (data['displayName'] != null &&
        data['displayName'].toString().isNotEmpty) {
      userName = data['displayName'];
    } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
      userName = data['name'];
    } else if (data['email'] != null && data['email'].toString().isNotEmpty) {
      userName = data['email'].split('@').first;
    }

    // ✅ غير حساس → SharedPreferences
    await prefs.setString('userName', userName);
    await prefs.setString('lastSync', DateTime.now().toIso8601String());

    // ✅ حساس → SecureStorage
    String? activeLicenseKey;
    try {
      final licensesSnapshot = await FirebaseFirestore.instance
          .collection('licenses')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final licenseDoc in licensesSnapshot.docs) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          activeLicenseKey = licenseDoc.id;
          safeDebugPrint('✅ Found active license: $activeLicenseKey');
          break;
        }
      }
    } catch (e) {
      safeDebugPrint('⚠️ Could not fetch active licenses: $e');
    }

    final licenseKey = activeLicenseKey ?? data['licenseKey'] as String?;
    if (licenseKey != null) {
      await _secureStorage.write(key: 'licenseKey', value: licenseKey);
    }

    final isAdmin = data['isAdmin'] ?? false;
    await _secureStorage.write(key: 'isAdmin', value: isAdmin.toString());

    safeDebugPrint(
        '[Sync] ✅ User data synced - Name: $userName, License: $licenseKey');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ User data sync failed: $e');
  }
}

/// ✅ مزامنة بيانات الترخيص (كلها حساسة → SecureStorage)
Future<void> _syncLicenseData(String userId) async {
  try {
    final currentLicenseKey = await _secureStorage.read(key: 'licenseKey');

    if (currentLicenseKey == null || currentLicenseKey.isEmpty) {
      safeDebugPrint('⚠️ No license key found');
      return;
    }

    final licenseDoc = await FirebaseFirestore.instance
        .collection('licenses')
        .doc(currentLicenseKey)
        .get();

    if (!licenseDoc.exists) {
      safeDebugPrint('⚠️ License document not found: $currentLicenseKey');
      return;
    }

    final data = licenseDoc.data()!;
    final expiry = (data['expiryDate'] as Timestamp?)?.toDate();
    final isActive = data['isActive'] ?? false;
    final devices = data['devices'] as List<dynamic>? ?? [];
    final maxDevices = data['maxDevices'] as int? ?? 1;
    final usedDevices = devices.length;

    final now = DateTime.now();
    final isValid = isActive && expiry != null && expiry.isAfter(now);

    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceFingerprintValid = devices.any((device) =>
        device is Map<String, dynamic> &&
        device['fingerprint'] == currentFingerprint);

    final statusData = {
      'isValid': isValid,
      'isActive': isActive,
      'expiryDate': expiry?.toIso8601String(),
      'daysLeft': expiry != null ? expiry.difference(now).inDays : 0,
      'maxDevices': maxDevices,
      'usedDevices': usedDevices,
      'reason': isValid ? 'Active' : 'Invalid license',
      'deviceLimitExceeded': usedDevices >= maxDevices &&
          maxDevices > 0 &&
          !deviceFingerprintValid,
      'licenseKey': currentLicenseKey,
      'deviceFingerprintValid': deviceFingerprintValid,
      'hasValidLicense': isValid && deviceFingerprintValid,
    };

    // ✅ كل هذه البيانات حساسة → تخزين في SecureStorage
    await _secureStorage.write(
        key: 'licenseStatus', value: json.encode(statusData));
    await _secureStorage.write(key: 'fingerprint', value: currentFingerprint);

    safeDebugPrint(
        '[Sync] ✅ License data synced - Valid: $isValid, FingerprintValid: $deviceFingerprintValid');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ License sync failed: $e');
  }
}

/// ✅ تنظيف بيانات الترخيص غير الصالحة
Future<void> _cleanupInvalidLicenseData() async {
  try {
    final currentLicenseKey = await _secureStorage.read(key: 'licenseKey');

    if (currentLicenseKey != null) {
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(currentLicenseKey)
          .get();

      if (licenseDoc.exists) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        final isActive = licenseDoc.get('isActive') ?? false;

        if (!isActive || (expiry != null && expiry.isBefore(DateTime.now()))) {
          safeDebugPrint(
              '🗑️ License $currentLicenseKey is invalid, clearing local data');
          await _secureStorage.delete(key: 'licenseKey');
          await _secureStorage.delete(key: 'fingerprint');
          await _secureStorage.delete(key: 'licenseStatus');
        }
      }
    }
  } catch (e) {
    safeDebugPrint('⚠️ Cleanup failed: $e');
  }
}

/// ✅ تنظيف التراخيص المنتهية والتبديل إلى ترخيص نشط
Future<void> _cleanupExpiredLicenses() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentLicenseKey = await _secureStorage.read(key: 'licenseKey');

    if (currentLicenseKey != null) {
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(currentLicenseKey)
          .get();

      if (licenseDoc.exists) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          safeDebugPrint('🗑️ Current license expired, finding active one...');
          final activeLicense = await _findActiveLicense(user.uid);
          if (activeLicense != null) {
            await _secureStorage.write(key: 'licenseKey', value: activeLicense);
            safeDebugPrint('✅ Switched to active license: $activeLicense');
          }
        }
      }
    }
  } catch (e) {
    safeDebugPrint('Error cleaning expired licenses: $e');
  }
}

/// ✅ البحث عن ترخيص نشط للمستخدم
Future<String?> _findActiveLicense(String userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('licenses')
      .where('userId', isEqualTo: userId)
      .where('isActive', isEqualTo: true)
      .get();

  for (final doc in snapshot.docs) {
    final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
    if (expiry != null && expiry.isAfter(DateTime.now())) {
      return doc.id;
    }
  }
  return null;
}

/// ✅ الحصول على حالة الترخيص مع التحقق من البصمة
Future<LicenseStatusWithFingerprint> _getLicenseStatusWithFingerprintCheck(
    String licenseKey) async {
  try {
    final cachedStatusJson = await _secureStorage.read(key: 'licenseStatus');

    if (cachedStatusJson != null) {
      final cachedStatus =
          json.decode(cachedStatusJson) as Map<String, dynamic>;

      bool isValid = cachedStatus['isValid'] ?? false;
      final deviceFingerprintValid =
          cachedStatus['deviceFingerprintValid'] ?? false;
      final expiryDateStr = cachedStatus['expiryDate'];
      final expiryDate =
          expiryDateStr != null ? DateTime.parse(expiryDateStr) : null;
      final daysLeft = cachedStatus['daysLeft'] ?? 0;
      final maxDevices = cachedStatus['maxDevices'] ?? 0;
      final usedDevices = cachedStatus['usedDevices'] ?? 0;
      final deviceLimitExceeded = cachedStatus['deviceLimitExceeded'] ?? false;
      final storedLicenseKey = cachedStatus['licenseKey'] as String?;

      if (expiryDate != null) {
        isValid = expiryDate.isAfter(DateTime.now());
      }

      return LicenseStatusWithFingerprint(
        isValid: isValid,
        isOffline: false,
        expiryDate: expiryDate,
        daysLeft: daysLeft,
        maxDevices: maxDevices,
        usedDevices: usedDevices,
        reason: isValid ? 'Active' : (cachedStatus['reason'] ?? 'Invalid'),
        deviceLimitExceeded: deviceLimitExceeded,
        licenseKey: storedLicenseKey ?? licenseKey,
        hasValidLicense: isValid && deviceFingerprintValid,
        deviceFingerprintValid: deviceFingerprintValid,
      );
    }

    return LicenseStatusWithFingerprint(
      isValid: false,
      isOffline: false,
      daysLeft: 0,
      maxDevices: 0,
      usedDevices: 0,
      deviceLimitExceeded: false,
      hasValidLicense: false,
      deviceFingerprintValid: false,
    );
  } catch (e) {
    safeDebugPrint('Error in _getLicenseStatusWithFingerprintCheck: $e');
    return LicenseStatusWithFingerprint(
      isValid: false,
      isOffline: false,
      daysLeft: 0,
      maxDevices: 0,
      usedDevices: 0,
      deviceLimitExceeded: false,
      hasValidLicense: false,
      deviceFingerprintValid: false,
    );
  }
}

/// ✅ التحقق من تسجيل الجهاز الحالي
Future<bool> _isCurrentDeviceRegistered(
    String licenseKey, String fingerprint) async {
  try {
    final licenseDoc = await FirebaseFirestore.instance
        .collection('licenses')
        .doc(licenseKey)
        .get();

    if (!licenseDoc.exists) return false;

    final devices = licenseDoc.data()?['devices'] as List<dynamic>? ?? [];
    return devices.any((device) =>
        device is Map<String, dynamic> && device['fingerprint'] == fingerprint);
  } catch (e) {
    safeDebugPrint('Error checking current device registration: $e');
    return false;
  }
}

/// 📬 التحقق من وجود طلبات ترخيص للمستخدم الحالي
Future<bool> _hasUserLicenseRequest() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final snapshot = await FirebaseFirestore.instance
      .collection('license_requests')
      .where('userId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'pending')
      .get();

  return snapshot.docs.isNotEmpty;
}

/// 📬 التحقق من وجود طلبات ترخيص عالقة للمشرف
Future<bool> _hasLicenseRequests() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('license_requests')
      .where('status', isEqualTo: 'pending')
      .get();

  return snapshot.docs.isNotEmpty;
}

// 🚦 الدالة الرئيسية لإعادة التوجيه
Future<String?> _appRedirectLogic(
    BuildContext context, GoRouterState state) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentPath = state.matchedLocation;

  if (currentPath == '/splash') return null;
  if (currentPath == '/reset') return null; // ✅ السماح بفتح صفحة الإعادة

  if (user == null) {
    return ['/login', '/signup'].contains(currentPath) ? null : '/login';
  }

  await _ensureUserHasLicense(user.uid);

  try {
    await _cleanupExpiredLicenses();
    await _cleanupInvalidLicenseData();
    await _syncUserData(user.uid);
    await _syncLicenseData(user.uid);

    final syncService = SyncService();
    await syncService.syncAllInBackground(force: true);

    // ✅ قراءة البيانات من SecureStorage (حساسة)
    final isAdminStr = await _secureStorage.read(key: 'isAdmin');
    final isAdmin = isAdminStr == 'true';
    final licenseKey = await _secureStorage.read(key: 'licenseKey');

    // ==================== معالج المسؤول ====================
    if (isAdmin) {
      final hasPendingRequests = await _hasLicenseRequests();
      if (currentPath == '/license/request') {
        return hasPendingRequests ? '/admin/licenses' : '/dashboard';
      }
      return null;
    }

    // ==================== معالج المستخدم العادي ====================

    final hasUserPendingRequest = await _hasUserLicenseRequest();
    if (hasUserPendingRequest && currentPath != '/license/request') {
      safeDebugPrint(
          '📋 Redirecting to /license/request - Pending request exists');
      return '/license/request';
    }

    final licenseStatus =
        await _getLicenseStatusWithFingerprintCheck(licenseKey ?? '');

    safeDebugPrint('''
    🔍 Detailed License Check:
    - User ID: ${user.uid}
    - Is Admin: $isAdmin
    - Has Pending Request: $hasUserPendingRequest
    - Path: $currentPath
    - License Valid: ${licenseStatus.isValid}
    - Fingerprint Valid: ${licenseStatus.deviceFingerprintValid}
    - Device Limit: ${licenseStatus.deviceLimitExceeded}
    - Days Left: ${licenseStatus.daysLeft}
    ''');

    // ==================== المنطق المتسلسل للتوجيه ====================

    // 1. إذا كان هناك طلب ترخيص معلق
    if (hasUserPendingRequest && currentPath != '/license/request') {
      return '/license/request';
    }

    // 2. إذا كانت الرخصة غير صالحة
    if (!licenseStatus.isValid && licenseKey == null) {
      safeDebugPrint('🚫 Redirecting to /license/request - No valid license');
      return '/license/request';
    }

    // 3. التحقق من البصمة
    if (licenseStatus.isValid && !licenseStatus.deviceFingerprintValid) {
      if (licenseKey != null) {
        final subscriptionService = UserSubscriptionService();
        final canChangeDevice =
            await subscriptionService.canChangeDevice(licenseKey);

        if (canChangeDevice) {
          if (!['/device-management', '/device-change'].contains(currentPath)) {
            safeDebugPrint(
                '🔄 Can change device - redirecting to device management');
            return '/device-management';
          }
          return null;
        }

        final registered =
            await subscriptionService.registerDeviceFingerprint(licenseKey);

        if (registered) {
          safeDebugPrint('✅ Device automatically registered!');
          if (currentPath == '/device-management' ||
              currentPath == '/device-registration') {
            return '/dashboard';
          }
          return null;
        }
      }

      if (![
        '/device-management',
        '/device-registration',
        '/device-request',
        '/device-change'
      ].contains(currentPath)) {
        safeDebugPrint(
            '📱 Redirecting to /device-management - Invalid fingerprint');
        return '/device-management';
      }
      return null;
    }

    // 4. التحقق من الجهاز الحالي
    if (licenseStatus.licenseKey != null) {
      final currentFingerprint = await DeviceFingerprint.generate();
      final isCurrentDeviceRegistered = await _isCurrentDeviceRegistered(
          licenseStatus.licenseKey!, currentFingerprint);

      if (!isCurrentDeviceRegistered) {
        final subscriptionService = UserSubscriptionService();
        final canChangeDevice = await subscriptionService
            .canChangeDevice(licenseStatus.licenseKey!);

        if (canChangeDevice) {
          if (currentPath != '/device-management') {
            safeDebugPrint(
                '🔄 Device not registered but can change - redirecting to device management');
            return '/device-management';
          }
          return null;
        }

        if (licenseStatus.deviceLimitExceeded) {
          if (currentPath != '/license/request' &&
              currentPath != '/device-management') {
            safeDebugPrint(
                '⚠️ Device limit exceeded - redirecting to license request');
            return '/license/request';
          }
          return null;
        }

        if (currentPath != '/license/request' &&
            currentPath != '/device-management') {
          safeDebugPrint(
              '⚠️ Device not registered - redirecting to license request');
          return '/license/request';
        }
        return null;
      }

      if (currentPath == '/device-management' ||
          currentPath == '/device-registration') {
        safeDebugPrint('✅ Device is registered, navigating to dashboard');
        return '/dashboard';
      }
    }

    // 5. إذا كانت الرخصة والبصمة صالحتين
    if (licenseStatus.isValid && licenseStatus.deviceFingerprintValid) {
      if (licenseStatus.expiryDate != null &&
          licenseStatus.expiryDate!.isBefore(DateTime.now())) {
        safeDebugPrint('⚠️ License expired - redirecting to license request');
        return '/license/request';
      }

      if ([
        '/license/request',
        '/device-management',
        '/device-registration',
        '/device-request'
      ].contains(currentPath)) {
        safeDebugPrint(
            '✅ Redirecting to /dashboard - Valid license and fingerprint');
        return '/dashboard';
      }
      return null;
    }

    // 6. الحالات الأخرى
    if (!licenseExemptPaths.contains(currentPath)) {
      safeDebugPrint('🔁 Redirecting to /license/request - Fallback case');
      return '/license/request';
    }

    return null;
  } catch (e) {
    safeDebugPrint('❌ Router Error: $e');
    if (currentPath == '/dashboard') return null;
    return '/dashboard';
  }
}

// 🧭 تكوين المسارات - نسخة محسنة مع KeepAliveWrapper
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  redirect: _appRedirectLogic,
  routes: [
    // ==================== المسارات الأساسية ====================
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const SplashScreen()),
    ),
    GoRoute(
      path: '/reset',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const ResetPage()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const LoginPage()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const SignupPage()),
    ),

    // ==================== Dashboard ====================
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const DashboardPage()),
    ),

    // ==================== الشركات ====================
    GoRoute(
      path: '/companies',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: CompaniesPage()),
      ),
    ),
    GoRoute(
      path: '/add-company',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const AddCompanyPage()),
    ),
    GoRoute(
      path: '/edit-company/:id',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: EditCompanyPage(companyId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/company-added/:id',
      pageBuilder: (context, state) {
        final docId = state.pathParameters['id']!;
        final nameEn = state.uri.queryParameters['nameEn'] ?? '';
        return MaterialPage(
          key: state.pageKey,
          child: CompanyAddedPage(nameEn: nameEn, docId: docId),
        );
      },
    ),

    // ==================== الموردين ====================
    GoRoute(
      path: '/suppliers',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: SuppliersPage()),
      ),
    ),
    GoRoute(
      path: '/add-supplier',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const AddSupplierPage()),
    ),
    GoRoute(
      path: '/edit-vendor/:id',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: EditSupplierPage(supplierId: state.pathParameters['id']!),
      ),
    ),

    // ==================== المنتجات ====================
    GoRoute(
      path: '/items',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: ItemsPage()),
      ),
    ),
    GoRoute(
      path: '/items/add',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const AddItemPage()),
    ),
    GoRoute(
      path: '/edit-item/:id',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: EditItemPage(itemId: state.pathParameters['id']!),
      ),
    ),

    // ==================== المصانع ====================
    GoRoute(
      path: '/factories',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: FactoriesPage()),
      ),
    ),
    GoRoute(
      path: '/add-factory',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const AddFactoryPage()),
    ),
    GoRoute(
      path: '/edit-factory/:id',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: EditFactoryPage(factoryId: state.pathParameters['id']!),
      ),
    ),

    // ==================== أوامر الشراء ====================
    GoRoute(
      path: '/purchase-orders',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: PurchaseOrdersPage()),
      ),
    ),
    GoRoute(
      path: '/add-purchase-order',
      pageBuilder: (context, state) {
        final selectedCompany =
            state.uri.queryParameters['selectedCompany'] ?? '';
        return MaterialPage(
          key: state.pageKey,
          child: AddPurchaseOrderPage(selectedCompany: selectedCompany),
        );
      },
    ),
    GoRoute(
      path: '/purchase/:id',
      name: 'purchase',
      pageBuilder: (context, state) {
        if (state.extra is PurchaseOrder) {
          final order = state.extra as PurchaseOrder;
          return MaterialPage(
            key: state.pageKey,
            child: order.status == 'pending'
                ? EditPurchaseOrderPage(order: order)
                : PurchaseOrderDetailsPage(order: order),
          );
        } else {
          final id = state.pathParameters['id']!;
          return MaterialPage(
            key: state.pageKey,
            child: FutureBuilder<PurchaseOrder?>(
              future: OrderService.getOrderById(id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data == null) {
                  return const Scaffold(
                    body: Center(child: Text('Order not found')),
                  );
                }
                final order = snapshot.data!;
                return order.status == 'pending'
                    ? EditPurchaseOrderPage(order: order)
                    : PurchaseOrderDetailsPage(order: order);
              },
            ),
          );
        }
      },
    ),

    // ==================== حركات المخزون ====================
    GoRoute(
      path: '/stock_movements',
      name: 'stock_movements',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: StockMovementsPage()),
      ),
    ),
    GoRoute(
      path: '/inventory-query',
      name: 'inventory-query',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: InventoryQueryPage()),
      ),
    ),

    // ==================== أوامر التصنيع ====================
    GoRoute(
      path: '/manufacturing_orders',
      name: 'manufacturing_orders',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: ManufacturingOrdersScreen()),
      ),
    ),
    GoRoute(
      path: '/finished_products',
      name: 'finished_products',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: FinishedProductsPage()),
      ),
    ),

    // ==================== التقارير ====================
    GoRoute(
      path: '/reports',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: ReportsPage()),
      ),
      routes: [
        GoRoute(
          path: '/advanced-movements',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const AdvancedStockMovementsReport(),
          ),
        ),
        GoRoute(
          path: '/slow-moving',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const SlowMovingReport(),
          ),
        ),
        GoRoute(
          path: '/expiry',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const ExpiryReport(),
          ),
        ),
        GoRoute(
          path: '/supplier-performance',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const SupplierPerformanceReport(),
          ),
        ),
        GoRoute(
          path: '/abc-analysis',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const AbcAnalysisReport(),
          ),
        ),
        GoRoute(
          path: '/consumption',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const ConsumptionReport(),
          ),
        ),
        GoRoute(
          path: '/cost-analysis',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const CostAnalysisReport(),
          ),
        ),
        GoRoute(
          path: '/purchase-orders-analysis',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const PurchaseOrdersAnalysisPage(),
          ),
        ),
        GoRoute(
          path: '/report-inventory',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const InventoryAnalysisPage(),
          ),
        ),
      ],
    ),

    // ==================== الإعدادات ====================
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) {
        final allCards = state.extra as List<String>? ?? [];
        return MaterialPage(
          key: state.pageKey,
          child: SettingsPage(allCards: allCards),
        );
      },
    ),
    GoRoute(
      path: '/additional-items',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const AdditionalItemsPage()),
    ),
    GoRoute(
      path: '/user-terms',
      pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey, child: const UserTermsManagementPage()),
    ),

    // ==================== الأجهزة والتراخيص ====================
    GoRoute(
      path: '/device-registration',
      pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey, child: const DeviceRegistrationHandler()),
    ),
    GoRoute(
      path: '/device-management',
      pageBuilder: (context, state) {
        final licenseId = state.extra as String?;
        return MaterialPage(
          key: state.pageKey,
          child: DeviceManagementPage(licenseId: licenseId),
        );
      },
    ),
    GoRoute(
      path: '/device-request',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const DeviceRequestPage()),
    ),
    GoRoute(
      path: '/license/request',
      pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey, child: const UserLicenseRequestPage()),
    ),
    GoRoute(
      path: '/admin/licenses',
      pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey, child: const AdminLicenseManagementPage()),
    ),
    GoRoute(
      path: '/admin/update-all-stats',
      builder: (context, state) => const UpdateAllUsersStatsPage(),
    ),

// أضف هذا المسار
    GoRoute(
      path: '/admin/force-update',
      builder: (context, state) => const ForceUpdateAllStats(),
    ),
  ],
);
 */