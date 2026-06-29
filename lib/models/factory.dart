import 'package:cloud_firestore/cloud_firestore.dart';

class Factory {
  // ➤ ثابتات أسماء الحقول
  static const fieldNameAr = 'nameAr';
  static const fieldNameEn = 'nameEn';
  static const fieldLocation = 'location';
  static const fieldManagerPhone = 'managerPhone';
  static const fieldManagerName = 'managerName';
  static const fieldUserId = 'userId';
  static const fieldCompanyIds = 'companyIds';
  static const fieldCreatedAt = 'createdAt';

  // ➤ الخصائص
  final String? id;
  final String nameAr;
  final String nameEn;
  final String location;
  final String managerName;
  final String managerPhone;
  final String userId;
  final DateTime? createdAt;
  final List<String> companyIds;

  Factory({
    this.id,
    required this.nameAr,
    required this.nameEn,
    required this.location,
    required this.managerName,
    required this.managerPhone,
    required this.userId,
    this.createdAt,
    required this.companyIds,
  });

  // ➤ من Firestore
  factory Factory.fromMap(Map<String, dynamic> map, String id) {
    return Factory(
      id: id,
      nameAr: map[fieldNameAr] ?? '',
      nameEn: map[fieldNameEn] ?? '',
      location: map[fieldLocation] ?? '',
      managerName: map[fieldManagerName] ?? '',
      managerPhone: map[fieldManagerPhone] ?? '',
      userId: map[fieldUserId] ?? '',
      createdAt: map[fieldCreatedAt] != null
          ? (map[fieldCreatedAt] as Timestamp).toDate()
          : null,
      companyIds: List<String>.from(map[fieldCompanyIds] ?? []),
    );
  }

  // ➤ إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      fieldNameAr: nameAr,
      fieldNameEn: nameEn,
      fieldLocation: location,
      fieldManagerName: managerName,
      fieldManagerPhone: managerPhone,
      fieldUserId: userId,
      fieldCreatedAt: createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      fieldCompanyIds: companyIds,
    };
  }
}
