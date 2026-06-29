import 'package:cloud_firestore/cloud_firestore.dart';

class ItemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateExistingItems() async {
    final snapshot = await _firestore.collection('items').get();
    
    for (final doc in snapshot.docs) {
      await doc.reference.update({
        'is_taxable': true // تعيين قيمة افتراضية
      });
    }
  }

  // يمكنك إضافة دوال أخرى متعلقة بالأصناف هنا
}