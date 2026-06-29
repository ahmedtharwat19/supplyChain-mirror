import 'package:cloud_firestore/cloud_firestore.dart';
class Company {
  // ➤ ثابتات الحقول
  static const fieldNameAr = 'nameAr';
  static const fieldNameEn = 'nameEn';
  static const fieldAddress = 'address';
  static const fieldManagerName = 'managerName';
  static const fieldManagerPhone = 'managerPhone';
  static const fieldLogoBase64 = 'logoBase64';
  static const fieldUserId = 'userId';
  static const fieldCreatedAt = 'createdAt';

  // ➤ الخصائص
  final String? id;
  final String nameAr;
  final String nameEn;
  final String address;
  final String managerName;
  final String managerPhone;
  final String? logoBase64;
  final String userId;
  final Timestamp createdAt;

  Company({
    this.id,
    required this.nameAr,
    required this.nameEn,
    required this.address,
    required this.managerName,
    required this.managerPhone,
    this.logoBase64,
    required this.userId,
    required this.createdAt,
  });

  // ➤ Factory Constructor from Map
  factory Company.fromMap(Map<String, dynamic> data, String documentId) {
    return Company(
      id: documentId,
      nameAr: data[fieldNameAr] ?? '',
      nameEn: data[fieldNameEn] ?? '',
      address: data[fieldAddress] ?? '',
      managerName: data[fieldManagerName] ?? '',
      managerPhone: data[fieldManagerPhone] ?? '',
      logoBase64: data[fieldLogoBase64],
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
    );
  }

  // ➤ Convert to Map
  Map<String, dynamic> toMap() {
    return {
      fieldNameAr: nameAr,
      fieldNameEn: nameEn,
      fieldAddress: address,
      fieldManagerName: managerName,
      fieldManagerPhone: managerPhone,
      fieldLogoBase64: logoBase64,
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
    };
  }
}
