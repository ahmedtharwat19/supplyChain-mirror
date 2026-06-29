import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddFinishedProductScreen extends StatefulWidget {
  const AddFinishedProductScreen({super.key});

  @override
  State<AddFinishedProductScreen> createState() => _AddFinishedProductScreenState();
}

class _AddFinishedProductScreenState extends State<AddFinishedProductScreen> {
  final _formKey = GlobalKey<FormState>();

  String _nameAr = '';
  String _nameEn = '';
  double _quantity = 0;
  String _unit = '';
  String _barCode = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSaving = false;

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('user_not_authenticated'.tr());

      // جلب companyId و factoryId من المستندات (تعديل حسب هيكل بياناتك)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final companyIds = userData['companyIds'] as List<dynamic>? ?? [];
      final factoryIds = userData['factoryIds'] as List<dynamic>? ?? [];

      final companyId = companyIds.isNotEmpty ? companyIds.first.toString() : 'default_companyId';
      final factoryId = factoryIds.isNotEmpty ? factoryIds.first.toString() : 'default_factoryId';

      final newProduct = FinishedProduct(
        id: null,
        nameAr: _nameAr,
        nameEn: _nameEn,
        quantity: _quantity,
        unit: _unit,
        companyId: companyId,
        factoryId: factoryId,
        userId: user.uid,
        createdAt: Timestamp.now(),
        barCode: _barCode,
        isValid: true,
      );

      await _firestore.collection('finished_products').add(newProduct.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('finished_products.added_success'.tr())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('finished_products.add'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'finished_products.name_ar'.tr()),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'validation.required'.tr();
                  }
                  return null;
                },
                onSaved: (value) => _nameAr = value!.trim(),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'finished_products.name_en'.tr()),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'validation.required'.tr();
                  }
                  return null;
                },
                onSaved: (value) => _nameEn = value!.trim(),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'finished_products.quantity'.tr()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'validation.required'.tr();
                  }
                  if (double.tryParse(value) == null) {
                    return 'validation.invalid_number'.tr();
                  }
                  return null;
                },
                onSaved: (value) => _quantity = double.parse(value!),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'finished_products.unit'.tr()),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'validation.required'.tr();
                  }
                  return null;
                },
                onSaved: (value) => _unit = value!.trim(),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'finished_products.barcode'.tr()),
                onSaved: (value) => _barCode = value?.trim() ?? '',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProduct,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('finished_products.save'.tr()),
              )
            ],
          ),
        ),
      ),
    );
  }
}
