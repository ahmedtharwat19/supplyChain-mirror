/* import 'package:flutter/material.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrderService {
  static final _firestore = FirebaseFirestore.instance;
  static final _collection = _firestore.collection('purchase_orders');

  // إنشاء أمر شراء جديد
  Future<void> createPurchaseOrder(PurchaseOrder order) async {
    // await _collection.doc(order.id).set(order.toFirestore());
    try {
      safeDebugPrint('📦 Saving order: ${order.toFirestore()}');
      await _collection.doc(order.id).set(order.toFirestore());
      safeDebugPrint('✅ Order saved.');
    } catch (e) {
      safeDebugPrint('❌ Error saving order: $e');
      rethrow;
    }
  }

  // تحميل أمر شراء واحد
  static Future<PurchaseOrder?> getOrderById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return PurchaseOrder.fromFirestore(doc);
  }

  // تحديث أمر شراء
  static Future<void> updatePurchaseOrder(PurchaseOrder order) async {
    await _collection.doc(order.id).update(order.toFirestore());
  }

  // حذف أمر شراء
  static Future<void> deletePurchaseOrder(String id) async {
    await _collection.doc(id).delete();
  }

  // تحميل قائمة أوامر الشراء
  static Future<List<PurchaseOrder>> getAllOrders() async {
    final snapshot =
        await _collection.orderBy('orderDate', descending: true).get();
    return snapshot.docs
        .map((doc) => PurchaseOrder.fromFirestore(doc))
        .toList();
  }
}
 */


/* 

//import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_order.dart';
import 'firestore_service.dart'; // مهم: استيراد الخدمة
import 'package:puresip_purchasing/debug_helper.dart';

class PurchaseOrderRepository {
  static final _firestore = FirebaseFirestore.instance;
  static final _collection = _firestore.collection('purchase_orders');

  final FirestoreService _firestoreService = FirestoreService();

  // إنشاء أمر شراء جديد مع توليد poNumber تلقائيًا
  Future<void> createPurchaseOrder(PurchaseOrder order) async {
    try {
      // توليد رقم أمر شراء فريد بناءً على الشركة
      final generatedPoNumber = await _firestoreService.generatePoNumber(order.companyId);

      final orderWithPo = order.copyWith(
        poNumber: generatedPoNumber,
        orderDate: order.orderDate,
        id: _collection.doc().id, // إنشاء ID تلقائي
      );

      safeDebugPrint('📦 Saving order: ${orderWithPo.toFirestore()}');

      await _collection.doc(orderWithPo.id).set(orderWithPo.toFirestore());

      safeDebugPrint('✅ Order saved.');
    } catch (e) {
      safeDebugPrint('❌ Error saving order: $e');
      rethrow;
    }
  }

  // تحميل أمر شراء واحد
  static Future<PurchaseOrder?> getOrderById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return PurchaseOrder.fromFirestore(doc);
  }

  // تحديث أمر شراء
  static Future<void> updatePurchaseOrder(PurchaseOrder order) async {
    await _collection.doc(order.id).update(order.toFirestore());
  }

  // حذف أمر شراء
  static Future<void> deletePurchaseOrder(String id) async {
    await _collection.doc(id).delete();
  }

  // تحميل كل أوامر الشراء
  static Future<List<PurchaseOrder>> getAllOrders() async {
    final snapshot =
        await _collection.orderBy('orderDate', descending: true).get();
    return snapshot.docs
        .map((doc) => PurchaseOrder.fromFirestore(doc))
        .toList();
  }
}
 */