import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// جلب الشركات المرتبطة بالمستخدم
Future<List<Map<String, dynamic>>> fetchUserCompanies(String uid) async {
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);

  final List<Map<String, dynamic>> companies = [];
  for (final id in companyIds) {
    final doc = await FirebaseFirestore.instance.collection('companies').doc(id).get();
    if (doc.exists) {
      // اختر إما 'nameAr' أو 'nameEn' أو 'name' حسب هيكل البيانات لديك
      final name = doc.data()?['nameAr'] ?? doc.data()?['nameEn'] ?? 'Unnamed Company';
      companies.add({'id': doc.id, 'name': name});
    }
  }
  return companies;
}

/// Dropdown لاختيار الشركة
class CompanySelector extends StatefulWidget {
  final String userId; // معرف المستخدم
  final Function(String companyId) onCompanySelected;

  const CompanySelector({
    super.key,
    required this.userId,
    required this.onCompanySelected,
  });

  @override
  State<CompanySelector> createState() => _CompanySelectorState();
}

class _CompanySelectorState extends State<CompanySelector> {
  List<Map<String, dynamic>> companies = [];
  String? selectedCompany;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    if (widget.userId.isEmpty) {
      setState(() {
        companies = [];
        isLoading = false;
      });
      return;
    }

    final fetchedCompanies = await fetchUserCompanies(widget.userId);
    setState(() {
      companies = fetchedCompanies;
      isLoading = false;

      if (companies.isNotEmpty) {
        selectedCompany = companies.first['id'];
        widget.onCompanySelected(selectedCompany!);
      } else {
        selectedCompany = null; // No companies found
        widget.onCompanySelected(''); // Notify parent no company selected
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (companies.isEmpty) {
      return const Text(
        'لم يتم العثور على شركات مرتبطة بالحساب',
        style: TextStyle(color: Colors.red),
      );
    }

    return DropdownButton<String>(
      value: selectedCompany,
      isExpanded: true,
      hint: const Text('اختر شركة'), // إضافة نص توضيحي
      items: companies.map<DropdownMenuItem<String>>((company) {
        return DropdownMenuItem<String>(
          value: company['id'] as String,
          child: Text(company['name']),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => selectedCompany = value);
        if (value != null) {
          widget.onCompanySelected(value);
        }
      },
    );
  }
}