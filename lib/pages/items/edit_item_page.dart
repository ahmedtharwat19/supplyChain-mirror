// pages/items/edit_item_page.dart - تصحيح الخطأ
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class EditItemPage extends StatefulWidget {
  final String itemId;

  const EditItemPage({super.key, required this.itemId});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _category = Item.allowedCategories.first;
  String _unit = Item.allowedUnits.first;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.itemId)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('item_not_found'))),
        );
        Navigator.of(context).pop();
        return;
      }

      final item = Item.fromMap(doc.data()!);

      _nameArController.text = item.nameAr;
      _nameEnController.text = item.nameEn;
      _descriptionController.text = item.description ?? '';
      _priceController.text = item.unitPrice.toString();

      _category = Item.allowedCategories.contains(item.category)
          ? item.category
          : Item.allowedCategories.first;

      _unit = Item.allowedUnits.contains(item.unit)
          ? item.unit
          : Item.allowedUnits.first;
          
      safeDebugPrint('Fetched category: ${item.category}');
      safeDebugPrint('Fetched unit: ${item.unit}');
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

  Future<void> _updateItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('please_login_first'))),
        );
        setState(() => _isSaving = false);
        return;
      }

      final itemData = {
        Item.fieldNameAr: _nameArController.text.trim(),
        Item.fieldNameEn: _nameEnController.text.trim(),
        Item.fieldDescription: _descriptionController.text.trim(),
        Item.fieldCategory: _category,
        Item.fieldUnit: _unit,
        Item.fieldUnitPrice: double.tryParse(_priceController.text.trim()) ?? 0,
        Item.fieldIsTaxable: true,
        Item.fieldUserId: userId,
        // ✅ استخدام FieldValue.serverTimestamp() مباشرة بدلاً من حقل غير موجود
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.itemId)
          .update(itemData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('item_updated_successfully'))),
      );

      Navigator.of(context).pop(true);
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
    _nameArController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('edit_item'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameArController,
                      decoration: InputDecoration(labelText: tr('nameArabic')),
                      validator: (value) => value == null || value.isEmpty
                          ? tr('required_field')
                          : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameEnController,
                      decoration: InputDecoration(labelText: tr('nameEnglish')),
                      validator: (value) => value == null || value.isEmpty
                          ? tr('required_field')
                          : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(labelText: tr('category')),
                      items: Item.allowedCategories
                          .map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(tr(cat)),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: InputDecoration(labelText: tr('unit')),
                      items: Item.allowedUnits
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(tr(unit)),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _unit = val!),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(labelText: tr('unit_price')),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return tr('please_enter_price');
                        }
                        if (double.tryParse(value.trim()) == null) {
                          return tr('invalid_price');
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: tr('description')),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _updateItem(),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _updateItem,
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