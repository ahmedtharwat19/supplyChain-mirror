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

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return AppScaffold(
      title: 'reports'.tr(),
      body: ListView(
        children: [
          // ✅ تقرير المخزون الراكد (جديد)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory_2, color: Colors.orange.shade800),
              ),
              title: Text(
                isArabic ? 'تقرير المخزون الراكد' : 'Slow Moving Inventory',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'الأصناف التي لم تتحرك منذ فترة طويلة'
                    : 'Items that haven\'t moved for a long time',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/slow-moving');
              },
            ),
          ),

          // تقرير المخزون
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory, color: Colors.blue.shade800),
              ),
              title: Text(
                isArabic ? 'تقرير المخزون' : 'Inventory Report',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'مستويات المخزون - دوران المخزون'
                    : 'Stock levels - Inventory turnover',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/report-inventory');
              },
            ),
          ),

          // تقرير صلاحية المخزون
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.timer, color: Colors.red.shade800),
              ),
              title: Text(
                isArabic ? 'تقرير صلاحية المخزون' : 'Expiry Report',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'المواد التي تنتهي صلاحيتها قريباً'
                    : 'Items expiring soon',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/expiry');
              },
            ),
          ),

          // تقرير الموردين
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.people, color: Colors.green.shade800),
              ),
              title: Text(
                isArabic ? 'تقرير الموردين' : 'Suppliers Report',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'أداء الموردين - الاعتمادية'
                    : 'Supplier performance - Reliability',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/report-suppliers');
              },
            ),
          ),
//تحليل اداء الموردين
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics, color: Colors.teal.shade800),
              ),
              title: Text(
                isArabic
                    ? 'تقرير أداء الموردين'
                    : 'Supplier Performance Report',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'تحليل أداء الموردين - التسليم في الوقت المحدد'
                    : 'Supplier performance analysis - On-time delivery',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/supplier-performance');
              },
            ),
          ),
// تقرير استهلاك المواد
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.show_chart, color: Colors.indigo.shade800),
              ),
              title: Text(
                isArabic
                    ? 'تقرير استهلاك المواد'
                    : 'Material Consumption Report',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'تحليل استهلاك المواد الخام خلال فترة زمنية'
                    : 'Raw material consumption analysis over time',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/consumption');
              },
            ),
          ),
          //,/ تقرير تحليل ABC
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.pie_chart, color: Colors.purple.shade800),
              ),
              title: Text(
                isArabic ? 'تحليل ABC للمخزون' : 'ABC Inventory Analysis',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'تصنيف الأصناف حسب القيمة (باريتو)'
                    : 'Classify items by value (Pareto analysis)',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/abc-analysis');
              },
            ),
          ),

          // تقرير المشتريات
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shopping_cart, color: Colors.purple.shade800),
              ),
              title: Text(
                isArabic ? 'تقرير المشتريات' : 'Procurement Report',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'طلبات الشراء - دورة الشراء'
                    : 'Purchase orders - Procurement cycle',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/purchase-orders-analysis');
              },
            ),
          ),
          // تقرير تحليل التكلفة
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.attach_money, color: Colors.deepPurple.shade800),
              ),
              title: Text(
                isArabic ? 'تحليل التكلفة' : 'Cost Analysis',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'تحليل تكاليف المشتريات والمخزون'
                    : 'Purchase and inventory cost analysis',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/cost-analysis');
              },
            ),
          ),

          /// تقرير حركات المخزون المتقدم
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.timeline, color: Colors.cyan.shade800),
              ),
              title: Text(
                isArabic
                    ? 'حركات المخزون المتقدمة'
                    : 'Advanced Stock Movements',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic
                    ? 'تحليل متقدم لحركات المخزون مع تصدير CSV'
                    : 'Advanced stock movements analysis with CSV export',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/reports/advanced-movements');
              },
            ),
          ),

          
        ],
      ),
    );
  }
}
