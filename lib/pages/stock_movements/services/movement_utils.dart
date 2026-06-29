// lib/utils/movement_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class MovementUtils {
  static Map<String, dynamic> getMovementTypeInfo(String type, double quantity) {
    // التأكد من أن الكمية موجبة دائمًا
    final absQuantity = quantity.abs();
    
    // دالة مساعدة لضمان أننا نحصل على String دائمًا
    String trSafe(String key) {
      try {
        final result = key.tr();
        return result;
      } catch (e) {
        return key;
      }
    }
    
    switch (type) {
      case 'purchase':
      case 'purchase_order':
      case 'buy':
        return {
          'in': absQuantity,
          'out': 0,
          'type_text': trSafe('purchase'),
        };
      case 'manufacturing':
      case 'manufacturing_deduction':
      case 'production':
        return {
          'in': 0,
          'out': absQuantity,
          'type_text': trSafe('manufacturing'),
        };
      case 'transfer_in':
      case 'receiving':
        return {
          'in': absQuantity,
          'out': 0,
          'type_text': trSafe('transfer_in'),
        };
      case 'transfer_out':
      case 'sending':
        return {
          'in': 0,
          'out': absQuantity,
          'type_text': trSafe('transfer_out'),
        };
      case 'adjustment':
      case 'correction':
        // للتصحيحات، نتحقق من إشارة الكمية
        if (quantity > 0) {
          return {
            'in': absQuantity,
            'out': 0,
            'type_text': trSafe('positive_adjustment'),
          };
        } else {
          return {
            'in': 0,
            'out': absQuantity,
            'type_text': trSafe('negative_adjustment'),
          };
        }
      case 'sale':
      case 'sales':
        return {
          'in': 0,
          'out': absQuantity,
          'type_text': trSafe('sale'),
        };
      case 'return':
      case 'returns':
        return {
          'in': absQuantity,
          'out': 0,
          'type_text': trSafe('return'),
        };
      default:
        // إذا كان النوع غير معروف، نتحقق من إشارة الكمية
        if (quantity > 0) {
          return {
            'in': absQuantity,
            'out': 0,
            'type_text': trSafe('unknown_in'),
          };
        } else {
          return {
            'in': 0,
            'out': absQuantity,
            'type_text': trSafe('unknown_out'),
          };
        }
    }
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  static String getMovementTypeDisplay(String type) {
    switch (type) {
      case 'purchase':
      case 'purchase_order':
      case 'buy':
        return 'purchase'.tr();
      case 'manufacturing':
      case 'manufacturing_deduction':
      case 'production':
        return 'manufacturing'.tr();
      case 'transfer_in':
      case 'receiving':
        return 'transfer_in'.tr();
      case 'transfer_out':
      case 'sending':
        return 'transfer_out'.tr();
      case 'adjustment':
      case 'correction':
        return 'adjustment'.tr();
      case 'sale':
      case 'sales':
        return 'sale'.tr();
      case 'return':
      case 'returns':
        return 'return'.tr();
      default:
        return 'unknown'.tr();
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMovements({
    Map<String, dynamic>? filters,
  }) async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('stock_movements')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? {},
            toFirestore: (m, _) => m,
          );

      // تطبيق الفلاتر
      if (filters != null) {
        if (filters['companyId'] != null) {
          query = query.where('companyId', isEqualTo: filters['companyId']);
        }
        if (filters['factoryId'] != null) {
          query = query.where('factoryId', isEqualTo: filters['factoryId']);
        }
        if (filters['itemId'] != null) {
          query = query.where('itemId', isEqualTo: filters['itemId']);
        }
        if (filters['fromDate'] != null && filters['toDate'] != null) {
          query = query
              .where('date', isGreaterThanOrEqualTo: filters['fromDate'])
              .where('date', isLessThanOrEqualTo: filters['toDate']);
        }
/*         if (filters['movementType'] != null) {
          query = query.where('type', isEqualTo: filters['movementType']);
        } */
      }

      final querySnapshot = await query.get();
      final movements = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': data['date']?.toString(),
          'company': data['nameAr'] ?? data['companyId'],
          'factory': data['nameAr'] ?? data['factoryId'],
          'item': data['nameAr'] ?? data['itemId'],
          'quantity': data['quantity']?.toString(),
          'movementType': getMovementTypeDisplay(data['type'] ?? ''),
          'user': data['displayName'] ?? data['userId'],
        };
      }).toList();

      return movements;
    } catch (e) {
      safeDebugPrint('Error fetching movements: $e');
      rethrow;
    }
  }
  
  static Future<void> exportExcel(List<Map<String, dynamic>> data) async {
    // نفّذ تصدير Excel هنا
    safeDebugPrint("Exporting Excel with ${data.length} records...");
  }
}