// add_company_page.dart - تصحيح الأخطاء

// ✅ احذف هذه الأسطر من الملف:

// السطر 38 - احذف هذا المتغير (غير مستخدم)
// final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

// السطر 46 - احذف هذا المفتاح (غير مستخدم)
// static const String _keyUserData = 'user_data';

// ✅ الكود النهائي المصحح للجزء العلوي من الملف:

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class AddCompanyPage extends StatefulWidget {
  const AddCompanyPage({super.key});

  @override
  State<AddCompanyPage> createState() => _AddCompanyPageState();
}

class _AddCompanyPageState extends State<AddCompanyPage> {
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _addressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();

  File? _logoImage;
  Uint8List? _imageBytes;
  String? _base64Logo;

  bool _isLoading = false;
  User? _currentUser;

  // ❌ تم حذف _secureStorage لأنه غير مستخدم

  // تعريف الـ RegExp للتحقق
  final RegExp arabicRegExp = RegExp(r'^[\u0600-\u06FF\s]*$');
  final RegExp englishRegExp = RegExp(r'^[a-zA-Z\s]*$');
  final RegExp phoneRegExp = RegExp(r'^[\d+\-\s\(\)]*$');

  // ✅ مفاتيح التخزين - تم حذف _keyUserData غير المستخدم
  static const String _keyCompaniesCache = 'companies_cache';
  static const String _keyUserCompaniesPrefix = 'user_companies_';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    safeDebugPrint('👤 المستخدم الحالي: ${_currentUser?.uid ?? "غير مسجل"}');
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _addressController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    if (_nameArController.text.trim().isEmpty ||
        _nameEnController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('required_fields'))),
      );
      return false;
    }

    if (!arabicRegExp.hasMatch(_nameArController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('company_name_arabic_invalid'))),
      );
      return false;
    }

    if (!englishRegExp.hasMatch(_nameEnController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('company_name_english_invalid'))),
      );
      return false;
    }

    if (_managerPhoneController.text.trim().isNotEmpty) {
      if (!phoneRegExp.hasMatch(_managerPhoneController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('phone_number_invalid'))),
        );
        return false;
      }
    }

    if (_base64Logo == null || _base64Logo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_select_logo'))),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      _imageBytes = bytes;
      _base64Logo = base64Encode(bytes);
      if (!kIsWeb) _logoImage = File(pickedFile.path);

      setState(() {});
      safeDebugPrint('✅ تم اختيار الشعار بنجاح');
    } catch (e) {
      safeDebugPrint('❌ خطأ أثناء اختيار الشعار: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_selecting_logo'))),
        );
      }
    }
  }

  /// ✅ التحقق من تكرار الشركة من الكاش فقط (سريع)
  Future<bool> _isCompanyDuplicateFromCache(String nameAr, String nameEn) async {
    final userId = _currentUser?.uid;
    if (userId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final cachedCompaniesJson = prefs.getString('$_keyUserCompaniesPrefix$userId');
    
    if (cachedCompaniesJson != null) {
      final companies = List<Map<String, dynamic>>.from(json.decode(cachedCompaniesJson));
      final normalizedAr = nameAr.trim().toLowerCase();
      final normalizedEn = nameEn.trim().toLowerCase();

      for (var company in companies) {
        final existingAr = (company['nameAr'] ?? '').toString().trim().toLowerCase();
        final existingEn = (company['nameEn'] ?? '').toString().trim().toLowerCase();
        if (existingAr == normalizedAr || existingEn == normalizedEn) return true;
      }
    }
    return false;
  }

  /// ✅ حفظ الشركة في SharedPreferences
  Future<void> _saveCompanyToCache(String companyId, Map<String, dynamic> companyData, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // حفظ بيانات الشركة
      final companiesJson = prefs.getString(_keyCompaniesCache);
      List<dynamic> allCompanies = companiesJson != null ? json.decode(companiesJson) : [];
      allCompanies.add({
        'id': companyId,
        ...companyData,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await prefs.setString(_keyCompaniesCache, json.encode(allCompanies));

      // تحديث قائمة شركات المستخدم
      final userCompaniesKey = '$_keyUserCompaniesPrefix$userId';
      final existingCompaniesJson = prefs.getString(userCompaniesKey);
      final existingCompanies = existingCompaniesJson != null 
          ? List<Map<String, dynamic>>.from(json.decode(existingCompaniesJson)) 
          : [];

      existingCompanies.add({
        'id': companyId,
        'nameAr': companyData['nameAr'],
        'nameEn': companyData['nameEn'],
        'logoBase64': companyData['logoBase64'],
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await prefs.setString(userCompaniesKey, json.encode(existingCompanies));
      safeDebugPrint('[CACHE] Company saved locally');
    } catch (e) {
      safeDebugPrint('[CACHE ERROR] Failed to save locally: $e');
    }
  }

  /// ✅ إضافة الشركة
  Future<void> _addCompany() async {
    if (!_validateInputs()) return;

    final userId = _currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('user_not_logged_in'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ تحقق سريع من الكاش فقط
      final isDuplicate = await _isCompanyDuplicateFromCache(
          _nameArController.text, _nameEnController.text);
      if (isDuplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('company_already_exists'))),
        );
        setState(() => _isLoading = false);
        return;
      }

      final companyData = {
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim(),
        'address': _addressController.text.trim(),
        'managerName': _managerNameController.text.trim(),
        'managerPhone': _managerPhoneController.text.trim(),
        'logoBase64': _base64Logo,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('companies')
          .add(companyData);
      final companyId = docRef.id;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'companyIds': FieldValue.arrayUnion([companyId])});

      await _saveCompanyToCache(companyId, companyData, userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('company_added_successfully'))),
        );
        context.pop({
          'success': true,
          'company': {
            'id': companyId,
            ...companyData,
            'createdAt': Timestamp.now(),
          }
        });
      }
    } catch (e) {
      safeDebugPrint('❌ خطأ أثناء إضافة الشركة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_while_adding_company'))),
        );
        context.pop({'success': false, 'error': e.toString()});
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: tr('add_company'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم الشركة بالعربية
                  TextFormField(
                    controller: _nameArController,
                    decoration: InputDecoration(
                      labelText: tr('company_nameArabic'),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      prefixIcon: const Icon(Icons.text_fields),
                      hintText: 'مثال: شركة الأمل',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // اسم الشركة بالإنجليزية
                  TextFormField(
                    controller: _nameEnController,
                    decoration: InputDecoration(
                      labelText: tr('company_nameEnglish'),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      prefixIcon: const Icon(Icons.translate),
                      hintText: 'Example: Al Amal Company',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // عنوان الشركة
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: tr('company_address'),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      prefixIcon: const Icon(Icons.location_on),
                      hintText: tr('enter_address'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // اسم المدير
                  TextFormField(
                    controller: _managerNameController,
                    decoration: InputDecoration(
                      labelText: tr('company_managerName'),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      prefixIcon: const Icon(Icons.person),
                      hintText: tr('enter_manager_name'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // رقم هاتف المدير
                  TextFormField(
                    controller: _managerPhoneController,
                    decoration: InputDecoration(
                      labelText: tr('company_managerPhone'),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      prefixIcon: const Icon(Icons.phone),
                      hintText: '012xxxxxxx',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s\(\)]')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // زر اختيار الشعار
                  ElevatedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.image),
                    label: Text(tr('please_select_logo')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.grey.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                  // عرض الصورة المختارة
                  if (_imageBytes != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          kIsWeb
                              ? Image.memory(_imageBytes!, height: 150, fit: BoxFit.contain)
                              : Image.file(_logoImage!, height: 150, fit: BoxFit.contain),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _imageBytes = null;
                                _logoImage = null;
                                _base64Logo = null;
                              });
                            },
                            icon: const Icon(Icons.delete, size: 16),
                            label: Text(tr('remove_logo')),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // زر الإضافة
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addCompany,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: const Color.fromARGB(255, 69, 200, 218),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              tr('add_company'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}