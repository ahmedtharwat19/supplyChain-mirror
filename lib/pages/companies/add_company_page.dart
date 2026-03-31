import 'dart:convert';
import 'dart:io';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  Uint8List? _webImageBytes;
  String? _base64Logo;

  bool _isLoading = false;
  User? _currentUser;

  // صناديق Hive
  late Box _companiesBox;
  late Box _userDataBox;

  final arabicOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'));
  final englishOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));
  final numbersOnlyFormatter = FilteringTextInputFormatter.digitsOnly;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    safeDebugPrint('👤 المستخدم الحالي: ${_currentUser?.uid ?? "غير مسجل"}');
    _initializeHive();
  }

  // تهيئة Hive
  Future<void> _initializeHive() async {
    try {
      await Hive.initFlutter();
      _companiesBox = await Hive.openBox('companies_cache');
      _userDataBox = await Hive.openBox('user_data_cache');
      safeDebugPrint('[HIVE] Hive initialized successfully');
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _addressController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _companiesBox.close();
    _userDataBox.close();
    super.dispose();
  }

  // التحقق من أن المستخدم نشط في النظام
  Future<bool> _checkUserActive() async {
    final userId = _currentUser?.uid;
    if (userId == null) return false;

    try {
      // التحقق من التخزين المحلي أولاً
      final cachedUser = _userDataBox.get('user_$userId');
      if (cachedUser != null && cachedUser['isActive'] == true) {
        return true;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) return false;
      final isActive = userDoc.data()?['isActive'] ?? false;

      // حفظ في Hive للمرة القادمة
      _userDataBox.put('user_$userId', {
        'isActive': isActive,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });

      return isActive == true;
    } catch (e) {
      safeDebugPrint('❌ خطأ في التحقق من حالة المستخدم: $e');
      return false;
    }
  }

  // ✅ التحقق من تكرار الشركة (بناءً على الاسم العربي أو الإنجليزي)
  Future<bool> _isCompanyDuplicate(String nameAr, String nameEn) async {
    final userId = _currentUser?.uid;
    if (userId == null) return false;

    // التحقق من التخزين المحلي أولاً
    final cachedCompanies = _companiesBox.get('user_companies_$userId');
    if (cachedCompanies != null) {
      final companies = List<Map<String, dynamic>>.from(cachedCompanies);
      final normalizedAr = nameAr.trim().toLowerCase();
      final normalizedEn = nameEn.trim().toLowerCase();

      for (var company in companies) {
        final existingAr =
            (company['nameAr'] ?? '').toString().trim().toLowerCase();
        final existingEn =
            (company['nameEn'] ?? '').toString().trim().toLowerCase();
        if (existingAr == normalizedAr || existingEn == normalizedEn) {
          return true;
        }
      }
    }

    // إذا لم يوجد في التخزين المحلي، التحقق من Firebase
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);

    if (companyIds.isEmpty) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds)
        .get();

    final normalizedAr = nameAr.trim().toLowerCase();
    final normalizedEn = nameEn.trim().toLowerCase();

    for (var doc in snapshot.docs) {
      final existingAr = (doc['nameAr'] ?? '').toString().trim().toLowerCase();
      final existingEn = (doc['nameEn'] ?? '').toString().trim().toLowerCase();
      if (existingAr == normalizedAr || existingEn == normalizedEn) {
        return true;
      }
    }
    return false;
  }

  // التحقق من صحة الحقول المطلوبة قبل الإرسال
  bool _validateInputs() {
    if (_nameArController.text.trim().isEmpty ||
        _nameEnController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('required_fields'))),
      );
      return false;
    }
    if (_base64Logo == null || _base64Logo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_select_logo'))),
      );
      return false;
    }
    return true;
  }

  // اختيار صورة الشعار من المعرض وتحويلها إلى base64
  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        safeDebugPrint('❌ لم يتم اختيار صورة');
        return;
      }

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        _webImageBytes = bytes;
        _base64Logo = base64Encode(bytes);
      } else {
        _logoImage = File(pickedFile.path);
        final bytes = await _logoImage!.readAsBytes();
        _base64Logo = base64Encode(bytes);
      }
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

  // حفظ البيانات في Hive
  Future<void> _saveToHive(
      String companyId, Map<String, dynamic> companyData, String userId) async {
    try {
      // حفظ بيانات الشركة
      await _companiesBox.put(companyId, {
        ...companyData,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // تحديث قائمة شركات المستخدم
      final userCompaniesKey = 'user_companies_$userId';
      final existingCompanies = _companiesBox.get(userCompaniesKey) ?? [];
      final updatedCompanies =
          List<Map<String, dynamic>>.from(existingCompanies);

      updatedCompanies.add({
        'id': companyId,
        'nameAr': companyData['nameAr'],
        'nameEn': companyData['nameEn'],
        'logoBase64': companyData['logoBase64'],
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await _companiesBox.put(userCompaniesKey, updatedCompanies);

      safeDebugPrint('[HIVE] تم حفظ بيانات الشركة في التخزين المحلي');
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] فشل في حفظ البيانات المحلية: $e');
    }
  }

  Future<bool> _verifyUserPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // تحديث token للمستخدم لتفعيل الصلاحيات
      await user.getIdToken(true);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final isActive = userDoc.data()?['isActive'] ?? false;
      final isAdmin = userDoc.data()?['isAdmin'] ?? false;

      safeDebugPrint('🔐 حالة المستخدم - نشط: $isActive, أدمن: $isAdmin');

      return isActive == true || isAdmin == true;
    } catch (e) {
      safeDebugPrint('❌ خطأ في التحقق من صلاحيات المستخدم: $e');
      return false;
    }
  }

  // دالة إضافة الشركة
Future<void> _addCompany() async {
  if (!_validateInputs()) return;

  final userId = _currentUser?.uid;
  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('user_not_logged_in'))),
    );
    return;
  }

  // التحقق من الصلاحيات أولاً
  final hasPermission = await _verifyUserPermissions();
  if (!hasPermission) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('user_not_active_or_no_permission'))),
    );
    return;
  }

  final isActive = await _checkUserActive();
  if (!isActive) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('user_not_active'))),
    );
    return;
  }

  final isDuplicate = await _isCompanyDuplicate(
      _nameArController.text, _nameEnController.text);
  if (isDuplicate) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('company_already_exists'))),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
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

    // تحديث قائمة الشركات في مستند المستخدم
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
    await userDocRef.update({
      'companyIds': FieldValue.arrayUnion([companyId]),
    });

    // حفظ البيانات في Hive
    await _saveToHive(companyId, companyData, userId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('company_added_successfully'))),
      );

      // ✅ التعديل هنا: إرجاع بيانات الشركة الجديدة بدلاً من الانتقال
      context.pop({
        'success': true,
        'company': {
          'id': companyId,
          'nameAr': _nameArController.text.trim(),
          'nameEn': _nameEnController.text.trim(),
          'address': _addressController.text.trim(),
          'managerName': _managerNameController.text.trim(),
          'managerPhone': _managerPhoneController.text.trim(),
          'logoBase64': _base64Logo,
          'userId': userId,
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
      
      // ✅ إرجاع حالة الفشل
      context.pop({
        'success': false,
        'error': e.toString()
      });
    }
  } finally {
    setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('add_company')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameArController,
                    decoration:
                        InputDecoration(labelText: tr('company_nameArabic')),
                    inputFormatters: [arabicOnlyFormatter],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameEnController,
                    decoration:
                        InputDecoration(labelText: tr('company_nameEnglish')),
                    inputFormatters: [englishOnlyFormatter],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration:
                        InputDecoration(labelText: tr('company_address')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _managerNameController,
                    decoration:
                        InputDecoration(labelText: tr('company_managerName')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _managerPhoneController,
                    decoration:
                        InputDecoration(labelText: tr('company_managerPhone')),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [numbersOnlyFormatter],
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.image),
                    label: Text(tr('please_select_logo')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  if (_base64Logo != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: kIsWeb
                          ? Image.memory(_webImageBytes!,
                              height: 150, fit: BoxFit.contain)
                          : Image.file(_logoImage!,
                              height: 150, fit: BoxFit.contain),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addCompany,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              tr('add_company'),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/* import 'dart:convert';
import 'dart:io';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

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
  Uint8List? _webImageBytes;
  String? _base64Logo;

  bool _isLoading = false;
  User? _currentUser;

  final arabicOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'));
  final englishOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));
  final numbersOnlyFormatter = FilteringTextInputFormatter.digitsOnly;

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

  // التحقق من أن المستخدم نشط في النظام
  Future<bool> _checkUserActive() async {
    final userId = _currentUser?.uid;
    if (userId == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) return false;
      final isActive = userDoc.data()?['isActive'] ?? false;
      return isActive == true;
    } catch (e) {
      safeDebugPrint('❌ خطأ في التحقق من حالة المستخدم: $e');
      return false;
    }
  }

// ✅ التحقق من تكرار الشركة (بناءً على الاسم العربي أو الإنجليزي)
  Future<bool> _isCompanyDuplicate(String nameAr, String nameEn) async {
    final userId = _currentUser?.uid;
    if (userId == null) return false;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);

    if (companyIds.isEmpty) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds)
        .get();

    final normalizedAr = nameAr.trim().toLowerCase();
    final normalizedEn = nameEn.trim().toLowerCase();

    for (var doc in snapshot.docs) {
      final existingAr = (doc['nameAr'] ?? '').toString().trim().toLowerCase();
      final existingEn = (doc['nameEn'] ?? '').toString().trim().toLowerCase();
      if (existingAr == normalizedAr || existingEn == normalizedEn) {
        return true;
      }
    }
    return false;
  }

  // التحقق من صحة الحقول المطلوبة قبل الإرسال
  bool _validateInputs() {
    if (_nameArController.text.trim().isEmpty ||
        _nameEnController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('required_fields'))),
      );
      return false;
    }
    if (_base64Logo == null || _base64Logo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_select_logo'))),
      );
      return false;
    }
    return true;
  }

  // اختيار صورة الشعار من المعرض وتحويلها إلى base64
  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        safeDebugPrint('❌ لم يتم اختيار صورة');
        return;
      }

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        _webImageBytes = bytes;
        _base64Logo = base64Encode(bytes);
      } else {
        _logoImage = File(pickedFile.path);
        final bytes = await _logoImage!.readAsBytes();
        _base64Logo = base64Encode(bytes);
      }
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

  // دالة إضافة الشركة
  Future<void> _addCompany() async {
    if (!_validateInputs()) return;

    final userId = _currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('user_not_logged_in'))),
      );
      return;
    }

    final isActive = await _checkUserActive();
    if (!isActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('user_not_active'))),
      );
      return;
    }

    final isDuplicate = await _isCompanyDuplicate(
        _nameArController.text, _nameEnController.text);
    if (isDuplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('company_already_exists'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
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

      // تحديث قائمة الشركات في مستند المستخدم
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userDocRef.update({
        'companyIds': FieldValue.arrayUnion([docRef.id]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('company_added_successfully'))),
        );
        context.pop(); // ارجع للصفحة اللي قبلها
      }
    } catch (e) {
      safeDebugPrint('❌ خطأ أثناء إضافة الشركة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_while_adding_company'))),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('add_company')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameArController,
                    decoration:
                        InputDecoration(labelText: tr('company_nameArabic')),
                    inputFormatters: [arabicOnlyFormatter],
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: _nameEnController,
                    decoration:
                        InputDecoration(labelText: tr('company_nameEnglish')),
                    inputFormatters: [englishOnlyFormatter],
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: _addressController,
                    decoration:
                        InputDecoration(labelText: tr('company_address')),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: _managerNameController,
                    decoration:
                        InputDecoration(labelText: tr('company_managerName')),
                    // inputFormatters: [arabicOnlyFormatter],
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: _managerPhoneController,
                    decoration:
                        InputDecoration(labelText: tr('company_managerPhone')),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [numbersOnlyFormatter],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.image),
                    label: Text(tr('please_select_logo')),
                  ),
                  if (_base64Logo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: kIsWeb
                          ? Image.memory(_webImageBytes!, height: 150)
                          : Image.file(_logoImage!, height: 150),
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _addCompany,
                    child: Text(tr('add_company')),
                  ),
                ],
              ),
            ),
    );
  }
}


/* import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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
  Uint8List? _webImageBytes;
  String? _base64Logo;
  bool _isLoading = false;
  User? _currentUser;

  final arabicOnlyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[\u0600-\u06FF\s]'),
  );
  final englishOnlyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z\s]'),
  );
  final numbersOnlyFormatter = FilteringTextInputFormatter.digitsOnly;

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

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        safeDebugPrint('❌ لم يتم اختيار صورة');
        return;
      }

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        _webImageBytes = bytes;
        _base64Logo = base64Encode(bytes);
      } else {
        _logoImage = File(pickedFile.path);
        final bytes = await _logoImage!.readAsBytes();
        _base64Logo = base64Encode(bytes);
      }
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

  Future<bool> _isCompanyDuplicate(String nameAr, String nameEn) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('companies').get();

      final normalizedAr = nameAr.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      final normalizedEn = nameEn.replaceAll(RegExp(r'\s+'), '').toLowerCase();

      for (var doc in snapshot.docs) {
        final existingAr = (doc['nameAr'] ?? '')
            .toString()
            .replaceAll(RegExp(r'\s+'), '')
            .toLowerCase();
        final existingEn = (doc['nameEn'] ?? '')
            .toString()
            .replaceAll(RegExp(r'\s+'), '')
            .toLowerCase();

        if (existingAr == normalizedAr || existingEn == normalizedEn) {
          return true;
        }
      }
      return false;
    } catch (e) {
      safeDebugPrint('❌ خطأ أثناء التحقق من التكرار: $e');
      return false; // في حالة الخطأ نفترض لا تكرار لكي لا نوقف العملية بدون سبب
    }
  }

  bool _validateInputs() {
    if (_nameArController.text.trim().isEmpty ||
        _nameEnController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('requierd_fields'))),
      );
      return false;
    }
    if (_base64Logo == null || _base64Logo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_select_logo'))),
      );
      return false;
    }
    return true;
  }

/*   Future<void> _addCompany() async {
    if (_isLoading) return;

    if (!_validateInputs()) return;

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('login_first'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final address = _addressController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();

    try {
      safeDebugPrint('🔍 التحقق من وجود شركة مكررة...');
      final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final companyId = firestore.collection('companies').doc().id;

      final companyRef = firestore.collection('companies').doc(companyId);
      final userRef = firestore.collection('users').doc(_currentUser!.uid);

      final companyData = {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'address': address,
        'managerName': managerName,
        'managerPhone': managerPhone,
        'logoBase64': _base64Logo,
        'userId': _currentUser!.uid,
        'createdAt': Timestamp.now(),
      };

      await firestore.runTransaction((transaction) async {
        try {
          transaction.set(companyRef, companyData);
          final userSnap = await transaction.get(userRef);

          if (userSnap.exists) {
            transaction.update(userRef, {
              'companyIds': FieldValue.arrayUnion([companyId]),
            });
          } else {
            transaction.set(userRef, {
              'companyIds': [companyId],
              'createdAt': Timestamp.now(),
            });
          }
        } catch (e, stackTrace) {
          safeDebugPrint('Error: $e');
          safeDebugPrint('StackTrace: $stackTrace');
          rethrow; // لإعادة رمي الاستثناء بعد معالجته
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('company_added_successfully'))),
      );

      await Future.delayed(const Duration(seconds: 1));

      final uri = Uri(
        path: '/company-added/$companyId',
        queryParameters: {'nameEn': nameEn},
      );
      safeDebugPrint('🚀 الانتقال إلى: $uri');
      if (mounted) {
        context.go(uri.toString());
      }
    } catch (e) {
      safeDebugPrint('❌ خطأ أثناء إضافة الشركة: $e');

      String userMessage = tr('error_while_adding_company');
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('permission-denied')) {
        userMessage = tr('permission_denied_hint');
      } else if (errorStr.contains('network')) {
        userMessage = tr('network_error');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $userMessage')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  } */

  Future<void> _addCompany() async {
    if (_isLoading) return;
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      final nameAr = _nameArController.text.trim();
      final nameEn = _nameEnController.text.trim();

      // التحقق من التكرار
      if (await _isCompanyDuplicate(nameAr, nameEn)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
        }
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final firestore = FirebaseFirestore.instance;
      final companyId = firestore.collection('companies').doc().id;

      // بيانات الشركة
      final companyData = {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'address': _addressController.text.trim(),
        'managerName': _managerNameController.text.trim(),
        'managerPhone': _managerPhoneController.text.trim(),
        'logoBase64': _base64Logo,
        'userId': currentUser.uid,
        'createdAt': Timestamp.now(),
      };

      // تنفيذ العملية في معاملة واحدة
      await firestore.runTransaction((transaction) async {
        // 1. إنشاء الشركة
        transaction.set(
            firestore.collection('companies').doc(companyId), companyData);

        // 2. تحديث مستخدم المستخدم
        final userRef = firestore.collection('users').doc(currentUser.uid);
        final userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          transaction.update(userRef, {
            'companyIds': FieldValue.arrayUnion([companyId]),
            'updatedAt': Timestamp.now(),
          });
        } else {
          transaction.set(userRef, {
            'companyIds': [companyId],
            'createdAt': Timestamp.now(),
            'userId': currentUser.uid,
          });
        }
      });

      // إظهار رسالة نجاح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('company_added_successfully'))),
        );

        // الانتقال إلى صفحة الشركة
        context.go('/company-added/$companyId', extra: {'nameEn': nameEn});
      }
    } on FirebaseException catch (e) {
      safeDebugPrint('Firebase Error: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getErrorMessage(e))),
        );
      }
    } catch (e) {
      safeDebugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_while_adding_company'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return tr('permission_denied_hint');
      case 'aborted':
        return tr('transaction_aborted');
      default:
        return e.message ?? tr('unknown_error');
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? previewBytes = _webImageBytes ??
        (_base64Logo != null ? base64Decode(_base64Logo!) : null);

    return Scaffold(
      appBar: AppBar(title: Text('add_company'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nameArController,
              decoration:
                  InputDecoration(labelText: 'company_nameArabic'.tr()),
              inputFormatters: [arabicOnlyFormatter],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameEnController,
              decoration:
                  InputDecoration(labelText: 'company_nameEnglish'.tr()),
              inputFormatters: [englishOnlyFormatter],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(labelText: 'company_address'.tr()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _managerNameController,
              decoration:
                  InputDecoration(labelText: 'company_managerName'.tr()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _managerPhoneController,
              decoration:
                  InputDecoration(labelText: 'company_managerPhone'.tr()),
              keyboardType: TextInputType.phone,
              inputFormatters: [numbersOnlyFormatter],
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: Text('company_logo'.tr()),
                  onPressed: _pickLogo,
                ),
                const SizedBox(width: 15),
                if (previewBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Image.memory(previewBytes, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.add_business),
                    label: Text('add_company'.tr()),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _addCompany,
                  ),
          ],
        ),
      ),
    );
  }
}


/* import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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
  Uint8List? _webImageBytes;
  String? _base64Logo;
  bool _isLoading = false;
  User? _currentUser;

  final arabicOnlyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[\u0600-\u06FF\s]'),
  );
  final englishOnlyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z\s]'),
  );
  final numbersOnlyFormatter = FilteringTextInputFormatter.digitsOnly;

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        _webImageBytes = await pickedFile.readAsBytes();
        _base64Logo = base64Encode(_webImageBytes!);
      } else {
        _logoImage = File(pickedFile.path);
        final bytes = await _logoImage!.readAsBytes();
        _base64Logo = base64Encode(bytes);
      }
      setState(() {});
      safeDebugPrint('Logo selected and encoded.');
    } else {
      safeDebugPrint('No logo image selected.');
    }
  }

  Future<bool> _isCompanyDuplicate(String nameAr, String nameEn) async {
    safeDebugPrint('Checking for duplicate company...');
    final querySnapshot =
        await FirebaseFirestore.instance.collection('companies').get();

    final normalizedAr = nameAr.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final normalizedEn = nameEn.replaceAll(RegExp(r'\s+'), '').toLowerCase();

    for (var doc in querySnapshot.docs) {
      final existingAr = doc['nameAr']
          ?.toString()
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      final existingEn = doc['nameEn']
          ?.toString()
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();

      if (existingAr == normalizedAr || existingEn == normalizedEn) {
        safeDebugPrint('Duplicate company found: ${doc.id}');
        return true;
      }
    }
    safeDebugPrint('No duplicate company found.');
    return false;
  }

  Future<void> _addCompany() async {
    if (_isLoading) return;

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final address = _addressController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();

    _currentUser ??= FirebaseAuth.instance.currentUser;
    safeDebugPrint('Logged in user UID: ${_currentUser!.uid}');

    if (_currentUser == null) {
      safeDebugPrint('❌ المستخدم غير مسجل الدخول');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login_first'.tr())),
      );
      return;
    }

    safeDebugPrint(
        '🟡 بدء عملية إضافة الشركة بواسطة المستخدم: ${_currentUser!.uid}');
    safeDebugPrint('📋 البيانات المُدخلة:');
    safeDebugPrint('- الاسم بالعربية: $nameAr');
    safeDebugPrint('- الاسم بالإنجليزية: $nameEn');
    safeDebugPrint('- العنوان: $address');

    if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
      safeDebugPrint('❌ الحقول المطلوبة ناقصة');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('requierd_fields'.tr())),
      );
      return;
    }

    if (_base64Logo == null || _base64Logo!.isEmpty) {
      safeDebugPrint('❌ لم يتم اختيار شعار');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_logo'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // التحقق من تكرار الشركة
      safeDebugPrint('🔍 التحقق من وجود شركة مكررة...');
      final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
      if (isDuplicate) {
        safeDebugPrint('⚠️ الشركة مكررة بالفعل');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final companyId = firestore.collection('companies').doc().id;
      final companyRef = firestore.collection('companies').doc(companyId);
      final userRef = firestore.collection('users').doc(_currentUser!.uid);

      final companyData = {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'address': address,
        'managerName': managerName,
        'managerPhone': managerPhone,
        'logoBase64': _base64Logo,
        'userId': _currentUser!.uid,
        'createdAt': Timestamp.now(),
      };

      safeDebugPrint('🛠️ بدء المعاملة لإضافة الشركة وتحديث المستخدم');
      safeDebugPrint('📦 البيانات المرسلة إلى Firestore: $companyData');

      await firestore.runTransaction((transaction) async {
        // إضافة مستند الشركة الجديد
        safeDebugPrint('🧪 سيتم إنشاء مستند الشركة بـ: $companyData');

        transaction.set(companyRef, companyData);

        // جلب بيانات المستخدم
        final userSnap = await transaction.get(userRef);

        if (userSnap.exists) {
          // تحديث قائمة الشركات لدى المستخدم
          transaction.update(userRef, {
            'companyIds': FieldValue.arrayUnion([companyId]),
          });
          safeDebugPrint('🔁 تحديث قائمة الشركات لدى المستخدم');
        } else {
          // إنشاء مستند مستخدم جديد مع الشركة
          safeDebugPrint('🧪 سيتم إنشاء مستند الشركة بـ: $companyData');

          transaction.set(userRef, {
            'companyIds': [companyId],
            'createdAt': Timestamp.now(),
          });
          safeDebugPrint('🆕 إنشاء مستند مستخدم جديد مع الشركة');
        }
      });

      safeDebugPrint('✅ تمت العملية بنجاح');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('company_added_successfully'.tr())),
      );

      await Future.delayed(const Duration(seconds: 1));

      final uri = Uri(
        path: '/company-added/$companyId',
        queryParameters: {'nameEn': nameEn},
      );

      safeDebugPrint('🚀 الانتقال إلى: $uri');
      if (mounted) {
        context.go(uri.toString());
      }
    } catch (e, stacktrace) {
      safeDebugPrint('❌ استثناء أثناء إضافة الشركة: $e');
      safeDebugPrint(stacktrace.toString());

      String userMessage = tr('error_while_adding_company');
      if (e.toString().contains('permission-denied')) {
        userMessage = tr('permission_denied_hint');
      } else if (e.toString().contains('network')) {
        userMessage = tr('network_error');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $userMessage')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

/* 
  Future<void> _addCompany() async {
    if (_isLoading) return;

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final address = _addressController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();

    safeDebugPrint('🟡 بدء عملية إضافة الشركة');
    safeDebugPrint('📋 البيانات المُدخلة:');
    safeDebugPrint('- الاسم بالعربية: $nameAr');
    safeDebugPrint('- الاسم بالإنجليزية: $nameEn');
    safeDebugPrint('- العنوان: $address');

    if (_currentUser == null) {
      safeDebugPrint('❌ المستخدم غير مسجل في _addCompany');
      return;
    }
    safeDebugPrint('✅ المستخدم داخل _addCompany: ${_currentUser!.uid}');

    if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
      safeDebugPrint('❌ حقول مطلوبة ناقصة');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('requierd_fields'.tr())),
      );
      return;
    }

    if (_base64Logo == null || _base64Logo!.isEmpty) {
      safeDebugPrint('❌ لم يتم اختيار شعار');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_logo'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      safeDebugPrint('🔍 التحقق من تكرار الشركة...');
      final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
      if (isDuplicate) {
        safeDebugPrint('⚠️ الشركة مكررة');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      safeDebugPrint(
          '📍 currentUser داخل _addCompany: ${currentUser?.uid ?? "null"}');
      if (currentUser == null) {
        safeDebugPrint('❌ المستخدم غير مسجل الدخول');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('login_first'.tr())),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final uid = currentUser.uid;
      safeDebugPrint('✅ المستخدم  uid  المسجل: $uid');

      final firestore = FirebaseFirestore.instance;
      final companyId = firestore.collection('companies').doc().id;

      final companyRef = firestore.collection('companies').doc(companyId);
      final userRef = firestore.collection('users').doc(uid);

      final companyData = {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'address': address,
        'managerName': managerName,
        'managerPhone': managerPhone,
        'logoBase64': _base64Logo,
        'userId': _currentUser!.uid,
        'createdAt': Timestamp.now(),
      };

      safeDebugPrint('🛠️ إعداد البيانات... سيتم بدء المعاملة');
      safeDebugPrint('🆔 معرف الشركة: $companyId');

      await firestore.runTransaction((transaction) async {
        // إضافة الشركة
        transaction.set(companyRef, companyData);
        safeDebugPrint('✅ الشركة تم إدراجها في قاعدة البيانات');

        final userSnap = await transaction.get(userRef);

        if (userSnap.exists) {
          safeDebugPrint('🔁 تحديث مستخدم حالي');
          transaction.update(userRef, {
            'companyIds': FieldValue.arrayUnion([companyId]),
          });
        } else {
          safeDebugPrint('🆕 إنشاء مستخدم جديد وربطه بالشركة');
          transaction.set(userRef, {
            'companyIds': [companyId],
            'createdAt': Timestamp.now(),
          });
        }
      });

      safeDebugPrint('✅ تمت العملية بنجاح');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('company_added_successfully'.tr())),
      );

      await Future.delayed(const Duration(seconds: 1));

      final uri = Uri(
        path: '/company-added/$companyId',
        queryParameters: {'nameEn': nameEn},
      );

      safeDebugPrint('🚀 الانتقال إلى: $uri');
      if (mounted) {
        context.go(uri.toString());
      }
    } catch (e, stacktrace) {
      safeDebugPrint('❌ استثناء أثناء إضافة الشركة: $e');
      safeDebugPrint(stacktrace.toString());

      if (mounted) {
        String userMessage = tr('error_while_adding_company');

        if (e.toString().contains('permission-denied')) {
          userMessage = tr('permission_denied_hint'); // نضيف ترجمة لهذه لاحقًا
        } else if (e.toString().contains('network')) {
          userMessage = tr('network_error'); // أيضًا نضيف ترجمة لها
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $userMessage')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
 */
/* 
    Future<void> _addCompany() async {
      if (_isLoading) return;

      final nameAr = _nameArController.text.trim();
      final nameEn = _nameEnController.text.trim();
      final address = _addressController.text.trim();
      final managerName = _managerNameController.text.trim();
      final managerPhone = _managerPhoneController.text.trim();

      safeDebugPrint('🔁 بدء إضافة الشركة...');
      safeDebugPrint(
          '🔍 بيانات الإدخال: nameAr="$nameAr", nameEn="$nameEn", address="$address"');

      if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
        safeDebugPrint('❌ الحقول المطلوبة ناقصة');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('requierd_fields'.tr())),
        );
        return;
      }

      if (_base64Logo == null || _base64Logo!.isEmpty) {
        safeDebugPrint('❌ الشعار غير محدد');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('please_select_logo'.tr())),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        safeDebugPrint('🔍 التحقق من وجود شركة مكررة...');
        final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
        if (isDuplicate) {
          if (!mounted) return;
          safeDebugPrint('⚠️ تم العثور على شركة مكررة، يتم الإيقاف');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (!mounted) return;
          safeDebugPrint('❌ المستخدم غير مسجل الدخول');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('login_first'.tr())),
          );
          setState(() => _isLoading = false);
          return;
        }

        safeDebugPrint('✅ المستخدم الحالي: ${currentUser.uid}');

        final firestore = FirebaseFirestore.instance;
        final companyId = firestore.collection('companies').doc().id;

        final companyRef = firestore.collection('companies').doc(companyId);
        final userRef = firestore.collection('users').doc(currentUser.uid);
        safeDebugPrint('companies $companyId');
        safeDebugPrint('users $currentUser');
        


        final companyData = {
          'nameAr': nameAr,
          'nameEn': nameEn,
          'address': address,
          'managerName': managerName,
          'managerPhone': managerPhone,
          'logoBase64': _base64Logo,
          'userId': currentUser.uid,
        //  'companyId': companyId,
          'createdAt': Timestamp.now(),
        };

        safeDebugPrint('📦 البيانات جاهزة، جاري التنفيذ داخل المعاملة...');

        await firestore.runTransaction((transaction) async {
          // إنشاء الشركة
          transaction.set(companyRef, companyData);
        //  transaction.set(companyRef, companyData);

          // جلب بيانات المستخدم
          final userSnap = await transaction.get(userRef);

          if (userSnap.exists) {
            safeDebugPrint('🔁 تحديث قائمة الشركات لدى المستخدم');
            transaction.update(userRef, {
              'companyIds': FieldValue.arrayUnion([companyId]),
            });
          } else {
            safeDebugPrint('🆕 إنشاء مستند مستخدم جديد مع الشركة');
            transaction.set(userRef, {
              'companyIds': [companyId],
              'createdAt': Timestamp.now(),
            });
          }
        });

        safeDebugPrint('✅ تم إضافة الشركة وتحديث المستخدم بنجاح.');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('company_added_successfully'.tr())),
        );

        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;

        final uri = Uri(
          path: '/company-added/$companyId',
          queryParameters: {'nameEn': nameEn},
        );
        safeDebugPrint('🚀 الانتقال إلى صفحة نجاح: $uri');
        context.go(uri.toString());
      } catch (e, stacktrace) {
        safeDebugPrint('❌ خطأ أثناء إضافة الشركة: $e');
        safeDebugPrint(stacktrace.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('error_while_adding_company')}: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
 */
  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _addressController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    safeDebugPrint(
        '👤 المستخدم الحالي في initState: ${_currentUser?.uid ?? "null"}');
    final user = FirebaseAuth.instance.currentUser;
    safeDebugPrint('👤 المستخدم الحالي في initState: ${user?.uid ?? "لا يوجد"}');

  }

  @override
  Widget build(BuildContext context) {
    Uint8List? previewBytes = _webImageBytes ??
        (_base64Logo != null ? base64Decode(_base64Logo!) : null);

    return Scaffold(
      appBar: AppBar(title: Text('add_company'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _nameArController,
              decoration:
                  InputDecoration(labelText: 'company_nameArabic'.tr()),
              inputFormatters: [arabicOnlyFormatter],
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              controller: _nameEnController,
              decoration:
                  InputDecoration(labelText: 'company_nameEnglish'.tr()),
              inputFormatters: [englishOnlyFormatter],
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(labelText: 'company_address'.tr()),
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              controller: _managerNameController,
              decoration:
                  InputDecoration(labelText: 'company_managerName'.tr()),
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              controller: _managerPhoneController,
              decoration:
                  InputDecoration(labelText: 'company_managerPhone'.tr()),
              keyboardType: TextInputType.phone,
              inputFormatters: [numbersOnlyFormatter],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.image),
                  label: Text('company_logo'.tr()),
                ),
                const SizedBox(width: 10),
                if (previewBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Image.memory(previewBytes),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: () {
                      safeDebugPrint('🟢 الزر تم الضغط عليه');
                      _addCompany();
                    },
                    icon: const Icon(Icons.add_business),
                    label: Text('add_company'.tr()),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
 */ */ */
