import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';

class PurchaseOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ إنشاء أمر شراء جديد
  Future<void> createPurchaseOrder(PurchaseOrder order) async {
    await _firestore.collection('purchase_orders').doc(order.id).set(order.toMap());
  }

  // ✅ تحديث أمر شراء
  Future<void> updatePurchaseOrder(PurchaseOrder order) async {
    await _firestore.collection('purchase_orders').doc(order.id).update(order.toMap());
  }

  // ✅ جلب أمر شراء بواسطة ID
  static Future<PurchaseOrder?> getOrderById(String orderId) async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('purchase_orders').doc(orderId).get();
    if (doc.exists) {
      return PurchaseOrder.fromMap(doc);
    }
    return null;
  }

  // ✅ جلب قائمة أوامر الشراء لمستخدم معين
  Stream<List<PurchaseOrder>> getUserOrders(String userId) {
    return _firestore
        .collection('purchase_orders')
        .where('userId', isEqualTo: userId)
        .orderBy('orderDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PurchaseOrder.fromMap(doc))
            .toList());
  }

  // ✅ حذف أمر شراء
  Future<void> deleteOrder(String orderId) async {
    await _firestore.collection('purchase_orders').doc(orderId).delete();
  }
}