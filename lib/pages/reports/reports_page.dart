import 'package:easy_localization/easy_localization.dart';
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
