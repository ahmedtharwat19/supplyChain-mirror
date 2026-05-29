// pages/factories/add_factory_page.dart - النسخة النهائية بدون Hive وبدون UserLocalStorage
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class AddFactoryPage extends StatefulWidget {
  const AddFactoryPage({super.key});

  @override
  State<AddFactoryPage> createState() => _AddFactoryPageState();
}

class _AddFactoryPageState extends State<AddFactoryPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameAr = TextEditingController();
  final TextEditingController _nameEn = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _manager = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  bool _isLoading = false;
  bool _warnAr = false, _warnEn = false, _warnPhone = false;

  List<Map<String, dynamic>> _companies = [];
  final List<String> _selectedCompanyIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies();
    });
  }

  Future<void> _loadCompanies() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final List<String> ids = List<String>.from(userDoc.data()?['companyIds'] ?? []);
    safeDebugPrint('📦 companyIds from Firestore user doc: $ids');

    if (ids.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: ids)
        .get();

    final loaded = snapshot.docs.map((doc) => {
      'id': doc.id,
      'name': isArabic ? doc.data()['nameAr'] ?? '' : doc.data()['nameEn'] ?? '',
    }).toList();

    safeDebugPrint('✅ Loaded companies count: ${loaded.length}');
    setState(() => _companies = loaded);
  }

  Future<void> _addFactory() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCompanyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_select_at_least_one_company'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;
    
    final data = {
      'nameAr': _nameAr.text.trim(),
      'nameEn': _nameEn.text.trim(),
      'location': _location.text.trim(),
      'managerName': _manager.text.trim(),
      'managerPhone': _phone.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'companyIds': _selectedCompanyIds,
    };

    try {
      final doc = await FirebaseFirestore.instance.collection('factories').add(data);

      // تحديث قائمة المصانع في مستند المستخدم
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'factoryIds': FieldValue.arrayUnion([doc.id]),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('factory_added_successfully'))),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_occurred')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('add_factory')),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ==================== حقل الاسم عربي ====================
              TextFormField(
                controller: _nameAr,
                decoration: InputDecoration(
                  labelText: tr('factory_nameAr'),
                  errorText: _warnAr ? tr('only_arabic_allowed') : null,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.text_fields),
                ),
                onChanged: (value) {
                  final hasNonArabic = RegExp(r'[^\u0600-\u06FF\s]').hasMatch(value);
                  setState(() {
                    _warnAr = hasNonArabic && value.isNotEmpty;
                  });
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('field_required');
                  }
                  if (RegExp(r'[^\u0600-\u06FF\s]').hasMatch(v)) {
                    return tr('only_arabic_allowed');
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // ==================== حقل الاسم إنجليزي ====================
              TextFormField(
                controller: _nameEn,
                decoration: InputDecoration(
                  labelText: tr('factory_nameEn'),
                  errorText: _warnEn ? tr('only_english_allowed') : null,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.translate),
                ),
                onChanged: (value) {
                  final hasNonEnglish = RegExp(r'[^a-zA-Z\s]').hasMatch(value);
                  setState(() {
                    _warnEn = hasNonEnglish && value.isNotEmpty;
                  });
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('field_required');
                  }
                  if (RegExp(r'[^a-zA-Z\s]').hasMatch(v)) {
                    return tr('only_english_allowed');
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // ==================== حقل الموقع ====================
              TextFormField(
                controller: _location,
                decoration: InputDecoration(
                  labelText: tr('location'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? tr('field_required') : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // ==================== حقل اسم المدير ====================
              TextFormField(
                controller: _manager,
                decoration: InputDecoration(
                  labelText: tr('managerName'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? tr('field_required') : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // ==================== حقل هاتف المدير ====================
              TextFormField(
                controller: _phone,
                decoration: InputDecoration(
                  labelText: tr('managerPhone'),
                  errorText: _warnPhone ? tr('only_digits_allowed') : null,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  setState(() {
                    _warnPhone = value.isNotEmpty && !RegExp(r'^\d+$').hasMatch(value);
                  });
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('field_required');
                  }
                  if (!RegExp(r'^\d+$').hasMatch(v)) {
                    return tr('only_digits_allowed');
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              // ==================== اختيار الشركات ====================
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            tr('select_companies'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_companies.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              tr('no_companies_found'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        Column(
                          children: _companies.map((company) {
                            final companyId = company['id'] as String;
                            final companyName = company['name'] ?? 'Unnamed';

                            return CheckboxListTile(
                              title: Text(companyName),
                              value: _selectedCompanyIds.contains(companyId),
                              onChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedCompanyIds.add(companyId);
                                  } else {
                                    _selectedCompanyIds.remove(companyId);
                                  }
                                });
                              },
                              activeColor: Theme.of(context).primaryColor,
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // ==================== زر الحفظ ====================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addFactory,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr('save'), style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _location.dispose();
    _manager.dispose();
    _phone.dispose();
    super.dispose();
  }
}