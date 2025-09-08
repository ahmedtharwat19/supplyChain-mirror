//import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class DashboardMetric {
  final String titleKey; // مفتاح الترجمة للعنوان
  final String Function(Map<String, dynamic>)
      valueBuilder; // دالة لتحويل البيانات إلى نص عرض
  final IconData icon;
  final Color color;
  final String route; // المسار الذي ينتقل إليه عند الضغط
  final double Function(Map<String, dynamic>)
      progressBuilder; // دالة لحساب نسبة التقدم
  final String  defaultMenuType;

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

// قائمة العناصر التي سيتم عرضها في لوحة التحكم
final List<DashboardMetric> dashboardMetrics = [
  DashboardMetric(
    titleKey: 'totalCompanies',
    valueBuilder: (data) => (data['totalCompanies'] ?? 0).toString(),
    icon: Icons.business,
    color: Colors.blue,
    route: '/companies',
    progressBuilder: (data) {
      final value = (data['totalCompanies'] ?? 0) as int;
      final max = 100; // مثلا الحد الأعلى لتدرج النسبة
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'short', // short, long, أو custom
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
    defaultMenuType: 'short', // short, long, أو custom
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
    defaultMenuType: 'short', // short, long, أو custom
  ),
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
    defaultMenuType: 'long', // short, long, أو custom
  ),
  // أضف باقي العناصر بنفس النمط حسب البيانات التي لديك
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
    defaultMenuType: 'long', // short, long, أو custom
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
    defaultMenuType: 'long', // short, long, أو custom
  ),
    DashboardMetric(
    titleKey: 'inventory_query',
    valueBuilder: (data) => (data['totalStockMovements'] ?? 0).toString(),
    icon: Icons.move_to_inbox,
    color: Colors.cyan,
    route: '/inventory-query',
    progressBuilder: (data) {
      final value = (data['totalStockMovements'] ?? 0) as int;
      final max = 300;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long', // short, long, أو custom
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
    defaultMenuType: 'long', // short, long, أو custom
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
    defaultMenuType: 'short', // short, long, أو custom
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
    defaultMenuType: 'long', // short, long, أو custom
  ),
    DashboardMetric(
    titleKey: 'reports',
    valueBuilder: (data) => (data['reports'] ?? 0).toString(),
    icon: Icons.query_stats,
    color: Colors.red,
    route: '/reports',
    progressBuilder: (data) {
      final value = (data['reports'] ?? 0) as int;
      final max = 50;
      return (value / max).clamp(0.0, 1.0);
    },
    defaultMenuType: 'long', // short, long, أو custom
  ),
];
