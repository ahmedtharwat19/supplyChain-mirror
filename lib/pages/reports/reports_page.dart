/* import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
     title: 'reports'.tr(),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text("Inventory Report"),
            subtitle: const Text("مستويات المخزون - دوران المخزون"),
            onTap: () {
              context.go('/reports/report-inventory');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text("Suppliers Report"),
            subtitle: const Text("أداء الموردين - الاعتمادية"),
            onTap: () {
             context.go('/reports/report-suppliers');
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text("Procurement Report"),
            subtitle: const Text("طلبات الشراء - دورة الشراء"),
            onTap: () {
              //Navigator.pushNamed(context, '/report-purchase-orders');
               context.go('/reports/purchase-orders-analysis');
            },
          ),
        ],
      ),
    );
  }
}
 */

// lib/pages/reports/reports_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/purchasing/purchase_orders_analysis/pages/purchase_orders_analysis_page.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

// ✅ استيراد جميع التقارير
import 'abc_analysis_report.dart';
import 'advanced_stock_movements_report.dart';
import 'consumption_report.dart';
import 'cost_analysis_report.dart';
import 'expiry_report.dart';
import 'factory_performance_report.dart';
import 'inventory_report_page.dart';
import 'slow_moving_report.dart';
import 'supplier_analysis_report.dart';
import 'supplier_performance_report.dart';
import 'trend_analysis_report.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  // ✅ قائمة جميع التقارير
  static const List<ReportItem> _reports = [
    ReportItem(
      titleKey: 'inventory_report',
      subtitleKey: 'inventory_report_desc',
      icon: Icons.inventory,
      color: Colors.blue,
      route: '/reports/report-inventory',
      widget: InventoryAnalysisPage(),
    ),
/*     ReportItem(
      titleKey: 'inventory_on_hand',
      subtitleKey: 'inventory_on_hand_desc',
      icon: Icons.inventory_2,
      color: Colors.teal,
      route: '/reports/report-inventoryOnHand',
      widget: InventoryOnHandPage(),
    ), */
    ReportItem(
      titleKey: 'slow_moving_inventory',
      subtitleKey: 'slow_moving_inventory_desc',
      icon: Icons.inventory_2_outlined,
      color: Colors.orange,
      route: '/reports/slow-moving',
      widget: SlowMovingReport(),
    ),
    ReportItem(
      titleKey: 'expiry_report',
      subtitleKey: 'expiry_report_desc',
      icon: Icons.timer,
      color: Colors.red,
      route: '/reports/expiry',
      widget: ExpiryReport(),
    ),
    ReportItem(
      titleKey: 'abc_analysis',
      subtitleKey: 'abc_analysis_desc',
      icon: Icons.pie_chart,
      color: Colors.purple,
      route: '/reports/abc-analysis',
      widget: AbcAnalysisReport(),
    ),
    ReportItem(
      titleKey: 'consumption_report',
      subtitleKey: 'consumption_report_desc',
      icon: Icons.show_chart,
      color: Colors.indigo,
      route: '/reports/consumption',
      widget: ConsumptionReport(),
    ),
    ReportItem(
      titleKey: 'trend_analysis',
      subtitleKey: 'trend_analysis_desc',
      icon: Icons.trending_up,
      color: Colors.amber,
      route: '/reports/trend-analysis',
      widget: TrendAnalysisReport(),
    ),
    ReportItem(
      titleKey: 'cost_analysis',
      subtitleKey: 'cost_analysis_desc',
      icon: Icons.attach_money,
      color: Colors.deepPurple,
      route: '/reports/cost-analysis',
      widget: CostAnalysisReport(),
    ),
    ReportItem(
      titleKey: 'purchase_orders_analysis',
      subtitleKey: 'purchase_orders_analysis_desc',
      icon: Icons.shopping_cart,
      color: Colors.pink,
      route: '/reports/purchase-orders-analysis',
      widget: PurchaseOrdersAnalysisPage(),
    ),
    ReportItem(
      titleKey: 'supplier_performance',
      subtitleKey: 'supplier_performance_desc',
      icon: Icons.people,
      color: Colors.green,
      route: '/reports/supplier-performance',
      widget: SupplierPerformanceReport(),
    ),
    ReportItem(
      titleKey: 'supplier_analysis',
      subtitleKey: 'supplier_analysis_desc',
      icon: Icons.analytics,
      color: Colors.teal,
      route: '/reports/supplier-analysis',
      widget: SupplierAnalysisReport(),
    ),
    ReportItem(
      titleKey: 'advanced_stock_movements',
      subtitleKey: 'advanced_stock_movements_desc',
      icon: Icons.timeline,
      color: Colors.cyan,
      route: '/reports/advanced-movements',
      widget: AdvancedStockMovementsReport(),
    ),
    ReportItem(
      titleKey: 'factory_performance',
      subtitleKey: 'factory_performance_desc',
      icon: Icons.factory,
      color: Colors.brown,
      route: '/reports/factory-performance',
      widget: FactoryPerformanceReport(),
    ),
  ];

  // ✅ عدد التقارير
  static int get totalCount => _reports.length;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'reports'.tr(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: _reports.map((report) {
          return _buildReportCard(
            context,
            icon: report.icon,
            color: report.color,
            titleKey: report.titleKey,
            subtitleKey: report.subtitleKey,
            route: report.route,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String titleKey,
    required String subtitleKey,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color.withValues(alpha: 0.8)),
        ),
        title: Text(
          titleKey.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitleKey.tr(),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: () => context.go(route),
      ),
    );
  }
}

// ✅ نموذج للتقرير
class ReportItem {
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final Color color;
  final String route;
  final Widget widget;

  const ReportItem({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.color,
    required this.route,
    required this.widget,
  });
}
