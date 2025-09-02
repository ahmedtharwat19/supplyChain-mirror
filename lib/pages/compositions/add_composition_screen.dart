// add_composition_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/product_composition_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/pages/compositions/services/composition_service.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/services/company_service.dart';
import 'package:puresip_purchasing/services/factory_service.dart';
import '../purchasing/Purchasing_orders_crud/item_selection_dialog.dart';

class AddCompositionScreen extends StatefulWidget {
  final String productId;
  final String companyId;
  final String factoryId;

  const AddCompositionScreen({
    super.key,
    required this.productId,
    required this.companyId,
    required this.factoryId,
  });

  @override
  State<AddCompositionScreen> createState() => _AddCompositionScreenState();
}

class _AddCompositionScreenState extends State<AddCompositionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _batchSizeController = TextEditingController();
  final TextEditingController _shelfLifeController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  final List<CompositionItem> _rawMaterials = [];
  final List<CompositionItem> _packagingMaterials = [];
  List<Item> _itemsRaws = [];
  List<Item> _itemsPackage = [];
  bool _isLoading = false;
  bool get _isArabic => context.locale.languageCode == 'ar';
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // متغيرات لتخزين أسماء المواد
  final Map<String, String> _itemNames = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    try {
      if (_currentUser == null) return;

      final itemsRaws = await _firestoreService.getUserTypeItems(
          _currentUser.uid, 'raw_material');
      final itemsPackage = await _firestoreService.getUserTypeItems(
          _currentUser.uid, 'packaging');

      // تخزين أسماء المواد في Map للوصول السريع
      for (var item in itemsRaws) {
        _itemNames[item.itemId] =
            _isArabic ? item.nameAr : item.nameEn; // استخدام الاسم العربي
      }
      for (var item in itemsPackage) {
        _itemNames[item.itemId] =
            _isArabic ? item.nameAr : item.nameEn; // استخدام الاسم العربي
      }

      setState(() {
        _itemsRaws = itemsRaws;
        _itemsPackage = itemsPackage;
      });
    } catch (e) {
      _showErrorSnackbar('error_loading_items'.tr());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showItemSelectionDialog(String itemCategory) async {
    final itemsToShow =
        itemCategory == 'raw_material' ? _itemsRaws : _itemsPackage;

    final selectedItems = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(
        allItems: itemsToShow,
        preSelectedItems: _getSelectedItemIds(itemCategory),
      ),
    );

    if (selectedItems == null || selectedItems.isEmpty) return;

    setState(() {
      for (var item in selectedItems) {
        final compositionItem = CompositionItem(
          itemId: item.itemId,
          quantity: 0.0, // الكمية الافتراضية 0
          unit: item.unit,
        );

        if (itemCategory == 'raw_material') {
          if (!_rawMaterials.any((i) => i.itemId == item.itemId)) {
            _rawMaterials.add(compositionItem);
          }
        } else {
          if (!_packagingMaterials.any((i) => i.itemId == item.itemId)) {
            _packagingMaterials.add(compositionItem);
          }
        }
      }
    });
  }

  List<String> _getSelectedItemIds(String category) {
    final items =
        category == 'raw_material' ? _rawMaterials : _packagingMaterials;
    return items.map((i) => i.itemId).toList();
  }

  void _updateMaterialQuantity(
      CompositionItem material, String newQuantity, String category) {
    final quantity = double.tryParse(newQuantity) ?? 0.0;

    setState(() {
      if (category == 'raw_material') {
        final index =
            _rawMaterials.indexWhere((i) => i.itemId == material.itemId);
        if (index != -1) {
          _rawMaterials[index] = CompositionItem(
            itemId: material.itemId,
            quantity: quantity,
            unit: material.unit,
          );
        }
      } else {
        final index =
            _packagingMaterials.indexWhere((i) => i.itemId == material.itemId);
        if (index != -1) {
          _packagingMaterials[index] = CompositionItem(
            itemId: material.itemId,
            quantity: quantity,
            unit: material.unit,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyService = Provider.of<CompanyService>(context);
    final factoryService = Provider.of<FactoryService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('add_composition'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveComposition,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // عرض معلومات المنتج
                    Text(
                      '${'product'.tr()}: ${widget.productId}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    FutureBuilder<String?>(
                      future: _getCompanyName(widget.companyId, companyService),
                      builder: (context, snapshot) {
                        return Text(
                          '${'company'.tr()}: ${snapshot.hasData ? snapshot.data : widget.companyId}',
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    FutureBuilder<String?>(
                      future: _getFactoryName(widget.factoryId, factoryService),
                      builder: (context, snapshot) {
                        return Text(
                          '${'factory'.tr()}: ${snapshot.hasData ? snapshot.data : widget.factoryId}',
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // حجم التشغيلة
                    TextFormField(
                      controller: _batchSizeController,
                      decoration: InputDecoration(
                        labelText: 'batch_size'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'enter_batch_size'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // الوحدة
                    TextFormField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: 'unit'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'enter_unit'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // مدة الصلاحية
                    TextFormField(
                      controller: _shelfLifeController,
                      decoration: InputDecoration(
                        labelText: 'shelf_life_months'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'enter_shelf_life'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // أزرار إضافة المواد
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text('add_raws'.tr()),
                            onPressed: () =>
                                _showItemSelectionDialog('raw_material'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text('add_packaging'.tr()),
                            onPressed: () =>
                                _showItemSelectionDialog('packaging'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // عرض المواد الخام مع إمكانية إدخال الكميات
                    _buildMaterialsList('raw_material', _rawMaterials),
                    const SizedBox(height: 16),

                    // عرض مواد التغليف مع إمكانية إدخال الكميات
                    _buildMaterialsList('packaging', _packagingMaterials),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMaterialsList(String category, List<CompositionItem> materials) {
    if (materials.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category == 'raw_material'
              ? 'raw_materials'.tr()
              : 'packaging_materials'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...materials.map((material) => _buildMaterialCard(material, category)),
      ],
    );
  }

  Widget _buildMaterialCard(CompositionItem material, String category) {
    final itemName = _itemNames[material.itemId] ?? material.itemId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itemName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: material.quantity.toString(),
                    decoration: InputDecoration(
                      labelText: 'quantity'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        _updateMaterialQuantity(material, value, category),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    material.unit,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeMaterial(material, category),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _removeMaterial(CompositionItem material, String category) {
    setState(() {
      if (category == 'raw_material') {
        _rawMaterials.removeWhere((i) => i.itemId == material.itemId);
      } else {
        _packagingMaterials.removeWhere((i) => i.itemId == material.itemId);
      }
    });
  }

  Future<void> _saveComposition() async {
    if (_formKey.currentState!.validate()) {
      // التحقق من إدخال الكميات
      final hasEmptyQuantities = _rawMaterials.any((m) => m.quantity <= 0) ||
          _packagingMaterials.any((m) => m.quantity <= 0);

      if (hasEmptyQuantities) {
        _showErrorSnackbar('enter_all_quantities'.tr());
        return;
      }

      setState(() => _isLoading = true);

      try {
        final compositionService =
            Provider.of<CompositionService>(context, listen: false);

        final composition = ProductComposition(
          id: null,
          productId: widget.productId,
          companyId: widget.companyId,
          factoryId: widget.factoryId,
          batchSize: double.parse(_batchSizeController.text),
          unit: _unitController.text,
          rawMaterials: _rawMaterials,
          packagingMaterials: _packagingMaterials,
          shelfLife: int.parse(_shelfLifeController.text),
          createdAt: Timestamp.now(),
          userId: _currentUser?.uid ?? '',
        );

        await compositionService.saveComposition(composition);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('composition_saved'.tr())),
        );
      } catch (e) {
        _showErrorSnackbar('${'error'.tr()}: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _getCompanyName(
      String companyId, CompanyService service) async {
    try {
      final company = await service.getCompanyById(companyId);
      return _isArabic ? company?.nameAr : company?.nameEn;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getFactoryName(
      String factoryId, FactoryService service) async {
    try {
      final factory = await service.getFactoryById(factoryId);
      return _isArabic ? factory?.nameAr : factory?.nameEn;
    } catch (e) {
      return null;
    }
  }
}
