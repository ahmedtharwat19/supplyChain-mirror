// lib/pages/dashboard/dashboard_metrics.dart
import 'package:flutter/material.dart';

class DashboardMetric {
  final String titleKey;
  final String Function(Map<String, dynamic>) valueBuilder;
  final IconData icon;
  final Color color;
  final String route;
  final double Function(Map<String, dynamic>) progressBuilder;
  final String defaultMenuType;

  DashboardMetric({
    required this.titleKey,
    required this.valueBuilder,
    required this.icon,
    required this.color,
    required this.route,
    required this.progressBuilder,
    required this.defaultMenuType,
  });
}

// ✅ قائمة بسيطة وواضحة - لا ديناميكية معقدة
final List<DashboardMetric> dashboardMetrics = [
  // ==================== عرض قصير (Short) ====================
  DashboardMetric(
    titleKey: 'totalCompanies',
    valueBuilder: (data) => (data['totalCompanies'] ?? 0).toString(),
    icon: Icons.business,
    color: Colors.blue,
    route: '/companies',
    progressBuilder: (data) {
      final value = (data['totalCompanies'] ?? 0) as int;
      final max = 100;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'short',
  ),
  DashboardMetric(
    titleKey: 'totalSuppliers',
    valueBuilder: (data) => (data['totalSuppliers'] ?? 0).toString(),
    icon: Icons.local_shipping,
    color: Colors.green,
    route: '/suppliers',
    progressBuilder: (data) {
      final value = (data['totalSuppliers'] ?? 0) as int;
      final max = 100;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'short',
  ),
  DashboardMetric(
    titleKey: 'totalOrders',
    valueBuilder: (data) => (data['totalOrders'] ?? 0).toString(),
    icon: Icons.shopping_cart,
    color: Colors.orange,
    route: '/purchase-orders',
    progressBuilder: (data) {
      final value = (data['totalOrders'] ?? 0) as int;
      final max = 1000;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'short',
  ),
  DashboardMetric(
    titleKey: 'totalFinishedProducts',
    valueBuilder: (data) => (data['totalFinishedProducts'] ?? 0).toString(),
    icon: Icons.check_circle_outline,
    color: Colors.deepPurple,
    route: '/finished_products',
    progressBuilder: (data) {
      final value = (data['totalFinishedProducts'] ?? 0) as int;
      final max = 400;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'short',
  ),

  // ==================== عرض طويل (Long) ====================
  DashboardMetric(
    titleKey: 'totalAmount',
    valueBuilder: (data) => (data['totalAmount'] ?? 0.0).toStringAsFixed(2),
    icon: Icons.attach_money,
    color: Colors.purple,
    route: '/purchase-orders',
    progressBuilder: (data) {
      final value = (data['totalAmount'] ?? 0.0) as double;
      final max = 100000.0;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ),
  DashboardMetric(
    titleKey: 'totalItems',
    valueBuilder: (data) => (data['totalItems'] ?? 0).toString(),
    icon: Icons.inventory_2,
    color: Colors.teal,
    route: '/items',
    progressBuilder: (data) {
      final value = (data['totalItems'] ?? 0) as int;
      final max = 500;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ),
  DashboardMetric(
    titleKey: 'totalStockMovements',
    valueBuilder: (data) => (data['totalStockMovements'] ?? 0).toString(),
    icon: Icons.move_to_inbox,
    color: Colors.cyan,
    route: '/stock_movements',
    progressBuilder: (data) {
      final value = (data['totalStockMovements'] ?? 0) as int;
      final max = 300;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ),
/*   DashboardMetric(
    titleKey: 'inventory_query',
    valueBuilder: (data) => (data['totalInventoryItems'] ?? 0).toString(),
    icon: Icons.search,
    color: Colors.lightBlue,
    route: '/inventory-query',
    progressBuilder: (data) {
      final value = (data['totalInventoryItems'] ?? '') as int;
      final max = 500;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ), */
  DashboardMetric(
    titleKey: 'inventory_query',
    // ✅ النص الظاهر: يعرض مسافة فارغة " " بدلاً من 0 إذا كانت البيانات غير موجودة
    valueBuilder: (data) {
      final val = data['totalInventoryItems'];
      return (val != null) ? val.toString() : " ";
    },
    icon: Icons.search,
    color: Colors.lightBlue,
    route: '/inventory-query',
    // ✅ شريط التقدم: يحسب النسبة بناءً على 0 داخلياً لمنع انهيار النوع (Type Mismatch)
    progressBuilder: (data) {
      final num value = (data['totalInventoryItems'] as num?) ?? 0;
      final max = 500;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ),

  DashboardMetric(
    titleKey: 'totalManufacturingOrders',
    valueBuilder: (data) => (data['totalManufacturingOrders'] ?? 0).toString(),
    icon: Icons.precision_manufacturing,
    color: Colors.amber,
    route: '/manufacturing_orders',
    progressBuilder: (data) {
      final value = (data['totalManufacturingOrders'] ?? 0) as int;
      final max = 200;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ),
  DashboardMetric(
    titleKey: 'totalFactories',
    valueBuilder: (data) => (data['totalFactories'] ?? 0).toString(),
    icon: Icons.factory,
    color: Colors.brown,
    route: '/factories',
    progressBuilder: (data) {
      final value = (data['totalFactories'] ?? 0) as int;
      final max = 50;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ),
  
  // ✅ بطاقة التقارير - واحدة فقط
/*   DashboardMetric(
    titleKey: 'reports',
    valueBuilder: (data) => (data['totalReports'] ?? 8).toString(),
    icon: Icons.query_stats,
    color: Colors.red,
    route: '/reports',
    progressBuilder: (data) {
      final value = (data['totalReports'] ?? 8) as int;
      final max = 20;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ), */

  DashboardMetric(
    titleKey: 'reports',
    // ✅ النص الظاهر على الشاشة: إذا لم تكن القيمة موجودة سيظهر نص فارغ " " بدلاً من 0
    valueBuilder: (data) {
      final val = data['totalReports'];
      return (val != null) ? val.toString() : " ";
    },
    icon: Icons.query_stats,
    color: Colors.red,
    route: '/reports',
    // شريط التقدم: يحسب النسبة بشكل آمن برقم 0 داخلياً لمنع الانهيار
    progressBuilder: (data) {
      final num value = (data['totalReports'] as num?) ?? 0;
      final max = 20;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long',
  ),
];

