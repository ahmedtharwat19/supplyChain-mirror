import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // التحقق من توفر المخزون لجميع المواد
  Future<bool> checkSufficientStock(List<RawMaterial> materials, int quantity) async {
    try {
      for (final material in materials) {
        final requiredQuantity = material.quantityRequired * quantity;
        final currentStock = await getCurrentStock(material.materialId);
        
        if (currentStock < requiredQuantity) {
          return false;
        }
      }
      return true;
    } catch (e) {
      throw Exception('Failed to check stock: $e');
    }
  }

  // الحصول على مستوى المخزون الحالي لمادة محددة
  Future<double> getCurrentStock(String materialId) async {
    try {
      final doc = await _firestore.collection('inventory').doc(materialId).get();
      return (doc.data()?['quantity'] ?? 0).toDouble();
    } catch (e) {
      throw Exception('Failed to get current stock: $e');
    }
  }

  // الحصول على مستويات المخزون لعدة مواد
  Stream<Map<String, double>> getCurrentStockLevels(List<String> materialIds) {
    return _firestore.collection('inventory')
      .where(FieldPath.documentId, whereIn: materialIds)
      .snapshots()
      .map((snapshot) {
        final levels = <String, double>{};
        for (final doc in snapshot.docs) {
          levels[doc.id] = (doc.data()['quantity'] ?? 0).toDouble();
        }
        return levels;
      });
  }

  // خصم كمية من المخزون
  Future<void> deductFromInventory(String materialId, double quantity, String batchNumber) async {
    try {
      final batch = _firestore.batch();
      
      // تحديث جدول المخزون
      final inventoryRef = _firestore.collection('inventory').doc(materialId);
      batch.update(inventoryRef, {
        'quantity': FieldValue.increment(-quantity),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // إضافة حركة مخزون للخصم
      final movementRef = _firestore.collection('stock_movements').doc();
      batch.set(movementRef, {
        'id': movementRef.id,
        'itemId': materialId,
        'itemName': await _getMaterialName(materialId),
        'quantity': -quantity,
        'type': 'manufacturing_deduction',
        'batchNumber': batchNumber,
        'date': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'companyId': await _getMaterialCompanyId(materialId),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to deduct from inventory: $e');
    }
  }

  // الحصول على اسم المادة
  Future<String> _getMaterialName(String materialId) async {
    final doc = await _firestore.collection('materials').doc(materialId).get();
    return doc.data()?['name'] ?? materialId;
  }

  // الحصول على companyId للمادة
  Future<String> _getMaterialCompanyId(String materialId) async {
    final doc = await _firestore.collection('materials').doc(materialId).get();
    return doc.data()?['companyId'] ?? 'default_company';
  }
}