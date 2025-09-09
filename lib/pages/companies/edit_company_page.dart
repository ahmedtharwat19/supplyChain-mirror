/* import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/company.dart';

class EditCompanyPage extends StatefulWidget {
  final String companyId;

  const EditCompanyPage({
    super.key,
    required this.companyId,
  });

  @override
  State<EditCompanyPage> createState() => _EditCompanyPageState();
}

class _EditCompanyPageState extends State<EditCompanyPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _addressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();

  File? _logoImageFile;
  Uint8List? _logoWebBytes;
  String? _logoBase64;

  bool _isLoading = false;
  bool _isDataLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الشركة غير موجودة')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data()!;
      _nameArController.text = data['nameAr'] ?? '';
      _nameEnController.text = data['nameEn'] ?? '';
      _addressController.text = data['address'] ?? '';
      _managerNameController.text = data['managerName'] ?? '';
      _managerPhoneController.text = data['managerPhone'] ?? '';
      _logoBase64 = data['logoBase64'];

      if (_logoBase64 != null) {
        if (kIsWeb) {
          _logoWebBytes = base64Decode(_logoBase64!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات الشركة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        _logoWebBytes = await pickedFile.readAsBytes();
        _logoBase64 = base64Encode(_logoWebBytes!);
      } else {
        _logoImageFile = File(pickedFile.path);
        final bytes = await _logoImageFile!.readAsBytes();
        _logoBase64 = base64Encode(bytes);
      }
      setState(() {});
    }
  }

  Future<void> _updateCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
        );
        return;
      }

      final updatedCompany = Company(
        nameAr: _nameArController.text.trim(),
        nameEn: _nameEnController.text.trim(),
        address: _addressController.text.trim(),
        managerName: _managerNameController.text.trim(),
        managerPhone: _managerPhoneController.text.trim(),
        logoBase64: _logoBase64,
        userId: user.uid,
        createdAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .update(updatedCompany.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بيانات الشركة بنجاح')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التحديث: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    Uint8List? previewBytes =
        _logoWebBytes ?? (_logoBase64 != null ? base64Decode(_logoBase64!) : null);

    return Scaffold(
      appBar: AppBar(title: const Text('تعديل بيانات الشركة')),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameArController,
                      decoration: const InputDecoration(labelText: 'اسم الشركة (عربي)'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'يرجى إدخال اسم الشركة بالعربي' : null,
                    ),
                    TextFormField(
                      controller: _nameEnController,
                      decoration: const InputDecoration(labelText: 'Company Name (English)'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Please enter the company name in English' : null,
                    ),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'عنوان الشركة'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'يرجى إدخال عنوان الشركة' : null,
                    ),
                    TextFormField(
                      controller: _managerNameController,
                      decoration: const InputDecoration(labelText: 'اسم المسؤول'),
                    ),
                    TextFormField(
                      controller: _managerPhoneController,
                      decoration: const InputDecoration(labelText: 'رقم هاتف المسؤول'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.image),
                          label: const Text('اختيار لوجو'),
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
                            onPressed: _updateCompany,
                            icon: const Icon(Icons.save),
                            label: const Text('تحديث البيانات'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
 */

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class EditCompanyPage extends StatefulWidget {
  final String companyId;
  const EditCompanyPage({super.key, required this.companyId});

  @override
  State<EditCompanyPage> createState() => _EditCompanyPageState();
}

class _EditCompanyPageState extends State<EditCompanyPage> {
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _addressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();

  File? _logoImage;
  Uint8List? _webImageBytes;
  String? _base64Logo;

  bool _isLoading = true; // بداية بنظهر تحميل لأننا بنجيب بيانات
  bool _isSaving = false;
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
    _loadCompanyData();
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

  Future<void> _loadCompanyData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('company_not_found'))),
          );
          context.pop();
        }
        return;
      }

      final data = doc.data()!;
      _nameArController.text = data['nameAr'] ?? '';
      _nameEnController.text = data['nameEn'] ?? '';
      _addressController.text = data['address'] ?? '';
      _managerNameController.text = data['managerName'] ?? '';
      _managerPhoneController.text = data['managerPhone'] ?? '';
      _base64Logo = data['logoBase64'];

      if (_base64Logo != null && _base64Logo!.isNotEmpty) {
        if (kIsWeb) {
          _webImageBytes = base64Decode(_base64Logo!);
        } else {
          // بالنسبة للموبايل: ممكن نخزن الصورة مؤقتًا لكن هنا نعرض الصورة من base64 مباشرة
          // لذلك نترك _logoImage = null ونستخدم _base64Logo فقط للعرض
        }
      }
    } catch (e) {
      safeDebugPrint('❌ خطأ في جلب بيانات الشركة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_loading_company'))),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      if (doc.id == widget.companyId) continue; // استثناء الشركة الحالية

      final existingAr = (doc['nameAr'] ?? '').toString().trim().toLowerCase();
      final existingEn = (doc['nameEn'] ?? '').toString().trim().toLowerCase();
      if (existingAr == normalizedAr || existingEn == normalizedEn) {
        return true;
      }
    }
    return false;
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

  Future<void> _updateCompany() async {
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

    setState(() => _isSaving = true);

    try {
      final companyData = {
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim(),
        'address': _addressController.text.trim(),
        'managerName': _managerNameController.text.trim(),
        'managerPhone': _managerPhoneController.text.trim(),
        'logoBase64': _base64Logo,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .update(companyData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('company_updated_successfully'))),
        );
        context.pop();
      }
    } catch (e) {
      safeDebugPrint('❌ خطأ أثناء تحديث الشركة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_while_updating_company'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('edit_company'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('edit_company')),
      ),
      body: _isSaving
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
                          : (_logoImage != null
                              ? Image.file(_logoImage!, height: 150)
                              : Image.memory(base64Decode(_base64Logo!), height: 150)),
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _updateCompany,
                    child: Text(tr('update_company')),
                  ),
                ],
              ),
            ),
    );
  }
}
