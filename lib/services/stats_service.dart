/* // services/stats_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ تحديث إحصائيات المستخدم في Firestore
  Future<void> updateUserStats(String userId) async {
    try {
      safeDebugPrint('📊 Updating user stats for: $userId');
      
      // 1. جلب شركات المستخدم أولاً
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
      final factoryIds = List<String>.from(userDoc.data()?['factoryIds'] ?? []);
      
      // 2. جلب الإحصائيات بالتوازي
      final results = await Future.wait([
        _firestore.collection('vendors').where('userId', isEqualTo: userId).count().get(),
        _firestore.collection('purchase_orders').where('userId', isEqualTo: userId).where('status', isEqualTo: 'pending').count().get(),
        _firestore.collection('items').where('userId', isEqualTo: userId).count().get(),
        _firestore.collection('manufacturing_orders').where('userId', isEqualTo: userId).count().get(),
        _firestore.collection('purchase_orders').where('userId', isEqualTo: userId).where('status', isEqualTo: 'pending').get(),
      ]);
      
      final suppliersCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
      final ordersCount = (results[1] as AggregateQuerySnapshot).count ?? 0;
      final itemsCount = (results[2] as AggregateQuerySnapshot).count ?? 0;
      final manufacturingCount = (results[3] as AggregateQuerySnapshot).count ?? 0;
      
      // 3. حساب إجمالي المبلغ
      double totalAmount = 0;
      final ordersSnapshot = results[4] as QuerySnapshot;
      for (var doc in ordersSnapshot.docs) {
        totalAmount += (doc['totalAmountAfterTax'] ?? doc['totalAmount'] ?? 0).toDouble();
      }
      
      // 4. عدد المصانع من factoryIds
      final factoriesCount = factoryIds.length;
      
      // 5. عدد المنتجات التامة
      int finishedCount = 0;
      for (final companyId in companyIds) {
        final count = await _firestore
            .collection('finished_products')
            .where('companyId', isEqualTo: companyId)
            .count()
            .get();
        finishedCount += (count).count ?? 0;
      }
      
      // 6. عدد حركات المخزون
      final movementsCount = await _firestore
          .collectionGroup('stock_movements')
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      final stockMovementsCount = (movementsCount).count ?? 0;
      
      // 7. ✅ حفظ الإحصائيات في وثيقة المستخدم (استخدام set مع merge)
      await _firestore.collection('users').doc(userId).set({
        'stats': {
          'totalSuppliers': suppliersCount,
          'totalOrders': ordersCount,
          'totalItems': itemsCount,
          'totalManufacturingOrders': manufacturingCount,
          'totalAmount': totalAmount,
          'totalFactories': factoriesCount,
          'totalFinishedProducts': finishedCount,
          'totalStockMovements': stockMovementsCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      
      safeDebugPrint('✅ User stats updated successfully');
    } catch (e) {
      safeDebugPrint('❌ Error updating user stats: $e');
    }
  }
  
  /// ✅ الحصول على إحصائيات المستخدم (قراءة واحدة فقط)
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final stats = userDoc.data()?['stats'] as Map<String, dynamic>? ?? {};
      
      // ✅ إذا لم توجد إحصائيات، قم بإنشائها
      if (stats.isEmpty) {
        await updateUserStats(userId);
        final updatedDoc = await _firestore.collection('users').doc(userId).get();
        final updatedStats = updatedDoc.data()?['stats'] as Map<String, dynamic>? ?? {};
        return {
          'totalSuppliers': updatedStats['totalSuppliers'] ?? 0,
          'totalOrders': updatedStats['totalOrders'] ?? 0,
          'totalItems': updatedStats['totalItems'] ?? 0,
          'totalManufacturingOrders': updatedStats['totalManufacturingOrders'] ?? 0,
          'totalAmount': (updatedStats['totalAmount'] ?? 0.0).toDouble(),
          'totalFactories': updatedStats['totalFactories'] ?? 0,
          'totalFinishedProducts': updatedStats['totalFinishedProducts'] ?? 0,
          'totalStockMovements': updatedStats['totalStockMovements'] ?? 0,
        };
      }
      
      return {
        'totalSuppliers': stats['totalSuppliers'] ?? 0,
        'totalOrders': stats['totalOrders'] ?? 0,
        'totalItems': stats['totalItems'] ?? 0,
        'totalManufacturingOrders': stats['totalManufacturingOrders'] ?? 0,
        'totalAmount': (stats['totalAmount'] ?? 0.0).toDouble(),
        'totalFactories': stats['totalFactories'] ?? 0,
        'totalFinishedProducts': stats['totalFinishedProducts'] ?? 0,
        'totalStockMovements': stats['totalStockMovements'] ?? 0,
      };
    } catch (e) {
      safeDebugPrint('Error getting user stats: $e');
      return {};
    }
  }
} */

// services/stats_service.dart - النسخة المعدلة

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ تحديث إحصائيات المستخدم في Firestore
  Future<void> updateUserStats(String userId) async {
    try {
      safeDebugPrint('📊 Updating user stats for: $userId');
      
      // 1. جلب شركات المستخدم أولاً
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
      final factoryIds = List<String>.from(userDoc.data()?['factoryIds'] ?? []);
      
      safeDebugPrint('📊 User $userId: Companies=${companyIds.length}, Factories=${factoryIds.length}');
      
      // 2. جلب الإحصائيات بالتوازي
      final results = await Future.wait([
        _firestore.collection('vendors').where('userId', isEqualTo: userId).count().get(),
        _firestore.collection('purchase_orders').where('userId', isEqualTo: userId).where('status', isEqualTo: 'pending').count().get(),
        _firestore.collection('items').where('userId', isEqualTo: userId).count().get(),
        _firestore.collection('manufacturing_orders').where('userId', isEqualTo: userId).count().get(),
        _firestore.collection('purchase_orders').where('userId', isEqualTo: userId).where('status', isEqualTo: 'pending').get(),
      ]);
      
      final suppliersCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
      final ordersCount = (results[1] as AggregateQuerySnapshot).count ?? 0;
      final itemsCount = (results[2] as AggregateQuerySnapshot).count ?? 0;
      final manufacturingCount = (results[3] as AggregateQuerySnapshot).count ?? 0;
      
      // 3. حساب إجمالي المبلغ
      double totalAmount = 0;
      final ordersSnapshot = results[4] as QuerySnapshot;
      for (var doc in ordersSnapshot.docs) {
        totalAmount += (doc['totalAmountAfterTax'] ?? doc['totalAmount'] ?? 0).toDouble();
      }
      
      // 4. عدد المصانع من factoryIds
      final factoriesCount = factoryIds.length;
      
      // 5. عدد المنتجات التامة
      int finishedCount = 0;
      for (final companyId in companyIds) {
        final count = await _firestore
            .collection('finished_products')
            .where('companyId', isEqualTo: companyId)
            .count()
            .get();
        finishedCount += (count).count ?? 0;
      }
      
      // 6. ✅ عدد حركات المخزون (لكل شركة على حدة)
      int stockMovementsCount = 0;
      for (final companyId in companyIds) {
        try {
          final snapshot = await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('stock_movements')
              .where('userId', isEqualTo: userId)
              .get();
          stockMovementsCount += snapshot.docs.length;
          safeDebugPrint('📊 Stock movements for company $companyId: ${snapshot.docs.length}');
        } catch (e) {
          safeDebugPrint('⚠️ Error counting stock movements for company $companyId: $e');
        }
      }
      safeDebugPrint('📊 Total Stock Movements: $stockMovementsCount');
      
      // 7. ✅ حفظ الإحصائيات في وثيقة المستخدم
      await _firestore.collection('users').doc(userId).set({
        'stats': {
          'totalSuppliers': suppliersCount,
          'totalOrders': ordersCount,
          'totalItems': itemsCount,
          'totalManufacturingOrders': manufacturingCount,
          'totalAmount': totalAmount,
          'totalFactories': factoriesCount,
          'totalFinishedProducts': finishedCount,
          'totalStockMovements': stockMovementsCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      
      safeDebugPrint('✅ User stats updated successfully');
    } catch (e) {
      safeDebugPrint('❌ Error updating user stats: $e');
    }
  }
  
  /// ✅ الحصول على إحصائيات المستخدم (قراءة واحدة فقط)
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final stats = userDoc.data()?['stats'] as Map<String, dynamic>? ?? {};
      
      // ✅ إذا لم توجد إحصائيات، قم بإنشائها
      if (stats.isEmpty) {
        await updateUserStats(userId);
        final updatedDoc = await _firestore.collection('users').doc(userId).get();
        final updatedStats = updatedDoc.data()?['stats'] as Map<String, dynamic>? ?? {};
        return {
          'totalSuppliers': updatedStats['totalSuppliers'] ?? 0,
          'totalOrders': updatedStats['totalOrders'] ?? 0,
          'totalItems': updatedStats['totalItems'] ?? 0,
          'totalManufacturingOrders': updatedStats['totalManufacturingOrders'] ?? 0,
          'totalAmount': (updatedStats['totalAmount'] ?? 0.0).toDouble(),
          'totalFactories': updatedStats['totalFactories'] ?? 0,
          'totalFinishedProducts': updatedStats['totalFinishedProducts'] ?? 0,
          'totalStockMovements': updatedStats['totalStockMovements'] ?? 0,
        };
      }
      
      return {
        'totalSuppliers': stats['totalSuppliers'] ?? 0,
        'totalOrders': stats['totalOrders'] ?? 0,
        'totalItems': stats['totalItems'] ?? 0,
        'totalManufacturingOrders': stats['totalManufacturingOrders'] ?? 0,
        'totalAmount': (stats['totalAmount'] ?? 0.0).toDouble(),
        'totalFactories': stats['totalFactories'] ?? 0,
        'totalFinishedProducts': stats['totalFinishedProducts'] ?? 0,
        'totalStockMovements': stats['totalStockMovements'] ?? 0,
      };
    } catch (e) {
      safeDebugPrint('Error getting user stats: $e');
      return {};
    }
  }
}