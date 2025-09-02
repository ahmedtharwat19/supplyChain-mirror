import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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

  @override
  void initState() {
    super.initState();
    _editedOrder = widget.order;
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
        //  isArabic: _isArabic,
      );

      final supplierName = await _firestoreService.getSupplierName(
        widget.order.supplierId,
        //  isArabic: _isArabic,
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

  FloatingActionButton _buildStatusActionButton() {
    return FloatingActionButton(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'edit_order'.tr(),
      floatingActionButton: _buildStatusActionButton(),
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
                Text('PO Number: ${_editedOrder.poNumber}',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                //    Text('Supplier: ${_editedOrder.supplierId}'),
                _buildInfoRow('company'.tr(), names['company']!),
                _buildInfoRow('supplier'.tr(), names['supplier']!),
                const SizedBox(height: 16),
                Text('Status: ${_editedOrder.status}'),
                const SizedBox(height: 16),
                Text(
                    'Total: ${_formatCurrency(_editedOrder.totalAmountAfterTax)}'),
                const SizedBox(height: 24),
                // هنا يمكنك إضافة المزيد من حقول التعديل حسب الحاجة
              ],
            ),
          );
        },
      ),
    );
  }
}
