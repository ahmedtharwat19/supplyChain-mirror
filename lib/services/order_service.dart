import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';

class OrderService {
  static Future<PurchaseOrder?> getOrderById(String orderId) async {
    final doc = await FirebaseFirestore.instance
        .collection('purchase_orders')
        .doc(orderId)
        .get();
    
    if (doc.exists) {
      return PurchaseOrder.fromMap(doc);
    }
    return null;
  }

  static Future<void> updateOrder(PurchaseOrder order) async {
    await FirebaseFirestore.instance
        .collection('purchase_orders')
        .doc(order.id)
        .update(order.toMap());
  }
}