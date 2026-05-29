// pages/items/add_item_page.dart - تصحيح الأخطاء
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
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

  final FocusNode _nameArFocus = FocusNode();
  final FocusNode _nameEnFocus = FocusNode();
  final FocusNode _categoryFocus = FocusNode();
  final FocusNode _unitFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();

  String _category = Item.allowedCategories.first;
  String _unit = Item.allowedUnits.first;
  bool _isLoading = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  // السماح بالأحرف العربية والأرقام والمسافات
  final arabicWithNumbersFormatter = FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF0-9\s]+'));
  // السماح بالأحرف الإنجليزية والأرقام والمسافات
  final englishWithNumbersFormatter = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]+'));
  // للسعر: أرقام ونقطة عشرية
  final priceFormatter = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

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
    _nameArFocus.dispose();
    _nameEnFocus.dispose();
    _categoryFocus.dispose();
    _unitFocus.dispose();
    _priceFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.always);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_fill_all_required_fields'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      
      safeDebugPrint('👤 Current user UID: $userId');

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
        await collection.doc(widget.existingItem!.itemId).update(itemData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('item_updated_successfully'))),
        );
      }

      // ✅ تم إزالة المتغيرات غير المستخدمة (prefs, itemsCacheKey)
      // إذا كنت بحاجة لتحديث الكاش لاحقاً، يمكنك إضافة المنطق هنا

      if (mounted) context.pop(true);
    } catch (e) {
      safeDebugPrint('Error saving item: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_occurred')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextFocus(FocusNode current, [FocusNode? next]) {
    if (next != null) {
      FocusScope.of(context).requestFocus(next);
    } else {
      current.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existingItem == null ? tr('add_item') : tr('edit_item')),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: ListView(
              children: [
                // الاسم عربي
                TextFormField(
                  controller: _nameArController,
                  focusNode: _nameArFocus,
                  decoration: InputDecoration(labelText: tr('nameArabic')),
                  validator: (value) =>
                      value == null || value.isEmpty ? tr('required_field') : null,
                  inputFormatters: [arabicWithNumbersFormatter],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _nextFocus(_nameArFocus, _nameEnFocus),
                ),
                const SizedBox(height: 16),

                // الاسم إنجليزي
                TextFormField(
                  controller: _nameEnController,
                  focusNode: _nameEnFocus,
                  decoration: InputDecoration(labelText: tr('nameEnglish')),
                  validator: (value) =>
                      value == null || value.isEmpty ? tr('required_field') : null,
                  inputFormatters: [englishWithNumbersFormatter],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _nextFocus(_nameEnFocus, _categoryFocus),
                ),
                const SizedBox(height: 16),

                // الفئة
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  focusNode: _categoryFocus,
                  decoration: InputDecoration(labelText: tr('category')),
                  items: Item.allowedCategories
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(tr(cat))))
                      .toList(),
                  onChanged: (val) => setState(() => _category = val!),
                  onTap: () => _categoryFocus.requestFocus(),
                ),
                const SizedBox(height: 16),

                // الوحدة
                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  focusNode: _unitFocus,
                  decoration: InputDecoration(labelText: tr('unit')),
                  items: Item.allowedUnits
                      .map((unit) => DropdownMenuItem(value: unit, child: Text(tr(unit))))
                      .toList(),
                  onChanged: (val) => setState(() => _unit = val!),
                  onTap: () => _unitFocus.requestFocus(),
                ),
                const SizedBox(height: 16),

                // السعر
                TextFormField(
                  controller: _priceController,
                  focusNode: _priceFocus,
                  decoration: InputDecoration(labelText: tr('unit_price')),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [priceFormatter],
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
                  onFieldSubmitted: (_) => _nextFocus(_priceFocus, _descriptionFocus),
                ),
                const SizedBox(height: 16),

                // الوصف
                TextFormField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocus,
                  decoration: InputDecoration(labelText: tr('description')),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _saveItem(),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _saveItem,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.existingItem == null ? tr('add') : tr('update')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}