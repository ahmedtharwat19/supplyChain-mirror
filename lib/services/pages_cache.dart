// services/pages_cache.dart
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/pages/companies/companies_page.dart';
import 'package:puresip_purchasing/pages/suppliers/suppliers_page.dart';
import 'package:puresip_purchasing/pages/items/items_page.dart';
import 'package:puresip_purchasing/pages/purchasing/Purchasing_orders_crud/purchase_orders_page.dart';
import 'package:puresip_purchasing/pages/factories/factories_page.dart';
import 'package:puresip_purchasing/pages/reports/reports_page.dart';
import 'package:puresip_purchasing/pages/stock_movements/stock_movements_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/manufacturing_orders_screen.dart';
import 'package:puresip_purchasing/pages/finished_products/finished_products_page.dart';

class PagesCache {
  static final Map<String, Widget> _cache = {};
  
  // ✅ الحصول على صفحة من الكاش أو إنشاؤها
  static Widget getPage(String route) {
    if (!_cache.containsKey(route)) {
      _cache[route] = _createPage(route);
    }
    return _cache[route]!;
  }
  
  static Widget _createPage(String route) {
    switch (route) {
      case '/companies':
        return const CompaniesPage();
      case '/suppliers':
        return const SuppliersPage();
      case '/items':
        return const ItemsPage();
      case '/purchase-orders':
        return const PurchaseOrdersPage();
      case '/factories':
        return const FactoriesPage();
      case '/reports':
        return const ReportsPage();
      case '/stock_movements':
        return const StockMovementsPage();
      case '/manufacturing_orders':
        return const ManufacturingOrdersScreen();
      case '/finished_products':
        return const FinishedProductsPage();
      default:
        return const SizedBox();
    }
  }
  
  // ✅ مسح الكاش (عند تسجيل الخروج)
  static void clearCache() {
    _cache.clear();
  }
}