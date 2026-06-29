import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreHelper {
  static Future<void> updateItemsTaxableField() async {
    final snapshot = await FirebaseFirestore.instance.collection('items').get();

    for (final doc in snapshot.docs) {
      await doc.reference.update({'is_taxable': true});
    }
  }

  Map<String, dynamic> convertTimestamps(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate();
      } else if (value is Map<String, dynamic>) {
        result[key] = convertTimestamps(value); // دعم التداخل العميق
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
