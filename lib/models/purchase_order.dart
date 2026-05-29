import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/item.dart';

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String userId;
  final String companyId;
  final String? factoryId;
  final String supplierId;
  final DateTime orderDate;
  final String status;
  final List<Item> items;
  final double taxRate;
  final double totalAmount;
  final double totalTax;
  final double totalAmountAfterTax;
  final bool isDelivered;
  
  // ✅ ضريبة الخصم من المنبع
  final double withholdingTaxAmount;
  final double withholdingTaxRate;
  final double netPayable;
  
  // ✅ شروط الدفع والتسليم
  final String? paymentTermCode;
  final String? deliveryTermCode;
  
  // ✅ العناصر الإضافية (قوائم المعرفات)
  final List<String> conditionsIds;
  final List<String> documentsIds;
  final List<String> notesIds;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.userId,
    required this.companyId,
    this.factoryId,
    required this.supplierId,
    required this.orderDate,
    required this.status,
    required this.items,
    required this.taxRate,
    required this.totalAmount,
    required this.totalTax,
    required this.totalAmountAfterTax,
    required this.isDelivered,
    this.withholdingTaxAmount = 0.0,
    this.withholdingTaxRate = 0.0,
    this.netPayable = 0.0,
    this.paymentTermCode,
    this.deliveryTermCode,
    this.conditionsIds = const [],
    this.documentsIds = const [],
    this.notesIds = const [],
  });

  factory PurchaseOrder.fromMap(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseOrder(
      id: doc.id,
      poNumber: data['poNumber'] ?? '',
      userId: data['userId'] ?? '',
      companyId: data['companyId'] ?? '',
      factoryId: data['factoryId'],
      supplierId: data['supplierId'] ?? '',
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => Item.fromMap(item as Map<String, dynamic>))
          .toList(),
      taxRate: (data['taxRate'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      totalTax: (data['totalTax'] ?? 0.0).toDouble(),
      totalAmountAfterTax: (data['totalAmountAfterTax'] ?? 0.0).toDouble(),
      isDelivered: data['isDelivered'] ?? false,
      withholdingTaxAmount: (data['withholdingTaxAmount'] ?? 0.0).toDouble(),
      withholdingTaxRate: (data['withholdingTaxRate'] ?? 0.0).toDouble(),
      netPayable: (data['netPayable'] ?? 0.0).toDouble(),
      paymentTermCode: data['paymentTermCode'],
      deliveryTermCode: data['deliveryTermCode'],
      conditionsIds: List<String>.from(data['conditionsIds'] ?? []),
      documentsIds: List<String>.from(data['documentsIds'] ?? []),
      notesIds: List<String>.from(data['notesIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'poNumber': poNumber,
      'userId': userId,
      'companyId': companyId,
      'factoryId': factoryId,
      'supplierId': supplierId,
      'orderDate': Timestamp.fromDate(orderDate),
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'taxRate': taxRate,
      'totalAmount': totalAmount,
      'totalTax': totalTax,
      'totalAmountAfterTax': totalAmountAfterTax,
      'isDelivered': isDelivered,
      'withholdingTaxAmount': withholdingTaxAmount,
      'withholdingTaxRate': withholdingTaxRate,
      'netPayable': netPayable,
      'paymentTermCode': paymentTermCode,
      'deliveryTermCode': deliveryTermCode,
      'conditionsIds': conditionsIds,
      'documentsIds': documentsIds,
      'notesIds': notesIds,
    };
  }

  PurchaseOrder copyWith({
    String? id,
    String? poNumber,
    String? userId,
    String? companyId,
    String? factoryId,
    String? supplierId,
    DateTime? orderDate,
    String? status,
    List<Item>? items,
    double? taxRate,
    double? totalAmount,
    double? totalTax,
    double? totalAmountAfterTax,
    bool? isDelivered,
    double? withholdingTaxAmount,
    double? withholdingTaxRate,
    double? netPayable,
    String? paymentTermCode,
    String? deliveryTermCode,
    List<String>? conditionsIds,
    List<String>? documentsIds,
    List<String>? notesIds,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      poNumber: poNumber ?? this.poNumber,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      factoryId: factoryId ?? this.factoryId,
      supplierId: supplierId ?? this.supplierId,
      orderDate: orderDate ?? this.orderDate,
      status: status ?? this.status,
      items: items ?? this.items,
      taxRate: taxRate ?? this.taxRate,
      totalAmount: totalAmount ?? this.totalAmount,
      totalTax: totalTax ?? this.totalTax,
      totalAmountAfterTax: totalAmountAfterTax ?? this.totalAmountAfterTax,
      isDelivered: isDelivered ?? this.isDelivered,
      withholdingTaxAmount: withholdingTaxAmount ?? this.withholdingTaxAmount,
      withholdingTaxRate: withholdingTaxRate ?? this.withholdingTaxRate,
      netPayable: netPayable ?? this.netPayable,
      paymentTermCode: paymentTermCode ?? this.paymentTermCode,
      deliveryTermCode: deliveryTermCode ?? this.deliveryTermCode,
      conditionsIds: conditionsIds ?? this.conditionsIds,
      documentsIds: documentsIds ?? this.documentsIds,
      notesIds: notesIds ?? this.notesIds,
    );
  }
}