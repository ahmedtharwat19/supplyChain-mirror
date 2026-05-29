import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

enum ManufacturingStatus { pending, inProgress, completed, cancelled }

enum QualityStatus { pending, passed, failed }

class ManufacturingRun {
  final String batchNumber;
  final int quantity;
  final DateTime? completedAt;

  ManufacturingRun({
    required this.batchNumber,
    required this.quantity,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'batchNumber': batchNumber,
      'quantity': quantity,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory ManufacturingRun.fromMap(Map<String, dynamic> map) {
    return ManufacturingRun(
      batchNumber: map['batchNumber'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ManufacturingOrder {
  final String id;
  final String productId;
  final String productName;
  final int totalQuantity;
  final String productUnit;
  final DateTime manufacturingDate;
  final DateTime expiryDate;
  final ManufacturingStatus status;
  final bool isFinished;
  final List<RawMaterial> rawMaterials;
  final List<PackagingMaterial> packagingMaterials;
  final DateTime createdAt;
  final QualityStatus qualityStatus;
  final String? qualityNotes;
  final String? barcodeUrl;
  final List<ManufacturingRun> runs;
  final String companyId; // أضف هذه الخاصية
  final String factoryId; // أضف هذه الخاصية

  ManufacturingOrder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.productUnit,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.status,
    required this.isFinished,
    required this.rawMaterials,
    required this.packagingMaterials,
    required this.createdAt,
    required this.runs,
    required this.companyId, // أضف هنا
    required this.factoryId, // أضف هنا
    this.qualityStatus = QualityStatus.pending,
    this.qualityNotes,
    this.barcodeUrl,
  });

  bool get isExpiringSoon {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7;
  }

  String get statusText {
    switch (status) {
      case ManufacturingStatus.pending:
        return 'manufacture.status_pending'.tr();
      case ManufacturingStatus.inProgress:
        return 'manufacture.status_inProgress'.tr();
      case ManufacturingStatus.completed:
        return 'manufacture.status_completed'.tr();
      case ManufacturingStatus.cancelled:
        return 'manufacture.status_cancelled'.tr();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'totalQuantity': totalQuantity,
      'productUnit': productUnit,
      'manufacturingDate': manufacturingDate is Timestamp 
          ? manufacturingDate 
          : Timestamp.fromDate(manufacturingDate),
      'expiryDate': expiryDate is Timestamp 
          ? expiryDate 
          : Timestamp.fromDate(expiryDate),
      'status': status.toString().split('.').last,
      'isFinished': isFinished,
      'rawMaterials': rawMaterials.map((rm) => rm.toMap()).toList(),
      'packagingMaterials': packagingMaterials.map((pm) => pm.toMap()).toList(),
      'createdAt': createdAt is Timestamp 
          ? createdAt 
          : Timestamp.fromDate(createdAt),
      'qualityStatus': qualityStatus.toString().split('.').last,
      'qualityNotes': qualityNotes,
      'barcodeUrl': barcodeUrl,
      'runs': runs.map((run) => run.toMap()).toList(),
      'companyId': companyId, // استخدم الخاصية المضافة
      'factoryId': factoryId, // استخدم الخاصية المضافة
    };
  }

  factory ManufacturingOrder.fromMap(Map<String, dynamic> map) {
    return ManufacturingOrder(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      totalQuantity: (map['totalQuantity'] as num?)?.toInt() ?? 0,
      productUnit: map['productUnit'] ?? '',
      manufacturingDate:
          (map['manufacturingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(map['status']),
      isFinished: map['isFinished'] ?? false,
      rawMaterials: List<RawMaterial>.from(
          (map['rawMaterials'] as List<dynamic>?)
                  ?.map((rm) => RawMaterial.fromMap(rm)) ??
              []),
      packagingMaterials: List<PackagingMaterial>.from(
          (map['packagingMaterials'] as List<dynamic>?)
                  ?.map((pk) => PackagingMaterial.fromMap(pk)) ??
              []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      qualityStatus: _parseQualityStatus(map['qualityStatus']),
      qualityNotes: map['qualityNotes'],
      barcodeUrl: map['barcodeUrl'],
      runs: List<ManufacturingRun>.from((map['runs'] as List<dynamic>?)
              ?.map((r) => ManufacturingRun.fromMap(r)) ??
          []),
      companyId: map['companyId'] ?? '', // أضف هنا
      factoryId: map['factoryId'] ?? '', // أضف هنا
    );
  }

  static ManufacturingStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return ManufacturingStatus.pending;
      case 'inProgress':
        return ManufacturingStatus.inProgress;
      case 'completed':
        return ManufacturingStatus.completed;
      case 'cancelled':
        return ManufacturingStatus.cancelled;
      default:
        return ManufacturingStatus.pending;
    }
  }

  static QualityStatus _parseQualityStatus(String? status) {
    switch (status) {
      case 'passed':
        return QualityStatus.passed;
      case 'failed':
        return QualityStatus.failed;
      default:
        return QualityStatus.pending;
    }
  }

  ManufacturingOrder copyWith({
    String? id,
    String? productId,
    String? productName,
    int? totalQuantity,
    String? productUnit,
    DateTime? manufacturingDate,
    DateTime? expiryDate,
    ManufacturingStatus? status,
    bool? isFinished,
    List<RawMaterial>? rawMaterials,
    List<PackagingMaterial>? packagingMaterials,
    DateTime? createdAt,
    List<ManufacturingRun>? runs,
    QualityStatus? qualityStatus,
    String? qualityNotes,
    String? barcodeUrl,
    String? companyId,
    String? factoryId,
  }) {
    return ManufacturingOrder(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      productUnit: productUnit ?? this.productUnit,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      isFinished: isFinished ?? this.isFinished,
      rawMaterials: rawMaterials ?? this.rawMaterials,
      packagingMaterials: packagingMaterials ?? this.packagingMaterials,
      createdAt: createdAt ?? this.createdAt,
      runs: runs ?? this.runs,
      qualityStatus: qualityStatus ?? this.qualityStatus,
      qualityNotes: qualityNotes ?? this.qualityNotes,
      barcodeUrl: barcodeUrl ?? this.barcodeUrl,
      companyId: companyId ?? this.companyId,
      factoryId: factoryId ?? this.factoryId,
    );
  }
}

class RawMaterial {
  final String materialId;
  final String materialName;
  final double quantityRequired;
  final String unit;
  final double minStockLevel;

  RawMaterial({
    required this.materialId,
    required this.materialName,
    required this.quantityRequired,
    required this.unit,
    this.minStockLevel = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'materialId': materialId,
      'materialName': materialName,
      'quantityRequired': quantityRequired,
      'unit': unit,
      'minStockLevel': minStockLevel,
    };
  }

  factory RawMaterial.fromMap(Map<String, dynamic> map) {
    return RawMaterial(
      materialId: map['materialId'] ?? '',
      materialName: map['materialName'] ?? '',
      quantityRequired: (map['quantityRequired'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      minStockLevel: (map['minStockLevel'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PackagingMaterial {
  final String materialId;
  final String materialName;
  final double quantityRequired;
  final String unit;
  final double minStockLevel;

  PackagingMaterial({
    required this.materialId,
    required this.materialName,
    required this.quantityRequired,
    required this.unit,
    this.minStockLevel = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'materialId': materialId,
      'materialName': materialName,
      'quantityRequired': quantityRequired,
      'unit': unit,
      'minStockLevel': minStockLevel,
    };
  }

  factory PackagingMaterial.fromMap(Map<String, dynamic> map) {
    return PackagingMaterial(
      materialId: map['materialId'] ?? '',
      materialName: map['materialName'] ?? '',
      quantityRequired: (map['quantityRequired'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      minStockLevel: (map['minStockLevel'] as num?)?.toDouble() ?? 0,
    );
  }
}