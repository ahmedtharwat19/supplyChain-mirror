import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/pages/manufacturing/add_manufacturing_order_screen.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class ManufacturingOrdersScreen extends StatefulWidget {
  const ManufacturingOrdersScreen({super.key});

  @override
  State<ManufacturingOrdersScreen> createState() =>
      _ManufacturingOrdersScreenState();
}

class _ManufacturingOrdersScreenState extends State<ManufacturingOrdersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
//  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final manufacturingService = Provider.of<ManufacturingService>(context);

    return AppScaffold(
      title: 'manufacture.orders'.tr(),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'manufacture.add_order'.tr(),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddManufacturingOrderScreen(),
              ),
            );
          },
        ),
      ],
      body: StreamBuilder<List<ManufacturingOrder>>(
        stream: manufacturingService.getManufacturingOrders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${'error'.tr()}: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return Center(child: Text('no_data'.tr()));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(context, order, manufacturingService);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, ManufacturingOrder order,
      ManufacturingService service) {
    final ManufacturingRun? run = order.runs.isNotEmpty ? order.runs.first : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
      child: ListTile(
        title: Text(order.productName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'manufacture.batch_number'.tr()}: ${run?.batchNumber ?? '-'}'),
            Text('${'manufacture.quantity'.tr()}: ${run?.quantity ?? 0} ${order.productUnit}'),
            Text('${'manufacture.status'.tr()}: ${order.statusText}'),
            Text('${'manufacture.expiry_date'.tr()}: ${_formatDate(order.expiryDate)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (order.status == ManufacturingStatus.pending)
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                tooltip: 'manufacture.start_manufacturing'.tr(),
                onPressed: () => _startManufacturing(order, service),
              ),
            if (order.status == ManufacturingStatus.inProgress)
              IconButton(
                icon: const Icon(Icons.check, color: Colors.blue),
                tooltip: 'manufacture.complete_manufacturing'.tr(),
                onPressed: () => _completeManufacturing(order, service, run),
              ),
            // يمكنك إضافة أزرار أخرى إذا لزم الأمر
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _startManufacturing(ManufacturingOrder order, ManufacturingService service) async {
    try {
      await service.deductRawMaterials(order.rawMaterials, order.totalQuantity, order.runs.first.batchNumber);
      await service.updateOrderStatus(order.id, ManufacturingStatus.inProgress);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacture.manufacturing_started'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e')),
        );
      }
    }
  }

  void _completeManufacturing(ManufacturingOrder order, ManufacturingService service, ManufacturingRun? run) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
/* 
      final companyId = await _getUserCompanyId(user.uid);
      final factoryId = await _getUserFactoryId(user.uid);

      final finishedProduct = FinishedProduct(
        id: null,
        nameEn: order.productName,  // استخدم productName فقط لأنه غير موجود لديك productNameEn
        nameAr: order.productName,  // أو أضف خاصية جديدة للمنتج إن أردت
        quantity: (run?.quantity ?? 0).toDouble(),
        unit: order.productUnit,
        companyId: companyId,
        factoryId: factoryId,
        userId: user.uid,
        createdAt: Timestamp.now(),
        barCode: order.barcodeUrl ?? '', // هذا الحقل مطلوب بناءً على رسالة الخطأ التي ذكرتها
        isValid: true, // أو حسب منطقك
      );
 */
   //   await service.addFinishedProductToInventory(finishedProduct);
      await service.updateOrderStatus(order.id, ManufacturingStatus.completed);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacture.manufacturing_completed'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e')),
        );
      }
    }
  }

/*   Future<String> _getUserCompanyId(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final companyIds = userData['companyIds'] as List<dynamic>?;
        if (companyIds != null && companyIds.isNotEmpty) {
          return companyIds.first.toString();
        }
      }
      return 'default_companyId';
    } catch (e) {
      return 'default_companyId';
    }
  }

  Future<String> _getUserFactoryId(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final factoryIds = userData['factoryIds'] as List<dynamic>?;
        if (factoryIds != null && factoryIds.isNotEmpty) {
          return factoryIds.first.toString();
        }
      }
      return 'default_factoryId';
    } catch (e) {
      return 'default_factoryId';
    }
  }
 */
}
