import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import '../../../services/firestore_service.dart';
import '../../../utils/user_local_storage.dart';
import 'item_selection_dialog.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;
  const AddPurchaseOrderPage({super.key, this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  double _taxRate = 14.0;
  final List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false; // غير ثابت لأننا سنغيره من الواجهة

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    debugPrint('⬇️ Start loading initial data...');
    setState(() => _isLoading = true);

    try {
      final user = await UserLocalStorage.getUser();
      debugPrint('🧑 user from storage: $user');

      if (user == null) {
        debugPrint('❌ User is null, stopping load.');
        setState(() => _isLoading = false);
        return;
      }

      final userId = user['userId'] as String;
      final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      debugPrint('🚀 userId: $userId');
      debugPrint('🚀 companyIds: $companyIds');
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Current Firebase userId: ${currentUser?.uid}');
      debugPrint('UserId from local storage: $userId');
      if (companyIds.isEmpty) {
        debugPrint('❌ companyIds is empty, stopping load.');
        setState(() => _isLoading = false);
        return;
      }

      final companies = await _firestoreService.getUserCompanies(companyIds);
      debugPrint('✅ Loaded companies count: ${companies.length}');

      final suppliers = await _firestoreService.getUserVendors(
        userId,
        (user['supplierIds'] as List?)?.cast<String>() ?? [],
      );

      debugPrint('✅ Loaded suppliers count: ${suppliers.length}');

      final items = await _firestoreService.getUserItems(userId);
      debugPrint('✅ Loaded items count: ${items.length}');

      List<Factory> factories = [];
      if (_selectedCompanyId != null) {
        factories =
            await _firestoreService.getUserFactories(userId, companyIds).first;
        debugPrint('✅ Loaded factories count: ${factories.length}');
      }

      if (!mounted) return;

      setState(() {
        _companies = companies;
        _suppliers = suppliers;
        _allItems = items;
        _factories = factories;

        if (_companies.isNotEmpty &&
            (_selectedCompanyId == null ||
                !_companies.any((c) => c.id == _selectedCompanyId))) {
          _selectedCompanyId = _companies.first.id;
          debugPrint(
              'ℹ️ _selectedCompanyId was reset to first company: $_selectedCompanyId');
        }

        if (_factories.isNotEmpty && _selectedFactoryId == null) {
          _selectedFactoryId = _factories.first.id;
          debugPrint(
              'ℹ️ _selectedFactoryId was set to first factory: $_selectedFactoryId');
        }
      });

      debugPrint('📊 State after loading:');
      debugPrint('  _companies.length: ${_companies.length}');
      debugPrint('  _suppliers.length: ${_suppliers.length}');
      debugPrint('  _allItems.length: ${_allItems.length}');
      debugPrint('  _factories.length: ${_factories.length}');
      debugPrint('  _selectedCompanyId: $_selectedCompanyId');
      debugPrint('  _selectedFactoryId: $_selectedFactoryId');
    } catch (e, st) {
      debugPrint('❌ Exception in _loadInitialData: $e');
      debugPrint(st.toString());
      _showErrorSnackbar('error_loading_data'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('⬆️ Finished loading initial data.');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCompanyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _companies.any((c) => c.id == _selectedCompanyId)
          ? _selectedCompanyId
          : null,
      decoration: InputDecoration(
        labelText: 'company'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _companies
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nameAr)))
          .toList(),
      onChanged: (val) async {
        if (val == null) return;
        setState(() => _selectedCompanyId = val);
        final user = await UserLocalStorage.getUser();
        final companyIds = (user?['companyIds'] as List?)?.cast<String>() ?? [];
        final userId = user?['userId'];
        debugPrint('🚀 userId: $userId');
        debugPrint('🚀 companyIds: $companyIds');
        final factories = await _firestoreService
            .getUserFactories(user?['userId'] ?? '', companyIds)
            .first;
        if (!mounted) return;
        setState(() {
          _factories =
              factories.where((f) => f.companyIds.contains(val)).toList();
          _selectedFactoryId =
              _factories.isNotEmpty ? _factories.first.id : null;
        });
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedFactoryId,
      decoration: InputDecoration(
        labelText: 'factory'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _factories
          .map((f) => DropdownMenuItem(value: f.id, child: Text(f.nameAr)))
          .toList(),
      onChanged: (val) => setState(() => _selectedFactoryId = val),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedSupplierId,
      decoration: InputDecoration(
        labelText: 'supplier'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _suppliers
          .map((v) => DropdownMenuItem(
              value: v.id, child: Text('${v.nameAr} (${v.nameEn})')))
          .toList(),
      onChanged: (val) => setState(() => _selectedSupplierId = val),
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Future<void> _showItemSelectionDialog() async {
    final selected = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (var i in selected) {
        if (!_items.any((e) => e.itemId == i.itemId)) {
          _items.add(i);
        }
      }
    });
  }

  bool _validateForm() {
    if (_selectedCompanyId == null ||
        _selectedSupplierId == null ||
        _items.isEmpty) {
      _showErrorSnackbar('missing_required_fields'.tr());
      return false;
    }
    return true;
  }

  Future<void> _submitOrder() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final poNumber =
          await _firestoreService.generatePoNumber(_selectedCompanyId!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderId = 'PO-$timestamp';
      final order = PurchaseOrder(
        id: orderId,
        poNumber: poNumber,
        userId: _auth.currentUser?.uid ?? '',
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId,
        supplierId: _selectedSupplierId!,
        orderDate: _orderDate,
        status: 'pending',
        items: _items,
        taxRate: _taxRate,
        totalAmount: _items.fold(0, (sTotal, item) => sTotal + item.totalPrice),
        totalTax: _items.fold(0, (sTotal, item) => sTotal + item.taxAmount),
        totalAmountAfterTax:
            _items.fold(0, (sTotal, item) => sTotal + item.totalAfterTaxAmount),
        isDelivered: _isDelivered,
      );
      await _firestoreService.createPurchaseOrder(order);
      // ✅ إذا كان الطلب مسلَّم مباشرةً، قم بتحديث المخزون
/*       if (_isDelivered) {
        final user = _auth.currentUser;
        if (user != null) {
          debugPrint(
              '📦 Order is marked as delivered. Processing stock movements.');

          for (final item in _items) {
            final itemId = item.itemId;
            final quantity = item.quantity;

            if (itemId.isEmpty || quantity <= 0) continue;

            try {
              // 1. أضف حركة المخزون
              await FirebaseFirestore.instance
                  .collection('companies/$_selectedCompanyId/stock_movements')
                  .add({
                'type': 'purchase',
                'itemId': itemId,
                'quantity': quantity,
                'date': FieldValue.serverTimestamp(),
                'referenceId': orderId,
                'userId': user.uid,
                'factoryId': _selectedFactoryId,
              });

              // 2. تحديث الكمية في المخزون
              final stockRef = FirebaseFirestore.instance
                  .collection('factories/$_selectedFactoryId/inventory')
                  .doc(itemId);

              await stockRef.set({
                'quantity': FieldValue.increment(quantity),
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (e) {
              debugPrint('❌ Error processing item $itemId: $e');
            }
          }
        }
      }
 */
if (_isDelivered) {
  final user = _auth.currentUser;
  if (user != null) {
    debugPrint('📦 Order is marked as delivered. Processing stock movements.');
    await _firestoreService.processStockDelivery(
      companyId: _selectedCompanyId!,
      factoryId: _selectedFactoryId!,
      orderId: orderId,
      userId: user.uid,
      items: _items,
    );
  }
}


      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_saved'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final currencyFormat = NumberFormat.currency(locale: 'ar', symbol: 'ج.م');
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('new_purchase_order'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    debugPrint('📦 building main UI');
    debugPrint('📦 companies length: ${_companies.length}');

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _submitOrder),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCompanyDropdown(),
              const SizedBox(height: 16),
              if (_selectedCompanyId != null) _buildFactoryDropdown(),
              const SizedBox(height: 16),
              _buildSupplierDropdown(),
              const SizedBox(height: 16),
              ListTile(
                title: Text('order_date'.tr()),
                subtitle: Text(DateFormat.yMd().format(_orderDate)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _orderDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null && mounted) setState(() => _orderDate = d);
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _taxRate.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'tax_rate_percent'.tr(),
                  suffixText: '%',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final rate = double.tryParse(v) ?? _taxRate;
                  setState(() => _taxRate = rate);
                },
              ),
              const SizedBox(height: 24),

              // Switch للتحكم بحالة التسليم
              SwitchListTile(
                  title: Text('delivered'.tr()),
                  value: _isDelivered,
                  onChanged: (val) {
                    setState(() {
                      _isDelivered = val;
                    });
                  }),

              // عرض الأصناف المضافة
              _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'no_items_added_to_order'.tr(),
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];

                        return Card(
                          color: Colors.grey[100],
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // اسم الصنف
                                Text(
                                  context.locale.languageCode == 'ar'
                                      ? item.nameAr
                                      : item.nameEn,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // الكمية والسعر في صف واحد
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item.quantity.toString(),
                                        decoration: InputDecoration(
                                          labelText: 'quantity'.tr(),
                                          border: const OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (v) {
                                          final newQty = double.tryParse(v) ??
                                              item.quantity;
                                          setState(() {
                                            _items[index] = item
                                                .updateQuantity(newQty)
                                                .updateTaxStatus(
                                                    item.isTaxable,
                                                    item.isTaxable
                                                        ? _taxRate
                                                        : 0);
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            item.unitPrice.toStringAsFixed(2),
                                        decoration: InputDecoration(
                                          labelText: 'unit_price'.tr(),
                                          border: const OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (v) {
                                          final newPrice = double.tryParse(v) ??
                                              item.unitPrice;
                                          setState(() {
                                            _items[index] = item
                                                .updateUnitPrice(newPrice)
                                                .updateTaxStatus(
                                                    item.isTaxable,
                                                    item.isTaxable
                                                        ? _taxRate
                                                        : 0);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // مفتاح هل خاضع للضريبة
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('is_taxable'.tr()),
                                  value: item.isTaxable,
                                  onChanged: (val) {
                                    setState(() {
                                      _items[index] = item.updateTaxStatus(
                                          val, val ? _taxRate : 0);
                                    });
                                  },
                                ),

                                const Divider(),

                                // تفاصيل المبلغ
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${'tax'.tr()}:'),
                                    Text(currencyFormat.format(item.taxAmount)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${'total'.tr()}:',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                      currencyFormat
                                          .format(item.totalAfterTaxAmount),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('add_items'.tr()),
                onPressed: _showItemSelectionDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



  // تعديل الكمية والسعر للوحدة في الأصناف
/*   void _editItemQuantityAndPrice(int index) async {
    final item = _items[index];
    double newQuantity = item.quantity;
    double newUnitPrice = item.unitPrice;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('edit_item'.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: item.quantity.toString(),
                  decoration: InputDecoration(labelText: 'quantity'.tr()),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'required_field'.tr();
                    if (double.tryParse(v) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                  onChanged: (v) {
                    newQuantity = double.tryParse(v) ?? newQuantity;
                  },
                ),
                TextFormField(
                  initialValue: item.unitPrice.toString(),
                  decoration: InputDecoration(labelText: 'unit_price'.tr()),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'required_field'.tr();
                    if (double.tryParse(v) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                  onChanged: (v) {
                    newUnitPrice = double.tryParse(v) ?? newUnitPrice;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: Text('save'.tr()),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        var updatedItem = item.updateQuantity(newQuantity);
        updatedItem = updatedItem.updateUnitPrice(newUnitPrice);
        _items[index] = updatedItem;
      });
    }
  }
 */

/*   void _editItemQuantityAndPrice(int index) async {
    final item = _items[index];
    double newQuantity = item.quantity;
    double newUnitPrice = item.unitPrice;
    bool isTaxable = item.isTaxable;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('edit_item'.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: item.quantity.toString(),
                  decoration: InputDecoration(labelText: 'quantity'.tr()),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'required_field'.tr();
                    if (double.tryParse(v) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                  onChanged: (v) {
                    newQuantity = double.tryParse(v) ?? newQuantity;
                  },
                ),
                TextFormField(
                  initialValue: item.unitPrice.toString(),
                  decoration: InputDecoration(labelText: 'unit_price'.tr()),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'required_field'.tr();
                    if (double.tryParse(v) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                  onChanged: (v) {
                    newUnitPrice = double.tryParse(v) ?? newUnitPrice;
                  },
                ),
                CheckboxListTile(
                  title: Text('is_taxable'.tr()),
                  value: isTaxable,
                  onChanged: (val) {
                    if (val != null) isTaxable = val;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: Text('save'.tr()),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        var updatedItem = item
            .updateQuantity(newQuantity)
            .updateUnitPrice(newUnitPrice)
            .updateTaxStatus(isTaxable, isTaxable ? _taxRate : 0.0);
        _items[index] = updatedItem;
      });
    }
  }
 */


/*                         return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(
                              context.locale.languageCode == 'ar'
                                  ? item.nameAr
                                  : item.nameEn,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${'quantity'.tr()}: ${item.quantity}'),
                                Text(
                                    '${'unit_price'.tr()}: ${item.unitPrice.toStringAsFixed(2)}'),
                                Text(
                                    '${'tax'.tr()}: ${item.taxAmount.toStringAsFixed(2)}'),
                                Text(
                                    '${'total'.tr()}: ${item.totalAfterTaxAmount.toStringAsFixed(2)}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editItemQuantityAndPrice(index),
                            ),
                          ),
                        );
                    },  */ 
          //         import 'package:intl/intl.dart';

/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_scaffold.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String selectedCompany;
  final String? editOrderId;

  const AddPurchaseOrderPage({
    super.key,
    required this.selectedCompany,
    this.editOrderId,
  });

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemQtyController = TextEditingController();

  List<Map<String, dynamic>> items = [];
  String? factoryId;
  DateTime orderDate = DateTime.now();
  bool isLoading = false;
  List<Map<String, dynamic>> allFactories = [];

  @override
  void initState() {
    super.initState();
    _loadFactories();
    if (widget.editOrderId != null) {
      _loadExistingOrder();
    }
  }

  Future<void> _loadFactories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('companies/${widget.selectedCompany}/factories')
        .get();
    setState(() {
      allFactories =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  Future<void> _loadExistingOrder() async {
    final doc = await FirebaseFirestore.instance
        .collection('companies/${widget.selectedCompany}/purchase_orders')
        .doc(widget.editOrderId)
        .get();
    final data = doc.data();
    if (!mounted || data == null) return;

    setState(() {
      _supplierController.text = data['supplierName'] ?? '';
      items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => {'name': e['name'], 'qty': e['qty']})
          .toList();
      factoryId = (data['factoryIds'] as List<dynamic>?)?.cast<String>().first;
      final ts = data['createdAt'] as Timestamp?;
      if (ts != null) orderDate = ts.toDate();
    });
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final qty = int.tryParse(_itemQtyController.text.trim());
    if (name.isEmpty || qty == null || qty <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('invalid_item'.tr())));
      return;
    }
    setState(() {
      items.add({'name': name, 'qty': qty});
      _itemNameController.clear();
      _itemQtyController.clear();
    });
  }

  Future<void> _saveOrder() async {
    if (items.isEmpty || _supplierController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('missing_fields'.tr())));
      return;
    }

    setState(() => isLoading = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('companies/${widget.selectedCompany}/purchase_orders');
      final data = {
        'supplierName': _supplierController.text.trim(),
        'items': items,
        'factoryIds': factoryId != null ? [factoryId] : [],
        'createdAt': orderDate,
        'isConfirmed': false,
        'companyId': widget.selectedCompany,
      };

      if (widget.editOrderId != null) {
        await ref.doc(widget.editOrderId).update(data);
      } else {
        await ref.add(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_saved'.tr())));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'save_error'.tr()}: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.editOrderId != null
          ? 'edit_purchase_order'.tr()
          : 'new_purchase_order'.tr(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _supplierController,
                      decoration: InputDecoration(labelText: 'supplier'.tr()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _itemNameController,
                            decoration: InputDecoration(labelText: 'item'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _itemQtyController,
                            decoration: InputDecoration(labelText: 'qty'.tr()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addItem,
                          child: Text('add'.tr()),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      children: items
                          .map((e) => Chip(
                                label: Text('${e['name']} x${e['qty']}'),
                                onDeleted: () => setState(() {
                                  items.remove(e);
                                }),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: factoryId,
                      items: allFactories
                          .map((f) => DropdownMenuItem<String>(
                                value: f['id'],
                                child: Text(f['nameAr'] ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => factoryId = v),
                      decoration: InputDecoration(labelText: 'factory'.tr()),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(DateFormat('dd/MM/yyyy').format(orderDate)),
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: orderDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (selected != null && mounted) {
                          setState(() => orderDate = selected);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveOrder,
                      child: Text('save'.tr()),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
 */ /* 

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/pages/purchasing/item_selection_dialog.dart';
import 'package:puresip_purchasing/services/purchase_order_service.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  const AddPurchaseOrderPage({super.key, required String selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  double _taxRate = 14.0;
  List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  // أضف هذه المتغيرات هنا
  bool _isLoading = false;
  bool _isLoadingFactories = false;
  


  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

/*   Future<void> _loadInitialData() async {
    final user = await UserLocalStorage.getUser();
    if (user == null) return;

    // Load companies the user has access to
    final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
    if (companyIds.isNotEmpty) {
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: companyIds)
          .get();

      setState(() {
        _companies = companiesSnapshot.docs
            .map((doc) => Company.fromMap(doc.data(), doc.id))
            .toList();
        _selectedCompanyId = companyIds.first;
      });
    }

    // Load suppliers
    final suppliersSnapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where('userId', isEqualTo: user['userId'])
        .get();

    setState(() {
      _suppliers = suppliersSnapshot.docs
          .map((doc) => Supplier.fromMap(doc.data(), doc.id))
          .toList();
    });

    // Load all items
    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('userId', isEqualTo: user['userId'])
        .get();

    setState(() {
      _allItems = itemsSnapshot.docs
          .map((doc) => Item.fromMap(doc.data(), doc.id))
          .toList();
    });

    // Load factories if company is selected
    if (_selectedCompanyId != null) {
      await _loadFactoriesForCompany(_selectedCompanyId!);
    }
  } */



 Future<void> _loadInitialData() async {
  final user = await UserLocalStorage.getUser();
  if (user == null || !mounted) return;

  setState(() {
    _isLoading = true;
    _isLoadingFactories = true;
  });

  try {
    final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
    if (companyIds.isNotEmpty) {
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: companyIds)
          .get();

      setState(() {
        _companies = companiesSnapshot.docs
            .map((doc) => Company.fromMap(doc.data(), doc.id))
            .toList();
        _selectedCompanyId = _companies.isNotEmpty ? _companies.first.id : null;
      });

      if (_selectedCompanyId != null) {
        await _loadFactoriesForCompany(_selectedCompanyId!);
      }
    }

    final suppliersSnapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where('userId', isEqualTo: user['userId'])
        .get();

    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('userId', isEqualTo: user['userId'])
        .get();

    setState(() {
      _suppliers = suppliersSnapshot.docs
          .map((doc) => Supplier.fromMap(doc.data(), doc.id))
          .toList();
      _allItems = itemsSnapshot.docs
          .map((doc) => Item.fromMap(doc.data(), doc.id))
          .toList();
    });

  } catch (e) {
    debugPrint('Error in _loadInitialData: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_loading_data'.tr())),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingFactories = false;
      });
    }
  }
}

/* Future<void> _loadInitialData() async {
  final user = await UserLocalStorage.getUser();
  if (user == null || !mounted) return;

  setState(() {
     _isLoading = true;
    _isLoadingFactories = true;
  });

  try {
    // جلب الشركات المتاحة للمستخدم
    final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
    if (companyIds.isNotEmpty) {
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: companyIds)
          .get();

      setState(() {
        _companies = companiesSnapshot.docs
            .map((doc) => Company.fromMap(doc.data(), doc.id))
            .toList();
        
        // تحديد أول شركة تلقائيًا
        _selectedCompanyId = _companies.isNotEmpty ? _companies.first.id : null;
      });

      // إذا تم تحديد شركة، جلب المصانع الخاصة بها
      if (_selectedCompanyId != null) {
        await _loadFactoriesForCompany(_selectedCompanyId!);
        
        // تحديد أول مصنع تلقائيًا بعد التحميل
        if (_factories.isNotEmpty) {
          setState(() {
            _selectedFactoryId = _factories.first.id;
          });
        }
      }
    }

    // جلب الموردين والأصناف
    final suppliersSnapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where('userId', isEqualTo: user['userId'])
        .get();

    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('userId', isEqualTo: user['userId'])
        .get();

    setState(() {
      _suppliers = suppliersSnapshot.docs
          .map((doc) => Supplier.fromMap(doc.data(), doc.id))
          .toList();
      
      _allItems = itemsSnapshot.docs
          .map((doc) => Item.fromMap(doc.data(), doc.id))
          .toList();
    });

  } catch (e) {
    debugPrint('Error in _loadInitialData: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_loading_data'.tr())),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

 */

Future<void> _loadFactoriesForCompany(String companyId) async {
  if (!mounted) return;

  setState(() {
    _isLoadingFactories = true;
    _selectedFactoryId = null;
  });

  try {
    final factoriesSnapshot = await FirebaseFirestore.instance
        .collection('factories')
        .where('companyIds', arrayContains: companyId)
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .get();

    if (!mounted) return;

    setState(() {
      _factories = factoriesSnapshot.docs
          .map((doc) => Factory.fromMap(doc.data(), doc.id))
          .toList();
      
      if (_factories.isNotEmpty) {
        _selectedFactoryId = _factories.first.id;
      }
    });

  } catch (e) {
    debugPrint('Error loading factories: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_loading_factories'.tr())),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoadingFactories = false);
    }
  }
}

/* Future<void> _loadFactoriesForCompany(String companyId) async {
  if (!mounted) return;

  setState(() {
    _isLoadingFactories = true;
    _selectedFactoryId = null; // إعادة تعيين قبل التحميل
  });

  try {
    final factoriesSnapshot = await FirebaseFirestore.instance
        .collection('factories')
        .where('companyIds', arrayContains: companyId)
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .get();

    if (!mounted) return;

    setState(() {
      _factories = factoriesSnapshot.docs
          .map((doc) => Factory.fromMap(doc.data(), doc.id))
          .toList();
      
      // تحديد أول مصنع تلقائيًا إذا كان هناك مصانع
      if (_factories.isNotEmpty) {
        _selectedFactoryId = _factories.first.id;
      }
    });

  } catch (e) {
    debugPrint('Error loading factories: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_loading_factories'.tr())),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoadingFactories = false);
    }
  }
}
 */
/*   Future<void> _loadFactoriesForCompany(String companyId) async {
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final factoriesSnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .where('companyIds', arrayContains: companyId)
          .where('userId',
              isEqualTo: user.uid) // تأكد أن المصانع تخص المستخدم الحالي
          .get();

      debugPrint('Factories found: ${factoriesSnapshot.docs.length}');

      if (!mounted) return;

      setState(() {
        _factories = factoriesSnapshot.docs
            .map((doc) => Factory.fromMap(doc.data(), doc.id))
            .toList();
        _selectedFactoryId = null;
        debugPrint('🔄 Factories loaded: ${_factories.length}');
      });
    } catch (e) {
      debugPrint('🔥 Load factories error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('error_loading_factories'.tr()),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
 */
  /*  Future<void> _loadFactoriesForCompany(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('factories')
          .doc('9BP0afXOIhoGPIuIKDPV')
          .get();

      debugPrint('Factory doc: ${doc.data()}');
    } catch (e) {
      debugPrint('🔥 Doc fetch error: $e');
    }

    try {
      final factoriesSnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .where('companyIds', arrayContains: companyId)
          //  .doc('9BP0afXOIhoGPIuIKDPV')
          .get();

      debugPrint('Factories found: ${factoriesSnapshot.docs.length}');

      setState(() {
        _factories = factoriesSnapshot.docs
            .map((doc) => Factory.fromMap(doc.data(), doc.id))
            .toList();
        _selectedFactoryId = null; // Reset factory selection
        debugPrint('🔄 Factories loaded: ${_factories.length}');
      });
    } catch (e) {
      debugPrint('🔥 Load factories error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_loading_factories'.tr())),
      );
    }
  }
 */
  Future<void> _showItemSelectionDialog() async {
    final List<Item>? selectedItems = await showDialog<List<Item>>(
      context: context,
      builder: (context) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        // Add new items only (not already in the list)
        for (var item in selectedItems) {
          if (!_items.any((i) => i.itemId == item.id)) {
            _items.add(Item(
              itemId: item.id!,
              name: item.nameAr,
              quantity: 1,
              unit: item.unit,
              unitPrice: item.unitPrice ?? 0.0,
              totalPrice: item.unitPrice ?? 0.0,
              taxAmount: (item.unitPrice ?? 0.0) * (_taxRate / 100),
              totalAfterTaxAmount:
                  (item.unitPrice ?? 0.0) * (1 + _taxRate / 100),
            ));
          }
        }
      });
    }
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) return;

    setState(() {
      final item = _items[index];
      _items[index] = Item(
        itemId: item.itemId,
        name: item.name,
        quantity: newQuantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        totalPrice: item.unitPrice * newQuantity,
        taxAmount: (item.unitPrice * newQuantity) * (_taxRate / 100),
        totalAfterTaxAmount:
            (item.unitPrice * newQuantity) * (1 + _taxRate / 100),
      );
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0) return;

    setState(() {
      final item = _items[index];
      _items[index] = Item(
        itemId: item.itemId,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        unitPrice: newPrice,
        totalPrice: newPrice * item.quantity,
        taxAmount: (newPrice * item.quantity) * (_taxRate / 100),
        totalAfterTaxAmount: (newPrice * item.quantity) * (1 + _taxRate / 100),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _submitOrder() async {
    if (_selectedCompanyId == null ||
        _selectedSupplierId == null ||
        _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('missing_required_fields'.tr())),
      );
      return;
    }

    final order = PurchaseOrder(
      id: 'PO-${DateTime.now().millisecondsSinceEpoch}',
      userId: (await UserLocalStorage.getUser())?['userId'] ?? '',
      companyId: _selectedCompanyId!,
      factoryId: _selectedFactoryId,
      supplierId: _selectedSupplierId!,
      orderDate: _orderDate,
      status: 'pending',
      items: _items,
      taxRate: _taxRate,
      totalAmount: _items.fold(0.0, (sTotal, item) => sTotal + item.totalPrice),
      totalTax: _items.fold(0.0, (sTotal, item) => sTotal + item.taxAmount),
      totalAmountAfterTax:
          _items.fold(0.0, (sTotal, item) => sTotal + item.totalAfterTaxAmount),
      isDelivered: false,
    );

    try {
      await PurchaseOrderService.createPurchaseOrder(order);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('order_saved_successfully'.tr())),
      );
      Navigator.pop(context, true); // Return success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('save_order_error'.tr(args: [e.toString()]))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold(0.0, (sTotal, item) => sTotal + item.totalPrice);
    final totalTax =
        _items.fold(0.0, (sTotal, item) => sTotal + item.taxAmount);
    final totalAfterTax =
        _items.fold(0.0, (sTotal, item) => sTotal + item.totalAfterTaxAmount);
  if (_isLoading) {
    return const Center(child: CircularProgressIndicator());
  }
    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitOrder,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Company Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCompanyId,
                items: _companies.map((company) {
                  return DropdownMenuItem(
                    value: company.id,
                    child: Text(company.nameAr),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;
    
    setState(() {
      _selectedCompanyId = value;
      _selectedFactoryId = null; // إعادة تعيين المصنع
    });
    
    await _loadFactoriesForCompany(value);
/*                   setState(() {
                    _selectedCompanyId = value;
                    _selectedFactoryId = null;
                    _factories = [];
                  });
                  if (value != null) {
                    _loadFactoriesForCompany(value);
                  } */
                },
                decoration: InputDecoration(
                  labelText: 'company'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'required_field'.tr();
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Factory Dropdown (only if company is selected)
              if (_selectedCompanyId != null)
                DropdownButtonFormField<String>(
                  value: _selectedFactoryId,
                  items: _factories.map((factory) {
                    return DropdownMenuItem(
                      value: factory.id,
                      child: Text(factory.nameAr),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFactoryId = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'factory'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),

              const SizedBox(height: 16),

              // Supplier Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSupplierId,
                items: _suppliers.map((supplier) {
                  return DropdownMenuItem(
                    value: supplier.id,
                    child: Text('${supplier.name} - ${supplier.company}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSupplierId = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'supplier'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'required_field'.tr();
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date Picker
              ListTile(
                title: Text('order_date'.tr()),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_orderDate)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: _orderDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selectedDate != null) {
                      setState(() {
                        _orderDate = selectedDate;
                      });
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Tax Rate
              TextFormField(
                initialValue: _taxRate.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'tax_rate_percent'.tr(),
                  border: const OutlineInputBorder(),
                  suffixText: '%',
                ),
                onChanged: (value) {
                  final newRate = double.tryParse(value) ?? _taxRate;
                  setState(() {
                    _taxRate = newRate;
                    // Update all items with new tax rate
                    _items = _items.map((item) {
                      return Item(
                        itemId: item.itemId,
                        name: item.name,
                        quantity: item.quantity,
                        unit: item.unit,
                        unitPrice: item.unitPrice,
                        totalPrice: item.unitPrice * item.quantity,
                        taxAmount:
                            (item.unitPrice * item.quantity) * (_taxRate / 100),
                        totalAfterTaxAmount: (item.unitPrice * item.quantity) *
                            (1 + _taxRate / 100),
                      );
                    }).toList();
                  });
                },
              ),

              const SizedBox(height: 24),

              // Items Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'items'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ElevatedButton.icon(
                    onPressed: _showItemSelectionDialog,
                    icon: const Icon(Icons.add),
                    label: Text('add_items'.tr()),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Items List
              if (_items.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'no_items_added'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
                )
              else
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(item.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item.quantity.toString(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'quantity'.tr(),
                                          border: const OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          final qty = double.tryParse(value) ??
                                              item.quantity;
                                          _updateItemQuantity(index, qty);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(item.unit),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue:
                                      item.unitPrice.toStringAsFixed(2),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'unit_price'.tr(),
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    final price = double.tryParse(value) ??
                                        item.unitPrice;
                                    _updateItemPrice(index, price);
                                  },
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${item.totalAfterTaxAmount.toStringAsFixed(2)} ${'currency'.tr()}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '(${item.taxAmount.toStringAsFixed(2)} ${'tax'.tr()})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // Order Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'order_summary'.tr(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildSummaryRow('subtotal'.tr(), total),
                      _buildSummaryRow('tax'.tr(), totalTax),
                      _buildSummaryRow(
                        'total'.tr(),
                        totalAfterTax,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Save Button
              ElevatedButton(
                onPressed: _submitOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('save_order'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '${value.toStringAsFixed(2)} ${'currency'.tr()}',
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
 */
/* 

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import './item_selection_dialog.dart';
import '../../services/purchase_order_service.dart';
import '../../utils/user_local_storage.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String selectedCompany;
  const AddPurchaseOrderPage({super.key, required this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _purchaseOrderService = PurchaseOrderService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  double _taxRate = 14.0;
  List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false; // تتبع حالة التسليم

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final user = await UserLocalStorage.getUser();
      if (user == null) return;

      await Future.wait([
        _loadCompanies(user),
        _loadSuppliers(user),
        _loadItems(user),
      ]);

      if (_selectedCompanyId != null) {
        await _loadFactoriesForCompany(_selectedCompanyId!);
      }
    } catch (e) {
      _showErrorSnackbar('error_loading_data'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCompanies(Map<String, dynamic> user) async {
    final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
    if (companyIds.isEmpty) return;

    final snapshot = await _firestore
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds)
        .get();

    if (!mounted) return;
    
    setState(() {
      _companies = snapshot.docs
          .map((doc) => Company.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> _loadSuppliers(Map<String, dynamic> user) async {
    final snapshot = await _firestore
        .collection('vendors')
        .where('userId', isEqualTo: user['userId'])
        .get();

    if (!mounted) return;
    
    setState(() {
      _suppliers = snapshot.docs
          .map((doc) => Supplier.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> _loadItems(Map<String, dynamic> user) async {
    final snapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: user['userId'])
        .get();

    if (!mounted) return;
    
    setState(() {
      _allItems = snapshot.docs
          .map((doc) => Item.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> _loadFactoriesForCompany(String companyId) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _factories = [];
      _selectedFactoryId = null;
    });

    try {
      final snapshot = await _firestore
          .collection('factories')
          .where('companyIds', arrayContains: companyId)
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .get();

      if (!mounted) return;
      
      setState(() {
        _factories = snapshot.docs
            .map((doc) => Factory.fromMap(doc.data(), doc.id))
            .toList();
        
        if (_factories.isNotEmpty) {
          _selectedFactoryId = _factories.first.id;
        }
      });
    } catch (e) {
      _showErrorSnackbar('error_loading_factories'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showItemSelectionDialog() async {
    final selectedItems = await showDialog<List<Item>>(
      context: context,
      builder: (context) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
      ),
    );

    if (selectedItems == null || selectedItems.isEmpty) return;

    setState(() {
      for (var item in selectedItems) {
        if (!_items.any((i) => i.itemId == item.id)) {
          _items.add(_createItem(item));
        }
      }
    });
  }

  Item _createItem(Item item) {
    return Item(
      itemId: item.id!,
      name: item.nameAr,
      quantity: 1,
      unit: item.unit,
      unitPrice: item.unitPrice ?? 0.0,
      totalPrice: item.unitPrice ?? 0.0,
      taxAmount: (item.unitPrice ?? 0.0) * (_taxRate / 100),
      totalAfterTaxAmount: (item.unitPrice ?? 0.0) * (1 + _taxRate / 100),
    );
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0 || newQuantity.isNaN) return;

    setState(() {
      _items[index] = _items[index].copyWith(
        quantity: newQuantity,
        totalPrice: _items[index].unitPrice * newQuantity,
      );
      _updateItemTax(index);
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0 || newPrice.isNaN) return;

    setState(() {
      _items[index] = _items[index].copyWith(
        unitPrice: newPrice,
        totalPrice: newPrice * _items[index].quantity,
      );
      _updateItemTax(index);
    });
  }

  void _updateItemTax(int index) {
    final item = _items[index];
    setState(() {
      _items[index] = item.copyWith(
        taxAmount: item.totalPrice * (_taxRate / 100),
        totalAfterTaxAmount: item.totalPrice * (1 + _taxRate / 100),
      );
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _submitOrder() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final order = _createPurchaseOrder();
      await PurchaseOrderService.createPurchaseOrder(order);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('order_saved_successfully'.tr())),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_selectedCompanyId == null || 
        _selectedSupplierId == null || 
        _items.isEmpty) {
      _showErrorSnackbar('missing_required_fields'.tr());
      return false;
    }
    return true;
  }

  PurchaseOrder _createPurchaseOrder() {
    return PurchaseOrder(
      id: 'PO-${DateTime.now().millisecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? '',
      companyId: _selectedCompanyId!,
      factoryId: _selectedFactoryId,
      supplierId: _selectedSupplierId!,
      orderDate: _orderDate,
      status: 'pending',
      items: _items,
      taxRate: _taxRate,
      totalAmount: _calculateTotal(),
      totalTax: _calculateTotalTax(),
      totalAmountAfterTax: _calculateTotalAfterTax(),
      isDelivered: _isDelivered, // تضمين حالة التسليم
    );
  }

  double _calculateTotal() => _items.fold(0.0, (sTotal, item) => sTotal + item.totalPrice);
  double _calculateTotalTax() => _items.fold(0.0, (sTotal, item) => sTotal + item.taxAmount);
  double _calculateTotalAfterTax() => _items.fold(0.0, (sTotal, item) => sTotal + item.totalAfterTaxAmount);

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectOrderDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (selectedDate != null && mounted) {
      setState(() => _orderDate = selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitOrder,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCompanyDropdown(),
              const SizedBox(height: 16),
              if (_selectedCompanyId != null) _buildFactoryDropdown(),
              const SizedBox(height: 16),
              _buildSupplierDropdown(),
              const SizedBox(height: 16),
              _buildDatePicker(),
              const SizedBox(height: 16),
              _buildTaxRateField(),
              const SizedBox(height: 16),
              _buildDeliveryStatusToggle(),
              const SizedBox(height: 24),
              _buildItemsSection(),
              const SizedBox(height: 24),
              _buildOrderSummary(),
              const SizedBox(height: 16),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCompanyId,
      items: _companies.map((company) {
        return DropdownMenuItem(
          value: company.id,
          child: Text(company.nameAr),
        );
      }).toList(),
      onChanged: (value) async {
        if (value == null) return;
        setState(() => _selectedCompanyId = value);
        await _loadFactoriesForCompany(value);
      },
      decoration: InputDecoration(
        labelText: 'company'.tr(),
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFactoryId,
      items: _factories.map((factory) {
        return DropdownMenuItem(
          value: factory.id,
          child: Text(factory.nameAr),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedFactoryId = value),
      decoration: InputDecoration(
        labelText: 'factory'.tr(),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSupplierId,
      items: _suppliers.map((supplier) {
        return DropdownMenuItem(
          value: supplier.id,
          child: Text('${supplier.name} - ${supplier.company}'),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedSupplierId = value),
      decoration: InputDecoration(
        labelText: 'supplier'.tr(),
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text('order_date'.tr()),
      subtitle: Text(DateFormat.yMd().format(_orderDate)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: _selectOrderDate,
      ),
    );
  }

  Widget _buildTaxRateField() {
    return TextFormField(
      initialValue: _taxRate.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'tax_rate_percent'.tr(),
        border: const OutlineInputBorder(),
        suffixText: '%',
      ),
      onChanged: (value) {
        final newRate = double.tryParse(value) ?? _taxRate;
        setState(() {
          _taxRate = newRate;
          _updateAllItemsTax();
        });
      },
    );
  }

  Widget _buildDeliveryStatusToggle() {
    return SwitchListTile(
      title: Text('delivered'.tr()),
      value: _isDelivered,
      onChanged: (value) => setState(() => _isDelivered = value),
    );
  }

  void _updateAllItemsTax() {
    setState(() {
      _items = _items.map((item) => item.copyWith(
        taxAmount: item.totalPrice * (_taxRate / 100),
        totalAfterTaxAmount: item.totalPrice * (1 + _taxRate / 100),
      )).toList();
    });
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'items'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ElevatedButton.icon(
              onPressed: _showItemSelectionDialog,
              icon: const Icon(Icons.add),
              label: Text('add_items'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _items.isEmpty 
            ? _buildNoItemsCard()
            : _buildItemsList(),
      ],
    );
  }

  Widget _buildNoItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'no_items_added'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildItemCard(index),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              title: Text(item.name),
              subtitle: _buildItemControls(index, item),
              trailing: _buildItemPriceInfo(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemControls(int index, Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: item.quantity.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'quantity'.tr(),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final qty = double.tryParse(value) ?? item.quantity;
                  _updateItemQuantity(index, qty);
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(item.unit),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: item.unitPrice.toStringAsFixed(2),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'unit_price'.tr(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            final price = double.tryParse(value) ?? item.unitPrice;
            _updateItemPrice(index, price);
          },
        ),
      ],
    );
  }

  Widget _buildItemPriceInfo(Item item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${item.totalAfterTaxAmount.toStringAsFixed(2)} ${'currency'.tr()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '(${item.taxAmount.toStringAsFixed(2)} ${'tax'.tr()})',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'order_summary'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), _calculateTotal()),
            _buildSummaryRow('tax'.tr(), _calculateTotalTax()),
            _buildSummaryRow(
              'total'.tr(),
              _calculateTotalAfterTax(),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '${value.toStringAsFixed(2)} ${'currency'.tr()}',
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitOrder,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text('save_order'.tr()),
    );
  }
} */
/* 

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import './item_selection_dialog.dart';
import '../../services/firestore_service.dart';
import '../../utils/user_local_storage.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String selectedCompany;
  const AddPurchaseOrderPage({super.key, required this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _purchaseOrderService = FirestoreService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  double _taxRate = 14.0;
  List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false;

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = await UserLocalStorage.getUser();
      if (user == null) return;

      await Future.wait([
        _loadCompanies(user),
        _loadSuppliers(user),
        _loadItems(user),
      ]);

      if (_selectedCompanyId != null) {
        await _loadFactoriesForCompany(_selectedCompanyId!);
      }
    } catch (e) {
      _showErrorSnackbar('error_loading_data'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCompanies(Map<String, dynamic> user) async {
    final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
    if (companyIds.isEmpty) return;

    final snapshot = await _firestore
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds)
        .get();

    if (!mounted) return;

    setState(() {
      _companies = snapshot.docs
          .map((doc) => Company.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> _loadSuppliers(Map<String, dynamic> user) async {
    final snapshot = await _firestore
        .collection('vendors')
        .where('userId', isEqualTo: user['userId'])
        .get();

    if (!mounted) return;

    setState(() {
      _suppliers = snapshot.docs
          .map((doc) => Supplier.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> _loadItems(Map<String, dynamic> user) async {
    final snapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: user['userId'])
        .get();

    if (!mounted) return;

    setState(() {
      _allItems =
          snapshot.docs.map((doc) => Item.fromMap(doc.data())).toList();
    });
  }

  Future<void> _loadFactoriesForCompany(String companyId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _factories = [];
      _selectedFactoryId = null;
    });

    try {
      final snapshot = await _firestore
          .collection('factories')
          .where('companyIds', arrayContains: companyId)
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _factories = snapshot.docs
            .map((doc) => Factory.fromMap(doc.data(), doc.id))
            .toList();

        if (_factories.isNotEmpty) {
          _selectedFactoryId = _factories.first.id;
        }
      });
    } catch (e) {
      _showErrorSnackbar('error_loading_factories'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showItemSelectionDialog() async {
    final selectedItems = await showDialog<List<Item>>(
      context: context,
      builder: (context) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
      ),
    );

    if (selectedItems == null || selectedItems.isEmpty) return;

    setState(() {
      for (var item in selectedItems) {
        if (!_items.any((i) => i.itemId == item.itemId)) {
          _items.add(_createItem(item));
        }
      }
    });
  }

  String generatePurchaseOrderNumber(String companyName, int count) {
    final now = DateTime.now();
    final yyMM = '${now.year % 100}${now.month.toString().padLeft(2, '0')}';
    final serial = (count + 1).toString().padLeft(4, '0');
    final safeCompany = companyName.replaceAll(' ', '').toUpperCase();
    return 'PO-$safeCompany-$yyMM$serial';
  }


  Item _createItem(Item item) {
    return Item.create(
      itemId: item.itemId!,
      nameAr: item.nameAr,
      nameEn: item.nameEn,
      quantity: 1,
      unit: item.unit,
      unitPrice: item.unitPrice ?? 0.0,
      isTaxable: item.isTaxable,
      taxRate: _taxRate,
    );
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0 || newQuantity.isNaN) return;

    setState(() {
      _items[index] = _items[index].updateQuantity(newQuantity);
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0 || newPrice.isNaN) return;

    setState(() {
      _items[index] = _items[index].updateUnitPrice(newPrice);
    });
  }

  void _updateItemTaxStatus(int index, bool isTaxable) {
    setState(() {
      _items[index] = _items[index].updateTaxStatus(
        isTaxable,
        isTaxable ? _taxRate : 0.0,
      );
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _submitOrder() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final order = _createPurchaseOrder();
      await _purchaseOrderService.createPurchaseOrder(order);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('order_saved_successfully'.tr())),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_selectedCompanyId == null ||
        _selectedSupplierId == null ||
        _items.isEmpty) {
      _showErrorSnackbar('missing_required_fields'.tr());
      return false;
    }
    return true;
  }

  PurchaseOrder _createPurchaseOrder() {
    return PurchaseOrder(
      id: 'PO-${DateTime.now().millisecondsSinceEpoch}',
    //  poNumber: generatedPoNumber,
      userId: _auth.currentUser?.uid ?? '',
      companyId: _selectedCompanyId!,
      factoryId: _selectedFactoryId,
      supplierId: _selectedSupplierId!,
      orderDate: _orderDate,
      status: 'pending',
      items: _items,
      taxRate: _taxRate,
      totalAmount: _calculateTotal(),
      totalTax: _calculateTotalTax(),
      totalAmountAfterTax: _calculateTotalAfterTax(),
      isDelivered: _isDelivered,
      
    );
  }

  double _calculateTotal() =>
      _items.fold(0.0, (sTotal, item) => sTotal + item.totalPrice);
  double _calculateTotalTax() =>
      _items.fold(0.0, (sTotal, item) => sTotal + item.taxAmount);
  double _calculateTotalAfterTax() =>
      _items.fold(0.0, (sTotal, item) => sTotal + item.totalAfterTaxAmount);

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectOrderDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null && mounted) {
      setState(() => _orderDate = selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitOrder,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCompanyDropdown(),
              const SizedBox(height: 16),
              if (_selectedCompanyId != null) _buildFactoryDropdown(),
              const SizedBox(height: 16),
              _buildSupplierDropdown(),
              const SizedBox(height: 16),
              _buildDatePicker(),
              const SizedBox(height: 16),
              _buildTaxRateField(),
              const SizedBox(height: 16),
              _buildDeliveryStatusToggle(),
              const SizedBox(height: 24),
              _buildItemsSection(),
              const SizedBox(height: 24),
              _buildOrderSummary(),
              const SizedBox(height: 16),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    return DropdownButtonFormField<String>(
      value: _companies.any((c) => c.id == _selectedCompanyId)
          ? _selectedCompanyId
          : null,
      items: _companies.map((company) {
        return DropdownMenuItem(
          value: company.id,
          child: Text(company.nameAr),
        );
      }).toList(),
      onChanged: (value) async {
        if (value == null) return;
        setState(() => _selectedCompanyId = value);
        await _loadFactoriesForCompany(value);
      },
      decoration: InputDecoration(
        labelText: 'company'.tr(),
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _factories.any((f) => f.id == _selectedFactoryId)
          ? _selectedFactoryId
          : null,
      items: _factories.map((factory) {
        return DropdownMenuItem(
          value: factory.id,
          child: Text(factory.nameAr),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedFactoryId = value),
      decoration: InputDecoration(
        labelText: 'factory'.tr(),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _suppliers.any((s) => s.id == _selectedSupplierId)
          ? _selectedSupplierId
          : null,
      items: _suppliers.map((supplier) {
        return DropdownMenuItem(
          value: supplier.id,
          child: Text('${supplier.name} - ${supplier.company}'),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedSupplierId = value),
      decoration: InputDecoration(
        labelText: 'supplier'.tr(),
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text('order_date'.tr()),
      subtitle: Text(DateFormat.yMd().format(_orderDate)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: _selectOrderDate,
      ),
    );
  }

  Widget _buildTaxRateField() {
    return TextFormField(
      initialValue: _taxRate.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'tax_rate_percent'.tr(),
        border: const OutlineInputBorder(),
        suffixText: '%',
      ),
      onChanged: (value) {
        final newRate = double.tryParse(value) ?? _taxRate;
        setState(() {
          _taxRate = newRate;
          _updateAllItemsTax();
        });
      },
    );
  }

  Widget _buildDeliveryStatusToggle() {
    return SwitchListTile(
      title: Text('delivered'.tr()),
      value: _isDelivered,
      onChanged: (value) => setState(() => _isDelivered = value),
    );
  }

  void _updateAllItemsTax() {
    setState(() {
      _items = _items
          .map((item) => item.updateTaxStatus(
                item.isTaxable,
                item.isTaxable ? _taxRate : 0.0,
              ))
          .toList();
    });
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'items'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ElevatedButton.icon(
              onPressed: _showItemSelectionDialog,
              icon: const Icon(Icons.add),
              label: Text('add_items'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _items.isEmpty ? _buildNoItemsCard() : _buildItemsList(),
      ],
    );
  }

  Widget _buildNoItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'no_items_added'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildItemCard(index),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              title: Text(context.locale.languageCode == 'ar' ? item.nameAr : item.nameEn),
              subtitle: _buildItemControls(index, item),
              trailing: _buildItemPriceInfo(item),
            ),
            SwitchListTile(
              title: Text('apply_tax'.tr()),
              value: item.isTaxable,
              onChanged: (value) => _updateItemTaxStatus(index, value),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemControls(int index, Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: item.quantity.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'quantity'.tr(),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final qty = double.tryParse(value) ?? item.quantity;
                  _updateItemQuantity(index, qty);
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(item.unit),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: item.unitPrice.toStringAsFixed(2),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'unit_price'.tr(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            final price = double.tryParse(value) ?? item.unitPrice;
            _updateItemPrice(index, price);
          },
        ),
      ],
    );
  }

  Widget _buildItemPriceInfo(Item item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${item.totalAfterTaxAmount.toStringAsFixed(2)} ${'currency'.tr()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '(${item.taxAmount.toStringAsFixed(2)} ${'tax'.tr()})',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'order_summary'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), _calculateTotal()),
            _buildSummaryRow('tax'.tr(), _calculateTotalTax()),
            _buildSummaryRow(
              'total'.tr(),
              _calculateTotalAfterTax(),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '${value.toStringAsFixed(2)} ${'currency'.tr()}',
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitOrder,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text('save_order'.tr()),
    );
  }
}


 */

/* 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import './item_selection_dialog.dart';
import '../../services/firestore_service.dart';
import '../../utils/user_local_storage.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String selectedCompany;
  const AddPurchaseOrderPage({super.key, required this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  double _taxRate = 14.0;
  List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false;

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = await UserLocalStorage.getUser();
      if (user == null) return;

      await Future.wait([
        _loadCompanies(user),
        _loadSuppliers(user),
        _loadItems(user),
      ]);

      if (_selectedCompanyId != null) {
        await _loadFactoriesForCompany(_selectedCompanyId!);
      }
    } catch (e) {
      _showErrorSnackbar('error_loading_data'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    debugPrint('Initial data loaded: '
        'Companies: ${_companies.length}, '
        'Suppliers: ${_suppliers.length}, '
        'Items: ${_allItems.length}, '
        'Factories: ${_factories.length}');
  }

  Future<void> _loadCompanies(Map<String, dynamic> user) async {
    final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
    if (companyIds.isEmpty) return;

    final docs = await _firestoreService.getCollection(
      collectionPath: 'companies',
      userId: user['userId'],
    );
    debugPrint('Loaded companies: ${docs.length}');

    if (!mounted) return;

    setState(() {
      _companies = docs
          .map((doc) =>
              Company.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
    debugPrint('Loaded companies: ${_companies.length}');
  }

  Future<void> _loadSuppliers(Map<String, dynamic> user) async {
    final docs = await _firestoreService.getCollection(
      collectionPath: 'vendors',
      userId: user['userId'],
    );

    if (!mounted) return;

    setState(() {
      _suppliers = docs
          .map((doc) =>
              Supplier.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<void> _loadItems(Map<String, dynamic> user) async {
    final docs = await _firestoreService.getCollection(
      collectionPath: 'items',
      userId: user['userId'],
    );

    if (!mounted) return;

    setState(() {
      _allItems = docs
          .map((doc) => Item.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _loadFactoriesForCompany(String companyId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _factories = [];
      _selectedFactoryId = null;
    });

    try {
      final user = await UserLocalStorage.getUser();
      if (user == null) return;

      final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      final factories = await _firestoreService
          .getUserFactories(
            user['userId'],
            companyIds,
          )
          .first;

      if (!mounted) return;

      setState(() {
        _factories =
            factories.where((f) => f.companyIds.contains(companyId)).toList();
        if (_factories.isNotEmpty) {
          _selectedFactoryId = _factories.first.id;
        }
      });
    } catch (e) {
      _showErrorSnackbar('error_loading_factories'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showItemSelectionDialog() async {
    final selectedItems = await showDialog<List<Item>>(
      context: context,
      builder: (context) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
      ),
    );

    if (selectedItems == null || selectedItems.isEmpty) return;

    setState(() {
      for (var item in selectedItems) {
        if (!_items.any((i) => i.itemId == item.itemId)) {
          _items.add(_createItem(item));
        }
      }
    });
  }

  Item _createItem(Item item) {
    return Item.create(
      itemId: item.itemId,
      nameAr: item.nameAr,
      nameEn: item.nameEn,
      quantity: 1,
      unit: item.unit,
      unitPrice: item.unitPrice,
      isTaxable: item.isTaxable,
      taxRate: _taxRate,
      category: item.category,
      description: item.description,
    );
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0 || newQuantity.isNaN) return;

    setState(() {
      _items[index] = _items[index].updateQuantity(newQuantity);
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0 || newPrice.isNaN) return;

    setState(() {
      _items[index] = _items[index].updateUnitPrice(newPrice);
    });
  }

  void _updateItemTaxStatus(int index, bool isTaxable) {
    setState(() {
      _items[index] = _items[index].updateTaxStatus(
        isTaxable,
        isTaxable ? _taxRate : 0.0,
      );
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _submitOrder() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final order = _createPurchaseOrder();
      await _firestoreService.createPurchaseOrder(order);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('order_saved_successfully'.tr())),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_selectedCompanyId == null ||
        _selectedSupplierId == null ||
        _items.isEmpty) {
      _showErrorSnackbar('missing_required_fields'.tr());
      return false;
    }
    return true;
  }

  PurchaseOrder _createPurchaseOrder() {
    return PurchaseOrder(
      id: '', // سيتم تعبئته تلقائياً في FirestoreService
      poNumber: '', // سيتم توليده تلقائياً
      userId: _auth.currentUser?.uid ?? '',
      companyId: _selectedCompanyId!,
      factoryId: _selectedFactoryId,
      supplierId: _selectedSupplierId!,
      orderDate: _orderDate,
      status: 'pending',
      items: _items,
      taxRate: _taxRate,
      totalAmount: _calculateTotal(),
      totalTax: _calculateTotalTax(),
      totalAmountAfterTax: _calculateTotalAfterTax(),
      isDelivered: _isDelivered,
    );
  }

  double _calculateTotal() =>
      _items.fold(0.0, (sTotal, item) => sTotal + item.totalPrice);

  double _calculateTotalTax() =>
      _items.fold(0.0, (sTotal, item) => sTotal + item.taxAmount);

  double _calculateTotalAfterTax() =>
      _items.fold(0.0, (sTotal, item) => sTotal + item.totalAfterTaxAmount);

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectOrderDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null && mounted) {
      setState(() => _orderDate = selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitOrder,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCompanyDropdown(),
              const SizedBox(height: 16),
              if (_selectedCompanyId != null) _buildFactoryDropdown(),
              const SizedBox(height: 16),
              _buildSupplierDropdown(),
              const SizedBox(height: 16),
              _buildDatePicker(),
              const SizedBox(height: 16),
              _buildTaxRateField(),
              const SizedBox(height: 16),
              _buildDeliveryStatusToggle(),
              const SizedBox(height: 24),
              _buildItemsSection(),
              const SizedBox(height: 24),
              _buildOrderSummary(),
              const SizedBox(height: 16),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // باقي دوال بناء الواجهة تبقى كما هي بدون تغيير
  Widget _buildCompanyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCompanyId,
      items: _companies.map((company) {
        return DropdownMenuItem(
          value: company.id,
          child: Text(company.nameAr),
        );
      }).toList(),
      onChanged: (value) async {
        if (value == null) return;
        setState(() => _selectedCompanyId = value);
        await _loadFactoriesForCompany(value);
         debugPrint('Loaded companies: ${_companies.length}');
      },
      decoration: InputDecoration(
        labelText: 'company'.tr(),
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'required_field'.tr() : null,
      
    );
   
  }

  Widget _buildFactoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFactoryId,
      items: _factories.map((factory) {
        return DropdownMenuItem(
          value: factory.id,
          child: Text(factory.nameAr),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedFactoryId = value),
      decoration: InputDecoration(
        labelText: 'factory'.tr(),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSupplierId,
      items: _suppliers.map((supplier) {
        return DropdownMenuItem(
          value: supplier.id,
          child: Text('${supplier.nameAr} - ${supplier.nameEn}'),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedSupplierId = value),
      decoration: InputDecoration(
        labelText: 'supplier'.tr(),
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text('order_date'.tr()),
      subtitle: Text(DateFormat.yMd().format(_orderDate)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: _selectOrderDate,
      ),
    );
  }

  Widget _buildTaxRateField() {
    return TextFormField(
      initialValue: _taxRate.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'tax_rate_percent'.tr(),
        border: const OutlineInputBorder(),
        suffixText: '%',
      ),
      onChanged: (value) {
        final newRate = double.tryParse(value) ?? _taxRate;
        setState(() {
          _taxRate = newRate;
          _updateAllItemsTax();
        });
      },
    );
  }

  Widget _buildDeliveryStatusToggle() {
    return SwitchListTile(
      title: Text('delivered'.tr()),
      value: _isDelivered,
      onChanged: (value) => setState(() => _isDelivered = value),
    );
  }

  void _updateAllItemsTax() {
    setState(() {
      _items = _items
          .map((item) => item.updateTaxStatus(
                item.isTaxable,
                item.isTaxable ? _taxRate : 0.0,
              ))
          .toList();
    });
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'items'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ElevatedButton.icon(
              onPressed: _showItemSelectionDialog,
              icon: const Icon(Icons.add),
              label: Text('add_items'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _items.isEmpty ? _buildNoItemsCard() : _buildItemsList(),
      ],
    );
  }

  Widget _buildNoItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'no_items_added'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildItemCard(index),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              title: Text(context.locale.languageCode == 'ar'
                  ? item.nameAr
                  : item.nameEn),
              subtitle: _buildItemControls(index, item),
              trailing: _buildItemPriceInfo(item),
            ),
            SwitchListTile(
              title: Text('apply_tax'.tr()),
              value: item.isTaxable,
              onChanged: (value) => _updateItemTaxStatus(index, value),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemControls(int index, Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: item.quantity.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'quantity'.tr(),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final qty = double.tryParse(value) ?? item.quantity;
                  _updateItemQuantity(index, qty);
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(item.unit),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: item.unitPrice.toStringAsFixed(2),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'unit_price'.tr(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            final price = double.tryParse(value) ?? item.unitPrice;
            _updateItemPrice(index, price);
          },
        ),
      ],
    );
  }

  Widget _buildItemPriceInfo(Item item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${item.totalAfterTaxAmount.toStringAsFixed(2)} ${'currency'.tr()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '(${item.taxAmount.toStringAsFixed(2)} ${'tax'.tr()})',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'order_summary'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), _calculateTotal()),
            _buildSummaryRow('tax'.tr(), _calculateTotalTax()),
            _buildSummaryRow(
              'total'.tr(),
              _calculateTotalAfterTax(),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '${value.toStringAsFixed(2)} ${'currency'.tr()}',
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitOrder,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text('save_order'.tr()),
    );
  }
}
 */

/* 
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = await UserLocalStorage.getUser();
      final userIdX = user?['userId'];
      debugPrint('🚀 userId: $userIdX');
      if (user == null) return;

      final userId = user['userId'] as String;
      final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      debugPrint('🚀 companyIds: $companyIds');
      if (companyIds.isEmpty) return;

      // تحميل البيانات حسب الهيكل الصحيح
      final companies = await _firestoreService.getUserCompanies(companyIds);
      debugPrint('✅ Loaded companies count: ${companies.length}');

      final suppliers = await _firestoreService.getUserVendors(userId); // ✅
      final items = await _firestoreService.getUserItems(companyIds); // ✅

      List<Factory> factories = [];
      if (_selectedCompanyId != null) {
        factories = await _firestoreService
            .getUserFactories(userId, companyIds) // ✅ هذا يرجع Stream
            .first; // ✅ أخذ أول نتيجة من الـ Stream
            debugPrint('✅ Loaded factories count: ${factories.length}');
      }

      if (!mounted) return;
      setState(() {
        _companies = companies;
        _suppliers = suppliers;
        _allItems = items;
        _factories = factories;

        if (_factories.isNotEmpty && _selectedFactoryId == null) {
          _selectedFactoryId = _factories.first.id;
        }
      });

      debugPrint('User data: $user');
      debugPrint('Company IDs: $companyIds');
      debugPrint('Companies count: ${companies.length}');
      debugPrint('Suppliers count: ${suppliers.length}');
      debugPrint('Items count: ${items.length}');
    } catch (e) {
      _showErrorSnackbar('error_loading_data'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
 */

/* Future<void> _loadInitialData() async {
  setState(() => _isLoading = true);
  try {
    final user = await UserLocalStorage.getUser();
    if (user == null) return;

    final userId = user['userId'] as String;
    final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
    if (companyIds.isEmpty) return;

    final companies = await _firestoreService.getUserCompanies(companyIds);

    final suppliers = await _firestoreService.getUserVendors(userId);
    final items = await _firestoreService.getUserItems(companyIds);

    List<Factory> factories = [];
    if (_selectedCompanyId != null) {
      factories = await _firestoreService
          .getUserFactories(userId, companyIds)
          .first;
    }

    if (!mounted) return;

    setState(() {
      _companies = companies;
      _suppliers = suppliers;
      _allItems = items;
      _factories = factories;

      // تعيين الشركة المختارة إلى أول شركة إذا لم تكن موجودة أصلاً
      if (_companies.isNotEmpty &&
          (_selectedCompanyId == null ||
           !_companies.any((c) => c.id == _selectedCompanyId))) {
        _selectedCompanyId = _companies.first.id;
      }

      if (_factories.isNotEmpty && _selectedFactoryId == null) {
        _selectedFactoryId = _factories.first.id;
      }
    });

  } catch (e) {
    _showErrorSnackbar('error_loading_data'.tr());
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
*/

/* import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import '../../services/firestore_service.dart';
import '../../utils/user_local_storage.dart';
import './item_selection_dialog.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;
  const AddPurchaseOrderPage({super.key, this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  double _taxRate = 14.0;
  final List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  final bool _isDelivered = false;

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    debugPrint('⬇️ Start loading initial data...');
    setState(() => _isLoading = true);

    try {
      final user = await UserLocalStorage.getUser();
      debugPrint('🧑 user from storage: $user');

      if (user == null) {
        debugPrint('❌ User is null, stopping load.');
        setState(() => _isLoading = false);
        return;
      }

      final userId = user['userId'] as String;
      final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      debugPrint('🚀 userId: $userId');
      debugPrint('🚀 companyIds: $companyIds');
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Current Firebase userId: ${currentUser?.uid}');
      debugPrint('UserId from local storage: $userId');
      if (companyIds.isEmpty) {
        debugPrint('❌ companyIds is empty, stopping load.');
        setState(() => _isLoading = false);
        return;
      }

      final companies = await _firestoreService.getUserCompanies(companyIds);
      debugPrint('✅ Loaded companies count: ${companies.length}');

      final suppliers = await _firestoreService.getUserVendors(
        userId,
        (user['supplierIds'] as List?)?.cast<String>() ?? [],
      );

      debugPrint('✅ Loaded suppliers count: ${suppliers.length}'); 

//الكود يطبع حتى هنا فقط ...
//يتجاهل بعد ذلك
      final items = await _firestoreService.getUserItems(userId);
      debugPrint('✅ Loaded items count: ${items.length}'); // تطبع 0

      
      List<Factory> factories = [];
      if (_selectedCompanyId != null) {
        factories =
            await _firestoreService.getUserFactories(userId, companyIds).first;
        debugPrint('✅ Loaded factories count: ${factories.length}');
      }

      if (!mounted) return;

      setState(() {
        _companies = companies;
        _suppliers = suppliers;
        _allItems = items;
        _factories = factories;

        // تعيين الشركة المحددة إذا لم تكن موجودة أو غير معروفة
        if (_companies.isNotEmpty &&
            (_selectedCompanyId == null ||
                !_companies.any((c) => c.id == _selectedCompanyId))) {
          _selectedCompanyId = _companies.first.id;
          debugPrint(
              'ℹ️ _selectedCompanyId was reset to first company: $_selectedCompanyId');
        }

        if (_factories.isNotEmpty && _selectedFactoryId == null) {
          _selectedFactoryId = _factories.first.id;
          debugPrint(
              'ℹ️ _selectedFactoryId was set to first factory: $_selectedFactoryId');
        }
      });

      debugPrint('📊 State after loading:');
      debugPrint('  _companies.length: ${_companies.length}');
      debugPrint('  _suppliers.length: ${_suppliers.length}');
      debugPrint('  _allItems.length: ${_allItems.length}');
      debugPrint('  _factories.length: ${_factories.length}');
      debugPrint('  _selectedCompanyId: $_selectedCompanyId');
      debugPrint('  _selectedFactoryId: $_selectedFactoryId');
    } catch (e, st) {
      debugPrint('❌ Exception in _loadInitialData: $e');
      debugPrint(st.toString());
      _showErrorSnackbar('error_loading_data'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('⬆️ Finished loading initial data.');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCompanyDropdown() {
    return DropdownButtonFormField<String>(
      value: _companies.any((c) => c.id == _selectedCompanyId)
          ? _selectedCompanyId
          : null,
      decoration: InputDecoration(
        labelText: 'company'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _companies
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nameAr)))
          .toList(),
      onChanged: (val) async {
        if (val == null) return;
        setState(() => _selectedCompanyId = val);
        final user = await UserLocalStorage.getUser();
        final companyIds = (user?['companyIds'] as List?)?.cast<String>() ?? [];
        final userId = user?['userId'];
        debugPrint('🚀 userId: $userId');
        debugPrint('🚀 companyIds: $companyIds');
        final factories = await _firestoreService
            .getUserFactories(user?['userId'] ?? '', companyIds)
            .first;
        if (!mounted) return;
        setState(() {
          _factories =
              factories.where((f) => f.companyIds.contains(val)).toList();
          _selectedFactoryId =
              _factories.isNotEmpty ? _factories.first.id : null;
        });
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFactoryId,
      decoration: InputDecoration(
        labelText: 'factory'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _factories
          .map((f) => DropdownMenuItem(value: f.id, child: Text(f.nameAr)))
          .toList(),
      onChanged: (val) => setState(() => _selectedFactoryId = val),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSupplierId,
      decoration: InputDecoration(
        labelText: 'supplier'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _suppliers
          .map((v) => DropdownMenuItem(
              value: v.id, child: Text('${v.nameAr} (${v.nameEn})')))
          .toList(),
      onChanged: (val) => setState(() => _selectedSupplierId = val),
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Future<void> _showItemSelectionDialog() async {
    final selected = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (var i in selected) {
        if (!_items.any((e) => e.itemId == i.itemId)) {
          _items.add(i);
        }
      }
    });
  }

  bool _validateForm() {
    if (_selectedCompanyId == null ||
        _selectedSupplierId == null ||
        _items.isEmpty) {
      _showErrorSnackbar('missing_required_fields'.tr());
      return false;
    }
    return true;
  }

  Future<void> _submitOrder() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final order = PurchaseOrder(
        id: '',
        poNumber: '',
        userId: _auth.currentUser?.uid ?? '',
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId,
        supplierId: _selectedSupplierId!,
        orderDate: _orderDate,
        status: 'pending',
        items: _items,
        taxRate: _taxRate,
        totalAmount: _items.fold(0, (sTotal, item) => sTotal + item.totalPrice),
        totalTax: _items.fold(0, (sTotal, item) => sTotal + item.taxAmount),
        totalAmountAfterTax:
            _items.fold(0, (sTotal, item) => sTotal + item.totalAfterTaxAmount),
        isDelivered: _isDelivered,
      );
      await _firestoreService.createPurchaseOrder(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_saved'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    //if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('new_purchase_order'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    debugPrint('📦 building main UI');
    debugPrint('📦 companies length: ${_companies.length}');

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _submitOrder),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCompanyDropdown(),
              const SizedBox(height: 16),
              if (_selectedCompanyId != null) _buildFactoryDropdown(),
              const SizedBox(height: 16),
              _buildSupplierDropdown(),
              const SizedBox(height: 16),
              ListTile(
                title: Text('order_date'.tr()),
                subtitle: Text(DateFormat.yMd().format(_orderDate)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _orderDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null && mounted) setState(() => _orderDate = d);
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _taxRate.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'tax_rate_percent'.tr(),
                  suffixText: '%',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final rate = double.tryParse(v) ?? _taxRate;
                  setState(() => _taxRate = rate);
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('items'.tr(),
                      style: Theme.of(context).textTheme.headlineSmall),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text('add_items'.tr()),
                    onPressed: _showItemSelectionDialog,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._items.map((i) => ListTile(
                    title: Text(context.locale.languageCode == 'ar'
                        ? i.nameAr
                        : i.nameEn),
                    subtitle: Text('${i.quantity} × ${i.unitPrice}'),
                  )),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('save_order'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
  */
