import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class ManufacturingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // دالة جديدة لإنشاء order من Map
  Future<void> createManufacturingOrderFromMap(Map<String, dynamic> orderData) async {
    try {
      final docRef = _firestore.collection('manufacturing_orders').doc();
      orderData['id'] = docRef.id;
      
      await docRef.set(orderData);
      safeDebugPrint('Manufacturing order created successfully with ID: ${docRef.id}');
    } catch (e) {
      safeDebugPrint('Error creating manufacturing order: $e');
      rethrow;
    }
  }

  // الدالة الأصلية - معدلة لإنشاء order جديد بدون تعيين id مباشرة
  Future<void> createManufacturingOrder(ManufacturingOrder order) async {
    try {
      final docRef = _firestore.collection('manufacturing_orders').doc();
      
      // إنشاء order جديد مع ID الصحيح
      final newOrder = order.copyWith(id: docRef.id);
      
      await docRef.set(newOrder.toMap());
      safeDebugPrint('Manufacturing order created successfully with ID: ${docRef.id}');
    } catch (e) {
      safeDebugPrint('Error creating manufacturing order: $e');
      rethrow;
    }
  }

  Stream<List<ManufacturingOrder>> getManufacturingOrders() {
    return _firestore.collection('manufacturing_orders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ManufacturingOrder.fromMap(doc.data()..['id'] = doc.id);
      }).toList();
    });
  }

  Future<void> updateOrderStatus(String orderId, ManufacturingStatus status) async {
    await _firestore.collection('manufacturing_orders').doc(orderId).update({
      'status': status.toString().split('.').last,
    });
  }

  Future<void> deductRawMaterials(List<RawMaterial> materials, int totalQuantity, String batchNumber) async {
    // منطق خصم المواد الخام
  }

  Future<void> addFinishedProductToInventory(FinishedProduct product) async {
    await _firestore.collection('finished_products_inventory').add(product.toMap());
  }

  Future<void> updateRunCompletion(String orderId, String batchNumber, DateTime completedAt) async {
    final docRef = _firestore.collection('manufacturing_orders').doc(orderId);

    final orderSnapshot = await docRef.get();
    if (!orderSnapshot.exists) return;

    final orderData = orderSnapshot.data()!;
    List<dynamic> runs = orderData['runs'] ?? [];

    final updatedRuns = runs.map((run) {
      if (run['batchNumber'] == batchNumber) {
        run['completedAt'] = Timestamp.fromDate(completedAt);
      }
      return run;
    }).toList();

    await docRef.update({'runs': updatedRuns});
  }

  Stream<List<ManufacturingOrder>> getExpiringProducts() {
    throw UnimplementedError();
  }

  Stream<List<RawMaterial>> getLowStockMaterials() {
    throw UnimplementedError();
  }
  

  Future<void> startManufacturingWithComposition({
  required String companyId,
  required String factoryId,
  required String productId,
  required int totalQuantity,
  required String batchNumber,
  required String userId,
  required BuildContext context,
}) async {
  final localContext = context;
  final firestore = FirebaseFirestore.instance;
final bool isArabic = Localizations.localeOf(localContext).languageCode == 'ar';
  try {
    // 1. جلب تركيب المنتج (composition)
    final compDoc = await firestore
        .collection('finished_products')
        .doc(productId)
        .collection('composition')
        .doc('data')
        .get();

    if (!compDoc.exists) {
      if (!localContext.mounted) return;
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(content: Text('manufacturing.composition_not_found'.tr())),
      );
      return;
    }

    final compData = compDoc.data()!;
    final batchSize = (compData['batchSize'] as num?)?.toDouble() ?? 1.0;

    // 2. تجميع بيانات المواد المطلوبة (الخام + التعبئة)
    final List<Map<String, dynamic>> requiredMaterials = [];

    // المواد الخام
    final rawMaterials = List<Map<String, dynamic>>.from(
        compData['rawMaterials'] ?? []);
    for (final raw in rawMaterials) {
      requiredMaterials.add({
        'itemId': raw['itemId']?.toString() ?? '',
        'itemType': 'raw',
        'requiredQuantity': (raw['quantity'] ?? 0).toDouble() * totalQuantity,// / batchSize,
        'unit': raw['unit']?.toString() ?? '',
      });
    }

    // مواد التعبئة والتغليف
    final packagingMaterials = List<Map<String, dynamic>>.from(
        compData['packagingMaterials'] ?? []);
    for (final pack in packagingMaterials) {
      requiredMaterials.add({
        'itemId': pack['itemId']?.toString() ?? '',
        'itemType': 'packaging',
        'requiredQuantity': (pack['quantity'] ?? 0).toDouble() * totalQuantity,// / batchSize,
        'unit': pack['unit']?.toString() ?? '',
      });
    }

    // 3. جلب أسماء المواد من جدول items
    for (var material in requiredMaterials) {
      final itemId = material['itemId'];
      if (itemId.isNotEmpty) {
        final itemDoc = await firestore.collection('items').doc(itemId).get();
        if (itemDoc.exists) {
          final itemData = itemDoc.data()!;
        //  final isArabic = Localizations.localeOf(localContext).languageCode == 'ar';
          material['itemName'] = isArabic 
              ? (itemData['nameAr'] ?? itemData['nameEn'] ?? 'Unknown')
              : (itemData['nameEn'] ?? itemData['nameAr'] ?? 'Unknown');
        } else {
          material['itemName'] = 'Unknown';
        }
      }
    }

    // 4. جلب الكميات المتوفرة لكل مادة
    for (var material in requiredMaterials) {
      final itemId = material['itemId'];
      if (itemId.isNotEmpty) {
        final invSnap = await firestore
            .collection('factories/$factoryId/inventory')
            .doc(itemId)
            .get();
        final avail = invSnap.exists
            ? (invSnap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
            : 0.0;
        material['availableQuantity'] = avail;
      }
    }

    // 5. التحقق مما إذا كان الـ context لا يزال mounted قبل showDialog
    if (!localContext.mounted) return;
    
    // 6. عرض Dialog يوضح المواد المطلوبة والمتوفرة
    final shouldProceed = await showDialog<bool>(
      context: localContext,
      builder: (ctx) {
        return AlertDialog(
          title: Text('manufacturing.required_materials'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: requiredMaterials.map((mat) {
                final requiredQty = mat['requiredQuantity'] ?? 0;
                final availQty = mat['availableQuantity'] ?? 0;
                final shortage = availQty < requiredQty;
                return ListTile(
                  title: Text(mat['itemName'] ?? mat['itemId']),
                  subtitle: Text(
                    '${'manufacturing.required'.tr()}: ${requiredQty.toStringAsFixed(2)} ${mat['unit']} | '
                    '${'manufacturing.available'.tr()}: ${availQty.toStringAsFixed(2)}'
                  ),
                  trailing: shortage 
                      ? const Icon(Icons.warning, color: Colors.red) 
                      : const Icon(Icons.check, color: Colors.green),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), 
              child: Text('cancel'.tr())
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: Text('manufacturing.confirm'.tr())
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;

    // 7. تحضير Batch للكتابة في stock_movements
    final batch = firestore.batch();
    final stockMovRef = firestore.collection('companies/$companyId/stock_movements');

    // 8. جلب اسم المنتج من finished_products
  //  String productName = '';
    final productDoc = await firestore.collection('finished_products').doc(productId).get();
    if (productDoc.exists) {
    //  final productData = productDoc.data()!;
     // final isArabic = Localizations.localeOf(localContext).languageCode == 'ar';
      // productName = isArabic 
      //     ? (productData['nameAr'] ?? productData['nameEn'] ?? 'Unknown Product')
      //     : (productData['nameEn'] ?? productData['nameAr'] ?? 'Unknown Product');
    }

    for (var material in requiredMaterials) {
      final itemId = material['itemId'];
      final qty = material['requiredQuantity'] as double;
      final itemName = material['itemName'] ?? '';

      if (itemId.isNotEmpty && qty > 0) {
        // إنشاء سجل حركة مخزنية
        final newMovRef = stockMovRef.doc();
        batch.set(newMovRef, {
          'type': 'manufacturing_deduction',
         // 'productId': productId,
         // 'productName': productName,
          'itemId': itemId,
        //  'itemName': itemName,
          'quantity': qty,
          'date': FieldValue.serverTimestamp(),
          'referenceId': newMovRef.id,
          'userId': userId,
          'factoryId': factoryId,
       //   'companyId': companyId,
       //   'batchNumber': batchNumber,
        //  'movementType': 'out',
        //  'description': 'Manufacturing deduction for product $productName',
      //    'unit': material['unit'],
        });

        // تحديث المخزون في المصنع
        final invDocRef = firestore.doc('factories/$factoryId/inventory/$itemId');
        batch.set(invDocRef, {
          'quantity': FieldValue.increment(-qty),
          'lastUpdated': FieldValue.serverTimestamp(),
          'itemName': itemName,
        }, SetOptions(merge: true));
      }
    }

    // 9. تنفيذ العمليات دفعة واحدة
    await batch.commit();

    // 10. البحث عن أمر التصنيع باستخدام productId و factoryId و batchNumber في runs
    final manufacturingOrdersQuery = await _firestore.collection('manufacturing_orders')
        .where('productId', isEqualTo: productId)
        .where('factoryId', isEqualTo: factoryId)
        .get();

    ManufacturingOrder? targetOrder;
    String? orderId;

    for (final orderDoc in manufacturingOrdersQuery.docs) {
      final orderData = orderDoc.data();
      final runs = orderData['runs'] as List<dynamic>? ?? [];
      
      // البحث عن التشغيل الذي يحتوي على batchNumber المطلوب
      final hasMatchingRun = runs.any((run) => run['batchNumber'] == batchNumber);
      
      if (hasMatchingRun) {
        targetOrder = ManufacturingOrder.fromMap(orderData);
        orderId = orderDoc.id;
        break;
      }

      if (targetOrder != null) {
  // Use it, e.g.:
        safeDebugPrint("Target order found: ${targetOrder.id}");
  // Or perform some action with it
}

    }

    // 11. تحديث أمر التصنيع ليشمل مواد التعبئة
    if (orderId != null) {
      // جلب أسماء مواد التعبئة من جدول items
      final updatedPackagingMaterials = [];
      for (final pack in packagingMaterials) {
        final itemId = pack['itemId']?.toString() ?? '';
        String itemName = '';
        
        if (itemId.isNotEmpty) {
          final itemDoc = await firestore.collection('items').doc(itemId).get();
          if (itemDoc.exists) {
            final itemData = itemDoc.data()!;
            
            itemName = isArabic 
                ? (itemData['nameAr'] ?? itemData['nameEn'] ?? 'Unknown')
                : (itemData['nameEn'] ?? itemData['nameAr'] ?? 'Unknown');
          }
        }

        updatedPackagingMaterials.add({
          'materialId': itemId,
          'materialName': itemName,
          'quantityRequired': (pack['quantity'] ?? 0).toDouble() * totalQuantity / batchSize,
          'unit': pack['unit']?.toString() ?? '',
          'minStockLevel': 0,
        });
      }

      await _firestore.collection('manufacturing_orders').doc(orderId).update({
        'packagingMaterials': updatedPackagingMaterials,
      });

      safeDebugPrint('Updated packaging materials for order: $orderId');
    }

    if (!localContext.mounted) return;
    ScaffoldMessenger.of(localContext).showSnackBar(
      SnackBar(content: Text('manufacturing.deduction_success'.tr())),
    );

  } catch (e) {
    safeDebugPrint('Error in manufacturing process: $e');
    if (!localContext.mounted) return;
    ScaffoldMessenger.of(localContext).showSnackBar(
      SnackBar(content: Text('${'error'.tr()}: $e')),
    );
  }
}

/* Future<void> startManufacturingWithComposition({
  required String companyId,
  required String factoryId,
  required String productId,
  required int totalQuantity,
  required String batchNumber,
  required String userId,
  required BuildContext context,
}) async {
  final localContext = context;
  final firestore = FirebaseFirestore.instance;

  try {
    // 1. جلب تركيب المنتج (composition)
    final compDoc = await firestore
        .collection('finished_products')
        .doc(productId)
        .collection('composition')
        .doc('data')
        .get();

    if (!compDoc.exists) {
      if (!localContext.mounted) return;
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(content: Text('manufacturing.composition_not_found'.tr())),
      );
      return;
    }

    final compData = compDoc.data()!;
    final batchSize = (compData['batchSize'] as num?)?.toDouble() ?? 1.0;

    // 2. تجميع بيانات المواد المطلوبة (الخام + التعبئة)
    final List<Map<String, dynamic>> requiredMaterials = [];

    // المواد الخام
    final rawMaterials = List<Map<String, dynamic>>.from(
        compData['rawMaterials'] ?? []);
    for (final raw in rawMaterials) {
      requiredMaterials.add({
        'itemId': raw['itemId']?.toString() ?? '',
        'itemType': 'raw',
        'requiredQuantity': (raw['quantity'] ?? 0).toDouble() * totalQuantity / batchSize,
        'unit': raw['unit']?.toString() ?? '',
      });
    }

    // مواد التعبئة والتغليف
    final packagingMaterials = List<Map<String, dynamic>>.from(
        compData['packagingMaterials'] ?? []);
    for (final pack in packagingMaterials) {
      requiredMaterials.add({
        'itemId': pack['itemId']?.toString() ?? '',
        'itemType': 'packaging',
        'requiredQuantity': (pack['quantity'] ?? 0).toDouble() * totalQuantity / batchSize,
        'unit': pack['unit']?.toString() ?? '',
      });
    }

    // 3. جلب أسماء المواد من جدول items
    for (var material in requiredMaterials) {
      final itemId = material['itemId'];
      if (itemId.isNotEmpty) {
        final itemDoc = await firestore.collection('items').doc(itemId).get();
        if (itemDoc.exists) {
          final itemData = itemDoc.data()!;
          // استخدام context لتحديد اللغة بدلاً من _isArabic
          final isArabic = Localizations.localeOf(localContext).languageCode == 'ar';
          material['itemName'] = isArabic 
              ? (itemData['nameAr'] ?? itemData['nameEn'] ?? 'Unknown')
              : (itemData['nameEn'] ?? itemData['nameAr'] ?? 'Unknown');
        } else {
          material['itemName'] = 'Unknown';
        }
      }
    }

    // 4. جلب الكميات المتوفرة لكل مادة
    for (var material in requiredMaterials) {
      final itemId = material['itemId'];
      if (itemId.isNotEmpty) {
        final invSnap = await firestore
            .collection('factories/$factoryId/inventory')
            .doc(itemId)
            .get();
        final avail = invSnap.exists
            ? (invSnap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
            : 0.0;
        material['availableQuantity'] = avail;
      }
    }

    // 5. التحقق مما إذا كان الـ context لا يزال mounted قبل showDialog
    if (!localContext.mounted) return;
    
    // 6. عرض Dialog يوضح المواد المطلوبة والمتوفرة
    final shouldProceed = await showDialog<bool>(
      context: localContext,
      builder: (ctx) {
        return AlertDialog(
          title: Text('manufacturing.required_materials'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: requiredMaterials.map((mat) {
                final requiredQty = mat['requiredQuantity'] ?? 0;
                final availQty = mat['availableQuantity'] ?? 0;
                final shortage = availQty < requiredQty;
                return ListTile(
                  title: Text(mat['itemName'] ?? mat['itemId']),
                  subtitle: Text(
                    '${'manufacturing.required'.tr()}: ${requiredQty.toStringAsFixed(2)} ${mat['unit']} | '
                    '${'manufacturing.available'.tr()}: ${availQty.toStringAsFixed(2)}'
                  ),
                  trailing: shortage 
                      ? const Icon(Icons.warning, color: Colors.red) 
                      : const Icon(Icons.check, color: Colors.green),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), 
              child: Text('cancel'.tr())
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: Text('manufacturing.confirm'.tr())
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;

    // 7. تحضير Batch للكتابة في stock_movements
    final batch = firestore.batch();
    final stockMovRef = firestore.collection('companies/$companyId/stock_movements');

    for (var material in requiredMaterials) {
      final itemId = material['itemId'];
      final qty = material['requiredQuantity'] as double;
      final itemName = material['itemName'] ?? '';

      if (itemId.isNotEmpty && qty > 0) {
        // إنشاء سجل حركة مخزنية
        final newMovRef = stockMovRef.doc();
        batch.set(newMovRef, {
          'type': 'manufacturing_deduction',
          'productId': productId,
          'productName': '', // يمكن إضافته إذا كان متوفراً
          'itemId': itemId,
          'itemName': itemName,
          'quantity': -qty,
          'date': FieldValue.serverTimestamp(),
          'referenceId': batchNumber,
          'userId': userId,
          'factoryId': factoryId,
          'companyId': companyId,
          'batchNumber': batchNumber,
          'movementType': 'out',
          'description': 'Manufacturing deduction for product $productId',
        });

        // تحديث المخزون في المصنع
        final invDocRef = firestore.doc('factories/$factoryId/inventory/$itemId');
        batch.set(invDocRef, {
          'quantity': FieldValue.increment(-qty),
          'lastUpdated': FieldValue.serverTimestamp(),
          'itemName': itemName,
        }, SetOptions(merge: true));
      }
    }

    // 8. تنفيذ العمليات دفعة واحدة
    await batch.commit();

    // 9. تحديث أمر التصنيع ليشمل مواد التعبئة
    final manufacturingOrderRef = _firestore.collection('manufacturing_orders')
        .where('batchNumber', isEqualTo: batchNumber)
        .where('factoryId', isEqualTo: factoryId)
        .limit(1);

    final orderQuery = await manufacturingOrderRef.get();
    if (orderQuery.docs.isNotEmpty) {
      final orderDoc = orderQuery.docs.first;
      final packagingList = packagingMaterials.map((pack) => {
        'materialId': pack['itemId'],
        'materialName': '', // يمكن جلب الاسم من items إذا لزم الأمر
        'quantityRequired': (pack['quantity'] ?? 0).toDouble() * totalQuantity / batchSize,
        'unit': pack['unit'],
        'minStockLevel': 0,
      }).toList();

      await orderDoc.reference.update({
        'packagingMaterials': packagingList,
      });
    }

    if (!localContext.mounted) return;
    ScaffoldMessenger.of(localContext).showSnackBar(
      SnackBar(content: Text('manufacturing.deduction_success'.tr())),
    );

  } catch (e) {
    safeDebugPrint('Error in manufacturing process: $e');
    if (!localContext.mounted) return;
    ScaffoldMessenger.of(localContext).showSnackBar(
      SnackBar(content: Text('${'error'.tr()}: $e')),
    );
  }
}
 */
}