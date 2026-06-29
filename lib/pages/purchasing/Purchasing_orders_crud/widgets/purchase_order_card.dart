import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PurchaseOrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final String companyName;
  final String vendorName;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final String poNumber;
  final String supplierName;
  final bool isArabic;

  const PurchaseOrderCard({
    super.key,
    required this.data,
    required this.orderId,
    required this.companyName,
    required this.vendorName,
    required this.onDelete,
    required this.onEdit,
    required this.onExport,
    required this.poNumber,
    required this.supplierName,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isConfirmed = data['isConfirmed'] ?? false;
    final dateStr = createdAt != null
        ? DateFormat('yyyy-MM-dd').format(createdAt.toLocal())
        : 'N/A';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(poNumber),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'company'.tr()}: $companyName'),
            Text('${'supplier'.tr()}: $vendorName'),
            Text(
              '${'total'.tr()}: ${data['totalAmount']?.toStringAsFixed(2) ?? 'N/A'} ${'currency'.tr()}',
            ),
            Text('${'date'.tr()}: $dateStr'),
            Text(
              '${'status'.tr()}: ${isConfirmed ? 'confirmed'.tr() : 'unconfirmed'.tr()}',
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.green),
              tooltip: 'QR Code',
              onPressed: () => _showQrDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: 'exportPDF'.tr(),
              onPressed: onExport,
            ),
            if (!isConfirmed) ...[
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: 'edit'.tr(),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'delete'.tr(),
                onPressed: onDelete,
              ),
            ]
          ],
        ),
        onTap: () {
          context.push(
            '/purchase-order-detail?companyId=${data['companyId']}&orderId=$orderId',
          );
        },
      ),
    );
  }

  void _showQrDialog(BuildContext context) {
    final qrData = 'PO:$poNumber\nCompany:$companyName\nSupplier:$vendorName';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code'),
        content: SizedBox(
          width: 200,
          height: 200,
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 200.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
