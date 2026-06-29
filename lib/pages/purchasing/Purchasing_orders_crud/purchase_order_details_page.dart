/* import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:printing/printing.dart';

class PurchaseOrderDetailsPage extends StatelessWidget {
  final PurchaseOrder order;
  const PurchaseOrderDetailsPage({super.key, required this.order});

  Future<void> _exportToPdf(BuildContext context) async {
    try {
      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: order.id,
        orderData: order.toMap(),
        supplierData: {}, // يجب استبدالها ببيانات المورد الفعلية
        companyData: {}, // يجب استبدالها ببيانات الشركة الفعلية
        itemData: {}, // يجب استبدالها ببيانات الأصناف الفعلية
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'order_${order.poNumber}.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('export_error'.tr())));
    }
  }

  Widget _buildOrderInfoRow(String label, String value) {
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['name'] ?? 'Unknown Item',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildItemDetailRow('quantity'.tr(), item['quantity'].toString()),
            _buildItemDetailRow('unit_price'.tr(),
                NumberFormat.currency().format(item['unitPrice'])),
            _buildItemDetailRow('total'.tr(),
                NumberFormat.currency().format(item['totalPrice'])),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final currencyFormat = NumberFormat.currency();

    return AppScaffold(
      title: 'order_details'.tr(),
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: () => _exportToPdf(context),
          tooltip: 'export_pdf'.tr(),
        ),
      ],
      body: SingleChildScrollView(
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
                      'PO #${order.poNumber}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _buildOrderInfoRow('status'.tr(), order.status),
                    _buildOrderInfoRow(
                        'date'.tr(), dateFormat.format(order.orderDate)),
                    _buildOrderInfoRow('supplier'.tr(), order.supplierId),
                    _buildOrderInfoRow('company'.tr(), order.companyId),
                    if (order.factoryId != null)
                      _buildOrderInfoRow('factory'.tr(), order.factoryId!),
                    const Divider(height: 24),
                    _buildOrderInfoRow('subtotal'.tr(),
                        currencyFormat.format(order.totalAmount)),
                    _buildOrderInfoRow(
                        'tax'.tr(), currencyFormat.format(order.totalTax)),
                    _buildOrderInfoRow('total'.tr(),
                        currencyFormat.format(order.totalAmountAfterTax)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'items'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) => _buildItemCard(item.toMap())),
          ],
        ),
      ),
    );
  }
}
 */

/* 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:printing/printing.dart';

class PurchaseOrderDetailsPage extends StatelessWidget {
  final PurchaseOrder order;
  const PurchaseOrderDetailsPage({super.key, required this.order});

  Future<void> _exportToPdf(BuildContext context) async {
    try {
      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: order.id,
        orderData: order.toMap(),
        supplierData: {},
        companyData: {},
        itemData: {},
      );
      
      final bytes = await pdf.save();
      
      if (!context.mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'order_${order.poNumber}.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('export_error'.tr())));
    }
  }

  Widget _buildOrderInfoRow(String label, String value) {
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['name'] ?? 'Unknown Item',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildItemDetailRow('quantity'.tr(), item['quantity'].toString()),
            _buildItemDetailRow(
                'unit_price'.tr(), NumberFormat.currency().format(item['unitPrice'])),
            _buildItemDetailRow(
                'total'.tr(), NumberFormat.currency().format(item['totalPrice'])),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final currencyFormat = NumberFormat.currency();

    return AppScaffold(
      title: 'order_details'.tr(),
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: () => _exportToPdf(context),
          tooltip: 'export_pdf'.tr(),
        ),
      ],
      body: SingleChildScrollView(
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
                      'PO #${order.poNumber}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _buildOrderInfoRow('status'.tr(), order.status),
                    _buildOrderInfoRow(
                        'date'.tr(), dateFormat.format(order.orderDate)),
                    _buildOrderInfoRow('supplier'.tr(), order.supplierId),
                    _buildOrderInfoRow('company'.tr(), order.companyId),
                    if (order.factoryId != null)
                      _buildOrderInfoRow('factory'.tr(), order.factoryId!),
                    const Divider(height: 24),
                    _buildOrderInfoRow('subtotal'.tr(),
                        currencyFormat.format(order.totalAmount)),
                    _buildOrderInfoRow(
                        'tax'.tr(), currencyFormat.format(order.totalTax)),
                    _buildOrderInfoRow(
                        'total'.tr(),
                        currencyFormat.format(
                            order.totalAmountAfterTax)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'items'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) => _buildItemCard(item.toMap())),
          ],
        ),
      ),
    );
  }
}

 */

/* 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/item.dart'; // تأكد من استيراد نموذج Item
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class PurchaseOrderDetailsPage extends StatelessWidget {
  final PurchaseOrder order;
  const PurchaseOrderDetailsPage({super.key, required this.order});

  Widget _buildItemDetails(BuildContext context, Item item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم الصنف
            Text(
              context.locale.languageCode == 'ar' ? item.nameAr : item.nameEn,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            
            // تفاصيل الصنف
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${'quantity'.tr()}:'),
                Text(item.quantity.toString()),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${'unit_price'.tr()}:'),
                Text(item.unitPrice.toStringAsFixed(2)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${'total'.tr()}:'),
                Text(item.totalPrice.toStringAsFixed(2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'order_details'.tr(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الطلب الأساسية
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PO #${order.poNumber}',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text('${'status'.tr()}: ${order.status}'),
                    const SizedBox(height: 8),
                    Text('${'date'.tr()}: ${order.orderDate.toString()}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // قائمة الأصناف
            Text('items'.tr(), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            
            if (order.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('no_items_found'.tr()),
              )
            else
              ...order.items.map((item) => _buildItemDetails(context, item)), // أضف context هنا
          ],
        ),
      ),
    );
  }
} */

/* import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:intl/intl.dart';

class PurchaseOrderDetailsPage extends StatelessWidget {
  final PurchaseOrder order;
  const PurchaseOrderDetailsPage({super.key, required this.order});

  Widget _buildItemCard(BuildContext context, Item item) {
    final currencyFormat = NumberFormat.currency(locale: 'ar');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم الصنف
            Text(
              context.locale.languageCode == 'ar' ? item.nameAr : item.nameEn,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            
            // تفاصيل الصنف
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${'quantity'.tr()}:'),
                Text(item.quantity.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${'unit_price'.tr()}:'),
                Text(currencyFormat.format(item.unitPrice)),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${'total'.tr()}:'),
                Text(
                  currencyFormat.format(item.totalPrice),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    return AppScaffold(
      title: 'order_details'.tr(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الطلب الأساسية
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PO #${order.poNumber}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ), */
/* 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class PurchaseOrderDetailsPage extends StatefulWidget {
  final PurchaseOrder order;
  const PurchaseOrderDetailsPage({super.key, required this.order});

  @override
  State<PurchaseOrderDetailsPage> createState() =>
      _PurchaseOrderDetailsPageState();
}

class _PurchaseOrderDetailsPageState extends State<PurchaseOrderDetailsPage> {
  late Future<Map<String, String>> _companySupplierNames;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _companySupplierNames = _loadCompanyAndSupplierNames();
  }

  Future<Map<String, String>> _loadCompanyAndSupplierNames() async {
    final companyName =
        await _firestoreService.getCompanyName(widget.order.companyId,isArabic: Localizations.localeOf(context).languageCode == 'ar',);

    final supplierName =
        await _firestoreService.getSupplierName(widget.order.supplierId,isArabic: Localizations.localeOf(context).languageCode == 'ar',);
    return {
      'company': companyName,
      'supplier': supplierName,
    };
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    //final currencyFormat = NumberFormat.currency(locale: 'ar');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.locale.languageCode == 'ar' ? item.nameAr : item.nameEn,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${'quantity'.tr()}:'),
                Text(item.quantity.toString()),
              ],
            ),
            // باقي تفاصيل الصنف...
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'order_details'.tr(),
      body: FutureBuilder<Map<String, String>>(
        future: _companySupplierNames,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final names = snapshot.data ??
              {'company': 'غير معروف', 'supplier': 'غير معروف'};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow('company'.tr(), names['company']!),
                        _buildInfoRow('supplier'.tr(), names['supplier']!),
                        _buildInfoRow('po_number'.tr(), widget.order.poNumber),
                        const SizedBox(height: 16),
                        Text('${'status'.tr()}: ${widget.order.status}'),
                        const SizedBox(height: 8),
                        Text(
                            '${'date'.tr()}: ${DateFormat('yyyy-MM-dd').format(widget.order.orderDate)}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // عنوان قسم الأصناف
                Text(
                  'items'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                // قائمة الأصناف
                if (widget.order.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'no_items_found'.tr(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...widget.order.items.map((item) => _buildItemCard(item)),
              ],
            ),
          );
        },
      ),
    );
  }
}
 */

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class PurchaseOrderDetailsPage extends StatefulWidget {
  final PurchaseOrder order;
  const PurchaseOrderDetailsPage({super.key, required this.order});

  @override
  State<PurchaseOrderDetailsPage> createState() =>
      _PurchaseOrderDetailsPageState();
}

class _PurchaseOrderDetailsPageState extends State<PurchaseOrderDetailsPage> {
  late Future<Map<String, String>> _companySupplierNames;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _companySupplierNames = _loadCompanyAndSupplierNames();
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

  Widget _buildItemCard(Item item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic ? item.nameAr : item.nameEn,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildItemDetailRow(
                'quantity'.tr(),  _formatCurrency(item.quantity)),
            _buildItemDetailRow('unit_price'.tr(),
                 _formatCurrency(item.unitPrice)),
            const Divider(height: 20),
            _buildItemDetailRow(
              'total'.tr(),
              _formatCurrency(item.totalPrice) ,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailRow(String label, String value,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: isTotal
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'order_details'.tr(),
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
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow('company'.tr(), names['company']!),
                        _buildInfoRow('supplier'.tr(), names['supplier']!),
                        _buildInfoRow('po_number'.tr(), widget.order.poNumber),
                        const Divider(height: 20),
                        _buildInfoRow('status'.tr(), widget.order.status),
                        _buildInfoRow(
                          'date'.tr(),
                          DateFormat('yyyy-MM-dd')
                              .format(widget.order.orderDate),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'items'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.order.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'no_items_found'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ...widget.order.items.map((item) => _buildItemCard(item)),
              ],
            ),
          );
        },
      ),
    );
  }
}
