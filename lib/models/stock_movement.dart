/* import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovement {
  // ➤ ثابتات أسماء الحقول
  static const fieldItemId = 'itemId';
  static const fieldQuantity = 'quantity';
  static const fieldUnit = 'unit';
  static const fieldType = 'type'; // 'in' or 'out'
  static const fieldDate = 'date';
  static const fieldCompanyId = 'companyId';
  static const fieldFactoryId = 'factoryId';
  static const fieldUserId = 'userId';
  static const fieldReferenceId = 'referenceId';

  // ➤ الخصائص
  final String? id;
  final String itemId;
  final double quantity;
  final String unit;
  final String type;
  final Timestamp date;
  final String companyId;
  final String factoryId;
  final String userId;
  final String referenceId;

  StockMovement({
    this.id,
    required this.itemId,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.date,
    required this.companyId,
    required this.factoryId,
    required this.userId,
    required this.referenceId,
  });

  factory StockMovement.fromMap(Map<String, dynamic> data, String documentId) {
    return StockMovement(
      id: documentId,
      itemId: data[fieldItemId] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      type: data[fieldType] ?? '',
      date: data[fieldDate] ?? Timestamp.now(),
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      userId: data[fieldUserId] ?? '',
      referenceId: data[fieldReferenceId] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      fieldItemId: itemId,
      fieldQuantity: quantity,
      fieldUnit: unit,
      fieldType: type,
      fieldDate: date,
      fieldCompanyId: companyId,
      fieldFactoryId: factoryId,
      fieldUserId: userId,
      fieldReferenceId: referenceId,
    };
  }

  factory StockMovement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockMovement(
      id: doc.id,
      itemId: data[fieldItemId] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      type: data[fieldType] ?? '',
      date: data[fieldDate] ?? Timestamp.now(),
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      userId: data[fieldUserId] ?? '',
      referenceId: data[fieldReferenceId] ?? '',
    );
  }
}
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'stock_movement.g.dart';

@HiveType(typeId: 0)
class StockMovement {
  // ➤ ثابتات أسماء الحقول
  static const fieldItemId = 'itemId';
  static const fieldQuantity = 'quantity';
  static const fieldUnit = 'unit';
  static const fieldType = 'type'; // 'in' or 'out'
  static const fieldDate = 'date';
  static const fieldCompanyId = 'companyId';
  static const fieldFactoryId = 'factoryId';
  static const fieldUserId = 'userId';
  static const fieldReferenceId = 'referenceId';

  // ➤ الخصائص مع Hive Fields
  @HiveField(0)
  final String? id;
  
  @HiveField(1)
  final String itemId;
  
  @HiveField(2)
  final double quantity;
  
  @HiveField(3)
  final String unit;
  
  @HiveField(4)
  final String type;
  
  @HiveField(5)
  final Timestamp date;
  
  @HiveField(6)
  final String companyId;
  
  @HiveField(7)
  final String factoryId;
  
  @HiveField(8)
  final String userId;
  
  @HiveField(9)
  final String referenceId;
  
  @HiveField(10)
  final bool isSynced;
  
  @HiveField(11)
  final DateTime lastUpdated;

  StockMovement({
    this.id,
    required this.itemId,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.date,
    required this.companyId,
    required this.factoryId,
    required this.userId,
    required this.referenceId,
    this.isSynced = true,
    required this.lastUpdated,
  });

  factory StockMovement.fromMap(Map<String, dynamic> data, String documentId) {
    return StockMovement(
      id: documentId,
      itemId: data[fieldItemId] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      type: data[fieldType] ?? '',
      date: data[fieldDate] ?? Timestamp.now(),
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      userId: data[fieldUserId] ?? '',
      referenceId: data[fieldReferenceId] ?? '',
      isSynced: true,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      fieldItemId: itemId,
      fieldQuantity: quantity,
      fieldUnit: unit,
      fieldType: type,
      fieldDate: date,
      fieldCompanyId: companyId,
      fieldFactoryId: factoryId,
      fieldUserId: userId,
      fieldReferenceId: referenceId,
    };
  }

  factory StockMovement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockMovement(
      id: doc.id,
      itemId: data[fieldItemId] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      type: data[fieldType] ?? '',
      date: data[fieldDate] ?? Timestamp.now(),
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      userId: data[fieldUserId] ?? '',
      referenceId: data[fieldReferenceId] ?? '',
      isSynced: true,
      lastUpdated: DateTime.now(),
    );
  }

  // دالة لتحويل Timestamp إلى DateTime للتخزين في Hive
  DateTime get dateAsDateTime => date.toDate();

  // دالة لإنشاء نسخة محدثة
  StockMovement copyWith({
    String? id,
    String? itemId,
    double? quantity,
    String? unit,
    String? type,
    Timestamp? date,
    String? companyId,
    String? factoryId,
    String? userId,
    String? referenceId,
    bool? isSynced,
    DateTime? lastUpdated,
  }) {
    return StockMovement(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      date: date ?? this.date,
      companyId: companyId ?? this.companyId,
      factoryId: factoryId ?? this.factoryId,
      userId: userId ?? this.userId,
      referenceId: referenceId ?? this.referenceId,
      isSynced: isSynced ?? this.isSynced,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // دالة للتحقق من المساواة
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          itemId == other.itemId &&
          quantity == other.quantity &&
          type == other.type &&
          date == other.date &&
          companyId == other.companyId &&
          factoryId == other.factoryId;

  @override
  int get hashCode =>
      id.hashCode ^
      itemId.hashCode ^
      quantity.hashCode ^
      type.hashCode ^
      date.hashCode ^
      companyId.hashCode ^
      factoryId.hashCode;

  @override
  String toString() {
    return 'StockMovement(id: $id, itemId: $itemId, quantity: $quantity, type: $type, date: $date)';
  }
}