// models/stock_receipt.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StockReceiptItem {
  final String itemId;
  final double orderedQuantity;
  final double receivedQuantity;
  final double unitPrice;
  final double totalAmount;

  StockReceiptItem({
    required this.itemId,
    required this.orderedQuantity,
    required this.receivedQuantity,
    required this.unitPrice,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'orderedQuantity': orderedQuantity,
      'receivedQuantity': receivedQuantity,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,
    };
  }

  factory StockReceiptItem.fromMap(Map<String, dynamic> map) {
    return StockReceiptItem(
      itemId: map['itemId'] ?? '',
      orderedQuantity: (map['orderedQuantity'] as num?)?.toDouble() ?? 0.0,
      receivedQuantity: (map['receivedQuantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StockReceipt {
  final String id;
  final String companyId;
  final String purchaseOrderId;
  final String factoryId;
  final String supplierId;
  final DateTime receivedDate;
  final List<StockReceiptItem> items;
  final double totalReceivedAmount;
  final String? journalEntryId;
  final DateTime createdAt;
  final String createdBy;
  final String? notes;

  StockReceipt({
    required this.id,
    required this.companyId,
    required this.purchaseOrderId,
    required this.factoryId,
    required this.supplierId,
    required this.receivedDate,
    required this.items,
    required this.totalReceivedAmount,
    this.journalEntryId,
    required this.createdAt,
    required this.createdBy,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'purchaseOrderId': purchaseOrderId,
      'factoryId': factoryId,
      'supplierId': supplierId,
      'receivedDate': Timestamp.fromDate(receivedDate),
      'items': items.map((i) => i.toMap()).toList(),
      'totalReceivedAmount': totalReceivedAmount,
      'journalEntryId': journalEntryId,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'notes': notes,
    };
  }

  factory StockReceipt.fromMap(Map<String, dynamic> map, String id) {
    return StockReceipt(
      id: id,
      companyId: map['companyId'] ?? '',
      purchaseOrderId: map['purchaseOrderId'] ?? '',
      factoryId: map['factoryId'] ?? '',
      supplierId: map['supplierId'] ?? '',
      receivedDate: (map['receivedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (map['items'] as List?)
              ?.map((i) => StockReceiptItem.fromMap(i))
              .toList() ??
          [],
      totalReceivedAmount: (map['totalReceivedAmount'] as num?)?.toDouble() ?? 0.0,
      journalEntryId: map['journalEntryId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      notes: map['notes'],
    );
  }
}