import 'package:cloud_firestore/cloud_firestore.dart';

class FinishedProduct {
  // ➤ ثابتات أسماء الحقول
  static const fieldNameAr = 'nameAr';
  static const fieldNameEn = 'nameEn';
  static const fieldQuantity = 'quantity';
  static const fieldUnit = 'unit';
  static const fieldIsValid = 'isValid';
//  static const fieldManufacturingOrderId = 'manufacturing_order_id';
//  static const fieldDate = 'date';
  static const fieldCompanyId = 'companyId';
  static const fieldFactoryId = 'factoryId';
  static const fieldUserId = 'userId';
  static const fieldCreatedAt = 'createdAt';
  static const fieldBarCode = 'barCode';
//  static const fieldExpiryDate = 'expiryDate';

  // ➤ الخصائص
  final String? id;
  final String nameAr;
  final String nameEn;
  final double quantity;
  final String unit;
//  final String manufacturingOrderId;
//  final Timestamp date;
  final String companyId;
  final String factoryId;
  final String userId;
  final Timestamp createdAt;
  final String barCode;
  final bool isValid;
  
//  final Timestamp expiryDate;

  FinishedProduct({
    this.id,
    required this.nameAr,
    required this.nameEn,
    required this.quantity,
    required this.unit,
  //  required this.manufacturingOrderId,
   // required this.date,
    required this.companyId,
    required this.factoryId,
    required this.userId,
    required this.createdAt,
    required this.barCode,
    required this.isValid,
//    required this.expiryDate,
  });

  // ➤ من Firestore
  factory FinishedProduct.fromMap(Map<String, dynamic> data, String documentId) {
    return FinishedProduct(
      id: documentId,
      nameAr: data[fieldNameAr] ?? '',
      nameEn: data[fieldNameEn] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
    //  manufacturingOrderId: data[fieldManufacturingOrderId] ?? '',
    //  date: data[fieldDate] ?? Timestamp.now(),
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
      barCode: data[fieldBarCode] ?? '',
      isValid: data[fieldIsValid] ?? true,
   //   expiryDate: data[fieldExpiryDate] ?? Timestamp.now(),
    );
  }

  // ➤ إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      fieldNameAr  : nameAr,
      fieldNameEn: nameEn,
      fieldQuantity: quantity,
      fieldUnit: unit,
  //    fieldManufacturingOrderId: manufacturingOrderId,
//      fieldDate: date,
      fieldCompanyId: companyId,
      fieldFactoryId: factoryId,
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
      fieldBarCode: barCode,
      fieldIsValid: isValid,
  //    fieldExpiryDate: expiryDate,
    };
  }

  // ➤ دالة نسخ
  FinishedProduct copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    double? quantity,
    String? unit,
  //  String? manufacturingOrderId,
  //  Timestamp? date,
    String? companyId,
    String? factoryId,
    String? userId,
    Timestamp? createdAt,
    String? barCode,
  bool? isValid,
   // Timestamp? expiryDate,
  }) {
    return FinishedProduct(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
   //   manufacturingOrderId: manufacturingOrderId ?? this.manufacturingOrderId,
   //   date: date ?? this.date,
      companyId: companyId ?? this.companyId,
      factoryId: factoryId ?? this.factoryId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      barCode: barCode ?? this.barCode,
      isValid: isValid ?? this.isValid,
   //   expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  // ➤ دالة لتحويل Timestamp إلى DateTime
//  DateTime get expiryDateTime => expiryDate.toDate();
//  DateTime get dateTime => date.toDate();
  DateTime get createdAtDateTime => createdAt.toDate();

  // ➤ دالة للتحقق من انتهاء الصلاحية
//  bool get isExpired => DateTime.now().isAfter(expiryDateTime);
//  bool get isExpiringSoon {
  //  final daysUntilExpiry = expiryDateTime.difference(DateTime.now()).inDays;
  //  return daysUntilExpiry <= 7;
//  }
}