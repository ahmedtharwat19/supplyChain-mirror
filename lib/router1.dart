/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/pages/companies/company_added_page.dart';
//import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/factories/add_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/edit_factory_page.dart';
import 'package:puresip_purchasing/pages/factories/factories_page.dart';
import 'package:puresip_purchasing/pages/finished_products/finished_products_page.dart';
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
import 'package:puresip_purchasing/widgets/auth/user_license_request.dart';

// الصفحات
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

// مفتاح التنقل العام
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final _licenseService = LicenseService();

final GoRouter appRouter = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
//    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/companies',
        builder: (context, state) => const CompaniesPage(),
      ),
      GoRoute(
        path: '/add-company',
        builder: (context, state) => const AddCompanyPage(),
      ),
      GoRoute(
        path: '/edit-company/:id',
        builder: (context, state) {
          final companyId = state.pathParameters['id']!;
          return EditCompanyPage(companyId: companyId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          final allCards = state.extra as List<String>? ?? [];

          return SettingsPage(
            allCards: allCards,
          );
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
        path: '/suppliers',
        builder: (context, state) => const SuppliersPage(),
      ),
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
          // يمكنك إضافة تقارير أخرى هنا بنفس الطريقة
        ],
      ),
      GoRoute(
        path: '/add-supplier',
        builder: (context, state) => const AddSupplierPage(),
      ),
      GoRoute(
        path: '/edit-vendor/:id',
        builder: (context, state) {
          final supplierId = state.pathParameters['id']!;
          return EditSupplierPage(supplierId: supplierId);
        },
      ),
      GoRoute(
        path: '/stock_movements',
        name: 'stock_movements',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const StockMovementsPage(),
        ),
      ),
      GoRoute(
        path: '/inventory-query',
        name: 'inventory-query',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const InventoryQueryPage(),
        ),
      ),
      GoRoute(
        path: '/manufacturing_orders',
        name: 'manufacturing_orders',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const ManufacturingOrdersScreen(),
        ),
      ),
      GoRoute(
        path: '/finished_products',
        name: 'finished_products',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const FinishedProductsPage(),
        ),
      ),
      GoRoute(
        path: '/purchase-orders',
        builder: (context, state) => const PurchaseOrdersPage(),
      ),
      GoRoute(
        path: '/purchase/:id',
        name: 'purchase',
        builder: (context, state) {
          if (state.extra != null && state.extra is PurchaseOrder) {
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
      GoRoute(
        path: '/items',
        builder: (context, state) => const ItemsPage(),
      ),
      GoRoute(
        path: '/items/add',
        builder: (context, state) => const AddItemPage(),
      ),
      GoRoute(
        path: '/edit-item/:id',
        builder: (context, state) {
          final itemId = state.pathParameters['id']!;
          return EditItemPage(itemId: itemId);
        },
      ),
      GoRoute(
        path: '/factories',
        builder: (context, state) => const FactoriesPage(),
      ),
      GoRoute(
        path: '/add-factory',
        builder: (context, state) => const AddFactoryPage(),
      ),
      GoRoute(
        path: '/edit-factory/:id',
        builder: (context, state) {
          final factoryId = state.pathParameters['id']!;
          return EditFactoryPage(factoryId: factoryId);
        },
      ),
      GoRoute(
        path: '/license/request',
        builder: (context, state) => const UserLicenseRequestPage(),
      ),
      GoRoute(
        path: '/admin/licenses',
        builder: (context, state) => const AdminLicenseManagementPage(),
      ),
    ],

redirect: (context, state) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentPath = state.matchedLocation;

  // 1. شاشة البداية
  if (currentPath == '/splash') return null;

  // 2. المستخدم غير مسجل الدخول
  if (user == null) {
    return ['/login', '/signup'].contains(currentPath) ? null : '/login';
  }

  try {
    final isAdmin = await _checkIfAdmin(user.uid);

    // 3. الأدمن
    if (isAdmin) {
      final hasPendingRequests = await _hasLicenseRequests();
      if (currentPath == '/license/request') {
        return hasPendingRequests ? '/admin/licenses' : '/dashboard';
      }
      return null; // الأدمن له صلاحية الوصول لباقي الصفحات
    }

    // 4. المستخدم العادي
    final hasUserPendingRequest = await _hasUserLicenseRequest();
    if (hasUserPendingRequest && currentPath != '/license/request') {
      return '/license/request';
    }

    // تحقق من حالة الترخيص
    final licenseStatus = await _licenseService.getCurrentUserLicenseStatus();

    debugPrint('''
    Auth State:
    User: ${user.uid}
    Is Admin: $isAdmin
    License Valid: ${licenseStatus.isValid}
    Offline: ${licenseStatus.isOffline}
    Current Path: $currentPath
    ExpireDate is: ${licenseStatus.expiryDate}
    Days Left: ${licenseStatus.daysLeft}
    Reason: ${licenseStatus.reason}
    ''');

    final licenseExemptPaths = ['/license/request', '/logout'];

    // 5. السماح إذا الترخيص صالح
    if (licenseStatus.isValid) {
      if (currentPath == '/license/request') return '/dashboard';
      return null;
    }

    // 6. لو الترخيص غير صالح لكن أوفلاين وعندنا كاش → السماح
    if (licenseStatus.isOffline) {
      debugPrint("✅ Offline mode with cached license, staying on $currentPath");
      return null;
    }

    // 7. في حالة الترخيص منتهي أو مش موجود
    if (!licenseExemptPaths.contains(currentPath)) {
      return '/license/request';
    }

    // 8. منع الوصول لصفحات تسجيل الدخول بعد الدخول
    if (['/login', '/signup'].contains(currentPath)) {
      return '/dashboard';
    }

    return null;
  } catch (e) {
    debugPrint('Router Error: $e');
    return '/login';
  }
});

Future<bool> _checkIfAdmin(String userId) async {
  try {
    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!docSnapshot.exists) {
      debugPrint('[AdminCheck] User document does not exist: $userId');
      return false;
    }

    final data = docSnapshot.data();
    final isAdmin = data?['isAdmin'] == true;

    debugPrint('[AdminCheck] User $userId isAdmin: $isAdmin');
    return isAdmin;
  } catch (e, stack) {
    debugPrint('[AdminCheck] Error checking admin status: $e');
    debugPrint(stack.toString());
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
    debugPrint('User license request check failed: $e');
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
    debugPrint('License request check failed: $e');
    return false;
  }
}
 */