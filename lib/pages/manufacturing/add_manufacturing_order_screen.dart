import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';


class AddManufacturingOrderScreen extends StatefulWidget {
  const AddManufacturingOrderScreen({super.key});

  @override
  AddManufacturingOrderScreenState createState() =>
      AddManufacturingOrderScreenState();
}

class AddManufacturingOrderScreenState
    extends State<AddManufacturingOrderScreen> {
  final _runsController = TextEditingController(text: '1');
  List<TextEditingController> _batchControllers = [];
  List<TextEditingController> _quantityControllers = [];
  FinishedProduct? _selectedProduct;
  Company? _selectedCompany;
  Factory? _selectedFactory;
  List<Company> _userCompanies = [];
  List<Factory> _companyFactories = [];
  List<FinishedProduct> _companyProducts = [];
  final _formKey = GlobalKey<FormState>();
  bool _loadingFactories = false;
  bool _loadingProducts = false;
  bool get _isArabic => context.locale.languageCode == 'ar';

  // بيانات الجدول للعرض
  List<_InventoryCheckItem> _inventoryCheckItems = [];

  bool _showInventoryTable = false;
  bool _checkingInventory = false;

  @override
  void initState() {
    super.initState();
    _generateRunFields(1);
    _loadUserCompanies();
  }

  void _loadUserCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
      if (companyIds.isEmpty) return;

      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: companyIds)
          .get();

      final companies = companiesSnapshot.docs
          .map((doc) => Company.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _userCompanies = companies;
      });
    } catch (e) {
      safeDebugPrint('Error loading companies: $e');
    }
  }

  Future<void> _loadCompanyFactories(String companyId) async {
    setState(() {
      _loadingFactories = true;
      _selectedFactory = null;
      _companyFactories = [];
      _selectedProduct = null;
      _companyProducts = [];
      _showInventoryTable = false;
    });

    try {
      final factoriesSnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .where('companyIds', arrayContains: companyId)
          .get();

      final factories = factoriesSnapshot.docs
          .map((doc) => Factory.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _companyFactories = factories;
        _loadingFactories = false;
      });
    } catch (e) {
      safeDebugPrint('Error loading factories: $e');
      setState(() {
        _loadingFactories = false;
      });
    }
  }

  Future<void> _loadCompanyProducts() async {
    if (_selectedCompany == null) return;

    setState(() {
      _loadingProducts = true;
      _selectedProduct = null;
      _showInventoryTable = false;
    });

    try {
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('finished_products')
          .where('companyId', isEqualTo: _selectedCompany!.id)
          .get();

      final products = productsSnapshot.docs
          .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _companyProducts = products;
        _loadingProducts = false;
      });
    } catch (e) {
      safeDebugPrint('Error loading products: $e');
      setState(() {
        _loadingProducts = false;
      });
    }
  }

  void _generateRunFields(int count) {
    _batchControllers = List.generate(
        count, (i) => TextEditingController(text: 'BATCH_${i + 1}'));
    _quantityControllers =
        List.generate(count, (i) => TextEditingController(text: '1'));
    setState(() {});
  }

/// يحسب كميات المواد الخام مضروبة في عدد التشغيلات الكلية
Future<void> _calculateInventoryNeeds() async {
  if (_selectedProduct == null || _selectedFactory == null) return;

  setState(() {
    _checkingInventory = true;
    _showInventoryTable = false;
    _inventoryCheckItems.clear();
  });

  try {
    // 1. احسب الكمية الإجمالية من جميع التشغيلات
    int totalRunsQuantity = _quantityControllers.fold(
        0, (sTotal, ctrl) => sTotal + (int.tryParse(ctrl.text) ?? 0));
    if (totalRunsQuantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.invalid_total_quantity'.tr())));
      setState(() {
        _checkingInventory = false;
      });
      return;
    }

    // 2. جلب بيانات التركيب من المسار المتداخل
    final compositionDoc = await FirebaseFirestore.instance
        .collection('finished_products')
        .doc(_selectedProduct!.id)
        .collection('composition')
        .doc('data')
        .get();

    if (!compositionDoc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.composition_not_found'.tr())));
      setState(() {
        _checkingInventory = false;
      });
      return;
    }

    final compositionData = compositionDoc.data()!;
    
    // 3. جلب المواد الخام ومواد التعبئة
    List<Map<String, dynamic>> rawMaterials = [];
    List<Map<String, dynamic>> packagingMaterials = [];

    // المواد الخام
    if (compositionData.containsKey('rawMaterials')) {
      final rawMaterialsData = compositionData['rawMaterials'];
      if (rawMaterialsData is List) {
        rawMaterials = List<Map<String, dynamic>>.from(
            rawMaterialsData.whereType<Map<String, dynamic>>());
      }
    }

    // مواد التعبئة والتغليف
    if (compositionData.containsKey('packagingMaterials')) {
      final packagingMaterialsData = compositionData['packagingMaterials'];
      if (packagingMaterialsData is List) {
        packagingMaterials = List<Map<String, dynamic>>.from(
            packagingMaterialsData.whereType<Map<String, dynamic>>());
      }
    }

    safeDebugPrint('Found ${rawMaterials.length} raw materials');
    safeDebugPrint('Found ${packagingMaterials.length} packaging materials');

    // 4. جمع كل المواد في قائمة واحدة
    List<_InventoryCheckItem> checkItems = [];

    // معالجة المواد الخام
    for (final item in rawMaterials) {
      String itemId = item['itemId']?.toString() ?? '';
      String itemName = 'Loading...';
      double qtyPerUnit = (item['quantity'] ?? 0).toDouble();

      if (itemId.isNotEmpty) {
        checkItems.add(_InventoryCheckItem(
          itemId: itemId,
          itemName: itemName,
          plannedQuantity: qtyPerUnit * totalRunsQuantity,
        ));
      }
    }

    // معالجة مواد التعبئة والتغليف
    for (final item in packagingMaterials) {
      String itemId = item['itemId']?.toString() ?? '';
      String itemName = 'Loading...';
      double qtyPerUnit = (item['quantity'] ?? 0).toDouble();

      if (itemId.isNotEmpty) {
        checkItems.add(_InventoryCheckItem(
          itemId: itemId,
          itemName: itemName,
          plannedQuantity: qtyPerUnit * totalRunsQuantity,
        ));
      }
    }

    // 5. جلب أسماء المواد من collection items والمخزون من المسار الصحيح
    for (int i = 0; i < checkItems.length; i++) {
      final item = checkItems[i];
      try {
        // جلب اسم المادة من collection items
        final itemDoc = await FirebaseFirestore.instance
            .collection('items')
            .doc(item.itemId)
            .get();

        if (itemDoc.exists) {
          final itemData = itemDoc.data()!;
          
          // تحديث اسم المادة
          final String itemName = _isArabic 
              ? (itemData['nameAr'] ?? itemData['nameEn'] ?? 'Unknown')
              : (itemData['nameEn'] ?? itemData['nameAr'] ?? 'Unknown');
          
          item.itemName = itemName;
        } else {
          item.itemName = 'Item Not Found';
        }

        // 6. جلب المخزون من المسار الصحيح: /factories/{factoryId}/inventory/{itemId}
        final inventoryDoc = await FirebaseFirestore.instance
            .collection('factories')
            .doc(_selectedFactory!.id)
            .collection('inventory')
            .doc(item.itemId)
            .get();

        double currentInventory = 0;
        if (inventoryDoc.exists) {
          final inventoryData = inventoryDoc.data()!;
          
          // البحث عن حقل الكمية في المخزون
          if (inventoryData.containsKey('quantity')) {
            currentInventory = (inventoryData['quantity'] ?? 0).toDouble();
          } else if (inventoryData.containsKey('stock')) {
            currentInventory = (inventoryData['stock'] ?? 0).toDouble();
          } else if (inventoryData.containsKey('currentQuantity')) {
            currentInventory = (inventoryData['currentQuantity'] ?? 0).toDouble();
          } else if (inventoryData.containsKey('availableQuantity')) {
            currentInventory = (inventoryData['availableQuantity'] ?? 0).toDouble();
          }
          
          safeDebugPrint('Inventory found for ${item.itemId}: $currentInventory');
        } else {
          safeDebugPrint('No inventory found for ${item.itemId} in factory ${_selectedFactory!.id}');
        }

        item.currentInventory = currentInventory;
        item.difference = currentInventory - item.plannedQuantity;

      } catch (e) {
        safeDebugPrint('Error fetching data for ${item.itemId}: $e');
        item.itemName = 'Error Loading';
        item.currentInventory = 0;
        item.difference = -item.plannedQuantity;
      }
    }

    setState(() {
      _inventoryCheckItems = checkItems;
      _showInventoryTable = true;
      _checkingInventory = false;
    });
    
    if (checkItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.no_materials_found'.tr())));
    }

  } catch (e) {
    safeDebugPrint('Error calculating inventory needs: $e');
    setState(() {
      _checkingInventory = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}


/* 
/// يحسب كميات المواد الخام مضروبة في عدد التشغيلات الكلية
Future<void> _calculateInventoryNeeds() async {
  if (_selectedProduct == null) return;

  setState(() {
    _checkingInventory = true;
    _showInventoryTable = false;
    _inventoryCheckItems.clear();
  });

  try {
    // 1. احسب الكمية الإجمالية من جميع التشغيلات
    int totalRunsQuantity = _quantityControllers.fold(
        0, (sTotal, ctrl) => sTotal + (int.tryParse(ctrl.text) ?? 0));
    if (totalRunsQuantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.invalid_total_quantity'.tr())));
      setState(() {
        _checkingInventory = false;
      });
      return;
    }

    // 2. جلب بيانات التركيب من المسار المتداخل
    final compositionDoc = await FirebaseFirestore.instance
        .collection('finished_products')
        .doc(_selectedProduct!.id)
        .collection('composition')
        .doc('data')
        .get();

    if (!compositionDoc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.composition_not_found'.tr())));
      setState(() {
        _checkingInventory = false;
      });
      return;
    }

    final compositionData = compositionDoc.data()!;
    
    // 3. جلب المواد الخام ومواد التعبئة
    List<Map<String, dynamic>> rawMaterials = [];
    List<Map<String, dynamic>> packagingMaterials = [];

    // المواد الخام
    if (compositionData.containsKey('rawMaterials')) {
      final rawMaterialsData = compositionData['rawMaterials'];
      if (rawMaterialsData is List) {
        rawMaterials = List<Map<String, dynamic>>.from(
            rawMaterialsData.whereType<Map<String, dynamic>>());
      }
    }

    // مواد التعبئة والتغليف
    if (compositionData.containsKey('packagingMaterials')) {
      final packagingMaterialsData = compositionData['packagingMaterials'];
      if (packagingMaterialsData is List) {
        packagingMaterials = List<Map<String, dynamic>>.from(
            packagingMaterialsData.whereType<Map<String, dynamic>>());
      }
    }

    safeDebugPrint('Found ${rawMaterials.length} raw materials');
    safeDebugPrint('Found ${packagingMaterials.length} packaging materials');

    // 4. جمع كل المواد في قائمة واحدة
    List<_InventoryCheckItem> checkItems = [];

    // معالجة المواد الخام
    for (final item in rawMaterials) {
      String itemId = item['itemId']?.toString() ?? '';
      String itemName = 'Loading...'; // سنحمل الاسم لاحقاً
      double qtyPerUnit = (item['quantity'] ?? 0).toDouble();

      if (itemId.isNotEmpty) {
        checkItems.add(_InventoryCheckItem(
          itemId: itemId,
          itemName: itemName, // مؤقتاً
          plannedQuantity: qtyPerUnit * totalRunsQuantity,
        ));
        
        safeDebugPrint('Raw Material: ID: $itemId, Qty: $qtyPerUnit');
      }
    }

    // معالجة مواد التعبئة والتغليف
    for (final item in packagingMaterials) {
      String itemId = item['itemId']?.toString() ?? '';
      String itemName = 'Loading...'; // سنحمل الاسم لاحقاً
      double qtyPerUnit = (item['quantity'] ?? 0).toDouble();

      if (itemId.isNotEmpty) {
        checkItems.add(_InventoryCheckItem(
          itemId: itemId,
          itemName: itemName, // مؤقتاً
          plannedQuantity: qtyPerUnit * totalRunsQuantity,
        ));
        
        safeDebugPrint('Packaging Material: ID: $itemId, Qty: $qtyPerUnit');
      }
    }

    // 5. جلب أسماء المواد والمخزون من collection items
    for (int i = 0; i < checkItems.length; i++) {
      final item = checkItems[i];
      try {
        // جلب بيانات المادة من collection items
        final itemDoc = await FirebaseFirestore.instance
            .collection('items')
            .doc(item.itemId)
            .get();

        if (itemDoc.exists) {
          final itemData = itemDoc.data()!;
          
          // تحديث اسم المادة
          final String itemName = _isArabic 
              ? (itemData['nameAr'] ?? itemData['nameEn'] ?? 'Unknown')
              : (itemData['nameEn'] ?? itemData['nameAr'] ?? 'Unknown');
          
          item.itemName = itemName;

          // جلب المخزون
          double currentInventory = 0;
          if (itemData.containsKey('quantity')) {
            currentInventory = (itemData['quantity'] ?? 0).toDouble();
          } else if (itemData.containsKey('stock')) {
            currentInventory = (itemData['stock'] ?? 0).toDouble();
          } else if (itemData.containsKey('inventory')) {
            currentInventory = (itemData['inventory'] ?? 0).toDouble();
          } else if (itemData.containsKey('currentStock')) {
            currentInventory = (itemData['currentStock'] ?? 0).toDouble();
          }
          
          item.currentInventory = currentInventory;
          item.difference = currentInventory - item.plannedQuantity;
          
          safeDebugPrint('Item ${item.itemId}: $itemName, Stock: $currentInventory');
        } else {
          item.itemName = 'Item Not Found';
          item.currentInventory = 0;
          item.difference = -item.plannedQuantity;
          safeDebugPrint('Item ${item.itemId} not found in items collection');
        }

      } catch (e) {
        safeDebugPrint('Error fetching item data for ${item.itemId}: $e');
        item.itemName = 'Error Loading';
        item.currentInventory = 0;
        item.difference = -item.plannedQuantity;
      }
    }

    setState(() {
      _inventoryCheckItems = checkItems;
      _showInventoryTable = true;
      _checkingInventory = false;
    });
    
    if (checkItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.no_materials_found'.tr())));
    }

  } catch (e) {
    safeDebugPrint('Error calculating inventory needs: $e');
    setState(() {
      _checkingInventory = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}
 */
/*   /// يحسب كميات المواد الخام مضروبة في عدد التشغيلات الكلية
  Future<void> _calculateInventoryNeeds() async {
    if (_selectedProduct == null) return;

    setState(() {
      _checkingInventory = true;
      _showInventoryTable = false;
      _inventoryCheckItems.clear();
    });

    try {
      // 1. احسب الكمية الإجمالية من جميع التشغيلات
      int totalRunsQuantity = _quantityControllers.fold(
          0, (sTotal, ctrl) => sTotal + (int.tryParse(ctrl.text) ?? 0));
      if (totalRunsQuantity <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('manufacturing.invalid_total_quantity'.tr())));
        setState(() {
          _checkingInventory = false;
        });
        return;
      }

      // 2. جلب بيانات التركيب من الـ Firestore للمنتج المحدد
      final productDoc = await FirebaseFirestore.instance
          .collection('finished_products')
          .doc(_selectedProduct!.id)
          .get();

      if (!productDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('manufacturing.product_not_found'.tr())));
        setState(() {
          _checkingInventory = false;
        });
        return;
      }

      final productData = productDoc.data()!;

      // 3. تحقق من هيكل البيانات - أضف هذا للتصحيح
      safeDebugPrint('Product data structure: ${productData.keys}');

      // 4. جلب قائمة المواد من الحقل materials أو items
      List<Map<String, dynamic>> materials = [];

      if (productData.containsKey('materials')) {
        final materialsData = productData['materials'];
        if (materialsData is List) {
          materials = List<Map<String, dynamic>>.from(
              materialsData.whereType<Map<String, dynamic>>());
        }
      } else if (productData.containsKey('items')) {
        final itemsData = productData['items'];
        if (itemsData is List) {
          materials = List<Map<String, dynamic>>.from(
              itemsData.whereType<Map<String, dynamic>>());
        }
      } else if (productData.containsKey('composition')) {
        final compositionData = productData['composition'];
        if (compositionData is Map) {
          final compMaterials =
              compositionData['materials'] ?? compositionData['items'];
          if (compMaterials is List) {
            materials = List<Map<String, dynamic>>.from(
                compMaterials.whereType<Map<String, dynamic>>());
          }
        }
      }

      safeDebugPrint('Found ${materials.length} materials in product');

      // 5. جمع كل المواد في قائمة واحدة
      List<_InventoryCheckItem> checkItems = [];

      for (final item in materials) {
        String itemId =
            item['itemId']?.toString() ?? item['id']?.toString() ?? '';
        String itemName = item['itemName']?.toString() ??
            item['name']?.toString() ??
            item['nameEn']?.toString() ??
            'Unknown';
        double qtyPerUnit = (item['quantity'] ?? item['qty'] ?? 0).toDouble();

        if (itemId.isNotEmpty) {
          checkItems.add(_InventoryCheckItem(
            itemId: itemId,
            itemName: itemName,
            plannedQuantity: qtyPerUnit * totalRunsQuantity,
          ));

          safeDebugPrint(
              'Material: $itemName (ID: $itemId), Qty per unit: $qtyPerUnit');
        } else {
          safeDebugPrint('Skipping material without ID: $item');
        }
      }

      // 6. جلب الرصيد الحالي من المخزون لكل مادة من collection items
      for (int i = 0; i < checkItems.length; i++) {
        final item = checkItems[i];
        try {
          // جلب بيانات المادة من collection items
          final itemDoc = await FirebaseFirestore.instance
              .collection('items')
              .doc(item.itemId)
              .get();

          double currentInventory = 0;
          if (itemDoc.exists) {
            final itemData = itemDoc.data();

            // تحقق من وجود حقل inventory أو quantity أو stock
            if (itemData?.containsKey('inventory') == true) {
              currentInventory = (itemData?['inventory'] ?? 0).toDouble();
            } else if (itemData?.containsKey('quantity') == true) {
              currentInventory = (itemData?['quantity'] ?? 0).toDouble();
            } else if (itemData?.containsKey('stock') == true) {
              currentInventory = (itemData?['stock'] ?? 0).toDouble();
            } else if (itemData?.containsKey('currentStock') == true) {
              currentInventory = (itemData?['currentStock'] ?? 0).toDouble();
            }

            // إذا كانت المادة raw_material، احسب الكمية المتاحة
            final category = itemData?['category']?.toString();
            if (category == 'raw_material') {
              safeDebugPrint(
                  'Raw material found: ${itemData?['nameEn']} - Stock: $currentInventory');
            }
          }

          item.currentInventory = currentInventory;
          item.difference = currentInventory - item.plannedQuantity;

          safeDebugPrint(
              'Item ${item.itemId}: planned=${item.plannedQuantity}, current=${item.currentInventory}');
        } catch (e) {
          safeDebugPrint('Error fetching item data for ${item.itemId}: $e');
          item.currentInventory = 0;
          item.difference = -item.plannedQuantity;
        }
      }

      setState(() {
        _inventoryCheckItems = checkItems;
        _showInventoryTable = true;
        _checkingInventory = false;
      });

      if (checkItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('manufacturing.no_materials_found'.tr())));
      }
    } catch (e) {
      safeDebugPrint('Error calculating inventory needs: $e');
      setState(() {
        _checkingInventory = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
 */
/*   Future<void> _calculateInventoryNeeds() async {
    if (_selectedProduct == null) return;

    setState(() {
      _checkingInventory = true;
      _showInventoryTable = false;
      _inventoryCheckItems.clear();
    });

    try {
      // 1. احسب الكمية الإجمالية من جميع التشغيلات
      int totalRunsQuantity = _quantityControllers.fold(
          0, (sTotal, ctrl) => sTotal + (int.tryParse(ctrl.text) ?? 0));
      if (totalRunsQuantity <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('manufacturing.invalid_total_quantity'.tr())));
        setState(() {
          _checkingInventory = false;
        });
        return;
      }

      // 2. جلب بيانات التركيب من الـ Firestore للمنتج المحدد
      final productDoc = await FirebaseFirestore.instance
          .collection('finished_products')
          .doc(_selectedProduct!.id)
          .get();

      if (!productDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('manufacturing.product_not_found'.tr())));
        setState(() {
          _checkingInventory = false;
        });
        return;
      }

      final productData = productDoc.data()!;
      final rawMaterials =
          List<Map<String, dynamic>>.from(productData['rawMaterials'] ?? []);
      final packagingMaterials = List<Map<String, dynamic>>.from(
          productData['packagingMaterials'] ?? []);

      // 3. جمع كل المواد (خام وتعبئة وتغليف) في قائمة واحدة مع الكميات مضروبة في العدد الإجمالي
      List<_InventoryCheckItem> checkItems = [];

      for (final item in rawMaterials) {
        String itemId = item['itemId'];
        String itemName = item['itemName'];
        double qtyPerUnit = (item['quantity'] ?? 0).toDouble();

        checkItems.add(_InventoryCheckItem(
          itemId: itemId,
          itemName: itemName,
          plannedQuantity: qtyPerUnit * totalRunsQuantity,
        ));
      }

      for (final item in packagingMaterials) {
        String itemId = item['itemId'];
        String itemName = item['itemName'];
        double qtyPerUnit = (item['quantity'] ?? 0).toDouble();

        checkItems.add(_InventoryCheckItem(
          itemId: itemId,
          itemName: itemName,
          plannedQuantity: qtyPerUnit * totalRunsQuantity,
        ));
      }

      // 4. جلب الرصيد الحالي من المخزون لكل مادة
      // نفترض أن المخزون محفوظ في collection اسمها 'inventory' مع المستندات حسب itemId
      for (int i = 0; i < checkItems.length; i++) {
        final item = checkItems[i];
        final invDoc = await FirebaseFirestore.instance
            .collection('inventory')
            .doc(item.itemId)
            .get();

        double currentInventory = 0;
        if (invDoc.exists) {
          final data = invDoc.data();
          currentInventory = (data?['quantity'] ?? 0).toDouble();
        }
        item.currentInventory = currentInventory;
        item.difference = currentInventory - item.plannedQuantity;
      }

      setState(() {
        _inventoryCheckItems = checkItems;
        _showInventoryTable = true;
        _checkingInventory = false;
      });
    } catch (e) {
      safeDebugPrint('Error calculating inventory needs: $e');
      setState(() {
        _checkingInventory = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
 */
/*   Future<void> _saveManufacturingOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedProduct == null ||
        _selectedCompany == null ||
        _selectedFactory == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('validation.select_all_fields'.tr())));
      return;
    }

    // تحقق من وجود نواقص قبل الحفظ
    bool hasShortages = _inventoryCheckItems.any((item) => item.difference < 0);
    if (hasShortages) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('manufacturing.insufficient_inventory'.tr()),
          content: Text('manufacturing.confirm_save_with_shortage'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('no'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('yes'.tr()),
            ),
          ],
        ),
      );
      if (result != true) {
        return;
      }
    }

    // جمع الكمية الكلية من التشغيلات
    int totalQuantity =
        _quantityControllers.fold(0, (sTotal, ctrl) => sTotal + (int.tryParse(ctrl.text) ?? 0));

    final runs = List.generate(_batchControllers.length, (index) {
      return ManufacturingRun(
        batchNumber: _batchControllers[index].text,
        quantity: int.parse(_quantityControllers[index].text),
        completedAt: null,
      );
    });

    // Convert inventory items to the correct type for RawMaterial
    final rawMaterialsList = _inventoryCheckItems
        .map((e) => RawMaterial(
              materialId: e.itemId,
              materialName: e.itemName,
              quantityRequired: e.plannedQuantity,
              unit: '', // يمكنك تعديل الوحدة حسب الحاجة
            ))
        .toList();

    final order = ManufacturingOrder(
      id: '',
      productId: _selectedProduct!.id!,
      productName:_isArabic // context.locale.languageCode == 'ar'
          ? _selectedProduct!.nameAr
          : _selectedProduct!.nameEn,
      totalQuantity: totalQuantity,
      productUnit: _selectedProduct!.unit,
      manufacturingDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      status: ManufacturingStatus.pending,
      isFinished: false,
      rawMaterials: rawMaterialsList,
      createdAt: DateTime.now(),
      runs: runs,
      companyId: _selectedCompany!.id!,
      factoryId: _selectedFactory!.id!,
      packagingMaterials: [], // يمكنك تعبئتها حسب الحاجة
    );

    try {
      final manufacturingService =
          Provider.of<ManufacturingService>(context, listen: false);
      await manufacturingService.createManufacturingOrder(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('manufacturing.order_created'.tr())));

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      safeDebugPrint('Error saving manufacturing order: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')));
    }
  } */

/*   Future<void> _saveManufacturingOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedProduct == null ||
        _selectedCompany == null ||
        _selectedFactory == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('validation.select_all_fields'.tr())));
      return;
    }

    // تحقق من وجود نواقص قبل الحفظ
    bool hasShortages = _inventoryCheckItems.any((item) => item.difference < 0);
    if (hasShortages) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('manufacturing.insufficient_inventory'.tr()),
          content: Text('manufacturing.confirm_save_with_shortage'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('no'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('yes'.tr()),
            ),
          ],
        ),
      );
      if (result != true) {
        return;
      }
    }

    // جمع الكمية الكلية من التشغيلات
    int totalQuantity = _quantityControllers.fold(
        0, (sTotal, ctrl) => sTotal + (int.tryParse(ctrl.text) ?? 0));

    final runs = List.generate(_batchControllers.length, (index) {
      return ManufacturingRun(
        batchNumber: _batchControllers[index].text,
        quantity: int.parse(_quantityControllers[index].text),
        completedAt: null,
      );
    });

    // Convert inventory items to the correct type for RawMaterial
    final rawMaterialsList = _inventoryCheckItems
        .map((e) => RawMaterial(
              materialId: e.itemId,
              materialName: e.itemName,
              quantityRequired: e.plannedQuantity,
              unit: '',
            ))
        .toList();

    final order = ManufacturingOrder(
      id: '',
      productId: _selectedProduct!.id!,
      productName: _isArabic // context.locale.languageCode == 'ar'
          ? _selectedProduct!.nameAr
          : _selectedProduct!.nameEn,
      totalQuantity: totalQuantity,
      productUnit: _selectedProduct!.unit,
      manufacturingDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      status: ManufacturingStatus.pending,
      isFinished: false,
      rawMaterials: rawMaterialsList,
      createdAt: DateTime.now(),
      runs: runs,
      companyId: _selectedCompany!.id!,
      factoryId: _selectedFactory!.id!,
      packagingMaterials: [], // يمكنك تعبئتها حسب الحاجة
    );

    try {
      // Get the service before any async operations that might cause the widget to dispose
      final manufacturingService =
          Provider.of<ManufacturingService>(context, listen: false);

      await manufacturingService.createManufacturingOrder(order);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.order_created'.tr())));

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      safeDebugPrint('Error saving manufacturing order: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
 */

/* Future<void> _saveManufacturingOrder() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }
  if (_selectedProduct == null ||
      _selectedCompany == null ||
      _selectedFactory == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('validation.select_all_fields'.tr())));
    return;
  }

  // تحقق من وجود نواقص قبل الحفظ
  bool hasShortages = _inventoryCheckItems.any((item) => item.difference < 0);
  if (hasShortages) {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('manufacturing.insufficient_inventory'.tr()),
        content: Text('manufacturing.confirm_save_with_shortage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('yes'.tr()),
          ),
        ],
      ),
    );
    if (result != true) {
      return;
    }
  }

  // جمع الكمية الكلية من التشغيلات
  int totalQuantity = _quantityControllers.fold(
      0, (sTotal, ctrl) => sTotal + (int.tryParse(ctrl.text) ?? 0));

  final runs = List.generate(_batchControllers.length, (index) {
    return {
      'batchNumber': _batchControllers[index].text,
      'quantity': int.parse(_quantityControllers[index].text),
      'completedAt': null,
    };
  });

  // Convert inventory items to the correct format
  final rawMaterialsList = _inventoryCheckItems
      .map((e) => {
            'materialId': e.itemId,
            'materialName': e.itemName,
            'quantityRequired': e.plannedQuantity,
            'unit': '',
            'minStockLevel': 0,
          })
      .toList();

  // إنشاء الـ order كـ Map بدلاً من object مباشر
  final orderData = {
    'productId': _selectedProduct!.id!,
    'productName': _isArabic
        ? _selectedProduct!.nameAr
        : _selectedProduct!.nameEn,
    'totalQuantity': totalQuantity,
    'productUnit': _selectedProduct!.unit,
    'manufacturingDate': Timestamp.now(),
    'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
    'status': 'pending',
    'isFinished': false,
    'rawMaterials': rawMaterialsList,
    'packagingMaterials': [],
    'createdAt': Timestamp.now(),
    'runs': runs,
    'companyId': _selectedCompany!.id!,
    'factoryId': _selectedFactory!.id!,
    'qualityStatus': 'pending',
    'qualityNotes': null,
    'barcodeUrl': null,
  };

  try {
    final manufacturingService =
        Provider.of<ManufacturingService>(context, listen: false);

    // استخدام دالة معدلة في ManufacturingService
    await manufacturingService.createManufacturingOrderFromMap(orderData);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('manufacturing.order_created'.tr())));

    if (!mounted) return;
    Navigator.of(context).pop();
  } catch (e) {
    safeDebugPrint('Error saving manufacturing order: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
  }
}
 */

  
  Future<void> _saveManufacturingOrder() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }
  if (_selectedProduct == null ||
      _selectedCompany == null ||
      _selectedFactory == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('validation.select_all_fields'.tr())));
    return;
  }

  // تحقق من وجود نواقص قبل الحفظ
  bool hasShortages = _inventoryCheckItems.any((item) => item.difference < 0);
  if (hasShortages) {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('manufacturing.insufficient_inventory'.tr()),
        content: Text('manufacturing.confirm_save_with_shortage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('yes'.tr()),
          ),
        ],
      ),
    );
    if (result != true) {
      return;
    }
  }

  // جمع الكمية الكلية من التشغيلات
  int totalQuantity = _quantityControllers.fold(
      0, (sTotal, ctrl) => sTotal + (int.tryParse(ctrl.text) ?? 0));

  final runs = List.generate(_batchControllers.length, (index) {
    return {
      'batchNumber': _batchControllers[index].text,
      'quantity': int.parse(_quantityControllers[index].text),
      'completedAt': null,
    };
  });

  // Convert inventory items to the correct format
  final rawMaterialsList = _inventoryCheckItems
      .map((e) => {
            'materialId': e.itemId,
            'materialName': e.itemName,
            'quantityRequired': e.plannedQuantity,
            'unit': '',
            'minStockLevel': 0,
          })
      .toList();

  // إنشاء الـ order كـ Map بدلاً من object مباشر
  final orderData = {
    'productId': _selectedProduct!.id!,
    'productName': _isArabic
        ? _selectedProduct!.nameAr
        : _selectedProduct!.nameEn,
    'totalQuantity': totalQuantity,
    'productUnit': _selectedProduct!.unit,
    'manufacturingDate': Timestamp.now(),
    'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
    'status': 'pending',
    'isFinished': false,
    'rawMaterials': rawMaterialsList,
    'packagingMaterials': [],
    'createdAt': Timestamp.now(),
    'runs': runs,
    'companyId': _selectedCompany!.id!,
    'factoryId': _selectedFactory!.id!,
    'qualityStatus': 'pending',
    'qualityNotes': null,
    'barcodeUrl': null,
  };

  try {
    if (!mounted) return;

    final manufacturingService =
        Provider.of<ManufacturingService>(context, listen: false);

    // استخدام دالة معدلة في ManufacturingService
    await manufacturingService.createManufacturingOrderFromMap(orderData);

    // استدعاء startManufacturingWithComposition بعد حفظ الأمر بنجاح
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (!mounted) return;

      await manufacturingService.startManufacturingWithComposition(
        companyId: _selectedCompany!.id!,
        factoryId: _selectedFactory!.id!,
        productId: _selectedProduct!.id!,
        totalQuantity: totalQuantity,
        batchNumber: _batchControllers.isNotEmpty ? _batchControllers[0].text : 'BATCH_1',
        userId: user.uid,
        context: context,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('manufacturing.order_created'.tr())));

    if (!mounted) return;
    Navigator.of(context).pop();
  } catch (e) {
    safeDebugPrint('Error saving manufacturing order: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
  }
}
  
  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text('manufacturing.add_order'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // اختيار الشركة
              DropdownButtonFormField<Company>(
                initialValue: _selectedCompany,
                decoration: InputDecoration(
                  labelText: 'company.select_company'.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: _userCompanies.map((company) {
                  return DropdownMenuItem(
                    value: company,
                    child: Text(isArabic ? company.nameAr : company.nameEn),
                  );
                }).toList(),
                onChanged: (selectedCompany) {
                  setState(() {
                    _selectedCompany = selectedCompany;
                    _selectedFactory = null;
                    _companyFactories = [];
                    _selectedProduct = null;
                    _companyProducts = [];
                    _showInventoryTable = false;
                  });
                  if (selectedCompany != null) {
                    _loadCompanyFactories(selectedCompany.id!);
                  }
                },
                validator: (v) => v == null ? 'validation.required'.tr() : null,
              ),
              const SizedBox(height: 16),

              // اختيار المصنع
              if (_selectedCompany != null) ...[
                _loadingFactories
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<Factory>(
                        initialValue: _selectedFactory,
                        decoration: InputDecoration(
                          labelText: 'factory.select_factory'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _companyFactories.map((factory) {
                          return DropdownMenuItem(
                            value: factory,
                            child: Text(
                                isArabic ? factory.nameAr : factory.nameEn),
                          );
                        }).toList(),
                        onChanged: (selectedFactory) {
                          setState(() {
                            _selectedFactory = selectedFactory;
                            _selectedProduct = null;
                            _companyProducts = [];
                            _showInventoryTable = false;
                          });
                          if (selectedFactory != null) {
                            _loadCompanyProducts();
                          }
                        },
                        validator: (v) =>
                            v == null ? 'validation.required'.tr() : null,
                      ),
                const SizedBox(height: 16),
              ],

              // اختيار المنتج
              if (_selectedFactory != null) ...[
                _loadingProducts
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<FinishedProduct>(
                        initialValue: _selectedProduct,
                        decoration: InputDecoration(
                          labelText: 'manufacturing.select_product'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _companyProducts.map((product) {
                          return DropdownMenuItem(
                            value: product,
                            child: Text(
                                isArabic ? product.nameAr : product.nameEn),
                          );
                        }).toList(),
                        onChanged: (selectedProduct) {
                          setState(() {
                            _selectedProduct = selectedProduct;
                            _showInventoryTable = false;
                          });
                        },
                        validator: (v) =>
                            v == null ? 'validation.required'.tr() : null,
                      ),
                const SizedBox(height: 16),
              ],

              // عدد التشغيلات
              if (_selectedProduct != null) ...[
                TextFormField(
                  controller: _runsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'manufacturing.number_of_runs'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    int count = int.tryParse(value) ?? 1;
                    if (count < 1) count = 1;
                    _generateRunFields(count);
                    setState(() {
                      _showInventoryTable = false;
                    });
                  },
                  validator: (v) {
                    final val = int.tryParse(v ?? '');
                    if (val == null || val < 1) {
                      return 'validation.invalid_number'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // التشغيلات (Batch + quantity)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _batchControllers.length,
                  itemBuilder: (context, index) {
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _batchControllers[index],
                            decoration: InputDecoration(
                              labelText:
                                  '${'manufacturing.batch_number'.tr()} #${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'validation.required'.tr()
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityControllers[index],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'manufacturing.run_quantity'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final val = int.tryParse(v ?? '');
                              if (val == null || val < 1) {
                                return 'validation.invalid_number'.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // أزرار: عرض الجدول - حفظ
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _checkingInventory
                            ? null
                            : _calculateInventoryNeeds,
                        child: _checkingInventory
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('manufacturing.show_inventory'.tr()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showInventoryTable
                            ? _saveManufacturingOrder
                            : null,
                        child: Text('manufacturing.save_order'.tr()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // جدول عرض المواد المطلوبة
                if (_showInventoryTable)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                      //  const DataColumn(label: Text('itemId')),
                        const DataColumn(label: Text('itemName')),
                        const DataColumn(label: Text('plan')),
                        const DataColumn(label: Text('inventory')),
                        const DataColumn(label: Text('difference')),
                      ],
                      rows: _inventoryCheckItems.map((item) {
                        final differenceColor =
                            item.difference < 0 ? Colors.red : Colors.green;
                        return DataRow(cells: [
                    //      DataCell(Text(item.itemId)),
                          DataCell(Text(item.itemName)),
                          DataCell(
                              Text(item.plannedQuantity.toStringAsFixed(2))),
                          DataCell(
                              Text(item.currentInventory.toStringAsFixed(2))),
                          DataCell(Text(
                            item.difference.toStringAsFixed(2),
                            style: TextStyle(color: differenceColor),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryCheckItem {
  final String itemId;
  String itemName;
  final double plannedQuantity;
  double currentInventory = 0;
  double difference = 0;

  _InventoryCheckItem({
    required this.itemId,
    required this.itemName,
    required this.plannedQuantity,
  });
}
