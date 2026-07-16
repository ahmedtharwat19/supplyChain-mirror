// lib/models/account.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountType {
  asset,      // أصل
  liability,  // التزام
  equity,     // حقوق ملكية
  revenue,    // إيراد
  expense,    // مصروف
}

enum AccountCategory {
  cash,               // خزينة
  bank,               // بنك
  accountsPayable,    // دائنون (موردين)
  inventory,          // مخزون
  purchases,          // مشتريات
  sales,              // مبيعات
  other,              // أخرى
}

class Account {
  final String id;
  final String companyId;
  final String code;
  final String nameAr;
  final String nameEn;
  final AccountType type;
  final AccountCategory category;
  final bool isActive;
  final double balance; // الرصيد الحالي (يمكن حسابه من القيود)
  final DateTime createdAt;
  final String? parentAccountId; // للحسابات الفرعية

  Account({
    required this.id,
    required this.companyId,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.type,
    required this.category,
    this.isActive = true,
    this.balance = 0.0,
    required this.createdAt,
    this.parentAccountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'code': code,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'type': type.name,
      'category': category.name,
      'isActive': isActive,
      'balance': balance,
      'createdAt': Timestamp.fromDate(createdAt),
      'parentAccountId': parentAccountId,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map, String id) {
    return Account(
      id: id,
      companyId: map['companyId'] ?? '',
      code: map['code'] ?? '',
      nameAr: map['nameAr'] ?? '',
      nameEn: map['nameEn'] ?? '',
      type: AccountType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AccountType.asset,
      ),
      category: AccountCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => AccountCategory.other,
      ),
      isActive: map['isActive'] ?? true,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentAccountId: map['parentAccountId'],
    );
  }

  Account copyWith({double? balance}) {
    return Account(
      id: id,
      companyId: companyId,
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      type: type,
      category: category,
      isActive: isActive,
      balance: balance ?? this.balance,
      createdAt: createdAt,
      parentAccountId: parentAccountId,
    );
  }
}