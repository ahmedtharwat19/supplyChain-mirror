

import 'package:puresip_purchasing/models/item.dart';

class PurchaseOrderUtils {
  static double calculateTotal(List<Item> items) {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  static double calculateTotalTax(List<Item> items) {
    return items.fold(0.0, (sum, item) => sum + item.taxAmount);
  }

  static double calculateTotalAfterTax(List<Item> items) {
    return items.fold(0.0, (sum, item) => sum + item.totalAfterTaxAmount);
  }

  static List<Item> recalculateItemsWithTax({
    required List<Item> items,
    required double taxRate,
  }) {
    return items.map((item) {
      final total = item.quantity * item.unitPrice;
      final tax = total * (taxRate / 100);
      final totalWithTax = total + tax;
      return Item(
        itemId: item.itemId,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        quantity: item.quantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        totalPrice: total,
        taxAmount: tax,
        totalAfterTaxAmount: totalWithTax,
        isTaxable: item.isTaxable,
        taxRate: item.isTaxable ? taxRate : 0.0,
        description: item.description,
        category: item.category,
      );
    }).toList();
  }
}
