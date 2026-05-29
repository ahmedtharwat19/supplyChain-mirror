// lib/models/additional_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AdditionalItemType {
  condition,
  document,
  note,
}

extension AdditionalItemTypeExtension on AdditionalItemType {
  String get asString {
    switch (this) {
      case AdditionalItemType.condition:
        return 'condition';
      case AdditionalItemType.document:
        return 'document';
      case AdditionalItemType.note:
        return 'note';
    }
  }
  
  static AdditionalItemType fromString(String value) {
    switch (value) {
      case 'condition':
        return AdditionalItemType.condition;
      case 'document':
        return AdditionalItemType.document;
      case 'note':
        return AdditionalItemType.note;
      default:
        return AdditionalItemType.condition;
    }
  }
}

class AdditionalItem {
  final String id;
  final String userId;
  final String titleAr;
  final String titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final AdditionalItemType type;
  final bool isActive;
  final int order;
  final DateTime createdAt;

  AdditionalItem({
    required this.id,
    required this.userId,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.type,
    required this.isActive,
    required this.order,
    required this.createdAt,
  });

  String getTitle(bool isArabic) => isArabic ? titleAr : titleEn;
  String? getDescription(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  factory AdditionalItem.fromMap(Map<String, dynamic> data, String id) {
    return AdditionalItem(
      id: id,
      userId: data['userId'] ?? '',
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      descriptionAr: data['descriptionAr'],
      descriptionEn: data['descriptionEn'],
      type: AdditionalItemTypeExtension.fromString(data['type'] ?? 'condition'),
      isActive: data['isActive'] ?? true,
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'descriptionAr': descriptionAr,
      'descriptionEn': descriptionEn,
      'type': type.asString,  // ✅ استخدام asString بدلاً من toString()
      'isActive': isActive,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}