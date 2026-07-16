// helpers/company_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class CompanyHelper {
  static const String _keySelectedCompanyId = 'selected_company_id';

  // تحميل قائمة الشركات للمستخدم الحالي مع الاسمين (عربي وإنجليزي)
  static Future<List<Map<String, String>>> getUserCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
    if (companyIds.isEmpty) return [];

    final List<Map<String, String>> companies = [];
    for (String id in companyIds) {
      try {
        final doc = await FirebaseFirestore.instance.collection('companies').doc(id).get();
        if (doc.exists) {
          final data = doc.data()!;
          final nameAr = data['nameAr'] ?? data['name'] ?? data['companyName'] ?? id;
          final nameEn = data['nameEn'] ?? data['name'] ?? data['companyName'] ?? id;
          companies.add({
            'id': id,
            'nameAr': nameAr.toString(),
            'nameEn': nameEn.toString(),
          });
        } else {
          // إذا كانت الشركة غير موجودة، نضيفها مع اسم افتراضي
          companies.add({
            'id': id,
            'nameAr': 'شركة $id',
            'nameEn': 'Company $id',
          });
        }
      } catch (e) {
        // تجاهل
      }
    }
    return companies;
  }

  // تحميل الشركة المختارة من SharedPreferences
  static Future<String?> getSelectedCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedCompanyId);
  }

  // حفظ الشركة المختارة
  static Future<void> setSelectedCompanyId(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedCompanyId, companyId);
  }

  // ✅ دالة مساعدة لإنشاء DropdownButton مع دعم اللغة
  static Widget buildCompanyDropdown({
    required List<Map<String, String>> companies,
    required String? selectedCompanyId,
    required ValueChanged<String?> onChanged,
    required String languageCode,
    Color? dropdownColor,
    Color? textColor,
    Color? iconColor,
  }) {
    if (companies.length <= 1) {
      return const SizedBox.shrink();
    }

    return DropdownButton<String>(
      value: selectedCompanyId,
      hint: Text(
        'select_company'.tr(),
        style: TextStyle(color: textColor ?? Colors.white),
      ),
      items: companies.map((company) {
        // اختيار الاسم حسب اللغة
        final companyName = languageCode == 'ar'
            ? (company['nameAr'] ?? company['nameEn'] ?? company['id'])
            : (company['nameEn'] ?? company['nameAr'] ?? company['id']);
        return DropdownMenuItem<String>(
          value: company['id'],
          child: Text(
            companyName!,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      dropdownColor: dropdownColor ?? const Color.fromARGB(255, 69, 200, 218),
      underline: const SizedBox(),
      icon: Icon(
        Icons.arrow_drop_down,
        color: iconColor ?? Colors.white,
      ),
      style: TextStyle(
        color: textColor ?? Colors.white,
        fontSize: 16,
      ),
    );
  }
}