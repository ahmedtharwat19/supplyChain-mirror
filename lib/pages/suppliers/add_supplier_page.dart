// pages/suppliers/add_supplier_page.dart - بدون UserLocalStorage
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/supplier.dart';

class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameArFocus = FocusNode();
  final _nameEnFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _notesFocus = FocusNode();

  final TextEditingController _nameArController = TextEditingController();
  final TextEditingController _nameEnController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  
  // متغيرات ضريبة الخصم من المنبع
  bool _subjectToWithholding = false;
  double _withholdingTaxRate = 1.0;

  @override
  void dispose() {
    _nameArFocus.dispose();
    _nameEnFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _notesFocus.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<bool> _isSupplierDuplicate(String nameAr, String nameEn) async {
    // ✅ الحصول على userId من FirebaseAuth مباشرة
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    
    if (userId == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    final supplierIds = List<String>.from(userDoc.data()?['supplierIds'] ?? []);
    
    if (supplierIds.isEmpty) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where(FieldPath.documentId, whereIn: supplierIds)
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

  Future<void> _addSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ الحصول على userId من FirebaseAuth مباشرة
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('user_not_logged_in'))),
      );
      return;
    }

    final isDuplicate = await _isSupplierDuplicate(
      _nameArController.text,
      _nameEnController.text,
    );

    if (isDuplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_already_exists'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('vendors').doc();
      final supplierId = docRef.id;

      final supplier = Supplier(
        nameAr: _nameArController.text.trim(),
        nameEn: _nameEnController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        userId: userId,
        createdAt: Timestamp.now(),
        subjectToWithholding: _subjectToWithholding,
        withholdingTaxRate: _withholdingTaxRate,
      );

      await docRef.set(supplier.toMap());

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
      await userDocRef.update({
        'supplierIds': FieldValue.arrayUnion([supplierId]),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_added'))),
      );
      Navigator.of(context).pop(true); // إرجاع true لتحديث الصفحة السابقة
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
      appBar: AppBar(title: Text(tr('add_supplier'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameArController,
                focusNode: _nameArFocus,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('supplier_nameArabic')),
                validator: _validateName,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_nameEnFocus);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameEnController,
                focusNode: _nameEnFocus,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('supplier_nameEnglish')),
                validator: _validateName,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_phoneFocus);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('phone')),
                validator: _validatePhone,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_emailFocus);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: tr('email')),
                validator: _validateEmail,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_addressFocus);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                focusNode: _addressFocus,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('address')),
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_notesFocus);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                focusNode: _notesFocus,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: tr('notes')),
                maxLines: 3,
                onFieldSubmitted: (_) {
                  _addSupplier();
                },
              ),
              const SizedBox(height: 16),
              _buildWithholdingTaxToggle(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _addSupplier,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('add')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}