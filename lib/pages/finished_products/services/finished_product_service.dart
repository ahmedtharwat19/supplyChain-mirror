// finished_product_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/finished_product.dart';

class FinishedProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // إضافة منتج تام جديد
  Future<void> addFinishedProduct(FinishedProduct product) async {
    await _firestore.collection('finished_products').add(product.toMap());
  }

  // جلب جميع المنتجات التامة للمستخدم
  Stream<List<FinishedProduct>> getFinishedProducts(String userId) {
    return _firestore
        .collection('finished_products')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }

  // جلب المنتجات التامة حسب الشركة
  Stream<List<FinishedProduct>> getFinishedProductsByCompany(String companyId) {
    return _firestore
        .collection('finished_products')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }

  // جلب المنتجات التامة حسب المصنع
  Stream<List<FinishedProduct>> getFinishedProductsByFactory(String factoryId) {
    return _firestore
        .collection('finished_products')
        .where('factoryId', isEqualTo: factoryId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }

  // تحديث منتج تام
  Future<void> updateFinishedProduct(FinishedProduct product) async {
    await _firestore
        .collection('finished_products')
        .doc(product.id)
        .update(product.toMap());
  }

  // حذف منتج تام
  Future<void> deleteFinishedProduct(String productId) async {
    await _firestore.collection('finished_products').doc(productId).delete();
  }

  // في finished_product_service.dart
  Stream<FinishedProduct?> getFinishedProductByIdStream(String productId) {
    return _firestore
        .collection('finished_products')
        .doc(productId)
        .snapshots()
        .map((snapshot) {
      return snapshot.exists
          ? FinishedProduct.fromMap(snapshot.data()!, snapshot.id)
          : null;
    });
  }

Future<void> deleteFinishedProductDirect(String productId) async {
  await FirebaseFirestore.instance.collection('finished_products').doc(productId).delete();
}


}
