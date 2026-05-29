/* import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_order.dart';

class OrderService {
  static Future<PurchaseOrder> getOrderById(String id) async {
    final doc = await FirebaseFirestore.instance
        .collection('purchase_orders')
        .doc(id)
        .get();
    
    return PurchaseOrder.fromFirestore(doc);
  }
} */