/* import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  // ➤ ثابتات أسماء الحقول
  static const fieldNameAr = 'nameAr';
  static const fieldNameEn = 'nameEn';
  static const fieldCategory = 'category';
  static const fieldUnit = 'unit';
  static const fieldDescription = 'description';
  static const fieldUserId = 'userId';
  static const fieldCreatedAt = 'createdAt';
  static const fieldUnitPrice = 'unit_price'; // 🆕 مضاف
 static const fieldIsTaxable = 'is_taxable'; // 🆕 حقل جديد
  // ➤ القيم المسموح بها لطبيعة الصنف
  static const List<String> allowedCategories = [
    'raw_material',
    'packaging',
    'finished_product',
    'service',
    'accessory',
    'other',
  ];

  // ➤ القيم المسموح بها للوحدة
  static const List<String> allowedUnits = [
    'kg',
    'gram',
    'piece',
    'box',
    'meter',
    'liter',
    'pack',
    'unit',
  ];

  // ➤ الخصائص
  final String? id;
  final String nameAr;
  final String nameEn;
  final String category;
  final String unit;
  final String? description;
  final double? unitPrice; // 🆕 مضاف
  final String userId;
  final Timestamp createdAt;
  final bool isTaxable;

  Item({
    this.id,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.unit,
    this.description,
    this.unitPrice, // 🆕
    required this.userId,
    required this.createdAt,
    this.isTaxable = true,
  });

  // ➤ من Firestore
  factory Item.fromMap(Map<String, dynamic> data, String documentId) {
    return Item(
      id: documentId,
      nameAr: data[fieldNameAr] ?? '',
      nameEn: data[fieldNameEn] ?? '',
      category: data[fieldCategory] ?? '',
      unit: data[fieldUnit] ?? '',
      description: data[fieldDescription],
      unitPrice: (data[fieldUnitPrice] != null)
          ? (data[fieldUnitPrice] as num).toDouble()
          : null, // 🆕 يدعم التحويل من num إلى double
      isTaxable: data[fieldIsTaxable] ?? true, // 🆕
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
    );
  }

  // ➤ إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      fieldNameAr: nameAr,
      fieldNameEn: nameEn,
      fieldCategory: category,
      fieldUnit: unit,
      fieldDescription: description,
      fieldUnitPrice: unitPrice, // 🆕
      fieldIsTaxable: isTaxable, // 🆕
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
    };
  }
}
 */

class Item {
  static const String fieldNameAr = 'nameAr';
  static const String fieldNameEn = 'nameEn';
  static const String fieldDescription = 'description';
  static const String fieldCategory = 'category';
  static const String fieldUnit = 'unit';
  static const String fieldUnitPrice = 'unitPrice';
  static const String fieldIsTaxable = 'isTaxable';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUserId = 'userId';
  final String itemId;
  final String nameAr;
  final String nameEn;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final bool isTaxable;
  final double taxRate;
  final double taxAmount;
  final double totalAfterTaxAmount;
  final String? description;
  final String category;

  Item({
    required this.itemId,
    required this.nameAr,
    required this.nameEn,
    required this.quantity,
    required this.category,
    required this.description,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    this.isTaxable = true,
    this.taxRate = 14.0,
    this.taxAmount = 0.0,
    this.totalAfterTaxAmount = 0.0,
  });

  // ➤ القيم المسموح بها لطبيعة الصنف
  static const List<String> allowedCategories = [
    'raw_material',
    'packaging',
    'finished_product',
    'service',
    'accessory',
    'other',
  ];

  // ➤ القيم المسموح بها للوحدة
  static const List<String> allowedUnits = [
    'kg',
    'gram',
    'piece',
    'box',
    'liter',
  ];

  factory Item.create({
    required String itemId,
    required String nameAr,
    required String nameEn,
    required double quantity,
    required String unit,
    required double unitPrice,
    required String category,
    String? description,
    bool isTaxable = true,
    double taxRate = 14.0,
  }) {
    final totalPrice = unitPrice * quantity;
    final taxAmount = isTaxable ? totalPrice * (taxRate / 100) : 0.0;
    final totalAfterTax = totalPrice + taxAmount;

    return Item(
      itemId: itemId,
      nameAr: nameAr,
      nameEn: nameEn,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      isTaxable: isTaxable,
      taxRate: isTaxable ? taxRate : 0.0,
      taxAmount: taxAmount,
      totalAfterTaxAmount: totalAfterTax,
      description: description,
      category: category,
    );
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      itemId: map['itemId'] ?? '',
      nameAr: map['nameAr'] ?? '',
      nameEn: map['nameEn'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      isTaxable: map['isTaxable'] ?? true,
      taxRate: (map['taxRate'] ?? 14.0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      totalAfterTaxAmount: (map['totalAfterTaxAmount'] ?? 0).toDouble(),
      description: map['description'],
      category: map['category'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'isTaxable': isTaxable,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'totalAfterTaxAmount': totalAfterTaxAmount,
      'description': description,
      'category': category,
    };
  }

  Item copyWith({
    String? itemId,
    String? nameAr,
    String? nameEn,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
    bool? isTaxable,
    double? taxRate,
    double? taxAmount,
    double? totalAfterTaxAmount,
    String? description,
    String? category,
  }) {
    return Item(
      itemId: itemId ?? this.itemId,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      isTaxable: isTaxable ?? this.isTaxable,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAfterTaxAmount: totalAfterTaxAmount ?? this.totalAfterTaxAmount,
      description: description ?? this.description,
      category: category ?? this.category,
    );
  }

  Item updateQuantity(double newQuantity) {
    final newTotalPrice = unitPrice * newQuantity;
    final newTaxAmount = isTaxable ? newTotalPrice * (taxRate / 100) : 0.0;
    final newTotalAfterTax = newTotalPrice + newTaxAmount;

    return copyWith(
      quantity: newQuantity,
      totalPrice: newTotalPrice,
      taxAmount: newTaxAmount,
      totalAfterTaxAmount: newTotalAfterTax,
    );
  }

  Item updateUnitPrice(double newUnitPrice) {
    final newTotalPrice = newUnitPrice * quantity;
    final newTaxAmount = isTaxable ? newTotalPrice * (taxRate / 100) : 0.0;
    final newTotalAfterTax = newTotalPrice + newTaxAmount;

    return copyWith(
      unitPrice: newUnitPrice,
      totalPrice: newTotalPrice,
      taxAmount: newTaxAmount,
      totalAfterTaxAmount: newTotalAfterTax,
    );
  }

  Item updateTaxStatus(bool taxable, double newTaxRate) {
    final newTaxAmount = taxable ? totalPrice * (newTaxRate / 100) : 0.0;
    final newTotalAfterTax = totalPrice + newTaxAmount;

    return copyWith(
      isTaxable: taxable,
      taxRate: newTaxRate,
      taxAmount: newTaxAmount,
      totalAfterTaxAmount: newTotalAfterTax,
    );
  }

  /// تستخدم عند تحميل البيانات من Firestore
  factory Item.fromFirestore(Map<String, dynamic> map, String docId) {
    return Item.fromMap({...map, 'itemId': docId});
  }
}
