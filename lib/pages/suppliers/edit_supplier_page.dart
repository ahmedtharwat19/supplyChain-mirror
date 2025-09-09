import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

class EditSupplierPage extends StatefulWidget {
  final String supplierId;

  const EditSupplierPage({
    super.key,
    required this.supplierId,
  });

  @override
  State<EditSupplierPage> createState() => _EditSupplierPageState();
}

class _EditSupplierPageState extends State<EditSupplierPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameFocus = FocusNode();
  final _companyFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _notesFocus = FocusNode();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSupplier();
  }

  Future<void> _loadSupplier() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.supplierId)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('supplier_not_found'))),
        );
        Navigator.of(context).pop();
        return;
      }

      final supplier = Supplier.fromMap(doc.data()!, doc.id);

      _nameController.text = supplier.nameAr;
      _companyController.text = supplier.nameEn;
      _phoneController.text = supplier.phone;
      _emailController.text = supplier.email;
      _addressController.text = supplier.address;
      _notesController.text = supplier.notes ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_occurred')}: $e')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('required_field');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // هاتف اختياري
    final phoneRegex = RegExp(r'^\+?\d{7,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return tr('invalid_phone');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // إيميل اختياري
    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return tr('invalid_email');
    }
    return null;
  }

/*   Future<void> _updateSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userData = await UserLocalStorage.getUser();
      if (userData == null) throw Exception(tr('user_not_logged_in'));
      final userId = userData['userId']!;

      final supplier = Supplier(
        id: widget.supplierId,
        name: _nameController.text.trim(),
        company: _companyController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        userId: userId,
        createdAt: Timestamp.now(), // ممكن تحتفظ بتاريخ الإنشاء القديم لو حابب
      );

      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.supplierId)
          .update(supplier.toMap());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_updated'))),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_occurred')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
 */

  Future<void> _updateSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userData = await UserLocalStorage.getUser();
      if (userData == null) throw Exception(tr('user_not_logged_in'));
      final userId = userData['userId']!;

      final supplier = Supplier(
        id: widget.supplierId,
        nameAr: _nameController.text.trim(),
        nameEn: _companyController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        userId: userId,
        createdAt: Timestamp.now(), // احتفظ بالتاريخ القديم إذا رغبت
      );

      // تحديث بيانات المورد
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.supplierId)
          .update(supplier.toMap());

      // تحقق من supplierIds للمستخدم
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final List<dynamic> supplierIds = data['supplierIds'] ?? [];

        if (!supplierIds.contains(widget.supplierId)) {
          await userRef.update({
            'supplierIds': FieldValue.arrayUnion([widget.supplierId]),
          });
          final updatedSupplierIds = List<String>.from(supplierIds)
            ..add(widget.supplierId);

          await UserLocalStorage.saveUser(
            userId: userId,
            email: userData['email'] ?? '',
            displayName: userData['displayName'],
            companyIds: List<String>.from(userData['companyIds'] ?? []),
            factoryIds: List<String>.from(userData['factoryIds'] ?? []),
            supplierIds: updatedSupplierIds,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_updated'))),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_occurred')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _companyFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _notesFocus.dispose();

    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('edit_supplier'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('edit_supplier'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                decoration: InputDecoration(labelText: tr('supplier_nameArabic')),
                validator: _validateName,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_companyFocus);
                },
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                controller: _companyController,
                focusNode: _companyFocus,
                decoration: InputDecoration(labelText: tr('supplier_nameEnglish')),
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_phoneFocus);
                },
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('phone')),
                validator: _validatePhone,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_emailFocus);
                },
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: tr('email')),
                validator: _validateEmail,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_addressFocus);
                },
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                controller: _addressController,
                focusNode: _addressFocus,
                decoration: InputDecoration(labelText: tr('address')),
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_notesFocus);
                },
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                controller: _notesController,
                focusNode: _notesFocus,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('notes')),
                maxLines: 3,
                onFieldSubmitted: (_) {
                  _updateSupplier();
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _updateSupplier,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(tr('update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



/* import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

class EditSupplierPage extends StatefulWidget {
  final String supplierId;

  const EditSupplierPage({super.key, required this.supplierId});

  @override
  State<EditSupplierPage> createState() => _EditSupplierPageState();
}

class _EditSupplierPageState extends State<EditSupplierPage> {
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadSupplierData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSupplierData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.supplierId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('supplier_not_found'))),
          );
          context.pop();
        }
        return;
      }

      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _companyController.text = data['company'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _emailController.text = data['email'] ?? '';
      _addressController.text = data['address'] ?? '';
      _notesController.text = data['notes'] ?? '';
    } catch (e) {
      safeDebugPrint('Error loading supplier data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
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
      safeDebugPrint('Error checking user active status: $e');
      return false;
    }
  }

  Future<bool> _isSupplierDuplicate(String name) async {
    final userId = _currentUser?.uid;
    if (userId == null) return false;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final supplierIds = List<String>.from(userDoc.data()?['supplierIds'] ?? []);

    if (supplierIds.isEmpty) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where(FieldPath.documentId, whereIn: supplierIds)
        .get();

    final normalizedName = name.trim().toLowerCase();

    for (var doc in snapshot.docs) {
      if (doc.id == widget.supplierId) continue; // استثناء المورد نفسه
      final existingName = (doc['name'] ?? '').toString().trim().toLowerCase();
      if (existingName == normalizedName) {
        return true;
      }
    }

    return false;
  }

  bool _validateInputs() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('required'))),
      );
      return false;
    }

    if (_emailController.text.isNotEmpty &&
        !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('invalid_email'))),
      );
      return false;
    }

    return true;
  }

  Future<void> _updateSupplier() async {
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

    final name = _nameController.text.trim();
    final isDuplicate = await _isSupplierDuplicate(name);
    if (isDuplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_already_exists'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supplierData = {
        'name': name,
        'company': _companyController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'notes': _notesController.text.trim(),
        // ممكن تحدث الحقول الأخرى اللي تحبها هنا
      };

      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.supplierId)
          .update(supplierData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('supplier_updated'))),
        );
        context.pop();
      }
    } catch (e) {
      safeDebugPrint('Error updating supplier: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('edit_supplier'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('edit_supplier'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: tr('name')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _companyController,
                    decoration: InputDecoration(labelText: tr('company')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(labelText: tr('phone')),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: tr('email')),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(labelText: tr('address')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(labelText: tr('notes')),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _updateSupplier,
                    child: Text(tr('save')),
                  ),
                ],
              ),
            ),
    );
  }
}
 */