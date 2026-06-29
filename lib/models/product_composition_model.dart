// product_composition_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductComposition {
  static const fieldProductId = 'productId';
  static const fieldCompanyId = 'companyId';
  static const fieldFactoryId = 'factoryId';
  static const fieldBatchSize = 'batchSize';
  static const fieldUnit = 'unit';
  static const fieldRawMaterials = 'rawMaterials';
  static const fieldPackagingMaterials = 'packagingMaterials';
  static const fieldShelfLife = 'shelfLife';
  static const fieldCreatedAt = 'createdAt';
  static const fieldUserId = 'userId';

  final String? id;
  final String productId;
  final String companyId;
  final String factoryId;
  final double batchSize;
  final String unit;
  final List<CompositionItem> rawMaterials;
  final List<CompositionItem> packagingMaterials;
  final int shelfLife;
  final Timestamp createdAt;
  final String userId;

  ProductComposition({
    this.id,
    required this.productId,
    required this.companyId,
    required this.factoryId,
    required this.batchSize,
    required this.unit,
    required this.rawMaterials,
    required this.packagingMaterials,
    required this.shelfLife,
    required this.createdAt,
    required this.userId,
  });

  factory ProductComposition.fromMap(Map<String, dynamic> data, String documentId) {
    return ProductComposition(
      id: documentId,
      productId: data[fieldProductId] ?? '',
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      batchSize: (data[fieldBatchSize] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      rawMaterials: List<CompositionItem>.from(
        (data[fieldRawMaterials] ?? []).map((item) => CompositionItem.fromMap(item)),
      ),
      packagingMaterials: List<CompositionItem>.from(
        (data[fieldPackagingMaterials] ?? []).map((item) => CompositionItem.fromMap(item)),
      ),
      shelfLife: data[fieldShelfLife] ?? 0,
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
      userId: data[fieldUserId] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      fieldProductId: productId,
      fieldCompanyId: companyId,
      fieldFactoryId: factoryId,
      fieldBatchSize: batchSize,
      fieldUnit: unit,
      fieldRawMaterials: rawMaterials.map((item) => item.toMap()).toList(),
      fieldPackagingMaterials: packagingMaterials.map((item) => item.toMap()).toList(),
      fieldShelfLife: shelfLife,
      fieldCreatedAt: createdAt,
      fieldUserId: userId,
    };
  }
}

class CompositionItem {
  final String itemId;
  final double quantity;
  final String unit;

  CompositionItem({
    required this.itemId,
    required this.quantity,
    required this.unit,
  });

  factory CompositionItem.fromMap(Map<String, dynamic> data) {
    return CompositionItem(
      itemId: data['itemId'] ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'quantity': quantity,
      'unit': unit,
    };
  }
}