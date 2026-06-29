/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/payment_terms.dart';
import 'package:puresip_purchasing/models/user_payment_term.dart';
import 'package:puresip_purchasing/models/user_delivery_term.dart';

class UserTermsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ تهيئة الشروط الافتراضية للمستخدم الجديد
  Future<void> initializeDefaultTerms(String userId) async {
    await Future.wait([
      _initializePaymentTerms(userId),
      _initializeDeliveryTerms(userId),
      _initializeDefaultAdditionalItems(userId)
    ]);
  }

  Future<void> _initializePaymentTerms(String userId) async {
    final batch = _firestore.batch();
    
    for (int i = 0; i < PaymentTerm.paymentTerms.length; i++) {
      final term = PaymentTerm.paymentTerms[i];
      final docRef = _firestore.collection('user_payment_terms').doc();
      final userTerm = UserPaymentTerm.fromStatic(term, userId, docRef.id, i);
      batch.set(docRef, userTerm.toMap());
    }
    
    await batch.commit();
  }

  Future<void> _initializeDeliveryTerms(String userId) async {
    final batch = _firestore.batch();
    
    for (int i = 0; i < DeliveryTerm.deliveryTerms.length; i++) {
      final term = DeliveryTerm.deliveryTerms[i];
      final docRef = _firestore.collection('user_delivery_terms').doc();
      final userTerm = UserDeliveryTerm.fromStatic(term, userId, docRef.id, i);
      batch.set(docRef, userTerm.toMap());
    }
    
    await batch.commit();
  }

  // ✅ جلب شروط الدفع الخاصة بالمستخدم
  Stream<List<UserPaymentTerm>> getUserPaymentTerms(String userId) {
    return _firestore
        .collection('user_payment_terms')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserPaymentTerm.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ✅ جلب شروط التسليم الخاصة بالمستخدم
  Stream<List<UserDeliveryTerm>> getUserDeliveryTerms(String userId) {
    return _firestore
        .collection('user_delivery_terms')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserDeliveryTerm.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ✅ تحديث شرط دفع
  Future<void> updatePaymentTerm(UserPaymentTerm term) async {
    await _firestore
        .collection('user_payment_terms')
        .doc(term.id)
        .update({
          'nameAr': term.nameAr,
          'nameEn': term.nameEn,
          'descriptionAr': term.descriptionAr,
          'descriptionEn': term.descriptionEn,
          'days': term.days,
          'isActive': term.isActive,
        });
  }

  // ✅ تحديث شرط تسليم
  Future<void> updateDeliveryTerm(UserDeliveryTerm term) async {
    await _firestore
        .collection('user_delivery_terms')
        .doc(term.id)
        .update({
          'nameAr': term.nameAr,
          'nameEn': term.nameEn,
          'descriptionAr': term.descriptionAr,
          'descriptionEn': term.descriptionEn,
          'isActive': term.isActive,
        });
  }

  // ✅ إضافة شرط دفع جديد
  Future<void> addPaymentTerm(String userId, String code, String nameAr, String nameEn, 
      String descriptionAr, String descriptionEn, int days) async {
    final terms = await getUserPaymentTerms(userId).first;
    final newOrder = terms.length;
    
    final docRef = _firestore.collection('user_payment_terms').doc();
    final term = UserPaymentTerm(
      id: docRef.id,
      userId: userId,
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      descriptionAr: descriptionAr,
      descriptionEn: descriptionEn,
      days: days,
      order: newOrder,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await docRef.set(term.toMap());
  }

  // ✅ إضافة شرط تسليم جديد
  Future<void> addDeliveryTerm(String userId, String code, String nameAr, String nameEn,
      String descriptionAr, String descriptionEn) async {
    final terms = await getUserDeliveryTerms(userId).first;
    final newOrder = terms.length;
    
    final docRef = _firestore.collection('user_delivery_terms').doc();
    final term = UserDeliveryTerm(
      id: docRef.id,
      userId: userId,
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      descriptionAr: descriptionAr,
      descriptionEn: descriptionEn,
      order: newOrder,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await docRef.set(term.toMap());
  }

  // ✅ حذف شرط دفع
  Future<void> deletePaymentTerm(String termId) async {
    await _firestore.collection('user_payment_terms').doc(termId).delete();
  }

  // ✅ حذف شرط تسليم
  Future<void> deleteDeliveryTerm(String termId) async {
    await _firestore.collection('user_delivery_terms').doc(termId).delete();
  }

  Future<void> _initializeDefaultAdditionalItems(String userId) async {
  final List<Map<String, String>> defaultItems = [
    // شروط
    {'titleAr': 'الدفع خلال 30 يوم', 'titleEn': 'Payment within 30 days', 'type': 'condition'},
    {'titleAr': 'الدفع خلال 45 يوم', 'titleEn': 'Payment within 45 days', 'type': 'condition'},
    {'titleAr': 'الدفع خلال 60 يوم', 'titleEn': 'Payment within 60 days', 'type': 'condition'},
    {'titleAr': 'دفعة مقدمة 30%', 'titleEn': '30% Advance payment', 'type': 'condition'},
    
    // مستندات
    {'titleAr': 'شهادة تحليل', 'titleEn': 'Certificate of Analysis', 'type': 'document'},
    {'titleAr': 'رقم الدفعة', 'titleEn': 'Batch Number', 'type': 'document'},
    {'titleAr': 'فاتورة أصلية', 'titleEn': 'Original Invoice', 'type': 'document'},
    {'titleAr': 'تاريخ الصلاحية', 'titleEn': 'Expiry Date', 'type': 'document'},
    
    // ملاحظات
    {'titleAr': 'الفحص قبل الاستلام', 'titleEn': 'Inspect before delivery', 'type': 'note'},
    {'titleAr': 'الإرجاع على حساب المورد', 'titleEn': 'Return at supplier cost', 'type': 'note'},
  ];

  final batch = FirebaseFirestore.instance.batch();
  for (int i = 0; i < defaultItems.length; i++) {
    final item = defaultItems[i];
    final docRef = FirebaseFirestore.instance.collection('additional_items').doc();
    batch.set(docRef, {
      'userId': userId,
      'titleAr': item['titleAr'],
      'titleEn': item['titleEn'],
      'descriptionAr': '',
      'descriptionEn': '',
      'type': item['type'],
      'isActive': true,
      'order': i,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

} */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/payment_terms.dart';
import 'package:puresip_purchasing/models/user_payment_term.dart';
import 'package:puresip_purchasing/models/user_delivery_term.dart';


class UserTermsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ تهيئة الشروط الافتراضية للمستخدم الجديد (مع منع التكرار)
  Future<void> initializeDefaultTerms(String userId) async {
    // ✅ التحقق أولاً: هل توجد بيانات بالفعل؟
    final paymentTermsCheck = await _firestore
        .collection('user_payment_terms')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    
    final deliveryTermsCheck = await _firestore
        .collection('user_delivery_terms')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    
    // ✅ إذا كانت البيانات موجودة بالفعل، لا تقم بالتهيئة
    if (paymentTermsCheck.docs.isNotEmpty && deliveryTermsCheck.docs.isNotEmpty) {
      safeDebugPrint('Terms already exist for user $userId, skipping initialization');
      return;
    }
    
    await Future.wait([
      _initializePaymentTerms(userId),
      _initializeDeliveryTerms(userId),
      _initializeDefaultAdditionalItems(userId)
    ]);
  }

  Future<void> _initializePaymentTerms(String userId) async {
    final batch = _firestore.batch();
    
    for (int i = 0; i < PaymentTerm.paymentTerms.length; i++) {
      final term = PaymentTerm.paymentTerms[i];
      final docRef = _firestore.collection('user_payment_terms').doc();
      final userTerm = UserPaymentTerm.fromStatic(term, userId, docRef.id, i);
      batch.set(docRef, userTerm.toMap());
    }
    
    await batch.commit();
  }

  Future<void> _initializeDeliveryTerms(String userId) async {
    final batch = _firestore.batch();
    
    for (int i = 0; i < DeliveryTerm.deliveryTerms.length; i++) {
      final term = DeliveryTerm.deliveryTerms[i];
      final docRef = _firestore.collection('user_delivery_terms').doc();
      final userTerm = UserDeliveryTerm.fromStatic(term, userId, docRef.id, i);
      batch.set(docRef, userTerm.toMap());
    }
    
    await batch.commit();
  }

  // ✅ جلب شروط الدفع الخاصة بالمستخدم
  Stream<List<UserPaymentTerm>> getUserPaymentTerms(String userId) {
    return _firestore
        .collection('user_payment_terms')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserPaymentTerm.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ✅ جلب شروط التسليم الخاصة بالمستخدم
  Stream<List<UserDeliveryTerm>> getUserDeliveryTerms(String userId) {
    return _firestore
        .collection('user_delivery_terms')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserDeliveryTerm.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ✅ تحديث شرط دفع
  Future<void> updatePaymentTerm(UserPaymentTerm term) async {
    await _firestore
        .collection('user_payment_terms')
        .doc(term.id)
        .update({
          'nameAr': term.nameAr,
          'nameEn': term.nameEn,
          'descriptionAr': term.descriptionAr,
          'descriptionEn': term.descriptionEn,
          'days': term.days,
          'isActive': term.isActive,
        });
  }

  // ✅ تحديث شرط تسليم
  Future<void> updateDeliveryTerm(UserDeliveryTerm term) async {
    await _firestore
        .collection('user_delivery_terms')
        .doc(term.id)
        .update({
          'nameAr': term.nameAr,
          'nameEn': term.nameEn,
          'descriptionAr': term.descriptionAr,
          'descriptionEn': term.descriptionEn,
          'isActive': term.isActive,
        });
  }

  // ✅ إضافة شرط دفع جديد
  Future<void> addPaymentTerm(String userId, String code, String nameAr, String nameEn, 
      String descriptionAr, String descriptionEn, int days) async {
    final terms = await getUserPaymentTerms(userId).first;
    final newOrder = terms.length;
    
    final docRef = _firestore.collection('user_payment_terms').doc();
    final term = UserPaymentTerm(
      id: docRef.id,
      userId: userId,
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      descriptionAr: descriptionAr,
      descriptionEn: descriptionEn,
      days: days,
      order: newOrder,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await docRef.set(term.toMap());
  }

  // ✅ إضافة شرط تسليم جديد
  Future<void> addDeliveryTerm(String userId, String code, String nameAr, String nameEn,
      String descriptionAr, String descriptionEn) async {
    final terms = await getUserDeliveryTerms(userId).first;
    final newOrder = terms.length;
    
    final docRef = _firestore.collection('user_delivery_terms').doc();
    final term = UserDeliveryTerm(
      id: docRef.id,
      userId: userId,
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      descriptionAr: descriptionAr,
      descriptionEn: descriptionEn,
      order: newOrder,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await docRef.set(term.toMap());
  }

  // ✅ حذف شرط دفع
  Future<void> deletePaymentTerm(String termId) async {
    await _firestore.collection('user_payment_terms').doc(termId).delete();
  }

  // ✅ حذف شرط تسليم
  Future<void> deleteDeliveryTerm(String termId) async {
    await _firestore.collection('user_delivery_terms').doc(termId).delete();
  }

  // ✅ تهيئة العناصر الإضافية الافتراضية (بدون تكرار)
  Future<void> _initializeDefaultAdditionalItems(String userId) async {
    // ✅ التحقق أولاً: هل توجد عناصر بالفعل؟
    final existingItems = await _firestore
        .collection('additional_items')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    
    if (existingItems.docs.isNotEmpty) {
      safeDebugPrint('Additional items already exist for user $userId, skipping');
      return;
    }
    
    final List<Map<String, String>> defaultItems = [
      // شروط
      {'titleAr': 'الدفع خلال 30 يوم', 'titleEn': 'Payment within 30 days', 'type': 'condition'},
      {'titleAr': 'الدفع خلال 45 يوم', 'titleEn': 'Payment within 45 days', 'type': 'condition'},
      {'titleAr': 'الدفع خلال 60 يوم', 'titleEn': 'Payment within 60 days', 'type': 'condition'},
      {'titleAr': 'دفعة مقدمة 30%', 'titleEn': '30% Advance payment', 'type': 'condition'},
      
      // مستندات
      {'titleAr': 'شهادة تحليل', 'titleEn': 'Certificate of Analysis', 'type': 'document'},
      {'titleAr': 'رقم الدفعة', 'titleEn': 'Batch Number', 'type': 'document'},
      {'titleAr': 'فاتورة أصلية', 'titleEn': 'Original Invoice', 'type': 'document'},
      {'titleAr': 'تاريخ الصلاحية', 'titleEn': 'Expiry Date', 'type': 'document'},
      {'titleAr': 'قائمة التعبئة', 'titleEn': 'Packing List', 'type': 'document'},
      
      // ملاحظات
      {'titleAr': 'الفحص قبل الاستلام', 'titleEn': 'Inspect before delivery', 'type': 'note'},
      {'titleAr': 'الإرجاع على حساب المورد', 'titleEn': 'Return at supplier cost', 'type': 'note'},
    ];

    final batch = _firestore.batch();
    for (int i = 0; i < defaultItems.length; i++) {
      final item = defaultItems[i];
      final docRef = _firestore.collection('additional_items').doc();
      batch.set(docRef, {
        'userId': userId,
        'titleAr': item['titleAr'],
        'titleEn': item['titleEn'],
        'descriptionAr': '',
        'descriptionEn': '',
        'type': item['type'],  // ✅ 'condition', 'document', 'note'
        'isActive': true,
        'order': i,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
