import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
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
import 'package:puresip_purchasing/pages/hive_settings_page.dart';
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
import 'package:puresip_purchasing/pages/reports/inventory_report_page.dart';
import 'package:puresip_purchasing/pages/reports/reports_page.dart';
import 'package:puresip_purchasing/pages/settings_page.dart';
import 'package:puresip_purchasing/pages/stock_movements/stock_movements_page.dart';
import 'package:puresip_purchasing/pages/suppliers/add_supplier_page.dart';
import 'package:puresip_purchasing/pages/suppliers/edit_supplier_page.dart';
import 'package:puresip_purchasing/pages/suppliers/suppliers_page.dart';
import 'package:puresip_purchasing/services/device_fingerprint.dart';
//import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/order_service.dart';
//import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/widgets/auth/admin_license_management.dart';

// 🌐 مفتاح التنقل العام
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🔐 خدمة الترخيص
// final _licenseService = LicenseService();

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

// 🚦 الدالة الرئيسية لإعادة التوجيه
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
        path: '/hive-settings',
        builder: (context, state) => const HiveSettingsPage()),
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
          return FutureBuilder<PurchaseOrder>(
            future: OrderService.getOrderById(id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Text('Order not found'));
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
  ], // 🧭 جميع المسارات موجودة كما هي دون تغيير
);

/* // دالة مساعدة للتحقق من التسجيل من Hive مباشرة
Future<bool> _isDeviceRegisteredLocally(String licenseKey) async {
  try {
    final userBox = await Hive.openBox('userBox');
    final cachedFingerprint = userBox.get('deviceFingerprint') as String?;
    if (cachedFingerprint == null) return false;

    // محاولة قراءة الأجهزة المخزنة محلياً (من Hive) - تأكد من اسم الـ Box
    final deviceBox = await Hive.openBox('devicesBox');
    final devices = deviceBox.get(licenseKey, defaultValue: <Map>[]) as List;
    
    // ابحث عن بصمة مطابقة في القائمة المحلية
    return devices.any((device) => device['fingerprint'] == cachedFingerprint);
  } catch (e) {
    safeDebugPrint('Local registration check failed: $e');
    return false;
  }
}
 */

// 🔄 دالة إعادة التوجيه الرئيسية - معدلة لفتح إدارة الأجهزة
Future<String?> _appRedirectLogic(
    BuildContext context, GoRouterState state) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentPath = state.matchedLocation;

  if (currentPath == '/splash') return null;

  if (user == null) {
    return ['/login', '/signup'].contains(currentPath) ? null : '/login';
  }

  try {
    // ✅ تنظيف التراخيص المنتهية
await _cleanupExpiredLicenses();
    // ✅ تنظيف البيانات غير الصالحة أولاً
    await _cleanupInvalidLicenseData();

    // ✅ ثم مزامنة البيانات
    await _syncUserData(user.uid);
    await _syncLicenseData(user.uid);

    final userBox = await Hive.openBox('userBox');
    final isAdmin = userBox.get('isAdmin', defaultValue: false);

    if (isAdmin) {
      final hasPendingRequests = await _hasLicenseRequests();
      if (currentPath == '/license/request') {
        return hasPendingRequests ? '/admin/licenses' : '/dashboard';
      }
      return null;
    }

    final hasUserPendingRequest = await _hasUserLicenseRequest();
    if (hasUserPendingRequest && currentPath != '/license/request') {
      return '/license/request';
    }

    final licenseKeyFromHive = userBox.get('licenseKey') as String?;
    final licenseStatus =
        await _getLicenseStatusWithFingerprintCheck(licenseKeyFromHive ?? '');

    safeDebugPrint('''
    🔍 Detailed License Check:
    - User ID: ${user.uid}
    - License Key from Hive: $licenseKeyFromHive
    - Has Pending Request: $hasUserPendingRequest
    - Path: $currentPath
    - License Valid: ${licenseStatus.isValid}
    - Fingerprint Valid: ${licenseStatus.deviceFingerprintValid}
    - Device Limit: ${licenseStatus.deviceLimitExceeded}
    - License Key: ${licenseStatus.licenseKey}
    ''');

    // 🎯 التسلسل المنطقي المصحح للتوجيه:

    // 1. إذا كان هناك طلب ترخيص معلق
    if (hasUserPendingRequest && currentPath != '/license/request') {
      safeDebugPrint(
          '📋 Redirecting to /license/request - Pending request exists');
      return '/license/request';
    }

    // 2. إذا كانت الرخصة غير صالحة تماماً ولا يوجد مفتاح
    if (!licenseStatus.isValid && licenseKeyFromHive == null) {
      safeDebugPrint('🚫 Redirecting to /license/request - No license key');
      return '/license/request';
    }

// 3. التحقق من البصمة
    if (licenseStatus.isValid && !licenseStatus.deviceFingerprintValid) {
      // ✅ محاولة التسجيل التلقائي للجهاز إذا كانت هناك مساحة
      if (licenseKeyFromHive != null) {
        final subscriptionService = UserSubscriptionService();
        final registered = await subscriptionService
            .registerDeviceFingerprint(licenseKeyFromHive);

        if (registered) {
          safeDebugPrint(
              '✅ Device automatically registered! Navigating to dashboard.');
          // تحديث الحالة المحلية
          final authBox = await Hive.openBox('authbox');
          final currentStatus = Map<String, dynamic>.from(
              authBox.get('licenseStatus', defaultValue: {}));
          currentStatus['deviceFingerprintValid'] = true;
          await authBox.put('licenseStatus', currentStatus);

          if (currentPath == '/device-management' ||
              currentPath == '/device-registration') {
            return '/dashboard';
          }
          return null;
        }
      }

      // إذا فشل التسجيل التلقائي، اذهب لإدارة الأجهزة
      if (!['/device-management', '/device-registration', '/device-request']
          .contains(currentPath)) {
        safeDebugPrint(
            '📱 Redirecting to /device-management - Valid license but invalid fingerprint');
        return '/device-management';
      }
      return null;
    }

/* // 3. إذا كانت الرخصة صالحة لكن البصمة غير صالحة - ✅ الحل السريع
if (licenseStatus.isValid && !licenseStatus.deviceFingerprintValid) {
  // تحقق إضافي: هل الجهاز مسجل محلياً بالفعل؟
  final isRegisteredLocally = await _isDeviceRegisteredLocally(licenseKeyFromHive ?? '');
  
  if (isRegisteredLocally) {
    // إذا كان مسجلاً محلياً، فتجاهل فشل البصمة واعتبره صالحاً
    safeDebugPrint('✅ Local registration found. Overriding fingerprint check. Navigating to dashboard.');
    // قم بتحديث الحالة في الـ authBox لمنع تكرار المشكلة
    final authBox = await Hive.openBox('authbox');
    final currentStatus = Map<String, dynamic>.from(authBox.get('licenseStatus', defaultValue: {}));
    currentStatus['deviceFingerprintValid'] = true;
    await authBox.put('licenseStatus', currentStatus);
    
    // انتقل إلى لوحة التحكم
    if (currentPath == '/device-management' || currentPath == '/device-registration') {
      return '/dashboard';
    }
    return null;
  }
  
  // إذا لم يكن مسجلاً محلياً، اذهب لإدارة الأجهزة كما هو الحال الآن
  if (!['/device-management', '/device-registration', '/device-request'].contains(currentPath)) {
    safeDebugPrint('📱 Redirecting to /device-management - Valid license but invalid fingerprint');
    return '/device-management';
  }
  return null;
} */

    // 4. إذا تم تجاوز حد الأجهزة
/*     if (licenseStatus.deviceLimitExceeded && licenseStatus.licenseKey != null) {
      if (!['/device-management', '/device-request'].contains(currentPath)) {
        safeDebugPrint(
            '⚠️ Redirecting to /device-management - Device limit exceeded');
        return '/device-management';
      }
      return null;
    } */
// 4. إذا تم تجاوز حد الأجهزة (مع استثناء الجهاز الحالي)
if (licenseStatus.deviceLimitExceeded && licenseStatus.licenseKey != null) {
  // ✅ تحقق: هل الجهاز الحالي هو أحد الأجهزة المسجلة؟
  final currentFingerprint = await DeviceFingerprint.generate();
  final isCurrentDeviceRegistered = await _isCurrentDeviceRegistered(licenseStatus.licenseKey!, currentFingerprint);
  
  if (!isCurrentDeviceRegistered) {
    // فقط إذا كان الجهاز الحالي غير مسجل ونحن تجاوزنا الحد
    if (!['/device-management', '/device-request'].contains(currentPath)) {
      safeDebugPrint('⚠️ Redirecting to /device-management - Device limit exceeded and current device not registered');
      return '/device-management';
    }
    return null;
  } else {
    // الجهاز الحالي مسجل، تجاهل حد الأجهزة
    safeDebugPrint('✅ Current device is registered, ignoring device limit');
  }
}
    // 5. إذا كانت الرخصة والبصمة صالحتين
    if (licenseStatus.isValid && licenseStatus.deviceFingerprintValid) {
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

    // 6. الحالات الأخرى - العودة إلى طلب الترخيص
    if (!licenseExemptPaths.contains(currentPath)) {
      safeDebugPrint('🔁 Redirecting to /license/request - Fallback case');
      return '/license/request';
    }

    return null;
  } catch (e) {
    safeDebugPrint('Router Error: $e');
    return '/login';
  }
}

Future<bool> _isCurrentDeviceRegistered(String licenseKey, String fingerprint) async {
  try {
    final licenseDoc = await FirebaseFirestore.instance
        .collection('licenses')
        .doc(licenseKey)
        .get();
    
    if (!licenseDoc.exists) return false;
    
    final devices = licenseDoc.data()?['devices'] as List<dynamic>? ?? [];
    return devices.any((device) =>
        device is Map<String, dynamic> &&
        device['fingerprint'] == fingerprint);
  } catch (e) {
    safeDebugPrint('Error checking current device registration: $e');
    return false;
  }
}

// 📦 مزامنة بيانات المستخدم من Firestore إلى Hive
/* Future<void> _syncUserData(String userId) async {
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final userBox = await Hive.openBox('userBox');
    final authBox = await Hive.openBox('authbox');

    // ✅ تعريف licenseKey مرة واحدة فقط
    final licenseKey = data['licenseKey'] as String?;
    final licenseExpiry = (data['license_expiry'] as Timestamp?)?.toDate();
    final isActive = data['isActive'] as bool? ?? false;
    final maxDevices = data['maxDevices'] as int? ?? 0;
    final deviceIds = data['deviceIds'] as List<dynamic>? ?? [];

    final now = DateTime.now();
    final isValid =
        isActive && licenseExpiry != null && licenseExpiry.isAfter(now);

    // ✅ حفظ بيانات المستخدم في userBox
    await userBox.putAll({
      'name': data['name'],
      'email': data['email'],
      'isAdmin': data['isAdmin'] ?? false,
      'licenseKey': licenseKey,
      'lastSync': DateTime.now().toIso8601String(),
    });

    // ✅ حفظ حالة الترخيص في authbox
    await authBox.put('licenseStatus', {
      'isValid': isValid,
      'licenseKey': licenseKey,
      'expiryDate': licenseExpiry?.toIso8601String(),
      'maxDevices': maxDevices,
      'usedDevices': deviceIds.length,
      'daysLeft': isValid ? licenseExpiry.difference(now).inDays : 0,
      'reason': isValid ? 'Active' : 'Expired',
      'lastUpdated': now.toIso8601String(),
    });

    safeDebugPrint('[Sync] ✅ User data synced');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ User data sync failed: $e');
  }
}
 */
/* Future<void> _syncUserData(String userId) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final userBox = await Hive.openBox('userBox');
    //final authBox = await Hive.openBox('authbox');

    // ✅ الحصول على الترخيص النشط من Firestore
    final licensesSnapshot = await FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();
    
    String? activeLicenseKey;
    for (final licenseDoc in licensesSnapshot.docs) {
      final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
      if (expiry != null && expiry.isAfter(DateTime.now())) {
        activeLicenseKey = licenseDoc.id;
        break;
      }
    }
    
    // ✅ استخدام الترخيص النشط إذا وجد
    final licenseKey = activeLicenseKey ?? data['licenseKey'] as String?;
    
    // ✅ حفظ مفتاح الترخيص الصحيح
    await userBox.put('licenseKey', licenseKey);
    
    // باقي الكود كما هو...
    await userBox.putAll({
      'name': data['name'],
      'email': data['email'],
      'isAdmin': data['isAdmin'] ?? false,
      'lastSync': DateTime.now().toIso8601String(),
    });

    safeDebugPrint('[Sync] ✅ User data synced with license: $licenseKey');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ User data sync failed: $e');
  }
}
 */

/* Future<void> _syncUserData(String userId) async {
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final userBox = await Hive.openBox('userBox');

    // ✅ الحصول على الترخيص النشط من مجموعة licenses
    String? activeLicenseKey;
    try {
      final licensesSnapshot = await FirebaseFirestore.instance
          .collection('licenses')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      // البحث عن ترخيص غير منتهي الصلاحية
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

    // ✅ استخدام الترخيص النشط إذا وجد، وإلا استخدم الترخيص من user document
    final licenseKey = activeLicenseKey ?? data['licenseKey'] as String?;

    // ✅ حفظ البيانات مع الترخيص الصحيح
    await userBox.putAll({
      'name': data['name'],
      'email': data['email'],
      'isAdmin': data['isAdmin'] ?? false,
      'licenseKey': licenseKey, // ✅ الآن الترخيص الصحيح
      'lastSync': DateTime.now().toIso8601String(),
    });

    safeDebugPrint('[Sync] ✅ User data synced with license: $licenseKey');

    // ✅ إذا تغير الترخيص، قم بتنظيف البصمة القديمة
    if (activeLicenseKey != null && activeLicenseKey != data['licenseKey']) {
      safeDebugPrint(
          '🔄 License key changed from ${data['licenseKey']} to $activeLicenseKey');
      final authBox = await Hive.openBox('authbox');
      await authBox.delete('fingerprint');
    }
  } catch (e) {
    safeDebugPrint('[Sync] ❌ User data sync failed: $e');
  }
}
 */

Future<void> _syncUserData(String userId) async {
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final userBox = await Hive.openBox('userBox');

    // ✅ الحصول على اسم المستخدم من displayName أو name أو email
    String userName = 'User';
    if (data['displayName'] != null && data['displayName'].toString().isNotEmpty) {
      userName = data['displayName'];
    } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
      userName = data['name'];
    } else if (data['email'] != null && data['email'].toString().isNotEmpty) {
      userName = data['email'].split('@').first;
    }

    // ✅ الحصول على الترخيص النشط من مجموعة licenses
    String? activeLicenseKey;
    try {
      final licensesSnapshot = await FirebaseFirestore.instance
          .collection('licenses')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      // البحث عن ترخيص غير منتهي الصلاحية
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

    // ✅ استخدام الترخيص النشط إذا وجد، وإلا استخدم الترخيص من user document
    final licenseKey = activeLicenseKey ?? data['licenseKey'] as String?;

    // ✅ حفظ البيانات مع الترخيص الصحيح
    await userBox.putAll({
      'name': userName,  // ✅ الآن الاسم الصحيح
      'displayName': data['displayName'] ?? '',
      'email': data['email'] ?? '',
      'isAdmin': data['isAdmin'] ?? false,
      'licenseKey': licenseKey,
      'lastSync': DateTime.now().toIso8601String(),
    });

    safeDebugPrint('[Sync] ✅ User data synced - Name: $userName, License: $licenseKey');

    // ✅ إذا تغير الترخيص، قم بتنظيف البصمة القديمة
    if (activeLicenseKey != null && activeLicenseKey != data['licenseKey']) {
      safeDebugPrint(
          '🔄 License key changed from ${data['licenseKey']} to $activeLicenseKey');
      final authBox = await Hive.openBox('authbox');
      await authBox.delete('fingerprint');
    }
  } catch (e) {
    safeDebugPrint('[Sync] ❌ User data sync failed: $e');
  }
}


Future<void> _cleanupInvalidLicenseData() async {
  try {
    final userBox = await Hive.openBox('userBox');
    final currentLicenseKey = userBox.get('licenseKey') as String?;

    if (currentLicenseKey != null) {
      // التحقق مما إذا كان الترخيص لا يزال صالحاً
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
          await userBox.delete('licenseKey');
          final authBox = await Hive.openBox('authbox');
          await authBox.delete('fingerprint');
          await authBox.delete('licenseStatus');
        }
      }
    }
  } catch (e) {
    safeDebugPrint('⚠️ Cleanup failed: $e');
  }
}

// 🔁 مزامنة بيانات الترخيص من Firestore إلى Hive
/* Future<void> _syncLicenseData(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    final authBox = await Hive.openBox('authbox');

    DateTime? latestExpiry;
    int maxDevices = 0;
    int usedDevices = 0;
    bool isValid = false;
    String? licenseKey;

    for (final doc in snapshot.docs) {
      final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
      final isActive = doc.get('isActive') ?? false;
      final devices = doc.get('devices') as List<dynamic>? ?? [];
      licenseKey = doc.id;

      if (isActive && expiry != null && expiry.isAfter(DateTime.now())) {
        isValid = true;
        latestExpiry = expiry;
        maxDevices = doc.get('maxDevices') ?? 0;
        usedDevices = devices.length;
        break;
      }
    }

    final deviceFingerprintValid =
        await _checkDeviceFingerprint(licenseKey ?? '');

    await authBox.put('licenseStatus', {
      'isValid': isValid,
      'expiryDate': latestExpiry?.toIso8601String(),
      'daysLeft': latestExpiry != null
          ? latestExpiry.difference(DateTime.now()).inDays
          : 0,
      'maxDevices': maxDevices,
      'usedDevices': usedDevices,
      'reason': isValid ? 'Active' : 'Invalid license',
      'deviceLimitExceeded': usedDevices >= maxDevices,
      'licenseKey': licenseKey,
      'deviceFingerprintValid': deviceFingerprintValid,
      'hasValidLicense': isValid && deviceFingerprintValid,
    });

    safeDebugPrint('[Sync] ✅ License data synced');
    for (final doc in snapshot.docs) {
      debugPrint('[License] 🔍 Found license: ${doc.id}');
    }
  } catch (e) {
    safeDebugPrint('[Sync] ❌ License sync failed: $e');
  }
}
 */

/* Future<void> _syncLicenseData(String userId) async {
  try {
    final subscriptionService = UserSubscriptionService();
    final subscriptionResult = await subscriptionService.checkUserSubscription();
    
    final authBox = await Hive.openBox('authbox');
    
    // ✅ حفظ حالة الترخيص بناءً على نتيجة subscriptionResult
    await authBox.put('licenseStatus', {
      'isValid': subscriptionResult.isValid && !subscriptionResult.isExpired,
      'expiryDate': subscriptionResult.expiryDate?.toIso8601String(),
      'daysLeft': subscriptionResult.expiryDate != null
          ? subscriptionResult.expiryDate!.difference(DateTime.now()).inDays
          : 0,
      'maxDevices': 1,
      'usedDevices': 0,
      'reason': subscriptionResult.isValid ? 'Active' : 'Invalid license',
      'deviceLimitExceeded': false,
      'licenseKey': subscriptionResult.licenseId,
      'deviceFingerprintValid': subscriptionResult.isValid,
      'hasValidLicense': subscriptionResult.isValid && !subscriptionResult.isExpired,
    });

    safeDebugPrint('[Sync] ✅ License data synced');
    safeDebugPrint('[License] 🔍 License: ${subscriptionResult.licenseId}');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ License sync failed: $e');
  }
}
 */

/* Future<void> _syncLicenseData(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    final authBox = await Hive.openBox('authbox');

    // ✅ البحث عن الترخيص النشط (غير منتهي)
    DateTime? latestExpiry;
    int maxDevices = 0;
    int usedDevices = 0;
    bool isValid = false;
    String? activeLicenseKey;
    List<dynamic> devices = [];

    for (final doc in snapshot.docs) {
      final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
      final isActive = doc.get('isActive') ?? false;

      if (isActive && expiry != null && expiry.isAfter(DateTime.now())) {
        isValid = true;
        latestExpiry = expiry;
        maxDevices = doc.get('maxDevices') ?? 0;
        devices = doc.get('devices') as List<dynamic>? ?? [];
        usedDevices = devices.length;
        activeLicenseKey = doc.id;
        break; // ✅ خذ أول ترخيص نشط
      }
    }

    // ✅ تحديث userBox بالترخيص النشط
    if (activeLicenseKey != null) {
      final userBox = await Hive.openBox('userBox');
      await userBox.put('licenseKey', activeLicenseKey);
      safeDebugPrint(
          '[Sync] ✅ Updated userBox licenseKey to: $activeLicenseKey');
    }

    // ✅ التحقق من بصمة الجهاز
    bool deviceFingerprintValid = false;
    if (activeLicenseKey != null && isValid) {
      final currentFingerprint = await DeviceFingerprint.generate();
      deviceFingerprintValid = devices.any((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == currentFingerprint);
    }

    await authBox.put('licenseStatus', {
      'isValid': isValid,
      'expiryDate': latestExpiry?.toIso8601String(),
      'daysLeft': latestExpiry != null
          ? latestExpiry.difference(DateTime.now()).inDays
          : 0,
      'maxDevices': maxDevices,
      'usedDevices': usedDevices,
      'reason': isValid ? 'Active' : 'Invalid license',
      'deviceLimitExceeded': usedDevices >= maxDevices && maxDevices > 0,
      'licenseKey': activeLicenseKey,
      'deviceFingerprintValid': deviceFingerprintValid,
      'hasValidLicense': isValid && deviceFingerprintValid,
    });

    safeDebugPrint(
        '[Sync] ✅ License data synced - Active: $activeLicenseKey, Valid: $isValid');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ License sync failed: $e');
  }
}
 */

Future<void> _syncLicenseData(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    final authBox = await Hive.openBox('authbox');
    
    DateTime? latestExpiry;
    int maxDevices = 0;
    int usedDevices = 0;
    bool isValid = false;
    String? activeLicenseKey;
    List<dynamic> devices = [];

    for (final doc in snapshot.docs) {
      final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
      final isActive = doc.get('isActive') ?? false;
      
      safeDebugPrint('🔍 Checking license ${doc.id}: isActive=$isActive, expiry=$expiry');
      
      if (isActive && expiry != null && expiry.isAfter(DateTime.now())) {
        isValid = true;
        latestExpiry = expiry;
        maxDevices = doc.get('maxDevices') ?? 0;
        devices = doc.get('devices') as List<dynamic>? ?? [];
        usedDevices = devices.length;
        activeLicenseKey = doc.id;
        safeDebugPrint('✅ Found valid license: $activeLicenseKey, expires: $expiry');
        break;
      }
    }

    if (activeLicenseKey == null) {
      safeDebugPrint('⚠️ No active non-expired license found for user: $userId');
      await authBox.put('licenseStatus', {
        'isValid': false,
        'reason': 'No active license found',
        'deviceFingerprintValid': false,
        'hasValidLicense': false,
      });
      return;
    }

    // تحديث userBox بالترخيص النشط
    final userBox = await Hive.openBox('userBox');
    await userBox.put('licenseKey', activeLicenseKey);
    safeDebugPrint('[Sync] ✅ Updated userBox licenseKey to: $activeLicenseKey');
  
    // التحقق من بصمة الجهاز
    bool deviceFingerprintValid = false;
    if (isValid) {
      final currentFingerprint = await DeviceFingerprint.generate();
      deviceFingerprintValid = devices.any((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == currentFingerprint);
      safeDebugPrint('🔍 Fingerprint check: current=$currentFingerprint, valid=$deviceFingerprintValid');
      safeDebugPrint('📱 Registered devices: ${devices.length}');
      for (var device in devices) {
        safeDebugPrint('   - ${device['fingerprint']}');
      }
    }

    final statusData = {
      'isValid': isValid,
      'expiryDate': latestExpiry?.toIso8601String(),
      'daysLeft': latestExpiry != null
          ? latestExpiry.difference(DateTime.now()).inDays
          : 0,
      'maxDevices': maxDevices,
      'usedDevices': usedDevices,
      'reason': isValid ? 'Active' : 'Invalid license',
      'deviceLimitExceeded': usedDevices >= maxDevices && maxDevices > 0,
      'licenseKey': activeLicenseKey,
      'deviceFingerprintValid': deviceFingerprintValid,
      'hasValidLicense': isValid && deviceFingerprintValid,
    };
    
    await authBox.put('licenseStatus', statusData);
    safeDebugPrint('[Sync] ✅ License data synced - Active: $activeLicenseKey, Valid: $isValid, FingerprintValid: $deviceFingerprintValid');
    safeDebugPrint('[Sync] 📦 Stored status: $statusData');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ License sync failed: $e');
  }
}

Future<void> _cleanupExpiredLicenses() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final userBox = await Hive.openBox('userBox');
    final currentLicenseKey = userBox.get('licenseKey') as String?;
    
    // التحقق مما إذا كان الترخيص الحالي منتهياً
    if (currentLicenseKey != null) {
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(currentLicenseKey)
          .get();
      
      if (licenseDoc.exists) {
        final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          safeDebugPrint('🗑️ Current license expired, finding active one...');
          // البحث عن ترخيص نشط
          final activeLicense = await _findActiveLicense(user.uid);
          if (activeLicense != null) {
            await userBox.put('licenseKey', activeLicense);
            safeDebugPrint('✅ Switched to active license: $activeLicense');
          }
        }
      }
    }
  } catch (e) {
    safeDebugPrint('Error cleaning expired licenses: $e');
  }
}

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

/* // 🧠 التحقق من حالة الترخيص مع البصمة
Future<LicenseStatusWithFingerprint> _getLicenseStatusWithFingerprintCheck(
    String licenseKey) async {
  try {
    final licenseService = LicenseService();
    final basicStatus = await licenseService.checkLicenseStatus(licenseKey);

    bool deviceFingerprintValid = false;
    bool hasValidLicense = basicStatus.isValid;

    // ✅ الإصلاح: إذا كانت الرخصة صالحة ولكن البصمة غير صالحة
    if (basicStatus.isValid && licenseKey.isNotEmpty) {
      final userSubscriptionService = UserSubscriptionService();
      final subscriptionResult =
          await userSubscriptionService.checkUserSubscription();

      deviceFingerprintValid = subscriptionResult.isValid;

      // ✅ التصحيح: الرخصة صالحة لكن البصمة تحتاج تصحيح
      hasValidLicense = deviceFingerprintValid; // فقط إذا كانت البصمة صالحة
    }

    return LicenseStatusWithFingerprint(
      isValid: basicStatus.isValid,
      isOffline: basicStatus.isOffline,
      expiryDate: basicStatus.expiryDate,
      daysLeft: basicStatus.daysLeft,
      maxDevices: basicStatus.maxDevices,
      usedDevices: basicStatus.usedDevices,
      reason: basicStatus.reason,
      deviceLimitExceeded: basicStatus.deviceLimitExceeded,
      licenseKey: licenseKey,
      hasValidLicense: hasValidLicense,
      deviceFingerprintValid: deviceFingerprintValid,
    );
  } catch (e) {
    safeDebugPrint('Error checking license with fingerprint: $e');
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
} */

/* Future<LicenseStatusWithFingerprint> _getLicenseStatusWithFingerprintCheck(
    String licenseKey) async {
  try {
    final licenseService = LicenseService();
    final basicStatus = await licenseService.checkLicenseStatus(licenseKey);

    bool deviceFingerprintValid = false;
    bool hasValidLicense = basicStatus.isValid;

    // ✅ الإصلاح الجوهري: تحقق من البصمة باستخدام licenseKey الصحيحة
    if (basicStatus.isValid && licenseKey.isNotEmpty) {
      // استدعِ دالة التحقق من البصمة مباشرة من LicenseService
      // بدلاً من UserSubscriptionService.checkUserSubscription()
      deviceFingerprintValid = await licenseService.checkDeviceFingerprint(licenseKey);
      
      // ✅ التصحيح: الرخصة صالحة إذا كانت البصمة صالحة أو إذا كان حد الأجهوزة لم يصل بعد
      // هذا يعتمد على منطق عملك، لكن في حالتك الجهاز مسجل لذا يجب أن تكون true
      hasValidLicense = basicStatus.isValid; 
    }

    return LicenseStatusWithFingerprint(
      isValid: basicStatus.isValid,
      isOffline: basicStatus.isOffline,
      expiryDate: basicStatus.expiryDate,
      daysLeft: basicStatus.daysLeft,
      maxDevices: basicStatus.maxDevices,
      usedDevices: basicStatus.usedDevices,
      reason: basicStatus.reason,
      deviceLimitExceeded: basicStatus.deviceLimitExceeded,
      licenseKey: licenseKey,
      hasValidLicense: hasValidLicense,
      deviceFingerprintValid: deviceFingerprintValid, // يجب أن تكون true الآن
    );
  } catch (e) {
    safeDebugPrint('Error checking license with fingerprint: $e');
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
 */

/* Future<LicenseStatusWithFingerprint> _getLicenseStatusWithFingerprintCheck(
    String licenseKey) async {
  try {
    // ✅ استخدام UserSubscriptionService بشكل موحد
    final subscriptionService = UserSubscriptionService();
    final subscriptionResult =
        await subscriptionService.checkUserSubscription();

    bool deviceFingerprintValid = subscriptionResult.isValid;
    bool hasValidLicense =
        subscriptionResult.isValid && !subscriptionResult.isExpired;

    return LicenseStatusWithFingerprint(
      isValid: hasValidLicense,
      isOffline: false,
      expiryDate: subscriptionResult.expiryDate,
      daysLeft: subscriptionResult.expiryDate != null
          ? subscriptionResult.expiryDate!.difference(DateTime.now()).inDays
          : 0,
      maxDevices: 1, // يمكنك جلب هذه القيمة من مكان آخر إذا لزم الأمر
      usedDevices: 0, // يمكنك جلب هذه القيمة من مكان آخر
      reason: subscriptionResult.isExpired
          ? 'License expired'
          : (subscriptionResult.isValid ? 'Active' : 'Invalid'),
      deviceLimitExceeded: false,
      licenseKey: licenseKey,
      hasValidLicense: hasValidLicense,
      deviceFingerprintValid: deviceFingerprintValid,
    );
  } catch (e) {
    safeDebugPrint('Error checking license with fingerprint: $e');
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
 */

Future<LicenseStatusWithFingerprint> _getLicenseStatusWithFingerprintCheck(
    String licenseKey) async {
  try {
    // ✅ استخدام البيانات المخزنة من _syncLicenseData بدلاً من استدعاء جديد
    final authBox = await Hive.openBox('authbox');
    final cachedStatus = authBox.get('licenseStatus');
    
    if (cachedStatus != null && cachedStatus is Map<String, dynamic>) {
      final isValid = cachedStatus['isValid'] ?? false;
      final deviceFingerprintValid = cachedStatus['deviceFingerprintValid'] ?? false;
      final expiryDateStr = cachedStatus['expiryDate'];
      final expiryDate = expiryDateStr != null ? DateTime.parse(expiryDateStr) : null;
      final daysLeft = cachedStatus['daysLeft'] ?? 0;
      final maxDevices = cachedStatus['maxDevices'] ?? 0;
      final usedDevices = cachedStatus['usedDevices'] ?? 0;
      final deviceLimitExceeded = cachedStatus['deviceLimitExceeded'] ?? false;
      final storedLicenseKey = cachedStatus['licenseKey'] as String?;
      
      safeDebugPrint('📦 Using cached license status: isValid=$isValid, fingerprintValid=$deviceFingerprintValid');
      
      return LicenseStatusWithFingerprint(
        isValid: isValid,
        isOffline: false,
        expiryDate: expiryDate,
        daysLeft: daysLeft,
        maxDevices: maxDevices,
        usedDevices: usedDevices,
        reason: cachedStatus['reason'] ?? (isValid ? 'Active' : 'Invalid'),
        deviceLimitExceeded: deviceLimitExceeded,
        licenseKey: storedLicenseKey ?? licenseKey,
        hasValidLicense: isValid && deviceFingerprintValid,
        deviceFingerprintValid: deviceFingerprintValid,
      );
    }
    
    // Fallback إذا لم تكن هناك بيانات مخزنة
    final subscriptionService = UserSubscriptionService();
    final subscriptionResult = await subscriptionService.checkUserSubscription();
    
    return LicenseStatusWithFingerprint(
      isValid: subscriptionResult.isValid && !subscriptionResult.isExpired,
      isOffline: false,
      expiryDate: subscriptionResult.expiryDate,
      daysLeft: subscriptionResult.expiryDate != null
          ? subscriptionResult.expiryDate!.difference(DateTime.now()).inDays
          : 0,
      maxDevices: 1,
      usedDevices: 0,
      reason: subscriptionResult.isValid ? 'Active' : 'Invalid',
      deviceLimitExceeded: false,
      licenseKey: licenseKey,
      hasValidLicense: subscriptionResult.isValid && !subscriptionResult.isExpired,
      deviceFingerprintValid: subscriptionResult.isValid,
    );
  } catch (e) {
    safeDebugPrint('Error checking license with fingerprint: $e');
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

// 🔒 التحقق من البصمة
/* Future<bool> _checkDeviceFingerprint(String licenseKey) async {
  try {
    return await _licenseService.checkDeviceFingerprint(licenseKey);
  } catch (e) {
    safeDebugPrint('[Fingerprint] ❌ Failed: $e');
    return false;
  }
}
 */
// 📬 التحقق من وجود طلبات ترخيص للمستخدم الحالي
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

// 📬 التحقق من وجود طلبات ترخيص عالقة للمشرف
Future<bool> _hasLicenseRequests() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('license_requests')
      .where('status', isEqualTo: 'pending')
      .get();

  return snapshot.docs.isNotEmpty;
}

// 🔄 دالة إعادة التوجيه الرئيسية - الإصدار المصحح
/* Future<String?> _appRedirectLogic(BuildContext context, GoRouterState state) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentPath = state.matchedLocation;

  if (currentPath == '/splash') return null;

  if (user == null) {
    return ['/login', '/signup'].contains(currentPath) ? null : '/login';
  }

  try {
    await _syncUserData(user.uid);
    await _syncLicenseData(user.uid);

    final userBox = await Hive.openBox('userBox');
    final isAdmin = userBox.get('isAdmin', defaultValue: false);

    if (isAdmin) {
      final hasPendingRequests = await _hasLicenseRequests();
      if (currentPath == '/license/request') {
        return hasPendingRequests ? '/admin/licenses' : '/dashboard';
      }
      return null;
    }

    final hasUserPendingRequest = await _hasUserLicenseRequest();
    if (hasUserPendingRequest && currentPath != '/license/request') {
      return '/license/request';
    }

    final licenseKeyFromHive = userBox.get('licenseKey') as String?;
    final licenseStatus = await _getLicenseStatusWithFingerprintCheck(licenseKeyFromHive ?? '');
    
    safeDebugPrint('''
    🔍 Detailed License Check:
    - User ID: ${user.uid}
    - License Key from Hive: $licenseKeyFromHive
    - Has Pending Request: $hasUserPendingRequest
    - Path: $currentPath
    - License Valid: ${licenseStatus.isValid}
    - Fingerprint Valid: ${licenseStatus.deviceFingerprintValid}
    - Device Limit: ${licenseStatus.deviceLimitExceeded}
    - License Key: ${licenseStatus.licenseKey}
    ''');

    // 🎯 التسلسل المنطقي المصحح للتوجيه:
    
    // 1. إذا كان هناك طلب ترخيص معلق
    if (hasUserPendingRequest && currentPath != '/license/request') {
      safeDebugPrint('📋 Redirecting to /license/request - Pending request exists');
      return '/license/request';
    }

    // 2. إذا كانت الرخصة غير صالحة تماماً ولا يوجد مفتاح
    if (!licenseStatus.isValid && licenseKeyFromHive == null) {
      safeDebugPrint('🚫 Redirecting to /license/request - No license key');
      return '/license/request';
    }

    // 3. إذا كانت الرخصة صالحة لكن البصمة غير صالحة
    if (licenseStatus.isValid && !licenseStatus.deviceFingerprintValid) {
      if (!['/device-registration', '/device-request'].contains(currentPath)) {
        safeDebugPrint('📱 Redirecting to /device-registration - Valid license but invalid fingerprint');
        
        // ✅ التحقق إذا كان هناك أماكن متاحة للأجهزة
        if (licenseStatus.usedDevices < licenseStatus.maxDevices) {
          return '/device-registration';
        } else {
          return '/device-request';
        }
      }
      return null;
    }

    // 4. إذا تم تجاوز حد الأجهزة
    if (licenseStatus.deviceLimitExceeded && licenseStatus.licenseKey != null) {
      if (!['/device-management', '/device-request'].contains(currentPath)) {
        safeDebugPrint('⚠️ Redirecting to /device-management - Device limit exceeded');
        return '/device-management';
      }
      return null;
    }

    // 5. إذا كانت الرخصة والبصمة صالحتين
    if (licenseStatus.isValid && licenseStatus.deviceFingerprintValid) {
      if (['/license/request', '/device-registration', '/device-request'].contains(currentPath)) {
        safeDebugPrint('✅ Redirecting to /dashboard - Valid license and fingerprint');
        return '/dashboard';
      }
      return null;
    }

    // 6. إذا كانت الرخصة صالحة ولكن تحتاج تسجيل جهاز
    if (licenseStatus.isValid && 
        !licenseStatus.deviceFingerprintValid && 
        licenseStatus.usedDevices < licenseStatus.maxDevices) {
      if (currentPath != '/device-registration') {
        safeDebugPrint('📱 Redirecting to /device-registration - License valid but device not registered');
        return '/device-registration';
      }
      return null;
    }

    // 7. إذا كانت الرخصة صالحة ولكن تجاوز الحد ويحتاج طلب جهاز
    if (licenseStatus.isValid && 
        !licenseStatus.deviceFingerprintValid && 
        licenseStatus.deviceLimitExceeded) {
      if (currentPath != '/device-request') {
        safeDebugPrint('📋 Redirecting to /device-request - License valid but device limit exceeded');
        return '/device-request';
      }
      return null;
    }

    // 8. الحالات الأخرى - العودة إلى طلب الترخيص
    if (!licenseExemptPaths.contains(currentPath)) {
      safeDebugPrint('🔁 Redirecting to /license/request - Fallback case');
      return '/license/request';
    }

    return null;
  } catch (e) {
    safeDebugPrint('Router Error: $e');
    return '/login';
  }
}
 */

/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/pages/companies/company_added_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_managment_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_registrations_handler.dart';
import 'package:puresip_purchasing/pages/factories/add_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/edit_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/factories_page.dart';
import 'package:puresip_purchasing/pages/finished_products/finished_products_page.dart';
import 'package:puresip_purchasing/pages/hive_settings_page.dart';
import 'package:puresip_purchasing/pages/inventory/inventory_query_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/manufacturing_orders_screen.dart';
import 'package:puresip_purchasing/pages/purchasing/purchase_orders_analysis/pages/purchase_orders_analysis_page.dart';
import 'package:puresip_purchasing/pages/reports/inventory_report_page.dart';
import 'package:puresip_purchasing/pages/reports/reports_page.dart';
import 'package:puresip_purchasing/pages/stock_movements/stock_movements_page.dart';
import 'package:puresip_purchasing/pages/items/add_item_page.dart';
import 'package:puresip_purchasing/pages/items/edit_item_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/edit_puchase_order_page.dart';
import 'package:puresip_purchasing/services/order_service.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/widgets/auth/admin_license_management.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_device_request_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_license_request.dart';

import 'pages/dashboard/splash_screen.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/companies/companies_page.dart';
import 'pages/companies/add_company_page.dart';
import 'pages/companies/edit_company_page.dart';
import 'pages/suppliers/suppliers_page.dart';
import 'pages/suppliers/add_supplier_page.dart';
import 'pages/suppliers/edit_supplier_page.dart';
import 'pages/purchasing/Purchasing_orders_crud/purchase_orders_page.dart';
import 'pages/purchasing/Purchasing_orders_crud/purchase_order_details_page.dart';
import 'pages/purchasing/Purchasing_orders_crud/add_purchase_order_page.dart';
import 'pages/items/items_page.dart';
import 'package:puresip_purchasing/pages/settings_page.dart';
import 'package:puresip_purchasing/debug_helper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final _licenseService = LicenseService();

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
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
        path: '/hive-settings',
        builder: (context, state) => const HiveSettingsPage()),
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
          return FutureBuilder<PurchaseOrder>(
            future: OrderService.getOrderById(id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Text('Order not found'));
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
  ],
 /*  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final currentPath = state.matchedLocation;

    if (currentPath == '/splash') return null;

    if (user == null) {
      return ['/login', '/signup'].contains(currentPath) ? null : '/login';
    }

    try {
      await _syncUserData(
          user.uid); // <-- التحديث من Firestore إلى Hive عند كل إعادة توجيه
          await _syncLicenseData(user.uid); // <-- أضف هذا

      final userBox = await Hive.openBox('userBox');
      final isAdmin = userBox.get('isAdmin', defaultValue: false);

      if (isAdmin) {
        final hasPendingRequests = await _hasLicenseRequests();
        if (currentPath == '/license/request') {
          return hasPendingRequests ? '/admin/licenses' : '/dashboard';
        }
        return null;
      }

      final hasUserPendingRequest = await _hasUserLicenseRequest();
      if (hasUserPendingRequest && currentPath != '/license/request') {
        return '/license/request';
      }

      final licenseStatus = await _licenseService.getCurrentUserLicenseStatus();

      safeDebugPrint('''
      Auth State:
      User: ${user.uid}
      Is Admin: $isAdmin
      License Valid: ${licenseStatus.isValid}
      Offline: ${licenseStatus.isOffline}
      Current Path: $currentPath
      ExpireDate: ${licenseStatus.expiryDate}
      Days Left: ${licenseStatus.daysLeft}
      Max Devices: ${licenseStatus.maxDevices}
      Used Devices: ${licenseStatus.usedDevices}
      Reason: ${licenseStatus.reason}
      Device Limit Exceeded: ${licenseStatus.deviceLimitExceeded}
      ''');

      final licenseExemptPaths = [
        '/license/request',
        '/logout',
        '/device-management',
        '/device-registration',
        '/device-request'
      ];

      if (licenseStatus.deviceLimitExceeded &&
          licenseStatus.licenseKey != null) {
        if (!['/device-management', '/device-request'].contains(currentPath)) {
          return '/device-management';
        }
        return null;
      }

      if (!licenseStatus.isValid &&
          licenseStatus.reason == 'Device not registered' &&
          licenseStatus.licenseKey != null &&
          licenseStatus.usedDevices < licenseStatus.maxDevices) {
        if (currentPath != '/device-registration') {
          return '/device-registration';
        }
        return null;
      }

      if (licenseStatus.isValid) {
        return currentPath == '/license/request' ? '/dashboard' : null;
      }

      if (licenseStatus.isOffline && licenseStatus.expiryDate != null) {
        safeDebugPrint(
            "✅ Offline mode with cached license, staying on $currentPath");
        return null;
      }

      if (!licenseExemptPaths.contains(currentPath)) {
        return '/license/request';
      }

      if (['/login', '/signup'].contains(currentPath)) {
        return '/dashboard';
      }

      return null;
    } catch (e) {
      safeDebugPrint('Router Error: $e');
      return '/login';
    }
  },
 */
redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final currentPath = state.matchedLocation;

    if (currentPath == '/splash') return null;

    if (user == null) {
      return ['/login', '/signup'].contains(currentPath) ? null : '/login';
    }

    try {
      await _syncUserData(user.uid);
      await _syncLicenseData(user.uid);

      final userBox = await Hive.openBox('userBox');
      final isAdmin = userBox.get('isAdmin', defaultValue: false);

      if (isAdmin) {
        final hasPendingRequests = await _hasLicenseRequests();
        if (currentPath == '/license/request') {
          return hasPendingRequests ? '/admin/licenses' : '/dashboard';
        }
        return null;
      }

      // ✅ أولاً: التحقق من وجود طلب ترخيص معلق
      final hasUserPendingRequest = await _hasUserLicenseRequest();
      if (hasUserPendingRequest && currentPath != '/license/request') {
        return '/license/request';
      }

      // ✅ ثانياً: الحصول على حالة الترخيص مع التحقق من البصمة
      final licenseStatus = await _getLicenseStatusWithFingerprintCheck(user.uid);

      safeDebugPrint('''
      Auth State:
      User: ${user.uid}
      Is Admin: $isAdmin
      License Valid: ${licenseStatus.isValid}
      Offline: ${licenseStatus.isOffline}
      Current Path: $currentPath
      ExpireDate: ${licenseStatus.expiryDate}
      Days Left: ${licenseStatus.daysLeft}
      Max Devices: ${licenseStatus.maxDevices}
      Used Devices: ${licenseStatus.usedDevices}
      Reason: ${licenseStatus.reason}
      Device Limit Exceeded: ${licenseStatus.deviceLimitExceeded}
      Device Fingerprint Valid: ${licenseStatus.deviceFingerprintValid}
      ''');

      final licenseExemptPaths = [
        '/license/request',
        '/logout',
        '/device-management',
        '/device-registration',
        '/device-request'
      ];

      // ✅ ثالثاً: التسلسل المنطقي للتحقق
      if (!licenseStatus.hasValidLicense) {
        if (!licenseExemptPaths.contains(currentPath)) {
          return '/license/request';
        }
        return null;
      }

           // 2. إذا كان الترخيص صالحاً ولكن البصمة غير صالحة، توجه إلى تسجيل الجهاز
      if (licenseStatus.isValid && !licenseStatus.deviceFingerprintValid) {
        if (currentPath != '/device-registration') {
          return '/device-registration'; // ✅ التصحيح هنا
        }
        return null;
      }

      // ✅ رابعاً: التحقق من حدود الأجهزة
      if (licenseStatus.deviceLimitExceeded && licenseStatus.licenseKey != null) {
        if (!['/device-management', '/device-request'].contains(currentPath)) {
          return '/device-management';
        }
        return null;
      }
  // 4. إذا كانت كل الشروط صحيحة، السماح بالدخول إلى Dashboard
      if (licenseStatus.isValid && licenseStatus.deviceFingerprintValid) {
        if (currentPath == '/license/request' || currentPath == '/device-registration') {
          return '/dashboard'; // ✅ إذا كان في صفحة تسجيل جهاز أو ترخيص، توجه إلى Dashboard
        }
        return null;
      }

      // ✅ خامساً: التحقق من تسجيل البصمة
      if (!licenseStatus.deviceFingerprintValid && 
          licenseStatus.licenseKey != null && 
          licenseStatus.usedDevices < licenseStatus.maxDevices) {
        if (currentPath != '/device-registration') {
          return '/device-registration';
        }
        return null;
      }

      // ✅ سادساً: إذا كانت كل الشروط صحيحة، السماح بالدخول
      if (licenseStatus.isValid && licenseStatus.deviceFingerprintValid) {
        return currentPath == '/license/request' ? '/dashboard' : null;
      }

      if (licenseStatus.isOffline && licenseStatus.expiryDate != null) {
        safeDebugPrint("✅ Offline mode with cached license, staying on $currentPath");
        return null;
      }

      if (!licenseExemptPaths.contains(currentPath)) {
        return '/license/request';
      }

      if (['/login', '/signup'].contains(currentPath)) {
        return '/dashboard';
      }

      return null;
    } catch (e) {
      safeDebugPrint('Router Error: $e');
      return '/login';
    }
  },
);

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

Future<LicenseStatusWithFingerprint> _getLicenseStatusWithFingerprintCheck(String userId) async {
  try {
    // ✅ أولاً: الحصول على حالة الترخيص الأساسية
    final basicStatus = await _licenseService.getCurrentUserLicenseStatus();
    
    // ✅ ثانياً: التحقق من البصمة إذا كان الترخيص صالحاً
    bool deviceFingerprintValid = false;
    bool hasValidLicense = basicStatus.isValid;

    if (basicStatus.isValid && basicStatus.licenseKey != null) {
      deviceFingerprintValid = await _checkDeviceFingerprint(basicStatus.licenseKey!);
      
      // ✅ إذا كانت البصمة غير صالحة، الترخيص غير صالح للاستخدام
      if (!deviceFingerprintValid) {
        hasValidLicense = false;
      }
    }

    return LicenseStatusWithFingerprint(
      isValid: basicStatus.isValid,
      isOffline: basicStatus.isOffline,
      expiryDate: basicStatus.expiryDate,
      daysLeft: basicStatus.daysLeft,
      maxDevices: basicStatus.maxDevices,
      usedDevices: basicStatus.usedDevices,
      reason: basicStatus.reason,
      deviceLimitExceeded: basicStatus.deviceLimitExceeded,
      licenseKey: basicStatus.licenseKey,
      hasValidLicense: hasValidLicense,
      deviceFingerprintValid: deviceFingerprintValid,
    );
  } catch (e) {
    safeDebugPrint('Error checking license with fingerprint: $e');
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

Future<bool> _checkDeviceFingerprint(String licenseKey) async {
  try {
    final userSubscriptionService = UserSubscriptionService();
    final result = await userSubscriptionService.checkUserSubscription();
    
    return result.isValid;
  } catch (e) {
    safeDebugPrint('Error checking device fingerprint: $e');
    return false;
  }
}

Future<void> _syncUserData(String userId) async {
  try {
    final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data() ?? {};
    final userBox = await Hive.openBox('userBox');
    final authBox = await Hive.openBox('authbox');

    // ✅ حفظ بيانات المستخدم
    await userBox.putAll({
      'name': data['name'],
      'email': data['email'],
      'isAdmin': data['isAdmin'] ?? false,
      'lastSync': DateTime.now().toIso8601String(),
    });

    // ✅ حفظ بيانات الترخيص في authbox
    final licenseExpiry = (data['license_expiry'] as Timestamp?)?.toDate();
    final licenseKey = data['licenseKey'] as String?;
    final isActive = data['isActive'] as bool? ?? false;
    final maxDevices = data['maxDevices'] as int? ?? 0;
    final deviceIds = data['deviceIds'] as List<dynamic>? ?? [];
    
    final now = DateTime.now();
    final isValid = isActive && licenseExpiry != null && licenseExpiry.isAfter(now);

    await authBox.put('licenseStatus', {
      'isValid': isValid,
      'licenseKey': licenseKey,
      'expiryDate': licenseExpiry?.toIso8601String(),
      'maxDevices': maxDevices,
      'usedDevices': deviceIds.length,
      'daysLeft': isValid ? licenseExpiry.difference(now).inDays : 0,
      'reason': isValid ? 'Active' : 'License expired',
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    safeDebugPrint('[Sync] ✅ User and license data synced to Hive');

  } catch (e) {
    safeDebugPrint('[Sync] ❌ Failed to sync user data: $e');
  }
}

/* Future<void> _syncLicenseData(String userId) async {
  try {
    final licenseSnapshot = await FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    final authBox = await Hive.openBox('authbox');
    DateTime? latestExpiry;
    int maxDevices = 0;
    int usedDevices = 0;
    bool isValid = false;

    for (var doc in licenseSnapshot.docs) {
      final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
      final isActive = doc.get('isActive') as bool? ?? false;
      final devices = doc.get('devices') as List<dynamic>? ?? [];

      if (isActive && expiry != null && expiry.isAfter(DateTime.now())) {
        isValid = true;
        latestExpiry = expiry;
        maxDevices = doc.get('maxDevices') as int? ?? 0;
        usedDevices = devices.length;
        break;
      }
    }

    await authBox.put('licenseStatus', {
      'isValid': isValid,
      'expiryDate': latestExpiry?.toIso8601String(),
      'daysLeft': latestExpiry != null
          ? latestExpiry.difference(DateTime.now()).inDays
          : 0,
      'maxDevices': maxDevices,
      'usedDevices': usedDevices,
      'reason': isValid ? 'Active' : 'No valid license',
      'deviceLimitExceeded': usedDevices >= maxDevices,
    });

    safeDebugPrint('[Sync] ✅ License data synced to Hive');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ Failed to sync license data: $e');
  }
}
 */
Future<void> _syncLicenseData(String userId) async {
  try {
    final licenseSnapshot = await FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    final authBox = await Hive.openBox('authbox');
    DateTime? latestExpiry;
    int maxDevices = 0;
    int usedDevices = 0;
    bool isValid = false;
    String? licenseKey;

    for (var doc in licenseSnapshot.docs) {
      final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
      final isActive = doc.get('isActive') as bool? ?? false;
      final devices = doc.get('devices') as List<dynamic>? ?? [];
      licenseKey = doc.id;

      if (isActive && expiry != null && expiry.isAfter(DateTime.now())) {
        isValid = true;
        latestExpiry = expiry;
        maxDevices = doc.get('maxDevices') as int? ?? 0;
        usedDevices = devices.length;
        break;
      }
    }

    // ✅ التحقق من البصمة أيضاً
    final deviceFingerprintValid = await _checkDeviceFingerprint(licenseKey ?? '');

    await authBox.put('licenseStatus', {
      'isValid': isValid,
      'expiryDate': latestExpiry?.toIso8601String(),
      'daysLeft': latestExpiry != null
          ? latestExpiry.difference(DateTime.now()).inDays
          : 0,
      'maxDevices': maxDevices,
      'usedDevices': usedDevices,
      'reason': isValid ? 'Active' : 'No valid license',
      'deviceLimitExceeded': usedDevices >= maxDevices,
      'licenseKey': licenseKey,
      'deviceFingerprintValid': deviceFingerprintValid,
      'hasValidLicense': isValid && deviceFingerprintValid,
    });

    safeDebugPrint('[Sync] ✅ License data synced to Hive');
  } catch (e) {
    safeDebugPrint('[Sync] ❌ Failed to sync license data: $e');
  }
}

Future<bool> _hasUserLicenseRequest() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  } catch (e) {
    safeDebugPrint('User license request check failed: $e');
    return false;
  }
}

Future<bool> _hasLicenseRequests() async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  } catch (e) {
    safeDebugPrint('License request check failed: $e');
    return false;
  }
} */

/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/pages/companies/company_added_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_managment_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_registrations_handler.dart';
import 'package:puresip_purchasing/pages/factories/add_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/edit_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/factories_page.dart';
import 'package:puresip_purchasing/pages/finished_products/finished_products_page.dart';
import 'package:puresip_purchasing/pages/hive_settings_page.dart';
import 'package:puresip_purchasing/pages/inventory/inventory_query_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/manufacturing_orders_screen.dart';
import 'package:puresip_purchasing/pages/purchasing/purchase_orders_analysis/pages/purchase_orders_analysis_page.dart';
import 'package:puresip_purchasing/pages/reports/inventory_report_page.dart';
import 'package:puresip_purchasing/pages/reports/reports_page.dart';
import 'package:puresip_purchasing/pages/stock_movements/stock_movements_page.dart';
import 'package:puresip_purchasing/pages/items/add_item_page.dart';
import 'package:puresip_purchasing/pages/items/edit_item_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/edit_puchase_order_page.dart';
import 'package:puresip_purchasing/services/order_service.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/widgets/auth/admin_license_management.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_device_request_page.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_license_request.dart';

import 'pages/dashboard/splash_screen.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/companies/companies_page.dart';
import 'pages/companies/add_company_page.dart';
import 'pages/companies/edit_company_page.dart';
import 'pages/suppliers/suppliers_page.dart';
import 'pages/suppliers/add_supplier_page.dart';
import 'pages/suppliers/edit_supplier_page.dart';
import 'pages/purchasing/Purchasing_orders_crud/purchase_orders_page.dart';
import 'pages/purchasing/Purchasing_orders_crud/purchase_order_details_page.dart';
import 'pages/purchasing/Purchasing_orders_crud/add_purchase_order_page.dart';
import 'pages/items/items_page.dart';
import 'package:puresip_purchasing/pages/settings_page.dart';
import 'package:puresip_purchasing/debug_helper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final _licenseService = LicenseService();

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash', // غير مباشرة إلى splash
  routes: [
    GoRoute(
      path: '/splash',
    //  builder: (context, state) => const SplashScreen(),
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const SplashScreen(),
      ),
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
    // في router.dart - إضافة Route جديد
    GoRoute(
      path: '/hive-settings',
      builder: (context, state) => const HiveSettingsPage(),
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
          path: '/purchase-orders-analysis',
          builder: (context, state) => const PurchaseOrdersAnalysisPage(),
        ),
        GoRoute(
          path: '/report-inventory',
          builder: (context, state) => const InventoryAnalysisPage(),
        ),
      ],
    ),
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
          return FutureBuilder<PurchaseOrder>(
            future: OrderService.getOrderById(id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Text('Order not found'));
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

    // إضافة Route جديدة في router
    GoRoute(
      path: '/device-registration',
      builder: (context, state) => const DeviceRegistrationHandler(),
    ),
// في router.dart
    GoRoute(
      path: '/device-management',
      builder: (context, state) {
        // حاول الحصول على licenseId من state.extra
        final licenseId = state.extra as String?;
        return DeviceManagementPage(licenseId: licenseId);
      },
    ),
    // في router.dart
    GoRoute(
      path: '/device-request',
      builder: (context, state) => const DeviceRequestPage(),
    ),
    GoRoute(
        path: '/license/request',
        builder: (context, state) => const UserLicenseRequestPage()),
    GoRoute(
        path: '/admin/licenses',
        builder: (context, state) => const AdminLicenseManagementPage()),
  ],

// في router.dart
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final currentPath = state.matchedLocation;

    if (currentPath == '/splash') return null;

    if (user == null) {
      return ['/login', '/signup'].contains(currentPath) ? null : '/login';
    }

    try {
      final isAdmin = await _checkIfAdmin(user.uid);

      if (isAdmin) {
        final hasPendingRequests = await _hasLicenseRequests();
        if (currentPath == '/license/request') {
          return hasPendingRequests ? '/admin/licenses' : '/dashboard';
        }
        return null;
      }

      final hasUserPendingRequest = await _hasUserLicenseRequest();
      if (hasUserPendingRequest && currentPath != '/license/request') {
        return '/license/request';
      }

      final licenseStatus = await _licenseService.getCurrentUserLicenseStatus();

      safeDebugPrint('''
    Auth State:
    User: ${user.uid}
    Is Admin: $isAdmin
    License Valid: ${licenseStatus.isValid}
    Offline: ${licenseStatus.isOffline}
    Current Path: $currentPath
    ExpireDate: ${licenseStatus.expiryDate}
    Days Left: ${licenseStatus.daysLeft}
    Max Devices: ${licenseStatus.maxDevices}
    Used Devices: ${licenseStatus.usedDevices}
    Reason: ${licenseStatus.reason}
    Device Limit Exceeded: ${licenseStatus.deviceLimitExceeded}
    ''');

      final licenseExemptPaths = [
        '/license/request',
        '/logout',
        '/device-management',
        '/device-registration',
        '/device-request'
      ];

      // حالة خاصة: ترخيص صالح ولكن تجاوز حد الأجهزة
      if (licenseStatus.deviceLimitExceeded &&
          licenseStatus.licenseKey != null) {
        if (!['/device-management', '/device-request'].contains(currentPath)) {
          return '/device-management';
        }
        return null;
      }

      // حالة: ترخيص صالح ولكن الجهاز غير مسجل (وهناك مساحة)
      if (!licenseStatus.isValid &&
          licenseStatus.reason == 'Device not registered' &&
          licenseStatus.licenseKey != null &&
          licenseStatus.usedDevices < licenseStatus.maxDevices) {
        if (currentPath != '/device-registration') {
          return '/device-registration';
        }
        return null;
      }

      if (licenseStatus.isValid) {
        return currentPath == '/license/request' ? '/dashboard' : null;
      }

      if (licenseStatus.isOffline && licenseStatus.expiryDate != null) {
        safeDebugPrint(
            "✅ Offline mode with cached license, staying on $currentPath");
        return null;
      }

      if (!licenseExemptPaths.contains(currentPath)) {
        return '/license/request';
      }

      if (['/login', '/signup'].contains(currentPath)) {
        return '/dashboard';
      }

      return null;
    } catch (e) {
      safeDebugPrint('Router Error: $e');
      return '/login';
    }
  },
);

Future<bool> _checkIfAdmin(String userId) async {
  try {
    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!docSnapshot.exists) return false;
    return docSnapshot.data()?['isAdmin'] == true;
  } catch (e) {
    safeDebugPrint('[AdminCheck] Error: $e');
    return false;
  }
}

Future<bool> _hasUserLicenseRequest() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  } catch (e) {
    safeDebugPrint('User license request check failed: $e');
    return false;
  }
}

Future<bool> _hasLicenseRequests() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  } catch (e) {
    safeDebugPrint('License request check failed: $e');
    return false;
  }
}
 */
/*     redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final currentPath = state.matchedLocation;

      // 1. شاشة البداية
      if (currentPath == '/splash') {
        return null;
      }

      // 2. المستخدم غير مسجل الدخول
      if (user == null) {
        return ['/login', '/signup'].contains(currentPath) ? null : '/login';
      }

      try {
        final isAdmin = await _checkIfAdmin(user.uid);

        if (isAdmin) {
          final hasPendingRequests = await _hasLicenseRequests();

          if (currentPath == '/license/request') {
            return hasPendingRequests ? '/admin/licenses' : '/dashboard';
          }

          return null;
        } else {
          // للمستخدم العادي: التحقق من طلباته الخاصة فقط
          final hasUserPendingRequest = await _hasUserLicenseRequest();

          if (hasUserPendingRequest && currentPath != '/license/request') {
            return '/license/request';
          }
        }

        // استخدام الدالة الجديدة للتحقق من الترخيص
        final licenseStatus =
            await _licenseService.getCurrentUserLicenseStatus();

        safeDebugPrint('''
      Auth State:
      User: ${user.uid}
      Is Admin: $isAdmin
      License Valid: ${licenseStatus.isValid}
      Current Path: $currentPath
      ExpireDate is: ${licenseStatus.expiryDate}
      Days Left: ${licenseStatus.daysLeft}
      Reason: ${licenseStatus.reason}
    ''');

        final licenseExemptPaths = ['/license/request', '/logout'];

        if (!licenseStatus.isValid &&
            !licenseExemptPaths.contains(currentPath)) {
          return '/license/request';
        }
        if (!licenseStatus.isValid &&
            !licenseStatus.isOffline &&
            !licenseExemptPaths.contains(currentPath)) {
          return '/license/request';
        }
    // السماح إذا الترخيص صالح
        if (licenseStatus.isValid) {
          // لو المستخدم واقف على /license/request نرجعه للداشبورد
          if (currentPath == '/license/request') {
            return '/dashboard';
          }
          return null;
        }

    // هنا الترخيص غير صالح
    // لو النت مقطوع لكن عندنا كاش صالح → السماح
        if (licenseStatus.isOffline) {
          safeDebugPrint(
              "Offline mode with cached license, staying on $currentPath");
          return null;
        }

    // في حالة عدم وجود كاش أو الترخيص فعلاً منتهي → تحويل
        if (!licenseExemptPaths.contains(currentPath)) {
          return '/license/request';
        }

        if (licenseStatus.isValid && currentPath == '/license/request') {
          return '/dashboard';
        }

        // 5. منع الوصول لصفحات تسجيل الدخول بعد الدخول
        if (['/login', '/signup'].contains(currentPath)) {
          return '/dashboard';
        }

        return null;
      } catch (e) {
        safeDebugPrint('Router Error: $e');
        return '/login';
      }
    });
 */
/*     redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final currentPath = state.matchedLocation;

      // 1. شاشة البداية
      if (currentPath == '/splash') {
        // return user != null ? '/dashboard' : '/login';
        return null;
      }

      // 2. المستخدم غير مسجل الدخول
      if (user == null) {
        return ['/login', '/signup'].contains(currentPath) ? null : '/login';
      }

      try {
        final isAdmin = await _checkIfAdmin(user.uid);

        if (isAdmin) {
          final hasPendingRequests = await _hasLicenseRequests();

          if (currentPath == '/license/request') {
            return hasPendingRequests ? '/admin/licenses' : '/dashboard';
          }

          return null; // الأدمن له صلاحية الوصول لجميع الصفحات الأخرى
        } else {
          // للمستخدم العادي: التحقق من طلباته الخاصة فقط
          final hasUserPendingRequest = await _hasUserLicenseRequest();

          if (hasUserPendingRequest && currentPath != '/license/request') {
            return '/license/request';
          }
        }
        // 4. التحقق من الترخيص للمستخدم العادي
        //  final licenseStatus = await _licenseService.checkLicenseStatus();
/*         final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final licenseKey = userDoc.data()?['licenseKey'];
        if (licenseKey == null) {
          return '/license/request';
        }

        final licenseStatus =
            await _licenseService.checkLicenseStatus(licenseKey); */

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          safeDebugPrint('User document does not exist');
          return '/license/request';
        }

        final data = userDoc.data();
        final licenseKey = data?['licenseKey'];

        if (licenseKey == null || licenseKey.isEmpty) {
          safeDebugPrint('No license key found for user');
          return '/license/request';
        }

        safeDebugPrint('License key found: $licenseKey');
        final licenseStatus =
            await _licenseService.checkLicenseStatus(licenseKey);

        safeDebugPrint('''
              Auth State:
              User: ${user.uid}
              Is Admin: $isAdmin
              License Valid: ${licenseStatus.isValid}
              Current Path: $currentPath
              ExpireDate is: ${licenseStatus.expiryDate}
              Days Left: ${licenseStatus.daysLeft}
              license request: ${await _hasLicenseRequests()}
            ''');

        final licenseExemptPaths = ['/license/request', '/logout'];

        if (!licenseStatus.isValid &&
            !licenseExemptPaths.contains(currentPath)) {
          return '/license/request';
        }

        if (licenseStatus.isValid && currentPath == '/license/request') {
          return '/dashboard';
        }

        // 5. منع الوصول لصفحات تسجيل الدخول بعد الدخول
        if (['/login', '/signup'].contains(currentPath)) {
          return '/dashboard';
        }

        return null; // السماح بباقي الصفحات
      } catch (e) {
        safeDebugPrint('Router Error: $e');
        return '/login';
      }
    });
 */
/* // في router.dart
redirect: (context, state) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentPath = state.matchedLocation;

  if (currentPath == '/splash') return null;

  if (user == null) {
    return ['/login', '/signup'].contains(currentPath) ? null : '/login';
  }

  try {
    final isAdmin = await _checkIfAdmin(user.uid);

    if (isAdmin) {
      final hasPendingRequests = await _hasLicenseRequests();
      if (currentPath == '/license/request') {
        return hasPendingRequests ? '/admin/licenses' : '/dashboard';
      }
      return null;
    }

    final hasUserPendingRequest = await _hasUserLicenseRequest();
    if (hasUserPendingRequest && currentPath != '/license/request') {
      return '/license/request';
    }

    final licenseStatus = await _licenseService.getCurrentUserLicenseStatus();

    safeDebugPrint('''
    Auth State:
    User: ${user.uid}
    Is Admin: $isAdmin
    License Valid: ${licenseStatus.isValid}
    Offline: ${licenseStatus.isOffline}
    Current Path: $currentPath
    ExpireDate: ${licenseStatus.expiryDate}
    Days Left: ${licenseStatus.daysLeft}
    Max Devices: ${licenseStatus.maxDevices}
    Used Devices: ${licenseStatus.usedDevices}
    Reason: ${licenseStatus.reason}
    Device Limit Exceeded: ${licenseStatus.deviceLimitExceeded}
    ''');

    final licenseExemptPaths = [
      '/license/request', 
      '/logout', 
      '/device-management', 
      '/device-registration',
      '/device-request'
    ];

    // حالة خاصة: ترخيص صالح ولكن تجاوز حد الأجهزة
    if (licenseStatus.deviceLimitExceeded && licenseStatus.licenseKey != null) {
      if (!['/device-management', '/device-request'].contains(currentPath)) {
        return '/device-management';
      }
      return null;
    }

    // حالة: ترخيص صالح ولكن الجهاز غير مسجل (وهناك مساحة)
    if (!licenseStatus.isValid && 
        licenseStatus.reason == 'Device not registered' &&
        licenseStatus.licenseKey != null &&
        licenseStatus.usedDevices < licenseStatus.maxDevices) {
      if (currentPath != '/device-registration') {
        return '/device-registration';
      }
      return null;
    }

    if (licenseStatus.isValid) {
      return currentPath == '/license/request' ? '/dashboard' : null;
    }

    if (licenseStatus.isOffline && licenseStatus.expiryDate != null) {
      safeDebugPrint("✅ Offline mode with cached license, staying on $currentPath");
      return null;
    }

    if (!licenseExemptPaths.contains(currentPath)) {
      return '/license/request';
    }

    if (['/login', '/signup'].contains(currentPath)) {
      return '/dashboard';
    }

    return null;
  } catch (e) {
    safeDebugPrint('Router Error: $e');
    return '/login';
  }
},
 */
// في ملف الراوتر (router.dart)
/* redirect: (context, state) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentPath = state.matchedLocation;

  if (currentPath == '/splash') return null;

  if (user == null) {
    return ['/login', '/signup'].contains(currentPath) ? null : '/login';
  }

  try {
    final isAdmin = await _checkIfAdmin(user.uid);

    if (isAdmin) {
      final hasPendingRequests = await _hasLicenseRequests();
      if (currentPath == '/license/request') {
        return hasPendingRequests ? '/admin/licenses' : '/dashboard';
      }
      return null;
    }

    final hasUserPendingRequest = await _hasUserLicenseRequest();
    if (hasUserPendingRequest && currentPath != '/license/request') {
      return '/license/request';
    }

    final licenseStatus = await _licenseService.getCurrentUserLicenseStatus();

    safeDebugPrint('''
    Auth State:
    User: ${user.uid}
    Is Admin: $isAdmin
    License Valid: ${licenseStatus.isValid}
    Offline: ${licenseStatus.isOffline}
    Current Path: $currentPath
    ExpireDate: ${licenseStatus.expiryDate}
    Days Left: ${licenseStatus.daysLeft}
    Reason: ${licenseStatus.reason}
    ''');

    final licenseExemptPaths = ['/license/request', '/logout', '/device-management', '/device-registration'];

    // إذا كان الترخيص صالحًا ولكن هناك مشكلة في الجهاز
    if (licenseStatus.isValid && licenseStatus.reason == 'Device limit exceeded') {
      if (currentPath != '/device-management') {
        return '/device-management';
      }
      return null;
    }

    if (licenseStatus.isValid) {
      return currentPath == '/license/request' ? '/dashboard' : null;
    }

    if (licenseStatus.isOffline && licenseStatus.expiryDate != null) {
      safeDebugPrint("✅ Offline mode with cached license, staying on $currentPath");
      return null;
    }

    if (!licenseExemptPaths.contains(currentPath)) {
      return '/license/request';
    }

    if (['/login', '/signup'].contains(currentPath)) {
      return '/dashboard';
    }

    return null;
  } catch (e) {
    safeDebugPrint('Router Error: $e');
    return '/login';
  }
},
 */ /*   redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final currentPath = state.matchedLocation;

    if (currentPath == '/splash') return null;

    if (user == null) {
      return ['/login', '/signup'].contains(currentPath) ? null : '/login';
    }

    try {
      final isAdmin = await _checkIfAdmin(user.uid);

      if (isAdmin) {
        final hasPendingRequests = await _hasLicenseRequests();
        if (currentPath == '/license/request') {
          return hasPendingRequests ? '/admin/licenses' : '/dashboard';
        }
        return null;
      }

      final hasUserPendingRequest = await _hasUserLicenseRequest();
      if (hasUserPendingRequest && currentPath != '/license/request') {
        return '/license/request';
      }

      final licenseStatus = await _licenseService.getCurrentUserLicenseStatus();

      safeDebugPrint('''
      Auth State:
      User: ${user.uid}
      Is Admin: $isAdmin
      License Valid: ${licenseStatus.isValid}
      Offline: ${licenseStatus.isOffline}
      Current Path: $currentPath
      ExpireDate: ${licenseStatus.expiryDate}
      Days Left: ${licenseStatus.daysLeft}
      Reason: ${licenseStatus.reason}
      ''');

      final licenseExemptPaths = ['/license/request', '/logout'];

      if (licenseStatus.isValid) {
        return currentPath == '/license/request' ? '/dashboard' : null;
      }

      if (licenseStatus.isOffline && licenseStatus.expiryDate != null) {
        safeDebugPrint(
            "✅ Offline mode with cached license, staying on $currentPath");
        return null;
      }

      if (!licenseExemptPaths.contains(currentPath)) {
        return '/license/request';
      }

      if (['/login', '/signup'].contains(currentPath)) {
        return '/dashboard';
      }

      return null;
    } catch (e) {
      safeDebugPrint('Router Error: $e');
      return '/login';
    }
  },
 */
