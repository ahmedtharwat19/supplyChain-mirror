import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class FirestoreUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';

  /// إنشاء مستخدم جديد إذا لم يكن موجوداً، وإعطاؤه ترخيصاً لمدة شهر
  Future<AppUser> createUserIfNeeded({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final docRef = _firestore.collection(_usersCollection).doc(uid);
    final doc = await docRef.get();

    if (doc.exists) {
      return AppUser.fromFirestore(doc);
    }

    // مستخدم جديد: نمنح ترخيصاً لمدة 30 يوماً
    final now = DateTime.now();
    final expiryDate = now.add(const Duration(days: 30));

    final newUser = AppUser(
      id: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      createdAt: now,
      licenseExpiryDate: expiryDate,
    );

    await docRef.set(newUser.toMap());
    return newUser;
  }

  /// جلب مستخدم من Firestore
  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    if (doc.exists) {
      return AppUser.fromFirestore(doc);
    }
    return null;
  }

  /// تحديث تاريخ انتهاء الترخيص (للاستخدام لاحقاً)
  Future<void> updateLicenseExpiry(String uid, DateTime newExpiry) async {
    await _firestore.collection(_usersCollection).doc(uid).update({
      'licenseExpiryDate': Timestamp.fromDate(newExpiry),
    });
  }
}
