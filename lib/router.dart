// router.dart - النسخة الكاملة المعدلة

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/pages/admin/admin_users_page.dart';
import 'package:puresip_purchasing/pages/admin/force_update_all_stats.dart';
import 'package:puresip_purchasing/pages/admin/update_all_users_stats_page.dart';
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
import 'package:puresip_purchasing/pages/reports/factory_performance_report.dart';
import 'package:puresip_purchasing/pages/reports/inventory_onhand_report_page.dart';
import 'package:puresip_purchasing/pages/reports/inventory_report_page.dart';
import 'package:puresip_purchasing/pages/reports/reports_page.dart';
import 'package:puresip_purchasing/pages/reports/slow_moving_report.dart';
import 'package:puresip_purchasing/pages/reports/supplier_analysis_report.dart';
import 'package:puresip_purchasing/pages/reports/supplier_performance_report.dart';
import 'package:puresip_purchasing/pages/reports/trend_analysis_report.dart';
import 'package:puresip_purchasing/pages/settings/additional_items_page.dart';
import 'package:puresip_purchasing/pages/settings/user_terms_management_page.dart';
import 'package:puresip_purchasing/pages/settings/settings_page.dart';
import 'package:puresip_purchasing/pages/stock_movements/stock_movements_page.dart';
import 'package:puresip_purchasing/pages/suppliers/add_supplier_page.dart';
import 'package:puresip_purchasing/pages/suppliers/edit_supplier_page.dart';
import 'package:puresip_purchasing/pages/suppliers/suppliers_page.dart';
import 'package:puresip_purchasing/pages/reset_page.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/order_service.dart';
import 'package:puresip_purchasing/widgets/auth/admin_license_management.dart';
import 'package:puresip_purchasing/widgets/keep_alive_wrapper.dart';

// 🌐 مفتاح التنقل العام
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// أنشئ instance للخدمة

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

/* // 🚦 الدالة الرئيسية لإعادة التوجيه
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
 */
// router.dart - الدالة النهائية

/* Future<String?> _appRedirectLogic(
    BuildContext context, GoRouterState state) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentPath = state.matchedLocation;

  if (currentPath == '/splash') return null;
  if (currentPath == '/reset') return null;

  if (user == null) {
    return '/login';
  }

  try {
    final isAdminStr = await _secureStorage.read(key: 'isAdmin');
    if (isAdminStr == 'true') {
      return null;  // Admin يمر فوراً
    }
    
    final licenseKey = await _secureStorage.read(key: 'licenseKey');
    if (licenseKey == null || licenseKey.isEmpty) {
      return '/license/request';
    }
    
    return null;  // مستخدم عادي مع ترخيص → Dashboard
    
  } catch (e) {
    return null;
  }
}
 */

/* Future<String?> _appRedirectLogic(
    BuildContext context, GoRouterState state) async {
  final currentPath = state.matchedLocation;

  if (currentPath == '/splash') return null;
  if (currentPath == '/reset') return null;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '/login';

  // Admin يمر مباشرة
  final isAdminStr = await _secureStorage.read(key: 'isAdmin');
  if (isAdminStr == 'true') return null;

  // التحقق من الترخيص
  final licenseService = LicenseService();
  final status = await licenseService.getCurrentUserLicenseStatus();

  safeDebugPrint('🔍 Router: isValid=${status.isValid} | path=$currentPath');

  const licenseRelatedPaths = [
    '/license/request',
    '/device-management',
    '/device-registration',
    '/device-request',
  ];

  if (status.isValid) {
    if (licenseRelatedPaths.contains(currentPath)) {
      return '/dashboard';
    }
    return null;
  } else {
    if (!licenseRelatedPaths.contains(currentPath)) {
      return '/license/request';
    }
    return null;
  }
}
 */

// router.dart - استبدل دالة _appRedirectLogic بهذه النسخة

// router.dart - استبدل دالة _appRedirectLogic بالكامل

Future<String?> _appRedirectLogic(
    BuildContext context, GoRouterState state) async {
  final currentPath = state.matchedLocation;

  // ✅ المسارات العامة
  const publicPaths = ['/splash', '/reset', '/login', '/signup'];
  if (publicPaths.contains(currentPath)) {
    return null;
  }

  final user = FirebaseAuth.instance.currentUser;

  // ✅ لا يوجد مستخدم
  if (user == null) {
    return '/login';
  }

  // ✅ التحقق من Admin باستخدام LicenseService
  final licenseService = LicenseService();
  final isAdmin = await licenseService.isCurrentUserAdmin();

  // ✅ إذا كان Admin، دعه يمر دون تحويل
  if (isAdmin) {
    safeDebugPrint('👑 Admin user: ${user.email} - full access granted');
    return null;
  }

/*   // ✅ للمستخدمين العاديين - تحقق من الترخيص
  final status = await licenseService.getCurrentUserLicenseStatus();

  safeDebugPrint(
      '🔍 User: ${user.email} | isValid=${status.isValid} | path=$currentPath'); */
  // ✅ أولاً: تحقق من SecureStorage (أسرع وأموثوق)
  const storage = FlutterSecureStorage();
  final cachedLicenseKey = await storage.read(key: 'license_key');
  final cachedExpiryStr = await storage.read(key: 'license_expiry');
  final cachedStatus = await storage.read(key: 'license_status');

  bool isCachedValid = false;
  if (cachedLicenseKey != null &&
      cachedStatus == 'active' &&
      cachedExpiryStr != null) {
    final expiry = DateTime.tryParse(cachedExpiryStr);
    if (expiry != null && expiry.isAfter(DateTime.now())) {
      isCachedValid = true;
      safeDebugPrint(
          '✅ Router: Valid license from SecureStorage: $cachedLicenseKey');
    }
  }

  // ✅ ثانياً: لو SecureStorage ما فيهوش، جرب Firestore
  bool isValid = isCachedValid;
  if (!isValid) {
    try {
      final status = await licenseService
          .getCurrentUserLicenseStatus()
          .timeout(const Duration(seconds: 5));
      isValid = status.isValid;
      safeDebugPrint('🔍 Router Firestore check: isValid=$isValid');
    } catch (e) {
      safeDebugPrint('⚠️ Router: Firestore check failed: $e');
      // لو Firestore فشل والـ cache موجود، استخدمه كـ fallback
      isValid = cachedLicenseKey != null;
    }
  }

  safeDebugPrint(
      '🔍 User: ${user.email} | isValid=$isValid | path=$currentPath');

  const licenseRelatedPaths = [
    '/license/request',
    '/device-management',
    '/device-registration',
    '/device-request',
  ];

  if (isValid) {
    if (licenseRelatedPaths.contains(currentPath)) {
      return '/dashboard';
    }
    return null;
  } else {
    if (!licenseRelatedPaths.contains(currentPath)) {
      safeDebugPrint('❌ No valid license, redirecting to /license/request');
      return '/license/request';
    }
    return null;
  }
}
/*   if (status.isValid) {
    // ترخيص صالح - إذا كان في صفحات الترخيص، اذهب إلى Dashboard
    if (licenseRelatedPaths.contains(currentPath)) {
      safeDebugPrint(
          '✅ Valid license, redirecting from license page to dashboard');
      return '/dashboard';
    }
    return null;
  } else {
    // لا يوجد ترخيص - إذا لم يكن في صفحات الترخيص، اذهب إليها
    if (!licenseRelatedPaths.contains(currentPath)) {
      safeDebugPrint('❌ No valid license, redirecting to /license/request');
      return '/license/request';
    }
    return null;
  }
} */

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
/*     GoRoute(
      path: '/reports',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: ReportsPage()),
      ),
      routes: [
        GoRoute(
          path: '/report-inventoryOnHand',
          pageBuilder: (context, state) => const MaterialPage(
            child: InventoryOnHandPage(),
          ),
        ),
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
    ), */

// في router.dart - قسم التقارير

// ==================== التقارير ====================
    GoRoute(
      path: '/reports',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeepAliveWrapper(child: ReportsPage()),
      ),
      routes: [
        // ✅ جميع التقارير الـ 13
        GoRoute(
          path: '/report-inventoryOnHand',
          pageBuilder: (context, state) => const MaterialPage(
            child: InventoryOnHandPage(),
          ),
        ),
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
        // 🆕 مسارات جديدة
        GoRoute(
          path: '/trend-analysis',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const TrendAnalysisReport(),
          ),
        ),
        GoRoute(
          path: '/supplier-analysis',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const SupplierAnalysisReport(),
          ),
        ),
        GoRoute(
          path: '/factory-performance',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const FactoryPerformanceReport(),
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
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const AdminUsersPage(),
    ),

  ],
);
