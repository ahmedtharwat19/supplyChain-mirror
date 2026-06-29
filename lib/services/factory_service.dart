import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' hide Factory;
import '../models/factory.dart';

class FactoryService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> fetchUserFactories(
      String uid) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final factoryIds = List<String>.from(userDoc.data()?['factoryIds'] ?? []);

    final List<Map<String, dynamic>> factories = [];
    for (final id in factoryIds) {
      final doc = await FirebaseFirestore.instance
          .collection('factories')
          .doc(id)
          .get();
      if (doc.exists) {
        factories.add({'id': doc.id, 'nameAr': doc['nameEn']});
      }
    }
    return factories;
  }

  // جلب المصانع حسب الشركة - الإصدار المصحح
  Stream<List<Factory>> getFactoriesByCompany(String companyId) {
    return _firestore
        .collection('factories')
        .where('companyIds', arrayContains: companyId) // تم التصحيح هنا
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Factory.fromMap(doc.data(), doc.id))
            .toList());
  }

  // // جلب مصنع بواسطة ID
  // Future<Factory?> getFactoryById(String factoryId) async {
  //   try {
  //     final doc = await _firestore.collection('factories').doc(factoryId).get();
  //     return doc.exists ? Factory.fromMap(doc.data()!, doc.id) : null;
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error getting factory: $e');
  //     }
  //     return null;
  //   }
  // }

  // جلب جميع مصانع المستخدم
  Stream<List<Factory>> getUserFactories(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap(
      (userSnapshot) async {
        final factoryIds =
            List<String>.from(userSnapshot.data()?['factoryIds'] ?? []);

        if (factoryIds.isEmpty) return [];

        final factories = <Factory>[];
        for (final factoryId in factoryIds) {
          final factoryDoc =
              await _firestore.collection('factories').doc(factoryId).get();
          if (factoryDoc.exists) {
            factories.add(Factory.fromMap(factoryDoc.data()!, factoryDoc.id));
          }
        }
        return factories;
      },
    );
  }

  Future<Factory?> getFactoryById(String factoryId) async {
  try {
    final doc = await _firestore.collection('factories').doc(factoryId).get();
    return doc.exists ? Factory.fromMap(doc.data()!, doc.id) : null;
  } catch (e) {
    return null;
  }
}

}
