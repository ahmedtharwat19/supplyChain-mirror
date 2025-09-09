/* import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

import '../../models/item.dart';

class AddItemPage extends StatefulWidget {
  final Item? existingItem;

  const AddItemPage({super.key, this.existingItem});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  FocusNode categoryFocusNode = FocusNode();
  FocusNode unitFocusNode = FocusNode();

  String _category = Item.allowedCategories.first;
  String _unit = Item.allowedUnits.first;

  bool _isLoading = false;

  final arabicOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'));
  final englishOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));
  final numbersOnlyFormatter = FilteringTextInputFormatter.digitsOnly;
  final priceFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _nameArController.text = item.nameAr;
      _nameEnController.text = item.nameEn;
      _descriptionController.text = item.description ?? '';
      _priceController.text = item.unitPrice?.toString() ?? '';
      _category = item.category;
      _unit = item.unit;
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    categoryFocusNode.dispose();
    unitFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_fill_all_required_fields'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await UserLocalStorage.getUser();
      final userId = user?['userId'];
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('please_login_first'))),
        );
        setState(() => _isLoading = false);
        return;
      }

      final itemData = {
        Item.fieldNameAr: _nameArController.text.trim(),
        Item.fieldNameEn: _nameEnController.text.trim(),
        Item.fieldCategory: _category,
        Item.fieldUnit: _unit,
        Item.fieldDescription: _descriptionController.text.trim(),
        Item.fieldUserId: userId,
        Item.fieldUnitPrice: double.tryParse(_priceController.text.trim()) ?? 0,
        Item.fieldCreatedAt: FieldValue.serverTimestamp(),
      };

      final collection = FirebaseFirestore.instance.collection('items');

      if (widget.existingItem == null) {
        await collection.add(itemData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('item_added_successfully'))),
        );
      } else {
        await collection.doc(widget.existingItem!.id).update(itemData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('item_updated_successfully'))),
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      safeDebugPrint('Error saving item: $e');
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
        title: Text(
            widget.existingItem == null ? tr('add_item') : tr('edit_item')),
      ),
      body: Padding(
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
                inputFormatters: [arabicOnlyFormatter],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(labelText: tr('nameEnglish')),
                validator: (value) => value == null || value.isEmpty
                    ? tr('required_field')
                    : null,
                inputFormatters: [englishOnlyFormatter],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
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
                value: _unit,
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
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveItem,
                child: Text(
                    widget.existingItem == null ? tr('add') : tr('update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import '../../models/item.dart';

class AddItemPage extends StatefulWidget {
  final Item? existingItem;

  const AddItemPage({super.key, this.existingItem});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  FocusNode categoryFocusNode = FocusNode();
  FocusNode unitFocusNode = FocusNode();

  String _category = Item.allowedCategories.first;
  String _unit = Item.allowedUnits.first;

  bool _isLoading = false;

  final arabicOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'));
  final englishOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));
  final numbersOnlyFormatter = FilteringTextInputFormatter.digitsOnly;
  final priceFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _nameArController.text = item.nameAr;
      _nameEnController.text = item.nameEn;
      _descriptionController.text = item.description ?? '';
      _priceController.text = item.unitPrice.toString();
      _category = item.category;
      _unit = item.unit;
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    categoryFocusNode.dispose();
    unitFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_fill_all_required_fields'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await UserLocalStorage.getUser();
      final userId = user?['userId'];
      safeDebugPrint('Local User ID: $userId');

    //       final authUser = FirebaseAuth.instance.currentUser;
    // final userId = authUser?.uid;

    // safeDebugPrint('🔥 Auth UID: $userId');
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('please_login_first'))),
        );
        setState(() => _isLoading = false);
        return;
      }

      final itemData = {
        Item.fieldNameAr: _nameArController.text.trim(),
        Item.fieldNameEn: _nameEnController.text.trim(),
        Item.fieldCategory: _category,
        Item.fieldUnit: _unit,
        Item.fieldDescription: _descriptionController.text.trim(),
        Item.fieldUserId: userId,
        Item.fieldUnitPrice: double.tryParse(_priceController.text.trim()) ?? 0,
        Item.fieldCreatedAt: FieldValue.serverTimestamp(),
      };
      safeDebugPrint("🔥 Auth UID: ${FirebaseAuth.instance.currentUser?.uid}");
      safeDebugPrint("📦 itemData['userId']: ${itemData[Item.fieldUserId]}");

      final collection = FirebaseFirestore.instance.collection('items');

      if (widget.existingItem == null) {
        await collection.add(itemData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('item_added_successfully'))),
        );
      } else {
        await collection.doc(widget.existingItem!.itemId).update(itemData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('item_updated_successfully'))),
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      safeDebugPrint('Error saving item: $e');
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
        title: Text(
            widget.existingItem == null ? tr('add_item') : tr('edit_item')),
      ),
      body: Padding(
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
                inputFormatters: [arabicOnlyFormatter],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(labelText: tr('nameEnglish')),
                validator: (value) => value == null || value.isEmpty
                    ? tr('required_field')
                    : null,
                inputFormatters: [englishOnlyFormatter],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              KeyboardListener(
                focusNode: categoryFocusNode,
                onKeyEvent: (KeyEvent event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    FocusScope.of(context).requestFocus(unitFocusNode);
                  }
                },
                child: DropdownButtonFormField<String>(
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
              ),
              const SizedBox(height: 16),
              KeyboardListener(
                focusNode: unitFocusNode,
                onKeyEvent: (KeyEvent event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    // ممكن تنتقل للفيلد التالي أو تحفظ مباشرة
                    _saveItem();
                  }
                },
                child: DropdownButtonFormField<String>(
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
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveItem,
                child: Text(
                    widget.existingItem == null ? tr('add') : tr('update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
