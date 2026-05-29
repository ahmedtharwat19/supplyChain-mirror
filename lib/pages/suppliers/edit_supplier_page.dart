// pages/suppliers/edit_supplier_page.dart - بدون UserLocalStorage
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/supplier.dart';

class EditSupplierPage extends StatefulWidget {
  final String supplierId;
  const EditSupplierPage({super.key, required this.supplierId});

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
  
  // متغيرات ضريبة الخصم من المنبع
  bool _subjectToWithholding = false;
  double _withholdingTaxRate = 1.0;

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
      
      _subjectToWithholding = supplier.subjectToWithholding;
      _withholdingTaxRate = supplier.withholdingTaxRate;
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
    if (value == null || value.trim().isEmpty) return null;
    final phoneRegex = RegExp(r'^\+?\d{7,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return tr('invalid_phone');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return tr('invalid_email');
    }
    return null;
  }

  Widget _buildWithholdingTaxToggle() {
    return Card(
      color: Colors.orange[50],
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(
                'subject_to_withholding'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('withholding_tax_description'.tr()),
              value: _subjectToWithholding,
              onChanged: (value) {
                setState(() {
                  _subjectToWithholding = value;
                  if (!value) _withholdingTaxRate = 0;
                });
              },
            ),
            if (_subjectToWithholding)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextFormField(
                  initialValue: _withholdingTaxRate.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'withholding_tax_rate_percent'.tr(),
                    suffixText: '%',
                    border: const OutlineInputBorder(),
                    helperText: 'withholding_tax_rate_helper'.tr(),
                  ),
                  onChanged: (value) {
                    final rate = double.tryParse(value) ?? 1.0;
                    setState(() => _withholdingTaxRate = rate.clamp(0, 100));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // ✅ الحصول على userId من FirebaseAuth مباشرة
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      
      if (userId == null) {
        throw Exception(tr('user_not_logged_in'));
      }

      final supplier = Supplier(
        id: widget.supplierId,
        nameAr: _nameController.text.trim(),
        nameEn: _companyController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        userId: userId,
        createdAt: Timestamp.now(),
        subjectToWithholding: _subjectToWithholding,
        withholdingTaxRate: _withholdingTaxRate,
      );

      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.supplierId)
          .update(supplier.toMap());

      // ✅ التأكد من أن supplierId موجود في قائمة المستخدم
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final List<dynamic> supplierIds = data['supplierIds'] ?? [];

        if (!supplierIds.contains(widget.supplierId)) {
          await userRef.update({
            'supplierIds': FieldValue.arrayUnion([widget.supplierId]),
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_updated'))),
      );
      Navigator.of(context).pop(true); // إرجاع true لتحديث الصفحة السابقة
    } catch (e) {
      if (!mounted) return;
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
              // الاسم عربي
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
              const SizedBox(height: 16),
              
              // الاسم إنجليزي
              TextFormField(
                controller: _companyController,
                focusNode: _companyFocus,
                decoration: InputDecoration(labelText: tr('supplier_nameEnglish')),
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_phoneFocus);
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              
              // رقم الهاتف
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
              const SizedBox(height: 16),
              
              // البريد الإلكتروني
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
              const SizedBox(height: 16),
              
              // العنوان
              TextFormField(
                controller: _addressController,
                focusNode: _addressFocus,
                decoration: InputDecoration(labelText: tr('address')),
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_notesFocus);
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              
              // ملاحظات
              TextFormField(
                controller: _notesController,
                focusNode: _notesFocus,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: tr('notes')),
                maxLines: 3,
                onFieldSubmitted: (_) {
                  _updateSupplier();
                },
              ),
              const SizedBox(height: 16),
              
              // ضريبة الخصم من المنبع
              _buildWithholdingTaxToggle(),
              const SizedBox(height: 24),
              
              // زر الحفظ
              ElevatedButton(
                onPressed: _isSaving ? null : _updateSupplier,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}