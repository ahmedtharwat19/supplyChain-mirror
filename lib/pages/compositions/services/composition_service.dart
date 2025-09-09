// composition_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/product_composition_model.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class CompositionService with ChangeNotifier { // Add with ChangeNotifier
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // جلب بيان التركيب من المجموعة الفرعية
  Stream<ProductComposition?> getCompositionByProductId(String productId) {
    return _firestore
        .collection('finished_products')
        .doc(productId)
        .collection('composition')
        .doc('data') // وثيقة واحدة لكل منتج
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return ProductComposition.fromMap(snapshot.data()!, snapshot.id);
        })
        .handleError((error) {
          if (kDebugMode) {
            safeDebugPrint('Error loading composition: $error');
          }
          return null;
        });
  }

  // حفظ بيان التركيب في المجموعة الفرعية
  Future<void> saveComposition(ProductComposition composition) async {
    try {
      final compositionData = composition.toMap();
      
      await _firestore
          .collection('finished_products')
          .doc(composition.productId) // نفس معرف المنتج التام
          .collection('composition')
          .doc('data') // وثيقة واحدة
          .set(compositionData, SetOptions(merge: true));
          
      notifyListeners(); // This will notify listeners when composition is saved
    } catch (e) {
      if (kDebugMode) {
        safeDebugPrint('Error saving composition: $e');
      }
      rethrow;
    }
  }

  // حذف بيان التركيب
  Future<void> deleteComposition(String productId) async {
    try {
      await _firestore
          .collection('finished_products')
          .doc(productId)
          .collection('composition')
          .doc('data')
          .delete();
          
      notifyListeners(); // This will notify listeners when composition is deleted
    } catch (e) {
      if (kDebugMode) {
        safeDebugPrint('Error deleting composition: $e');
      }
      rethrow;
    }
  }
}