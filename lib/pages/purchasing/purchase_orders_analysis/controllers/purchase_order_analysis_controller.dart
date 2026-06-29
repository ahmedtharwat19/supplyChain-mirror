import 'package:puresip_purchasing/services/firestore_service.dart';

class PurchaseOrderAnalysisController {
  final FirestoreService firestoreService;

  PurchaseOrderAnalysisController(this.firestoreService);

  Future<Map<String, dynamic>> analyzeOrders(
    String userId, {
    String period = "monthly",
  }) async {
    // الـ Stream يتحول لـ List
    final orders = await firestoreService.getPurchaseOrders(userId).first;

    // فلترة حسب الفترة
    final now = DateTime.now();
    late DateTime fromDate;

    if (period == "daily") {
      fromDate = DateTime(now.year, now.month, now.day);
    } else if (period == "monthly") {
      fromDate = DateTime(now.year, now.month, 1);
    } else {
      fromDate = DateTime(now.year, 1, 1);
    }

    final filtered = orders.where((order) {
      return order.orderDate.isAfter(fromDate);
    }).toList();

    // إجمالي قيمة المشتريات
    final totalValue = filtered.fold<double>(
      0,
      (sum, item) => sum + (item.totalAmount),
    );

    // توزيع حسب الحالة
    final statusCount = <String, int>{};
    // توزيع حسب المورد
    final supplierTotals = <String, double>{};

    for (var order in filtered) {
      // الحالة
      final status = order.status;
      statusCount[status] = (statusCount[status] ?? 0) + 1;

      // المورد
      final supplier = order.supplierId;
      supplierTotals[supplier] =
          (supplierTotals[supplier] ?? 0) + order.totalAmount;
    }

    return {
      'totalValue': totalValue,
      'totalOrders': filtered.length,
      'avgOrderValue': filtered.isNotEmpty ? totalValue / filtered.length : 0,
      'statusCount': statusCount,
      'supplierTotals': supplierTotals,
    };
  }
}
