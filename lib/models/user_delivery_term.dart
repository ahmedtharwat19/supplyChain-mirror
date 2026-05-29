import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/payment_terms.dart'; // ✅ إضافة هذا الـ import

class UserDeliveryTerm {
  final String id;
  final String userId;
  final String code;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final int order;
  final bool isActive;
  final DateTime createdAt;

  UserDeliveryTerm({
    required this.id,
    required this.userId,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.order,
    required this.isActive,
    required this.createdAt,
  });

  String getName(bool isArabic) => isArabic ? nameAr : nameEn;
  String getDescription(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  factory UserDeliveryTerm.fromMap(Map<String, dynamic> data, String id) {
    return UserDeliveryTerm(
      id: id,
      userId: data['userId'] ?? '',
      code: data['code'] ?? '',
      nameAr: data['nameAr'] ?? '',
      nameEn: data['nameEn'] ?? '',
      descriptionAr: data['descriptionAr'] ?? '',
      descriptionEn: data['descriptionEn'] ?? '',
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'code': code,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'descriptionAr': descriptionAr,
      'descriptionEn': descriptionEn,
      'order': order,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // تحويل من DeliveryTerm الثابت إلى UserDeliveryTerm
  factory UserDeliveryTerm.fromStatic(DeliveryTerm term, String userId, String id, int order) {
    return UserDeliveryTerm(
      id: id,
      userId: userId,
      code: term.code,
      nameAr: term.nameAr,
      nameEn: term.nameEn,
      descriptionAr: term.descriptionAr,
      descriptionEn: term.descriptionEn,
      order: order,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }
}