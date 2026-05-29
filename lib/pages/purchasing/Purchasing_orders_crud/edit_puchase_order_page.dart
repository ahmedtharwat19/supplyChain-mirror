/* import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class EditPurchaseOrderPage extends StatefulWidget {
  final PurchaseOrder order;
  const EditPurchaseOrderPage({super.key, required this.order});

  @override
  State<EditPurchaseOrderPage> createState() => _EditPurchaseOrderPageState();
}

class _EditPurchaseOrderPageState extends State<EditPurchaseOrderPage> {
  late Future<Map<String, String>> _companySupplierNames;
  final FirestoreService _firestoreService = FirestoreService();
  late PurchaseOrder _editedOrder;
  bool _isLoading = false;
  double _taxRate = 14.0;
  
  // ✅ متغيرات ضريبة الخصم من المنبع
  double _withholdingTaxAmount = 0.0;
  double _withholdingTaxRate = 0.0;
  bool _hasWithholdingTax = false;

  @override
  void initState() {
    super.initState();
    _editedOrder = widget.order;
    _taxRate = _editedOrder.taxRate;
    
    // ✅ قراءة ضريبة الخصم من المنبع
    _withholdingTaxAmount = _editedOrder.withholdingTaxAmount;
    _withholdingTaxRate = _editedOrder.withholdingTaxRate;
    _hasWithholdingTax = _withholdingTaxAmount > 0;
    
    _companySupplierNames = _loadCompanyAndSupplierNames();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.updatePurchaseOrder(_editedOrder);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_updated'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('update_error'.tr())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() {
      _editedOrder = _editedOrder.copyWith(status: newStatus);
    });
    await _saveChanges();
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) return;
    setState(() {
      final item = _editedOrder.items[index];
      final updatedItem = item.updateQuantity(newQuantity);
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0) return;
    setState(() {
      final item = _editedOrder.items[index];
      final updatedItem = item.updateUnitPrice(newPrice);
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _updateItemTaxStatus(int index, bool isTaxable) {
    setState(() {
      final item = _editedOrder.items[index];
      final updatedItem = item.updateTaxStatus(
        isTaxable,
        isTaxable ? _taxRate : 0.0,
      );
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

voideTotals() {
  double total = 0;
  double totalTax = 0;
  double beforeWithholding = 0;

  for (var item in _editedOrder.items) {
    totalAmount += item.totalPrice;
    totalTax += item.taxAmount;
  }
  
  beforeWithholding = totalAmount + totalTax;
  final netPayable = beforeWithholding - _withholdingTaxAmount;

  _editedOrder = _editedOrder.copyWith(
    totalAmount: totalAmount,
    totalTax: totalTax,
    totalAmountAfterTax: beforeWithholding,
    netPayable: netPayable,
  );
}

  void _removeItem(int index) {
    setState(() {
      _editedOrder.items.removeAt(index);
      _recalculateTotals();
    });
  }

  bool get _isArabic => context.locale.languageCode == 'ar';

  String localizedName(Map<String, String?> nameMap) {
    return _isArabic
        ? nameMap['nameAr'] ?? 'غير معروف'
        : nameMap['nameEn'] ?? 'Unknown';
  }

  Future<Map<String, String>> _loadCompanyAndSupplierNames() async {
    try {
      final companyName = await _firestoreService.getCompanyName(
        widget.order.companyId,
      );
      final supplierName = await _firestoreService.getSupplierName(
        widget.order.supplierId,
      );
      return {
        'company': localizedName(companyName),
        'supplier': localizedName(supplierName),
      };
    } catch (e) {
      return {
        'company': _isArabic ? 'غير معروف' : 'Unknown',
        'supplier': _isArabic ? 'غير معروف' : 'Unknown',
      };
    }
  }

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue =
        value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numValue);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Item item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic ? item.nameAr : item.nameEn,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('quantity'.tr(), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          final qty = double.tryParse(value) ?? item.quantity;
                          _updateItemQuantity(index, qty);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('unit_price'.tr(), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          prefixText: '${'currency'.tr()} ',
                        ),
                        onChanged: (value) {
                          final price = double.tryParse(value) ?? item.unitPrice;
                          _updateItemPrice(index, price);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('taxable'.tr()),
                    value: item.isTaxable,
                    onChanged: (value) => _updateItemTaxStatus(index, value),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'total'.tr(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${_formatCurrency(item.totalAfterTaxAmount)} ${'currency'.tr()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (item.isTaxable)
                      Text(
                        '(${_formatCurrency(item.taxAmount)} tax)',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildOrderSummary() {
  final subtotal = _editedOrder.totalAmount;
  final totalTax = _editedOrder.totalTax;
  final beforeWithholding = subtotal + totalTax;
  final netPayable = _editedOrder.netPayable;
  
  return Card(
    color: Colors.grey[50],
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'order_summary'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          _buildSummaryRow('subtotal'.tr(), subtotal),
          _buildSummaryRow('tax'.tr(), totalTax),
          _buildSummaryRow('total_before_withholding'.tr(), beforeWithholding),
          
          // ✅ عرض ضريبة الخصم من المنبع
          if (_hasWithholdingTax && _withholdingTaxAmount > 0) ...[
            const Divider(),
            Text(
              'withholding_tax_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            _buildSummaryRow(
              'withholding_tax_rate'.tr(),
              _withholdingTaxRate,
              suffix: '%',
              valueColor: Colors.orange,
            ),
            _buildSummaryRow(
              'withholding_tax_amount'.tr(),
              -_withholdingTaxAmount,
              valueColor: Colors.red,
            ),
          ],
          
          const Divider(thickness: 2),
          _buildSummaryRow(
            'net_payable'.tr(),
            netPayable,
            isTotal: true,
          ),
        ],
      ),
    ),
  );
}
  Widget _buildSummaryRow(String label, double value, 
      {bool isTotal = false, Color? valueColor, String suffix = ''}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                : const TextStyle(fontSize: 14),
          ),
          Text(
            '$sign${displayValue.toStringAsFixed(2)}$suffix ${'currency'.tr()}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'edit_order',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'edit_order'.tr(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('change_status'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('mark_as_completed'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus('completed');
                    },
                  ),
                  ListTile(
                    title: Text('mark_as_cancelled'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus('cancelled');
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _companySupplierNames,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final names = snapshot.data ??
              {
                'company': _isArabic ? 'غير معروف' : 'Unknown',
                'supplier': _isArabic ? 'غير معروف' : 'Unknown'
              };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PO Number: ${_editedOrder.poNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('company'.tr(), names['company']!),
                        _buildInfoRow('supplier'.tr(), names['supplier']!),
                        _buildInfoRow('status'.tr(), _editedOrder.status.tr()),
                        _buildInfoRow(
                          'order_date'.tr(),
                          DateFormat('yyyy-MM-dd').format(_editedOrder.orderDate),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  'items'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_editedOrder.items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('no_items'.tr()),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _editedOrder.items.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(_editedOrder.items[index], index);
                    },
                  ),
                const SizedBox(height: 16),
                
                _buildOrderSummary(),
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save),
                    label: Text('save_changes'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} */
/* 

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPurchaseOrderPage extends StatefulWidget {
  final PurchaseOrder order;
  const EditPurchaseOrderPage({super.key, required this.order});

  @override
  State<EditPurchaseOrderPage> createState() => _EditPurchaseOrderPageState();
}

class _EditPurchaseOrderPageState extends State<EditPurchaseOrderPage> {
  late Future<Map<String, String>> _companySupplierNames;
  final FirestoreService _firestoreService = FirestoreService();
  late PurchaseOrder _editedOrder;
  bool _isLoading = false;
  double _taxRate = 14.0;
  
  // ✅ متغيرات ضريبة الخصم من المنبع
  double _withholdingTaxAmount = 0.0;
  double _withholdingTaxRate = 0.0;
  bool _hasWithholdingTax = false;
  String? _supplierId;
  
  // ✅ قائمة الموردين لتحديث البيانات

  @override
  void initState() {
    super.initState();
    _editedOrder = widget.order;
    _taxRate = _editedOrder.taxRate;
    _supplierId = _editedOrder.supplierId;
    
    // ✅ قراءة ضريبة الخصم من المنبع
    _withholdingTaxAmount = _editedOrder.withholdingTaxAmount;
    _withholdingTaxRate = _editedOrder.withholdingTaxRate;
    _hasWithholdingTax = _withholdingTaxAmount > 0;
    
    _loadSupplierData();
    _companySupplierNames = _loadCompanyAndSupplierNames();
  }

  // ✅ تحميل بيانات المورد لتحديث حالة الخصم
  Future<void> _loadSupplierData() async {
    if (_supplierId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_supplierId)
          .get();
      
      if (doc.exists) {
        final supplier = Supplier.fromMap(doc.data()!, doc.id);
        
        // ✅ تحديث حالة الخصم من المنبع بناءً على بيانات المورد الحالية
        if (supplier.subjectToWithholding) {
          _withholdingTaxRate = supplier.withholdingTaxRate;
          _recalculateWithholdingTax(); // ✅ إعادة حساب الضريبة
        } else {
          _withholdingTaxAmount = 0.0;
          _withholdingTaxRate = 0.0;
          _hasWithholdingTax = false;
        }
      }
    } catch (e) {
      safeDebugPrint('Error loading supplier data: $e');
    }
  }

  // ✅ إعادة حساب ضريبة الخصم من المنبع
  void _recalculateWithholdingTax() {
    final subtotal = _editedOrder.totalAmount;
  //  final totalTax = _editedOrder.totalTax;
    //final totalBeforeWithholding = subtotal + totalTax;
    _withholdingTaxAmount = subtotal * (_withholdingTaxRate / 100);
    _hasWithholdingTax = _withholdingTaxAmount > 0;
    
    // ✅ تحديث الإجمالي النهائي
    _recalculateTotals();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      // ✅ تحديث قيم الضريبة قبل الحفظ
      _editedOrder = _editedOrder.copyWith(
        withholdingTaxAmount: _withholdingTaxAmount,
        withholdingTaxRate: _withholdingTaxRate,
      );
      
      await _firestoreService.updatePurchaseOrder(_editedOrder);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_updated'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('update_error'.tr())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() {
      _editedOrder = _editedOrder.copyWith(status: newStatus);
    });
    await _saveChanges();
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) return;
    setState(() {
      final item = _editedOrder.items[index];
      final updatedItem = item.updateQuantity(newQuantity);
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0) return;
    setState(() {
      final item = _editedOrder.items[index];
      final updatedItem = item.updateUnitPrice(newPrice);
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _updateItemTaxStatus(int index, bool isTaxable) {
    setState(() {
      final item = _editedOrder.items[index];
      final updatedItem = item.updateTaxStatus(
        isTaxable,
        isTaxable ? _taxRate : 0.0,
      );
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    double totalAmount = 0;
    double totalTax = 0;
    
    for (var item in _editedOrder.items) {
      totalAmount += item.totalPrice;
      totalTax += item.taxAmount;
    }
    
    final totalBeforeWithholding = totalAmount ;
    final netPayable = totalBeforeWithholding - _withholdingTaxAmount;

    _editedOrder = _editedOrder.copyWith(
      totalAmount: totalAmount,
      totalTax: totalTax,
      totalAmountAfterTax: totalBeforeWithholding,
      netPayable: netPayable,
    );
  }

  void _removeItem(int index) {
    setState(() {
      _editedOrder.items.removeAt(index);
      _recalculateTotals();
    });
  }

  bool get _isArabic => context.locale.languageCode == 'ar';

  String localizedName(Map<String, String?> nameMap) {
    return _isArabic
        ? nameMap['nameAr'] ?? 'غير معروف'
        : nameMap['nameEn'] ?? 'Unknown';
  }

  Future<Map<String, String>> _loadCompanyAndSupplierNames() async {
    try {
      final companyName = await _firestoreService.getCompanyName(widget.order.companyId);
      final supplierName = await _firestoreService.getSupplierName(widget.order.supplierId);
      return {
        'company': localizedName(companyName),
        'supplier': localizedName(supplierName),
      };
    } catch (e) {
      return {
        'company': _isArabic ? 'غير معروف' : 'Unknown',
        'supplier': _isArabic ? 'غير معروف' : 'Unknown',
      };
    }
  }

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numValue);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Item item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic ? item.nameAr : item.nameEn,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('quantity'.tr(), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          final qty = double.tryParse(value) ?? item.quantity;
                          _updateItemQuantity(index, qty);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('unit_price'.tr(), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          prefixText: '${'currency'.tr()} ',
                        ),
                        onChanged: (value) {
                          final price = double.tryParse(value) ?? item.unitPrice;
                          _updateItemPrice(index, price);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('taxable'.tr()),
                    value: item.isTaxable,
                    onChanged: (value) => _updateItemTaxStatus(index, value),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('total'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_formatCurrency(item.totalAfterTaxAmount)} ${'currency'.tr()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (item.isTaxable)
                      Text(
                        '(${_formatCurrency(item.taxAmount)} tax)',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = _editedOrder.totalAmount;
    final totalTax = _editedOrder.totalTax;
    final beforeWithholding = subtotal + totalTax;
    final netPayable = beforeWithholding - _withholdingTaxAmount;
    
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('order_summary'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), subtotal),
            _buildSummaryRow('tax'.tr(), totalTax),
            _buildSummaryRow('total_before_withholding'.tr(), beforeWithholding),
            
            if (_hasWithholdingTax && _withholdingTaxAmount > 0) ...[
              const Divider(),
              Text('withholding_tax_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              _buildSummaryRow('withholding_tax_rate'.tr(), _withholdingTaxRate, suffix: '%', valueColor: Colors.orange),
              _buildSummaryRow('withholding_tax_amount'.tr(), -_withholdingTaxAmount, valueColor: Colors.red),
            ],
            
            const Divider(thickness: 2),
            _buildSummaryRow('net_payable'.tr(), netPayable, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, 
      {bool isTotal = false, Color? valueColor, String suffix = ''}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isTotal ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(
            '$sign${displayValue.toStringAsFixed(2)}$suffix ${'currency'.tr()}',
            style: TextStyle(color: valueColor, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'edit_order',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'edit_order'.tr(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('change_status'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('mark_as_completed'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus('completed');
                    },
                  ),
                  ListTile(
                    title: Text('mark_as_cancelled'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus('cancelled');
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _companySupplierNames,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final names = snapshot.data ?? {
            'company': _isArabic ? 'غير معروف' : 'Unknown',
            'supplier': _isArabic ? 'غير معروف' : 'Unknown'
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PO Number: ${_editedOrder.poNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildInfoRow('company'.tr(), names['company']!),
                        _buildInfoRow('supplier'.tr(), names['supplier']!),
                        _buildInfoRow('status'.tr(), _editedOrder.status.tr()),
                        _buildInfoRow('order_date'.tr(), DateFormat('yyyy-MM-dd').format(_editedOrder.orderDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Text('items'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_editedOrder.items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('no_items'.tr())),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _editedOrder.items.length,
                    itemBuilder: (context, index) => _buildItemCard(_editedOrder.items[index], index),
                  ),
                const SizedBox(height: 16),
                
                _buildOrderSummary(),
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save),
                    label: Text('save_changes'.tr()),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} */
/* 

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPurchaseOrderPage extends StatefulWidget {
  final PurchaseOrder order;
  const EditPurchaseOrderPage({super.key, required this.order});

  @override
  State<EditPurchaseOrderPage> createState() => _EditPurchaseOrderPageState();
}

class _EditPurchaseOrderPageState extends State<EditPurchaseOrderPage> {
  late Future<Map<String, String>> _companySupplierNames;
  final FirestoreService _firestoreService = FirestoreService();
  late PurchaseOrder _editedOrder;
  bool _isLoading = false;
  double _taxRate = 14.0;
  
  double _withholdingTaxAmount = 0.0;
  double _withholdingTaxRate = 0.0;
  bool _hasWithholdingTax = false;
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    _editedOrder = widget.order;
    _taxRate = _editedOrder.taxRate;
    _supplierId = _editedOrder.supplierId;
    
    _withholdingTaxAmount = _editedOrder.withholdingTaxAmount;
    _withholdingTaxRate = _editedOrder.withholdingTaxRate;
    _hasWithholdingTax = _withholdingTaxAmount > 0;
    
    _loadSupplierData();
    _companySupplierNames = _loadCompanyAndSupplierNames();
  }

  Future<void> _loadSupplierData() async {
    if (_supplierId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_supplierId)
          .get();
      
      if (doc.exists) {
        final supplier = Supplier.fromMap(doc.data()!, doc.id);
        
        if (supplier.subjectToWithholding) {
          _withholdingTaxRate = supplier.withholdingTaxRate;
          _recalculateWithholdingTax();
          if (mounted) setState(() {});
        } else {
          _withholdingTaxAmount = 0.0;
          _withholdingTaxRate = 0.0;
          _hasWithholdingTax = false;
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      safeDebugPrint('Error loading supplier data: $e');
    }
  }

  void _recalculateWithholdingTax() {
    final subtotal = _editedOrder.totalAmount;
    final totalTax = _editedOrder.totalTax;
    final totalBeforeWithholding = subtotal + totalTax;
    _withholdingTaxAmount = totalBeforeWithholding * (_withholdingTaxRate / 100);
    _hasWithholdingTax = _withholdingTaxAmount > 0;
    
    _recalculateTotals();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      // ✅ حساب القيم النهائية
      double totalAmount = 0;
      double totalTax = 0;
      
      for (var item in _editedOrder.items) {
        totalAmount += item.totalPrice;
        totalTax += item.taxAmount;
      }
      
      final totalBeforeWithholding = totalAmount + totalTax;
      final netPayable = totalBeforeWithholding - _withholdingTaxAmount;
      
      _editedOrder = _editedOrder.copyWith(
        totalAmount: totalAmount,
        totalTax: totalTax,
        totalAmountAfterTax: totalBeforeWithholding,
        withholdingTaxAmount: _withholdingTaxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        netPayable: netPayable,
      );
      
      await _firestoreService.updatePurchaseOrder(_editedOrder);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_updated'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      safeDebugPrint('Error saving: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('update_error'.tr())));
      Navigator.pop(context, false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() {
      _editedOrder = _editedOrder.copyWith(status: newStatus);
    });
    await _saveChanges();
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) return;
    setState(() {
      final item = _editedOrder.items[index];
      final newTotalPrice = item.unitPrice * newQuantity;
      final newTaxAmount = item.isTaxable ? (newTotalPrice * _taxRate / 100) : 0.0;
      final newTotalAfterTax = newTotalPrice + newTaxAmount;
      
      final updatedItem = item.copyWith(
        quantity: newQuantity,
        totalPrice: newTotalPrice,
        taxAmount: newTaxAmount,
        totalAfterTaxAmount: newTotalAfterTax,
      );
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0) return;
    setState(() {
      final item = _editedOrder.items[index];
      final newTotalPrice = newPrice * item.quantity;
      final newTaxAmount = item.isTaxable ? (newTotalPrice * _taxRate / 100) : 0.0;
      final newTotalAfterTax = newTotalPrice + newTaxAmount;
      
      final updatedItem = item.copyWith(
        unitPrice: newPrice,
        totalPrice: newTotalPrice,
        taxAmount: newTaxAmount,
        totalAfterTaxAmount: newTotalAfterTax,
      );
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _updateItemTaxStatus(int index, bool isTaxable) {
    setState(() {
      final item = _editedOrder.items[index];
      final newTaxAmount = isTaxable ? (item.totalPrice * _taxRate / 100) : 0.0;
      final newTotalAfterTax = item.totalPrice + newTaxAmount;
      
      final updatedItem = item.copyWith(
        isTaxable: isTaxable,
        taxAmount: newTaxAmount,
        totalAfterTaxAmount: newTotalAfterTax,
      );
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    double totalAmount = 0;
    double totalTax = 0;
    List<Item> updatedItems = [];
    
    for (var item in _editedOrder.items) {
      final itemTax = item.isTaxable ? (item.totalPrice * _taxRate / 100) : 0.0;
      final itemTotalAfterTax = item.totalPrice + itemTax;
      
      final updatedItem = item.copyWith(
        taxAmount: itemTax,
        totalAfterTaxAmount: itemTotalAfterTax,
      );
      updatedItems.add(updatedItem);
      
      totalAmount += updatedItem.totalPrice;
      totalTax += updatedItem.taxAmount;
    }
    
    _editedOrder.items.clear();
    _editedOrder.items.addAll(updatedItems);
    
    final totalBeforeWithholding = totalAmount + totalTax;
    final netPayable = totalBeforeWithholding - _withholdingTaxAmount;

    _editedOrder = _editedOrder.copyWith(
      totalAmount: totalAmount,
      totalTax: totalTax,
      totalAmountAfterTax: totalBeforeWithholding,
      netPayable: netPayable,
    );
    
    if (mounted) setState(() {});
  }

  void _removeItem(int index) {
    setState(() {
      _editedOrder.items.removeAt(index);
      _recalculateTotals();
    });
  }

  bool get _isArabic => context.locale.languageCode == 'ar';

  String localizedName(Map<String, String?> nameMap) {
    return _isArabic
        ? nameMap['nameAr'] ?? 'غير معروف'
        : nameMap['nameEn'] ?? 'Unknown';
  }

  Future<Map<String, String>> _loadCompanyAndSupplierNames() async {
    try {
      final companyName = await _firestoreService.getCompanyName(widget.order.companyId);
      final supplierName = await _firestoreService.getSupplierName(widget.order.supplierId);
      return {
        'company': localizedName(companyName),
        'supplier': localizedName(supplierName),
      };
    } catch (e) {
      return {
        'company': _isArabic ? 'غير معروف' : 'Unknown',
        'supplier': _isArabic ? 'غير معروف' : 'Unknown',
      };
    }
  }

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numValue);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Item item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic ? item.nameAr : item.nameEn,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('quantity'.tr(), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          final qty = double.tryParse(value) ?? item.quantity;
                          _updateItemQuantity(index, qty);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('unit_price'.tr(), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          prefixText: '${'currency'.tr()} ',
                        ),
                        onChanged: (value) {
                          final price = double.tryParse(value) ?? item.unitPrice;
                          _updateItemPrice(index, price);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('taxable'.tr()),
                    value: item.isTaxable,
                    onChanged: (value) => _updateItemTaxStatus(index, value),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('total'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_formatCurrency(item.totalPrice)} ${'currency'.tr()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (item.isTaxable)
                      Text(
                        '(${_formatCurrency(item.taxAmount)} tax)',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = _editedOrder.totalAmount;
    final totalTax = _editedOrder.totalTax;
    final beforeWithholding = subtotal + totalTax;
    final netPayable = beforeWithholding - _withholdingTaxAmount;
    
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('order_summary'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), subtotal),
            _buildSummaryRow('tax'.tr(), totalTax),
            _buildSummaryRow('total_before_withholding'.tr(), beforeWithholding),
            
            if (_hasWithholdingTax && _withholdingTaxAmount > 0) ...[
              const Divider(),
              Text('withholding_tax_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              _buildSummaryRow('withholding_tax_rate'.tr(), _withholdingTaxRate, suffix: '%', valueColor: Colors.orange),
              _buildSummaryRow('withholding_tax_amount'.tr(), -_withholdingTaxAmount, valueColor: Colors.red),
            ],
            
            const Divider(thickness: 2),
            _buildSummaryRow('net_payable'.tr(), netPayable, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, 
      {bool isTotal = false, Color? valueColor, String suffix = ''}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isTotal ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(
            '$sign${displayValue.toStringAsFixed(2)}$suffix ${'currency'.tr()}',
            style: TextStyle(color: valueColor, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'edit_order',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'edit_order'.tr(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('change_status'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('mark_as_completed'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus('completed');
                    },
                  ),
                  ListTile(
                    title: Text('mark_as_cancelled'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus('cancelled');
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _companySupplierNames,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final names = snapshot.data ?? {
            'company': _isArabic ? 'غير معروف' : 'Unknown',
            'supplier': _isArabic ? 'غير معروف' : 'Unknown'
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PO Number: ${_editedOrder.poNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildInfoRow('company'.tr(), names['company']!),
                        _buildInfoRow('supplier'.tr(), names['supplier']!),
                        _buildInfoRow('status'.tr(), _editedOrder.status.tr()),
                        _buildInfoRow('order_date'.tr(), DateFormat('yyyy-MM-dd').format(_editedOrder.orderDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Text('items'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_editedOrder.items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('no_items'.tr())),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _editedOrder.items.length,
                    itemBuilder: (context, index) => _buildItemCard(_editedOrder.items[index], index),
                  ),
                const SizedBox(height: 16),
                
                _buildOrderSummary(),
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save),
                    label: Text('save_changes'.tr()),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} */

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/payment_terms.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPurchaseOrderPage extends StatefulWidget {
  final PurchaseOrder order;
  const EditPurchaseOrderPage({super.key, required this.order});

  @override
  State<EditPurchaseOrderPage> createState() => _EditPurchaseOrderPageState();
}

class _EditPurchaseOrderPageState extends State<EditPurchaseOrderPage> {
  late Future<Map<String, String>> _companySupplierNames;
  final FirestoreService _firestoreService = FirestoreService();
  late PurchaseOrder _editedOrder;
  bool _isLoading = false;
  double _taxRate = 14.0;
  
  double _withholdingTaxAmount = 0.0;
  double _withholdingTaxRate = 0.0;
  bool _hasWithholdingTax = false;
  String? _supplierId;

  // ✅ شروط الدفع والتسليم
  String? _selectedPaymentTermCode;
  String? _selectedDeliveryTermCode;

  @override
  void initState() {
    super.initState();
    _editedOrder = widget.order;
    _taxRate = _editedOrder.taxRate;
    _supplierId = _editedOrder.supplierId;
    
    _withholdingTaxAmount = _editedOrder.withholdingTaxAmount;
    _withholdingTaxRate = _editedOrder.withholdingTaxRate;
    _hasWithholdingTax = _withholdingTaxAmount > 0;
    
    // ✅ قراءة شروط الدفع والتسليم
    _selectedPaymentTermCode = _editedOrder.paymentTermCode;
    _selectedDeliveryTermCode = _editedOrder.deliveryTermCode;
    
    _loadSupplierData();
    _companySupplierNames = _loadCompanyAndSupplierNames();
  }

  Future<void> _loadSupplierData() async {
    if (_supplierId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_supplierId)
          .get();
      
      if (doc.exists) {
        final supplier = Supplier.fromMap(doc.data()!, doc.id);
        
        if (supplier.subjectToWithholding) {
          _withholdingTaxRate = supplier.withholdingTaxRate;
          _recalculateWithholdingTax();
          if (mounted) setState(() {});
        } else {
          _withholdingTaxAmount = 0.0;
          _withholdingTaxRate = 0.0;
          _hasWithholdingTax = false;
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      safeDebugPrint('Error loading supplier data: $e');
    }
  }

  void _recalculateWithholdingTax() {
    final subtotal = _editedOrder.totalAmount;
    final totalTax = _editedOrder.totalTax;
    final totalBeforeWithholding = subtotal + totalTax;
    _withholdingTaxAmount = totalBeforeWithholding * (_withholdingTaxRate / 100);
    _hasWithholdingTax = _withholdingTaxAmount > 0;
    
    _recalculateTotals();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      // ✅ حساب القيم النهائية
      double totalAmount = 0;
      double totalTax = 0;
      
      for (var item in _editedOrder.items) {
        totalAmount += item.totalPrice;
        totalTax += item.taxAmount;
      }
      
      final totalBeforeWithholding = totalAmount + totalTax;
      final netPayable = totalBeforeWithholding - _withholdingTaxAmount;
      
      _editedOrder = _editedOrder.copyWith(
        totalAmount: totalAmount,
        totalTax: totalTax,
        totalAmountAfterTax: totalBeforeWithholding,
        withholdingTaxAmount: _withholdingTaxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        netPayable: netPayable,
        // ✅ حفظ شروط الدفع والتسليم
        paymentTermCode: _selectedPaymentTermCode,
        deliveryTermCode: _selectedDeliveryTermCode,
      );
      
      await _firestoreService.updatePurchaseOrder(_editedOrder);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_updated'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      safeDebugPrint('Error saving: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('update_error'.tr())));
      Navigator.pop(context, false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() {
      _editedOrder = _editedOrder.copyWith(status: newStatus);
    });
    await _saveChanges();
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) return;
    setState(() {
      final item = _editedOrder.items[index];
      final newTotalPrice = item.unitPrice * newQuantity;
      final newTaxAmount = item.isTaxable ? (newTotalPrice * _taxRate / 100) : 0.0;
      final newTotalAfterTax = newTotalPrice + newTaxAmount;
      
      final updatedItem = item.copyWith(
        quantity: newQuantity,
        totalPrice: newTotalPrice,
        taxAmount: newTaxAmount,
        totalAfterTaxAmount: newTotalAfterTax,
      );
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0) return;
    setState(() {
      final item = _editedOrder.items[index];
      final newTotalPrice = newPrice * item.quantity;
      final newTaxAmount = item.isTaxable ? (newTotalPrice * _taxRate / 100) : 0.0;
      final newTotalAfterTax = newTotalPrice + newTaxAmount;
      
      final updatedItem = item.copyWith(
        unitPrice: newPrice,
        totalPrice: newTotalPrice,
        taxAmount: newTaxAmount,
        totalAfterTaxAmount: newTotalAfterTax,
      );
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _updateItemTaxStatus(int index, bool isTaxable) {
    setState(() {
      final item = _editedOrder.items[index];
      final newTaxAmount = isTaxable ? (item.totalPrice * _taxRate / 100) : 0.0;
      final newTotalAfterTax = item.totalPrice + newTaxAmount;
      
      final updatedItem = item.copyWith(
        isTaxable: isTaxable,
        taxAmount: newTaxAmount,
        totalAfterTaxAmount: newTotalAfterTax,
      );
      _editedOrder.items[index] = updatedItem;
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    double totalAmount = 0;
    double totalTax = 0;
    List<Item> updatedItems = [];
    
    for (var item in _editedOrder.items) {
      final itemTax = item.isTaxable ? (item.totalPrice * _taxRate / 100) : 0.0;
      final itemTotalAfterTax = item.totalPrice + itemTax;
      
      final updatedItem = item.copyWith(
        taxAmount: itemTax,
        totalAfterTaxAmount: itemTotalAfterTax,
      );
      updatedItems.add(updatedItem);
      
      totalAmount += updatedItem.totalPrice;
      totalTax += updatedItem.taxAmount;
    }
    
    _editedOrder.items.clear();
    _editedOrder.items.addAll(updatedItems);
    
    final totalBeforeWithholding = totalAmount + totalTax;
    final netPayable = totalBeforeWithholding - _withholdingTaxAmount;

    _editedOrder = _editedOrder.copyWith(
      totalAmount: totalAmount,
      totalTax: totalTax,
      totalAmountAfterTax: totalBeforeWithholding,
      netPayable: netPayable,
    );
    
    if (mounted) setState(() {});
  }

  void _removeItem(int index) {
    setState(() {
      _editedOrder.items.removeAt(index);
      _recalculateTotals();
    });
  }

  bool get _isArabic => context.locale.languageCode == 'ar';

  String localizedName(Map<String, String?> nameMap) {
    return _isArabic
        ? nameMap['nameAr'] ?? 'غير معروف'
        : nameMap['nameEn'] ?? 'Unknown';
  }

  Future<Map<String, String>> _loadCompanyAndSupplierNames() async {
    try {
      final companyName = await _firestoreService.getCompanyName(widget.order.companyId);
      final supplierName = await _firestoreService.getSupplierName(widget.order.supplierId);
      return {
        'company': localizedName(companyName),
        'supplier': localizedName(supplierName),
      };
    } catch (e) {
      return {
        'company': _isArabic ? 'غير معروف' : 'Unknown',
        'supplier': _isArabic ? 'غير معروف' : 'Unknown',
      };
    }
  }

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numValue);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ✅ شروط الدفع
  Widget _buildPaymentTermsDisplay() {
    if (_selectedPaymentTermCode == null) return const SizedBox();
    
    final isArabic = context.locale.languageCode == 'ar';
    final term = PaymentTerm.paymentTerms.firstWhere(
      (t) => t.code == _selectedPaymentTermCode,
      orElse: () => PaymentTerm.paymentTerms.first,
    );
    
    return Card(
      color: Colors.grey[100],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'payment_terms'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(term.getName(isArabic)),
            Text(
              term.getDescription(isArabic),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ شروط التسليم
  Widget _buildDeliveryTermsDisplay() {
    if (_selectedDeliveryTermCode == null) return const SizedBox();
    
    final isArabic = context.locale.languageCode == 'ar';
    final term = DeliveryTerm.deliveryTerms.firstWhere(
      (t) => t.code == _selectedDeliveryTermCode,
      orElse: () => DeliveryTerm.deliveryTerms.first,
    );
    
    return Card(
      color: Colors.grey[100],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'delivery_terms'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(term.getName(isArabic)),
            Text(
              term.getDescription(isArabic),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Item item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic ? item.nameAr : item.nameEn,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('quantity'.tr(), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          final qty = double.tryParse(value) ?? item.quantity;
                          _updateItemQuantity(index, qty);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('unit_price'.tr(), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          prefixText: '${'currency'.tr()} ',
                        ),
                        onChanged: (value) {
                          final price = double.tryParse(value) ?? item.unitPrice;
                          _updateItemPrice(index, price);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('taxable'.tr()),
                    value: item.isTaxable,
                    onChanged: (value) => _updateItemTaxStatus(index, value),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('total'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_formatCurrency(item.totalPrice)} ${'currency'.tr()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (item.isTaxable)
                      Text(
                        '(${_formatCurrency(item.taxAmount)} tax)',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = _editedOrder.totalAmount;
    final totalTax = _editedOrder.totalTax;
    final beforeWithholding = subtotal + totalTax;
    final netPayable = beforeWithholding - _withholdingTaxAmount;
    
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('order_summary'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), subtotal),
            _buildSummaryRow('tax'.tr(), totalTax),
            _buildSummaryRow('total_before_withholding'.tr(), beforeWithholding),
            
            if (_hasWithholdingTax && _withholdingTaxAmount > 0) ...[
              const Divider(),
              Text('withholding_tax_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              _buildSummaryRow('withholding_tax_rate'.tr(), _withholdingTaxRate, suffix: '%', valueColor: Colors.orange),
              _buildSummaryRow('withholding_tax_amount'.tr(), -_withholdingTaxAmount, valueColor: Colors.red),
            ],
            
            const Divider(thickness: 2),
            _buildSummaryRow('net_payable'.tr(), netPayable, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, 
      {bool isTotal = false, Color? valueColor, String suffix = ''}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isTotal ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(
            '$sign${displayValue.toStringAsFixed(2)}$suffix ${'currency'.tr()}',
            style: TextStyle(color: valueColor, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'edit_order',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'edit_order'.tr(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('change_status'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('mark_as_completed'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus('completed');
                    },
                  ),
                  ListTile(
                    title: Text('mark_as_cancelled'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus('cancelled');
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _companySupplierNames,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final names = snapshot.data ?? {
            'company': _isArabic ? 'غير معروف' : 'Unknown',
            'supplier': _isArabic ? 'غير معروف' : 'Unknown'
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PO Number: ${_editedOrder.poNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildInfoRow('company'.tr(), names['company']!),
                        _buildInfoRow('supplier'.tr(), names['supplier']!),
                        _buildInfoRow('status'.tr(), _editedOrder.status.tr()),
                        _buildInfoRow('order_date'.tr(), DateFormat('yyyy-MM-dd').format(_editedOrder.orderDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // ✅ عرض شروط الدفع والتسليم
                _buildPaymentTermsDisplay(),
                _buildDeliveryTermsDisplay(),
                
                Text('items'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_editedOrder.items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('no_items'.tr())),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _editedOrder.items.length,
                    itemBuilder: (context, index) => _buildItemCard(_editedOrder.items[index], index),
                  ),
                const SizedBox(height: 16),
                
                _buildOrderSummary(),
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save),
                    label: Text('save_changes'.tr()),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}