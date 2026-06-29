import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/company.dart';

class CompanyService  with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> fetchUserCompanies(
      String uid) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);

    final List<Map<String, dynamic>> companies = [];
    for (final id in companyIds) {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(id)
          .get();
      if (doc.exists) {
        companies.add({'id': doc.id, 'nameAr': doc['nameEn']});
      }
    }
    return companies;
  }

  Stream<List<Company>> getUserCompanies(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap(
      (userSnapshot) async {
        final companyIds =
            List<String>.from(userSnapshot.data()?['companyIds'] ?? []);

        if (companyIds.isEmpty) return [];

        final companies = <Company>[];
        for (final companyId in companyIds) {
          final companyDoc =
              await _firestore.collection('companies').doc(companyId).get();
          if (companyDoc.exists) {
            companies.add(Company.fromMap(companyDoc.data()!, companyDoc.id));
          }
        }
        return companies;
      },
    );
  }

  // Future<Company?> getCompanyById(String companyId) async {
  //   final doc = await _firestore.collection('companies').doc(companyId).get();
  //   return doc.exists ? Company.fromMap(doc.data()!, doc.id) : null;
  // }

  Future<Company?> getCompanyById(String companyId) async {
  try {
    final doc = await _firestore.collection('companies').doc(companyId).get();
    return doc.exists ? Company.fromMap(doc.data()!, doc.id) : null;
  } catch (e) {
    return null;
  }
}
}
